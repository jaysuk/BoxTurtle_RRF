; param.A - This is the lane number
; param.B - This determines if the DC motors should run. B1 is yes
; param.C - This is used to ignore anything that requires an X/Y/Z move

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

; --- Variable Initialization ---
var tfree_time1=0 ; End time of macro (upTime)
var tfree_time=state.upTime ; Start time of macro (upTime)
var time=0 ; Total duration in seconds
var time_seconds=0 ; Calculated remaining seconds
var time_minutes=0 ; Calculated minutes
var DC_motor=0 ; Flag for DC motor assistance
var retract = 0 ; Filament retract distance variable
var lane_number = 0 ; Index of the lane being freed

; --- Determine Lane Number ---
if exists(param.A) ; Check if lane number parameter was passed
    set var.lane_number = param.A ; Assign parameter to local variable
if !exists(param.A) ; If parameter is missing
    set var.lane_number = state.currentTool ; Use the currently active tool index

; --- Spoolman Support ---
if global.AFC_features[10] == 1 ; Check if Spoolman feature is enabled
    set global.spoolman_capture_extrusion[{var.lane_number}] = false ; Disable extrusion tracking for this lane

; --- Homing Check ---
if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed ; Verify all axes are homed
    G28 ; Perform homing if necessary

; --- Feature Execution (Cut/Park) ---
if !exists(param.C) ; If not ignoring movement commands
    if global.AFC_features[1] ; Check if Cut feature is enabled
        M98 P"0:/sys/AFC/cut.g" ; Execute filament cutting macro
    if global.AFC_features[3] ; Check if Park feature is enabled
        M98 P"0:/sys/AFC/park.g" ; Execute toolhead parking macro

var total_axis = #move.axes ; Capture total axis count for cleanup later
if global.AFC_features[1] ; Check if Cut feature is enabled
    set var.retract = global.main_extruder_measurements[1]+5 ; Set longer retract distance for cut scenario
else
    set var.retract = global.main_extruder_measurements[0]+5 ; Set standard retract distance

if !exists(param.C) ; If not ignoring moves (Unused variable in snippet)
    var current_temp = tools[{var.lane_number}].active[0] ; Capture current tool temperature

if exists(param.B) ; Check if DC motor parameter was passed
    set var.DC_motor=param.B ; Set local DC motor flag
else
    set var.DC_motor=0 ; Default DC motor to off

; --- Buffer Management (Disarm Sensors) ---
if !exists(param.C) ; If not ignoring moves
    M581 P{global.AFC_buffer_input_numbers[0]} R-1 T{global.AFC_buffer_trigger_numbers[0]} ; Disable 'Advance' buffer trigger
    M581 P{global.AFC_buffer_input_numbers[1]} R-1 T{global.AFC_buffer_trigger_numbers[1]} ; Disable 'Trail' buffer trigger
    M400 ; Wait for command execution
    M950 J{global.AFC_buffer_input_numbers[0]} C"nil" ; Unmap 'Advance' buffer pin
    M950 J{global.AFC_buffer_input_numbers[1]} C"nil" ; Unmap 'Trail' buffer pin

; --- LED Status Update ---
set global.AFC_LED_array[{var.lane_number}]=2 ; Set lane LED to Blue (Busy/Active)

; --- Hotend Retraction ---
M83 ; Ensure relative extrusion mode
G1 E{-var.retract} F600 ; Retract filament from hotend melt zone
M400 ; Wait for move completion

; --- Hardware Unmapping ---
M591 D1 P0 ; Disable filament monitor D1
M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B0 ; Unmap extruder drive for this lane
M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number} ; Map lane motor to temporary axis
G92 'f{global.AFC_lane_total_length[var.lane_number]} ; Set temporary 'F' axis position to known length

; --- Main Retraction Sequence ---
if var.DC_motor==1 ; If DC motor assist is enabled
    M98 P"0:/sys/AFC/Motors/dc_motors.g" A"R" B{var.lane_number} ; Activate DC motor in Reverse
    M400 ; Wait for activation

; Unload Method 0: Sensor-based Retraction
if global.AFC_features[9] == 0
    M574 'f1 P{"!"^global.AFC_hub_switch} S1 ; Configure F-axis endstop to inverted hub switch
    G92 'f20000 ; Preset F position
    G1 H4 'f-20000 F{global.AFC_load_retract_speed[1]*60} ; Homing move to retract until hub sensor triggers
    G91 ; Relative positioning
    G1 'f{-global.AFC_hub_retract_distance} F{global.AFC_load_retract_speed[1]*60} ; Retract further to clear hub
    G90 ; Absolute positioning
    M574 'f1 P"nil" S1 ; Clear F-axis endstop configuration
    M400 ; Wait for moves

; Unload Method 1: Distance-based Retraction
elif global.AFC_features[9] == 1
    G92 'f{global.AFC_lane_total_length[var.lane_number]} ; Reset F position
    M400 ; Wait
    G1 'f{global.AFC_lane_first_length[{var.lane_number}]} F{global.AFC_load_retract_speed[1]*60} ; Retract to 'first load' position
M400 ; Wait

if var.DC_motor==1 ; If DC motor was used
    M98 P"0:/sys/AFC/Motors/dc_motors.g" A"O" B{var.lane_number} ; Turn off DC motor
M400 ; Wait

; --- Safety Check (Method 1 Only) ---
if global.AFC_features[9] == 1 ; If distance-based method was used
    M574 'f2 S1 P{global.AFC_hub_switch} ; Set F max endstop to hub switch
    G1 H4 'f300 F{global.AFC_load_retract_speed[0]*60} ; Short homing move forward to verify sensor state
    G91 ; Relative positioning
    G1 'f{-global.AFC_hub_retract_distance+10} F{global.AFC_load_retract_speed[1]*60} ; Final clearing retract
    G90 ; Absolute positioning
    M574 'f1 P"nil" S1 ; Clear endstop
    M400 ; Wait

; --- Final Cleanup ---
set global.AFC_LED_array[{var.lane_number}]=1 ; Set lane LED to Green (Ready)
M98 P"0:/sys/AFC/LEDs.g" ; Update physical LEDs
M584 P{var.total_axis-1} ; Hide temporary 'F' axis
M400 ; Wait

; --- Time Calculation and Output ---
set var.tfree_time1=state.upTime ; Capture finish time
set var.time=var.tfree_time1-var.tfree_time ; Calculate total seconds
set var.time_minutes=floor(var.time/60) ; Calculate minutes
set var.time_seconds=var.time-(var.time_minutes*60) ; Calculate remaining seconds

if !exists(param.C) ; If output is not suppressed
    echo "The tool unload time was "^var.time^" seconds ("^var.time_minutes^" minutes