; === AFC System Initialization (config.g) ===

; --- Configuration Loading ---
if !exists(global.AFC_settings_loaded)                                             ; Checks if the primary AFC settings have been loaded into global variables.
    M98 P"0:/sys/AFC/AFC_vars.g"                                                   ; If not loaded, execute AFC_vars.g to define default global settings (e.g., driver numbers, directions, etc.).
    global AFC_settings_loaded = true                                              ; Set a flag to prevent re-execution of the default settings file on subsequent runs.

if fileexists("0:/sys/AFC/AFC_user_vars.g")                                        ; Checks for the existence of an optional user override file.
    M98 P"0:/sys/AFC/AFC_user_vars.g"                                              ; If it exists, execute it to load custom settings, overriding any defaults set in AFC_vars.g.

; --- Motor Driver Setup (M569) ---
; M569: Configure a stepper driver (P parameter specifies the driver).
; S: Sets the direction (0 for reverse, 1 for forward).
; This section sets the hardware direction for the four motors/drivers used by the AFC lanes.
; The specific driver number and direction are read from global variables.

;######## Motors ################
while iterations < global.AFC_total_lanes
    M569 P{global.AFC_driver_number[iterations]} S{global.AFC_stepper_direction[iterations]}             ; Sets up the direction for the motor/driver assigned to each lane

; --- Axis Count Initialization ---
if !exists(global.max_axes)                                                        ; Checks if a 'max_axes' global variable is defined.
    global max_axes=#move.axes                                                     ; If not, initialize it using the total number of movement axes currently configured.

; --- Lane Trigger & Input Setup ---
; M950: Configure a digital input (endstop, switch, etc.). J is the logical input number, C is the physical pin.
; M581: Configure an external trigger (run a file when an input changes state). P is the trigger number, T is the input number, S is the action/edge.

;######## Lane Triggers #########
; M950 sets up the digital inputs (switches) used to detect filament presence/prep for each lane.
while iterations < global.AFC_total_lanes
    M950 J{global.AFC_trigger_input_numbers[iterations]} C{global.AFC_prep_switch[iterations]}           ; Configure digital input for each Lane Prep Switch

    ; M581 configures the external triggers for the four lanes.
    ; Px: Trigger number 0-3. R2: Run on rising edge (switch actuation). Sx: Enable/Disable trigger.
    M581 P{global.AFC_trigger_input_numbers[iterations]} R2 T{global.AFC_trigger_numbers[iterations]} S1 ; Lane triggerx.g  ; This sets up the lane trigger


; --- Extruder Motor Configuration (M584, M350, M92, etc.) ---
; This section configures the primary extruder motor (often E0) and the Lane 0 AFC motor as 'extruders' 
; to control their movement parameters. The indices suggest a dual-extruder setup is being configured.

;######## Extruders #################
M584 E{global.main_extruder[0],global.AFC_driver_number[0]}                        ; Maps the main extruder driver (index 0) and the Lane 0 motor driver as 'Extruders'.
M350 E{global.main_extruder[1],global.AFC_microsteps[0]}                           ; Sets the microstepping for both motors/drivers listed as 'Extruders'.
M92 E{global.main_extruder[2],global.AFC_steps_per_mm[0]}                          ; Sets the steps per millimeter for both motors/drivers.
M906 E{global.main_extruder[6],global.AFC_stepper_current[0]}                      ; Sets the motor current (Amps) for both motors/drivers.
M566 E{global.main_extruder[3],global.AFC_stepper_jerk[0]*60}                      ; Sets the maximum instantaneous speed changes (mm/min) for both motors/drivers. (Value multiplied by 60 for min/sec conversion)
M203 E{global.main_extruder[4],global.AFC_stepper_max_speed[0]*60}                 ; Sets the maximum speeds (mm/min) for both motors/drivers. (Value multiplied by 60 for min/sec conversion)
M201 E{global.main_extruder[5],global.AFC_stepper_acc[0]}                          ; Sets the acceleration (mm/s^2) for both motors/drivers.
M83                                                                                ; Sets all extruders to relative mode (E-values are relative movements).

; --- Tool Definition (M563, G10) ---
; M563: Define a Tool (P#). D# maps extruder drives to the tool.
; G10: Set Tool Offsets (X,Y,Z) and standby/active temperatures (R, S).
; Four tools (P0 to P3) are defined, corresponding to the four AFC lanes.

;######## Tools #################
while iterations < global.AFC_total_lanes
    M563 P{iterations} D0:1 H{tools[0].heaters[0]} F{tools[0].fans[0]}                            ; Define Tool. D0:1 maps Extruder 0 and 1 to this tool. Uses the primary heater/fan settings.
    G10 P{iterations} X0 Y0 Z0                                                                    ; Set Tool axis offsets to zero.
    G10 P{iterations} R0 S0                                                                       ; Set Tool standby (R) and active (S) temperatures to 0°C.

; --- Lane Status & Info Loading ---
; This loads various files that likely contain the current state/metrics of the AFC system, such as filament used, spool details, and overall status.

;######## Lane Info ################
if fileexists("0:/sys/AFC/AFC-info/lane_first_length.g")                           ; Load the amount of filament used on the first print with the current spool/lane.
    M98 P"0:/sys/AFC/AFC-info/lane_first_length.g"
if fileexists("0:/sys/AFC/AFC-info/lane_total_length.g")                           ; Load the total amount of filament used for the current spool/lane.
    M98 P"0:/sys/AFC/AFC-info/lane_total_length.g"
if fileexists("0:/sys/AFC/AFC-info/lane_status.g")                                 ; Load the current operational status of the lane (e.g., loaded, empty, error).
    M98 P"0:/sys/AFC/AFC-info/lane_status.g"
if fileexists("0:/sys/AFC/AFC-info/lane_filament.g")                               ; Load details about the filament currently assigned to the lane (e.g., type, color).
    M98 P"0:/sys/AFC/AFC-info/lane_filament.g"
if fileexists("0:/sys/AFC/AFC-info/spoolman_status.g")                             ; Load status/data from an external spool management system (Spoolman).
    M98 P"0:/sys/AFC/AFC-info/spoolman_status.g"
set global.AFC_lane_filament_type1 = global.AFC_lane_filament_type                 ; Assigns the loaded filament type to a new variable (potentially for Lane 1).

; --- LED Configuration ---
; M950: Used here to define and configure a Neopixel/RGB LED strip.

;######## LEDs ##################
M950 E{global.AFC_neopixel_settings[0]} C{global.AFC_neopixel_pin} T{global.AFC_neopixel_settings[1]} U{global.AFC_neopixel_settings[2]}
; M950 sets up the Neopixel strip: E is the logical index, C is the physical pin, T is the type/number of LEDs, U is the colour encoding format.

if fileexists("0:/sys/AFC/AFC-info/LEDs.g")                                        ; Load specific/saved LED state information.
    M98 P"0:/sys/AFC/AFC-info/LEDs.g"
M98 P"0:/sys/AFC/LEDs.g"                                                           ; Execute the main LED control macro to set the initial strip appearance.