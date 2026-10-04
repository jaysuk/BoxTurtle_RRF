; === AFC Load Method 2: preload (extruder input) switch ===
; param.A = tool number
; Called by tpre.g between lane_motion_begin.g and lane_motion_end.g ('f is visible and mapped to the lane).

if !exists(param.A)
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"load_with_preload.g: missing the tool number (A)" Q1
    set global.Machine_tpre_failed = true
    M99

var tool_number = param.A
var unit_number = global.AFC_tool_map[var.tool_number][0]
var lane_number = global.AFC_tool_map[var.tool_number][1]
var lane_tool = global.AFC_lane_to_tool[var.unit_number][var.lane_number]                  ; native tool number of that lane (lane identity for the lane helpers and afc_error)
var search_distance = global.AFC_max_min_axes[var.unit_number][1]                ; fallback when the lane has not been measured

if global.Machine_extruder_switches[0] == "nil"
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"Load method 2 needs Machine_extruder_switches[0] (the extruder input switch)" T{var.lane_tool} Q1
    set global.Machine_tpre_failed = true
    M99

if global.AFC_lanes[var.unit_number][var.lane_number][2] > 0
    set var.search_distance = global.AFC_lanes[var.unit_number][var.lane_number][2] + 100   ; expected length + margin

; --- Filament Loading to Sensor ---
; 'f2 = max endstop; the extruder input switch stops the search move.
M574 'f2 P{global.Machine_extruder_switches[0]} S1
M400
G4 S1
G1 H4 'f{var.search_distance} F{global.AFC_load_retract_speed[var.unit_number][0] * 60}
M400
if !sensors.endstops[global.AFC_f_axis].triggered
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"The extruder input switch was not reached by Unit "^var.unit_number^" Lane "^var.lane_number^" within "^var.search_distance^"mm"} T{var.lane_tool} Q1
    set global.Machine_tpre_failed = true
    M99

; --- Endstop Cleanup and Tool Activation ---
M574 'f2 P"nil" S1                                                                ; free the switch pin
G4 P500
M400
M98 P"0:/sys/AFC/Macros/extruder_setup.g" A{var.tool_number} B1
M400
