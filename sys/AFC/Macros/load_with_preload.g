; --- Macro Parameters ---
; param.A = tool number                              ; The index of the active filament lane.

; --- Variable Assignment ---
var tool_number = param.A                                                                                       ; Assign parameter to local variable for cleaner syntax
var unit_number = global.Tool_to_AFC[var.tool_number][0]
var lane_number = global.Tool_to_AFC[var.tool_number][1]                                                                                        ; Store the total axis count locally.
M584 P{#move.axes} 
; --- Filament Loading to Sensor ---
; M574: Define endstop configuration for the temporary 'F' axis (motor).
; 'f2' sets the Max Endstop; 'P' specifies the pin; 'S1' sets the active-low/normal mode.
M574 'f2 P{global.Machine_extruder_switches[0]} S1                                                              ; Assigns the pin for the pre-extruder filament sensor (extruder_switches[0]) as the maximum endstop for the 'F' axis.
M400                                                                                                            ; Wait for the M574 command to be fully processed.
G4 S1
; G1 H4: Homing move for the specified axis. Stops immediately upon endstop trigger.
G1 H4 'f{global.AFC_max_min_axes[var.unit_number][1]} F{global.AFC_load_retract_speed[var.unit_number][0] * 60} ; Drives the filament forward (20000mm arbitrary max distance) until the pre-extruder sensor is triggered, confirming the filament is staged. Speed is in mm/min.
M400
; This next move is to prime the turtleneck
;G91                                                                                                            ; Wait for the homing move to finish.
;G1  'f{global.AFC_tn_retract_distance[var.unit_number]} F{global.AFC_load_retract_speed[var.unit_number][0] * 60}                                                                                                            ; Wait for the homing move to finish.
;G90
; --- Endstop Cleanup and Tool Activation ---
M574 'f2 P"nil" S1                                                                                              ; De-assign the physical pin (P"nil") from the 'F' axis endstop, freeing the pin.
G4 P500                                                                                                         ; Pause for 500 milliseconds.
M400
M98 P"0:/sys/AFC/Macros/extruder_setup.g" A{var.tool_number} B1                                                 ; Execute a macro to configure and enable the main extruder drives (E-axes) for the current lane, ready for printing.
M400
M584 P{#move.axes-1}                                                                                         ; Revert the axis configuration to hide the temporary 'F' axis from the user interface.