; === AFC configuration check (config_check.g) ===
; Called at the end of AFC.g. Looks for settings that would fail in the middle of a tool change and reports each one with
; M118 ("AFC config: ..."), then shows ONE summary box. It never aborts boot and never blocks (a blocking M291 in config.g
; would stall the boot until someone answers it).

var problems = 0
var u = 0
var l = 0
var f = 0
var ok = false
var x_idx = global.Machine_axis_number[0]
var y_idx = global.Machine_axis_number[1]

; --- 1. Feature positions: must be set (not -1) and inside the axis limits (RRF 3.7 rejects out-of-limit moves) ---
; Machine_features index -> position of that feature: 0 brush, 1 cut, 2 kick, 3 park, 4 poop (Machine_purge_location)
var names = ["brush", "cut", "kick", "park", "poop"]
var xs = [global.Machine_brush[0], global.Machine_cut_location[0], global.Machine_kick[0], global.Machine_park[0], global.Machine_purge_location[0]]
var ys = [global.Machine_brush[1], global.Machine_cut_location[1], global.Machine_kick[1], global.Machine_park[1], global.Machine_purge_location[1]]
while iterations < 5
    set var.f = iterations
    if global.Machine_features[var.f]
        if var.xs[var.f] == -1 || var.ys[var.f] == -1
            M118 S{"AFC config: the "^var.names[var.f]^" feature is enabled but its position is still -1"}
            set var.problems = var.problems + 1
        elif var.xs[var.f] < move.axes[var.x_idx].min || var.xs[var.f] > move.axes[var.x_idx].max || var.ys[var.f] < move.axes[var.y_idx].min || var.ys[var.f] > move.axes[var.y_idx].max
            M118 S{"AFC config: the "^var.names[var.f]^" position is outside the X/Y limits"}
            set var.problems = var.problems + 1

; --- 1b. The DC motor outputs (M950 P) must still be free (one that is bound at boot belongs to config.g, B35) ---
while iterations < 3
    set var.f = iterations
    if exists(state.gpOut[global.AFC_dcm_out_no[var.f]]) && state.gpOut[global.AFC_dcm_out_no[var.f]] != null
        M118 S{"AFC config: output P"^global.AFC_dcm_out_no[var.f]^" is already defined in config.g - the DC motor code would take it over. Set AFC_dcm_out_no to free numbers"}
        set var.problems = var.problems + 1

; --- 2. Switches needed by the chosen methods ---
if global.Machine_features[8] == 1 && global.Machine_extruder_switches[0] == "nil"
    M118 S"AFC config: initial unload 1 needs Machine_extruder_switches[0]"
    set var.problems = var.problems + 1

while iterations < #global.AFC_unit_CAN_ids
    set var.u = iterations

    if global.AFC_features[var.u][2] == 2 && global.Machine_extruder_switches[0] == "nil"
        M118 S{"AFC config: unit "^var.u^" uses load method 2 but Machine_extruder_switches[0] is not set"}
        set var.problems = var.problems + 1

    ; --- 3. The first hub load move must be longer than the hub retract distance ---
    if global.AFC_hub_load_distance[var.u][0] <= global.AFC_hub_retract_distance[var.u]
        M118 S{"AFC config: unit "^var.u^" AFC_hub_load_distance[0] must be larger than AFC_hub_retract_distance"}
        set var.problems = var.problems + 1

    ; --- 4. Lengths of lanes that are marked as loaded ---
    while iterations < global.AFC_unit_total_lanes[var.u]
        set var.l = iterations
        if global.AFC_lanes[var.u][var.l][0] && (global.AFC_lanes[var.u][var.l][1] <= 0 || global.AFC_lanes[var.u][var.l][2] <= global.AFC_lanes[var.u][var.l][1])
            M118 S{"AFC config: unit "^var.u^" lane "^var.l^" is loaded but not measured (run Lane - Measure First and Measure Main Length)"}
            set var.problems = var.problems + 1

        ; --- 6. Driver ids must carry the +0.0001 float offset. An integer (e.g. 119) in an array is read as a
        ;        main-board driver, so a user override written as {0,1,2,3} would drive the wrong board ---
        set var.ok = abs(global.AFC_steppers[var.u][var.l][0] - floor(global.AFC_steppers[var.u][var.l][0] * 10) / 10 - 0.0001) < 0.00005
        if !var.ok
            M118 S{"AFC config: unit "^var.u^" lane "^var.l^" driver id has no 0.0001 offset - write lane offsets as 0.0, 0.1, 0.2 ... and keep the +0.0001"}
            set var.problems = var.problems + 1

    ; --- 5. The unit's CAN board must be present (expansion boards may still be starting up; this is a warning only) ---
    set var.ok = false
    while iterations < #boards
        if boards[iterations].canAddress == global.AFC_unit_CAN_ids[var.u]
            set var.ok = true
    if !var.ok
        M118 S{"AFC config: unit "^var.u^" CAN address "^global.AFC_unit_CAN_ids[var.u]^" is not in boards[] (is the board powered and is G4 S2 before AFC.g in config.g?)"}
        set var.problems = var.problems + 1

    ; --- 7. Multi-tool: the printer tool a unit feeds must exist; other motion systems need a board that supports them ---
    if global.tool_and_motion[var.u][0] >= #global.Machine_actual_tools
        M118 S{"AFC config: unit "^var.u^" feeds printer tool "^global.tool_and_motion[var.u][0]^" which does not exist"}
        set var.problems = var.problems + 1
    if global.tool_and_motion[var.u][1] != 0
        M118 S{"AFC config: unit "^var.u^" asks for motion system "^global.tool_and_motion[var.u][1]^" - only motion system 0 is supported yet, it is treated as 0"}
        set var.problems = var.problems + 1
        if boards[0].shortName != "MB6HC" && boards[0].shortName != "MB6XD"
            M118 S{"AFC config: and "^boards[0].shortName^" does not support more than one motion system in RRF 3.7"}

if var.problems > 0
    M291 P{"AFC found "^var.problems^" configuration problem(s). The details are in the console / event log (lines starting with AFC config)."} R"AFC configuration" S1 T0
