; This file is used to setup the axis for the lane of the BT
; param.A is the tool number

M584 P{#move.axes}                                                     ; Set the visible axes to the current count

if !exists(param.A)                                                    ; Check if the required parameter A (Tool Number) exists
    M118 S"Missing the A parameter for the tool number"                 ; Error message
    M291 P{"Aborting macro. Line "^line} R"0:/sys/AFC/Macros/axis_setup.g" S1
    abort                                                              ; Stop macro execution

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
;if global.tool_and_motion[var.unit_number][1] == 0
M584 'f{global.AFC_steppers[var.unit_number][var.lane_number][0]}      ; Map the physical driver for this lane to temporary axis 'f'
M350 'f{global.AFC_steppers[var.unit_number][var.lane_number][2]}      ; Set microstepping for axis 'f'
M92 'f{global.AFC_steppers[var.unit_number][var.lane_number][3]}       ; Set steps per mm for axis 'f'
M906 'f{global.AFC_steppers[var.unit_number][var.lane_number][4]}      ; Set motor current (mA) for axis 'f'
M566 'f{global.AFC_steppers[var.unit_number][var.lane_number][5] * 60} ; Set maximum instantaneous speed change (mm/min)
M203 'f{global.AFC_steppers[var.unit_number][var.lane_number][6] * 60} ; Set maximum speed (mm/min)
M201 'f{global.AFC_steppers[var.unit_number][var.lane_number][7]}      ; Set acceleration (mm/s^2)
M208 'f{global.AFC_max_min_axes[var.unit_number][0]} s1                ; Set minimum axis limit (S1)
M208 'f{global.AFC_max_min_axes[var.unit_number][1]} s0                ; Set maximum axis limit (S0)
;elif global.tool_and_motion[var.unit_number][1] == 1
;    M584 'e{global.AFC_steppers[var.unit_number][var.lane_number][0]}      ; Map the physical driver for this lane to temporary axis 'f'
;    M350 'e{global.AFC_steppers[var.unit_number][var.lane_number][2]}      ; Set microstepping for axis 'f'
;    M92 'e{global.AFC_steppers[var.unit_number][var.lane_number][3]}       ; Set steps per mm for axis 'f'
;    M906 'e{global.AFC_steppers[var.unit_number][var.lane_number][4]}      ; Set motor current (mA) for axis 'f'
;    M566 'e{global.AFC_steppers[var.unit_number][var.lane_number][5] * 60} ; Set maximum instantaneous speed change (mm/min)
;    M203 'e{global.AFC_steppers[var.unit_number][var.lane_number][6] * 60} ; Set maximum speed (mm/min)
;    M201 'e{global.AFC_steppers[var.unit_number][var.lane_number][7]}      ; Set acceleration (mm/s^2)
;    M208 'e{global.AFC_max_min_axes[var.unit_number][0]} s1                ; Set minimum axis limit (S1)
;    M208 'e{global.AFC_max_min_axes[var.unit_number][1]} s0                ; Set maximum axis limit (S0)
M584 P{#move.axes - 1} 