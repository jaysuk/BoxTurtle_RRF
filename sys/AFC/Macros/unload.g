; param.A - This is the lane number
; param.B - This determines if the DC motors should run. A value of 1 is yes. No B value or a value of 0 is no

; AFC Feature Numbers
; 0 = brush
; 1 = cut
; 2 = kick
; 3 = park
; 4 = poop
; 5 = purge
; 6 = load
; 7 = startup check
; 8 = use the dc motor on unload
; 9 = unload method
; 10 = spoolman support

var first_length = 0                                                                                  ; This just initialises the variable
var unload_length = 0                                                                                 ; This just initialises the variable
var DC_motor = 0                                                                                      ; This just initialises the variable
var total_axis = 0                                                                                    ; This just initialises the variable
var retries = 5
var retry_successful = false
var additional_unload = 120
var unload_retry_length = 50

if !exists(param.A)                                                                                   ; This checks for the existance of param.A as it is needed for this macro to work
    M118 S{"Missing the tool number from this script call"}
    abort

var tool_number = param.A
var unit_number = global.Tool_to_AFC[var.tool_number][0]                                              ; Get Unit ID
var lane_number = global.Tool_to_AFC[var.tool_number][1]

M118 S{"Unit " ^ var.unit_number ^ " Lane " ^ var.lane_number ^ " is being unloaded."}                ; This message is to confirm the lane being unloaded

set var.first_length = global.AFC_lanes[var.unit_number][var.lane_number][2]                          ; This sets the variable to the measured first length
set var.unload_length = var.first_length + 50                                                         ; This is to give an extra length during unloading

if exists(param.B)                                                                                    ; This is a check to see if the DC motor is required during unloading
    set var.DC_motor = param.B                                                                        ; Sets the variable value to the B value. A value of 1 being passed to the macro would mean the DC motor is required

M98 P"0:/sys/AFC/Macros/axis_setup.g" A{var.tool_number}                                              ; This is to ensure that the motor used for all moves is set to the correct lane
M584 P{#move.axes}                                                                                    ; This unhides any hidden axes
set var.total_axis = #move.axes                                                                       ; This recounts the number of axis and sets it to a variable to be used later

if global.AFC_lanes[var.unit_number][var.lane_number][0] == true                                      ; This checks whether the lane has been marked as being loaded filament. It will not run if it hasn't
    if global.AFC_mainboard[var.unit_number] == 1
        while iterations < global.AFC_unit_total_lanes[var.unit_number]
            M581 P{global.AFC_trigger_input_numbers[var.unit_number][iterations]} R-1 T{global.AFC_trigger_numbers[var.unit_number][iterations]}
            M950 J{global.AFC_trigger_input_numbers[var.unit_number][iterations]} C"nil" 
    M574 'f1 P{"!"^global.AFC_load_switch[var.unit_number][var.lane_number]} S1                       ; This sets the load switch as a GPIO so we can do a sanity check to make sure the filament has been unloaded
    G92 'f{var.unload_length}                                                                         ; This sets the axis position to the unload length, which is 50mm more than the first length
    if var.DC_motor == 1                                                                              ; This is the check whether the DC motor is required to run
        M98 P"0:/sys/AFC/Macros/dc_motors.g" A"R" B{var.tool_number}                                  ; This enables the DC motor in the reseverse direction
        M400                                                                                          ; This just makes sure the above command runs
    G1 H4 'f0 F{global.AFC_load_retract_speed[var.unit_number][1]*60}                                 ; This is the actual command to retract the filament back on to the spool
    M400                                                                                              ; This just makes sure the above command runs
    G92 'f{var.additional_unload}                                                                     ; This sets the axis position to the unload length, which is an additional length to make sure the filament is unloaded and passed the initial loading endstop
    G1 'f0 F{global.AFC_load_retract_speed[var.unit_number][1]*60}                                    ; Does one final unload
    M400                                                                                              ; This just makes sure the above command runs
    M98 P"0:/sys/AFC/Macros/dc_motors.g" A"O" B{var.tool_number}                                      ; This ensures the DC motor is off regardless of whether it was commanded to be on
    M400                                                                                              ; This just makes sure the above command runs
    if sensors.endstops[{global.Machine_om_axis_number}].triggered                                    ; This checks to make sure the filament has been unloaded
        set global.AFC_lanes[var.unit_number][var.lane_number][0] = false                             ; This marks the lane as having no filament loaded
        M400                                                                                          ; This just makes sure the above command runs
        set global.AFC_LED_array[var.unit_number][var.lane_number] = 0                                ; This sets the neopixel colour for this lane to 0
        M98 P"0:/sys/AFC/Macros/leds.g"                                                               ; This runs the LED macro which sets the lane colour to red and records its status to the SD card
        M98 P"0:/sys/AFC/Macros/save_status.g"  
        M400                                                                                          ; This just makes sure the above command runs
        set var.retry_successful = true                                                               ; Sets the var as true so the M118 lower down does not run
    else
        while (iterations < var.retries) && !var.retry_successful                                     ; this 
            G92 'f{var.unload_retry_length}
            if var.DC_motor = 1                                                                       ; This is the check whether the DC motor is required to run
                M98 P"0:/sys/AFC/Macros/dc_motors.g" A"R" B{var.tool_number}                          ; This enables the DC motor in the reseverse direction
                M400                                                                                  ; This just makes sure the above command runs
            G1 H4 'f0 F{global.AFC_load_retract_speed[var.unit_number][1]*60}                         ; This is the actual command to retract the filament back on to the spool
            M400                                                                                      ; This just makes sure the above command runs
            M98 P"0:/sys/AFC/Macros/dc_motors.g" A"O" B{var.tool_number}                              ; This ensures the DC motor is off regardless of whether it was commanded to be on
            M400                                                                                      ; This just makes sure the above command runs
            set global.AFC_lanes[var.unit_number][var.lane_number][4][0] = "None"
            if sensors.endstops[{global.Machine_om_axis_number}].triggered                            ; This checks to make sure the filament has been unloaded
                set global.AFC_lanes[var.unit_number][var.lane_number][0] = false                  ; This marks the lane as having no filament loaded
                M400                                                                                  ; This just makes sure the above command runs
                set global.AFC_LED_array[var.unit_number][var.lane_number] = 0                        ; This sets the neopixel colour for this lane to 0
                M98 P"0:/sys/AFC/Macros/leds.g"                                                       ; This runs the LED macro which sets the lane colour to red and records its status to the SD card
                M98 P"0:/sys/AFC/Macros/save_status.g"
                M400                                                                                  ; This just makes sure the above command runs
                set var.retry_successful = true
    if var.retry_successful == false
        M118 S{"Unit " ^ var.unit_number ^ " Lane "^{var.lane_number}^" has not been successfully unloaded. Please recheck your measurements"}
    M574 'f1 P"nil" S1                                                                                ; This frees up the load switch from being used as a GPIO input
    M584 P{var.total_axis-1}                                                                          ; This hides the axis used for movement
else
    M118 S{"No Filament Loaded in Unit " ^ var.unit_number ^ " Lane "^{var.lane_number}^" to Unload"} ; If no filament is recorded as being loaded in the lane, this message will display

if global.AFC_mainboard[var.unit_number] == 1
    while iterations < global.AFC_unit_total_lanes[var.unit_number]
        M950 J{global.AFC_trigger_input_numbers[var.unit_number][iterations]} C{global.AFC_prep_switch[var.unit_number][iterations]}
        M581 P{global.AFC_trigger_input_numbers[var.unit_number][iterations]} R2 T{global.AFC_trigger_numbers[var.unit_number][iterations]} S1