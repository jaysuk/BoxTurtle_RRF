; === AFC Brush Retract Macro (RepRapFirmware G-Code) ===

; --- Variable Initialization ---
; Calculate the travel speed in mm/minute (G-Code standard unit).
; The global speed setting (global.AFC_travel_speed[0]) is assumed to be in mm/second, hence the multiplication by 60.
var travel_speed = global.Machine_travel_speed[0] * 60

; --- Retraction Move ---
; G1: Linear movement command.
; U: Specifies the movement along the temporary/auxiliary U-axis (often used for non-primary axes like tool wipers or brushes).
; F: Specifies the feedrate (speed in mm/min).
G1 U1 F{var.travel_speed} ; Move the U-axis (likely the brush head) to the **absolute zero position (U0)** at the calculated travel speed. This action retracts or parks the brush away from the tool path.