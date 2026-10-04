; lane_motion_begin.g - prepare the 'f axis for filament moves on one lane
; param.A tool number (required)
; Maps 'f to the lane driver, unhides it, disarms the Longboi lane triggers and records the OM index of 'f in
; global.AFC_f_axis. Every exit path of the calling macro must call lane_motion_end.g (afc_error.g does it for errors).
if !exists(param.A)
    M118 S"lane_motion_begin.g needs A (tool number)"
    M99

var unit_number = global.Tool_to_AFC[param.A][0]

M98 P"0:/sys/AFC/Macros/axis_setup.g" A{param.A}        ; creates / re-points 'f (leaves it hidden)
M584 P{#move.axes}                                       ; unhide 'f

; Longboi: the lane prep switches are on the main board and their interrupts must not fire during motion
if global.AFC_mainboard[var.unit_number] == 1
    while iterations < global.AFC_unit_total_lanes[var.unit_number]
        M581 P{global.AFC_trigger_input_numbers[var.unit_number][iterations]} R-1 T{global.AFC_trigger_numbers[var.unit_number][iterations]}
        M950 J{global.AFC_trigger_input_numbers[var.unit_number][iterations]} C"nil"

; Find the object model index of the 'f axis (any printer axis added after X/Y/Z shifts it)
set global.AFC_f_axis = -1
while iterations < #move.axes
    if move.axes[iterations].letter == "f"
        set global.AFC_f_axis = iterations
        break
