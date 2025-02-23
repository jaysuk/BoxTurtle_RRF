; param.A - This is the lane number
; param.B - CAN address of board hosting the filament monitor
; param.D - Extruder #
; param.P - Filament error type code

M226 ; Pause the print

if !exists(param.A)
    echo "Missing the lane number"
    abort

var lane_number = param.A
var choice=0
var choice_lane=0

M98 P"0:/sys/AFC/tfree.g" A{var.lane_number] B1

M98 P"0:/sys/AFC/unload.g" A{var.lane_number] B1

if global.AFC_lane_continuous[var.lane_number]
    while iterations < global.AFC_number_of_lanes
        if iterations != var.lane.number
            if global.AFC_lane_continuous[iterations]
                M98 P"0:/sys/AFC/tpre.g" A{iterations}
                M98 P"0:/sys/AFC/tpost.g" A{iterations} B1
                set global.AFC_lane_continuous[var.lane_number] = false
                M24

M291 P"Select the option below" S4 J1 K{"Reload Lane "^{var.lane_number},"Continue with a different Lane"}
set var.choice=input

if var.choice == 0
    M291 R"Lane "^{var.lane_number}^" Filament Runout" P"Reload filament into lane "^{var.lane_number}^" and click ok" S2
    if global.AFC_lane_loaded[var.lane_number]
        M98 P"0:/sys/AFC/tpre.g" A{var.lane_number}
        M98 P"0:/sys/AFC/tpost.g" A{var.lane_number} B1
        M24

if var.choice == 1
    M291 P"Select the lane to be used" K{"Lane 0","Lane 1","Lane 2","Lane 3"} S4 J1
    set var.choice_lane=input
    if global.AFC_lane_loaded[var.choice_lane]
        M98 P"0:/sys/AFC/tpre.g" A{var.choice_lane}
        M98 P"0:/sys/AFC/tpost.g" A{var.choice_lane} B1
        M24
    else
        M291 P"Select a different lane to be used" K{"Lane 0","Lane 1","Lane 2","Lane 3"} S4 J1
        set var.choice_lane=input
        if global.AFC_lane_loaded[var.choice_lane]
            M98 P"0:/sys/AFC/tpre.g" A{var.choice_lane}
            M98 P"0:/sys/AFC/tpost.g" A{var.choice_lane} B1
            M24
