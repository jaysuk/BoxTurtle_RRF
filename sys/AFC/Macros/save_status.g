var v0 = false
var v1 = 0
var v2 = 0
var v3 = 0
var v4 = ""
var v5 = ""
var cU = 0
var cL = 0
var string = ""

echo >"0:/sys/AFC/Status/status.g" "; This records the status of each lane"                                                                                                 ; Overwrite/start the lane status file.
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
        echo >>"0:/sys/AFC/Status/status.g" "set global.AFC_lanes["^var.cU^"]["^var.cL^ "] = {"^var.v0^","^var.v1^","^var.v2^","^var.v3^",{"""^var.v4^""","""^var.v5^"""}}" ; Save the updated loaded status array to the file.
        set var.cL = var.cL + 1
if #global.AFC_unit_CAN_ids == 1
    echo >>"0:/sys/AFC/Status/status.g" "set global.AFC_LED_array[0] = " ^ global.AFC_LED_array[0]
else
    echo >>"0:/sys/AFC/Status/status.g" "set global.AFC_LED_array = " ^ global.AFC_LED_array
echo >>"0:/sys/AFC/Status/status.g" "set global.spoolman = " ^ global.spoolman