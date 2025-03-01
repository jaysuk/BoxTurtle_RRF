var xmin = move.axes[0].min
var xmax = move.axes[0].max
var ymin = move.axes[1].min
var ymax = move.axes[1].max

M98 P"0:/sys/AFC/debug.g" A"AFC_Kick: Starting Filament Kick"

M98 P"0:/sys/AFC/debug.g" A"AFC_Kick: Move to Start Position"

G1 Z{global.AFC_kick[2]} F{global.AFC_speed[1]*60}
G1 X{global.AFC_kick[0]} Y{global.AFC_kick[1]} F{global.AFC_speed[0]*60}

M98 P"0:/sys/AFC/debug.g" A"AFC_Kick: Drop Z For Kick Move"

if global.AFC_kick[2] > 0
    G1 Z{global.AFC_kick[2]} F{global.AFC_speed[1]*60}
else
    M118 S"AFC-KICK: kick_z value to low. Please adjust in AFC_Vars.g. Defaulting to 0.5mm z-height"
    G1 Z0.5 F{global.AFC_speed[1]*60}

if global.AFC_kick[6] == "left"
    set var.location_factor = {-1,0}
if global.AFC_kick[6] == "right"
    set var.location_factor = {1,0}
if global.AFC_kick[6] == "front"
    set var.location_factor = {0,-1}
if global.AFC_kick[6] == "back"
    set var.location_factor = {0,1}

M98 P"0:/sys/AFC/debug.g" A"AFC_Kick: Kick filament"

if global.AFC_kick[6] == "left" || global.AFC_kick[6] == "right"
    if (global.AFC_kick[0] + var.location_factor[0] * global.AFC_kick[7] > var.xmax ) || (global.AFC_kick[0] + var.location_factor[0] * global.AFC_kick[7] < var.xmin )
        M118 S"X Kick move is outside your printer bounds. Check the kick_move_dist in your AFC_Vars.g file!"
    else
        G1 X{global.AFC_kick[0] + var.location_factor[0] * global.AFC_kick[7]} F{global.AFC_kick[4] * 60}
elif global.AFC_kick[6] == "front" || global.AFC_kick[6] == "back"
    if (global.AFC_kick[1] + var.location_factor[1] * global.AFC_kick[7] > var.ymax ) || (global.AFC_kick[1] + var.location_factor[1] * global.AFC_kick[7] < var.xmin )
        M118 S"Y Kick move is outside your printer bounds. Check the kick_move_dist in your AFC_Vars.g file!"
    else
        G1 Y{global.AFC_kick[1] + var.location_factor[1] * global.AFC_kick[7]} F{global.AFC_kick[4] * 60}
else
    M118 S"Error in kick movement. Check the directions in your AFC_Vars.g file!"

G1 Z{global.AFC_kick[8]} F{global.AFC_speed[1]*60}