; --- Calculation of Brush Boundaries ---
; global.AFC_brush[0] = Brush Center X, global.AFC_brush[4] = Brush Width X
var brush_x_max = global.Machine_brush[0] + (global.Machine_brush[4]/2)       ; Calculate the maximum X coordinate for the brush path.
var brush_x_min = global.Machine_brush[0] - (global.Machine_brush[4]/2)       ; Calculate the minimum X coordinate for the brush path.
; global.AFC_brush[1] = Brush Center Y, global.AFC_brush[5] = Brush Depth Y
var brush_y_max = global.Machine_brush[1] + (global.Machine_brush[5]/2)       ; Calculate the maximum Y coordinate for the brush path.
var brush_y_min = global.Machine_brush[1] - (global.Machine_brush[5]/2)       ; Calculate the minimum Y coordinate for the brush path.

; --- Speed and Position Capture ---
var travel_speed = global.Machine_travel_speed[0] * 60                            ; Convert fast XY travel speed (index 0) from mm/s to mm/min.
var z_travel_speed = global.Machine_travel_speed[1] * 60                          ; Convert Z travel speed (index 1) from mm/s to mm/min.
var xmin = move.axes[global.Machine_axis_number[0]].min                                                   ; Capture the printer's X axis minimum limit. (Not used below, but good for context/debugging)
var xmax = move.axes[global.Machine_axis_number[0]].max                                                   ; Capture the printer's X axis maximum limit.
var ymin = move.axes[global.Machine_axis_number[1]].min                                                   ; Capture the printer's Y axis minimum limit.
var ymax = move.axes[global.Machine_axis_number[1]].max                                                   ; Capture the printer's Y axis maximum limit.
var currentx = move.axes[global.Machine_axis_number[0]].machinePosition                                   ; Capture the current X position for return later.
var currenty = move.axes[global.Machine_axis_number[1]].machinePosition                                   ; Capture the current Y position for return later.
var currentz = move.axes[global.Machine_axis_number[2]].machinePosition                                   ; Capture the current Z position.

; --- Global Machine_brush Array Index Reference ---
; [0]: Brush Center X Position
; [1]: Brush Center Y Position
; [2]: Brush Z Position (or -1 to skip Z move)
; [3]: Speed of cleaning moves when brushing (mm/s)
; [4]: Total width in mm of the brush in the X direction
; [5]: Total depth in mm of the brush in the Y direction
; [6]: True - Brush along Y axis first then X. False - Only brush along X.
; [7]: Number of passes to make on the brush.
; [8]: Whether the brush is on a servo or motor for deployment
; [9]: Servo pin number
; [10]: Deployed angle
; [11]: Retracted angle
; [12]: Servo number (for M950)
; [13]: Brush clean acceleration
; [14]: True - Z needs to be above a certain height for brush deployment. False - No minimum z height required

; move to the centre of the brush

M98 P"0:/sys/AFC/Macros/debug.g" A"Machine_brush: Clean Nozzle"               ; Log start of Nozzle Clean routine.
M98 P"0:/sys/AFC/Macros/debug.g" A"Machine_brush: Move to Brush."             ; Log move preparation.

; Check Z-Height Safety and Move Z
; Check if Z minimum height is required (global.Machine_brush[13]) AND if the target Z is higher than the current Z.
if global.Machine_brush[14] && (global.Machine_brush[2] > var.currentz)
    G1 Z{global.Machine_brush[2]} F{var.z_travel_speed}                       ; Move Z axis up to the required Z position before horizontal travel.

; Deploy the brush mechanism
if global.Machine_brush[8] && fileexists("0:/sys/AFC/Macros/brush_deploy.g")  ; Check if servo deployment is active and a custom macro exists.
    M98 P"0:/sys/AFC/Macros/brush_deploy.g"                                   ; Execute the custom deployment macro.
elif global.Machine_brush[8]                                                  ; If servo deployment is active but no macro exists, use direct servo control.
    M950 S{global.Machine_brush[12]} C{global.Machine_brush[9]}               ; Define the logical servo (S[11] - Retracted angle index) and assign physical pin (C[9]).
    M280 P{global.Machine_brush[12]} S{global.Machine_brush[10]}              ; Move the defined servo (P[11]) to the deployed angle (S[10]).

; Move to the centre of the brush
G1 X{global.Machine_brush[0]} Y{global.Machine_brush[1]} F{var.travel_speed}  ; Move the toolhead horizontally to the brush center coordinates.

;if global.Machine_brush[8] && global.Machine_brush[2] > 0
;    G1 Z{global.Machine_brush[2]} F{var.z_travel_speed}

; Brush in the Y direction if set
if global.Machine_brush[6]
    M98 P"0:/sys/AFC/Macros/debug.g" A"Machine_brush: Y Brush Moves"
    while iterations < global.Machine_brush[7]
        G1 Y{var.brush_y_min} F{global.Machine_brush[3]*60}
        G1 Y{var.brush_y_max} F{global.Machine_brush[3]*60}
        G1 Y{global.Machine_brush[1]} F{global.Machine_brush[3]*60}

; Brush in the X direction
M98 P"0:/sys/AFC/Macros/debug.g" A"Machine_brush: X Brush Moves"
while iterations < global.Machine_brush[7]
    G1 X{var.brush_x_min} F{global.Machine_brush[3]*60}
    G1 X{var.brush_x_max} F{global.Machine_brush[3]*60}
    G1 X{global.Machine_brush[0]} F{global.Machine_brush[3]*60}

M400                                                                          ; wait for moves to finish

; Move nozzle back to original X and Y to allow brush retraction
G1 X{var.currentx} Y{var.currenty} F{var.travel_speed}                        ; Return the toolhead to the saved starting X and Y position.

; Retract brush
if global.Machine_brush[8] && fileexists("0:/sys/AFC/Macros/brush_retract.g") ; Check if a custom retract macro exists.
    M98 P"0:/sys/AFC/Macros/brush_retract.g"                                  ; Execute the custom retraction macro.
elif global.Machine_brush[8]                                                  ; If no macro, use direct servo control.
    M280 P{global.Machine_brush[12]} S{global.Machine_brush[11]}              ; Move the servo (P[12]) to the retracted angle (S[11]).
    G4 P500                                                                   ; Pause for 500ms to allow the servo to move.
    M950 S{global.Machine_brush[12]} C"nil"                                   ; De-assign the servo pin to free the hardware resource.
if global.Machine_brush[15] && fileexists("0:/sys/AFC/Macros/brush_safe_retract.g")
    M98 P"0:/sys/AFC/Macros/brush_safe_retract.g" 