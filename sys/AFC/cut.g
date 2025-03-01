var location_factor = {0,0}
var pin_park_x_loc = 0
var pin_park_y_loc = 0
var fast_slow_transition_loc_x = 0
var full_cut_loc_x = 0
var fast_slow_transition_loc_y = 0
var full_cut_loc_y = 0
var xmin = move.axes[0].min
var xmax = move.axes[0].max
var ymin = move.axes[1].min
var ymax = move.axes[1].max
var x_current = move.axes[0].current
var y_current = move.axes[1].current
var z_current = move.axes[2].current
var extruder_move_dist = 0
var previous_pa = move.extruders[0].pressureAdvance

M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Cut Filament"

if global.AFC_cut_direction == "left"
    set var.location_factor = {1,0}
if global.AFC_cut_direction == "right"
    set var.location_factor = {-1,0}
if global.AFC_cut_direction == "front"
    set var.location_factor = {0,1}
if global.AFC_cut_direction == "back"
    set var.location_factor = {0,-1}

if global.AFC_cut_direction == "left" || global.AFC_cut_direction == "right"
    set var.pin_park_x_loc = global.AFC_cut_location[0] + (var.location_factor[0] * global.AFC_cut_dist[0])
    set var.pin_park_y_loc = global.AFC_cut_location[1]
elif global.AFC_cut_direction == "front" || global.AFC_cut_direction == "back"
    set var.pin_park_x_loc = global.AFC_cut_location[0] 
    set var.pin_park_y_loc = global.AFC_cut_location[1] + (var.location_factor[1] * global.AFC_cut_dist[1])
else
    M118 S"Invalid cut direction. Check the cut_direction in your AFC_Vars.g file!"

M572 D0 S0 ; Temporarily disable PA

G90 ; Absolute positioning
M83 ; Relative extrusion
G92 E0

if global.AFC_cut_retract_length > 0
    M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Retract Filament for Cut"
    G1 E{-global.AFC_cut_retract_length} F{global.AFC_cut_move[5]*60}
    if global.AFC_cut_quick_tip_forming
        M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Performing Quick Tip Form"
        G1 E{global.AFC_cut_retract_length/2} F{global.AFC_cut_move[5]*60}
        G1 E{-global.AFC_cut_retract_length/2} F{global.AFC_cut_move[5]*60}
    set var.extruder_move_dist = var.extruder_move_dist + global.AFC_cut_retract_length

M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Move to Cut Pin Location"

G1 X{var.pin_park_x_loc} Y{var.pin_park_y_loc} F{global.AFC_speed[0]*60}

M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Cut Move..."

if global.AFC_cut_current_stepper[0] > 0
    M906 X{global.AFC_cut_current_stepper[0]}
if global.AFC_cut_current_stepper[1] > 0
    M906 Y{global.AFC_cut_current_stepper[1]}
if global.AFC_cut_current_stepper[2] > 0
    M906 Z{global.AFC_cut_current_stepper[2]}

while iterations < {global.AFC_cut_move[6]-1}
    if global.AFC_cut_direction == "left"
        set var.location_factor = {-1,0}
    if global.AFC_cut_direction == "right"
        set var.location_factor = {1,0}
    if global.AFC_cut_direction == "front"
        set var.location_factor = {0,-1}
    if global.AFC_cut_direction == "back"
        set var.location_factor = {0,1}
    if global.AFC_cut_direction == "left" || global.AFC_cut_direction == "right"
        set var.fast_slow_transition_loc_x = var.pin_park_x_loc + var.location_factor[0] * (global.AFC_cut_dist[1] * global.AFC_cut_move[4])
        set var.full_cut_loc_x = var.pin_park_x_loc + var.location_factor[0] * global.AFC_cut_move[4]
        if var.full_cut_loc_x > var.xmax || var.full_cut_loc_x < var.xmin
            M118 S"X Cut move is outside your printer bounds. Check the cut_move_dist in your AFC_Vars.cfg file!"
        else
            G1 X{var.fast_slow_transition_loc_x} F{global.AFC_cut_move[0]*60}
            G1 X{var.full_cut_loc_x} F{global.AFC_cut_move[1]*60}
            G4 P{global.AFC_cut_move[3]}
            G4 P200
            G1 X{var.pin_park_x_loc} F{global.AFC_cut_move[2]*60}
    elif global.AFC_cut_direction == "front" || global.AFC_cut_direction == "back"
        set var.fast_slow_transition_loc_y = var.pin_park_y_loc + var.location_factor[1] * (global.AFC_cut_dist[1] * global.AFC_cut_move[4])
        set var.full_cut_loc_y = var.pin_park_y_loc + var.location_factor[1] * global.AFC_cut_move[4]
        if var.full_cut_loc_y > var.ymax || var.full_cut_loc_y < var.ymin
            M118 S"X Cut move is outside your printer bounds. Check the cut_move_dist in your AFC_Vars.cfg file!"
        else
            G1 Y{var.fast_slow_transition_loc_y} F{global.AFC_cut_move[0]*60}
            G1 Y{var.full_cut_loc_y} F{global.AFC_cut_move[1]*60}
            G4 P{global.AFC_cut_move[3]}
            G4 P200
            G1 Y{var.pin_park_y_loc} F{global.AFC_cut_move[2]*60}
    else
        M118 S"Invalid cut direction. Check the cut_direction in your AFC_Vars.g file!"

M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Final Move..."

if global.AFC_cut_direction == "left"
    set var.location_factor = {-1,0}
if global.AFC_cut_direction == "right"
    set var.location_factor = {1,0}
if global.AFC_cut_direction == "front"
    set var.location_factor = {0,-1}
if global.AFC_cut_direction == "back"
    set var.location_factor = {0,1}
if global.AFC_cut_direction == "left" || global.AFC_cut_direction == "right"
    set var.fast_slow_transition_loc_x = var.pin_park_x_loc + var.location_factor[0] * (global.AFC_cut_dist[1] * global.AFC_cut_move[4])
    set var.full_cut_loc_x = var.pin_park_x_loc + var.location_factor[0] * global.AFC_cut_move[4]
    if var.full_cut_loc_x > var.xmax || var.full_cut_loc_x < var.xmin
        M118 S"X Cut move is outside your printer bounds. Check the cut_move_dist in your AFC_Vars.cfg file!"
    else
        G1 X{var.fast_slow_transition_loc_x} F{global.AFC_cut_move[0]*60}
        G1 X{var.full_cut_loc_x} F{global.AFC_cut_move[1]*60}
        G4 P{global.AFC_cut_move[3]}
        if global.AFC_cut_rip[0] > 0
            G1 E{-global.AFC_cut_rip[0]} F{global.AFC_cut_rip[1] * 60}
        G4 P200
        G1 X{var.pin_park_x_loc} F{global.AFC_cut_move[2]*60}
elif global.AFC_cut_direction == "front" || global.AFC_cut_direction == "back"
    set var.fast_slow_transition_loc_y = var.pin_park_y_loc + var.location_factor[1] * (global.AFC_cut_dist[1] * global.AFC_cut_move[4])
    set var.full_cut_loc_y = var.pin_park_y_loc + var.location_factor[1] * global.AFC_cut_move[4]
    if var.full_cut_loc_y > var.ymax || var.full_cut_loc_y < var.ymin
        M118 S"X Cut move is outside your printer bounds. Check the cut_move_dist in your AFC_Vars.cfg file!"
    else
        G1 Y{var.fast_slow_transition_loc_y} F{global.AFC_cut_move[0]*60}
        G1 Y{var.full_cut_loc_y} F{global.AFC_cut_move[1]*60}
        G4 P{global.AFC_cut_move[3]}
        if global.AFC_cut_rip[0] > 0
            G1 E{-global.AFC_cut_rip[0]} F{global.AFC_cut_rip[1] * 60}
        G4 P200
        G1 Y{var.pin_park_y_loc} F{global.AFC_cut_move[2]*60}
else
    M118 S"Invalid cut direction. Check the cut_direction in your AFC_Vars.g file!"

if global.AFC_cut_current_stepper[0] > 0
    M906 X{var.x_current}
if global.AFC_cut_current_stepper[1] > 0
    M906 Y{var.y_current}
if global.AFC_cut_current_stepper[2] > 0
    M906 Z{var.z_current}

set var.extruder_move_dist = var.extruder_move_dist + global.AFC_cut_rip[0]

; Optionally pushback of the cut piece into the hotend to avoid potential clog
if global.AFC_cut_pushback[0] > 0
    M98 P"0:/sys/AFC/debug.g" A"AFC_Cut: Push cut tip back into hotend"
    G1 E{global.AFC_cut_pushback[0]} F{global.AFC_cut_move[5]*60}
    G4 P{global.AFC_cut_pushback[1]}
    G1 E{-global.AFC_cut_pushback[0]} F{global.AFC_cut_move[5]*60}
    set var.extruder_move_dist = var.extruder_move_dist + global.AFC_cut_pushback[0]

M572 D0 S{var.previous_pa}