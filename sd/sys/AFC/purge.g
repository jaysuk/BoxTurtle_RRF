; --- Variable Initialization ---
; Convert Z travel speed from assumed mm/s to mm/min for G-Code command F parameter.
var z_travel_speed = global.AFC_travel_speed[1] * 60
var prime_speed = global.AFC_load_retract_speed[2] * 60

; --- Z-Axis Positioning Check ---
; global.AFC_brush[8] is likely a boolean flag: True if the brush mechanism is deployed by servo/motor.
; global.AFC_brush[2] is the target Z height for the brush operation.
if global.AFC_brush[8] && global.AFC_brush[2] > 0
    G1 Z{global.AFC_brush[2]} F{var.z_travel_speed}           ; Move Z to the brushing height at the calculated Z speed (mm/min).

M400                                                          ; Wait for the Z movement to complete before proceeding to the deployment/extrusion.

; --- Brush Deployment (Servo/Motor Control) ---
if global.AFC_brush[8]                                        ; Check if the brush mechanism is enabled (e.g., using a servo).
    M950 S10 C{global.AFC_brush[9]}                           ; Define a new logical servo (S10) using the pin specified in global.AFC_brush[9].
    M280 P10 S{global.AFC_brush[10]}                          ; Move the defined servo (P10) to the deployed angle specified in global.AFC_brush[10].
    G4 P500                                                   ; Add a small delay for the servo to finish moving
    M950 S10 C"nil"                                           ; De-assign the pin

; --- Final Filament Prime/Push ---
; This move is often used to ensure the filament tip is properly seated in the nozzle or to perform a small final purge.
; global.main_extruder_measurements[2] is the E-distance to move.
; global.AFC_load_retract_speed[2] is the speed for this final E-move.
G1 E{global.main_extruder_measurements[2]} F{var.prime_speed} ; Extrude the specified filament amount at the defined speed (mm/min).