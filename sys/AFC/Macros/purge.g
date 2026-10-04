; === AFC Purge Macro ===
; Purpose: final prime/push of the filament tip at the current position (after park / poop).
; param.A - 1 = the toolhead is over a safe place (park or poop ran for this tool change). Without it nothing is extruded.
; param.B - tool number (its unit's prime speed is used)

if !exists(param.A) || param.A != 1
    M118 S"AFC purge: enable park or poop so the toolhead is over a safe place - purge skipped"
    M99

var unit_number = 0
if exists(param.B) && param.B >= 0 && param.B < #global.AFC_tool_map
    set var.unit_number = global.AFC_tool_map[param.B][0]

; Prime speed (mm/min) of the unit being loaded (AFC_load_retract_speed[u][2] is the extruder-limited speed, mm/s)
var prime_speed = global.AFC_load_retract_speed[var.unit_number][2] * 60

; --- Final Filament Prime/Push ---
; Ensures the filament tip is properly seated in the nozzle.
; global.Machine_extruder_measurements[2] is the E-distance (Cutter to Nozzle).
M83
G1 E{global.Machine_extruder_measurements[2]} F{var.prime_speed}
