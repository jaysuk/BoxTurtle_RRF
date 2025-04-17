var brush_x_max = global.AFC_brush[0] + (global.AFC_brush[4]/2)
var brush_x_min = global.AFC_brush[0] - (global.AFC_brush[4]/2)
var brush_y_max = global.AFC_brush[1] + (global.AFC_brush[5]/2)
var brush_y_min = global.AFC_brush[1] - (global.AFC_brush[5]/2)
var travel_speed = global.AFC_travel_speed[0] * 60
var z_travel_speed = global.AFC_travel_speed[1] * 60
var xmin = move.axes[0].min
var xmax = move.axes[0].max
var ymin = move.axes[1].min
var ymax = move.axes[1].max

; move to the centre of the brush

M98 P"0:/sys/AFC/debug.g" A"AFC_Brush: Clean Nozzle"

M98 P"0:/sys/AFC/debug.g" A"AFC_Brush: Move to Brush."

if global.AFC_brush[8] && (global.AFC_brush[2] > move.axes[2].machinePosition)
    G1 Z{global.AFC_brush[2]} F{var.z_travel_speed}

G1 X{global.AFC_brush[0]} Y{global.AFC_brush[1]} F{var.travel_speed}

if global.AFC_brush[8] && global.AFC_brush[2] > 0
    G1 Z{global.AFC_brush[2]} F{var.z_travel_speed}

if global.AFC_brush[8] && fileexists("0:/sys/AFC/brush_deploy.g")
    M98 P"0:/sys/AFC/brush_deploy.g"
elif global.AFC_brush[8]
    M950 S10 C{global.AFC_brush[9]}
    M280 P10 S{global.AFC_brush[10]}

if global.AFC_brush[6]
    M98 P"0:/sys/AFC/debug.g" A"AFC_Brush: Y Brush Moves"
    while iterations < global.AFC_brush[7]
        G1 Y{var.brush_y_min} F{global.AFC_brush[3]*60}
        G1 Y{var.brush_y_max} F{global.AFC_brush[3]*60}
        G1 Y{global.AFC_brush[1]} F{global.AFC_brush[3]*60}

M98 P"0:/sys/AFC/debug.g" A"AFC_Brush: X Brush Moves"
while iterations < global.AFC_brush[7]
    G1 X{var.brush_x_min} F{global.AFC_brush[3]*60}
    G1 X{var.brush_x_max} F{global.AFC_brush[3]*60}
    G1 X{global.AFC_brush[0]} F{global.AFC_brush[3]*60}

M400

if global.AFC_brush[8] && fileexists("0:/sys/AFC/brush_retract.g")
    M98 P"0:/sys/AFC/brush_retract.g"
elif global.AFC_brush[8]
    M280 P{global.AFC_brush[12]} S{global.AFC_brush[11]}
    G4 P500
    M950 S{global.AFC_brush[12]} C"nil"