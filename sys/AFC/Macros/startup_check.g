; === AFC startup lane check (startup_check.g) ===
; Runs when Machine_features[6] ("start check") is on: sys/daemon.g calls it right after boot_check.g, so the lane of a tool
; that is loaded in the toolhead has already been dealt with. For every other lane:
;   1. compare the lane's load switch with AFC_lanes[u][l][0] (recorded as loaded / empty) and correct the record
;   2. a lane recorded as loaded and measured is probed once: the filament is pushed forward (bounded) until the hub
;      switch triggers, then backed off to the park position. That proves the filament really sits at the park position.
; The result is one summary box. Nothing is retracted or unloaded automatically beyond that.

var u = 0
var l = 0
var cur_u = -1                                                    ; lane that the current tool draws from (skipped)
var cur_l = -1
var present = false
var hub_busy = false
var report = ""
var problems = 0
var lane_tool = 0
var errors = global.AFC_error_count

if move.motionSystems[0].currentTool >= 0 && move.motionSystems[0].currentTool < #global.AFC_tool_map
    set var.cur_u = global.AFC_tool_map[move.motionSystems[0].currentTool][0]
    set var.cur_l = global.AFC_tool_map[move.motionSystems[0].currentTool][1]

while iterations < #global.AFC_unit_CAN_ids
    set var.u = iterations

    ; The hub must be empty before any probe
    M950 J{global.AFC_hub_input_numbers[var.u]} C{global.AFC_hub_switch[var.u]}
    G4 P100
    set var.hub_busy = sensors.gpIn[global.AFC_hub_input_numbers[var.u]].value != 0
    M950 J{global.AFC_hub_input_numbers[var.u]} C"nil"

    while iterations < global.AFC_unit_total_lanes[var.u]
        set var.l = iterations
        set var.lane_tool = global.AFC_lane_to_tool[var.u][var.l]
        if var.u == var.cur_u && var.l == var.cur_l
            continue

        ; --- 1. Load switch vs record (the hub J is borrowed to read the lane's load switch) ---
        M950 J{global.AFC_hub_input_numbers[var.u]} C{global.AFC_load_switch[var.u][var.l]}
        G4 P100
        set var.present = sensors.gpIn[global.AFC_hub_input_numbers[var.u]].value != 0
        M950 J{global.AFC_hub_input_numbers[var.u]} C"nil"

        if global.AFC_lanes[var.u][var.l][0] && !var.present
            set global.AFC_lanes[var.u][var.l][0] = false
            set global.AFC_LED_array[var.u][var.l] = 0
            set var.problems = var.problems + 1
            if #var.report < 180
                set var.report = var.report ^ "U" ^ var.u ^ "L" ^ var.l ^ ": no filament at the load switch, marked empty. "
        elif !global.AFC_lanes[var.u][var.l][0] && var.present
            set var.problems = var.problems + 1
            if #var.report < 180
                set var.report = var.report ^ "U" ^ var.u ^ "L" ^ var.l ^ ": filament present but not marked loaded (re-insert it or use Lane - Mark Loaded). "

        ; --- 2. Probe a lane that is recorded as loaded and measured ---
        elif global.AFC_lanes[var.u][var.l][0] && global.AFC_lanes[var.u][var.l][1] > 0 && !var.hub_busy
            M98 P"0:/sys/AFC/Macros/lane_motion_begin.g" A{var.lane_tool}
            M574 'f2 S1 P{global.AFC_hub_switch[var.u]}
            G92 'f{global.AFC_lanes[var.u][var.l][1]}
            G1 H4 'f{global.AFC_lanes[var.u][var.l][1] + global.AFC_hub_retract_distance[var.u] + 50} F{global.AFC_load_retract_speed[var.u][0]*60}
            M400
            if sensors.endstops[global.AFC_f_axis].triggered
                G91
                G1 'f{-global.AFC_hub_retract_distance[var.u]} F{global.AFC_load_retract_speed[var.u][1]*60}      ; back to the park position
                G90
                M400
            else
                G1 'f{global.AFC_lanes[var.u][var.l][1]} F{global.AFC_load_retract_speed[var.u][1]*60}
                M400
                set var.problems = var.problems + 1
                if #var.report < 180
                    set var.report = var.report ^ "U" ^ var.u ^ "L" ^ var.l ^ ": hub switch not reached from the park position (check the lengths). "
            M98 P"0:/sys/AFC/Macros/lane_motion_end.g" A{var.lane_tool}

M98 P"0:/sys/AFC/Macros/leds.g"
M98 P"0:/sys/AFC/Macros/save_status.g"

if var.problems == 0
    M118 S"AFC startup check: all lanes match their records"
else
    M291 P{"AFC startup check: "^var.problems^" problem(s). "^var.report} R"Startup check" S2
