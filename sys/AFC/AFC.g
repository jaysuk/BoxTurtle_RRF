; === AFC Main Initialization Script (AFC.g) ===
; Purpose: Loads configurations, initializes hardware (motors, tools, LEDs), 
; and restores the saved system state.

var file_address = ""
var curLane = 0
var curUnit = 0
var count = 0

; --- Configuration Loading ---
if !exists(global.AFC_settings_loaded)                                                                          ; Checks if the primary AFC settings have been loaded into global variables.
    M98 P"0:/sys/AFC/Macros/gather_machine_info.g"
    M98 P"0:/sys/AFC/AFC_units.g"                                                                               ; Load Unit Definitions
    M98 P"0:/sys/AFC/Machine_vars.g"                                                                            ; Load Machine Settings
    global AFC_settings_loaded = true                                                                           ; Set a flag to prevent re-execution of the default settings file on subsequent runs.

; --- User Overrides (Unit Specific) ---
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set var.file_address = "0:/sys/AFC/"^var.curUnit^"/AFC_user_vars.g"
    if fileexists(var.file_address)                                                                             ; Checks for the existence of an optional user override file.
        M98 P{var.file_address} A{var.curUnit}                                                                   ; Load per-unit user overrides

; --- User Overrides (Machine Specific) ---
if fileexists("0:/sys/AFC/Machine/Machine_user_vars.g")                                                         ; Checks for the existence of an optional user override file.
    M98 P"0:/sys/AFC/Machine/Machine_user_vars.g"                                                               ; Load machine user overrides

; --- Motor Driver Setup ---
; Initialize the driver direction (M569) for every motor in every unit.
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    M98 P"0:/sys/AFC/Macros/AFC_setup.g" A{var.curUnit}

M98 P"0:/sys/AFC/Macros/calculate_tools.g"

; --- State Restoration (Persistence) ---
; Loads the saved status of lanes, lengths, and colors from the Status folder.
if fileexists("0:/sys/AFC/Status/status.g")
    M98 P"0:/sys/AFC/Status/status.g"

; --- LED Configuration ---
; Configures the Neopixel strips for each unit.
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    while iterations < #global.AFC_neopixel[var.curUnit][0]
        set var.count = iterations
        M950 E{global.AFC_neopixel[var.curUnit][1][var.count]} C{global.AFC_neopixel[var.curUnit][0][var.count]} T{global.AFC_neopixel[var.curUnit][2][var.count]} U{global.AFC_neopixel[var.curUnit][3][var.count]}
; M950 sets up the Neopixel strip: E is the logical index, C is the physical pin, T is the type/number of LEDs, U is the colour encoding format.

M98 P"0:/sys/AFC/Macros/leds.g"

while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set var.curLane = 0
    while var.curLane <  global.AFC_unit_total_lanes[var.curUnit]
        set global.AFC_lanes[var.curUnit][var.curLane][4][1] = global.AFC_lanes[var.curUnit][var.curLane][4][0] ; Assigns the loaded filament type to a new variable (potentially for Lane 1).
        set var.curLane = var.curLane + 1