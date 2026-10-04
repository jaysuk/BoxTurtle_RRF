; === AFC Filament Cutting Macro (RepRapFirmware G-Code) ===
; Purpose: Executes a high-force filament cutting routine against a fixed pin/blade
;          by moving the X or Y axis, manages safety features, and restores settings.
; The configuration is validated before anything moves; a problem calls afc_error.g (pause + message), never abort.

; --- Machine_cut_* settings used ---
; Machine_cut_location   {x, y}  toolhead position where the cutter arm just touches the depressor pin
; Machine_cut_direction  "left"|"right"|"front"|"back"  direction of the cutting move
; Machine_cut_dist       {park, move}  run-up distance before the pin, distance to compress the cutter arm (mm)
; Machine_cut_move       {fast, slow, evacuate speed (mm/s), dwell (ms), fast fraction, extruder speed (mm/s), cut count}

; --- Validate the configuration (before any state is changed) ---
var axis = 0                                                                                                                        ; 0 = cut along X, 1 = cut along Y
var sign = 1                                                                                                                        ; +1 = cut towards the axis maximum, -1 = towards the minimum
if global.Machine_cut_direction == "left"
    set var.axis = 0
    set var.sign = -1
elif global.Machine_cut_direction == "right"
    set var.axis = 0
    set var.sign = 1
elif global.Machine_cut_direction == "front"
    set var.axis = 1
    set var.sign = -1
elif global.Machine_cut_direction == "back"
    set var.axis = 1
    set var.sign = 1
else
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"Invalid cut direction. Check Machine_cut_direction in your Machine_user_vars.g file" Q1 F1
    M99

var other = 1 - var.axis                                                                                                            ; the axis we do not move along
var axis_idx = global.Machine_axis_number[var.axis]
var other_idx = global.Machine_axis_number[var.other]
var cut_dist = global.Machine_cut_dist[0] + global.Machine_cut_dist[1]                                                              ; Total cut travel distance.
var park_pos = global.Machine_cut_location[var.axis] - var.sign * global.Machine_cut_dist[0]                                         ; Run-up position on the cut axis (away from the pin).
var full_pos = var.park_pos + var.sign * var.cut_dist                                                                               ; End of the cut move.
var trans_pos = var.park_pos + var.sign * var.cut_dist * global.Machine_cut_move[4]                                                 ; Fast-to-slow transition.
var axis_name = "X"
if var.axis == 1
    set var.axis_name = "Y"

var out_of_bounds = var.park_pos < move.axes[var.axis_idx].min || var.park_pos > move.axes[var.axis_idx].max
set var.out_of_bounds = var.out_of_bounds || var.full_pos < move.axes[var.axis_idx].min || var.full_pos > move.axes[var.axis_idx].max
set var.out_of_bounds = var.out_of_bounds || global.Machine_cut_location[var.other] < move.axes[var.other_idx].min || global.Machine_cut_location[var.other] > move.axes[var.other_idx].max
if var.out_of_bounds
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"The "^var.axis_name^" cut move is outside your printer bounds. Check Machine_cut_location and Machine_cut_dist in your Machine_user_vars.g file"} Q1 F1
    M99

; --- Local Variable Initialization and State Capture ---
var park_x = global.Machine_cut_location[0]                                                                                         ; XY position of the run-up (only the cut axis differs from the pin location).
var park_y = global.Machine_cut_location[1]
if var.axis == 0
    set var.park_x = var.park_pos
else
    set var.park_y = var.park_pos
var x_current = move.axes[global.Machine_axis_number[0]].current                                                                    ; Capture current motor currents so they can be restored.
var y_current = move.axes[global.Machine_axis_number[1]].current
var z_current = move.axes[global.Machine_axis_number[2]].current
var ext = tools[move.motionSystems[0].currentTool].extruders[0]                                                                     ; Printer extruder of the tool that is being unloaded.
var pa_k0 = move.extruders[var.ext].pressAdv.k0                                                                                     ; Capture pressure advance (3.7 two-slope) to restore it afterwards.
var pa_k1 = move.extruders[var.ext].pressAdv.k1
var pa_d = move.extruders[var.ext].pressAdv.d
var passes = max(global.Machine_cut_move[6], 1)

M98 P"0:/sys/AFC/Macros/debug.g" A"AFC_Cut: Cut Filament"                                                                           ; Log start of cut macro.

; --- Safety Setup and Initial Retract/Lift ---
M572 D{var.ext} S0                                                                                                                  ; Temporarily disable Pressure Advance (PA).
G90                                                                                                                                 ; Switch to Absolute Positioning mode.
M83                                                                                                                                 ; Switch to Relative Extrusion mode (M83).
G92 E0                                                                                                                              ; Reset the extruder position to 0.

M98 P"0:/sys/AFC/Macros/debug.g" A"AFC_Cut: Lift Z"                                                                                 ; Log Z lift.
G91                                                                                                                                 ; Switch to Relative Positioning mode.
G1 Z5 E-1 F{global.Machine_travel_speed[1] * 60}                                                                                    ; Lift Z by 5mm and retract E by 1mm.
G90                                                                                                                                 ; Switch back to Absolute Positioning mode.

if global.Machine_cut_retract_length > 0                                                                                            ; Check if pre-cut retract is configured.
    M98 P"0:/sys/AFC/Macros/debug.g" A"Machine_Cut: Retract Filament for Cut"
    G1 E{-global.Machine_cut_retract_length} F{global.Machine_cut_move[5] * 60}                                                     ; Retract filament by configured length.
    if global.Machine_cut_quick_tip_forming                                                                                         ; Perform quick tip forming (small push/pull).
        M98 P"0:/sys/AFC/Macros/debug.g" A"Machine_Cut: Performing Quick Tip Form"
        G1 E{global.Machine_cut_retract_length/2} F{global.Machine_cut_move[5] * 60}                                                ; Push E forward half retract length.
        G1 E{-global.Machine_cut_retract_length/2} F{global.Machine_cut_move[5] * 60}                                               ; Pull E back half retract length.

M98 P"0:/sys/AFC/Macros/debug.g" A"Machine_Cut: Move to Cut Pin Location"
G1 X{var.park_x} Y{var.park_y} F{global.Machine_travel_speed[0] * 60}                                                               ; Move to the run-up position near the cut pin.

M98 P"0:/sys/AFC/Macros/debug.g" A"AFC_Cut: Cut Move..."

; --- Increase Motor Current for Cutting Force (M906) ---
if global.Machine_cut_current_stepper[0] > 0
    M906 X{global.Machine_cut_current_stepper[0]}                                                                                   ; Temporarily increase X motor current.
if global.Machine_cut_current_stepper[1] > 0
    M906 Y{global.Machine_cut_current_stepper[1]}                                                                                   ; Temporarily increase Y motor current.
if global.Machine_cut_current_stepper[2] > 0
    M906 Z{global.Machine_cut_current_stepper[2]}                                                                                   ; Temporarily increase Z motor current.

; --- Cutting passes: all but the last are plain cuts, the last one also rips the filament free ---
while iterations < var.passes
    var final_pass = (iterations == var.passes - 1)
    if var.axis == 0
        G1 X{var.trans_pos} F{global.Machine_cut_move[0] * 60}                                                                      ; Fast approach to the transition point.
        G1 X{var.full_pos} F{global.Machine_cut_move[1] * 60}                                                                       ; Slow, high-force cut move.
    else
        G1 Y{var.trans_pos} F{global.Machine_cut_move[0] * 60}
        G1 Y{var.full_pos} F{global.Machine_cut_move[1] * 60}
    G4 P{global.Machine_cut_move[3]}                                                                                                ; Dwell after cut.
    if var.final_pass && global.Machine_cut_rip[0] > 0                                                                              ; Rip: E-retract to tear the filament free.
        G1 E{-global.Machine_cut_rip[0]} F{global.Machine_cut_rip[1] * 60}
    G4 P200
    if var.axis == 0
        G1 X{var.park_pos} F{global.Machine_cut_move[2] * 60}                                                                       ; Fast return to the run-up position.
    else
        G1 Y{var.park_pos} F{global.Machine_cut_move[2] * 60}

; --- Restore Motor Current ---
if global.Machine_cut_current_stepper[0] > 0
    M906 X{var.x_current}                                                                                                           ; Restore X motor current to captured value.
if global.Machine_cut_current_stepper[1] > 0
    M906 Y{var.y_current}                                                                                                           ; Restore Y motor current to captured value.
if global.Machine_cut_current_stepper[2] > 0
    M906 Z{var.z_current}                                                                                                           ; Restore Z motor current to captured value.

; --- Tip Pushback (Optional Cleanup) ---
if global.Machine_cut_pushback[0] > 0
    M98 P"0:/sys/AFC/Macros/debug.g" A"Machine_Cut: Push cut tip back into hotend"
    G1 E{global.Machine_cut_pushback[0]} F{global.Machine_cut_move[5] * 60}                                                         ; Push E forward slightly to clear entrance.
    G4 P{global.Machine_cut_pushback[1]}                                                                                            ; Dwell.
    G1 E{-global.Machine_cut_pushback[0]} F{global.Machine_cut_move[5] * 60}                                                        ; Retract E back.

; --- Restore Pressure Advance (single value, or the two-slope pair with its speed threshold) ---
if var.pa_k0 == var.pa_k1
    M572 D{var.ext} S{var.pa_k0}
else
    M572 D{var.ext} S{var.pa_k0, var.pa_k1} L{var.pa_d}
