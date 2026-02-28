; === AFC Brush Deploy Macro (RepRapFirmware G-Code) ===

; --- Variable Initialization ---
; Calculate the travel speed in mm/minute (G-Code standard unit), based on a global speed setting (which is likely in mm/second).
var travel_speed = global.Machine_travel_speed[0] * 60

G1 X115 Y200 F6000
; --- Deployment Move ---
; G1: Linear movement command.
; U: Specifies the movement along the temporary/auxiliary U-axis. This axis is typically reserved for specialized tool movements like a brush, wiper, or tool dock.
; F: Specifies the feedrate (speed in mm/min).
G1 U59.5 F{var.travel_speed} ; Move the U-axis (likely the brush head) to the absolute position 59.5 mm at the calculated travel speed.