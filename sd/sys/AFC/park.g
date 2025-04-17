var max_z = move.axes[2].max
var cur_z = move.axes[2].machinePosition
var z_safe = 0

if global.AFC_park[2] > move.axes[2].machinePosition
    set var.z_safe = global.AFC_park[2]
else
    set var.z_safe = move.axes[2].machinePosition

M98 P"0:/sys/AFC/debug.g" A"AFC_Park: Park Toolhead"

if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed
    G28

G1 Z{var.z_safe} F{global.AFC_travel_speed[1] * 60}
G1 X{global.AFC_park[0]} Y{global.AFC_park[1]} F{global.AFC_travel_speed[0] * 60}