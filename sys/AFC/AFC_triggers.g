; param.A - This is the lane number

if !exists(param.A) ; Do a check of whether the lane number has been passed
    echo "Missing the lane number"
    abort

var lane_number=param.A

M584 P{#move.axes}

M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}

var total_axis=#move.axes

M574 's1 P{global.AFC_load_switch[var.lane_number]} S1 
M98 P"0:/sys/AFC/debug.g" A"Debug 1"
G92 's0
M98 P"0:/sys/AFC/debug.g" A"Debug 2"
G28 's0
M98 P"0:/sys/AFC/debug.g" A"Debug 3"
if move.axes[{global.om_axis_number}].homed
    M98 P"0:/sys/AFC/debug.g" A"Debug 4"
    set global.AFC_lane_loaded[{var.lane_number}]=true
    M98 P"0:/sys/AFC/debug.g" A"Debug 5"
    echo >"0:/sys/AFC/AFC-info/lane_status.g" "; lane status"
    M98 P"0:/sys/AFC/debug.g" A"Debug 6"
    echo >>"0:/sys/AFC/AFC-info/lane_status.g" "set global.AFC_lane_loaded = " ^ global.AFC_lane_loaded
    M98 P"0:/sys/AFC/debug.g" A"Debug 7"
    if fileexists("0:/sys/AFC/AFC-info/lane_first_length.g")
        M98 P"0:/sys/AFC/debug.g" A"Debug 8"
        if global.AFC_lane_first_length[{var.lane_number}] !==0
            G1 's{global.AFC_lane_first_length[{var.lane_number}]} F{global.AFC_load_speed}
        M98 P"0:/sys/AFC/debug.g" A"Debug 9"
        M400
    set global.AFC_LED_array[{var.lane_number}]=1
    M98 P"0:/sys/AFC/debug.g" A"Debug 10"
    M98 P"0:/sys/AFC/LEDs.g"
    M98 P"0:/sys/AFC/debug.g" A"Debug 11"
M400
M574 's1 P"nil" S1
M400
M98 P"0:/sys/AFC/debug.g" A"Debug 12"
M584 P{var.total_axis-1}
M98 P"0:/sys/AFC/debug.g" A"Debug 13"