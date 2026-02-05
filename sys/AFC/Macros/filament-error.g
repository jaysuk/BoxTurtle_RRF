; === Filament Runout / Error Recovery Macro (Duet RepRapFirmware) ===
; This macro is typically called by a filament monitor (M591) upon detecting an error.

; --- Macro Parameters (passed from the M591 error command) ---
; param.B - CAN address of board hosting the filament monitor (used for complex setups).
; param.D - Extruder # (The logical extruder index).
; param.P - Filament error type code (e.g., runout, too fast, too slow).

M226                                                                                                                                ; Pause the print immediately upon detection of the filament error.

; --- Parameter Validation ---
var tool_number = param.D                                                                                                           ; Assign the input parameter to a local variable for easier use.
var unit_number = global.Tool_to_AFC[var.tool_number][0]
var lane_number = global.Tool_to_AFC[var.tool_number][1]
var curUnit = 0
var curLane = 0
var choice = 0                                                                                                                      ; Local variable to store the user's main recovery choice (0 or 1).
var choice_lane = 0                                                                                                                 ; Local variable to store the index of the new lane selected by the user.
var tool_to_load = 0
var countdown = 0
var choice_unit = 0

; --- Initial Unload of the Failed Filament ---
; Check AFC feature flag 0 (use DC motor on unload) to determine the tfree call parameters.
; 0 = use dc motors
; 1 = how to unload? hubswitch or lengths?
if global.AFC_features[0]
    M98 P"0:/sys/AFC/Macros/tfree.g" A{var.tool_number} B1                                                                          ; Call tool-free macro, enabling DC assist (B1).
else
    M98 P"0:/sys/AFC/Macros/tfree.g" A{var.tool_number} B0                                                                          ; Call tool-free macro, disabling DC assist (B0).

M98 P"0:/sys/AFC/Macros/unload.g" A{var.tool_number} B1                                                                             ; Call the specific AFC unload macro for the failed lane. (B1 is likely a flag for 'error unload').

; --- Check for Continuous Feed Backup (Auto-switch logic) ---
; This loop checks if any other active lane is flagged for continuous feed, and if so, initiates a switch.
if global.AFC_lanes[var.unit_number][var.lane_number][3]                                                                            ; Check if the failed lane was set as continuous (should fail if runout is detected).
    while iterations < #global.AFC_unit_CAN_ids
        set var.curUnit = iterations
        set var.curLane = 0
        ; FIX: Updated variable name to 'global.AFC_unit_total_lanes' to match AFC_Units.g
        while var.curLane < global.AFC_unit_total_lanes[var.curUnit]                                                                ; Iterate through all defined lanes.
            if (var.curLane != var.lane_number) && (var.curUnit != var.unit_number)                                                 ; Skip the current failed lane.
                if global.AFC_lanes[var.curUnit][var.curLane][3]                                                                    ; Check if a different lane is marked for continuous use.
                    if var.curUnit = 0
                        set var.tool_to_load = var.lane_number
                    else 
                        set var.countdown = var.curUnit
                        set var.tool_to_load = var.lane_number
                        while iterations < var.countdown
                            set var.tool_to_load = var.tool_to_load + global.AFC_unit_total_lanes[iterations]
                            set var.countdown = var.countdown - 1  
                    M98 P"0:/sys/AFC/Macros/tpre.g" A{var.tool_to_load}                                                             ; Prepare the new continuous lane (load sequence pre-macro).
                    M98 P"0:/sys/AFC/Macros/tpost.g" A{var.tool_to_load} B1                                                         ; Complete the tool change (load sequence post-macro, B1 likely signals 'error recovery').
                    set global.AFC_lanes[var.curUnit][var.curLane][3] = false                                                       ; Clear the continuous flag on the *failing* lane.
                    M24                                                                                                             ; Resume the paused print (M24).
            set var.curLane = var.curLane + 1

; --- User Interaction (Manual Recovery Selection) ---
; M291: Display a popup message. S4: Modal; J1: Collects user input; K: Button options.
M291 P"Select the option below" S4 J1 K{"Reload Lane "^{var.lane_number},"Continue with a different Lane"}                          ; Prompt user for recovery choice.
set var.choice=input                                                                                                                ; Store user's button selection (0 or 1).

; --- Choice 0: Reload Current Lane ---
if var.choice == 0                                                                                                                  ; If user selects "Reload Lane X".
    M291 R"Lane "^{var.lane_number}^" Filament Runout" P"Reload filament into lane "^{var.lane_number}^" and click ok" S2           ; Display a persistent (S2) message prompting user to physically reload the filament.
    if var.unit_number = 0
        set var.tool_to_load = var.lane_number
    else 
        set var.countdown = var.unit_number
        set var.tool_to_load = var.lane_number
        while iterations < var.countdown
            set var.tool_to_load = var.tool_to_load + global.AFC_unit_total_lanes[iterations]
            set var.countdown = var.countdown - 1
    if global.AFC_lanes[var.unit_number][var.lane_number][0]                                                                        ; Check if the lane is now loaded (assumes user reloaded and clicked OK on the M291).
        M98 P"0:/sys/AFC/Macros/tpre.g" A{var.tool_to_load}                                                                         ; Prepare the reloaded lane (tpre.g).
        M98 P"0:/sys/AFC/Macros/tpost.g" A{var.tool_to_load} B1                                                                     ; Complete the tool load/change (tpost.g).
        M24                                                                                                                         ; Resume the print.

; --- Choice 1: Switch to a Different Lane ---
if var.choice == 1                                                                                                                  ; If user selects "Continue with a different Lane".
    ; FIX: Updated to use global.M291_data[0] for Unit List
    if #global.M291_data[0] != 1
        M291 P"Select the Unit" K{global.M291_data[0]} S4 J1
        set var.choice_unit = input
    
    ; FIX: Updated to use global.M291_data[1] for Lane List
    M291 P"Select the lane to be used" K{global.M291_data[1][var.choice_unit]} S4 J1                                                ; Prompt user to choose the new lane.
    set var.choice_lane=input                                                                                                       ; Store the selected new lane index.

    if var.choice_unit = 0
        set var.tool_to_load = var.choice_lane
    else 
        set var.countdown = var.choice_unit
        set var.tool_to_load = var.choice_lane
        while iterations < var.countdown
            set var.tool_to_load = var.tool_to_load + global.AFC_unit_total_lanes[iterations]
            set var.countdown = var.countdown - 1

    if global.AFC_lanes[var.choice_unit][var.choice_lane][0]                                                                        ; Check if the selected new lane is loaded with filament.
        M98 P"0:/sys/AFC/Macros/tpre.g" A{var.choice_lane}                                                                          ; Prepare the new lane.
        M98 P"0:/sys/AFC/Macros/tpost.g" A{var.choice_lane} B1                                                                      ; Complete the tool change.
        M24                                                                                                                         ; Resume the print.
    else
                                                                                                                                    ; --- Secondary Lane Choice (If first choice was unloaded) ---
        ; FIX: Updated to use global.M291_data[0] for Unit List
        if #global.M291_data[0] != 1
            M291 P"Select a different Unit as the chosen lane was empty" K{global.M291_data[0]} S4 J1
            set var.choice_unit = input
        
        ; FIX: Updated to use global.M291_data[1] for Lane List
        M291 P"Select a different lane to be used as the chosen lane was empty" K{global.M291_data[1][var.choice_unit]} S4 J1       ; Prompt user to choose the new lane.
        set var.choice_lane=input                                                                                                   ; Store the selected new lane index.

        if var.choice_unit = 0
            set var.tool_to_load = var.choice_lane
        else 
            set var.countdown = var.choice_unit
            set var.tool_to_load = var.choice_lane
            while iterations < var.countdown
                set var.tool_to_load = var.tool_to_load + global.AFC_unit_total_lanes[iterations]
                set var.countdown = var.countdown - 1

        if global.AFC_lanes[var.choice_unit][var.choice_lane][0]                                                                    ; Check if the selected new lane is loaded with filament.
            M98 P"0:/sys/AFC/Macros/tpre.g" A{var.choice_lane}                                                                      ; Prepare the new lane.
            M98 P"0:/sys/AFC/Macros/tpost.g" A{var.choice_lane} B1                                                                  ; Complete the tool change.
            M24                                                                                                                     ; Resume the print.