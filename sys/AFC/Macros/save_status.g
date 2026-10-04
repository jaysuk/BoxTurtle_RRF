; param.A is used to identify tfree.g

var cU = 0
var cL = 0
var filename = "0:/sys/AFC/Status/status.g"

; One line per lane / unit. RRF 3.7 prints arrays as [..] with quoted strings, so no manual quoting is needed - but a string
; with a double quote inside would break the file (embedded quotes are not escaped), so the macros that accept text reject them.
echo >{var.filename} "; This records the status of each lane"
while iterations < #global.AFC_unit_CAN_ids
    set var.cU = iterations
    set var.cL = 0
    while var.cL < global.AFC_unit_total_lanes[var.cU]
        echo >>{var.filename} "set global.AFC_lanes["^var.cU^"]["^var.cL^"] = ", global.AFC_lanes[var.cU][var.cL]
        set var.cL = var.cL + 1
while iterations < #global.AFC_unit_CAN_ids
    echo >>{var.filename} "set global.AFC_LED_array["^iterations^"] = ", global.AFC_LED_array[iterations]
; Record which tool is loaded (-1 = none). The boot check (boot_check.g) asks the user what to do with it; nothing is
; reselected silently. While that check is still pending the value restored at boot is kept.
if !global.AFC_boot_check_pending
    if move.motionSystems[0].currentTool != -1 && !exists(param.A)
        set global.AFC_loaded_tool = move.motionSystems[0].currentTool
    else
        set global.AFC_loaded_tool = -1
echo >>{var.filename} "set global.AFC_loaded_tool = " ^ global.AFC_loaded_tool
; Tool -> lane map and infinite-spool backups: one line per tool / lane (each stays far below the 255 character line limit)
while iterations < #global.AFC_tool_map
    echo >>{var.filename} "set global.AFC_tool_map["^iterations^"] = ", global.AFC_tool_map[iterations]
while iterations < #global.AFC_unit_CAN_ids
    set var.cU = iterations
    while iterations < global.AFC_unit_total_lanes[var.cU]
        echo >>{var.filename} "set global.AFC_lane_backup["^var.cU^"]["^iterations^"] = "^global.AFC_lane_backup[var.cU][iterations]
; Filament colours ("#RRGGBB" strings written with doubled quotes so the file reads back as strings)
while iterations < #global.AFC_unit_CAN_ids
    set var.cU = iterations
    while iterations < global.AFC_unit_total_lanes[var.cU]
        echo >>{var.filename} "set global.AFC_lane_hex["^var.cU^"]["^iterations^"] = """^global.AFC_lane_hex[var.cU][iterations]^""""
; Hand off Spool ID persistence to its dedicated macro to prevent array flattening
M98 P"0:/sys/AFC/Macros/spool_save_status.g"