; === AFC Filament Cutting Macro (RepRapFirmware G-Code) ===
; Purpose: Executes a high-force filament cutting routine against a fixed pin/blade
;          by moving the X or Y axis, manages safety features, and restores settings.

; --- Macro Parameters ---
; param.A = lane number (not used in motion calculations below, but useful for logging/context)
; param.B = total number of axes (not strictly needed as it's not used in cleanup here)

; --- Local Variable Initialization and State Capture ---
var location_factor = {0,0}                                                                                                        ; Array to hold the direction vector for the cut move.
var pin_park_x_loc = 0                                                                                                             ; Calculated X coordinate for the pre-cut/park position.
var pin_park_y_loc = 0                                                                                                             ; Calculated Y coordinate for the pre-cut/park position.
var fast_slow_transition_loc_x = 0                                                                                                 ; X coordinate where the cut move slows down.
var full_cut_loc_x = 0                                                                                                             ; Final X coordinate of the hard cut move.
var fast_slow_transition_loc_y = 0                                                                                                 ; Y coordinate where the cut move slows down.
var full_cut_loc_y = 0                                                                                                             ; Final Y coordinate of the hard cut move.
var extruder_move_dist = 0                                                                                                         ; Tracks the total amount of E movement for logging/context.
var cut_dist = 0                                                                                                                   ; Stores the calculated total distance of the cut move.
var xmin = move.axes[0].min                                                                                                        ; Capture X axis minimum limit for safety check.
var xmax = move.axes[0].max                                                                                                        ; Capture X axis maximum limit for safety check.
var ymin = move.axes[1].min                                                                                                        ; Capture Y axis minimum limit for safety check.
var ymax = move.axes[1].max                                                                                                        ; Capture Y axis maximum limit for safety check.
var x_current = move.axes[0].current                                                                                               ; Capture current X motor current for restoration later.
var y_current = move.axes[1].current                                                                                               ; Capture current Y motor current for restoration later.
var z_current = move.axes[2].current                                                                                               ; Capture current Z motor current for restoration later.
var previous_pa = move.extruders[0].pressureAdvance                                                                                ; Capture current Pressure Advance (PA) value for restoration later.

M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Cut Filament"                                                                                 ; Log start of cut macro.

; --- Calculate Location Factor Vector (Used to calculate initial park location) ---
if global.AFC_cut_direction == "left"
    set var.location_factor = {1,0}                                                                                                ; Initial move is away from cut, along X+.
if global.AFC_cut_direction == "right"
    set var.location_factor = {-1,0}                                                                                               ; Initial move is away from cut, along X-.
if global.AFC_cut_direction == "front"
    set var.location_factor = {0,1}                                                                                                ; Initial move is away from cut, along Y+.
if global.AFC_cut_direction == "back"
    set var.location_factor = {0,-1}                                                                                               ; Initial move is away from cut, along Y-.

; --- Calculate Pre-Cut Park Position (pin_park_x/y_loc) ---
if global.AFC_cut_direction == "left" || global.AFC_cut_direction == "right"
    set var.pin_park_x_loc = global.AFC_cut_location[0] + (var.location_factor[0] * global.AFC_cut_dist[0])                        ; Calculate X park position.
    set var.pin_park_y_loc = global.AFC_cut_location[1]                                                                            ; Y remains constant.
elif global.AFC_cut_direction == "front" || global.AFC_cut_direction == "back"
    set var.pin_park_x_loc = global.AFC_cut_location[0]
    set var.pin_park_y_loc = global.AFC_cut_location[1] + (var.location_factor[1] * global.AFC_cut_dist[0])                        ; Calculate Y park position.
else
    M118 S"Invalid cut direction. Check the cut_direction in your AFC_Vars.g file!"                                                ; Report error if direction is invalid.

; --- Safety Setup and Initial Retract/Lift ---
M572 D0 S0                                                                                                                         ; Temporarily disable Pressure Advance (PA) on D0.
G90                                                                                                                                ; Switch to Absolute Positioning mode.
M83                                                                                                                                ; Switch to Relative Extrusion mode (M83).
G92 E0                                                                                                                             ; Reset the extruder position to 0.

M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Lift Z"                                                                                       ; Log Z lift.
G91                                                                                                                                ; Switch to Relative Positioning mode.
G1 Z5 E-1 F{global.AFC_travel_speed[1]*60}                                                                                         ; Lift Z by 5mm and retract E by 1mm.
M98 P"0:/sys/AFC/step_through_macro.g" A{line} A{line}                                                                             ; Call debug macro.
G90                                                                                                                                ; Switch back to Absolute Positioning mode.

if global.AFC_cut_retract_length > 0                                                                                               ; Check if pre-cut retract is configured.
    M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Retract Filament for Cut"
    G1 E{-global.AFC_cut_retract_length} F{global.AFC_cut_move[5]*60}                                                              ; Retract filament by configured length.
    M98 P"0:/sys/AFC/step_through_macro.g" A{line}
    if global.AFC_cut_quick_tip_forming                                                                                            ; Perform quick tip forming (small push/pull).
        M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Performing Quick Tip Form"
        G1 E{global.AFC_cut_retract_length/2} F{global.AFC_cut_move[5]*60}                                                         ; Push E forward half retract length.
        M98 P"0:/sys/AFC/step_through_macro.g" A{line}
        G1 E{-global.AFC_cut_retract_length/2} F{global.AFC_cut_move[5]*60}                                                        ; Pull E back half retract length.
        M98 P"0:/sys/AFC/step_through_macro.g" A{line}
    set var.extruder_move_dist = var.extruder_move_dist + global.AFC_cut_retract_length                                            ; Update E distance tracked.

M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Move to Cut Pin Location"
G1 X{var.pin_park_x_loc} Y{var.pin_park_y_loc} F{global.AFC_travel_speed[0]*60}                                                    ; Move to the calculated park position near the cut pin.
M98 P"0:/sys/AFC/step_through_macro.g" A{line} A{line}

M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Cut Move..."

; --- Increase Motor Current for Cutting Force (M906) ---
if global.AFC_cut_current_stepper[0] > 0
    M906 X{global.AFC_cut_current_stepper[0]}                                                                                      ; Temporarily increase X motor current.
if global.AFC_cut_current_stepper[1] > 0
    M906 Y{global.AFC_cut_current_stepper[1]}                                                                                      ; Temporarily increase Y motor current.
if global.AFC_cut_current_stepper[2] > 0
    M906 Z{global.AFC_cut_current_stepper[2]}                                                                                      ; Temporarily increase Z motor current.

; --- Cutting Distance Calculation ---
set var.cut_dist = global.AFC_cut_dist[0]+global.AFC_cut_dist[1]                                                                   ; Calculate total cut travel distance.

; --- Multi-Pass Cutting Loop (N-1 passes) ---
while iterations < {global.AFC_cut_move[6]-1}
                                                                                                                                   ; Redundant direction vector calculation (should ideally be moved out of the loop).
    if global.AFC_cut_direction == "left"
        set var.location_factor = {-1,0}                                                                                           ; Actual cut move direction (X-).
    if global.AFC_cut_direction == "right"
        set var.location_factor = {1,0}                                                                                            ; Actual cut move direction (X+).
    if global.AFC_cut_direction == "front"
        set var.location_factor = {0,-1}                                                                                           ; Actual cut move direction (Y-).
    if global.AFC_cut_direction == "back"
        set var.location_factor = {0,1}                                                                                            ; Actual cut move direction (Y+).

                                                                                                                                   ; --- X-Axis Cut Pass ---
    if global.AFC_cut_direction == "left" || global.AFC_cut_direction == "right"
        set var.fast_slow_transition_loc_x = var.pin_park_x_loc + var.location_factor[0] * (var.cut_dist * global.AFC_cut_move[4]) ; Calculate fast-to-slow transition X point.
        set var.full_cut_loc_x = var.pin_park_x_loc + var.location_factor[0] * var.cut_dist                                        ; Calculate final cut X point.
        if var.full_cut_loc_x > var.xmax || var.full_cut_loc_x < var.xmin                                                          ; Safety Check: Check if final X position is within limits.
            M118 S"X Cut move is outside your printer bounds. Check the cut_move_dist in your AFC_Vars.cfg file!"
        else
            G1 X{var.fast_slow_transition_loc_x} F{global.AFC_cut_move[0]*60}                                                      ; Move to transition point (Fast Approach).
            M98 P"0:/sys/AFC/step_through_macro.g" A{line}
            G1 X{var.full_cut_loc_x} F{global.AFC_cut_move[1]*60}                                                                  ; Move to final cut point (Slow, High-Force Cut).
            M98 P"0:/sys/AFC/step_through_macro.g" A{line}
            G4 P{global.AFC_cut_move[3]}                                                                                           ; Dwell after cut.
            G4 P200
            G1 X{var.pin_park_x_loc} F{global.AFC_cut_move[2]*60}                                                                  ; Move back to the initial park position (Fast Return).
            M98 P"0:/sys/AFC/step_through_macro.g" A{line}

                                                                                                                                   ; --- Y-Axis Cut Pass ---
    elif global.AFC_cut_direction == "front" || global.AFC_cut_direction == "back"
        set var.fast_slow_transition_loc_y = var.pin_park_y_loc + var.location_factor[1] * (var.cut_dist * global.AFC_cut_move[4]) ; Calculate transition Y point.
        set var.full_cut_loc_y = var.pin_park_y_loc + var.location_factor[1] * var.cut_dist                                        ; Calculate final cut Y point.
        if var.full_cut_loc_y > var.ymax || var.full_cut_loc_y < var.ymin                                                          ; Safety Check: Check if final Y position is within limits.
            M118 S"X Cut move is outside your printer bounds. Check the cut_move_dist in your AFC_Vars.cfg file!"                  ; Note: Error message incorrectly refers to 'X Cut move'.
        else
            G1 Y{var.fast_slow_transition_loc_y} F{global.AFC_cut_move[0]*60}                                                      ; Fast approach move.
            M98 P"0:/sys/AFC/step_through_macro.g" A{line}
            G1 Y{var.full_cut_loc_y} F{global.AFC_cut_move[1]*60}                                                                  ; Slow, high-force cut move.
            M98 P"0:/sys/AFC/step_through_macro.g" A{line}
            G4 P{global.AFC_cut_move[3]}                                                                                           ; Dwell after cut.
            G4 P200
            G1 Y{var.pin_park_y_loc} F{global.AFC_cut_move[2]*60}                                                                  ; Fast return to park position.
            M98 P"0:/sys/AFC/step_through_macro.g" A{line}
    else
        M118 S"Invalid cut direction. Check the cut_direction in your AFC_Vars.g file!"

; --- Final Pass and Rip ---
M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Final Move..."

; Redundant direction vector calculation.
if global.AFC_cut_direction == "left"
    set var.location_factor = {-1,0}
if global.AFC_cut_direction == "right"
    set var.location_factor = {1,0}
if global.AFC_cut_direction == "front"
    set var.location_factor = {0,-1}
if global.AFC_cut_direction == "back"
    set var.location_factor = {0,1}

; --- X-Axis Final Cut and Rip Routine ---
if global.AFC_cut_direction == "left" || global.AFC_cut_direction == "right"
    set var.fast_slow_transition_loc_x = var.pin_park_x_loc + var.location_factor[0] * (var.cut_dist * global.AFC_cut_move[4])
    set var.full_cut_loc_x = var.pin_park_x_loc + var.location_factor[0] * var.cut_dist
    if var.full_cut_loc_x > var.xmax || var.full_cut_loc_x < var.xmin
        M118 S"X Cut move is outside your printer bounds. Check the cut_move_dist in your AFC_Vars.cfg file!"
    else
        G1 X{var.fast_slow_transition_loc_x} F{global.AFC_cut_move[0]*60}                                                          ; Fast approach to transition point.
        M98 P"0:/sys/AFC/step_through_macro.g" A{line}
        G1 X{var.full_cut_loc_x} F{global.AFC_cut_move[1]*60}                                                                      ; Final slow cut move.
        M98 P"0:/sys/AFC/step_through_macro.g" A{line}
        G4 P{global.AFC_cut_move[3]}                                                                                               ; Dwell.
        if global.AFC_cut_rip[0] > 0                                                                                               ; Check if rip/pullback is configured.
            G1 E{-global.AFC_cut_rip[0]} F{global.AFC_cut_rip[1] * 60}                                                             ; Perform E-retract to tear/rip filament free.
        G4 P200
        G1 X{var.pin_park_x_loc} F{global.AFC_cut_move[2]*60}                                                                      ; Return to park position.
        M98 P"0:/sys/AFC/step_through_macro.g" A{line}

; --- Y-Axis Final Cut and Rip Routine ---
elif global.AFC_cut_direction == "front" || global.AFC_cut_direction == "back"
    set var.fast_slow_transition_loc_y = var.pin_park_y_loc + var.location_factor[1] * (var.cut_dist * global.AFC_cut_move[4])
    set var.full_cut_loc_y = var.pin_park_y_loc + var.location_factor[1] * var.cut_dist
    if var.full_cut_loc_y > var.ymax || var.full_cut_loc_y < var.ymin
        M118 S"Y Cut move is outside your printer bounds. Check the cut_move_dist in your AFC_Vars.cfg file!"                      ; Safety check.
    else
        G1 Y{var.fast_slow_transition_loc_y} F{global.AFC_cut_move[0]*60}                                                          ; Fast approach to transition point.
        M98 P"0:/sys/AFC/step_through_macro.g" A{line}
        G1 Y{var.full_cut_loc_y} F{global.AFC_cut_move[1]*60}                                                                      ; Final slow cut move.
        M98 P"0:/sys/AFC/step_through_macro.g" A{line}
        G4 P{global.AFC_cut_move[3]}
        if global.AFC_cut_rip[0] > 0
            G1 E{-global.AFC_cut_rip[0]} F{global.AFC_cut_rip[1] * 60}                                                             ; Perform E-retract to tear/rip filament free.
        G4 P200
        G1 Y{var.pin_park_y_loc} F{global.AFC_cut_move[2]*60}                                                                      ; Return to park position.
        M98 P"0:/sys/AFC/step_through_macro.g" A{line}
else
    M118 S"Invalid cut direction. Check the cut_direction in your AFC_Vars.g file!"

; --- Restore Motor Current ---
if global.AFC_cut_current_stepper[0] > 0
    M906 X{var.x_current}                                                                                                          ; Restore X motor current to captured value.
if global.AFC_cut_current_stepper[1] > 0
    M906 Y{var.y_current}                                                                                                          ; Restore Y motor current to captured value.
if global.AFC_cut_current_stepper[2] > 0
    M906 Z{var.z_current}                                                                                                          ; Restore Z motor current to captured value.

set var.extruder_move_dist = var.extruder_move_dist + global.AFC_cut_rip[0]                                                        ; Update E distance tracked.

; --- Tip Pushback (Optional Cleanup) ---
if global.AFC_cut_pushback[0] > 0
    M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Push cut tip back into hotend"
    G1 E{global.AFC_cut_pushback[0]} F{global.AFC_cut_move[5]*60}                                                                  ; Push E forward slightly to clear entrance.
    M98 P"0:/sys/AFC/step_through_macro.g" A{line}
    G4 P{global.AFC_cut_pushback[1]}                                                                                               ; Dwell.
    G1 E{-global.AFC_cut_pushback[0]} F{global.AFC_cut_move[5]*60}                                                                 ; Retract E back.
    M98 P"0:/sys/AFC/step_through_macro.g" A{line}
    set var.extruder_move_dist = var.extruder_move_dist + global.AFC_cut_pushback[0]                                               ; Update E distance tracked.

M572 D0 S{var.previous_pa}                                                                                                         ; Restore Pressure Advance (PA) value.