; This file is used to setup the axis for the lane of the BT
; param.A is the tool number

M584 P{#move.axes}                                         ; Set the visible axes to the current count

if !exists(param.A)                                        ; Check if the required parameter A (Lane Number) exists
    echo "Missing the A parameter for the lane number"     ; Error message
    abort                                                  ; Stop macro execution

;if !exists(param.B)
;    echo "Missing the B parameter for whether to map or unmap the axis"
;    abort

var toolNumber = param.A                                   ; Assign parameter to local variable for cleaner syntax

M584 'f{global.AFC_driver_number[{var.toolNumber}]}        ; Map the physical driver for this lane to temporary axis 'f'
M350 'f{global.AFC_microsteps[{var.toolNumber}]}           ; Set microstepping for axis 'f'
M92 'f{global.AFC_steps_per_mm[{var.toolNumber}]}          ; Set steps per mm for axis 'f'
M906 'f{global.AFC_stepper_current[{var.toolNumber}]}      ; Set motor current (mA) for axis 'f'
M566 'f{global.AFC_stepper_jerk[{var.toolNumber}]*60}      ; Set maximum instantaneous speed change (mm/min)
M203 'f{global.AFC_stepper_max_speed[{var.toolNumber}]*60} ; Set maximum speed (mm/min)
M201 'f{global.AFC_stepper_acc[{var.toolNumber}]}          ; Set acceleration (mm/s^2)
M208 'f-500 s1                                             ; Set minimum axis limit (S1)
M208 'f20000 s0                                            ; Set maximum axis limit (S0)