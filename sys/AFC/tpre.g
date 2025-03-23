; param.A - This is the lane number

if !exists(param.A)
    echo "Missing the lane number"
    abort

set global.AFC_time=state.upTime

var lane_number = {param.A}
var warning_text = "No filament loaded in Lane "^{var.lane_number}

M568 P{var.lane_number} A2

M950 J{global.AFC_hub_input_number} C{global.AFC_hub_switch}
if sensors.gpIn[global.AFC_hub_input_number].value !=0
    M291 S2 P"There is filament loaded to the printer through the hub, aborting macro" R"Warning"
    M950 J{global.AFC_hub_input_number} C"nil"
    T-1 P0
    abort

M950 J{global.AFC_hub_input_number} C"nil"

if global.AFC_extruder_temp[{var.lane_number}] != 0
    M568 P{var.lane_number} S{global.AFC_extruder_temp[{var.lane_number}]} R{global.AFC_extruder_temp[{var.lane_number}]}
else
    M568 P{var.lane_number} S220 R220                                                        ; Enable the hotend to this temperature

M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}

var total_axis = #move.axes

if global.AFC_lane_loaded[{var.lane_number}] && !global.AFC_features[6]   ; This checks to make sure there is filament loaded in the lane and checks for the feature settings
    G92 'f{global.AFC_lane_first_length[{var.lane_number}]}
    M400
    set global.AFC_LED_array[{var.lane_number}]=2                   ; This sets the colour to blue so we know filament is being loaded
    M584 P{var.total_axis}                                          ; This unhides all the axes
    M574 'f2 P{global.TN_switches[0]} S1                            ; This sets the TN Advance pin as a homing switch for loading the filament
    G1 H4 'f20000 F{global.AFC_load_retract_speed[0]*60}                          ; This is an arbitory load distance to cover the length of the buffer tube
    M400                                                            ; finish all moves
    G91                                                             ; relative mode
    G4 P500
    G1 H2 'f{-global.AFC_tn_retract_distance} F{global.AFC_load_retract_speed[1]*60}                         ; This retracts 15mm of filament to ensure the buffer is somewhere in the middle and not triggering either the trailing or advance switches
    M400                                                            ; finish all moves
    G90                                                             ; absolute mode
    G4 P500
    M574 'f2 P"nil" S1                                              ; free up the endstop pin for this axis
    G4 P500
    M400
    M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B1 ; setup the mixing extruder
    M400
    M584 P{var.total_axis-1}                                        ; hide all the BT axes
elif global.AFC_lane_loaded[{var.lane_number}] && global.AFC_features[6]   ; This checks to make sure there is filament loaded in the lane and checks for the feature settings
    G92 'f{global.AFC_lane_first_length[{var.lane_number}]}
    M400
    set global.AFC_LED_array[{var.lane_number}]=2                   ; This sets the colour to blue so we know filament is being loaded
    M584 P{var.total_axis}                                          ; This unhides all the axes
    G1 'f{(global.AFC_lane_total_length[var.lane_number])} F{global.AFC_load_retract_speed[0]*60}                          ; This is an arbitory load distance to cover the length of the buffer tube
    M400                                                            ; finish all moves
    M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B1 ; setup the mixing extruder
    M400
    M584 P{var.total_axis-1}                                        ; hide all the BT axes
else 
    M291 S2 P{var.warning_text} R"Warning"
    T-1 P0
    abort