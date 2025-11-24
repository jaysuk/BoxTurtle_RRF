; === AFC Tool Post-Change Macro (tpost.g) ===
; Purpose: Finalizes the tool change sequence by heating the nozzle, priming filament,
; cleaning the nozzle, enabling sensors, and restoring the print position.

; --- Macro Parameters ---
; param.A - This is the lane number (Tool index).
; param.B - This is a flag to skip heating (1 = skip).

; --- AFC Feature Flags (Reference) ---
; 0 = brush, 1 = cut, 2 = kick, 3 = park, 4 = poop
; 5 = purge, 6 = load, 7 = startup check, 8 = dc motor on unload
; 9 = unload method, 10 = spoolman support

; --- Parameter Validation ---
if !exists(param.A)
    echo "Missing the lane number"
    abort

; --- Variable Initialization ---
var tpost_time=0                                                                                                              ; Variable to capture end time.
var tpre_time=global.AFC_time                                                                                                 ; Retrieve start time captured in tpre.g.
var time=0                                                                                                                    ; Variable for total duration calculation.
var time_seconds=0                                                                                                            ; Variable for seconds component.
var time_minutes=0                                                                                                            ; Variable for minutes component.
var lane_number=param.A                                                                                                       ; Local variable for the lane number.

; --- Heater Control ---
; If param.B is NOT present, or if it is NOT 1, proceed with heating.
if !exists(param.B) || param.B != 1
    if global.AFC_extruder_temp[{var.lane_number}] != 0                                                                       ; Check if a specific temp is defined for this lane.
        M568 P{var.lane_number} S{global.AFC_extruder_temp[{var.lane_number}]} R{global.AFC_extruder_temp[{var.lane_number}]} ; Set Active (S) and Standby (R) temps.
    else
        M568 P{var.lane_number} S220 R220                                                                                     ; Default to 220C if no specific temp is set.
    M116 P{var.lane_number}                                                                                                   ; Wait for the heater to reach the set temperature.

; --- Prime Nozzle (Move Filament from Park to Nozzle) ---
if global.AFC_features[1]                                                                                                     ; Check if "Cut" feature is enabled (implies different priming distance).
    G1 E{global.main_extruder_measurements[1]} F{global.AFC_load_retract_speed[0]*60}                                         ; Prime using measurement index 1.
else
    G1 E{global.main_extruder_measurements[0]} F{global.AFC_load_retract_speed[0]*60}                                         ; Prime using measurement index 0 (Standard).

M400                                                                                                                          ; Wait for priming moves to finish.

; --- Nozzle Cleaning Routines (Poop & Kick) ---
if global.AFC_features[4]                                                                                                     ; Check if "Poop" (Purge Bucket) feature is enabled.
    M98 P"0:/sys/AFC/poop.g"                                                                                                  ; Execute purge macro.

if global.AFC_features[2]                                                                                                     ; Check if "Kick" feature is enabled.
    M98 P"0:/sys/AFC/kick.g"                                                                                                  ; Execute kick macro to dislodge waste.

; --- Status Update and Sensor Activation ---
set global.AFC_LED_array[{var.lane_number}]=2                                                                                 ; Set LED status to Blue (Busy/Active).
M98 P"0:/sys/AFC/LEDs.g"                                                                                                      ; Update physical LEDs.

; Map Buffer Switches (TN - Tool Notch / Tension)
M950 J{global.AFC_buffer_input_numbers[0]} C{global.TN_switches[0]}                                                           ; Map Advance switch pin.
M950 J{global.AFC_buffer_input_numbers[1]} C{global.TN_switches[1]}                                                           ; Map Trail switch pin.

; Configure Triggers for Buffer Switches
M581 P{global.AFC_buffer_input_numbers[0]} R1 T{global.AFC_buffer_trigger_numbers[0]} S1                                      ; Trigger on Rising Edge (R1) for Advance switch.
M581 P{global.AFC_buffer_input_numbers[1]} R1 T{global.AFC_buffer_trigger_numbers[1]} S1                                      ; Trigger on Rising Edge (R1) for Trail switch.

; Enable Filament Monitor
M591 P1 D1 C{global.AFC_load_switch[var.lane_number]} S1                                                                      ; Enable filament monitor on Drive 1 using the lane's specific load switch.

M400

; --- Final Cleaning and Parking ---
if global.AFC_features[3]                                                                                                     ; Check if "Park" feature is enabled.
    M98 P"0:/sys/AFC/park.g"

if global.AFC_features[5]                                                                                                     ; Check if "Purge" feature is enabled.
    M98 P"0:/sys/AFC/purge.g"

if global.AFC_features[0]                                                                                                     ; Check if "Brush" feature is enabled.
    M98 P"0:/sys/AFC/brush.g"

M400

; --- Time Calculation and Reporting ---
set var.tpost_time=state.upTime                                                                                               ; Capture end time.
set var.time=var.tpost_time-var.tpre_time                                                                                     ; Calculate duration since tpre start.
set var.time_minutes=floor(var.time/60)                                                                                       ; Calculate minutes.
set var.time_seconds=var.time-(var.time_minutes*60)                                                                           ; Calculate seconds.

echo "The tool load time was "^var.time^" seconds ("^var.time_minutes^" minutes and "^var.time_seconds^" seconds)"

; --- Spoolman Integration ---
if global.AFC_features[10] == 1                                                                                               ; Check if Spoolman feature is enabled.
    set global.spoolman_capture_extrusion[{var.lane_number}] = true                                                           ; Enable extrusion tracking for this lane.
    G92 E0                                                                                                                    ; Reset extruder position.

; --- Restore Position ---
; G1 R2: Move to the position stored in Restore Point 2 (usually saved at the start of the tool change).
; Z5: Add a 5mm hop to the Z position during restoration.
G1 R2 X0 Y0 Z5 F{global.AFC_travel_speed[0]*60}                                                                               ; Return to print position.