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

if !exists(param.A)                                                                                                       ; This just checks if the lane number has been provided.
    echo "Missing the lane number"
    abort

set global.AFC_time=state.upTime                                                                                          ; This is to record the time at the start of the tool load process

var lane_number = {param.A}                                                                                               ; sets up the lane_number variable
var warning_text = "No filament loaded in Lane "^{var.lane_number}                                                        ; sets up the warning text to be used
var lane_load_retry = 5                                                                                                   ; sets up the number of retries allowed to load the hub
var hub_loaded = false                                                                                                    ; initiates a variable with a value of false

if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed                                                      ; checks if the printer is homed
	G28                                                                                                                   ; home the printer

M568 P{var.lane_number} A2                                                                                                ; sets the hotend to on

M950 J{global.AFC_hub_input_number} C{global.AFC_hub_switch}                                                              ; sets up the hub switch
if sensors.gpIn[global.AFC_hub_input_number].value !=0                                                                    ; checks there is nothing loaded in the hub already
    M291 S2 P"There is filament loaded to the printer through the hub, aborting macro" R"Warning"
    M950 J{global.AFC_hub_input_number} C"nil"
    T-1 P0
    abort

M950 J{global.AFC_hub_input_number} C"nil"                                                                                ; turns the hub switch off

if global.AFC_extruder_temp[{var.lane_number}] != 0
    M568 P{var.lane_number} S{global.AFC_extruder_temp[{var.lane_number}]} R{global.AFC_extruder_temp[{var.lane_number}]}
else
    M568 P{var.lane_number} S220 R220                                                        ; Enable the hotend to this temperature

M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}

var total_axis = #move.axes

G92 'f{global.AFC_lane_first_length[{var.lane_number}]}                                                                   ; sets the position of the 'f axis
M400                                                                                                                      ; this is just a pause
set global.AFC_LED_array[{var.lane_number}]=2                                                                             ; This sets the colour to blue so we know filament is being loaded
M584 P{var.total_axis}                                                                                                    ; This unhides all the axes
if global.AFC_lane_loaded[{var.lane_number}]                                                                              ; This checks to make sure there is filament loaded in the lane
    M950 J{global.AFC_hub_input_number} C{global.AFC_hub_switch}                                                          ; sets up the hub switch
    G91                                                                                                                   ; set relative positioning
    G1 'f{global.AFC_hub_load_distance[0]} F{global.AFC_load_retract_speed[0]*60}                                         ; This does an initial load to check the filament has made it to the switch
    M400
    if sensors.gpIn[global.AFC_hub_input_number].value == 1                                                               ; checks the lane status
        M98 P"0:/sys/AFC/debug.g" A"T Pre: Filament loaded into hub"                                                      ; debug output if enabled
        M950 J{global.AFC_hub_input_number} C"nil"
    else
        while iterations < var.lane_load_retry && !var.hub_loaded                                                         ; attempts the load a few more times
            G1 'f{global.AFC_hub_load_distance[1]} F{global.AFC_load_retract_speed[0]*60}                                 ; loads a small amount
            M400
            if sensors.gpIn[global.AFC_hub_input_number].value == 1                                                       ; checks the hub switch
                set var.hub_loaded = true                                                                                 ; if loaded it changes it to true
                M98 P"0:/sys/AFC/debug.g" A"T Pre: Filament loaded into hub"                                                      ; debug output if enabled
                M950 J{global.AFC_hub_input_number} C"nil"
            if iterations == (var.lane_load_retry - 1) && !var.hub_loaded                                                 ; if not loaded on last try put out a warning and abort
                M291 S2 P"Filament has not made it into the filament hub, aborting macro" R"Warning"
                M950 J{global.AFC_hub_input_number} C"nil"
                T-1 P0
                abort
    G90
    
    if global.AFC_features[6] == 0                                                                                        ; This checks for the feature settings
        M98 P"0:/sys/AFC/Features/6_0.g"
    elif global.AFC_features[6] == 1                                                                                      ; This checks for the feature settings
        M98 P"0:/sys/AFC/Features/6_1.g"
    elif global.AFC_features[6] == 2                                                                                      ; This checks for the feature settings
        M98 P"0:/sys/AFC/Features/6_2.g"
    else 
        M291 S2 P{var.warning_text} R"Warning"
        T-1 P0
        abort