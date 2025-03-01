var max_z = move.axes[2].max
var cur_z = move.axes[2].machinePosition

var z_safe = var.cur_z + global.AFC_park[2]

if var.z_safe > var.max_z
    set var.z_safe = var.max_z

M98 P"0:/sys/AFC/debug.g" A"AFC_Park: Park Toolhead"

G1 Z{var.z_safe} F{global.AFC_speed[1] * 60}
G1 X{global.AFC_park[0]} Y{global.AFC_park[1]} F{global.AFC_speed[0] * 60}