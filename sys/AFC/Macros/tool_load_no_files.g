if !exists(param.A)                                                                                                                                     ; This just checks if the lane number has been provided.
    M118 S"Missing the lane number"                                                                                                                     ; Echo error message
    M99

var tool_number = param.A                                                                                                                             ; The Tool ID (Lane ID system-wide)
var unit_number = global.AFC_tool_map[var.tool_number][0]                                                                                                ; Get Unit ID
var lane_number = global.AFC_tool_map[var.tool_number][1]                                                                                                ; Get Local Lane ID
var lane_tool = global.AFC_lane_to_tool[var.unit_number][var.lane_number]                                   ; Native tool number of the lane

M98 P"0:/sys/AFC/Macros/axis_setup.g" A{var.lane_tool}                                                                                                ; Map the lane motor to an axis
M400
M98 P"0:/sys/AFC/Macros/extruder_setup.g" A{var.tool_number} B1                                                      ; Execute a macro to configure the physical extruder/toolhead for the current lane. (B1 likely indicates 'mixing' or 'enabled').
M400
set global.AFC_LED_array[var.unit_number][var.lane_number]=2                                                                               ; Set LED status to Blue (Busy/Active).