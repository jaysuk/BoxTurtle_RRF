; This is for controlling the DC motors
; param.A can be either F = forwards, R = reserve and O = off
; param.B this is the tool number

var tool_number = param.B                                              ; Assign parameter to local variable for cleaner syntax
var unit_number = global.Tool_to_AFC[var.tool_number][0]
var lane_number = global.Tool_to_AFC[var.tool_number][1]

var SLP_pin=global.AFC_SLP_pins[var.unit_number][var.lane_number]  ; Get the Sleep/Enable pin for this specific lane
var DC1_pin=global.AFC_DC_pins[var.unit_number][var.lane_number][0]  ; Get the first logic pin for the motor driver
var DC2_pin=global.AFC_DC_pins[var.unit_number][var.lane_number][1]  ; Get the second logic pin for the motor driver

if param.A = "F" || param.A = "R" || param.A = "O" ; Configure the pins first (also for Off, so M42 never hits an unassigned pin)
    M950 P{global.AFC_dcm_out_no[0]} C{var.SLP_pin} ; Configure Sleep/Enable pin to the logical P number defined in globals
    if global.AFC_dc_speed < 1
        ; Below full speed the two logic pins are PWM outputs; the one that is driven high carries the duty cycle
        M950 P{global.AFC_dcm_out_no[1]} C{var.DC1_pin} Q{global.AFC_dc_freq}
        M950 P{global.AFC_dcm_out_no[2]} C{var.DC2_pin} Q{global.AFC_dc_freq}
    else
        M950 P{global.AFC_dcm_out_no[1]} C{var.DC1_pin} ; Configure Logic Pin 1 to the logical P number defined in globals
        M950 P{global.AFC_dcm_out_no[2]} C{var.DC2_pin} ; Configure Logic Pin 2 to the logical P number defined in globals

if param.A = "F"                                    ; Logic for Forward motion
    M42 P{global.AFC_dcm_out_no[0]} S1              ; Set Sleep/Enable Pin HIGH (Enable Driver) using dynamic P index
    M42 P{global.AFC_dcm_out_no[1]} S0              ; Set Logic Pin 1 LOW using dynamic P index
    M42 P{global.AFC_dcm_out_no[2]} S{global.AFC_dc_speed} ; Set Logic Pin 2 HIGH (duty cycle = AFC_dc_speed) using dynamic P index (Polarity for Forward)

if param.A = "R"                                    ; Logic for Reverse motion
    M42 P{global.AFC_dcm_out_no[0]} S1              ; Set Sleep/Enable Pin HIGH (Enable Driver) using dynamic P index
    M42 P{global.AFC_dcm_out_no[1]} S{global.AFC_dc_speed} ; Set Logic Pin 1 HIGH (duty cycle = AFC_dc_speed) using dynamic P index
    M42 P{global.AFC_dcm_out_no[2]} S0              ; Set Logic Pin 2 LOW using dynamic P index (Polarity for Reverse)

if param.A = "O"                                    ; Logic for Off/Stop
    M42 P{global.AFC_dcm_out_no[0]} S0              ; Set Sleep/Enable Pin LOW (Disable Driver) using dynamic P index
    M42 P{global.AFC_dcm_out_no[1]} S0              ; Set Logic Pin 1 LOW using dynamic P index
    M42 P{global.AFC_dcm_out_no[2]} S0              ; Set Logic Pin 2 LOW using dynamic P index
    M950 P{global.AFC_dcm_out_no[0]} C"nil"         ; Free the logical pin used for Sleep/Enable
    M950 P{global.AFC_dcm_out_no[1]} C"nil"         ; Free the logical pin used for DC1
    M950 P{global.AFC_dcm_out_no[2]} C"nil"         ; Free the logical pin used for DC2