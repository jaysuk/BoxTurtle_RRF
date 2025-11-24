; === AFC Toolhead Park Macro (RepRapFirmware G-Code) ===
; Purpose: Safely moves the toolhead to a specified park position (X/Y) at a calculated safe Z height.

; --- State Capture and Variable Initialization ---
var max_z = move.axes[2].max                                          ; Capture Z axis maximum machine limit. (Not used below, but useful for context/debugging)
var cur_z = move.axes[2].machinePosition                              ; Capture current Z position.
var z_safe = 0                                                        ; Initialize safe Z height variable.
var travel_speed_xy = global.AFC_travel_speed[0] * 60
var travel_speed_z = global.AFC_travel_speed[1] * 60

; --- Calculate Safe Z Height ---
; This logic finds the highest of two values: the configured park Z height or the current Z height.
set var.z_safe = max(global.AFC_park[2], move.axes[2].machinePosition)

M98 P"0:/sys/AFC/debug.g" A"AFC_Park: Park Toolhead"                  ; Log the start of the park routine.

; --- Homing Safety Check ---
; Ensures the coordinate system is valid before attempting absolute moves.
if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed  ; Check if X (axis 0), Y (axis 1), or Z (axis 2) are not homed.
    G28                                                               ; If any axis is unhomed, perform a full homing routine.
    M400

; --- Execute Park Sequence (Moves to Absolute Position) ---
; Moves Z first for vertical safety, then moves X/Y horizontally.
G1 Z{var.z_safe} F{var.travel_speed_z}                                ; Move Z to the calculated safe height (mm/min speed).
G1 X{global.AFC_park[0]} Y{global.AFC_park[1]} F{var.travel_speed_xy} ; Move X/Y to the configured park coordinates (mm/min speed).