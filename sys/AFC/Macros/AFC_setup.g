
;░█▄█░█▀█░▀█▀░█▀█░█▀▄░█▀▀
;░█░█░█░█░░█░░█░█░█▀▄░▀▀█
;░▀░▀░▀▀▀░░▀░░▀▀▀░▀░▀░▀▀▀

; This is the AFC unit number used to get information from other arrays.
; This should be changed to match the unit folder number

var tl = global.AFC_unit_total_lanes[param.A]
var unit_number = param.A

while iterations < var.tl
    M569 P{global.AFC_steppers[var.unit_number][iterations][0]} S{global.AFC_steppers[var.unit_number][iterations][1]}             ; Sets up the direction for the motor/driver assigned to each lane

    ; --- Lane Trigger & Input Setup ---
    ; M950: Configure a digital input (endstop, switch, etc.). J is the logical input number, C is the physical pin.
    ; M581: Configure an external trigger (run a file when an input changes state). P is the trigger number, T is the input number, S is the action/edge.

    ;░█░░░█▀█░█▀█░█▀▀░░░▀█▀░█▀▄░▀█▀░█▀▀░█▀▀░█▀▀░█▀▄░█▀▀
    ;░█░░░█▀█░█░█░█▀▀░░░░█░░█▀▄░░█░░█░█░█░█░█▀▀░█▀▄░▀▀█
    ;░▀▀▀░▀░▀░▀░▀░▀▀▀░░░░▀░░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀

    ; M950 sets up the digital inputs (switches) used to detect filament presence/prep for each lane.
    M950 J{global.AFC_trigger_input_numbers[var.unit_number][iterations]} C{global.AFC_prep_switch[var.unit_number][iterations]}           ; Configure digital input for each Lane Prep Switch

    ; M581 configures the external triggers for the four lanes.
    ; Px: Trigger number 0-3. R2: Run on rising edge (switch actuation). Sx: Enable/Disable trigger.
    M581 P{global.AFC_trigger_input_numbers[var.unit_number][iterations]} R2 T{global.AFC_trigger_numbers[var.unit_number][iterations]} S1 ; Lane triggerx.g  ; This sets up the lane trigger
