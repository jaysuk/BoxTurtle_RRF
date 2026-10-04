; === AFC Main Initialization Script (AFC.g) ===
; Purpose: Loads configurations, initializes hardware (motors, tools, LEDs), 
; and restores the saved system state.

; The AFC log (Machine_log): keep the previous boot's file as afc.old.log
if fileexists("0:/sys/AFC/Status/afc.log")
    M471 S"0:/sys/AFC/Status/afc.log" T"0:/sys/AFC/Status/afc.old.log" D1

var file_address = ""
var curUnit = 0
var count = 0

; --- Configuration Loading ---
if !exists(global.AFC_settings_loaded)                                                                          ; Checks if the primary AFC settings have been loaded into global variables.
    M98 P"0:/sys/AFC/Macros/gather_machine_info.g"
    M98 P"0:/sys/AFC/AFC_Units_Setup.g"                                                                         ; Load Unit Definitions
    M98 P"0:/sys/AFC/Machine_Vars_Setup.g"                                                                      ; Load Machine Settings
    global AFC_settings_loaded = true                                                                           ; Set a flag to prevent re-execution of the default settings file on subsequent runs.

; --- User Overrides (Unit Specific) ---
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set var.file_address = "0:/sys/AFC/"^var.curUnit^"/AFC_user_vars.g"
    if fileexists(var.file_address)                                                                             ; Checks for the existence of an optional user override file.
        M98 P{var.file_address} A{var.curUnit}                                                                  ; Load per-unit user overrides

; --- User Overrides (Machine Specific) ---
if fileexists("0:/sys/AFC/Machine/Machine_user_vars.g")                                                         ; Checks for the existence of an optional user override file.
    M98 P"0:/sys/AFC/Machine/Machine_user_vars.g"                                                               ; Load machine user overrides

; --- Motor Driver Setup ---
; Initialize the driver direction (M569) for every motor in every unit.
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    M98 P"0:/sys/AFC/Macros/AFC_setup.g" A{var.curUnit}

M98 P"0:/sys/AFC/Macros/calculate_tools.g"

; --- Extruder Input Switch (initial unload method 1) ---
; Bound once at boot so tfree can unload with one "G1 H1 E-x" that stops when the input goes inactive (RRF 3.7 M574 E).
; J number = AFC_unload_input_numbers[0]. EVERY extruder gets it: on a mixing tool both the printer extruder and the AFC
; extruder move, and an extruder without an input endstop would get a stall-detection endstop instead (EndstopsManager).
if global.Machine_features[8] == 1 && global.Machine_extruder_switches[0] != "nil"
    M950 J{global.AFC_unload_input_numbers[0]} C{global.Machine_extruder_switches[0]}
    while iterations < #move.extruders
        M574 E{iterations} P{global.AFC_unload_input_numbers[0]}

; --- LED Configuration ---
; Configures the Neopixel strips for each unit.
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    while iterations < global.AFC_neopixel_port_qty[var.curUnit]
        set var.count = iterations
        M950 E{global.AFC_neopixel[var.curUnit][1][var.count]} C{global.AFC_neopixel[var.curUnit][0][var.count]} T{global.AFC_neopixel[var.curUnit][2][var.count]} U{global.AFC_neopixel[var.curUnit][3][var.count]}
; M950 sets up the Neopixel strip: E is the logical index, C is the physical pin, T is the type/number of LEDs, U is the colour encoding format.

; --- State Restoration (Persistence) ---
; Loads the saved status of lanes, lengths, and colors from the Status folder.
if fileexists("0:/sys/AFC/Status/status.g")
    M98 P"0:/sys/AFC/Status/status.g"

; --- Spool Tracking Restoration ---
; Restores Spool IDs to specific lanes
if fileexists("0:/sys/AFC/Status/spool_status.g")
    M98 P"0:/sys/AFC/Status/spool_status.g"
    
; Migration from the old "spoolman" name: an old spool_status.g sets global.spoolman. If it holds assignments and the new
; spool_tracking has none, copy them across and rewrite the file with the new name.
var old_found = false
var new_found = false
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    while iterations < global.AFC_unit_total_lanes[var.curUnit]
        if global.spoolman[var.curUnit][iterations][0] != -1
            set var.old_found = true
        if global.spool_tracking[var.curUnit][iterations][0] != -1
            set var.new_found = true
if var.old_found && !var.new_found
    while iterations < #global.AFC_unit_CAN_ids
        set var.curUnit = iterations
        while iterations < global.AFC_unit_total_lanes[var.curUnit]
            set global.spool_tracking[var.curUnit][iterations] = global.spoolman[var.curUnit][iterations]
    M98 P"0:/sys/AFC/Macros/spool_save_status.g"

; Restores active spool files into RAM for assigned lanes
M98 P"0:/sys/AFC/Macros/spool_read_all.g"

M98 P"0:/sys/AFC/Macros/leds.g"

; --- Low-spool warning (RRF 3.7 M581.1 expression trigger; fires when the condition turns true, only while printing) ---
if global.Machine_features[7] == 1 && global.Machine_low_spool > 0
    M581.1 T{global.AFC_lowspool_trigger} P"global.AFC_spool_left >= 0 && global.AFC_spool_left < global.Machine_low_spool" R1

; --- Boot State Check ---
; A blocking dialog in config.g would stall the boot, so sys/daemon.g runs boot_check.g once, a few seconds after boot.
set global.AFC_boot_check_pending = true

; --- Configuration Check ---
; Reports settings that would fail during a tool change (one summary box; never aborts or blocks the boot).
M98 P"0:/sys/AFC/Macros/config_check.g"
