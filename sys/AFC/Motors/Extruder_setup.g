; This file is used to setup the mixing hotend for the lane of the BT and the extruder on the printer
; param.A is the tool number
; param.B if whether to map (1) or unmap (0)

if !exists(param.A)
    echo "Missing the A parameter for the lane number"
    abort

if !exists(param.B)
    echo "Missing the B parameter for whether to map or unmap the extruder"
    abort

var toolNumber = param.A                                                      ; This just sets up a variable for the param  
var extruder = param.B

if var.extruder == 1
    M584 E{global.main_extruder[0],global.AFC_driver_number[{var.toolNumber}]}     ; This maps the current extruder driver and the driver for the correct channel as extruders
    M350 E{global.main_extruder[1],global.AFC_microsteps[{var.toolNumber}]}    ; This sets the microsteps for both steppers
    M92 E{global.main_extruder[2],global.AFC_steps_per_mm[{var.toolNumber}]} ; This sets the steps per mm for both steppers
    M906 E{global.main_extruder[6],global.AFC_stepper_current[{var.toolNumber}]}  ; This sets the current for both steppers
    M566 E{global.main_extruder[3],global.AFC_stepper_jerk[{var.toolNumber}]*60}                       ; This sets the maximum instantaneous speed changes (mm/min) for both steppers
    M203 E{global.main_extruder[4],global.AFC_stepper_max_speed[{var.toolNumber}]*60}             ; This sets the maximum speeds (mm/min) for both steppers
    M201 E{global.main_extruder[5],global.AFC_stepper_acc[{var.toolNumber}]}                         ; This sets the accelerations for both steppers
    M567 P{var.toolNumber} E1:1                                                   ; This sets the mixing ratio as 1 to 1. This will be adjusted during the print using the buffer
    M83

if var.extruder == 0                                                      
    M567 P{var.toolNumber} E1:0   
    M83