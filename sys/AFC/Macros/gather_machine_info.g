var curTool = 0
var curExtruder = 0

; 0 = extruder number
; 1 = fans
; 2 = heaters
if !exists(global.Machine_actual_tools)
    global Machine_actual_tools = vector(#tools, {0, 0, 0})
while iterations < #tools
    set var.curTool = iterations
    set global.Machine_actual_tools[var.curTool][0] = vector(#tools[var.curTool].extruders, 0)
    while iterations < #tools[var.curTool].extruders
        set global.Machine_actual_tools[var.curTool][0][iterations] = tools[var.curTool].extruders[iterations]
    set global.Machine_actual_tools[var.curTool][1] = vector(#tools[var.curTool].fans, 0)
    while iterations < #tools[var.curTool].fans
        set global.Machine_actual_tools[var.curTool][1][iterations] = tools[var.curTool].fans[iterations]
    set global.Machine_actual_tools[var.curTool][2] = vector(#tools[var.curTool].heaters, 0)
    while iterations < #tools[var.curTool].heaters
        set global.Machine_actual_tools[var.curTool][2][iterations] = tools[var.curTool].heaters[iterations]

; 0 = acceleration
; 1 = current
; 2 = driver
; 3 = jerk
; 4 = microstepping
; 4a = interpolated
; 4b = value
; 5 = speed
; 6 = stepspermm
if !exists(global.Machine_extruder_info)
    global Machine_extruder_info = vector(#move.extruders, {0, 0, "", 0, {0, 0}, 0, 0})
while iterations < #move.extruders
    set var.curExtruder = iterations
    set global.Machine_extruder_info[iterations][0] = move.extruders[iterations].acceleration
    set global.Machine_extruder_info[iterations][1] = move.extruders[iterations].current
    set global.Machine_extruder_info[iterations][2] = move.extruders[iterations].driver
    set global.Machine_extruder_info[iterations][3] = move.extruders[iterations].jerk
    set global.Machine_extruder_info[iterations][4][0] = move.extruders[iterations].microstepping.interpolated
    set global.Machine_extruder_info[iterations][4][1] = move.extruders[iterations].microstepping.value
    set global.Machine_extruder_info[iterations][5] = move.extruders[iterations].speed
    set global.Machine_extruder_info[iterations][6] = move.extruders[iterations].stepsPerMm