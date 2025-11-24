; This file is used to setup the mixing hotend for the lane of the BT and the extruder on the printer
; param.A is the tool number
; param.B is whether to map (1) or unmap (0)

if !exists(param.A)                                                                   ; Check if lane number parameter exists
    echo "Missing the A parameter for the lane number"                                ; Error message
    abort                                                                             ; Stop execution

if !exists(param.B)                                                                   ; Check if map/unmap parameter exists
    echo "Missing the B parameter for whether to map or unmap the extruder"           ; Error message
    abort                                                                             ; Stop execution

var toolNumber = param.A                                                              ; Assign parameter A to local variable
var extruder = param.B                                                                ; Assign parameter B to local variable

if var.extruder == 1                                                                  ; Logic to MAP (Enable) the AFC motor
    M584 E{global.main_extruder[0],global.AFC_driver_number[{var.toolNumber}]}        ; Map E-axis to use Main Extruder Drive AND AFC Lane Drive
    M350 E{global.main_extruder[1],global.AFC_microsteps[{var.toolNumber}]}           ; Set microsteps for both mapped E-drives
    M92 E{global.main_extruder[2],global.AFC_steps_per_mm[{var.toolNumber}]}          ; Set steps per mm for both mapped E-drives
    M906 E{global.main_extruder[6],global.AFC_stepper_current[{var.toolNumber}]}      ; Set motor current for both mapped E-drives
    M566 E{global.main_extruder[3],global.AFC_stepper_jerk[{var.toolNumber}]*60}      ; Set max instantaneous speed change (jerk) for E-drives
    M203 E{global.main_extruder[4],global.AFC_stepper_max_speed[{var.toolNumber}]*60} ; Set max speed for E-drives
    M201 E{global.main_extruder[5],global.AFC_stepper_acc[{var.toolNumber}]}          ; Set acceleration for E-drives
    M567 P{var.toolNumber} E1:1                                                       ; Set mixing ratio to 1:1 (Both motors move equally for extrusion)
    M83                                                                               ; Set relative extrusion mode

if var.extruder == 0                                                                  ; Logic to UNMAP (Soft Disable) the AFC motor
    M567 P{var.toolNumber} E1:0                                                       ; Set mixing ratio to 1:0 (Main extruder moves, AFC motor stays still)
    M83                                                                               ; Set relative extrusion mode