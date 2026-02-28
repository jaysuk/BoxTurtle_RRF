; ==========================================================================================
; spool_save_status.g
; Automatically serializes the Spool ID assignments per lane.
; This separates Spool tracking from the main status.g to prevent array flattening bugs.
; ==========================================================================================

var unit_idx = 0
var lane_idx = 0
var current_id = 0

echo >"0:/sys/AFC/Status/spool_status.g" "; Automatically generated spool assignments"

while var.unit_idx < #global.AFC_unit_CAN_ids
    set var.lane_idx = 0
    while var.lane_idx < global.AFC_unit_total_lanes[var.unit_idx]
        set var.current_id = global.spoolman[var.unit_idx][var.lane_idx][0]
        
        ; Write complete inner array assignment rather than deep indexing
        ; e.g., set global.spoolman[0][0] = {42, false}
        echo >>"0:/sys/AFC/Status/spool_status.g" "set global.spoolman[" ^ var.unit_idx ^ "][" ^ var.lane_idx ^ "] = {" ^ var.current_id ^ ", " ^ global.spoolman[var.unit_idx][var.lane_idx][1] ^ "}"
        
        set var.lane_idx = var.lane_idx + 1
    
    set var.unit_idx = var.unit_idx + 1
