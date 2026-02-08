; === AFC Filament Load/Detection Macro (RepRapFirmware G-Code) ===

; --- Macro Parameters ---
; param.A - This is the lane number (0, 1, 2, 3, etc.) passed when the macro is called.

; --- AFC Feature Flags (Reference) ---
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

; --- Parameter Validation ---
if !exists(param.A)                                                                                           ; Check if the required 'A' parameter (tool number) was passed to the macro.
    M118 S"Missing the Tool number"                                                                            ; Report the error.
    abort                                                                                                     ; Stop macro execution if the parameter is missing.

var tool_number = param.A                                                                                       ; Assign the input parameter to a local variable for easier use.
var unit_number = global.Tool_to_AFC[var.tool_number][0]
var lane_number = global.Tool_to_AFC[var.tool_number][1]

; --- Axis Setup ---
; Call a sub-macro to configure the motor associated with the current lane as a temporary axis (likely 'F').
M98 P"0:/sys/AFC/Macros/axis_setup.g" A{var.tool_number}

var total_axis=#move.axes                                                                                     ; Store the total number of axes (used later to hide the temporary axis).

if global.AFC_mainboard[var.unit_number] == 1
    while iterations < global.AFC_unit_total_lanes[var.unit_number]
        M581 P{global.AFC_trigger_input_numbers[var.unit_number][iterations]} R-1 T{global.AFC_trigger_numbers[var.unit_number][iterations]}
        M950 J{global.AFC_trigger_input_numbers[var.unit_number][iterations]} C"nil" 

; --- Filament Detection Routine ---
; M574: Define endstop configuration for the temporary axis ('f').
M574 'f1 P{global.AFC_load_switch[var.unit_number][var.lane_number]} S1                                                        ; Assign the physical pin (P) for the filament load switch of the current lane to the 'F' axis, using active-low/normal switch mode (S1).
G92 'f0                                                                                                       ; Set the current position of the temporary 'F' axis to 0.
M574
if !sensors.endstops[{global.Machine_om_axis_number}].triggered                                                       ; Check if the filament is already triggering the endstop. OM = Other Motor/Temporary Axis.
    G28 'f                                                                                                    ; If not triggered, perform a homing move (G28) on the 'F' axis (motor feeds filament) until the switch is hit.
    if sensors.endstops[{global.Machine_om_axis_number}].triggered                                                    ; Check if the homing move successfully found the filament (switch triggered).
                                                                                                              ; --- Filament Detected: Update Status ---
        set global.AFC_lanes[var.unit_number][var.lane_number][0] = true                                                    ; Set the global flag that this lane is loaded.
        
         
                                                                                                              ; --- Optional Filament Retract/Pre-positioning ---

        if global.AFC_lanes[var.unit_number][var.lane_number][1] !== 0                                           ; If a previous first-load length is recorded (meaning filament was fully loaded once).
                                                                                                            ; G1: Perform an absolute move to retract the filament to the known "first length" position.
            G1 'f{global.AFC_lanes[var.unit_number][var.lane_number][1]} F{global.AFC_load_retract_speed[var.unit_number][0]*60} ; Move the filament back to a calculated parking position.
        M400
         
                                                                                                              ; --- LED Update ---
        set global.AFC_LED_array[var.unit_number][var.lane_number] = 1                                                         ; Set the LED array state for this lane (1 likely means filament present/ready).
        M98 P"0:/sys/AFC/Macros/leds.g"                                                                             ; Execute the macro to update the physical LED lights.
        M98 P"0:/sys/AFC/Macros/save_status.g"
M400                                                                                                          ; Wait for all movement/commands to finish.

; --- Cleanup ---
M574 'f1 P"nil" S1                                                                                            ; Disable the endstop for the temporary
M400
M18 'f
M584 P{var.total_axis-1}
if global.AFC_mainboard[var.unit_number] == 1
    while iterations < global.AFC_unit_total_lanes[var.unit_number]
        M950 J{global.AFC_trigger_input_numbers[var.unit_number][iterations]} C{global.AFC_prep_switch[var.unit_number][iterations]}
        M581 P{global.AFC_trigger_input_numbers[var.unit_number][iterations]} R2 T{global.AFC_trigger_numbers[var.unit_number][iterations]} S1