; tool_map_swap.g - make RRF tool A draw from the lane whose native tool number is B (P3-03)
; param.A RRF tool whose lane changes
; param.B native tool number of the target lane (Tool_to_AFC identity, i.e. the lane's own tool number)
; The tool that currently uses the target lane gets tool A's old lane (a swap), so the map stays a permutation.
; Both lanes must serve the same printer head. Neither tool may be the current tool. Failures call afc_error.g.
; Saves the status file.

if !exists(param.A) || !exists(param.B)
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"tool_map_swap.g needs A (tool) and B (lane tool)"
    M99
if param.A < 0 || param.A >= #global.AFC_tool_map || param.B < 0 || param.B >= #global.Tool_to_AFC
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"tool_map_swap.g: tool number out of range"
    M99

var other = -1                                                                  ; the tool that currently uses the target lane
var cur = move.motionSystems[0].currentTool
var target_u = global.Tool_to_AFC[param.B][0]
var target_l = global.Tool_to_AFC[param.B][1]
var old_u = global.AFC_tool_map[param.A][0]
var old_l = global.AFC_tool_map[param.A][1]

; Same printer head (tool_and_motion[u][0]) for the tool's own unit and the target lane's unit
if global.tool_and_motion[global.Tool_to_AFC[param.A][0]][0] != global.tool_and_motion[var.target_u][0]
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"Tool "^param.A^" cannot use Unit "^var.target_u^" Lane "^var.target_l^": that unit feeds a different printer head"}
    M99

while iterations < #global.AFC_tool_map
    if global.AFC_tool_map[iterations][0] == var.target_u && global.AFC_tool_map[iterations][1] == var.target_l
        set var.other = iterations

if var.other == param.A                                                         ; already mapped
    M99
if var.cur == param.A || (var.other >= 0 && var.cur == var.other)
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"A tool that is loaded in the toolhead cannot be remapped. Select T-1 first"
    M99

if var.other >= 0
    set global.AFC_tool_map[var.other] = [var.old_u, var.old_l]
set global.AFC_tool_map[param.A] = [var.target_u, var.target_l]
M98 P"0:/sys/AFC/Macros/save_status.g"
