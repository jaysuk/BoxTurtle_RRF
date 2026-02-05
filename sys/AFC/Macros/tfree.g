; param.A - This is the lane number
; param.B - This determines if the DC motors should run. B1 is yes
; param.C - This is used to ignore anything that requires an X/Y/Z move

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

; AFC Feature Numbers (AFC_features[unit])
; 0 = use dc motors
; 1 = unload method (0=hubswitch, 1=lengths)

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
var lane_number = 0                                                                                                          ; The local Lane ID (0-3) for this tool

; --- Determine Lane Number ---
if exists(param.A)                                                                                                           ; Check if lane number parameter was passed
    set var.tool_number = param.A                                                                                            ; Assign parameter to local variable
else                                                                                                                         ; If parameter is missing
    set var.tool_number = state.currentTool                                                                                  ; Use the currently active tool index

; --- Resolve Unit and Lane ---
set var.unit_number = global.Tool_to_AFC[var.tool_number][0]                                                                 ; Get the BoxTurtle Unit ID
set var.lane_number = global.Tool_to_AFC[var.tool_number][1]                                                                 ; Get the local Lane ID (0-3)

; --- If the print head is not hot, make it hot ---
if (state.nextTool == -1 && tools[{var.tool_number}].active[0] <= 175)
    M568 P{var.tool_number} S220 R220
    M116 P{var.tool_number}

; --- Spoolman Support ---
if global.Machine_features[8] == 1                                                                                           ; Check if Spoolman feature is enabled (Index 8 in Machine_features)
    set global.spoolman[var.unit_number][var.lane_number][1] = false                                                         ; Disable extrusion tracking for this lane

; --- Homing Check ---
if !move.axes[global.Machine_axis_number[0]].homed || !move.axes[global.Machine_axis_number[1]].homed || !move.axes[global.Machine_axis_number[0]].homed                                                         ; Verify all axes are homed
    G28                                                                                                                      ; Perform homing if necessary

; --- Feature Execution (Cut/Park) ---
M400                                                                                                                         ; wait for other commands to finish executing

; --- Feature Execution (Cut/Park) ---
if !exists(param.C)                                                                                                          ; If not ignoring movement commands
    if global.Machine_features[1]                                                                                            ; Check if Cut feature is enabled (Index 1)
        M98 P"0:/sys/AFC/Macros/cut.g"                                                                                              ; Execute filament cutting macro
    if global.Machine_features[3]                                                                                            ; Check if Park feature is enabled (Index 3)
        M98 P"0:/sys/AFC/Macros/park.g"                                                                                             ; Execute toolhead parking macro

var total_axis = #move.axes                                                                                                  ; Capture total axis count for cleanup later
if global.Machine_features[1]                                                                                                ; Check if Cut feature is enabled (Index 1)
    set var.retract = global.Machine_extruder_measurements[1] + 5                                                              ; Set longer retract distance for cut scenario
else
    set var.retract = global.Machine_extruder_measurements[0] + 5                                                              ; Set standard retract distance

if !exists(param.C)                                                                                                          ; If not ignoring moves
    var current_temp = tools[{var.tool_number}].active[0]                                                                    ; Capture current tool temperature

if exists(param.B)                                                                                                           ; Check if DC motor parameter was passed
    set var.DC_motor=param.B                                                                                                 ; Set local DC motor flag
else
    set var.DC_motor=0                                                                                                       ; Default DC motor to off

; --- Buffer Management (Disarm Sensors) ---
if !exists(param.C)                                                                                                          ; If not ignoring moves
    M581 P{global.AFC_buffer_input_numbers[var.unit_number][0]} R-1 T{global.AFC_buffer_trigger_numbers[var.unit_number][0]} ; Disable 'Advance' buffer trigger for this unit
    M581 P{global.AFC_buffer_input_numbers[var.unit_number][1]} R-1 T{global.AFC_buffer_trigger_numbers[var.unit_number][1]} ; Disable 'Trail' buffer trigger for this unit
    M400                                                                                                                     ; Wait for command execution
    M950 J{global.AFC_buffer_input_numbers[var.unit_number][0]} C"nil"                                                       ; Unmap 'Advance' buffer pin
    M950 J{global.AFC_buffer_input_numbers[var.unit_number][1]} C"nil"                                                       ; Unmap 'Trail' buffer pin

; --- LED Status Update ---
set global.AFC_LED_array[var.unit_number][var.lane_number]=2                                                                 ; Set lane LED to Blue (Busy/Active)
M98 P"0:/sys/AFC/Macros/LEDs.g"                                                                                                     ; Flush LEDs

; --- Hotend Retraction ---
M83                                                                                                                          ; Ensure relative extrusion mode
G1 E{-var.retract} F600                                                                                                      ; Retract filament from hotend melt zone
M400                                                                                                                         ; Wait for move completion

; --- Hardware Unmapping ---
M591 D1 P0                                                                                                                   ; Disable filament monitor D1
M98 P"0:/sys/AFC/Macros/Extruder_setup.g" A{var.tool_number} B0                                                              ; Unmap extruder drive for this lane
M98 P"0:/sys/AFC/Macros/Axis_setup.g" A{var.tool_number}                                                                     ; Map lane motor to temporary axis
G92 'f{global.AFC_lanes[var.unit_number][var.lane_number][2]}                                                                ; Set temporary 'F' axis position to known total length

; --- Main Retraction Sequence ---
if var.DC_motor == 1                                                                                                           ; If DC motor assist is enabled
    M98 P"0:/sys/AFC/Macros/dc_motors.g" A"R" B{var.tool_number}                                                             ; Activate DC motor in Reverse
    M400                                                                                                                     ; Wait for activation

; Unload Method 0: Sensor-based Retraction (Hub Switch)
if global.AFC_features[var.unit_number][1] == 0                                                                              ; Check unit unload preference (Index 1: 0=Hub, 1=Lengths)
    M574 'f1 P{"!"^global.AFC_hub_switch[var.unit_number]} S1                                                                ; Configure F-axis endstop to inverted hub switch for this unit
    G92 'f20000                                                                                                              ; Preset F position
    G1 H4 'f-20000 F{global.AFC_load_retract_speed[var.unit_number][1]*60}                                                   ; Homing move to retract until hub sensor triggers (Reverse Speed)
    G91                                                                                                                      ; Relative positioning
    G1 'f{-global.AFC_hub_retract_distance[var.unit_number]} F{global.AFC_load_retract_speed[var.unit_number][1]*60}         ; Retract further to clear hub
    G90                                                                                                                      ; Absolute positioning
    M574 'f1 P"nil" S1                                                                                                       ; Clear F-axis endstop configuration
    M400                                                                                                                     ; Wait for moves

; Unload Method 1: Distance-based Retraction
elif global.AFC_features[var.unit_number][1] == 1                                                                            ; Check unit unload preference
    G92 'f{global.AFC_lanes[var.unit_number][var.lane_number][2]}                                                            ; Reset F position to Total Length
    M400                                                                                                                     ; Wait
    G1 'f{global.AFC_lanes[var.unit_number][var.lane_number][1]} F{global.AFC_load_retract_speed[var.unit_number][1]*60}     ; Retract to 'first load' position
M400                                                                                                                         ; Wait

if var.DC_motor==1                                                                                                           ; If DC motor was used
    M98 P"0:/sys/AFC/Macros/dc_motors.g" A"O" B{var.tool_number}                                                             ; Turn off DC motor
M400                                                                                                                         ; Wait

; --- Safety Check (Method 1 Only) ---
if global.AFC_features[var.unit_number][1] == 1                                                                              ; If distance-based method was used
    M574 'f2 S1 P{global.AFC_hub_switch[var.unit_number]}                                                                    ; Set F max endstop to hub switch
    G1 H4 'f300 F{global.AFC_load_retract_speed[var.unit_number][0]*60}                                                      ; Short homing move forward to verify sensor state (Forward Speed)
    G91                                                                                                                      ; Relative positioning
    G1 'f{-global.AFC_hub_retract_distance[var.unit_number]+10} F{global.AFC_load_retract_speed[var.unit_number][1]*60}      ; Final clearing retract
    G90                                                                                                                      ; Absolute positioning
    M574 'f1 P"nil" S1                                                                                                       ; Clear endstop
    M400                                                                                                                     ; Wait

; --- Final Cleanup ---
set global.AFC_LED_array[var.unit_number][var.lane_number]=1                                                                 ; Set lane LED to Green (Ready)
M98 P"0:/sys/AFC/Macros/LEDs.g"                                                                                                     ; Update physical LEDs
M98 P"0:/sys/AFC/Macros/save_status.g"
M584 P{var.total_axis-1}                                                                                                     ; Hide temporary 'F' axis
M400                                                                                                                         ; Wait

set global.Machine_last_tool = state.currentTool                                                                             ; Update last tool used (renamed from AFC_last_tool)

; --- Time Calculation and Output ---
set var.tfree_time1=state.upTime                                                                                             ; Capture finish time
set var.time=var.tfree_time1-var.tfree_time                                                                                  ; Calculate total seconds
set var.time_minutes=floor(var.time/60)                                                                                      ; Calculate minutes
set var.time_seconds=var.time-(var.time_minutes*60)                                                                          ; Calculate remaining seconds

if !exists(param.C)                                                                                                          ; If output is not suppressed
    echo "The tool unload time was "^var.time^" seconds ("^var.time_minutes^" minutes"