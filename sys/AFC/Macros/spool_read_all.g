; ==========================================================================================
; Spool - Read All (spool_read_all.g)
; Iterates through global.spoolman on system startup and loads the active spool files
; into global.spool_active_data to restore tracking state across reboots.
; ==========================================================================================

var unit_idx = 0
var lane_idx = 0
var current_id = 0
var spool_file = ""

; Iterate through all units
while var.unit_idx < #global.AFC_unit_CAN_ids
    set var.lane_idx = 0
    
    ; Iterate through all lanes in the unit
    while var.lane_idx < global.AFC_unit_total_lanes[var.unit_idx]
        
        ; Check if this lane has a Spool assigned in the persistence stub
        set var.current_id = global.spoolman[var.unit_idx][var.lane_idx][0]
        
        if var.current_id != -1
            set var.spool_file = "0:/spools/" ^ var.current_id ^ ".g"
            
            ; Verify the file actually exists
            if fileexists(var.spool_file)
                ; Load it into temp RAM
                M98 P{var.spool_file}
                
                ; Copy from temp to active_data slot
                set global.spool_active_data[var.unit_idx][var.lane_idx][0] = global.spool_load_temp[0]
                set global.spool_active_data[var.unit_idx][var.lane_idx][1] = global.spool_load_temp[1]
                set global.spool_active_data[var.unit_idx][var.lane_idx][2] = global.spool_load_temp[2]
                set global.spool_active_data[var.unit_idx][var.lane_idx][3] = global.spool_load_temp[3]
                set global.spool_active_data[var.unit_idx][var.lane_idx][4] = global.spool_load_temp[4]
                set global.spool_active_data[var.unit_idx][var.lane_idx][5] = global.spool_load_temp[5]
                set global.spool_active_data[var.unit_idx][var.lane_idx][6] = global.spool_load_temp[6]
                set global.spool_active_data[var.unit_idx][var.lane_idx][7] = global.spool_load_temp[7]
                set global.spool_active_data[var.unit_idx][var.lane_idx][8] = global.spool_load_temp[8]
                set global.spool_active_data[var.unit_idx][var.lane_idx][9] = global.spool_load_temp[9]
                set global.spool_active_data[var.unit_idx][var.lane_idx][10] = global.spool_load_temp[10]
                set global.spool_active_data[var.unit_idx][var.lane_idx][11] = global.spool_load_temp[11]
                ; Sync standard AFC properties
                set global.AFC_lanes[var.unit_idx][var.lane_idx][4] = {global.spool_active_data[var.unit_idx][var.lane_idx][1], global.spool_active_data[var.unit_idx][var.lane_idx][2]}
        
        set var.lane_idx = var.lane_idx + 1
        
    set var.unit_idx = var.unit_idx + 1

; Clear the temporary load variable
set global.spool_load_temp = {-1, "", "", "", 0.0, 0.0, "", "", "", 0.0, 0.0, 1.24}
