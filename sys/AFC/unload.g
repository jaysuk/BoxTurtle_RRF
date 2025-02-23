; param.A - This is the lane number
; param.B - This determines if the DC motors should run. B1 is no

if !exists(param.A)
    echo "Missing the lane number"
    abort

var lane_number=param.A
var first_length=global.AFC_lane_first_length[var.lane_number]
var unload_length=0

if exists(param.B)
    var DC_motors=param.B
else
    var DC_motors=0

set var.unload_length=var.first_length+50

M584 P{#move.axes}

M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}

var total_axis=#move.axes

if {global.AFC_lane_loaded[var.lane_number]}=true
    M950 J{global.AFC_unload_input_number} C{global.AFC_load_switch[var.lane_number]}
    G92 's{var.first_length}
    if var.DC_motors=1
        M98 P"0:/sys/AFC/Motors/dc_motors.g" A"R" B{var.lane_number}
        M400 
    G1 's{-var.unload_length} F{global.AFC_retract_speed}
    M400
    if var.DC_motors=1
        M98 P"0:/sys/AFC/Motors/dc_motors.g" A"O" B{var.lane_number}
        M400
    if sensors.gpIn[global.AFC_unload_input_number].value=0
        set global.AFC_lane_loaded[{var.lane_number}]=false
        echo >"0:/sys/AFC/AFC-info/lane_status.g" "; lane status"
        echo >>"0:/sys/AFC/AFC-info/lane_status.g" "set global.AFC_lane_loaded = " ^ global.AFC_lane_loaded
        M400
        set global.AFC_LED_array[var.lane_number]=0
        M98 P"0:/sys/AFC/LEDs.g"

    M950 J{global.AFC_unload_input_number} C"nil"
    M584 P{var.total_axis-1}
else
    M117 "No Filament Loaded to Unload"