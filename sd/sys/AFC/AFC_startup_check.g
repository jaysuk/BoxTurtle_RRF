; === AFC Initial State & Unload Macro (RepRapFirmware G-Code) ===

; --- AFC Feature Flags (Reference) ---
; 0 = brush                ; Used to check if specific optional cleaning/prep features are enabled.
; 1 = cut
; 2 = kick
; 3 = park
; 4 = poop
; 5 = purge
; 6 = load
; 7 = startup check
; 8 = use the dc motor on unload  ; Flag to determine if the DC motor assist should be used during filament removal.
; 9 = unload method
; 10 = spoolman support

; --- Variable Initialization ---
var hub_empty = false                                                                                                              ; Flag to track if the main filament hub/path is clear.
var lane_number = 0                                                                                                                ; Variable to store the lane number selected by the user.
var lane_in_extruder = false                                                                                                       ; Flag to track if the filament is currently loaded into the hotend.
var home_safe = false                                                                                                              ; Flag to track if it is safe to execute the G28 homing sequence.
var total_axis = #move.axes                                                                                                        ; Stores the total number of movement axes configured in the system.

; --- Hub Switch Check ---
M950 J{global.AFC_hub_input_number} C{global.AFC_hub_switch}                                                                       ; Map the logical input 'J' to the physical pin 'C' for the hub filament switch.
M400                                                                                                                               ; Wait for any previously queued commands to complete.
if sensors.gpIn[global.AFC_hub_input_number].value = 0                                                                             ; Check the current state of the hub switch (0 likely means filament is present).
    set var.hub_empty = true                                                                                                       ; Note: Logic seems inverted. If value=0 means filament IS present, hub_empty should be false here. Assuming 0 means **empty**.

M950 J{global.AFC_hub_input_number} C"nil"                                                                                         ; De-map the physical pin from the logical input to prevent accidental triggering.
M400

; --- User Prompt for Unload (If Hub is NOT Empty) ---
if !var.hub_empty
                                                                                                                                   ; M291: Display a user pop-up message (S4: stop on completion, J1: collect user input, K: buttons)
    M291 P"One of the lanes is loaded. Please select which one so it can be unloaded" K{"Lane 0","Lane 1","Lane 2","Lane 3"} S4 J1 ; Asks the user to select the lane to unload.
    set var.lane_number=input                                                                                                      ; Stores the selected lane number (0, 1, 2, or 3).

    M291 P{"Is Lane "^var.lane_number^" loaded into the extruder?"} K{"Yes","No"} S4 J1                                            ; Asks if the filament is loaded all the way to the hotend.
    if input == 0                                                                                                                  ; If "Yes" is selected (index 0).
        set var.lane_in_extruder = true

                                                                                                                                   ; --- Unload Filament from Hotend Path (Requires Homing) ---
    if var.lane_in_extruder
        M291 P{"Is it safe to home the printer?"} K{"Yes","No"} S4 J1                                                              ; Asks if the toolhead is clear to home.
        if input == 0                                                                                                              ; If "Yes".
            set var.home_safe = true
        if var.home_safe                                                                                                           ; If homing is safe.
            G28                                                                                                                    ; Home all axes.
            M568 P{var.lane_number} S220 A2                                                                                        ; Set tool P{lane_number} active temperature to 220°C and enable the heater.
            if global.AFC_features[8]                                                                                              ; Check feature flag 8: 'use the dc motor on unload'.
                M98 P"0:/sys/AFC/tfree.g" A{var.lane_number} B1                                                                    ; Call standard tfree.g macro with parameters for lane and DC motor usage (B1).
            else
                M98 P"0:/sys/AFC/tfree.g" A{var.lane_number} B0                                                                    ; Call standard tfree.g macro without DC motor usage (B0).
            M400                                                                                                                   ; Wait for unload to complete.
            M568 P{var.lane_number} A0                                                                                             ; Reset tool P{lane_number} to inactive (disables heater).
        elif !var.home_safe                                                                                                        ; If homing is NOT safe.
            M568 P{var.lane_number} S220 A2                                                                                        ; Set tool P{lane_number} active temperature to 220°C and enable the heater.
            if global.AFC_features[8]
                M98 P"0:/sys/AFC/tfree.g" A{var.lane_number} B1 C1                                                                 ; Call tfree.g with B1 (DC assist) and C1 (Skip homing/parking, assume unparked).
            else
                M98 P"0:/sys/AFC/tfree.g" A{var.lane_number} B0 C1                                                                 ; Call tfree.g with B0 (No DC assist) and C1 (Skip homing/parking).
            M400
            M568 P{var.lane_number} A0                                                                                             ; Reset tool P{lane_number} to inactive.

                                                                                                                                   ; --- Unload Filament from Hub/Lane Only (No Hotend Unload) ---
    if !var.lane_in_extruder
        M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}                                                                   ; Configure the motor associated with this lane as a temporary 'F' axis.
        M400
        M98 P"0:/sys/AFC/Motors/dc_motors.g" A"R" B{var.lane_number}                                                               ; Run the DC motor (if present) in reverse ('R') to wind the filament back onto the spool.
        M400
        M574 'f1 P{"!"^global.AFC_hub_switch} S1                                                                                   ; Define the temporary 'F' axis endstop as the inverted hub switch.
        G92 'f20000                                                                                                                ; Set the 'F' axis position to a large absolute value (20000 mm).
        G1 H4 'f-20000 F{global.AFC_load_retract_speed[1]*60}                                                                      ; Perform a homing move (H4) backward (-20000) on the 'F' axis to retract the filament until the hub switch is triggered.
        G91                                                                                                                        ; Switch to relative positioning mode.
        G1 'f{-global.AFC_hub_retract_distance} F{global.AFC_load_retract_speed[1]*60}                                             ; Retract the filament a set distance further to clear the hub switch.
        G90                                                                                                                        ; Switch back to absolute positioning mode.
        M574 'f1 P"nil" S1                                                                                                         ; Disable the 'F' axis endstop.
        M400
        M98 P"0:/sys/AFC/Motors/dc_motors.g" A"O" B{var.lane_number}                                                               ; Turn the DC motor off ('O').
        M400
        set global.AFC_LED_array[{var.lane_number}]=1                                                                              ; Set the LED color for this lane back to Green (assuming 1 = Green/Unloaded).
                                                                                                                                   ; M584 P{var.total_axis-1} is generally used to hide the last configured axes from the user interface
        M584 P{var.total_axis-1}                                                                                                   ; Hide the temporary 'F' axis from the system/UI.
        M400

; --- Re-Check Hub Status After Unload Attempt ---
if !var.hub_empty
    M950 J{global.AFC_hub_input_number} C{global.AFC_hub_switch}
    M400
    if sensors.gpIn[global.AFC_hub_input_number].value = 0
        set var.hub_empty = true                                                                                                   ; Re-check the hub switch state.

    M950 J{global.AFC_hub_input_number} C"nil"
    M400

; --- Automatic Unload Loop (If Hub is Empty) ---
; This section runs if the hub is detected as empty at the beginning or after a user-initiated unload.
if var.hub_empty
    while iterations < global.AFC_total_lanes                                                                                      ; Loop through all available lanes (0 to N-1).
        if global.AFC_lane_loaded[iterations]                                                                                      ; Check if the current lane is marked as loaded.
                                                                                                                                   ; M574 'f2 S1 P{switch} sets up the hub switch as a temporary 'F' axis endstop, stopping on the second trigger edge (S1 for low-level switch).
            M574 'f2 S1 P{global.AFC_hub_switch} 
            M400                                                                                                                   ; Set the hub switch up as an endstop for the temporary 'F' axis.
            M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{iterations}                                                                    ; Set up the motor for the current lane as the 'F' axis.
            M400
            G92 'f0                                                                                                                ; Set the 'F' axis current position to 0.
            M400
                                                                                                                                   ; G1 H4: perform a homing move (using an endstop) and stop on trigger.
            G1 H4 'f{global.AFC_lane_first_length[iterations]} F{global.AFC_load_retract_speed[0]*60}                              ; Feed filament forward until the hub switch is hit, measuring the distance moved.
            if move.axes[{global.om_axis_number}].machinePosition < global.AFC_lane_first_length[iterations]                       ; Check if the measured distance is less than expected, meaning filament is present but not fully loaded.
                G91                                                                                                                ; Switch to relative mode.
                G1 'f{-global.AFC_hub_retract_distance+10} F{global.AFC_load_retract_speed[1]*60}                                  ; Retract the filament by a calculated amount to clear the hub.
                G90                                                                                                                ; Switch back to absolute mode.
            else
                M98 P"0:/macros/Lane - Mark Unloaded" A{iterations}                                                                ; If the filament failed to reach the hub switch, it's considered unloaded, so run cleanup macro.
            M84 'f                                                                                                                 ; Disable (idle) the motor associated with the temporary 'F' axis.
            M574 'f1 P"nil" S1                                                                                                     ; Disable the 'F' axis endstop.
            M400
            M584 P{var.total_axis-1}                                                                                               ; Hide the temporary 'F' axis again.