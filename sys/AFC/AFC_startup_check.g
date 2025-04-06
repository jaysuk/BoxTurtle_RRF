var hub_empty = false
var lane_number = 0
var lane_in_extruder = false
var home_safe = false
var total_axis = #move.axes

M950 J{global.AFC_hub_input_number} C{global.AFC_hub_switch}
M400
if sensors.gpIn[global.AFC_hub_input_number].value = 0
    set var.hub_empty = true

M950 J{global.AFC_hub_input_number} C"nil"
M400

if !var.hub_empty
    M291 P"One of the lanes is loaded. Please select which one so it can be unloaded" K{"Lane 0","Lane 1","Lane 2","Lane 3"} S4 J1                               ; Popup box with options for the lane to unload
    set var.lane_number=input

    M291 P{"Is Lane "^var.lane_number^" loaded into the extruder?"} K{"Yes","No"} S4 J1
    if input == 0
        set var.lane_in_extruder = true

    if var.lane_in_extruder
        M291 P{"Is it safe to home the printer?"} K{"Yes","No"} S4 J1
        if input == 0
            set var.home_safe = true
        if var.home_safe
            G28
            M568 P{var.lane_number} S220 A2
            if global.AFC_features[8]
                M98 P"0:/sys/AFC/tfree.g" A{var.lane_number} B1
            else
                M98 P"0:/sys/AFC/tfree.g" A{var.lane_number} B0
            M400
            M568 P{var.lane_number} A0
        elif !var.home_safe
            M568 P{var.lane_number} S220 A2
            if global.AFC_features[8]
                M98 P"0:/sys/AFC/tfree.g" A{var.lane_number} B1 C1
            else
                M98 P"0:/sys/AFC/tfree.g" A{var.lane_number} B0 C1
            M400
            M568 P{var.lane_number} A0

    if !var.lane_in_extruder
        M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}
        M400
        M98 P"0:/sys/AFC/Motors/dc_motors.g" A"R" B{var.lane_number}                       ; This sets the DC motor in reverse to wind the filament up
        M400
        M574 'f1 P{"!"^global.AFC_hub_switch} S1 
        G92 'f20000
        G1 H4 'f-20000 F{global.AFC_load_retract_speed[1]*60} ; This retracts the filament
        G91
        G1 'f{-global.AFC_hub_retract_distance} F{global.AFC_load_retract_speed[1]*60}
        G90
        M574 'f1 P"nil" S1
        M400
        M98 P"0:/sys/AFC/Motors/dc_motors.g" A"O" B{var.lane_number}                       ; This turns the DC motor off
        M400                                                                                                           ; This waits for all movement to stop
        ; This sets the LED colour back to green
        set global.AFC_LED_array[{var.lane_number}]=1

        ; This hides the axes again
        M584 P{var.total_axis-1}

        M400

if !var.hub_empty
    M950 J{global.AFC_hub_input_number} C{global.AFC_hub_switch}
    M400
    if sensors.gpIn[global.AFC_hub_input_number].value = 0
        set var.hub_empty = true

    M950 J{global.AFC_hub_input_number} C"nil"
    M400

if var.hub_empty
    while iterations < global.AFC_number_of_lanes
        if global.AFC_lane_loaded[iterations]
            M574 'f2 S1 P{global.AFC_hub_switch}       
            M400                                                                           ; This sets the hub switch up as an endstop
            M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{iterations}
            M400
            G92 'f0
            M400
            G1 H4 'f{global.AFC_lane_first_length[iterations]} F{global.AFC_load_retract_speed[0]*60}                                                                                  ; This moves to the hub switch and measures the distance moved
            if move.axes[{global.om_axis_number}].machinePosition < global.AFC_lane_first_length[iterations]
                G91                                                                                                                   ; This sets the system into relative mode
                G1 'f{-global.AFC_hub_retract_distance+10} F{global.AFC_load_retract_speed[1]*60}                                                   ; This retracts the filament by a set amount so its no longer in the hub
                G90                                                                                                                   ; This sets the system into absolute mode
            else
                M98 P"0:/macros/Lane - Mark Unloaded" A{iterations}
            M574 'f1 P"nil" S1
            M400   
            ; This hides the axes again
            M584 P{var.total_axis-1}

