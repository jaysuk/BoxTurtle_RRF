; param.A - This is the lane number

; Machine Feature Numbers (Machine_features)
; 0 = brush
; 1 = cut
; 2 = kick
; 3 = park
; 4 = poop
; 5 = purge
; 6 = load
; 7 = startup check
; 8 = spoolman support

if !exists(param.A)                                                                                                                                     ; This just checks if the lane number has been provided.
    M118 S"Missing the lane number"                                                                                                                     ; Echo error message
    M291 P{"Aborting macro. Line "^line} R"0:/sys/AFC/Macros/tpre.g" S1
    set global.Machine_tpre_failed = true
    abort                                                                                                                                               ; Stop execution

set global.AFC_time=state.upTime                                                                                                                        ; This is to record the time at the start of the tool load process

var tool_number = param.A                                                                                                                               ; sets up the lane_number variable

var lane_load_retry = 5                                                                                                                                 ; sets up the number of retries allowed to load the hub
var hub_loaded = false                                                                                                                                  ; initiates a variable with a value of false

; --- Unit Mapping ---
var unit_number = global.Tool_to_AFC[var.tool_number][0]                                                                                                ; Get Unit ID
var lane_number = global.Tool_to_AFC[var.tool_number][1]                                                                                                ; Get Local Lane ID

var warning_text = "No filament loaded in Unit "^var.unit_number^" Lane "^var.lane_number                                                               ; sets up the warning text to be used

if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed                                                                                    ; checks if the printer is homed
    G28                                                                                                                                                 ; home the printer

M568 P{var.tool_number} A2                                                                                                                              ; sets the hotend to active state

M950 J{global.AFC_hub_input_numbers[var.unit_number]} C{global.AFC_hub_switch[var.unit_number]}                                                         ; sets up the hub switch for this unit
G4 P100
if sensors.gpIn[global.AFC_hub_input_numbers[var.unit_number]].value != 0                                                                               ; checks there is nothing loaded in the hub already
    M291 S2 P"There is filament loaded to the printer through the hub, aborting macro" R"Warning"                                                       ; Warn user
    M950 J{global.AFC_hub_input_numbers[var.unit_number]} C"nil"                                                                                        ; Disable hub switch
    M291 P{"Aborting macro. Line "^line} R"0:/sys/AFC/Macros/tpre.g" S1
    set global.Machine_tpre_failed = true
    abort                                                                                                                                               ; Stop execution

M950 J{global.AFC_hub_input_numbers[var.unit_number]} C"nil"                                                                                            ; turns the hub switch off

if global.AFC_extruder_temp[var.unit_number][var.lane_number] != 0                                                                                      ; Check if a specific temperature is set for this lane
    M568 P{var.tool_number} S{global.AFC_extruder_temp[var.unit_number][var.lane_number]} R{global.AFC_extruder_temp[var.unit_number][var.lane_number]} ; Set Active/Standby temps
else
    M568 P{var.tool_number} S220 R220                                                                                                                   ; Enable the hotend to this default temperature
M116 P{var.tool_number}

M98 P"0:/sys/AFC/Macros/axis_setup.g" A{var.tool_number}                                                                                                ; Map the lane motor to an axis

M584 P{#move.axes}                                                                                                                             ; Capture total number of axes

G92 'f{global.AFC_lanes[var.unit_number][var.lane_number][1]}                                                                                           ; sets the position of the 'f axis based on stored first length
M400                                                                                                                                                    ; this is just a pause to wait for moves
set global.AFC_LED_array[var.unit_number][var.lane_number]=2                                                                                            ; This sets the colour to blue so we know filament is being loaded                                                                                                                                  ; This unhides all the axes (make sure total_axis is correct)

if global.AFC_lanes[var.unit_number][var.lane_number][0]                                                                                                ; This checks to make sure there is filament loaded in the lane
    M950 J{global.AFC_hub_input_numbers[var.unit_number]} C{global.AFC_hub_switch[var.unit_number]}                                                     ; sets up the hub switch for this unit
    G91                                                                                                                                                 ; set relative positioning
    G1 'f{global.AFC_hub_load_distance[var.unit_number][0]} F{global.AFC_load_retract_speed[var.unit_number][0]*60}                                     ; This does an initial load to check the filament has made it to the switch
    M400                                                                                                                                                ; Wait for move
    if sensors.gpIn[global.AFC_hub_input_numbers[var.unit_number]].value == 1                                                                           ; checks the lane status (1 = filament present)
        M98 P"0:/sys/AFC/Macros/debug.g" A"T Pre: Filament loaded into hub"                                                                             ; debug output if enabled
        M950 J{global.AFC_hub_input_numbers[var.unit_number]} C"nil"                                                                                    ; Disable hub switch
    else
        while iterations < var.lane_load_retry && !var.hub_loaded                                                                                       ; attempts the load a few more times
            G1 'f{global.AFC_hub_load_distance[var.unit_number][1]} F{global.AFC_load_retract_speed[var.unit_number][0]*60}                             ; loads a small amount
            M400                                                                                                                                        ; Wait for move
            if sensors.gpIn[global.AFC_hub_input_numbers[var.unit_number]].value == 1                                                                   ; checks the hub switch
                set var.hub_loaded = true                                                                                                               ; if loaded it changes it to true
                M98 P"0:/sys/AFC/Macros/debug.g" A"T Pre: Filament loaded into hub"                                                                     ; debug output if enabled
                M950 J{global.AFC_hub_input_numbers[var.unit_number]} C"nil"                                                                            ; Disable hub switch
            if iterations == (var.lane_load_retry - 1) && !var.hub_loaded                                                                               ; if not loaded on last try put out a warning and abort
                M291 S2 P"Filament has not made it into the filament hub, aborting macro" R"Warning"                                                    ; Warn user
                M950 J{global.AFC_hub_input_numbers[var.unit_number]} C"nil"                                                                            ; Disable hub switch
                M291 P{"Aborting macro. Line "^line} R"0:/sys/AFC/Macros/tpre.g" S1
                set global.Machine_tpre_failed = true
                abort                                                                                                                                   ; Stop execution
    G90                                                                                                                                                 ; Set absolute positioning

    if global.AFC_features[var.unit_number][2] == 0                                                                                                     ; This checks for the feature settings (Load Method 0)
        M98 P"0:/sys/AFC/Macros/load_with_turtleneck.g" A{var.tool_number}                                                           ; Execute Load Method 0
        M400
    elif global.AFC_features[var.unit_number][2] == 1                                                                                                   ; This checks for the feature settings (Load Method 1)
        M98 P"0:/sys/AFC/Macros/load_with_length.g" A{var.tool_number}                                                                ; Execute Load Method 1
        M400
    elif global.AFC_features[var.unit_number][2] == 2                                                                                                   ; This checks for the feature settings (Load Method 2)
        M98 P"0:/sys/AFC/Macros/load_with_preload.g" A{var.tool_number}                                                             ; Execute Load Method 2
        M400
    else 
        M291 S2 P"Invalid Load Method Configured" R"Warning"                                                                                            ; Warn if no valid load method or no filament loaded
        M291 P{"Aborting macro. Line "^line} R"0:/sys/AFC/Macros/tpre.g" S1
        set global.Machine_tpre_failed = true
        abort       
M584 P{#move.axes - 1}                                                                                                                                     ; Stop execution