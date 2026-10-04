; === Filament runout / error recovery (filament-error.g) ===
; Run by the generated 0:/sys/filament-error.g (Create System Files -> Filament Errors) when the filament monitor of the
; AFC extruder fires: the lane's LOAD switch opened during a print, i.e. the filament ran out.
; RRF does NOT pause when 0:/sys/filament-error.g exists, so this macro pauses first. It runs on an asynchronous channel,
; so a failed step here never cancels the print. M291 menus use J2 and test `result` (R2 triggers do not fire while a job is
; paused, so reloading is detected by reading the lane's prep switch directly).
;
; Flow: M25 -> wait for the pause -> T-1 (tfree pulls the tail back) -> mark the lane empty ->
;   infinite spool: the lane's backup (AFC_lane_backup) takes over this tool (tool map swap), T<n>, M24
;   otherwise a menu: reload this lane / use another lane / leave it paused.
; Needs a resume.g that returns the head to the pause position (the unload moves the head).
;
; param.D extruder number, param.B board (from RRF; only D is used). RRF also passes P (status) and S (text) to the event file;
; P cannot be forwarded through M98 (it is the macro file name)

var tool = move.motionSystems[0].currentTool
var unit_number = 0
var lane_number = 0
var lane_tool = 0
var errors = 0
var choice = 2
var tries = 0
var u = 0
var l = 0
var backup = -1
var done = false

; --- Only act on a running print and on an AFC extruder ---
if job.file.fileName == null
    M118 S"AFC: filament error reported while no print is running - ignored"
    M99
if var.tool < 0 || var.tool >= #global.AFC_tool_map
    M25                                                                       ; RRF would have paused; keep that for tools we don't manage
    M99
if !exists(param.D) || param.D != tools[var.tool].extruders[#tools[var.tool].extruders - 1]
    M25
    M99

set var.unit_number = global.AFC_tool_map[var.tool][0]
set var.lane_number = global.AFC_tool_map[var.tool][1]
set var.lane_tool = global.AFC_lane_to_tool[var.unit_number][var.lane_number]

; --- Pause (from this channel RRF turns it into a deferred M226 if a macro is running) and wait for it ---
M25
while iterations < 120 && state.status != "paused"
    G4 S1
if state.status != "paused"
    M118 S"AFC: the print did not pause - the runout was not handled"
    M99
M118 S{"AFC: tool "^var.tool^" (Unit "^var.unit_number^" Lane "^var.lane_number^") ran out of filament"}

; --- Unload the tail with a normal T-1 (cut, park, retract to the lane's park position) ---
set var.errors = global.AFC_error_count
T-1
if global.AFC_error_count != var.errors
    M118 S"AFC: unloading after the runout failed - the print stays paused"
    M99

; --- The lane is empty now (its tail was pulled back to the park position and has to be removed by hand) ---
set global.AFC_lanes[var.unit_number][var.lane_number][0] = false
set global.AFC_LED_array[var.unit_number][var.lane_number] = 0
M98 P"0:/macros/Spool - Unassign" A{var.unit_number} B{var.lane_number}       ; silent: writes the last length, clears the lane's spool
M98 P"0:/sys/AFC/Macros/leds.g"
M98 P"0:/sys/AFC/Macros/save_status.g"

; --- Infinite spool: the backup lane takes over this tool ---
set var.backup = global.AFC_lane_backup[var.unit_number][var.lane_number]
if var.backup >= 0 && var.backup < #global.Tool_to_AFC
    set var.u = global.Tool_to_AFC[var.backup][0]
    set var.l = global.Tool_to_AFC[var.backup][1]
    if global.AFC_lanes[var.u][var.l][0]
        set var.errors = global.AFC_error_count
        M98 P"0:/sys/AFC/Macros/tool_map_swap.g" A{var.tool} B{var.backup}
        if global.AFC_error_count == var.errors
            M118 S{"AFC: Unit "^var.u^" Lane "^var.l^" takes over tool "^var.tool}
            set var.done = true
    else
        M118 S{"AFC: the backup lane (Unit "^var.u^" Lane "^var.l^") is empty"}

; --- No (usable) backup: ask ---
while !var.done
    M291 P{"Tool "^var.tool^" (Unit "^var.unit_number^" Lane "^var.lane_number^") ran out of filament. The print is paused."} R"Filament runout" K{"Reload this lane", "Use another lane", "Leave it paused"} S4 J2
    if result == -1
        M99
    set var.choice = input
    if var.choice == 2
        M99

    if var.choice == 0                                                        ; Reload this lane
        set var.tries = 0
        while var.tries < 3 && !global.AFC_lanes[var.unit_number][var.lane_number][0]
            M291 P{"Remove the old tail from Unit "^var.unit_number^" Lane "^var.lane_number^", insert the new filament and press OK"} R"Reload lane" S2
            if sensors.gpIn[global.AFC_trigger_input_numbers[var.unit_number][var.lane_number]].value == 1   ; prep switch sees filament
                M98 P"0:/sys/AFC/Macros/triggers.g" A{var.lane_tool}          ; feeds it to the load switch, parks it, marks the lane loaded
            else
                M118 S"AFC: no filament detected at the lane's prep switch"
            set var.tries = var.tries + 1
        if global.AFC_lanes[var.unit_number][var.lane_number][0]
            set var.done = true

    elif var.choice == 1                                                      ; Use another lane (swap the tool map)
        if #global.M291_data[0] != 1
            M291 P"Select the Unit" K{global.M291_data[0]} S4 J2
            if result == -1
                M99
            set var.u = input
        else
            set var.u = 0
        M291 P"Select the lane to continue with" K{global.M291_data[1][var.u]} S4 J2
        if result == -1
            M99
        set var.l = input
        if !global.AFC_lanes[var.u][var.l][0]
            M118 S{"AFC: Unit "^var.u^" Lane "^var.l^" is empty"}
        else
            set var.errors = global.AFC_error_count
            M98 P"0:/sys/AFC/Macros/tool_map_swap.g" A{var.tool} B{global.AFC_lane_to_tool[var.u][var.l]}
            if global.AFC_error_count == var.errors
                set var.done = true

; --- Load the new lane through the normal tool change (tpre/tpost) and resume ---
set var.errors = global.AFC_error_count
T{var.tool}
if global.AFC_error_count != var.errors
    M118 S"AFC: loading the replacement lane failed - the print stays paused"
    M99
M24
