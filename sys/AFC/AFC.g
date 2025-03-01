M98 P"0:/sys/AFC/AFC-vars.g"

;######## Motors ################
M569 P119.0 S{global.AFC_stepper_direction[0]}
M569 P119.1 S{global.AFC_stepper_direction[1]}
M569 P119.2 S{global.AFC_stepper_direction[2]}
M569 P119.3 S{global.AFC_stepper_direction[3]}

global max_axes=#move.axes

;######## Lane Triggers #########
M950 J{global.AFC_trigger_input_numbers[0]} C{global.AFC_prep_switch[0]}           ; Lane 0 Prep
M950 J{global.AFC_trigger_input_numbers[1]} C{global.AFC_prep_switch[1]}           ; Lane 1 Prep
M950 J{global.AFC_trigger_input_numbers[2]} C{global.AFC_prep_switch[2]}           ; Lane 2 Prep
M950 J{global.AFC_trigger_input_numbers[3]} C{global.AFC_prep_switch[3]}           ; Lane 3 Prep
M581 P0 R2 T{global.AFC_trigger_numbers[0]} S1 ; Lane 0 trigger2.g
M581 P1 R2 T{global.AFC_trigger_numbers[1]} S1 ; Lane 1 trigger3.g
M581 P2 R2 T{global.AFC_trigger_numbers[2]} S1 ; Lane 2 trigger4.g
M581 P3 R2 T{global.AFC_trigger_numbers[3]} S1 ; Lane 3 trigger5.g

;######## Tools #################
M563 P0 D0 H1 F0                               ; define tool 0
G10 P0 X0 Y0 Z0                                ; set tool 0 axis offsets
G10 P0 R0 S0                                   ; set initial tool 0 active and standby temperatures to 0C

M563 P1 D0 H1 F0                               ; define tool 0
G10 P1 X0 Y0 Z0                                ; set tool 0 axis offsets
G10 P1 R0 S0                                   ; set initial tool 0 active and standby temperatures to 0C

M563 P2 D0 H1 F0                               ; define tool 0
G10 P2 X0 Y0 Z0                                ; set tool 0 axis offsets
G10 P2 R0 S0                                   ; set initial tool 0 active and standby temperatures to 0C

M563 P3 D0 H1 F0                               ; define tool 0
G10 P3 X0 Y0 Z0                                ; set tool 0 axis offsets
G10 P3 R0 S0                                   ; set initial tool 0 active and standby temperatures to 0C

;######## Lane 0 ################
if fileexists("0:/sys/AFC/AFC-info/lane_first_length.g")
    M98 P"0:/sys/AFC/AFC-info/lane_first_length.g"
if fileexists("0:/sys/AFC/AFC-info/lane_total_length.g")
    M98 P"0:/sys/AFC/AFC-info/lane_total_length.g"
if fileexists("0:/sys/AFC/AFC-info/lane_status.g")
    M98 P"0:/sys/AFC/AFC-info/lane_status.g"
if fileexists("0:/sys/AFC/AFC-info/lane_filament.g")
    M98 P"0:/sys/AFC/AFC-info/lane_filament.g"
set global.AFC_lane_filament_type1 = global.AFC_lane_filament_type
    
;######## LEDs ##################
M950 E0 C"119.neopixel1" T2 U4
if fileexists("0:/sys/AFC/AFC-info/LEDs.g")
    M98 P"0:/sys/AFC/AFC-info/LEDs.g"
M98 P"0:/sys/AFC/LEDs.g"