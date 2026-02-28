; --- Variable Initialization ---
; Convert Z travel speed from assumed mm/s to mm/min for G-Code command F parameter.
var z_travel_speed = global.Machine_travel_speed[1] * 60

; Accessed Unit 0's speed settings. Change [0] to a different unit index if needed.
var prime_speed = global.AFC_load_retract_speed[0][2] * 60

; --- Z-Axis Positioning Check ---
; global.Machine_brush[8] is likely a boolean flag: True if the brush mechanism is deployed by servo/motor.
; global.Machine_brush[2] is the target Z height for the brush operation.
if global.Machine_brush[8] && global.Machine_brush[2] > 0 && !global.Machine_brush[15]
    G1 Z{global.Machine_brush[2]} F{var.z_travel_speed}          ; Move Z to the brushing height at the calculated Z speed (mm/min).

M400                                                             ; Wait for the Z movement to complete before proceeding to the deployment/extrusion.

; --- Brush Deployment (Servo/Motor Control) ---
if global.Machine_brush[8] && !global.Machine_brush[15]          ; Check if the brush mechanism is enabled (e.g., using a servo).
                                                                 ; Used Machine_brush[12] for Servo Index and [9] for Pin
    M950 S{global.Machine_brush[12]} C{global.Machine_brush[9]}  ; Define the logical servo using the configured index and pin.
                                                                 ; [Used Machine_brush[12] for Servo Index and [10] for Deployed Angle
    M280 P{global.Machine_brush[12]} S{global.Machine_brush[10]} ; Move the defined servo to the deployed angle.
    G4 P500                                                      ; Add a small delay for the servo to finish moving
    M950 S{global.Machine_brush[12]} C"nil"                      ; De-assign the pin

; --- Final Filament Prime/Push ---
; This move is often used to ensure the filament tip is properly seated in the nozzle or to perform a small final purge.
; global.Machine_extruder_measurements[2] is the E-distance (Cutter to Nozzle).
; global.AFC_load_retract_speed[0][2] is the speed for this final E-move.
M83
G1 E{global.Machine_extruder_measurements[2]} F{var.prime_speed} ; Extrude the specified filament amount at the defined speed (mm/min).