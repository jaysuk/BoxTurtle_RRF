; This is for controlling the DC motors
; param.A can be either F = forwards, R = reserve and O = off
; param.B this is the lane/tool number

;if param.A !="F" || param.A !="R" || param.A !="O"
;    M117 "Not specified if forwards, reverse or off"
;    abort

var lane_number=param.B                             ; Assign the lane number from the parameter
var SLP_pin=global.AFC_SLP_pins[{var.lane_number}]  ; Get the Sleep/Enable pin for this specific lane
var DC1_pin=global.AFC_DC1_pins[{var.lane_number}]  ; Get the first logic pin for the motor driver
var DC2_pin=global.AFC_DC2_pins[{var.lane_number}]  ; Get the second logic pin for the motor driver

echo var.SLP_pin                                    ; Debug: Output the SLP pin to console
echo param.A                                        ; Debug: Output the requested direction to console

if param.A = "F" || param.A = "R"                   ; If the request is Forward or Reverse, we need to configure the pins
    M950 P{global.AFC_dcm_out_no[0]} C{var.SLP_pin} ; Configure Sleep/Enable pin to the logical P number defined in globals
    M950 P{global.AFC_dcm_out_no[1]} C{var.DC1_pin} ; Configure Logic Pin 1 to the logical P number defined in globals
    M950 P{global.AFC_dcm_out_no[2]} C{var.DC2_pin} ; Configure Logic Pin 2 to the logical P number defined in globals

if param.A = "F"                                    ; Logic for Forward motion
    M42 P{global.AFC_dcm_out_no[0]} S1              ; Set Sleep/Enable Pin HIGH (Enable Driver) using dynamic P index
    M42 P{global.AFC_dcm_out_no[1]} S0              ; Set Logic Pin 1 LOW using dynamic P index
    M42 P{global.AFC_dcm_out_no[2]} S1              ; Set Logic Pin 2 HIGH using dynamic P index (Polarity for Forward)

if param.A = "R"                                    ; Logic for Reverse motion
    M42 P{global.AFC_dcm_out_no[0]} S1              ; Set Sleep/Enable Pin HIGH (Enable Driver) using dynamic P index
    M42 P{global.AFC_dcm_out_no[1]} S1              ; Set Logic Pin 1 HIGH using dynamic P index
    M42 P{global.AFC_dcm_out_no[2]} S0              ; Set Logic Pin 2 LOW using dynamic P index (Polarity for Reverse)

if param.A = "O"                                    ; Logic for Off/Stop
    M42 P{global.AFC_dcm_out_no[0]} S0              ; Set Sleep/Enable Pin LOW (Disable Driver) using dynamic P index
    M42 P{global.AFC_dcm_out_no[1]} S0              ; Set Logic Pin 1 LOW using dynamic P index
    M42 P{global.AFC_dcm_out_no[2]} S0              ; Set Logic Pin 2 LOW using dynamic P index
    M950 P{global.AFC_dcm_out_no[0]} C"nil"         ; Free the logical pin used for Sleep/Enable
    M950 P{global.AFC_dcm_out_no[1]} C"nil"         ; Free the logical pin used for DC1
    M950 P{global.AFC_dcm_out_no[2]} C"nil"         ; Free the logical pin used for DC2