var unit_number = 0
var lane_number = 0

if exists(global.Macine_startup_check)
    if global.Machine_startup_check = false
        if global.Machine_features[7]
            M98 P"0:/sys/AFC/Macros/startup_check.g"
        set global.AFC_startup_check = true

    while iterations < #global.AFC_unit_CAN_ids
        set var.unit_number = itertions
        while iterations < global.AFC_unit_total_lanes[var.unit_number]
            set var.lane_number = iterations
            if global.AFC_lanes[var.unit_number][var.lane_number][4][0] != global.AFC_lanes[var.unit_number][var.lane_number][4][1]
                set global.AFC_lanes[var.unit_number][var.lane_number][4][1] = global.AFC_lanes[var.unit_number][var.lane_number][4][0]
    M98 P"0:/sys/AFC/Macros/save_status.g"