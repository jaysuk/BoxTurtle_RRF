var z_travel_speed = global.AFC_travel_speed[1] * 60

if global.AFC_brush[8] && global.AFC_brush[2] > 0
    G1 Z{global.AFC_brush[2]} F{var.z_travel_speed}

M400

if global.AFC_brush[8]
    M950 S10 C{global.AFC_brush[9]}
    M280 P10 S{global.AFC_brush[10]}

G1 E{global.main_extruder_measurements[2]} F{global.AFC_load_retract_speed[2]*60}
