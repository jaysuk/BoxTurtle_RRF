; === AFC Tool Free Macro (tfree.g) - unloads the filament of the current tool back into its lane ===
; param.A - tool number (default: the current tool)
; param.B - 1 = run the DC motor while unloading
; param.C - ignore anything that requires an X/Y/Z move
; Failures call afc_error.g (pauses a running print instead of aborting it); afc_error F1 makes the following tpre skip.

; Machine Feature Numbers (Machine_features)
; 0 = brush, 1 = cut, 2 = kick, 3 = park, 4 = poop, 5 = purge, 6 = start check, 7 = spool tracking, 8 = initial unload
; AFC_features[u] = {use DC motor, unload method (0 hub, 1 lengths), load method (0 turtleneck, 1 lengths, 2 preload switch)}

; --- Variable Initialization ---
var tfree_time1=0                                                                                                            ; End time of macro (upTime)
var tfree_time=state.upTime                                                                                                  ; Start time of macro (upTime)
var time=0                                                                                                                   ; Total duration in seconds
var time_seconds=0                                                                                                           ; Calculated remaining seconds
var time_minutes=0                                                                                                           ; Calculated minutes
var DC_motor=0                                                                                                               ; Flag for DC motor assistance
var retract = 0                                                                                                              ; Filament retract distance variable
var tool_number = 0                                                                                                          ; The Tool ID (Lane ID system-wide)
var unit_number = 0                                                                                                          ; The Unit ID for this tool
var lane_tool = 0                                                                                                           ; Native tool number of the lane (lane identity for the lane helpers and afc_error)
var lane_number = 0                                                                                                          ; The local Lane ID (0-3) for this tool
var min_temp = 180                                                                                                           ; Minimum nozzle temperature for the retraction
var lane_temp = 220                                                                                                          ; Temperature to heat to if the nozzle is too cold
var chain = 0                                                                                                                ; 1 = a tool is loaded after this unload, so a failure must stop its tpre
var hub_search = 0                                                                                                           ; Bounded 'f search distance towards the hub

; --- Determine Lane Number ---
if exists(param.A)                                                                                                           ; Check if lane number parameter was passed
    set var.tool_number = param.A                                                                                            ; Assign parameter to local variable
else                                                                                                                         ; If parameter is missing
    set var.tool_number = move.motionSystems[0].currentTool                                                                  ; Use the currently active tool index

if var.tool_number < 0 || var.tool_number >= #global.Tool_to_AFC
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"tfree.g: tool "^var.tool_number^" is not an AFC tool"} Q1 F{var.chain}
    M99

set global.Machine_tpre_failed = false                                                                                       ; a new tool change starts here
if move.motionSystems[0].nextTool >= 0
    set var.chain = 1

; --- Resolve Unit and Lane ---
set var.unit_number = global.AFC_tool_map[var.tool_number][0]                                                                 ; Get the BoxTurtle Unit ID
set var.lane_number = global.AFC_tool_map[var.tool_number][1]                                                                 ; Get the local Lane ID (0-3)
set var.lane_tool = global.AFC_lane_to_tool[var.unit_number][var.lane_number]

; --- Make sure the hotend is hot enough to retract (uses the actual temperature, not the setpoint) ---
if global.AFC_extruder_temp[var.unit_number][var.lane_number] != 0
    set var.lane_temp = global.AFC_extruder_temp[var.unit_number][var.lane_number]
    set var.min_temp = var.lane_temp - 20
if heat.heaters[tools[var.tool_number].heaters[0]].current < var.min_temp
    M568 P{var.tool_number} S{var.lane_temp} R{var.lane_temp}
    M116 P{var.tool_number}

; --- Spool Tracking ---
if global.Machine_features[7] == 1                                                                                           ; Check if spool tracking is enabled (Machine_features[7])
    set global.spool_tracking[var.unit_number][var.lane_number][1] = false                                                         ; Disable extrusion tracking for this lane

    ; Calculate amount extruded since this tool was loaded (in tpost)
    var extIdx = tools[var.tool_number].filamentExtruder
    if var.extIdx != -1
        var baseline = global.spool_extrusion_baseline[var.tool_number]
        var current = move.extruders[var.extIdx].position
        var extruded_mm = var.current - var.baseline

        if global.spool_active_data[var.unit_number][var.lane_number][0] != -1

            if var.extruded_mm > 0
                ; Ensure First Used Date is populated if this is the very first time it's extruded
                if global.spool_active_data[var.unit_number][var.lane_number][6] == "" && state.time != null
                    set global.spool_active_data[var.unit_number][var.lane_number][6] = state.time

                ; Always update Last Used Date whenever filament is actively consumed
                if state.time != null
                    set global.spool_active_data[var.unit_number][var.lane_number][7] = state.time

                ; Deduct the final remaining chunk from the spool length (index 5)
                set global.spool_active_data[var.unit_number][var.lane_number][5] = global.spool_active_data[var.unit_number][var.lane_number][5] - var.extruded_mm

            ; Instantly persist the new length back to the spool's .g file on the SD card
            ; We do this ALWAYS on unload because daemon.g might have left buffered unsaved extrusion
            M98 P"0:/sys/AFC/Macros/spool_write.g" U{var.unit_number} L{var.lane_number}

        ; Reset baseline and unsaved tracker
        set global.spool_extrusion_baseline[var.tool_number] = 0.0
        set global.spool_unsaved_extrusion[var.tool_number] = 0.0

; --- Homing Check ---
if !move.axes[global.Machine_axis_number[0]].homed || !move.axes[global.Machine_axis_number[1]].homed || !move.axes[global.Machine_axis_number[2]].homed   ; Verify all axes are homed
    G28                                                                                                                      ; Perform homing if necessary

; --- Feature Execution (Cut/Park) ---
M400                                                                                                                         ; wait for other commands to finish executing
if !exists(param.C)                                                                                                          ; If not ignoring movement commands
    if global.Machine_features[1]                                                                                            ; Check if Cut feature is enabled (Index 1)
        M98 P"0:/sys/AFC/Macros/cut.g"                                                                                       ; Execute filament cutting macro
    if global.Machine_features[3]                                                                                            ; Check if Park feature is enabled (Index 3)
        M98 P"0:/sys/AFC/Macros/park.g" A0                                                                                   ; Execute toolhead parking macro
    if global.Machine_tpre_failed                                                                                            ; cut/park failed and has already reported it
        if var.chain == 0
            set global.Machine_tpre_failed = false                                                                           ; nothing follows this unload
        M99

if global.Machine_features[1]                                                                                                ; Check if Cut feature is enabled (Index 1)
    set var.retract = global.Machine_extruder_measurements[1] + 5                                                            ; Set longer retract distance for cut scenario
else
    set var.retract = global.Machine_extruder_measurements[0] + 5                                                            ; Set standard retract distance

if exists(param.B)                                                                                                           ; Check if DC motor parameter was passed
    set var.DC_motor=param.B                                                                                                 ; Set local DC motor flag
else
    set var.DC_motor=0                                                                                                       ; Default DC motor to off

; --- Buffer Management (Disarm Sensors) ---
M581.1 T{global.AFC_buffer_fault_triggers[var.unit_number]} P-1                                                          ; Delete the buffer fault trigger first (its expression reads the inputs we unmap below)
M581 P{global.AFC_buffer_input_numbers[var.unit_number][0]} R-1 T{global.AFC_buffer_trigger_numbers[var.unit_number][0]} ; Disable 'Advance' buffer trigger for this unit
M581 P{global.AFC_buffer_input_numbers[var.unit_number][1]} R-1 T{global.AFC_buffer_trigger_numbers[var.unit_number][1]} ; Disable 'Trail' buffer trigger for this unit
M400                                                                                                                         ; Wait for command execution
M950 J{global.AFC_buffer_input_numbers[var.unit_number][0]} C"nil"                                                           ; Unmap 'Advance' buffer pin
M950 J{global.AFC_buffer_input_numbers[var.unit_number][1]} C"nil"                                                           ; Unmap 'Trail' buffer pin

; --- LED Status Update ---
set global.AFC_LED_array[var.unit_number][var.lane_number]=2                                                                 ; Set lane LED to Blue (Busy/Active)
M98 P"0:/sys/AFC/Macros/leds.g"                                                                                              ; Flush LEDs

; --- Tip forming (printers without a cutter) ---
set global.AFC_tip_retracted = 0
if global.Machine_tip_forming && !global.Machine_features[1] && !exists(param.C)
    M98 P"0:/sys/AFC/Macros/tip_form.g" A{var.tool_number}

; --- Hotend Retraction ---
M83                                                                                                                          ; Ensure relative extrusion mode
if global.Machine_features[8] == 0
    G1 E{-max(var.retract - global.AFC_tip_retracted, 0)} F600                                                              ; Retract the rest of the way out of the hotend (tip forming already pulled the tip back)
    M400
elif global.Machine_features[8] == 1
    ; The extruder input switch is bound once at boot (AFC.g): J = AFC_unload_input_numbers[0], M574 E<every extruder> P<J>.
    ; An unloading H1 E move stops as soon as the input goes inactive (filament gone).
    if global.Machine_extruder_switches[0] == "nil" || sensors.gpIn[global.AFC_unload_input_numbers[0]] == null
        M98 P"0:/sys/AFC/Macros/afc_error.g" S"Initial unload method 1 needs Machine_extruder_switches[0] to be configured" T{var.lane_tool} Q1 F{var.chain}
        M99
    G1 H1 E{-(global.Machine_extruder_measurements[0] + 20)} F600
    M400
    if sensors.gpIn[global.AFC_unload_input_numbers[0]].value != 0
        M98 P"0:/sys/AFC/Macros/afc_error.g" S{"Filament is still at the extruder input switch after retracting "^(global.Machine_extruder_measurements[0] + 20)^"mm"} T{var.lane_tool} Q1 F{var.chain}
        M99

; --- Hardware Unmapping ---
M591 D{tools[var.tool_number].extruders[#tools[var.tool_number].extruders - 1]} P0                                           ; Disable the filament monitor on this tool's AFC extruder (the last drive of the tool)
M98 P"0:/sys/AFC/Macros/extruder_setup.g" A{var.tool_number} B0                                                              ; Unmap extruder drive for this lane
M98 P"0:/sys/AFC/Macros/lane_motion_begin.g" A{var.lane_tool}                                                              ; Map lane motor to the temporary 'f axis, unhide it
G92 'f{global.AFC_lanes[var.unit_number][var.lane_number][2]}                                                                ; Set temporary 'F' axis position to known total length

; --- Main Retraction Sequence ---
if var.DC_motor == 1                                                                                                         ; If DC motor assist is enabled
    M98 P"0:/sys/AFC/Macros/dc_motors.g" A"R" B{var.lane_tool}                                                             ; Activate DC motor in Reverse
    M400                                                                                                                     ; Wait for activation

; Unload Method 0: Sensor-based Retraction (Hub Switch)
if global.AFC_features[var.unit_number][1] == 0                                                                              ; Check unit unload preference (Index 1: 0=Hub, 1=Lengths)
    M400
    M574 'f1 P{"!"^global.AFC_hub_switch[var.unit_number]} S1                                                                ; Configure F-axis endstop to inverted hub switch for this unit (triggers when the hub clears)
    if global.AFC_lanes[var.unit_number][var.lane_number][2] > 0
        set var.hub_search = global.AFC_lanes[var.unit_number][var.lane_number][1] - 100                                     ; Search at most (total - first) + 100mm
    else
        set var.hub_search = -20000                                                                                          ; Lane not measured: fall back to the long search
        G92 'f20000
    G1 H4 'f{var.hub_search} F{global.AFC_load_retract_speed[var.unit_number][1]*60}                                         ; Homing move to retract until hub sensor clears
    M400
    if !sensors.endstops[global.AFC_f_axis].triggered                                                                        ; the hub never cleared
        M98 P"0:/sys/AFC/Macros/afc_error.g" S{"Filament did not clear the hub of Unit "^var.unit_number^" Lane "^var.lane_number^". Check the lane lengths and the hub switch"} T{var.lane_tool} Q1 F{var.chain}
        M99
    G91                                                                                                                      ; Relative positioning
    G1 'f{-global.AFC_hub_retract_distance[var.unit_number]} F{global.AFC_load_retract_speed[var.unit_number][1]*60}         ; Retract further to the park position (same distance as Lane - Measure First)
    G90                                                                                                                      ; Absolute positioning
    M574 'f1 P"nil" S1                                                                                                       ; Clear F-axis endstop configuration
    M400                                                                                                                     ; Wait for moves

; Unload Method 1: Distance-based Retraction
elif global.AFC_features[var.unit_number][1] == 1                                                                            ; Check unit unload preference
    M400                                                                                                                     ; Wait
    G1 'f{global.AFC_lanes[var.unit_number][var.lane_number][1]} F{global.AFC_load_retract_speed[var.unit_number][1]*60}     ; Retract to 'first load' position
M400                                                                                                                         ; Wait

if var.DC_motor==1                                                                                                           ; If DC motor was used
    M98 P"0:/sys/AFC/Macros/dc_motors.g" A"O" B{var.lane_tool}                                                             ; Turn off DC motor
M400                                                                                                                         ; Wait

; --- Safety Check (Method 1 Only) ---
; Re-reference the park position: the filament tip must trigger the hub switch hub_retract_distance ahead of the park position
if global.AFC_features[var.unit_number][1] == 1                                                                              ; If distance-based method was used
    M574 'f2 S1 P{global.AFC_hub_switch[var.unit_number]}                                                                    ; Set F max endstop to hub switch
    G1 H4 'f{global.AFC_lanes[var.unit_number][var.lane_number][1] + global.AFC_hub_retract_distance[var.unit_number] + 50} F{global.AFC_load_retract_speed[var.unit_number][0]*60}   ; Short homing move forward to verify the sensor (Forward Speed)
    M400
    if !sensors.endstops[global.AFC_f_axis].triggered                                                                        ; the hub switch was not found where expected
        M98 P"0:/sys/AFC/Macros/afc_error.g" S{"The hub switch of Unit "^var.unit_number^" was not found after unloading Lane "^var.lane_number^". Check the lane lengths"} T{var.lane_tool} Q1 F{var.chain}
        M99
    G91                                                                                                                      ; Relative positioning
    G1 'f{-global.AFC_hub_retract_distance[var.unit_number]} F{global.AFC_load_retract_speed[var.unit_number][1]*60}         ; Back to the park position
    G90                                                                                                                      ; Absolute positioning
    M574 'f2 P"nil" S1                                                                                                       ; Clear endstop
    M400                                                                                                                     ; Wait

; --- Final Cleanup ---
set global.AFC_LED_array[var.unit_number][var.lane_number]=1                                                                 ; Set lane LED to Green (Ready)
M98 P"0:/sys/AFC/Macros/leds.g"                                                                                              ; Update physical LEDs
M98 P"0:/sys/AFC/Macros/save_status.g" A1
M98 P"0:/sys/AFC/Macros/lane_motion_end.g" A{var.lane_tool}                                                                ; Free endstops, hide 'f, re-arm triggers
M400                                                                                                                         ; Wait

set global.Machine_last_tool = move.motionSystems[0].currentTool                                                             ; Update last tool used (renamed from AFC_last_tool)

; --- Time Calculation and Output ---
set var.tfree_time1=state.upTime                                                                                             ; Capture finish time
set var.time=var.tfree_time1-var.tfree_time                                                                                  ; Calculate total seconds
set var.time_minutes=floor(var.time/60)                                                                                      ; Calculate minutes
set var.time_seconds=var.time-(var.time_minutes*60)                                                                          ; Calculate remaining seconds

if !exists(param.C)                                                                                                          ; If output is not suppressed
    M118 S{"The tool unload time was "^var.time^" seconds ("^var.time_minutes^" minutes and "^var.time_seconds^" seconds)"}
    M98 P"0:/sys/AFC/Macros/afc_log.g" S{"T"^var.tool_number^" unloaded in "^var.time^"s (Unit "^var.unit_number^" Lane "^var.lane_number^")"}
