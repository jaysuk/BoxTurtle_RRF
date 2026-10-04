; set_temp_global.g - store the slicer's temperature for a tool (called from the slicer's change-filament G-code)
; param.A tool number
; param.B temperature
; param.C purge length in mm from the slicer for this tool change (optional); poop.g applies Machine_purge_length_modifier/_addition
if !exists(param.A) || !exists(param.B)
    M118 S"set_temp_global.g needs A (tool) and B (temperature)"
    M99
if param.A < 0 || param.A >= #global.AFC_tool_map
    M118 S{"set_temp_global.g: tool "^param.A^" is not an AFC tool"}
    M99
set global.AFC_extruder_temp[global.AFC_tool_map[param.A][0]][global.AFC_tool_map[param.A][1]] = param.B
if exists(param.C)
    set global.Machine_slicer_purge = param.C
