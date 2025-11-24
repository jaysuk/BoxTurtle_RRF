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
if !exists(param.A)                                                                                           ; Check if the required 'A' parameter (lane number) was passed to the macro.
    echo "Missing the lane number"                                                                            ; Report the error.
    abort                                                                                                     ; Stop macro execution if the parameter is missing.

var lane_number=param.A                                                                                       ; Assign the input parameter to a local variable for easier use.

; --- Axis Setup ---
; Call a sub-macro to configure the motor associated with the current lane as a temporary axis (likely 'F').
M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}

var total_axis=#move.axes                                                                                     ; Store the total number of axes (used later to hide the temporary axis).

; --- Filament Detection Routine ---
; M574: Define endstop configuration for the temporary axis ('f').
M574 'f1 P{global.AFC_load_switch[var.lane_number]} S1                                                        ; Assign the physical pin (P) for the filament load switch of the current lane to the 'F' axis, using active-low/normal switch mode (S1).
G92 'f0                                                                                                       ; Set the current position of the temporary 'F' axis to 0.

if !sensors.endstops[{global.om_axis_number}].triggered                                                       ; Check if the filament is already triggering the endstop. OM = Other Motor/Temporary Axis.
    G28 'f                                                                                                    ; If not triggered, perform a homing move (G28) on the 'F' axis (motor feeds filament) until the switch is hit.
    if sensors.endstops[{global.om_axis_number}].triggered                                                    ; Check if the homing move successfully found the filament (switch triggered).
                                                                                                              ; --- Filament Detected: Update Status ---
        set global.AFC_lane_loaded[{var.lane_number}]=true                                                    ; Set the global flag that this lane is loaded.
        echo >"0:/sys/AFC/AFC-info/lane_status.g" "; lane status"                                             ; Overwrite/start the lane status file.
        echo >>"0:/sys/AFC/AFC-info/lane_status.g" "set global.AFC_lane_loaded = " ^ global.AFC_lane_loaded   ; Save the updated loaded status array to the file.
         
                                                                                                              ; --- Optional Filament Retract/Pre-positioning ---
        if fileexists("0:/sys/AFC/AFC-info/lane_first_length.g")                                              ; Check for a file containing the filament length used on first load.
            if global.AFC_lane_first_length[{var.lane_number}] !==0                                           ; If a previous first-load length is recorded (meaning filament was fully loaded once).
                                                                                                              ; G1: Perform an absolute move to retract the filament to the known "first length" position.
                G1 'f{global.AFC_lane_first_length[{var.lane_number}]} F{global.AFC_load_retract_speed[0]*60} ; Move the filament back to a calculated parking position.
            M400
         
                                                                                                              ; --- LED Update ---
        set global.AFC_LED_array[{var.lane_number}]=1                                                         ; Set the LED array state for this lane (1 likely means filament present/ready).
        M98 P"0:/sys/AFC/LEDs.g"                                                                              ; Execute the macro to update the physical LED lights.
M400                                                                                                          ; Wait for all movement/commands to finish.

; --- Cleanup ---
M574 'f1 P"nil" S1                                                                                            ; Disable the endstop for the temporary