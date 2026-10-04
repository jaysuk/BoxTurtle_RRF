; afc_error.g - report an AFC failure and leave the machine recoverable (never aborts)
; param.S message (required)
; param.T tool number (optional): its lane LED goes red, its DC motor is stopped and its hub input is freed
; param.Q 1 = pause the print if one is running (not P: M98 uses P for the macro file name, so P is never passed on)
; param.F 1 = a tool change is running: set Machine_tpre_failed so the following tpre/tpost steps skip
; Callers do their own cleanup of pins they bound, then call this and M99. During a print the pause is deferred until
; the tool-change macros have returned, so a failed tfree/tpre sets global.Machine_tpre_failed to make the rest skip.
if !exists(param.S)
    M118 S"afc_error.g called without S"
    M99

set global.AFC_error_count = global.AFC_error_count + 1

var unit_number = -1
var lane_number = -1
if exists(param.T) && param.T >= 0 && param.T < #global.Tool_to_AFC
    set var.unit_number = global.Tool_to_AFC[param.T][0]
    set var.lane_number = global.Tool_to_AFC[param.T][1]

if var.unit_number >= 0
    if global.AFC_features[var.unit_number][0]
        M98 P"0:/sys/AFC/Macros/dc_motors.g" A"O" B{param.T}
    M950 J{global.AFC_hub_input_numbers[var.unit_number]} C"nil"
    set global.AFC_LED_array[var.unit_number][var.lane_number] = 0

if exists(param.F) && param.F == 1
    set global.Machine_tpre_failed = true

M98 P"0:/sys/AFC/Macros/lane_motion_end.g"          ; free the 'f endstop, hide 'f, re-arm triggers
M98 P"0:/sys/AFC/Macros/leds.g"
M118 S{"AFC error: " ^ param.S}
M98 P"0:/sys/AFC/Macros/afc_log.g" S{"ERROR: " ^ param.S}

if exists(param.Q) && param.Q == 1 && job.file.fileName != null && state.status != "paused" && state.status != "pausing"
    if inputs[state.thisInput].name == "File" || inputs[state.thisInput].name == "File2"
        M226                                            ; job channel: deferred until the tool-change macros unwind
    else
        M25                                             ; other channels: RRF defers it itself if the job is inside a macro

M291 P{param.S} R"AFC error" S1 T0
