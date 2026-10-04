; === AFC Filament Insert Macro (called by the generated trigger<N>.g when filament is inserted into a lane) ===
; Runs only while NOT printing (the lane triggers are M581 R2). Feeds the filament to the load switch, marks the lane as
; loaded and moves it to the park position (stored first length).

; --- Macro Parameters ---
; param.A - tool number of the lane that triggered

; --- Parameter Validation ---
if !exists(param.A)
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"triggers.g: missing the tool number (A)"
    M99

var tool_number = param.A
var unit_number = global.Tool_to_AFC[var.tool_number][0]
var lane_number = global.Tool_to_AFC[var.tool_number][1]
var search_distance = 300                                                                                       ; Max distance to push the filament while looking for the load switch

; --- Axis Setup ---
; Maps the lane motor to 'f, unhides it and (Longboi) disarms the lane triggers while we move.
M98 P"0:/sys/AFC/Macros/lane_motion_begin.g" A{var.tool_number}

; --- Filament Detection Routine ---
; The lane's load switch is the 'f min endstop.
M574 'f1 P{global.AFC_load_switch[var.unit_number][var.lane_number]} S1
G92 'f0                                                                                                         ; Position is relative to where the filament is now
if !sensors.endstops[global.AFC_f_axis].triggered                                                               ; Filament is not on the switch yet: push it forward until it is
    G1 H1 'f{var.search_distance} F{global.AFC_load_retract_speed[var.unit_number][0]*60}
    M400
    G92 'f0

if sensors.endstops[global.AFC_f_axis].triggered                                                                ; Filament is on the load switch (it was there already, or the search found it)
    set global.AFC_lanes[var.unit_number][var.lane_number][0] = true                                            ; Mark the lane as loaded.
    if global.AFC_lanes[var.unit_number][var.lane_number][1] != 0                                               ; A first length is recorded: move to the park position.
        G1 'f{global.AFC_lanes[var.unit_number][var.lane_number][1]} F{global.AFC_load_retract_speed[var.unit_number][0]*60}
    M400
    set global.AFC_LED_array[var.unit_number][var.lane_number] = 1                                              ; Green = loaded and ready
    M98 P"0:/sys/AFC/Macros/leds.g"
    M98 P"0:/sys/AFC/Macros/save_status.g"
else
    M118 S{"Unit "^var.unit_number^" Lane "^var.lane_number^": the filament did not reach the load switch within "^var.search_distance^"mm. Check the filament and the switch"}
M400

; --- Cleanup ---
M18 'f                                                                                                          ; Release the lane motor
M98 P"0:/sys/AFC/Macros/lane_motion_end.g" A{var.tool_number}                                                   ; Free the endstop, hide 'f, re-arm the triggers
