var curLane = 0
var curUnit = 0
var count = 0
var driver = 0
var total_extruders = 0
var current = 0
var accel = 0
var jerk = 0
var stepping = 0
var speed = 0
var stepspermm = 0
var extra_to_add = 0
var different_tool = 0
var different_tool_check = true
var different_tool_start = 0
var curTool = 0
var heaters = 0
var fans = 0

; Iterate through each tool_and_motion array to check if both 0 and 1 are present
set var.count = global.tool_and_motion[0][0]
while iterations < global.AFC_unit_total_available_lanes
    set var.curUnit = global.Tool_to_AFC[iterations][0]
    if var.count != global.tool_and_motion[var.curUnit][0]
        set var.count = var.count + 1

if var.count == global.tool_and_motion[0][0]
    if !exists(global.multiple_tools)
        global multiple_tools = false
    else
        set global.multiple_tools = false
else
    if !exists(global.multiple_tools)
        global multiple_tools = true
    else
        set global.multiple_tools = true

if global.multiple_tools
    set var.different_tool_start = global.tool_and_motion[0][0]
    while var.different_tool_check
        if var.different_tool_start != global.tool_and_motion[iterations][0]
            set var.different_tool = global.tool_and_motion[iterations][0]
            set var.different_tool_check = false

; 0 = acceleration
; 1 = current
; 2 = driver
; 3 = jerk
; 4 = microstepping
; 4a = interpolated
; 4b = value
; 5 = speed
; 6 = stepspermm
if !global.multiple_tools 
    set var.extra_to_add = 1
else
    set var.extra_to_add = var.count + 1

while iterations < #global.Machine_extruder_info
    set var.total_extruders = iterations
    if iterations == 0
        set var.driver = vector(#global.Machine_extruder_info+var.extra_to_add, 0)
        set var.accel = vector(#global.Machine_extruder_info+var.extra_to_add, 0)
        set var.current = vector(#global.Machine_extruder_info+var.extra_to_add, 0)
        set var.jerk = vector(#global.Machine_extruder_info+var.extra_to_add, 0)
        set var.stepping = vector(#global.Machine_extruder_info+var.extra_to_add, 0)
        set var.speed = vector(#global.Machine_extruder_info+var.extra_to_add, 0)
        set var.stepspermm = vector(#global.Machine_extruder_info+var.extra_to_add, 0)
    set var.accel[iterations] = global.Machine_extruder_info[iterations][0]
    set var.current[iterations] = global.Machine_extruder_info[iterations][1]
    set var.driver[iterations] = global.Machine_extruder_info[iterations][2]
    set var.jerk[iterations] = global.Machine_extruder_info[iterations][3]
    set var.stepping[iterations] = global.Machine_extruder_info[iterations][4][1]
    set var.speed[iterations] = global.Machine_extruder_info[iterations][5]
    set var.stepspermm[iterations] = global.Machine_extruder_info[iterations][6]


; 0 = driver number
; 1 = driver direction
; 2 = microsteps
; 3 = steps per mm
; 4 = current
; 5 = jerk
; 6 = max speed
; 7 = acceleration
set var.driver[var.total_extruders+1] = global.AFC_steppers[0][0][0]
set var.accel[var.total_extruders+1] = global.AFC_steppers[0][0][7]
set var.current[var.total_extruders+1] = global.AFC_steppers[0][0][4]
set var.jerk[var.total_extruders+1] = global.AFC_steppers[0][0][5] * 60
set var.stepping[var.total_extruders+1] = global.AFC_steppers[0][0][2]
set var.speed[var.total_extruders+1] = global.AFC_steppers[0][0][6] * 60
set var.stepspermm[var.total_extruders+1] = global.AFC_steppers[0][0][3]
if global.multiple_tools
    set var.driver[var.total_extruders+2] = global.AFC_steppers[var.different_tool][0][0]
    set var.accel[var.total_extruders+2] = global.AFC_steppers[var.different_tool][0][7]
    set var.current[var.total_extruders+2] = global.AFC_steppers[var.different_tool][0][4]
    set var.jerk[var.total_extruders+2] = global.AFC_steppers[var.different_tool][0][5] * 60
    set var.stepping[var.total_extruders+2] = global.AFC_steppers[var.different_tool][0][2]
    set var.speed[var.total_extruders+2] = global.AFC_steppers[var.different_tool][0][6] * 60
    set var.stepspermm[var.total_extruders+2] = global.AFC_steppers[var.different_tool][0][3]
    
M584 E{var.driver}   
M350 E{var.stepping}
M92 E{var.stepspermm}
M906 E{var.current}
M566 E{var.jerk}
M203 E{var.speed}
M201 E{var.accel}
M83

; --- Tool Definition ---
; Creates a "Tool" for every available lane in the system.
; All tools map to the same drives (D0:1). Logic in tpre.g handles the switching.

; 0 = extruder number
; 1 = fans
; 2 = heaters
while iterations < global.AFC_unit_total_available_lanes
    set var.curTool = iterations
    set var.curUnit = global.Tool_to_AFC[var.curTool][0]
    set var.curLane = global.Tool_to_AFC[var.curTool][1]
    var D = vector(#global.Machine_actual_tools[global.tool_and_motion[var.curUnit][0]][0] + 1, 0)
    while iterations < #global.Machine_actual_tools[global.tool_and_motion[var.curUnit][0]][0]
        set var.D[iterations] = global.Machine_actual_tools[global.tool_and_motion[var.curUnit][0]][0][iterations]
    set var.D[#global.Machine_actual_tools[global.tool_and_motion[var.curUnit][0]][0]] = #global.Machine_extruder_info
    var H = {global.Machine_actual_tools[global.tool_and_motion[var.curUnit][0]][2]}
    var F = {global.Machine_actual_tools[global.tool_and_motion[var.curUnit][0]][1]}
    if !global.multiple_tools
        M563 P{var.curTool} D{var.D} H{var.H} F{var.F}                                          ; Define Tool. D0:1 maps Extruder 0 and 1 to this tool. Uses the primary heater/fan settings.
        G10 P{var.curTool} X0 Y0 Z0                                                                                  ; Set Tool axis offsets to zero.
        G10 P{var.curTool} R0 S0                                                                                     ; Set Tool standby (R) and active (S) temperatures to 0°C.
    elif global.multiple_tools
        if global.tool_and_motion[var.curUnit][1] == 0
            M563 P{var.curTool} D{var.D} H{var.H} F{var.F}                                          ; Define Tool. D0:1 maps Extruder 0 and 1 to this tool. Uses the primary heater/fan settings.
            G10 P{var.curTool} X0 Y0 Z0                                                                                  ; Set Tool axis offsets to zero.
            G10 P{var.curTool} R0 S0                                                                                     ; Set Tool standby (R) and active (S) temperatures to 0°C.
        elif global.tool_and_motion[var.curUnit][1] == 1
            var D = {global.Machine_actual_tools[global.tool_and_motion[var.curUnit][0]][0]}:{#global.Machine_extruder_info+1}
            M563 P{var.curTool} D{var.D} H{var.H} F{var.F}                                          ; Define Tool. D0:1 maps Extruder 0 and 1 to this tool. Uses the primary heater/fan settings.
            G10 P{var.curTool} X0 Y0 Z0                                                                                  ; Set Tool axis offsets to zero.
            G10 P{var.curTool} R0 S0                                                                                     ; Set Tool standby (R) and active (S) temperatures to 0°C.
