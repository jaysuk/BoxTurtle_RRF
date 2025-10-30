; param.A - This is the lane number

; AFC Feature Numbers
; 0 = brush
; 1 = cut
; 2 = kick
; 3 = park
; 4 = poop
; 5 = purge
; 6 = load
; 7 = startup check
; 8 = use the dc motor on unload
; 9 = unload method
; 10 = spoolman support

if !exists(param.A) ; Do a check of whether the lane number has been passed
    echo "Missing the lane number"
    abort

var lane_number=param.A

M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}

var total_axis=#move.axes

M574 'f1 P{global.AFC_load_switch[var.lane_number]} S1 
G92 'f0
if !sensors.endstops[{global.om_axis_number}].triggered
    G28 'f0
    if sensors.endstops[{global.om_axis_number}].triggered ;move.axes[{global.om_axis_number}].homed
        set global.AFC_lane_loaded[{var.lane_number}]=true
        echo >"0:/sys/AFC/AFC-info/lane_status.g" "; lane status"
        echo >>"0:/sys/AFC/AFC-info/lane_status.g" "set global.AFC_lane_loaded = " ^ global.AFC_lane_loaded
        if fileexists("0:/sys/AFC/AFC-info/lane_first_length.g")
            if global.AFC_lane_first_length[{var.lane_number}] !==0
                G1 'f{global.AFC_lane_first_length[{var.lane_number}]} F{global.AFC_load_retract_speed[0]*60}
            M400
        set global.AFC_LED_array[{var.lane_number}]=1
        M98 P"0:/sys/AFC/LEDs.g"
M400
M574 'f1 P"nil" S1
M400
M84 'f
M584 P{var.total_axis-1}