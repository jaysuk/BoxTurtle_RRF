if !exists(global.AFC_settings_loaded)  ; This checks whether the settings have been loaded before. Helpful for when running config checks
    M98 P"0:/sys/AFC/AFC_vars.g"
    global AFC_settings_loaded = true

if fileexists("0:/sys/AFC/AFC_user_vars.g") ; This checks for the existance of user overrides
    M98 P"0:/sys/AFC/AFC_user_vars.g"

;######## Motors ################
M569 P{global.AFC_driver_number[0]} S{global.AFC_stepper_direction[0]}  ; This sets up the direction for lane 0
M569 P{global.AFC_driver_number[1]} S{global.AFC_stepper_direction[1]} ; This sets up the direction for lane 1
M569 P{global.AFC_driver_number[2]} S{global.AFC_stepper_direction[2]} ; This sets up the direction for lane 2
M569 P{global.AFC_driver_number[3]} S{global.AFC_stepper_direction[3]} ; This sets up the direction for lane 3

if !exists(global.max_axes)
    global max_axes=#move.axes

;######## Lane Triggers #########
M950 J{global.AFC_trigger_input_numbers[0]} C{global.AFC_prep_switch[0]}           ; Lane 0 Prep
M950 J{global.AFC_trigger_input_numbers[1]} C{global.AFC_prep_switch[1]}           ; Lane 1 Prep
M950 J{global.AFC_trigger_input_numbers[2]} C{global.AFC_prep_switch[2]}           ; Lane 2 Prep
M950 J{global.AFC_trigger_input_numbers[3]} C{global.AFC_prep_switch[3]}           ; Lane 3 Prep
M581 P0 R2 T{global.AFC_trigger_numbers[0]} S1 ; Lane 0 trigger2.g  ; This sets up the lane 0 trigger
M581 P1 R2 T{global.AFC_trigger_numbers[1]} S1 ; Lane 1 trigger3.g ; This sets up the lane 0 trigger
M581 P2 R2 T{global.AFC_trigger_numbers[2]} S1 ; Lane 2 trigger4.g ; This sets up the lane 0 trigger
M581 P3 R2 T{global.AFC_trigger_numbers[3]} S1 ; Lane 3 trigger5.g ; This sets up the lane 0 trigger

;######## Extruders #################
M584 E{global.main_extruder[0],global.AFC_driver_number[0]}     ; This maps the current extruder driver and the driver for the correct channel as extruders
M350 E{global.main_extruder[1],global.AFC_microsteps[0]}    ; This sets the microsteps for both steppers
M92 E{global.main_extruder[2],global.AFC_steps_per_mm[0]} ; This sets the steps per mm for both steppers
M906 E{global.main_extruder[6],global.AFC_stepper_current[0]}  ; This sets the current for both steppers
M566 E{global.main_extruder[3],global.AFC_stepper_jerk[0]*60}                       ; This sets the maximum instantaneous speed changes (mm/min) for both steppers
M203 E{global.main_extruder[4],global.AFC_stepper_max_speed[0]*60}             ; This sets the maximum speeds (mm/min) for both steppers
M201 E{global.main_extruder[5],global.AFC_stepper_acc[0]}                         ; This sets the accelerations for both steppers
M83

;######## Tools #################
M563 P0 D0:1 H{tools[0].heaters[0]} F{tools[0].fans[0]}                               ; define tool 0 used by lane 0
G10 P0 X0 Y0 Z0                                ; set tool 0 axis offsets
G10 P0 R0 S0                                   ; set initial tool 0 active and standby temperatures to 0C

M563 P1 D0:1 H{tools[0].heaters[0]} F{tools[0].fans[0]}                               ; define tool 1 used by lane 1
G10 P1 X0 Y0 Z0                                ; set tool 0 axis offsets
G10 P1 R0 S0                                   ; set initial tool 0 active and standby temperatures to 0C

M563 P2 D0:1 H{tools[0].heaters[0]} F{tools[0].fans[0]}                               ; define tool 2 used by lane 2
G10 P2 D0:1 Y0 Z0                                ; set tool 0 axis offsets
G10 P2 R0 S0                                   ; set initial tool 0 active and standby temperatures to 0C

M563 P3 D0:1 H{tools[0].heaters[0]} F{tools[0].fans[0]}                               ; define tool 3 used by lane 3
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
if fileexists("0:/sys/AFC/AFC-info/spoolman_status.g")
    M98 P"0:/sys/AFC/AFC-info/spoolman_status.g"
set global.AFC_lane_filament_type1 = global.AFC_lane_filament_type
    
;######## LEDs ##################
M950 E{global.AFC_neopixel_settings[0]} C{global.AFC_neopixel_pin} T{global.AFC_neopixel_settings[1]} U{global.AFC_neopixel_settings[2]}
if fileexists("0:/sys/AFC/AFC-info/LEDs.g")
    M98 P"0:/sys/AFC/AFC-info/LEDs.g"
M98 P"0:/sys/AFC/LEDs.g"
