; === validate_job.g - check that the lanes a job needs are ready (called by start_print.g) ===
; The tools a job uses come from the slicer's filament usage in the file header (job.file.filament, mm per extruder), or from
; the optional param.L: one character per tool, "1" = used (e.g. L"1011"). For every used tool its lane (through the tool map)
; must be loaded and measured, and - with spool tracking - the assigned spool must hold more filament than the job needs.
; Problems are listed in ONE box with a Cancel button; Cancel sets Machine_cancelled (start_print.g then stops the print).

var problems = 0
var report = ""
var t = 0
var u = 0
var l = 0
var used = false
var need = 0
var n = #global.AFC_tool_map

while iterations < var.n
    set var.t = iterations
    set var.used = false
    set var.need = 0
    if exists(param.L)
        set var.used = #param.L > var.t && take(drop(param.L, var.t), 1) == "1"
    if exists(job.file.filament[var.t])
        set var.need = job.file.filament[var.t]
        if var.need > 0
            set var.used = true
    if !var.used
        continue

    set var.u = global.AFC_tool_map[var.t][0]
    set var.l = global.AFC_tool_map[var.t][1]
    if !global.AFC_lanes[var.u][var.l][0]
        set var.problems = var.problems + 1
        if #var.report < 170
            set var.report = var.report ^ "T" ^ var.t ^ " (U" ^ var.u ^ "L" ^ var.l ^ ") is empty. "
    elif global.AFC_lanes[var.u][var.l][1] <= 0 || global.AFC_lanes[var.u][var.l][2] <= global.AFC_lanes[var.u][var.l][1]
        set var.problems = var.problems + 1
        if #var.report < 170
            set var.report = var.report ^ "T" ^ var.t ^ " (U" ^ var.u ^ "L" ^ var.l ^ ") is not measured. "
    elif global.Machine_features[7] == 1 && global.spool_active_data[var.u][var.l][0] != -1 && var.need > 0
        if global.spool_active_data[var.u][var.l][5] < var.need
            set var.problems = var.problems + 1
            if #var.report < 170
                set var.report = var.report ^ "T" ^ var.t ^ " (U" ^ var.u ^ "L" ^ var.l ^ ") has " ^ floor(global.spool_active_data[var.u][var.l][5] / 1000) ^ "m left, needs " ^ ceil(var.need / 1000) ^ "m. "

if var.problems > 0
    M291 P{"Job check: " ^ var.report ^ "Print anyway?"} R"AFC job check" S3 J2
    if result == -1
        set global.Machine_cancelled = true
