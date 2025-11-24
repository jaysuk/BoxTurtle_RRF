; === Filament Runout / Error Recovery Macro (Duet RepRapFirmware) ===
; This macro is typically called by a filament monitor (M591) upon detecting an error.

; --- Macro Parameters (passed from the M591 error command) ---
; param.A - This is the lane number (index of the failing filament).
; param.B - CAN address of board hosting the filament monitor (used for complex setups).
; param.D - Extruder # (The logical extruder index).
; param.P - Filament error type code (e.g., runout, too fast, too slow).

M226                                                                                                                      ; Pause the print immediately upon detection of the filament error.

; --- Parameter Validation ---
if !exists(param.A)
    echo "Missing the lane number"                                                                                        ; Report error if the required lane number parameter is missing.
    abort                                                                                                                 ; Terminate the macro execution.

var lane_number = param.A                                                                                                 ; Store the failing lane index locally for easier access.
var choice=0                                                                                                              ; Local variable to store the user's main recovery choice (0 or 1).
var choice_lane=0                                                                                                         ; Local variable to store the index of the new lane selected by the user.

; --- Initial Unload of the Failed Filament ---
; Check AFC feature flag 8 (use DC motor on unload) to determine the tfree call parameters.
if global.AFC_features[8]
    M98 P"0:/sys/AFC/tfree.g" A{var.lane_number} B1                                                                       ; Call tool-free macro, enabling DC assist (B1).
else
    M98 P"0:/sys/AFC/tfree.g" A{var.lane_number} B0                                                                       ; Call tool-free macro, disabling DC assist (B0).

M98 P"0:/sys/AFC/unload.g" A{var.lane_number} B1                                                                          ; Call the specific AFC unload macro for the failed lane. (B1 is likely a flag for 'error unload').

; --- Check for Continuous Feed Backup (Auto-switch logic) ---
; This loop checks if any other active lane is flagged for continuous feed, and if so, initiates a switch.
if global.AFC_lane_continuous[var.lane_number]                                                                            ; Check if the failed lane was set as continuous (should fail if runout is detected).
    while iterations < global.AFC_total_lanes                                                                             ; Iterate through all defined lanes.
        if iterations != var.lane.number                                                                                  ; Skip the current failed lane.
            if global.AFC_lane_continuous[iterations]                                                                     ; Check if a different lane is marked for continuous use.
                M98 P"0:/sys/AFC/tpre.g" A{iterations}                                                                    ; Prepare the new continuous lane (load sequence pre-macro).
                M98 P"0:/sys/AFC/tpost.g" A{iterations} B1                                                                ; Complete the tool change (load sequence post-macro, B1 likely signals 'error recovery').
                set global.AFC_lane_continuous[var.lane_number] = false                                                   ; Clear the continuous flag on the *failing* lane.
                M24                                                                                                       ; Resume the paused print (M24).

; --- User Interaction (Manual Recovery Selection) ---
; M291: Display a popup message. S4: Modal; J1: Collects user input; K: Button options.
M291 P"Select the option below" S4 J1 K{"Reload Lane "^{var.lane_number},"Continue with a different Lane"}                ; Prompt user for recovery choice.
set var.choice=input                                                                                                      ; Store user's button selection (0 or 1).

; --- Choice 0: Reload Current Lane ---
if var.choice == 0                                                                                                        ; If user selects "Reload Lane X".
    M291 R"Lane "^{var.lane_number}^" Filament Runout" P"Reload filament into lane "^{var.lane_number}^" and click ok" S2 ; Display a persistent (S2) message prompting user to physically reload the filament.
    if global.AFC_lane_loaded[var.lane_number]                                                                            ; Check if the lane is now loaded (assumes user reloaded and clicked OK on the M291).
        M98 P"0:/sys/AFC/tpre.g" A{var.lane_number}                                                                       ; Prepare the reloaded lane (tpre.g).
        M98 P"0:/sys/AFC/tpost.g" A{var.lane_number} B1                                                                   ; Complete the tool load/change (tpost.g).
        M24                                                                                                               ; Resume the print.

; --- Choice 1: Switch to a Different Lane ---
if var.choice == 1                                                                                                        ; If user selects "Continue with a different Lane".
    M291 P"Select the lane to be used" K{"Lane 0","Lane 1","Lane 2","Lane 3"} S4 J1                                       ; Prompt user to choose the new lane.
    set var.choice_lane=input                                                                                             ; Store the selected new lane index.
    if global.AFC_lane_loaded[var.choice_lane]                                                                            ; Check if the selected new lane is loaded with filament.
        M98 P"0:/sys/AFC/tpre.g" A{var.choice_lane}                                                                       ; Prepare the new lane.
        M98 P"0:/sys/AFC/tpost.g" A{var.choice_lane} B1                                                                   ; Complete the tool change.
        M24                                                                                                               ; Resume the print.
    else
                                                                                                                          ; --- Secondary Lane Choice (If first choice was unloaded) ---
        M291 P"Select a different lane to be used" K{"Lane 0","Lane 1","Lane 2","Lane 3"} S4 J1                           ; Prompt for a new lane selection.
        set var.choice_lane=input                                                                                         ; Store the secondary selection.
        if global.AFC_lane_loaded[var.choice_lane]                                                                        ; Check if the secondary choice is loaded.
            M98 P"0:/sys/AFC/tpre.g" A{var.choice_lane}                                                                   ; Prepare the new lane.
            M98 P"0:/sys/AFC/tpost.g" A{var.choice_lane} B1                                                               ; Complete the tool change.
            M24                                                                                                           ; Resume the print.