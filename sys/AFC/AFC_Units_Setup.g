;░█▀▄░█▀█░░░█▀█░█▀█░▀█▀░░░█▀▀░█▀▄░▀█▀░▀█▀░░░█▀█░█▀█░█▀▀░▀█▀░░░█░█░█▀▀░█▀▄░█▀▀░█░█░█
;░█░█░█░█░░░█░█░█░█░░█░░░░█▀▀░█░█░░█░░░█░░░░█▀▀░█▀█░▀▀█░░█░░░░█▀█░█▀▀░█▀▄░█▀▀░▀░▀░▀
;░▀▀░░▀▀▀░░░▀░▀░▀▀▀░░▀░░░░▀▀▀░▀▀░░▀▀▀░░▀░░░░▀░░░▀░▀░▀▀▀░░▀░░░░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀

; Please rename AFC_Unit_Count.example to AFC_Unit_Count.g to set the CAN address
; and number of lanes per unit as this file is included as part of the release
; and the settings will get overridden!!!!

if fileexists("0:/sys/AFC/AFC_Unit_Count.g")
    M98 P"0:/sys/AFC/AFC_Unit_Count.g"
else
    ; Array to store CAN addresses for up to 8 BoxTurtles. 
    ; 0 = Not Installed. 
    ; Example: Unit 1 is at CAN 119.
    global AFC_unit_CAN_ids = [119]

    ; Array defining the number of lanes available on each specific BoxTurtle unit.
    global AFC_unit_total_lanes = [4]

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
global Tool_to_AFC = vector(global.AFC_unit_total_available_lanes, [0, 0])
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

; Tool -> lane map (P3-03): [t] = {u, l} = the lane that RRF tool t currently draws from. Default = Tool_to_AFC (tool t is
; lane t). The tool-change macros resolve lanes through this map; Tool_to_AFC stays the static numbering of the lanes
; ("native tool" of a lane). A tool may only be mapped to a lane of a unit that feeds the same printer head.
global AFC_tool_map = vector(global.AFC_unit_total_available_lanes, [0, 0])
while iterations < global.AFC_unit_total_available_lanes
    set global.AFC_tool_map[iterations] = global.Tool_to_AFC[iterations]

; Select the tool number and motion system to assign to each AFC
; 0 = machine tool number
; 1 = motion system
global tool_and_motion = vector(#global.AFC_unit_CAN_ids, [0, 0])
; [u][0] = the printer tool (from the user's config.g) whose heater, fans, offsets and axis mapping the lanes of unit u use.
;           Units of one printer head share it; an IDEX printer uses one value per head (e.g. T0 = left, T1 = right).
; [u][1] = motion system (only 0 is supported; see ARCHITECTURE.md section 1.2)

; Each printer tool that has AFC units gets its own AFC extruder, appended after the printer's own extruders in order of
; first use. [printerTool] = OM index of that head's AFC extruder, -1 if no unit feeds the tool. Set by calculate_tools.g.
global AFC_head_extruder = vector(#global.Machine_actual_tools, -1)

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
    set global.AFC_steppers[var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit], [0, 0, 16, 682, 1000, 60, 60, 3000])
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
global AFC_load_retract_speed = vector(#global.AFC_unit_CAN_ids, [35, 35, 5])
global AFC_max_min_axes = vector(#global.AFC_unit_CAN_ids, [-500, 20000])

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
global AFC_buffer_trigger_numbers = vector(#global.AFC_unit_CAN_ids, [0, 0])
set var.bufferStartNumber = var.trigger_count
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_buffer_trigger_numbers[iterations][0] = var.bufferStartNumber
    set global.AFC_buffer_trigger_numbers[iterations][1] = var.bufferStartNumber + 1
    set var.bufferStartNumber = var.bufferStartNumber + 2

; --- Buffer Fault Triggers (P3-06) ---
; One expression trigger (M581.1) per unit that fires when BOTH buffer switches are active at once (a jam or a wiring fault).
; Numbers follow the last buffer trigger. tpost arms it, tfree deletes it.
global AFC_buffer_fault_triggers = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_buffer_fault_triggers[iterations] = var.bufferStartNumber + iterations

; Low-spool trigger (P4-05): one expression trigger (M581.1) for the whole machine, armed in AFC.g when
; spool tracking is on and Machine_low_spool > 0. It follows AFC_spool_left, which sys/daemon.g keeps up to date.
global AFC_lowspool_trigger = var.bufferStartNumber + #global.AFC_unit_CAN_ids
global AFC_spool_left = -1

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
global AFC_buffer_input_numbers = vector(#global.AFC_unit_CAN_ids, [0, 0])
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
global AFC_hub_retract_distance = vector(#global.AFC_unit_CAN_ids, 35)
; {first move, retry step}: the first move must be longer than the hub retract distance (park position is hub_retract_distance short of the hub)
global AFC_hub_load_distance = vector(#global.AFC_unit_CAN_ids, [45, 5])
global AFC_tn_retract_distance = vector(#global.AFC_unit_CAN_ids, 15)

; --- Feature Configuration ---
global AFC_features=vector(#global.AFC_unit_CAN_ids, [true, 0, 0])
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
    set global.AFC_DC_pins[var.curUnit] = vector(global.AFC_unit_total_lanes[var.curUnit], ["dc", "dc"])
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
global AFC_TN_switches = vector(#global.AFC_unit_CAN_ids, ["SW", "SW"])
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
; M950 P output numbers used for the DC motor pins (sleep, in1, in2) while a DC motor runs. They must be free: config_check.g
; warns when one of them is already defined at boot (override in AFC_user_vars.g if config.g uses P0-P2).
global AFC_dcm_out_no = [0, 1, 2]
; DC motor speed 0..1 (1 = full power, the pins stay digital) and the PWM frequency used when the speed is below 1
global AFC_dc_speed = 1.0
global AFC_dc_freq = 500
; true = the DC motor also assists while loading (tpre), not only while unloading
global AFC_dc_load_assist = false

; ########## Lane Info ############

; Tracks the state of every lane in the system.
global AFC_lanes = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    ; 0 = whether the lane is loaded (true/false)
    ; 1 = first lane length (mm)
    ; 2 = total lane length (mm)
    ; 3 = reserved (was a "continuous" flag that nothing used; the backup lane is AFC_lane_backup)
    ; 4 = filament type {Type, Color}
    set global.AFC_lanes[iterations] = vector(global.AFC_unit_total_lanes[iterations], [false, 0, 0, 0, ["None", "None"]])

; Filament colour of each lane as "#RRGGBB" ("" = none): leds.g shows it instead of green when the lane is ready.
; Set by Lane - Set Filament and Spool - Assign to Lane, cleared when the lane is unloaded. Persisted in Status/status.g.
global AFC_lane_hex = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_lane_hex[iterations] = vector(global.AFC_unit_total_lanes[iterations], "")
; Result of hex_to_rgb.g: [r, g, b] or [-1, -1, -1]
global AFC_rgb = [-1, -1, -1]

; Infinite spool (P3-04): [u][l] = the native tool number of the lane that takes over when lane {u,l} runs out, -1 = none.
; The backup lane must serve the same printer head. Persisted in Status/status.g.
global AFC_lane_backup = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_lane_backup[iterations] = vector(global.AFC_unit_total_lanes[iterations], -1)

; ########## Additional Info ##########

; Tracks LED colors/status per lane.
global AFC_LED_array = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set global.AFC_LED_array[iterations] = vector(global.AFC_unit_total_lanes[iterations], 0)

; ########## Spool Tracking #######

; Spool assigned to each lane: [u][l] = {spoolId (-1 = none), trackingActive}. Persisted in Status/spool_status.g.
global spool_tracking = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set global.spool_tracking[iterations] = vector(global.AFC_unit_total_lanes[iterations], [-1, false])

; DEPRECATED migration shim: the old name of spool_tracking. An old Status/spool_status.g sets this one; AFC.g copies it
; into spool_tracking and rewrites the file. Remove together with the shim in AFC.g in a later release.
global spoolman = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set global.spoolman[iterations] = vector(global.AFC_unit_total_lanes[iterations], [-1, false])

; Empty spool record - copy this whenever a spool slot is cleared so the record always has all 12 fields
; Data schema: {SpoolID, FilamentType, Color, Manufacturer, InitialLength, RemainingLength, DateFirstUsed, DateLastUsed, HexColor, Price, EmptyWeight, Density}
if !exists(global.spool_empty_record)
    global spool_empty_record = [-1, "", "", "", 0.0, 0.0, "", "", "", 0.0, 0.0, 1.24]

; Temporary holding variable for reading spool files from SD
if !exists(global.spool_load_temp)
    global spool_load_temp = global.spool_empty_record

; Active Spool Data (only populated for lanes with a loaded spool)
; Data schema: {SpoolID, FilamentType, Color, Manufacturer, InitialLength, RemainingLength, DateFirstUsed, DateLastUsed, HexColor, Price, EmptyWeight, Density}
global spool_active_data = vector(#global.AFC_unit_CAN_ids, 0)
while iterations < #global.AFC_unit_CAN_ids
    set global.spool_active_data[iterations] = vector(global.AFC_unit_total_lanes[iterations], global.spool_empty_record)

; Baseline extrusion length snapshotted when a tool is loaded (indexed by AFC tool; AFC tools are 0..N-1)
global spool_extrusion_baseline = vector(global.AFC_unit_total_available_lanes, 0.0)

; Accumulated un-saved extrusion length for daemon.g to trigger periodic SD writes
global spool_unsaved_extrusion = vector(global.AFC_unit_total_available_lanes, 0.0)

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

global AFC_time = 0

; OM index of the temporary 'f axis. Set by lane_motion_begin.g (-1 until 'f exists)
global AFC_f_axis = -1

global AFC_debug = false

; Tool that was loaded at the last status save (-1 = none), restored from Status/status.g at boot. boot_check.g asks what to do with it.
global AFC_loaded_tool = -1
; Net distance (mm) tip_form.g pulled the filament back; tfree retracts only the rest
global AFC_tip_retracted = 0
; Counts every afc_error.g call. A caller that runs a nested step (T-1, T<n>) compares it before/after to learn whether that step failed.
global AFC_error_count = 0
; true from the end of AFC.g until sys/daemon.g has run boot_check.g
global AFC_boot_check_pending = false