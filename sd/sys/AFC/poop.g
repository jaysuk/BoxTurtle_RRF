var max_iteration_length = 40                                                                    ; Defines the maximum length of filament (mm) extruded per loop pass.
var iteration_z_raise = 6                                                                        ; Maximum initial Z-raise distance (mm) within a blob cycle.
var iteration_z_change = 0.6                                                                     ; Z-height change (mm) applied per step to create the tapered effect.
var max_iterations_per_blob = 3                                                                  ; Number of passes (steps) that constitute one "blob" or layer cycle before resetting the Z start height.
var pressure_release_time = 1000                                                                 ; Dwell time (ms) for pressure release (not used in final code).
var purge_z = 0                                                                                  ; Initial Z height variable (not explicitly calculated from globals, but used as base).
var purge_amount_left = 0                                                                        ; Tracks how much total purge material is remaining.
var purge_len = 0                                                                                ; Total calculated length of filament to purge.
var backup_feedrate = 0                                                                          ; Stores the original M220 speed factor for restoration.
var extrude_amount = 0                                                                           ; Actual amount of filament (mm) to extrude in the current pass.
var extrude_ratio = 0                                                                            ; Ratio of current extrude amount to max iteration length (used to scale Z move).
var step_triangular = 0                                                                          ; Stores the cumulative Z change calculation (triangular number series).
var z_raise_substract = 0                                                                        ; The amount to subtract from the iteration_z_raise based on the current step.
var raise_z = 0                                                                                  ; Final calculated Z movement distance for the current pass.
var duration = 0                                                                                 ; Calculated time (seconds) the current extrusion move will take.
var speed = 0                                                                                    ; Calculated Z speed (mm/s) for coordinated Z/E move.
var max_iterations_reached = false                                                               ; Flag: True if the max steps per blob cycle has been reached.
var purge_length_reached = false                                                                 ; Flag: True if the total required purge length has been met.
var backup_fan_speed = 0                                                                         ; Stores the original part cooling fan speed for restoration.
var max_iterations = 0                                                                           ; Total number of passes required to meet the full purge length.
var step = 0                                                                                     ; The current step number within the max_iterations_per_blob cycle (modulus).
var travel_speed_xy = global.AFC_travel_speed[0] * 60
var travel_speed_z = global.AFC_travel_speed[1] * 60
var purge_speed_mm_min = global.AFC_purge_speed * 60

M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Starting poop"                                             ; Log the start of the purge routine.

; --- Part Cooling Fan Setup ---
if global.AFC_part_cooling_fan[0]                                                                ; Check if fan control is enabled (index 0 is likely a boolean flag).
    M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Set Cooling Fan to Full Speed"
    set var.backup_fan_speed = fans[0].requestedValue                                            ; Capture original fan speed.
    M400                                                                                         ; Wait for moves to finish before changing fan state.
    M106 S{global.AFC_part_cooling_fan[1]}                                                       ; Set fan to the configured full speed value (index 1).

; --- Speed Factor Setup ---
set var.backup_feedrate = (move.speedFactor * 100)                                               ; Capture original M220 speed factor (scaled by 100).
M220 S100                                                                                        ; Set M220 speed factor to 100% for predictable movement.

; TODO add handling of slicer driven purge values
set var.purge_len = global.AFC_purge_length[0]                                                   ; Set target purge length from configuration (index 0).

; Apply purge minimum
set var.purge_len = max(var.purge_len,global.AFC_purge_length[1])                                ; Enforce a minimum purge length (index 1).

M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Move To Purge Location"                                    ; Log move to purge location.

; --- Move to Start Location ---
G1 X{global.AFC_purge_location[0]} Y{global.AFC_purge_location[1]} F{var.travel_speed_xy}        ; Move XY to the configured purge coordinates (mm/min speed).

if global.AFC_z_purge_move                                                                       ; Check if Z movement is enabled for purging.
    G1 Z{var.purge_z+global.AFC_purge_start} F{var.travel_speed_z}                               ; Move Z to the starting height (base Z + configured offset).

; --- Iteration Setup ---
set var.max_iterations = ceil(var.purge_len / var.max_iteration_length)                          ; Calculate the total number of passes needed.

; Repeat the process until purge_len is reached

; --- Purge Loop (Executes the segmented extrusion and Z lift) ---
while iterations < var.max_iterations                                                            ; Loop executes once per segment of max_iteration_length.
    M98 P"0:/sys/AFC/debug.g" A{"AFC_Poop: Iteration " ^ iterations ^ ", Blob Step " ^ var.step} ; Log current pass number.
    set var.step = mod(iterations, var.max_iterations_per_blob)                                  ; Calculate current step within the blob cycle (0 to max_iterations_per_blob - 1).
    if var.step == 0                                                                             ; If this is the start of a new blob cycle (new layer).
        if global.AFC_z_purge_move                                                               ; If Z movement is enabled.
            G1 Z{var.purge_z+global.AFC_purge_start} F{var.travel_speed_z}                       ; Reset Z to the base starting height.
    set var.purge_amount_left = var.purge_len - (var.max_iteration_length * iterations)          ; Calculate remaining filament needed.
    set var.extrude_amount = min(var.purge_amount_left,var.max_iteration_length)                 ; Extrude the remaining amount or the max iteration length, whichever is smaller.
    set var.extrude_ratio = var.extrude_amount / var.max_iteration_length                        ; Ratio of E movement for Z-scaling (if necessary).

    G91                                                                                          ; Switch to Relative Positioning mode.
    M83                                                                                          ; Ensure Relative Extrusion mode is active.

                                                                                                 ; --- Z-Height Lift Calculation (Creates the tapered structure) ---
    set var.step_triangular = var.step * (var.step + 1) / 2                                      ; Calculates the triangular series (1, 3, 6, 10...) for stepped Z change.
    if var.step == 0
        set var.z_raise_substract = global.AFC_purge_start                                       ; If first step, subtract the starting Z offset.
    else 
        set var.z_raise_substract = var.step_triangular * var.iteration_z_change                 ; Otherwise, subtract the cumulative stepped Z change.
    set var.raise_z = ((var.iteration_z_raise - var.z_raise_substract) * var.extrude_ratio)      ; Calculate the Z distance to move in this pass (scaled by E ratio).
    set var.raise_z = max(var.raise_z,0)                                                         ; Ensure Z movement is never negative.

    set var.duration = var.extrude_amount / (var.purge_speed_mm_min)                             ; Calculate duration (seconds) based on E amount and E speed (mm/min).

                                                                                                 ; --- Coordinated E/Z Move ---
    if global.AFC_z_purge_move                                                                   ; If Z movement is enabled.
        set var.speed = var.raise_z / var.duration                                               ; Calculate the required Z speed (mm/s) to coordinate Z and E movements.
        G1 Z{var.raise_z} E{var.extrude_amount} F{var.speed}                                     ; Coordinated move of Z (relative) and E (relative) at the calculated Z speed.
    else
        G1 E{var.extrude_amount} F{var.speed}                                                    ; Pure extrusion move (no Z lift).

                                                                                                 ; --- Loop Termination Checks (Prepares for next loop or final actions) ---
    if var.step == var.max_iterations_per_blob - 1                                               ; Check if the last step of the current blob cycle has been reached.
        set var.max_iterations_reached = true

    if (var.purge_len - var.max_iteration_length * (iterations + 1)) <= 0                        ; Check if the total purge length is met or exceeded by the end of the next iteration.
         set var.purge_length_reached = true

    if var.max_iterations_reached || var.purge_length_reached                                    ; If cycle ends or total length is met.
        M83                                                                                      ; Re-assert relative extrusion mode (redundant if M83 is still active).
        G4 S{global.AFC_part_cooling_fan[2]}                                                     ; Dwell/Wait for pressure to release (index 2 is likely the time in seconds).

G90                                                                                              ; Switch back to Absolute Positioning mode.

; --- Final Z Lift and Restoration ---
M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Fast Z Lift to keep poop from sticking"                    ; Log fast lift.

if global.AFC_z_purge_move
    G1 Z{global.AFC_purge_fast_z[1]} F{global.AFC_purge_fast_z[0] * 60}                          ; Perform a fast Z move to the final park height (index 1) to break the purged blob free.

M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Restore fan speed and feedrate"                            ; Log restoration.

if global.AFC_part_cooling_fan[0]                                                                ; Check if fan was controlled.
    M106 S{var.backup_fan_speed}                                                                 ; Restore original part cooling fan speed.

M220 S{var.backup_feedrate}                                                                      ; Restore original M220 speed factor.