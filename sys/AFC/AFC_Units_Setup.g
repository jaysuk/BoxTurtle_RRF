;░█▀▄░█▀█░░░█▀█░█▀█░▀█▀░░░█▀▀░█▀▄░▀█▀░▀█▀░░░█▀█░█▀█░█▀▀░▀█▀░░░█░█░█▀▀░█▀▄░█▀▀░█░█░█
;░█░█░█░█░░░█░█░█░█░░█░░░░█▀▀░█░█░░█░░░█░░░░█▀▀░█▀█░▀▀█░░█░░░░█▀█░█▀▀░█▀▄░█▀▀░▀░▀░▀
;░▀▀░░▀▀▀░░░▀░▀░▀▀▀░░▀░░░░▀▀▀░▀▀░░▀▀▀░░▀░░░░▀░░░▀░▀░▀▀▀░░▀░░░░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀

; Please rename AFC_Unit_Count.example to AFC_Unit_Count.g to set the CAN address
; and number of lanes per unit as this file is included as part of the release
; and the settings will get overridden!!!!

if fileexists(0:/sys/AFC/AFC_Unit_Count.g)
    M98 P"0:/sys/AFC/AFC_Unit_Count.g"
else
    ; Array to store CAN addresses for up to 8 BoxTurtles. 
    ; 0 = Not Installed. 
    ; Example: Unit 1 is at CAN 119.
    global AFC_unit_CAN_ids = {119,}

    ; Array defining the number of lanes available on each specific BoxTurtle unit.
    global AFC_unit_total_lanes = {4,}

; Please use AFC_user_vars.g instead to override any of these settings 
; as this file is included as part of each release and your settings will be overridden!!!!

; --- Helper Variables for Iteration ---
; These variables are used as counters and temporary storage during the setup loops.
var curLane = 0
var curUnit = 0
var triggerStartNumber = 2
var triggerInputStartNumber = 0
var lastUnit = #global.AFC_unit_CAN_ids - 1
var driver_start_number = 0.0
var SLP_start_number = 0
var dc1_start_number = 0
var dc2_start_number = 0
var ps_start_number = 0
var psp = ""
var ls_start_number = 0
var lsp = ""
var tn_start_number = 0
var tnsp = ""
var hub_start_number = 0
var hsp = ""

; These counters persist across unit iterations to ensure unique IDs system-wide
var trigger_count = 0
var trigger_input_count = 0
var bufferStartNumber = 0
var bufferInputStartNumber = 0
var hubInputStartNumber = 0
var unloadInputStartNumber = 0

; --- Calculate Total System Capacity ---
; Iterates through all units to calculate the grand total of available filament lanes.
global AFC_unit_total_available_lanes = 0
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_unit_total_available_lanes = global.AFC_unit_total_available_lanes + global.AFC_unit_total_lanes[iterations]

; --- Map Tools to Specific Units/Lanes ---
; Creates a mapping vector where the index corresponds to a system-wide tool number (0, 1, 2...)
; and the value is a pair {Unit_Index, Lane_Index}.
; This allows finding "Unit 0, Lane 3" just by asking for "Tool 3".
global Tool_to_AFC = vector(global.AFC_unit_total_available_lanes, {0, 0})
global AFC_lane_to_tool = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.AFC_lane_to_tool[iterations] = vector(global.AFC_unit_total_lanes[var.curUnit], 0)
set var.curLane = 0
set var.curUnit = 0
while iterations < global.AFC_unit_total_available_lanes
    set global.Tool_to_AFC[iterations][0] = var.curUnit
    set global.Tool_to_AFC[iterations][1] = var.curLane
    set global.AFC_lane_to_tool[var.curUnit][var.curLane] = iterations
    set var.curLane = var.curLane + 1
    ; If we exceed lanes in current unit, move to next unit
    if var.curLane >= global.AFC_unit_total_lanes[var.curUnit]
        set var.curUnit = var.curUnit + 1
        set var.curLane = 0

; Select the tool number and motion system to assign to each AFC
; 0 = machine tool number
; 1 = motion system
global tool_and_motion = vector(#global.AFC_unit_CAN_ids, {0, 0})

; --- Temperature Config ---
; Stores extruder temperature settings per global lane index.
global AFC_extruder_temp = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_extruder_temp[iterations] = vector(global.AFC_unit_total_lanes[iterations], 0) 

; This sets the mainboard type
; Needed due to interrupts on STM32 Boards
; 0 = AFC-Lite v1.0 or v1.1
; 1 = Longboi
global AFC_mainboard = vector(#global.AFC_unit_CAN_ids, 0)

; --- Stepper Motor Configuration ---
; Generates a nested structure for stepper settings per unit and lane.
; Dynamically calculates the driver CAN address (e.g. 119.0, 119.1) based on the unit ID.
global AFC_steppers = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    ; Initialize vector with default stepper settings
    set global.AFC_steppers[var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit], {0, 0, 16, 682, 1000, 60, 60, 3000})
    ; 0 = driver number
    ; 1 = driver direction
    ; 2 = microsteps
    ; 3 = steps per mm
    ; 4 = current
    ; 5 = jerk
    ; 6 = max speed
    ; 7 = acceleration
    set var.driver_start_number = 0.0
    set var.curLane = 0
    while var.curLane < global.AFC_unit_total_lanes[var.curUnit]
        ; Construct Driver ID: CAN_ID + Driver_Index + Float_Correction
        set global.AFC_steppers[var.curUnit][var.curLane][0] = global.AFC_unit_CAN_ids[var.curUnit]+var.driver_start_number+0.0001
        set var.driver_start_number = var.driver_start_number + 0.1
        set var.curLane = var.curLane + 1

; --- Speed & Axis Limits ---
global AFC_load_retract_speed = vector(#global.AFC_unit_CAN_ids, {35, 35, 5})
global AFC_max_min_axes = vector(#global.AFC_unit_CAN_ids, {-500, 20000})

; --- Trigger Allocation ---
; Assigns sequential trigger numbers to every lane across all units.
; Each lane gets two triggers (likely for filament presence/runout states).
global AFC_trigger_numbers = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.AFC_trigger_numbers[var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit], 0)
    set var.curLane = 0
    while var.curLane < global.AFC_unit_total_lanes[var.curUnit]
        set global.AFC_trigger_numbers[var.curUnit][var.curLane] = var.triggerStartNumber
        set var.triggerStartNumber = var.triggerStartNumber + 1
        set var.curLane = var.curLane + 1
        ; Update the continuous counter so the next unit starts where this one left off
        set var.trigger_count = var.triggerStartNumber

; --- Buffer Trigger Allocation ---
; Calculates trigger numbers for the buffer, starting immediately after the LAST lane trigger used above.
global AFC_buffer_trigger_numbers = vector(#global.AFC_unit_CAN_ids, {0, 0})
set var.bufferStartNumber = var.trigger_count
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_buffer_trigger_numbers[iterations][0] = var.bufferStartNumber
    set global.AFC_buffer_trigger_numbers[iterations][1] = var.bufferStartNumber + 1
    set var.bufferStartNumber = var.bufferStartNumber + 2

; --- Trigger Input Numbers ---
; Assigns Logical Input numbers (P parameter in M950/M581) sequentially per lane.
global AFC_trigger_input_numbers = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.AFC_trigger_input_numbers[var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit], 0)
    set var.curLane = 0
    while var.curLane < global.AFC_unit_total_lanes[var.curUnit]
        set global.AFC_trigger_input_numbers[var.curUnit][var.curLane] = var.triggerInputStartNumber
        set var.triggerInputStartNumber = var.triggerInputStartNumber + 1
        ; Update continuous counter for next block
        set var.trigger_input_count = var.triggerInputStartNumber
        set var.curLane = var.curLane + 1

; --- Buffer Input Numbers ---
; Assigns Input numbers for buffer sensors, continuing from the last lane input.
global AFC_buffer_input_numbers = vector(#global.AFC_unit_CAN_ids, {0, 0})
set var.bufferInputStartNumber = var.trigger_input_count
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_buffer_input_numbers[iterations][0] = var.bufferInputStartNumber
    set global.AFC_buffer_input_numbers[iterations][1] = var.bufferInputStartNumber + 1
    set var.bufferInputStartNumber = var.bufferInputStartNumber + 2

; --- Hub & Unload Input Numbers ---
; Assigns Input numbers for the Hub switch and Unload sensors.
global AFC_hub_input_numbers = vector(#global.AFC_unit_CAN_ids, 0)
set var.hubInputStartNumber = global.AFC_buffer_input_numbers[var.lastUnit][1] + 1
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_hub_input_numbers[iterations] = var.hubInputStartNumber
    set var.hubInputStartNumber = var.hubInputStartNumber + 1

global AFC_unload_input_numbers = vector(#global.AFC_unit_CAN_ids, 0)
set var.unloadInputStartNumber = global.AFC_hub_input_numbers[var.lastUnit] + 1
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_unload_input_numbers[iterations] = var.unloadInputStartNumber
    set var.unloadInputStartNumber = var.unloadInputStartNumber + 1

; --- Distance Configuration ---
global AFC_hub_retract_distance = vector(#global.AFC_unit_CAN_ids, 25)
global AFC_hub_load_distance = vector(#global.AFC_unit_CAN_ids, {35, 5})
global AFC_tn_retract_distance = vector(#global.AFC_unit_CAN_ids, 15)

; --- Feature Configuration ---
global AFC_features=vector(#global.AFC_unit_CAN_ids, {true, 0, 0})
; 0 = use dc motors (true/false)
; 1 = unload method (0=hubswitch, 1=lengths)
; 2 = load method (0=Use turtleneck, 1=lengths, 2=Use preload switch)

; --- Pin Definitions (Dynamic Construction) ---

; 1.SLP Pins
; Constructs pin names based on CAN address: "119.SLP1", "119.SLP2", etc.
global AFC_SLP_pins = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.AFC_SLP_pins[var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit], "SLP")
    set var.curLane = 0
    set var.SLP_start_number = 1
    while var.curLane < global.AFC_unit_total_lanes[var.curUnit]
        set global.AFC_SLP_pins[var.curUnit][var.curLane] = global.AFC_unit_CAN_ids[var.curUnit] ^ "." ^ global.AFC_SLP_pins[var.curUnit][var.curLane] ^ var.SLP_start_number
        set var.SLP_start_number = var.SLP_start_number + 1
        set var.curLane = var.curLane + 1

; 2. DC Motor Pins
; Constructs pairs of pins for H-bridge control (e.g., "119.dc11", "119.dc21")
global AFC_DC_pins = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.AFC_DC_pins[var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit], {"dc", "dc"})
    set var.curLane = 0
    set var.dc1_start_number = 11
    set var.dc2_start_number = 21
    while var.curLane < global.AFC_unit_total_lanes[var.curUnit]
        set global.AFC_DC_pins[var.curUnit][var.curLane][0] = global.AFC_unit_CAN_ids[var.curUnit] ^ "." ^ global.AFC_DC_pins[var.curUnit][var.curLane][0] ^ var.dc1_start_number
        set global.AFC_DC_pins[var.curUnit][var.curLane][1] = global.AFC_unit_CAN_ids[var.curUnit] ^ "." ^ global.AFC_DC_pins[var.curUnit][var.curLane][1] ^ var.dc2_start_number
        set var.dc1_start_number = var.dc1_start_number + 1
        set var.dc2_start_number = var.dc2_start_number + 1
        set var.curLane = var.curLane + 1

; 3. Prep Switches
; Inverted logic (^!) pins for prep switches
global AFC_prep_switch = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.AFC_prep_switch[var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit], "SW")
    set var.curLane = 0
    set var.ps_start_number = 2
    set var.psp = "^!"
    while var.curLane < global.AFC_unit_total_lanes[var.curUnit]
        set global.AFC_prep_switch[var.curUnit][var.curLane] = var.psp ^ global.AFC_unit_CAN_ids[var.curUnit] ^ "." ^ global.AFC_prep_switch[var.curUnit][var.curLane] ^ var.ps_start_number
        set var.ps_start_number = var.ps_start_number + 1
        set var.curLane = var.curLane + 1

; 4. Load Switches
; Pull-up logic (^) for load switches
global AFC_load_switch = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.AFC_load_switch[var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit], "SW")
    set var.curLane = 0
    set var.ls_start_number = 7
    set var.lsp = "^"
    while var.curLane < global.AFC_unit_total_lanes[var.curUnit]
        set global.AFC_load_switch[var.curUnit][var.curLane] = var.lsp ^ global.AFC_unit_CAN_ids[var.curUnit] ^ "." ^ global.AFC_load_switch[var.curUnit][var.curLane] ^ var.ls_start_number
        set var.ls_start_number = var.ls_start_number + 1
        set var.curLane = var.curLane + 1

; 5. TN (Turtleneck?) Switches
global AFC_TN_switches = vector(#global.AFC_unit_CAN_ids, {"SW", "SW"})
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set var.tn_start_number = 11
    set var.tnsp = ""
    set global.AFC_TN_switches[var.curUnit][0] = var.tnsp ^ global.AFC_unit_CAN_ids[var.curUnit] ^ "." ^ global.AFC_TN_switches[var.curUnit][0] ^ var.tn_start_number
    set global.AFC_TN_switches[var.curUnit][1] = var.tnsp ^ global.AFC_unit_CAN_ids[var.curUnit] ^ "." ^ global.AFC_TN_switches[var.curUnit][1] ^ (var.tn_start_number + 1)

; 6. Hub Switches
global AFC_hub_switch = vector(#global.AFC_unit_CAN_ids, "SW")
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set var.hub_start_number = 1
    set var.hsp = "^"
    set global.AFC_hub_switch[var.curUnit] = var.hsp ^ global.AFC_unit_CAN_ids[var.curUnit] ^ "." ^ global.AFC_hub_switch[var.curUnit] ^ var.hub_start_number

global AFC_neopixel_port_qty = vector(#global.AFC_unit_CAN_ids, 1)

; 0 = neopixel pin string
; 1 = LED strip number (logical index)
; 2 = LED Type
; 3 = No. of LEDs in the strip
; 4 = No. of LEDs per lane
; 5 = Reverse LEDs (true or false)
; 6 = LED Brightness (0-255)
global AFC_neopixel = vector(#global.AFC_unit_CAN_ids, 0)

var neopixel_start_number = 0
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.AFC_neopixel[var.curUnit] = vector(7, 0)
    set global.AFC_neopixel[var.curUnit][0] = vector(global.AFC_neopixel_port_qty[var.curUnit], "")
    set global.AFC_neopixel[var.curUnit][1] = vector(global.AFC_neopixel_port_qty[var.curUnit], 0)
    set global.AFC_neopixel[var.curUnit][2] = vector(global.AFC_neopixel_port_qty[var.curUnit], 2) ; Type 2 default
    set global.AFC_neopixel[var.curUnit][3] = vector(global.AFC_neopixel_port_qty[var.curUnit], 4)
    set global.AFC_neopixel[var.curUnit][4] = vector(global.AFC_neopixel_port_qty[var.curUnit], 1)
    set global.AFC_neopixel[var.curUnit][5] = vector(global.AFC_neopixel_port_qty[var.curUnit], false)
    set global.AFC_neopixel[var.curUnit][6] = vector(global.AFC_neopixel_port_qty[var.curUnit], 255)

    var port_idx = 0
    while var.port_idx < global.AFC_neopixel_port_qty[var.curUnit]
        set global.AFC_neopixel[var.curUnit][0][var.port_idx] = global.AFC_unit_CAN_ids[var.curUnit] ^ ".neopixel" ^ (var.port_idx + 1)
        set global.AFC_neopixel[var.curUnit][1][var.port_idx] = var.neopixel_start_number
        set var.neopixel_start_number = var.neopixel_start_number + 1
        set var.port_idx = var.port_idx + 1

; --- Output Pin Index ---
global AFC_dcm_out_no = {0, 1, 2}

; ########## Lane Info ############

; Tracks the state of every lane in the system.
global AFC_lanes = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    ; 0 = whether the lane is loaded (true/false)
    ; 1 = first lane length (mm)
    ; 2 = total lane length (mm)
    ; 3 = lane is continuous?
    ; 4 = filament type {Type, Color}
    set global.AFC_lanes[iterations] = vector(global.AFC_unit_total_lanes[iterations], {false, 0, 0, 0, {"None", "None"}})

; ########## Additional Info ##########

; Tracks LED colors/status per lane.
global AFC_LED_array = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_LED_array[iterations] = vector(global.AFC_unit_total_lanes[iterations], 0)

; ########## Spoolman Support #######

; Stores Spoolman IDs for integration per lane.
global spoolman = vector(#global.AFC_unit_CAN_ids, "Unit ")
while iterations < #global.AFC_unit_CAN_ids
    set global.spoolman[iterations] = vector(global.AFC_unit_total_lanes[iterations], {0, false})

; ########## Button Lists (Merged into M291_data) ##########

; Initialize global data structure for M291 Dialogs
; Index [0] = Unit Names
; Index [1] = Lane Names
; Index [2] = Lane Names + "All" option
global M291_data = vector(3, 0)

; 1. Generate List of Unit Names ("Unit 0", "Unit 1"...)
set global.M291_data[0] = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.M291_data[0][var.curUnit] = "Unit " ^ var.curUnit

; 2. Generate List of Lane Names per Unit ("Lane 0", "Lane 1"...)
set global.M291_data[1] = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.M291_data[1][var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit], "Lane ")
    set var.curLane = 0
    while var.curLane < global.AFC_unit_total_lanes[var.curUnit]
        set global.M291_data[1][var.curUnit][var.curLane] = global.M291_data[1][var.curUnit][var.curLane] ^ var.curLane
        set var.curLane = var.curLane + 1

; 3. Generate List of Lane Names per Unit INCLUDING "All" option
set global.M291_data[2] = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set global.M291_data[2][var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit] + 1, "Lane ")
    set var.curLane = 0
    while var.curLane < global.AFC_unit_total_lanes[var.curUnit]
        set global.M291_data[2][var.curUnit][var.curLane] = global.M291_data[2][var.curUnit][var.curLane] ^ var.curLane
        set var.curLane = var.curLane + 1
    ; Append "All" to the end of the vector
    set global.M291_data[2][var.curUnit][global.AFC_unit_total_lanes[var.curUnit]] = "All"