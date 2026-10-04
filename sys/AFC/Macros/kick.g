; === AFC Filament Kick Macro (RepRapFirmware G-Code) ===
; Purpose: Executes a fast, short movement of the toolhead (X or Y) to dislodge cut filament.
; The configuration is validated before anything moves; a problem calls afc_error.g (pause + message), never abort.

; --- Machine_kick Array Index Reference ---
; [0]: Kick start X   [1]: Kick start Y
; [2]: Approach Z (safe height used for the travel to the start position)
; [3]: Kick Z (height of the nozzle during the sweep)
; [4]: Kick speed (mm/s)
; [5]: Kick acceleration (mm/s^2, 0 = leave the machine acceleration alone)
; [6]: Kick direction ("left", "right", "front", "back")
; [7]: Kick distance (mm)
; [8]: Z height after the kick

; --- Validate the configuration (before any state is changed) ---
var axis = 0                                                                                                      ; 0 = kick along X, 1 = kick along Y
var sign = 1                                                                                                      ; +1 = towards the axis maximum, -1 = towards the minimum
if global.Machine_kick[6] == "left"
    set var.axis = 0
    set var.sign = -1
elif global.Machine_kick[6] == "right"
    set var.axis = 0
    set var.sign = 1
elif global.Machine_kick[6] == "front"
    set var.axis = 1
    set var.sign = -1
elif global.Machine_kick[6] == "back"
    set var.axis = 1
    set var.sign = 1
else
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"Invalid kick direction. Check Machine_kick[6] in your Machine_user_vars.g file" Q1 F1
    M99

var axis_idx = global.Machine_axis_number[var.axis]
var start_pos = global.Machine_kick[var.axis]
var end_pos = var.start_pos + var.sign * global.Machine_kick[7]
var axis_name = "X"
if var.axis == 1
    set var.axis_name = "Y"
var out_of_bounds = global.Machine_kick[0] < move.axes[global.Machine_axis_number[0]].min || global.Machine_kick[0] > move.axes[global.Machine_axis_number[0]].max
set var.out_of_bounds = var.out_of_bounds || global.Machine_kick[1] < move.axes[global.Machine_axis_number[1]].min || global.Machine_kick[1] > move.axes[global.Machine_axis_number[1]].max
set var.out_of_bounds = var.out_of_bounds || var.end_pos < move.axes[var.axis_idx].min || var.end_pos > move.axes[var.axis_idx].max
if var.out_of_bounds
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"The "^var.axis_name^" kick move is outside your printer bounds. Check Machine_kick in your Machine_user_vars.g file"} Q1 F1
    M99

var travel_speed_xy = global.Machine_travel_speed[0] * 60
var travel_speed_z = global.Machine_travel_speed[1] * 60
var kick_speed = global.Machine_kick[4] * 60
var kick_z = global.Machine_kick[3]
var print_accel = move.motionSystems[0].printingAcceleration                                                                       ; Captured so the kick acceleration can be undone
var travel_accel = move.motionSystems[0].travelAcceleration

if var.kick_z <= 0                                                                                                ; If the configured kick height is invalid/too low.
    M118 S"AFC-KICK: Machine_kick[3] (kick Z) is too low. Defaulting to 0.5mm z-height"
    set var.kick_z = 0.5

M98 P"0:/sys/AFC/Macros/debug.g" A"AFC_Kick: Starting Filament Kick"                                              ; Log the start of the kick routine.

; --- Move to Start Position ---
G90
G1 Z{global.Machine_kick[2]} F{var.travel_speed_z}                                                                ; Approach height (index [2]).
G1 X{global.Machine_kick[0]} Y{global.Machine_kick[1]} F{var.travel_speed_xy}                                     ; Kick start coordinates (index [0] & [1]).

M98 P"0:/sys/AFC/Macros/debug.g" A"AFC_Kick: Drop Z For Kick Move"                                                ; Log Z drop.
G1 Z{var.kick_z} F{var.travel_speed_z}                                                                            ; Drop to the kick height (index [3]).

; --- Execute Kick Move ---
M98 P"0:/sys/AFC/Macros/debug.g" A"AFC_Kick: Kick filament"                                                       ; Log kick execution.
if global.Machine_kick[5] > 0
    M204 P{global.Machine_kick[5]} T{global.Machine_kick[5]}                                                      ; Kick acceleration for this move only.
if var.axis == 0
    G1 X{var.end_pos} F{var.kick_speed}                                                                           ; Perform fast X move to knock filament.
else
    G1 Y{var.end_pos} F{var.kick_speed}                                                                           ; Perform fast Y move to knock filament.
M400
if global.Machine_kick[5] > 0
    M204 P{var.print_accel} T{var.travel_accel}                                                                   ; Restore the machine acceleration.

G1 Z{global.Machine_kick[8]} F{var.travel_speed_z}                                                                ; Raise to the post-kick height (index [8]).
