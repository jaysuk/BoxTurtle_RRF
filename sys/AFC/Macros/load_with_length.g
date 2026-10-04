; === AFC Load Method 1: Measured Lengths ===
; param.A = tool number
; Called by tpre.g between lane_motion_begin.g and lane_motion_end.g ('f is visible and mapped to the lane).

if !exists(param.A)
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"load_with_length.g: missing the tool number (A)" Q1
    set global.Machine_tpre_failed = true
    M99

var tool_number = param.A
var unit_number = global.AFC_tool_map[var.tool_number][0]
var lane_number = global.AFC_tool_map[var.tool_number][1]
var lane_tool = global.AFC_lane_to_tool[var.unit_number][var.lane_number]                  ; native tool number of that lane (lane identity for the lane helpers and afc_error)

if global.AFC_lanes[var.unit_number][var.lane_number][2] <= 0
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"Unit "^var.unit_number^" Lane "^var.lane_number^" has no measured total length. Run Lane - Measure Main Length"} T{var.lane_tool} Q1
    set global.Machine_tpre_failed = true
    M99

; --- Final Filament Loading Move ---
; 'f is an axis in the same frame as the stored lengths: feed to the total length (index [2]) in one absolute move.
G1 'f{global.AFC_lanes[var.unit_number][var.lane_number][2]} F{global.AFC_load_retract_speed[var.unit_number][0]*60}
M400

; --- Extruder Setup ---
; B1 = map the lane driver to the AFC extruder and set the mix to 1:1
M98 P"0:/sys/AFC/Macros/extruder_setup.g" A{var.tool_number} B1
M400
