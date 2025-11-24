; === AFC Filament Kick Macro (RepRapFirmware G-Code) ===
; Purpose: Executes a fast, short movement of the toolhead (X or Y) to dislodge cut filament.

; --- State Capture ---
var xmin = move.axes[0].min                                                                                   ; Capture X axis minimum limit for boundary checking.
var xmax = move.axes[0].max                                                                                   ; Capture X axis maximum limit for boundary checking.
var ymin = move.axes[1].min                                                                                   ; Capture Y axis minimum limit for boundary checking.
var ymax = move.axes[1].max                                                                                   ; Capture Y axis maximum limit for boundary checking.
var location_factor = {0,0}                                                                                   ; Placeholder variable for the direction vector array.
var travel_speed_xy = global.AFC_travel_speed[0] * 60
var travel_speed_z = global.AFC_travel_speed[1] * 60
var kick_speed = global.AFC_kick[4] * 60

; --- AFC_kick Array Index Reference (Assumed) ---
; [0]: Kick Start X position
; [1]: Kick Start Y position
; [2]: Kick Z position (Safety Z height)
; [3]: (Unused or implicitly used)
; [4]: Kick Speed (mm/s)
; [6]: Kick Direction ("left", "right", "front", "back")
; [7]: Kick Distance (mm)
; [8]: Kick Z Return Height

M98 P"0:/sys/AFC/debug.g" A"AFC_Kick: Starting Filament Kick"                                                 ; Log the start of the kick routine.
M98 P"0:/sys/AFC/debug.g" A"AFC_Kick: Move to Start Position"                                                 ; Log move to starting coordinates.

; --- Move to Start Position ---
G1 Z{global.AFC_kick[2]} F{var.travel_speed_z}                                                                ; Move Z to the configured safety height (index [2]). Speed is in mm/min.
G1 X{global.AFC_kick[0]} Y{global.AFC_kick[1]} F{var.travel_speed_xy}                                         ; Move X/Y to the kick start coordinates (index [0] & [1]). Speed is in mm/min.

M98 P"0:/sys/AFC/debug.g" A"AFC_Kick: Drop Z For Kick Move"                                                   ; Log Z drop.

; --- Safety Check and Z Drop ---
if global.AFC_kick[2] > 0                                                                                     ; If the configured Z height is valid (> 0).
    G1 Z{global.AFC_kick[2]} F{var.travel_speed_z}                                                            ; Move Z down to the designated kick Z height (redundant if Z was moved above).
else                                                                                                          ; If the configured Z height is invalid/too low.
    M118 S"AFC-KICK: kick_z value to low. Please adjust in AFC_Vars.g. Defaulting to 0.5mm z-height"          ; Send error message.
    G1 Z0.5 F{var.travel_speed_z}                                                                             ; Default to a safe Z height of 0.5mm.

; --- Determine Kick Direction Vector ---
if global.AFC_kick[6] == "left"
    set var.location_factor = {-1,0}                                                                          ; Vector for X- movement (left).
if global.AFC_kick[6] == "right"
    set var.location_factor = {1,0}                                                                           ; Vector for X+ movement (right).
if global.AFC_kick[6] == "front"
    set var.location_factor = {0,-1}                                                                          ; Vector for Y- movement (front).
if global.AFC_kick[6] == "back"
    set var.location_factor = {0,1}                                                                           ; Vector for Y+ movement (back).

M98 P"0:/sys/AFC/debug.g" A"AFC_Kick: Kick filament"                                                          ; Log kick execution.

; --- Execute Kick Move (X-Axis) ---
if global.AFC_kick[6] == "left" || global.AFC_kick[6] == "right"                                              ; Check for X-axis direction.
                                                                                                              ; Safety Check: Calculate final X position and verify against X machine limits (xmin/xmax).
    if (global.AFC_kick[0] + var.location_factor[0] * global.AFC_kick[7] > var.xmax ) || (global.AFC_kick[0] + var.location_factor[0] * global.AFC_kick[7] < var.xmin )
        M118 S"X Kick move is outside your printer bounds. Check the kick_move_dist in your AFC_Vars.g file!" ; Send error message.
    else
                                                                                                              ; G1 X{Start X + Direction * Distance} F{Kick Speed}
    G1 X{global.AFC_kick[0] + var.location_factor[0] * global.AFC_kick[7]} F{var.kick_speed}                  ; Perform fast X move to knock filament.

; --- Execute Kick Move (Y-Axis) ---
elif global.AFC_kick[6] == "front" || global.AFC_kick[6] == "back"                                            ; Check for Y-axis direction.
                                                                                                              ; Safety Check: Calculate final Y position and verify against Y machine limits (ymin/ymax).
    if (global.AFC_kick[1] + var.location_factor[1] * global.AFC_kick[7] > var.ymax ) || (global.AFC_kick[1] + var.location_factor[1] * global.AFC_kick[7] < var.ymin )
        M118 S"Y Kick move is outside your printer bounds. Check the kick_move_dist in your AFC_Vars.g file!" ; Send error message (Note: Check correctly uses ymin/ymax but still references "kick_move_dist").
    else
                                                                                                              ; G1 Y{Start Y + Direction * Distance} F{Kick Speed}
        G1 Y{global.AFC_kick[1] + var.location_factor[1] * global.AFC_kick[7]} F{var.kick_speed}              ; Perform fast Y move to knock filament.
else
    M118 S"Error in kick movement. Check the directions in your AFC_Vars.g file!"                             ; Fallback error if direction is unknown.

; --- Move Z to Final Safe Height ---
G1 Z{global.AFC_kick[8]} F{var.travel_speed_z}                                                                ; Move Z axis to the configured final return height (index [8]).