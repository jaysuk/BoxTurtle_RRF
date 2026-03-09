; param.A is used to identify tfree.g

var v0 = false
var v1 = 0
var v2 = 0
var v3 = 0
var v4 = ""
var v5 = ""
var cU = 0
var cL = 0
var string = ""
var filename = "0:/sys/AFC/Status/status.g"
var unit_number = 0
var lane_number = 0

echo >{var.filename} "; This records the status of each lane"                                                                                                 ; Overwrite/start the lane status file.
while iterations < #global.AFC_unit_CAN_ids
    set var.cU = iterations
    set var.cL = 0
    while var.cL <  global.AFC_unit_total_lanes[var.cU]
        set var.v0 = global.AFC_lanes[var.cU][var.cL][0]
        set var.v1 = global.AFC_lanes[var.cU][var.cL][1]
        set var.v2 = global.AFC_lanes[var.cU][var.cL][2]
        set var.v3 = global.AFC_lanes[var.cU][var.cL][3]
        set var.v4 = global.AFC_lanes[var.cU][var.cL][4][0]
        set var.v5 = global.AFC_lanes[var.cU][var.cL][4][1]
        echo >>{var.filename} "set global.AFC_lanes["^var.cU^"]["^var.cL^ "] = {"^var.v0^","^var.v1^","^var.v2^","^var.v3^",{"""^var.v4^""","""^var.v5^"""}}" ; Save the updated loaded status array to the file.
        set var.cL = var.cL + 1
if #global.AFC_unit_CAN_ids == 1
    echo >>{var.filename} "set global.AFC_LED_array[0] = " ^ global.AFC_LED_array[0]
else
    echo >>{var.filename} "set global.AFC_LED_array = " ^ global.AFC_LED_array
; Hand off Spool ID persistence to its dedicated macro to prevent array flattening
if state.currentTool != -1 && !exists(param.A)
    echo >>{var.filename} "T" ^state.currentTool^" P0"
    echo >>{var.filename} "M98 P""0:/sys/AFC/Macros/tool_load_no_files.g"" A"^state.currentTool
M98 P"0:/sys/AFC/Macros/spool_save_status.g"