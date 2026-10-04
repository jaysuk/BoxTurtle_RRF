; === AFC Tool Post-Change Macro (tpost.g) ===
; Purpose: Finalizes the tool change sequence by heating the nozzle, priming filament,
; cleaning the nozzle, enabling sensors, and restoring the print position.

; --- Macro Parameters ---
; param.A - This is the lane number (Tool index).
; param.B - This is a flag to skip heating (1 = skip).

; --- Machine Feature Flags (Machine_features) ---
; 0 = brush, 1 = cut, 2 = kick, 3 = park, 4 = poop
; 5 = purge, 6 = start check, 7 = spool tracking, 8 = initial unload

; --- Parameter Validation ---
if !exists(param.A)
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"tpost.g: missing the tool number (A)" Q1
    M99

; A failed tfree/tpre has already reported the problem (and pauses the print). Never issue T here (RRF_NOTES) - just stand down.
if global.Machine_tpre_failed
    set global.Machine_tpre_failed = false
    M568 P{param.A} A0                                                                                                                         ; The tool stays selected but its heater goes to standby.
    M118 S"AFC: the tool change failed, so tpost was skipped. Fix the problem, then reselect the tool"
    M99

; --- Variable Initialization ---
var tpost_time = 0                                                                                                                         ; Variable to capture end time.
var tpre_time = global.AFC_time                                                                                                            ; Retrieve start time captured in tpre.g.
var time = 0                                                                                                                               ; Variable for total duration calculation.
var time_seconds = 0                                                                                                                       ; Variable for seconds component.
var time_minutes = 0                                                                                                                       ; Variable for minutes component.
var tool_number = param.A                                                                                                                  ; Local variable for the lane number.
var unit_number = global.AFC_tool_map[var.tool_number][0]                                                                                   ; Get Unit ID from Tool ID
var lane_number = global.AFC_tool_map[var.tool_number][1]                                                                                   ; Get Local Lane ID (0-3)
var afc_ext = tools[var.tool_number].extruders[#tools[var.tool_number].extruders - 1]                                                      ; The AFC extruder is the last drive of the tool
var prime_distance = global.Machine_extruder_measurements[0]                                                                               ; Filament to feed from the extruder input to the nozzle
var prime_fast = 0                                                                                                                         ; Part of the prime that can run at lane speed

; --- Heater Control ---
; If param.B is NOT present, or if it is NOT 1, proceed with heating.
if !exists(param.B) || param.B != 1
    if global.AFC_extruder_temp[var.unit_number][var.lane_number] != 0                                                                     ; Check if a specific temp is defined for this lane.
        M568 P{var.tool_number} S{global.AFC_extruder_temp[var.unit_number][var.lane_number]} R{global.AFC_extruder_temp[var.unit_number][var.lane_number]} ; Set Active (S) and Standby (R) temps.
    else
        M568 P{var.tool_number} S220 R220                                                                                                  ; Default to 220C if no specific temp is set.
    M116 P{var.tool_number}                                                                                                                ; Wait for the heater to reach the set temperature.

; --- Spool Tracking: start counting at the prime so prime and poop filament are deducted too ---
M83                                                                                                                                        ; Relative extrusion
G92 E0                                                                                                                                     ; Reset extruder position BEFORE the baseline snapshot.
if global.Machine_features[7] == 1                                                                                                         ; Check if spool tracking is enabled.
    var extIdx = tools[var.tool_number].filamentExtruder
    if var.extIdx != -1
        set global.spool_extrusion_baseline[var.tool_number] = move.extruders[var.extIdx].position
        set global.spool_unsaved_extrusion[var.tool_number] = 0.0
    set global.spool_tracking[var.unit_number][var.lane_number][1] = true                                                                        ; Enable extrusion tracking for this lane.

; --- Prime Nozzle (Move Filament from Park to Nozzle) ---
if global.Machine_features[1]                                                                                                              ; Check if "Cut" feature is enabled (implies different priming distance).
    set var.prime_distance = global.Machine_extruder_measurements[1]                                                                       ; Prime using measurement index 1 (input to cutter).
set var.prime_fast = max(var.prime_distance - 10, 0)
G1 E{var.prime_fast} F{global.AFC_load_retract_speed[var.unit_number][0]*60}                                                               ; Fast through the cold section.
G1 E{var.prime_distance - var.prime_fast} F{global.AFC_load_retract_speed[var.unit_number][2]*60}                                          ; Last 10mm at the extruder-limited speed (the nozzle is hot).

M400                                                                                                                                       ; Wait for priming moves to finish.

; --- Nozzle Cleaning Routines (Poop & Kick) ---
if global.Machine_features[4]                                                                                                              ; Check if "Poop" (Purge Bucket) feature is enabled.
    M98 P"0:/sys/AFC/Macros/poop.g"                                                                                                        ; Execute purge macro.

if global.Machine_features[2] && !global.Machine_tpre_failed                                                                               ; Check if "Kick" feature is enabled.
    M98 P"0:/sys/AFC/Macros/kick.g"                                                                                                        ; Execute kick macro to dislodge waste.

if global.Machine_tpre_failed                                                                                                              ; poop/kick failed and has already reported it
    set global.Machine_tpre_failed = false
    M99

; --- Status Update and Sensor Activation ---
set global.AFC_LED_array[var.unit_number][var.lane_number]=2                                                                               ; Set LED status to Blue (Busy/Active).
M98 P"0:/sys/AFC/Macros/leds.g"                                                                                                            ; Update physical LEDs.

; Map Buffer Switches (TN - Tool Notch / Tension)
M950 J{global.AFC_buffer_input_numbers[var.unit_number][0]} C{global.AFC_TN_switches[var.unit_number][0]}                                  ; Map Advance switch pin.
M950 J{global.AFC_buffer_input_numbers[var.unit_number][1]} C{global.AFC_TN_switches[var.unit_number][1]}                                  ; Map Trail switch pin.

; Configure Triggers for Buffer Switches
M581 P{global.AFC_buffer_input_numbers[var.unit_number][0]} R1 T{global.AFC_buffer_trigger_numbers[var.unit_number][0]} S1                 ; Trigger on both edges (R1; S1 rising + S0 falling) for Advance switch.
M581 P{global.AFC_buffer_input_numbers[var.unit_number][0]} R1 T{global.AFC_buffer_trigger_numbers[var.unit_number][0]} S0
M581 P{global.AFC_buffer_input_numbers[var.unit_number][1]} R1 T{global.AFC_buffer_trigger_numbers[var.unit_number][1]} S1                 ; Trigger on both edges (R1; S1 rising + S0 falling) for Trail switch.
M581 P{global.AFC_buffer_input_numbers[var.unit_number][1]} R1 T{global.AFC_buffer_trigger_numbers[var.unit_number][1]} S0

; Buffer fault trigger (3.7 M581.1): both buffer switches active at the same time means a jam or a wiring fault
M581.1 T{global.AFC_buffer_fault_triggers[var.unit_number]} P{"sensors.gpIn["^global.AFC_buffer_input_numbers[var.unit_number][0]^"].value == 1 && sensors.gpIn["^global.AFC_buffer_input_numbers[var.unit_number][1]^"].value == 1"} R1

; Enable Filament Monitor on this tool's AFC extruder, using the lane's load switch (re-created here because M584 E remaps the driver)
M591 P1 D{var.afc_ext} C{global.AFC_load_switch[var.unit_number][var.lane_number]} S1

M400

; --- Final Cleaning and Parking ---
if global.Machine_features[3]                                                                                                              ; Check if "Park" feature is enabled.
    M98 P"0:/sys/AFC/Macros/park.g" A1

if global.Machine_features[5] && !global.Machine_tpre_failed                                                                               ; Check if "Purge" feature is enabled.
    var safe_place = 0                                                                                                                     ; purge only extrudes when the head is over the park position or the poop bucket
    if global.Machine_features[3] || global.Machine_features[4]
        set var.safe_place = 1
    M98 P"0:/sys/AFC/Macros/purge.g" A{var.safe_place} B{var.tool_number}

if global.Machine_features[0] && !global.Machine_tpre_failed                                                                               ; Check if "Brush" feature is enabled.
    M98 P"0:/sys/AFC/Macros/brush.g"

M400

if global.Machine_tpre_failed                                                                                                              ; park/purge/brush failed and has already reported it
    set global.Machine_tpre_failed = false
    M99

; --- Time Calculation and Reporting ---
set var.tpost_time=state.upTime                                                                                                            ; Capture end time.
set var.time=var.tpost_time-var.tpre_time                                                                                                  ; Calculate duration since tpre start.
set var.time_minutes=floor(var.time/60)                                                                                                    ; Calculate minutes.
set var.time_seconds=var.time-(var.time_minutes*60)                                                                                        ; Calculate seconds.

M118 S{"The tool load time was "^var.time^" seconds ("^var.time_minutes^" minutes and "^var.time_seconds^" seconds)"}
M98 P"0:/sys/AFC/Macros/afc_log.g" S{"T"^var.tool_number^" loaded in "^var.time^"s (Unit "^var.unit_number^" Lane "^var.lane_number^")"}

M98 P"0:/sys/AFC/Macros/save_status.g"

; --- Restore Position ---
; G1 R2: Move to the position stored in Restore Point 2 (usually saved at the start of the tool change).
; Z5: Add a 5mm hop to the Z position during restoration.
G1 R2 X0 Y0 Z5 F{global.Machine_travel_speed[0]*60}                                                                                        ; Return to print position.
; Lower the 5 mm hop so the next move starts at the correct layer height
G1 R2 Z0 F{global.Machine_travel_speed[1]*60}
