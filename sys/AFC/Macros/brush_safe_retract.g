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

; Check Z-Height Safety and Move Z
; Check if Z minimum height is required (global.Machine_brush[13]) AND if the target Z is higher than the current Z.
if global.Machine_brush[15] && (global.Machine_brush[18] > var.currentz)
    G1 Z{global.Machine_brush[2]} F{var.z_travel_speed}                       ; Move Z axis up to the required Z position before horizontal travel.

; Move to the centre of the brush
G1 X{global.Machine_brush[16]} Y{global.Machine_brush[17]} F{var.travel_speed}  ; Move the toolhead horizontally to the brush center coordinates.
; --- Deployment Move ---
; G1: Linear movement command.
; U: Specifies the movement along the temporary/auxiliary U-axis. This axis is typically reserved for specialized tool movements like a brush, wiper, or tool dock.
; F: Specifies the feedrate (speed in mm/min).
G1 U1 F{var.travel_speed} ; Move the U-axis (likely the brush head) to the absolute position 59.5 mm at the calculated travel speed.