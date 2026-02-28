; ==========================================================================================
; AFC Initial State & Unload Macro
; Checks if the system is clear. If blocked, guides user through unload.
; Then verifies the position of all loaded lanes.
; ==========================================================================================

; --- Machine Feature Flags (Reference) ---
; 0 = brush                ; Used to check if specific optional cleaning/prep features are enabled.
; 1 = cut
; 2 = kick
; 3 = park
; 4 = poop
; 5 = purge
; 6 = load
; 7 = startup check
; 8 = spoolman support

; --- AFC Feature Flags (Reference) ---
; 0 = use the dc motor on unload  ; Flag to determine if the DC motor assist should be used during filament removal.
; 1 = unload method

; --- Variable Initialization ---
var hub_empty = vector(#global.AFC_unit_CAN_ids, false)                                                                                                 ; Flag to track if the main filament hub/path is clear.
var unit_number = 0                                                                                                     ; Variable to store the unit number selected by the user.
var lane_number = 0                                                                                                    ; Variable to store the lane number selected by the user.
var lane_in_extruder = false                                                                                           ; Flag to track if the filament is currently loaded into the hotend.
var home_safe = false                                                                                                  ; Flag to track if it is safe to execute the G28 homing sequence.
var total_axis = #move.axes                                                                                            ; Stores the total number of movement axes configured in the system.
var msg_time = 3
var curUnit = 0
var tool_to_load = 0
var countdown = 0

; ==========================================================================================
; 1. Hub Status Check
; ==========================================================================================
while iterations <  #global.AFC_unit_CAN_ids
    set var.curUnit = iterations

    M950 J{global.AFC_hub_input_number[var.curUnit]} C{global.AFC_hub_switch[var.curUnit]}                                                       ; Map the logical input 'J' to the physical pin 'C' for the hub filament switch.
    M400                                                                                                                   ; Wait for any previously queued commands to complete.

    ; Check if switch is empty (0 = Empty/Open, 1 = Filament Present)
    if sensors.gpIn[global.AFC_hub_input_number[var.curUnit]].value == 0                                                              ; Check the current state of the hub switch (0 likely means filament is present).
        set var.hub_empty[var.curUnit] = true                                                                                           ; Note: Logic seems inverted. If value=0 means filament IS present, hub_empty should be false here. Assuming 0 means **empty**.

    ; Free the pin
    M950 J{global.AFC_hub_input_number[var.curUnit]} C"nil"                                                                           ; De-map the physical pin from the logical input to prevent accidental triggering.
    M400

; ==========================================================================================
; 2. Unload Routine (If Hub is Blocked)
; ==========================================================================================
while iterations <  #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    if !var.hub_empty[var.curUnit]
                                                                                                                        ; M291: Display a user pop-up message (S4: stop on completion, J1: collect user input, K: buttons)
        M291 P"One of the lanes on Unit "^var.curUnit^" is loaded. Please select which one so it can be unloaded" K{global.M291_data[1][var.curUnit]} S4 J1   ; Asks the user to select the lane to unload.
        set var.lane_number=input                                                                                          ; Stores the selected lane number (0, 1, 2, or 3).
        
        set var.tool_to_load = 0
        if var.curUnit = 0
            set var.tool_to_load = var.lane_number
        else 
            set var.countdown = var.curUnit
            set var.tool_to_load = var.lane_number
            while iterations < var.countdown
                set var.tool_to_load = var.tool_to_load + global.AFC_unit_total_lanes[iterations]
                set var.countdown = var.countdown - 1  
        
        M291 P{"Is Lane "^var.lane_number^" loaded into the extruder?"} K{"Yes","No"} S4 J1                                ; Asks if the filament is loaded all the way to the hotend.
        if input == 0                                                                                                      ; If "Yes" is selected (index 0).
            set var.lane_in_extruder = true
        
                                                                                                                        ; --- Unload Filament from Hotend Path (Requires Homing) ---
        if var.lane_in_extruder
            M291 P"Safety Check: Is it safe to home the printer?" K{"Yes", "No"} S4 J1                                     ; Asks if the toolhead is clear to home.
            if input == 0                                                                                                  ; If "Yes".
                set var.home_safe = true
            
            M291 P"Unloading from Hotend..." R"Busy" S0 T{var.msg_time}

                                                                                                                   ; Sequence: Home -> Heat -> Retract (tfree)
            if var.home_safe                                                                                               ; If homing is safe.
                G28                                                                                                        ; Home all axes.
                
                M568 P{var.tool_to_load} S220 A2                                                                            ; Set tool P{lane_number} active temperature to 220°C and enable the heater.
                T{var.tool_to_load} P0
                T-1
                M400
                M568 P{var.tool_to_load} A0                                                                                 ; Reset tool P{lane_number} to inactive (disables heater).
            else
                M291 P"Unsafe to automatically unload. Clear the printbed. Aborting..." R"Aborting" S0 T{var.msg_time}
                M400
                abort
                                                                                                                        ; --- Unload Filament from Hub/Lane Only (No Hotend Unload) ---
        if !var.lane_in_extruder
            M291 P"Clearing Hub Switch..." R"Busy" S0 T{var.msg_time}
            
                                                                                                                        ; Setup Axis
            M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.tool_to_load}                                                       ; Configure the motor associated with this lane as a temporary 'F' axis.
            M400
            
                                                                                                                        ; DC Assist (Reverse)
            M98 P"0:/sys/AFC/Motors/dc_motors.g" A"R" B{var.tool_to_load}                                                   ; Run the DC motor (if present) in reverse ('R') to wind the filament back onto the spool.
            M400
            
                                                                                                                        ; Retract until Hub Switch OPENS (P"!"...)
            M574 'f1 P{"!"^global.AFC_hub_switch[var.curUnit]} S1                                                                     ; Define the temporary 'F' axis endstop as the inverted hub switch.
            G92 'f{global.AFC_max_min_axes[var.curUnit][1]}                                                                                                   ; Set the 'F' axis position to a large absolute value (20000 mm).
            G1 H4 'f{-global.AFC_max_min_axes[var.curUnit][1]}    F{global.AFC_load_retract_speed[var.curUnit][1]*60}                                                        ; Perform a homing move (H4) backward (-20000) on the 'F' axis to retract the filament until the hub switch is triggered.
            
                                                                                                                        ; Safety Retract (Back off slightly more)
            G91                                                                                                            ; Switch to relative positioning mode.
            G1 'f{-global.AFC_hub_retract_distance[var.curUnit]} F{global.AFC_load_retract_speed[var.curUnit][1]*60}                             ; Retract the filament a set distance further to clear the hub switch.
            G90                                                                                                            ; Switch back to absolute positioning mode.
            
                                                                                                                        ; Cleanup
            M574 'f1 P"nil" S1                                                                                             ; Disable the 'F' axis endstop.
            M400
            M98 P"0:/sys/AFC/Motors/dc_motors.g" A"O" B{var.tool_to_load}                                                   ; Turn the DC motor off ('O').
            M400
            
                                                                                                                        ; Reset LED to "Loaded/Ready" (Green)
            set global.AFC_LED_array[var.curUnit][var.lane_number]=1                                                                ; Set the LED color for this lane back to Green (assuming 1 = Green/Unloaded).
                                                                                                                        ; M584 P{var.total_axis-1} is generally used to hide the last configured axes from the user interface
            M98 P"0:/sys/AFC/LEDs.g"                                                                             ; Execute the macro to update the physical LED lights.
            M98 P"0:/sys/AFC/Macros/save_status.g"
                                                                                                                        ; Hide Axis
            M584 P{var.total_axis-1}                                                                                       ; Hide the temporary 'F' axis from the system/UI.
            M400

    ; --- Re-Check Hub Status After Unload Attempt ---
    if !var.hub_empty[var.curUnit]
        M950 J{global.AFC_hub_input_number[var.curUnit]} C{global.AFC_hub_switch[var.curUnit]}
        M400
        if sensors.gpIn[global.AFC_hub_input_number[var.curUnit]].value == 0
            set var.hub_empty = true                                                                                       ; Re-check the hub switch state.
            M950 J{global.AFC_hub_input_number[var.curUnit]} C"nil"
        else
            M291 P"Hub still not empty. Aborting..." R"Aborting" S0 T{var.msg_time}
            M950 J{global.AFC_hub_input_number[var.curUnit]} C"nil"
            M400
            abort

; ==========================================================================================
; 3. System Consistency Check (Verify all Loaded Lanes)
; ==========================================================================================
while iterations <  #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    if var.hub_empty[var.curUnit]
        M291 P"Hub Clear. Verifying lane positions..." R"System Check" S0 T{var.msg_time}
        while iterations <  #global.AFC_unit_CAN_ids
            set var.curUnit = iterations
            set var.curLane = 0
            
            while var.curLane < global.AFC_unit_total_lanes[var.curUnit]                                                                        ; Loop through all available lanes (0 to N-1).
                
                                                                                                                            ; Only check lanes that the software thinks are loaded
                if global.AFC_lanes[var.curUnit][var.curLane][0]                                                                         ; Check if the current lane is marked as loaded.
                    
                                                                                                                            ; M574 'f2 S1 P{switch} sets up the hub switch as a temporary 'F' axis endstop, stopping on the second trigger edge (S1 for low-level switch).
                    M574 'f2 S1 P{global.AFC_hub_switch[var.curUnit]} 
                    M400                                                                                                       ; Set the hub switch up as an endstop for the temporary 'F' axis.

                    set var.tool_to_load = 0
                    if var.curUnit = 0
                        set var.tool_to_load = var.curLane
                    else 
                        set var.countdown = var.curUnit
                        set var.tool_to_load = var.curLane
                        while iterations < var.countdown
                            set var.tool_to_load = var.tool_to_load + global.AFC_unit_total_lanes[iterations]
                            set var.countdown = var.countdown - 1  

                    M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.tool_to_load}                                                        ; Set up the motor for the current lane as the 'F' axis.
                    M400
                    
                                                                                                                            ; Probe Forward to Hub Switch
                    G92 'f0                                                                                                    ; Set the 'F' axis current position to 0.
                    M400
                                                                                                                            ; G1 H4: perform a homing move (using an endstop) and stop on trigger.
                    G1 H4 'f{global.AFC_lanes[var.curUnit][var.curLane][1]} F{global.AFC_load_retract_speed[var.curUnit][0]*60}              ; Feed filament forward until the hub switch is hit, measuring the distance moved.

                                                                                                                            ; --- Logic Check ---
                                                                                                                            ; If we stopped BEFORE the full distance, the switch triggered (Filament Found).
                    if move.axes[global.Machine_om_axis_number].machinePosition < global.AFC_lanes[var.curUnit][var.curLane][1] ; Check if the measured distance is less than expected, meaning filament is present but not fully loaded.
                        G91                                                                                                    ; Switch to relative mode.
                        G1 'f{-global.AFC_hub_retract_distance[var.curUnit]+10} F{global.AFC_load_retract_speed[var.curUnit][1]*60}                  ; Retract the filament by a calculated amount to clear the hub.
                        G90                                                                                                    ; Switch back to absolute mode.
                    else
                                                                                                                            ; Filament NOT found (reached end without triggering).
                                                                                                                            ; Mark as Unloaded.
                        M291 P{"Unit " ^ var.curUnit ^ ": Lane " ^ iterations ^ " was empty. Updating status."} R"Correction" S1 T{var.msg_time}
                        M98 P"0:/macros/Lane - Mark Unloaded" A{var.tool_to_load}                                                    ; If the filament failed to reach the hub switch, it's considered unloaded, so run cleanup macro.
                        M98 P"0:/macros/Spool - Unassign" A{var.curUnit} B{var.curLane}                                              ; Automatically clear the spool data for this empty lane
                    
                                                                                                                            ; Cleanup
                    M18 'f                                                                                                     ; Disable (idle) the motor associated with the temporary 'F' axis.
                    M574 'f1 P"nil" S1                                                                                         ; Disable the 'F' axis endstop.
                    M400
                    M584 P{var.total_axis-1}                                                                                   ; Hide the temporary 'F' axis again.
                set var.curLane = var.curLane + 1
            M291 P"System Ready." R"Startup Complete" S1 T{var.msg_time}