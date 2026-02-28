if !exists(param.A)                                                                                                                                     ; This just checks if the lane number has been provided.
    M118 S"Missing the lane number"                                                                                                                     ; Echo error message
    abort                                                                                                                                               ; Stop execution

var unit_number = global.Tool_to_AFC[var.tool_number][0]                                                                                                ; Get Unit ID
var lane_number = global.Tool_to_AFC[var.tool_number][1]                                                                                                ; Get Local Lane ID

M98 P"0:/sys/AFC/Macros/axis_setup.g" A{var.tool_number}                                                                                                ; Map the lane motor to an axis
M400
M98 P"0:/sys/AFC/Macros/extruder_setup.g" A{var.tool_number} B1                                                      ; Execute a macro to configure the physical extruder/toolhead for the current lane. (B1 likely indicates 'mixing' or 'enabled').
M400
set global.AFC_LED_array[var.unit_number][var.lane_number]=2                                                                               ; Set LED status to Blue (Busy/Active).
M98 P"0:/sys/AFC/Macros/LEDs.g"  
; --- Spoolman Integration ---
if global.Machine_features[7] == 1                                                                                                         ; Check if Spoolman feature is enabled (Index 8).
    set global.spoolman[var.unit_number][var.lane_number][1] = true                                                                        ; Enable extrusion tracking for this lane.
    
    ; Snapshot the extruder's position value so we can calculate differences
    var extIdx = tools[var.tool_number].filamentExtruder
    if var.extIdx != -1
        set global.spool_extrusion_baseline[var.tool_number] = move.extruders[var.extIdx].position
        set global.spool_unsaved_extrusion[var.tool_number] = 0.0

    G92 E0               