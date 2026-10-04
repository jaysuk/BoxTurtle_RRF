; lane_motion_end.g - undo lane_motion_begin.g; safe to call from any exit path
; param.A tool number (optional). Without it the lane triggers of every Longboi unit are re-armed.
; An axis has one endstop object, so M574 'f1 P"nil" frees whatever is bound to 'f (hub, load, TN or extruder switch).
if global.AFC_f_axis >= 0
    if move.axes[global.AFC_f_axis].visible
        M574 'f1 P"nil" S1
        M400
        M584 P{#move.axes - 1}                           ; hide 'f

var first_unit = 0
var last_unit = #global.AFC_unit_CAN_ids - 1
if exists(param.A) && param.A >= 0 && param.A < #global.Tool_to_AFC
    set var.first_unit = global.Tool_to_AFC[param.A][0]
    set var.last_unit = var.first_unit

while var.first_unit <= var.last_unit
    if global.AFC_mainboard[var.first_unit] == 1
        while iterations < global.AFC_unit_total_lanes[var.first_unit]
            M950 J{global.AFC_trigger_input_numbers[var.first_unit][iterations]} C{global.AFC_prep_switch[var.first_unit][iterations]}
            M581 P{global.AFC_trigger_input_numbers[var.first_unit][iterations]} R2 T{global.AFC_trigger_numbers[var.first_unit][iterations]} S1
    set var.first_unit = var.first_unit + 1
