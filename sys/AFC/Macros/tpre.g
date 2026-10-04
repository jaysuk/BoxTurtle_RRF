; === AFC Tool Pre-Change Macro (tpre.g) - loads the lane of the new tool up to the toolhead ===
; param.A - tool number
; Failures call afc_error.g (pauses a running print instead of aborting it) and set Machine_tpre_failed so tpost skips.

; Machine Feature Numbers (Machine_features)
; 0 = brush, 1 = cut, 2 = kick, 3 = park, 4 = poop, 5 = purge, 6 = start check, 7 = spool tracking, 8 = initial unload
; AFC_features[u] = {use DC motor, unload method (0 hub, 1 lengths), load method (0 turtleneck, 1 lengths, 2 preload switch)}

if !exists(param.A)
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"tpre.g: missing the tool number (A)" Q1
    set global.Machine_tpre_failed = true
    M99

if global.Machine_tpre_failed                                                  ; tfree already failed for this tool change - don't load on top of it
    M99

set global.AFC_time=state.upTime                                               ; This is to record the time at the start of the tool load process

var tool_number = param.A
var lane_load_retry = 5                                                        ; number of extra attempts to reach the hub switch
var hub_loaded = false

; --- Unit Mapping ---
var unit_number = global.AFC_tool_map[var.tool_number][0]                       ; Get Unit ID
var lane_number = global.AFC_tool_map[var.tool_number][1]                       ; Get Local Lane ID
var lane_tool = global.AFC_lane_to_tool[var.unit_number][var.lane_number]                  ; native tool number of that lane (lane identity for the lane helpers and afc_error)

if !move.axes[global.Machine_axis_number[0]].homed || !move.axes[global.Machine_axis_number[1]].homed || !move.axes[global.Machine_axis_number[2]].homed
    G28                                                                        ; home the printer

M568 P{var.tool_number} A2                                                     ; sets the hotend to active state

; --- The lane must hold filament ---
if !global.AFC_lanes[var.unit_number][var.lane_number][0]
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"No filament loaded in Unit "^var.unit_number^" Lane "^var.lane_number} T{var.lane_tool} Q1
    set global.Machine_tpre_failed = true
    M99

; --- The hub must be empty ---
M950 J{global.AFC_hub_input_numbers[var.unit_number]} C{global.AFC_hub_switch[var.unit_number]}   ; sets up the hub switch for this unit
G4 P100
if sensors.gpIn[global.AFC_hub_input_numbers[var.unit_number]].value != 0
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"Filament is already in the hub of Unit "^var.unit_number^". Clear it (Lane - Unload to Hub) and retry"} T{var.lane_tool} Q1
    set global.Machine_tpre_failed = true
    M99
M950 J{global.AFC_hub_input_numbers[var.unit_number]} C"nil"                   ; turns the hub switch off

if global.AFC_extruder_temp[var.unit_number][var.lane_number] != 0             ; Check if a specific temperature is set for this lane
    M568 P{var.tool_number} S{global.AFC_extruder_temp[var.unit_number][var.lane_number]} R{global.AFC_extruder_temp[var.unit_number][var.lane_number]} ; Set Active/Standby temps
else
    M568 P{var.tool_number} S220 R220                                          ; Enable the hotend to this default temperature
M116 P{var.tool_number}

; --- Move the filament from the lane park position into the hub ---
M98 P"0:/sys/AFC/Macros/lane_motion_begin.g" A{var.lane_tool}                ; map + unhide 'f, disarm Longboi triggers
G92 'f{global.AFC_lanes[var.unit_number][var.lane_number][1]}                  ; sets the position of the 'f axis based on stored first length
if global.AFC_dc_load_assist && global.AFC_features[var.unit_number][0]
    M98 P"0:/sys/AFC/Macros/dc_motors.g" A"F" B{var.lane_tool}                 ; DC motor assists the load (stopped at the end, or by afc_error)
M400
set global.AFC_LED_array[var.unit_number][var.lane_number]=2                   ; blue = loading

M950 J{global.AFC_hub_input_numbers[var.unit_number]} C{global.AFC_hub_switch[var.unit_number]}   ; sets up the hub switch for this unit
G91                                                                            ; set relative positioning
G1 'f{global.AFC_hub_load_distance[var.unit_number][0]} F{global.AFC_load_retract_speed[var.unit_number][0]*60}   ; initial load towards the hub switch
M400
set var.hub_loaded = sensors.gpIn[global.AFC_hub_input_numbers[var.unit_number]].value == 1
while iterations < var.lane_load_retry && !var.hub_loaded                      ; attempts the load a few more times
    G1 'f{global.AFC_hub_load_distance[var.unit_number][1]} F{global.AFC_load_retract_speed[var.unit_number][0]*60}
    M400
    set var.hub_loaded = sensors.gpIn[global.AFC_hub_input_numbers[var.unit_number]].value == 1
G90                                                                            ; Set absolute positioning
M950 J{global.AFC_hub_input_numbers[var.unit_number]} C"nil"                   ; Disable hub switch
if !var.hub_loaded
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"Filament has not made it into the hub of Unit "^var.unit_number^" Lane "^var.lane_number} T{var.lane_tool} Q1
    set global.Machine_tpre_failed = true
    M99
M98 P"0:/sys/AFC/Macros/debug.g" A"T Pre: Filament loaded into hub"           ; debug output if enabled

; --- Load from the hub to the toolhead ---
if global.AFC_features[var.unit_number][2] == 0                                ; Load Method 0: turtleneck
    M98 P"0:/sys/AFC/Macros/load_with_turtleneck.g" A{var.tool_number}
elif global.AFC_features[var.unit_number][2] == 1                              ; Load Method 1: lengths
    M98 P"0:/sys/AFC/Macros/load_with_length.g" A{var.tool_number}
elif global.AFC_features[var.unit_number][2] == 2                              ; Load Method 2: preload (extruder input) switch
    M98 P"0:/sys/AFC/Macros/load_with_preload.g" A{var.tool_number}
else
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"Invalid load method "^global.AFC_features[var.unit_number][2]^" for Unit "^var.unit_number} T{var.lane_tool} Q1
    set global.Machine_tpre_failed = true
    M99
M400
if global.Machine_tpre_failed                                                  ; the load macro failed and has already cleaned up
    M99

if global.AFC_dc_load_assist && global.AFC_features[var.unit_number][0]
    M98 P"0:/sys/AFC/Macros/dc_motors.g" A"O" B{var.lane_tool}
M98 P"0:/sys/AFC/Macros/lane_motion_end.g" A{var.lane_tool}                  ; free endstops, hide 'f, re-arm triggers
