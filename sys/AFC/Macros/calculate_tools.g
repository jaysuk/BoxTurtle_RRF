; === calculate_tools.g - extruders and tools for the AFC lanes (called once at boot, after the user files) ===
; Model (ARCHITECTURE.md 1.2): a unit feeds one printer tool (tool_and_motion[u][0], e.g. the left or right head of an IDEX
; printer). Every printer tool that has AFC units gets its own AFC extruder, appended after the printer's own extruders in
; order of first use (global.AFC_head_extruder[printerTool]). Every lane becomes one RRF tool numbered like Tool_to_AFC,
; with the heater, fans, axis mapping and offsets of the printer tool its unit feeds, and drives
; {the printer tool's extruders..., the head's AFC extruder}.
; The printer's own tools were snapshotted by gather_machine_info.g before this file redefines tools 0..N-1.

var curTool = 0
var curUnit = 0
var pt = 0                                          ; printer tool that the current unit feeds
var heads = 0                                       ; number of printer tools that have AFC units
var found = false
var k = 0
var e = 0
var u = 0
var n_printer = #global.Machine_extruder_info       ; the printer's own extruders come first
var head_tool = vector(#global.AFC_unit_CAN_ids, -1) ; printer tool of the k-th head
var head_unit = vector(#global.AFC_unit_CAN_ids, 0)  ; first unit that feeds the k-th head (its lane 0 gives the placeholder driver)

; --- Which printer tools have AFC units (in order of first use) ---
while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set var.pt = global.tool_and_motion[var.curUnit][0]
    if var.pt < 0 || var.pt >= #global.Machine_actual_tools
        M118 S{"AFC: unit "^var.curUnit^" feeds printer tool "^var.pt^" which does not exist - using tool 0"}
        set var.pt = 0
        set global.tool_and_motion[var.curUnit][0] = 0
    set var.found = false
    while iterations < var.heads
        if var.head_tool[iterations] == var.pt
            set var.found = true
    if !var.found
        set var.head_tool[var.heads] = var.pt
        set var.head_unit[var.heads] = var.curUnit
        set global.AFC_head_extruder[var.pt] = var.n_printer + var.heads
        set var.heads = var.heads + 1

if !exists(global.multiple_tools)
    global multiple_tools = false
set global.multiple_tools = var.heads > 1

; --- Extruders: the printer's own plus one AFC extruder per head ---
; 0 = acceleration, 1 = current, 2 = driver, 3 = jerk (OM mm/s), 4 = microstepping, 5 = speed (OM mm/s), 6 = steps per mm  (Machine_extruder_info)
; AFC_steppers: 0 = driver, 1 = direction, 2 = microsteps, 3 = steps per mm, 4 = current, 5 = jerk, 6 = max speed, 7 = acceleration
var n = var.n_printer + var.heads
var driver = vector(var.n, 0)
var accel = vector(var.n, 0)
var current = vector(var.n, 0)
var jerk = vector(var.n, 0)
var stepping = vector(var.n, 0)
var speed = vector(var.n, 0)
var stepspermm = vector(var.n, 0)

while iterations < var.n_printer
    set var.accel[iterations] = global.Machine_extruder_info[iterations][0]
    set var.current[iterations] = global.Machine_extruder_info[iterations][1]
    set var.driver[iterations] = global.Machine_extruder_info[iterations][2]
    ; OM extruder jerk/speed are mm/s; M566/M203 take mm/min
    set var.jerk[iterations] = global.Machine_extruder_info[iterations][3] * 60
    set var.stepping[iterations] = global.Machine_extruder_info[iterations][4][1]
    set var.speed[iterations] = global.Machine_extruder_info[iterations][5] * 60
    set var.stepspermm[iterations] = global.Machine_extruder_info[iterations][6]

while iterations < var.heads
    set var.k = iterations
    set var.u = var.head_unit[var.k]
    set var.e = var.n_printer + var.k
    set var.driver[var.e] = global.AFC_steppers[var.u][0][0]
    set var.accel[var.e] = global.AFC_steppers[var.u][0][7]
    set var.current[var.e] = global.AFC_steppers[var.u][0][4]
    set var.jerk[var.e] = global.AFC_steppers[var.u][0][5] * 60
    set var.stepping[var.e] = global.AFC_steppers[var.u][0][2]
    set var.speed[var.e] = global.AFC_steppers[var.u][0][6] * 60
    set var.stepspermm[var.e] = global.AFC_steppers[var.u][0][3]

M584 E{var.driver}
M350 E{var.stepping}
M92 E{var.stepspermm}
M906 E{var.current}
M566 E{var.jerk}
M203 E{var.speed}
M201 E{var.accel}
M83

; --- Tool Definition ---
; One tool per lane. The mix (M567) is set by extruder_setup.g when a lane is loaded.
var drives = 0
var offsets = 0
while iterations < global.AFC_unit_total_available_lanes
    set var.curTool = iterations
    set var.curUnit = global.Tool_to_AFC[var.curTool][0]
    set var.pt = global.tool_and_motion[var.curUnit][0]
    set var.drives = vector(#global.Machine_actual_tools[var.pt][0] + 1, 0)
    while iterations < #global.Machine_actual_tools[var.pt][0]
        set var.drives[iterations] = global.Machine_actual_tools[var.pt][0][iterations]
    set var.drives[#global.Machine_actual_tools[var.pt][0]] = global.AFC_head_extruder[var.pt]
    set var.offsets = global.Machine_actual_tools[var.pt][4]
    ; Heater, fans, axis mapping (IDEX: e.g. U also moves X) and offsets of the printer tool this lane's unit feeds
    M563 P{var.curTool} D{var.drives} H{global.Machine_actual_tools[var.pt][2]} F{global.Machine_actual_tools[var.pt][1]} X{global.Machine_actual_tools[var.pt][3][0]} Y{global.Machine_actual_tools[var.pt][3][1]}
    G10 P{var.curTool} X{var.offsets[global.Machine_axis_number[0]]} Y{var.offsets[global.Machine_axis_number[1]]} Z{var.offsets[global.Machine_axis_number[2]]}
    G10 P{var.curTool} R0 S0                        ; Set Tool standby (R) and active (S) temperatures to 0°C.
