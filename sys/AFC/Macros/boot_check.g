; === AFC boot state check (boot_check.g) ===
; Run once by sys/daemon.g shortly after boot (AFC_boot_check_pending). It never reselects anything silently:
; if a tool was loaded at power-off, or a hub switch is occupied, it asks the user what to do.
; The daemon channel can wait for the answer; a blocking M291 in config.g would stall the boot.

var tool = global.AFC_loaded_tool                                   ; restored from Status/status.g
var unit_number = 0
var lane_number = 0
var hub_unit = -1                                                   ; first unit whose hub switch is occupied
var u = 0
var choice = 2                                                      ; answer of the dialog (2 = leave it)

; An old status.g (from before this check existed) reselects the tool itself - treat that as "was loaded" too
if var.tool == -1 && move.motionSystems[0].currentTool != -1
    set var.tool = move.motionSystems[0].currentTool

; --- Read every hub switch (bind, read, free) ---
while iterations < #global.AFC_unit_CAN_ids
    set var.u = iterations
    M950 J{global.AFC_hub_input_numbers[var.u]} C{global.AFC_hub_switch[var.u]}
    G4 P100
    if sensors.gpIn[global.AFC_hub_input_numbers[var.u]].value != 0 && var.hub_unit == -1
        set var.hub_unit = var.u
    M950 J{global.AFC_hub_input_numbers[var.u]} C"nil"

if var.tool == -1 && var.hub_unit == -1
    M99                                                             ; nothing loaded, nothing in a hub: all clean

; --- A tool was loaded at power-off ---
if var.tool != -1 && var.tool < #global.AFC_tool_map
    set var.unit_number = global.AFC_tool_map[var.tool][0]
    set var.lane_number = global.AFC_tool_map[var.tool][1]
    M291 P{"Tool "^var.tool^" (Unit "^var.unit_number^" Lane "^var.lane_number^") was loaded at power-off. What should happen to it?"} R"AFC boot check" K{"Keep it loaded", "Unload it now", "Leave it - I will sort it out"} S4 J2
    if result != -1
        set var.choice = input
    if var.choice == 2                                              ; cancelled or "leave it"
        set global.AFC_loaded_tool = -1
        set global.AFC_LED_array[var.unit_number][var.lane_number] = 4   ; yellow = needs attention
        M98 P"0:/sys/AFC/Macros/leds.g"
        M98 P"0:/sys/AFC/Macros/save_status.g"
        M99
    ; Keep or unload: select the tool WITHOUT running tpre/tpost (P0) and restore its extruder mapping
    T{var.tool} P0
    M98 P"0:/sys/AFC/Macros/tool_load_no_files.g" A{var.tool}
    M400
    if var.choice == 1                                              ; unload it now: a normal T-1 (tfree heats, cuts, retracts)
        T-1
    M98 P"0:/sys/AFC/Macros/save_status.g"
    M99

; --- No tool recorded, but filament is sitting in a hub ---
M291 P{"Filament is in the hub of Unit "^var.hub_unit^" but no tool is recorded as loaded."} R"AFC boot check" K{"Unload a lane now", "Leave it"} S4 J2
if result != -1 && input == 0
    M98 P"0:/macros/Lane - Unload to Hub"
