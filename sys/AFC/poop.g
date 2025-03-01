var max_iteration_length = 40
var iteration_z_raise = 6
var iteration_z_change = 0.6
var max_iterations_per_blob = 3
var pressure_release_time = 1000
var purge_z = 0
var purge_amount_length = 0
var purge_len = 0
var backup_feedrate = 0
var extrude_amount = 0
var extrude_ratio = 0
var step_triangular = 0
var z_raise_substract = 0
var raise_z = 0
var duration = 0
var speed = 0
var max_iterations_reached = false
var purge_length_reached = false
var backup_fan_speed = 0

M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Starting poop"

if global.AFC_part_cooling_fan[0]
    M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Set Cooling Fan to Full Speed"
    set var.backup_fan_speed = fans[0].requestedValue
    M106 S{global.AFC_part_cooling_fan[1] * 255}

set var.backup_feedrate = move.speedFactor
M220 S100

set var.purge_len = global.AFC_purge_length[0]

; Apply purge minimum
set var.purge_len = max(var.purge_len,global.AFC_purge_length[1])

M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Move To Purge Location"

G1 X{global.AFC_purge_location[0]} Y{global.AFC_purge_location[1]} F{global.AFC_speed[0] * 60}
G1 Z{var.purge_z+global.AFC_purge_start} F{global.AFC_speed[1] * 60}

var max_iterations = ceil(var.purge_len / var.max_iteration_length)

; Repeat the process until purge_len is reached

while iterations < var.max_iterations
    M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Purge Iteration "^iterations
    if iterations == 0
        G1 Z{var.purge_z+global.AFC_purge_start} F{global.AFC_speed[1] * 60}
    set var.purge_amount_length = var.purge_len - (var.max_iteration_length * iterations)
    set var.extrude_amount = min(var.purge_amount_length,var.max_iteration_length)
    set var.extrude_ratio = var.extrude_amount / var.max_iteration_length

    G91
    M83

    set var.step_triangular = iterations * (iterations + 1) / 2
    if iterations == 0
        set var.z_raise_substract = global.AFC_purge_start
    else 
        set var.z_raise_substract = var.step_triangular * var.iteration_z_change
    set var.raise_z = ((var.iteration_z_change - var.z_raise_substract) * var.extrude_ratio)
    set var.raise_z = max(var.raise_z,0)

    set var.duration = var.extrude_amount / global.AFC_purge_speed
    set var.speed = var.raise_z / var.duration

    G1 Z{var.raise_z} E{var.extrude_amount} F{var.speed}

    if iterations == var.max_iterations_per_blob - 1
        set var.max_iterations_reached = true
    
    if (var.purge_len - var.max_iteration_length * (iterations - 1)) <= 0
        set var.purge_length_reached = true
    
    if var.max_iterations_reached || var.purge_length_reached
        M83
        G4 S{global.AFC_part_cooling_fan[2]}

M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Fast Z Lift to keep poop from sticking"

G1 Z{global.AFC_purge_fast_z[1]} F{global.AFC_purge_fast_z[1] * 60}

M98 P"0:/sys/AFC/debug.g" A"AFC_Poop: Restore fan speed and feedrate"

if global.AFC_part_cooling_fan[0]
    M106 S{var.backup_fan_speed * 255}

M220 S{var.backup_feedrate}