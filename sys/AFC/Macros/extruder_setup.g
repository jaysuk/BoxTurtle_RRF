; This file is used to setup the mixing hotend for the lane of the BT and the extruder on the printer
; param.A is the tool number
; param.B is whether to map (1) or unmap (0)
var driver = 0
var total_extruders = 0
var current = 0
var accel = 0
var jerk = 0
var stepping = 0
var speed = 0
var stepspermm = 0
var extra_to_add = 0
var last_extruder = #move.extruders - 1
var count = 0

if !exists(param.A)                                                                   ; Check if lane number parameter exists
    M118 S"Missing the A parameter for the lane number"                                ; Error message
    abort                                                                             ; Stop execution

if !exists(param.B)                                                                   ; Check if map/unmap parameter exists
    M118 S"Missing the B parameter for whether to map or unmap the extruder"           ; Error message
    abort                                                                             ; Stop execution

;var toolNumber = param.A                                                              ; Assign parameter A to local variable
var extruder = param.B                                                                ; Assign parameter B to local variable

var tool_number = param.A                                              ; Assign parameter to local variable for cleaner syntax
var unit_number = global.Tool_to_AFC[var.tool_number][0]
var lane_number = global.Tool_to_AFC[var.tool_number][1]


; global.AFC_steppers
; 0 = driver number
; 1 = driver direction
; 2 = microsteps
; 3 = steps per mm
; 4 = current
; 5 = jerk
; 6 = max speed
; 7 = acceleration

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
if !global.multiple_tools
set var.driver[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][0]
set var.accel[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][7]
set var.current[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][4]
set var.jerk[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][5] * 60
set var.stepping[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][2]
set var.speed[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][6] * 60
set var.stepspermm[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][3]
elif global.multiple_tools
    if global.tool_and_motion[0][0] == global.tool_and_motion[var.unit_number][0]
        set var.driver[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][0]
        set var.accel[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][7]
        set var.current[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][4]
        set var.jerk[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][5] * 60
        set var.stepping[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][2]
        set var.speed[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][6] * 60
        set var.stepspermm[var.total_extruders+1] = global.AFC_steppers[var.unit_number][var.lane_number][3]
        set var.driver[var.total_extruders+2] = move.extruders[var.last_extruder].driver
        set var.accel[var.total_extruders+2] = move.extruders[var.last_extruder].acceleration
        set var.current[var.total_extruders+2] = move.extruders[var.last_extruder].current
        set var.jerk[var.total_extruders+2] = move.extruders[var.last_extruder].jerk
        set var.stepping[var.total_extruders+2] = move.extruders[var.last_extruder].microstepping.value
        set var.speed[var.total_extruders+2] = move.extruders[var.last_extruder].speed
        set var.stepspermm[var.total_extruders+2] = move.extruders[var.last_extruder].stepsPerMm
    else
        set var.driver[var.total_extruders+1] = move.extruders[var.last_extruder-1].driver
        set var.accel[var.total_extruders+1] = move.extruders[var.last_extruder-1].acceleration
        set var.current[var.total_extruders+1] = move.extruders[var.last_extruder-1].current
        set var.jerk[var.total_extruders+1] = move.extruders[var.last_extruder-1].jerk
        set var.stepping[var.total_extruders+1] = move.extruders[var.last_extruder-1].microstepping.value
        set var.speed[var.total_extruders+1] = move.extruders[var.last_extruder-1].speed
        set var.stepspermm[var.total_extruders+1] = move.extruders[var.last_extruder-1].stepsPerMm
        set var.driver[var.total_extruders+2] = global.AFC_steppers[var.unit_number][var.lane_number][0]
        set var.accel[var.total_extruders+2] = global.AFC_steppers[var.unit_number][var.lane_number][7]
        set var.current[var.total_extruders+2] = global.AFC_steppers[var.unit_number][var.lane_number][4]
        set var.jerk[var.total_extruders+2] = global.AFC_steppers[var.unit_number][var.lane_number][5] * 60
        set var.stepping[var.total_extruders+2] = global.AFC_steppers[var.unit_number][var.lane_number][2]
        set var.speed[var.total_extruders+2] = global.AFC_steppers[var.unit_number][var.lane_number][6] * 60
        set var.stepspermm[var.total_extruders+2] = global.AFC_steppers[var.unit_number][var.lane_number][3]

if var.extruder == 1         
    M584 E{var.driver}   
    M350 E{var.stepping}
    M92 E{var.stepspermm}
    M906 E{var.current}
    M566 E{var.jerk}
    M203 E{var.speed}
    M201 E{var.accel}
    M83
    M567 P{var.tool_number} E1:0                                                       ; Set mixing ratio to 1:0 (Main extruder moves, AFC motor stays still)

if var.extruder == 0                                                                  ; Logic to UNMAP (Soft Disable) the AFC motor
    M567 P{var.tool_number} E1:0                                                       ; Set mixing ratio to 1:0 (Main extruder moves, AFC motor stays still)
    M83                                                                               ; Set relative extrusion mode