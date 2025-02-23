; param.A - This is the lane number

if !exists(param.A)
    echo "Missing the lane number"
    abort

var lane_number = {param.A}

M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}
M98 P"0:/sys/AFC/debug.g" A"Debug 1"

var total_axis = #move.axes

if global.AFC_lane_loaded[{var.lane_number}]=true   ; This checks to make sure there is filament loaded in the lane
    M98 P"0:/sys/AFC/debug.g" A"Debug 2"
    G92 's{global.AFC_lane_first_length[{var.lane_number}]}
    M98 P"0:/sys/AFC/debug.g" A"Debug 3"
    M400
    set global.AFC_LED_array[{var.lane_number}]=2   ; This sets the colour to blue so we know filament is being loaded
    M98 P"0:/sys/AFC/debug.g" A"Debug 4"
    M98 P"0:/sys/AFC/LEDs.g"                        ; This calls the LED script
    M98 P"0:/sys/AFC/debug.g" A"Debug 5"
    M584 P{var.total_axis}                          ; This unhides all the axes
    M98 P"0:/sys/AFC/debug.g" A"Debug 6"
    M574 's2 P{global.TN_switches[0]} S1            ; This sets the TN Advance pin as a homing switch for loading the filament
    M98 P"0:/sys/AFC/debug.g" A"Debug 7"
    G1 H4 's20000 F{global.AFC_load_speed}          ; This is an arbitory load distance to cover the length of the buffer tube
    M98 P"0:/sys/AFC/debug.g" A"Debug 8"
    M400                                            ; finish all moves
    G91                                             ; relative mode
    M98 P"0:/sys/AFC/debug.g" A"Debug 9"
    G4 P500
    G1 H2 's-15 F{global.AFC_retract_speed}         ; This retracts 15mm of filament to ensure the buffer is somewhere in the middle and not triggering either the trailing or advance switches
    M98 P"0:/sys/AFC/debug.g" A"Debug 10"
    M400                                            ; finish all moves
    G90                                             ; absolute mode
    M98 P"0:/sys/AFC/debug.g" A"Debug 11"
    G4 P500
    M574 's2 P"nil" S1                              ; free up the endstop pin for this axis
    M98 P"0:/sys/AFC/debug.g" A"Debug 12"
    G4 P500
    M400
    M584 P{var.total_axis-1}                        ; hide all the BT axes
    M98 P"0:/sys/AFC/debug.g" A"Debug 13"
    M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B1 ; setup the mixing extruder
    M98 P"0:/sys/AFC/debug.g" A"Debug 14"
else 
    M117 "No filament loaded in Lane "^{var.lane_number}
    abort