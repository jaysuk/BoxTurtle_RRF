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
    echo "Missing the lane number"                                                                                        ; Echo error message
    abort                                                                                                                 ; Stop execution

set global.AFC_time=state.upTime                                                                                          ; This is to record the time at the start of the tool load process

var lane_number = param.A                                                                                                 ; sets up the lane_number variable
var warning_text = "No filament loaded in Lane "^{var.lane_number}                                                        ; sets up the warning text to be used
var lane_load_retry = 5                                                                                                   ; sets up the number of retries allowed to load the hub
var hub_loaded = false                                                                                                    ; initiates a variable with a value of false

if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed                                                      ; checks if the printer is homed
    G28                                                                                                                   ; home the printer

M568 P{var.lane_number} A2                                                                                                ; sets the hotend to active state

M950 J{global.AFC_hub_input_number} C{global.AFC_hub_switch}                                                              ; sets up the hub switch
G4 P100
if sensors.gpIn[global.AFC_hub_input_number].value !=0                                                                    ; checks there is nothing loaded in the hub already
    M291 S2 P"There is filament loaded to the printer through the hub, aborting macro" R"Warning"                         ; Warn user
    M950 J{global.AFC_hub_input_number} C"nil"                                                                            ; Disable hub switch
    abort                                                                                                                 ; Stop execution

M950 J{global.AFC_hub_input_number} C"nil"                                                                                ; turns the hub switch off

if global.AFC_extruder_temp[{var.lane_number}] != 0                                                                       ; Check if a specific temperature is set for this lane
    M568 P{var.lane_number} S{global.AFC_extruder_temp[{var.lane_number}]} R{global.AFC_extruder_temp[{var.lane_number}]} ; Set Active/Standby temps
else
    M568 P{var.lane_number} S220 R220                                                                                     ; Enable the hotend to this default temperature

M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}                                                                  ; Map the lane motor to an axis

var total_axis = #move.axes                                                                                               ; Capture total number of axes

G92 'f{global.AFC_lane_first_length[{var.lane_number}]}                                                                   ; sets the position of the 'f axis based on stored length
M400                                                                                                                      ; this is just a pause to wait for moves
set global.AFC_LED_array[{var.lane_number}]=2                                                                             ; This sets the colour to blue so we know filament is being loaded
M584 P{var.total_axis}                                                                                                    ; This unhides all the axes (make sure total_axis is correct)
if global.AFC_lane_loaded[{var.lane_number}]                                                                              ; This checks to make sure there is filament loaded in the lane
    M950 J{global.AFC_hub_input_number} C{global.AFC_hub_switch}                                                          ; sets up the hub switch
    G91                                                                                                                   ; set relative positioning
    G1 'f{global.AFC_hub_load_distance[0]} F{global.AFC_load_retract_speed[0]*60}                                         ; This does an initial load to check the filament has made it to the switch
    M400                                                                                                                  ; Wait for move
    if sensors.gpIn[global.AFC_hub_input_number].value == 1                                                               ; checks the lane status (1 = filament present)
        M98 P"0:/sys/AFC/debug.g" A"T Pre: Filament loaded into hub"                                                      ; debug output if enabled
        M950 J{global.AFC_hub_input_number} C"nil"                                                                        ; Disable hub switch
    else
        while iterations < var.lane_load_retry && !var.hub_loaded                                                         ; attempts the load a few more times
            G1 'f{global.AFC_hub_load_distance[1]} F{global.AFC_load_retract_speed[0]*60}                                 ; loads a small amount
            M400                                                                                                          ; Wait for move
            if sensors.gpIn[global.AFC_hub_input_number].value == 1                                                       ; checks the hub switch
                set var.hub_loaded = true                                                                                 ; if loaded it changes it to true
                M98 P"0:/sys/AFC/debug.g" A"T Pre: Filament loaded into hub"                                              ; debug output if enabled
                M950 J{global.AFC_hub_input_number} C"nil"                                                                ; Disable hub switch
            if iterations == (var.lane_load_retry - 1) && !var.hub_loaded                                                 ; if not loaded on last try put out a warning and abort
                M291 S2 P"Filament has not made it into the filament hub, aborting macro" R"Warning"                      ; Warn user
                M950 J{global.AFC_hub_input_number} C"nil"                                                                ; Disable hub switch
                abort                                                                                                     ; Stop execution
    G90                                                                                                                   ; Set absolute positioning

    if global.AFC_features[6] == 0                                                                                        ; This checks for the feature settings (Load Method 0)
        M98 P"0:/sys/AFC/Features/6_0.g" A{var.lane_number} B{var.total_axis}                                             ; Execute Load Method 0
    elif global.AFC_features[6] == 1                                                                                      ; This checks for the feature settings (Load Method 1)
        M98 P"0:/sys/AFC/Features/6_1.g" A{var.lane_number} B{var.total_axis}                                             ; Execute Load Method 1
    elif global.AFC_features[6] == 2                                                                                      ; This checks for the feature settings (Load Method 2)
        M98 P"0:/sys/AFC/Features/6_2.g" A{var.lane_number} B{var.total_axis}                                             ; Execute Load Method 2
    else 
        M291 S2 P"Invalid Load Method Configured" R"Warning"                                                              ; Warn if no valid load method or no filament loaded
        abort                                                                                                             ; Stop execution