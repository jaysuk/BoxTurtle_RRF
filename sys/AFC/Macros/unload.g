; === AFC Lane Unload (unload.g) - pulls the filament of an idle lane back onto the spool ===
; param.A - tool number of the lane
; param.B - 1 = run the DC motors (ignored: the unit's DC setting AFC_features[u][0] decides)
; Idle use only (Lane - Unload). It refuses to touch the lane of the tool that is currently loaded.

; AFC_features[u] = {use DC motor, unload method, load method}

var total_length = 0                                                                                  ; Length of the lane (park position to the toolhead sensor)
var unload_length = 0
var retries = 5
var retry_successful = false
var additional_unload = 120
var unload_retry_length = 50
var attempt = 0

if !exists(param.A)                                                                                   ; This checks for the existance of param.A as it is needed for this macro to work
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"unload.g: missing the tool number (A)"
    M99

var tool_number = param.A
var unit_number = global.Tool_to_AFC[var.tool_number][0]                                              ; Get Unit ID
var lane_number = global.Tool_to_AFC[var.tool_number][1]

; Pulling filament through a loaded extruder would grind it: the current tool must be unloaded with T-1 first
if move.motionSystems[0].currentTool >= 0 && move.motionSystems[0].currentTool < #global.AFC_tool_map
    if global.AFC_tool_map[move.motionSystems[0].currentTool][0] == var.unit_number && global.AFC_tool_map[move.motionSystems[0].currentTool][1] == var.lane_number
        M98 P"0:/sys/AFC/Macros/afc_error.g" S{"Unit "^var.unit_number^" Lane "^var.lane_number^" is loaded in the toolhead. Select T-1 first, then unload the lane"}
        M99

M118 S{"Unit " ^ var.unit_number ^ " Lane " ^ var.lane_number ^ " is being unloaded."}                ; This message is to confirm the lane being unloaded

if !global.AFC_lanes[var.unit_number][var.lane_number][0]                                             ; Nothing recorded as loaded in this lane
    M118 S{"No Filament Loaded in Unit " ^ var.unit_number ^ " Lane "^var.lane_number^" to Unload"}
    M99

set var.total_length = global.AFC_lanes[var.unit_number][var.lane_number][2]
set var.unload_length = var.total_length + 50                                                         ; This is to give an extra length during unloading

M98 P"0:/sys/AFC/Macros/lane_motion_begin.g" A{var.tool_number}                                       ; Map the lane motor to 'f, unhide it, disarm Longboi triggers

M574 'f1 P{"!"^global.AFC_load_switch[var.unit_number][var.lane_number]} S1                           ; Load switch (inverted) as the 'f min endstop: triggers when the filament has cleared it
; Retry loop: the first pass is the normal unload, later passes are retries from a shorter start position
while iterations < var.retries + 1 && !var.retry_successful
    set var.attempt = iterations
    if var.attempt == 0
        G92 'f{var.unload_length}                                                                     ; Start position = unload length (50mm more than the measured length)
    else
        G92 'f{var.unload_retry_length}
    if global.AFC_features[var.unit_number][0]                                                        ; This is the check whether the DC motor is required to run
        M98 P"0:/sys/AFC/Macros/dc_motors.g" A"R" B{var.tool_number}                                  ; This enables the DC motor in the reseverse direction
        M400
    G1 H4 'f0 F{global.AFC_load_retract_speed[var.unit_number][1]*60}                                 ; Retract onto the spool until the load switch clears (bounded by the start position)
    M400
    G92 'f{var.additional_unload}                                                                     ; Additional length to make sure the filament has passed the initial loading endstop
    G4 S1
    M400
    G1 'f0 F{global.AFC_load_retract_speed[var.unit_number][1]*60}                                    ; Does one final unload
    M400
    if global.AFC_features[var.unit_number][0]
        M98 P"0:/sys/AFC/Macros/dc_motors.g" A"O" B{var.tool_number}                                  ; This ensures the DC motor is off regardless of whether it was commanded to be on
        M400
    if sensors.endstops[global.AFC_f_axis].triggered                                                  ; The load switch has cleared: the filament is unloaded
        set var.retry_successful = true

if var.retry_successful
    set global.AFC_lanes[var.unit_number][var.lane_number][0] = false                                 ; This marks the lane as having no filament loaded
    M98 P"0:/macros/Spool - Unassign" A{var.unit_number} B{var.lane_number}                           ; Automatically unassign the spool since the lane is empty
    set global.AFC_LED_array[var.unit_number][var.lane_number] = 0                                    ; This sets the neopixel colour for this lane to 0
    set global.AFC_lanes[var.unit_number][var.lane_number][4][0] = "None"
    set global.AFC_lane_hex[var.unit_number][var.lane_number] = ""
    M98 P"0:/sys/AFC/Macros/leds.g"                                                                   ; This runs the LED macro which sets the lane colour to red
    M98 P"0:/sys/AFC/Macros/save_status.g"                                                            ; and records its status to the SD card
    M118 S{"Unit " ^ var.unit_number ^ " Lane "^var.lane_number^" has been successfully unloaded"}
else
    M118 S{"Unit " ^ var.unit_number ^ " Lane "^var.lane_number^" has not been successfully unloaded. Please recheck your measurements"}

M98 P"0:/sys/AFC/Macros/lane_motion_end.g" A{var.tool_number}                                         ; Frees the load switch, hides the axis, re-arms the triggers
