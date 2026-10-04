; === tip_form.g - form a filament tip before unloading (printers without a cutter) ===
; Called by tfree.g when Machine_tip_forming is on and the cut feature is off. Uses the Machine_tip_* settings:
;   Machine_tip_ramming_volume   mm^3 pressed into the tip first (0 = no ramming)
;   Machine_tip_toolchange_temp  temperature during the tip formation (0 = unchanged)
;   Machine_tip_unloading_speed  {fast move out of the melt zone, slower move through the cooling tube} mm/s
;   Machine_tip_cooling          {start of the cooling tube (mm), length of the move (mm), first speed, fast speed (mm/s), back-and-forth moves}
;   Machine_tip_use_skinnydip / Machine_tip_skinnydip  {distance, insertion speed, extraction speed (mm/s), pause in melt zone (s), pause in cooling zone (s)}
; Sets global.AFC_tip_retracted = the net distance (mm) the filament was pulled back, so tfree retracts only the rest.
; param.A tool number (the tool whose heater is lowered)

set global.AFC_tip_retracted = 0
if !exists(param.A)
    M99

var ram_len = 0
var moves = 0

M83                                                                       ; relative extrusion

; --- 1. Ramming: press the filament into the tip before anything cools ---
if global.Machine_tip_ramming_volume > 0
    set var.ram_len = global.Machine_tip_ramming_volume / (pi * (global.Machine_filament_diameter / 2) * (global.Machine_filament_diameter / 2))
    G1 E{var.ram_len} F{global.Machine_tip_unloading_speed[0] * 60}
    G1 E{-var.ram_len} F{global.Machine_tip_unloading_speed[0] * 60}
    M400

; --- 2. Lower the temperature for the tip formation ---
if global.Machine_tip_toolchange_temp > 0
    M568 P{param.A} S{global.Machine_tip_toolchange_temp} R{global.Machine_tip_toolchange_temp}
    M116 P{param.A}

; --- 3. Pull the tip out of the melt zone: fast to the start of the cooling tube, then slower through it ---
G1 E{-global.Machine_tip_cooling[0]} F{global.Machine_tip_unloading_speed[0] * 60}
G1 E{-global.Machine_tip_cooling[1]} F{global.Machine_tip_unloading_speed[1] * 60}
M400
set global.AFC_tip_retracted = global.Machine_tip_cooling[0] + global.Machine_tip_cooling[1]

; --- 4. Cooling moves: back and forth in the cooling tube (first pass slowly, later passes fast) ---
while iterations < global.Machine_tip_cooling[4]
    set var.moves = global.Machine_tip_cooling[3]
    if iterations == 0
        set var.moves = global.Machine_tip_cooling[2]
    G1 E{global.Machine_tip_cooling[1]} F{var.moves * 60}
    G1 E{-global.Machine_tip_cooling[1]} F{var.moves * 60}
M400

; --- 5. Skinny dip: briefly re-insert to burn off hairs on stringy materials ---
if global.Machine_tip_use_skinnydip
    G1 E{global.Machine_tip_skinnydip[0]} F{global.Machine_tip_skinnydip[1] * 60}
    G4 S{global.Machine_tip_skinnydip[3]}
    G1 E{-global.Machine_tip_skinnydip[0]} F{global.Machine_tip_skinnydip[2] * 60}
    G4 S{global.Machine_tip_skinnydip[4]}
    M400
