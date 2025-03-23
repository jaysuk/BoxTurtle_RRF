; This file is used to setup the axis for the lane of the BT
; param.A is the tool number

M584 P{#move.axes}

if !exists(param.A)
    echo "Missing the A parameter for the lane number"
    abort

;if !exists(param.B)
;    echo "Missing the B parameter for whether to map or unmap the axis"
;    abort

var toolNumber = param.A                                                      ; This just sets up a variable for the param  

M584 'l{global.AFC_driver_number[{var.toolNumber}]}
M350 'l{global.AFC_microsteps[{var.toolNumber}]}
M92 'l{global.AFC_steps_per_mm[{var.toolNumber}]} 
M906 'l{global.AFC_stepper_current[{var.toolNumber}]} 
M566 'l{global.AFC_stepper_jerk[{var.toolNumber}]*60} 
M203 'l{global.AFC_stepper_max_speed[{var.toolNumber}]*60} 
M201 'l{global.AFC_stepper_acc[{var.toolNumber}]} 
M208 'l-500 s1
M208 'l20000 s0