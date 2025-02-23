; This file is used to setup the axis for the lane of the BT
; param.A is the tool number
; param.B if whether to map (1) or unmap (0)

if !exists(param.A)
    echo "Missing the A parameter for the lane number"
    abort

;if !exists(param.B)
;    echo "Missing the B parameter for whether to map or unmap the axis"
;    abort

var toolNumber = param.A                                                      ; This just sets up a variable for the param  

M584 's{global.AFC_driver_number[{var.toolNumber}]}
M350 's{global.AFC_microsteps[{var.toolNumber}]}
M92 's{global.AFC_steps_per_mm[{var.toolNumber}]} 
M906 's{global.AFC_stepper_current[{var.toolNumber}]} 
M566 's{global.AFC_stepper_jerk[{var.toolNumber}]} 
M203 's{global.AFC_stepper_max_speed[{var.toolNumber}]} 
M201 's{global.AFC_stepper_acc[{var.toolNumber}]} 
M208 's-100 s1
M208 's20000 s0