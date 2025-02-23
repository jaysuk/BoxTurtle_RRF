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

if param.B == 1
    M584 E{global.extruder_driver,global.AFC_driver_number[{var.toolNumber}]}     ; This maps the current extruder driver and the driver for the correct channel as extruders
    M563 P{var.toolNumber} D0:1 H1 F0                                             ; This sets up the tool parameters and sets the two drivers as a mixing hotend setup
    M350 E{global.extruder_microsteps,global.AFC_microsteps[{var.toolNumber}]}    ; This sets the microsteps for both steppers
    M92 E{global.extruder_steps_per_mm,global.AFC_steps_per_mm[{var.toolNumber}]} ; This sets the steps per mm for both steppers
    M906 E{global.extruder_current,global.AFC_stepper_current[{var.toolNumber}]}  ; This sets the current for both steppers
    M566 E{global.extruder_jerk,global.AFC_stepper_jerk[4]}                       ; This sets the maximum instantaneous speed changes (mm/min) for both steppers
    M203 E{global.extruder_max_speed,global.AFC_stepper_max_speed[4]}             ; This sets the maximum speeds (mm/min) for both steppers
    M201 E{global.extruder_acc,global.AFC_stepper_acc[4]}                         ; This sets the accelerations for both steppers
    M567 P{var.toolNumber} E1:1                                                   ; This sets the mixing ratio as 1 to 1. This will be adjusted during the print using the buffer
    M83

if param.B == 0                                                      
    M584 E{global.extruder_driver}      ; This maps the current extruder driver and the driver for the correct channel as extruders
    M563 P{var.toolNumber} D0 H1 F0     ; This sets up the tool parameters and sets the two drivers as a mixing hotend setup
    M350 E{global.extruder_microsteps}  ; This sets the microsteps for both steppers
    M92 E{global.extruder_steps_per_mm} ; This sets the steps per mm for both steppers
    M906 E{global.extruder_current}     ; This sets the current for both steppers
    M566 E{global.extruder_jerk}        ; This sets the maximum instantaneous speed changes (mm/min) for both steppers
    M203 E{global.extruder_max_speed}   ; This sets the maximum speeds (mm/min) for both steppers
    M201 E{global.extruder_acc}         ; This sets the accelerations for both steppers
    M83