; === AFC Load Method 0: Turtleneck/Switch Based ===
; --- Macro Parameters ---
; param.A = tool number                              ; The index of the active filament lane.

; --- Machine Feature Flags (Reference) ---
; 6 = load method (0=Switch/TN, 1=Lengths, 2=Preload)

; --- Variable Assignment ---
var tool_number = param.A                                                                                            ; Assign parameter to local variable for cleaner syntax
var unit_number = global.Tool_to_AFC[var.tool_number][0]
var lane_number = global.Tool_to_AFC[var.tool_number][1]

M584 P{#move.axes} 
; --- Filament Load to Sensor (Homing Move) ---
; M574: Define endstop configuration for the temporary 'F' axis.
; 'f2' suggests setting up the "maximum" endstop (high end).
M574 'f2 P{global.AFC_TN_switches[var.unit_number][0]} S1                                                                ; Assigns the pin for the **TN Advance Switch** (index 0) as the maximum endstop for the temporary 'F' axis.
M400
G4 S1
; G1 H4: Homing move for the specified axis. Stops upon endstop trigger.
G1 H4 'f{global.AFC_max_min_axes[var.unit_number][1]} F{global.AFC_load_retract_speed[var.unit_number][0] * 60}      ; Feeds filament forward (homing move) up to 20000mm (arbitrary distance) until the TN Advance Switch is triggered. Speed is in mm/min.
M400                                                                                                                 ; Wait for the homing move to finish.

; --- Retract to Park Position (Relative Move) ---
G91                                                                                                                  ; Switch to relative positioning mode.
G4 P500                                                                                                              ; Pause for 500 milliseconds (0.5 seconds).
; G1 H2: Relative move, ignoring software limits (allows retraction outside of defined max boundary).
G1 H2 'f{-global.AFC_tn_retract_distance[var.unit_number]} F{global.AFC_load_retract_speed[var.unit_number][1] * 60} ; Retracts the filament by a defined distance to position it safely within the buffer tube (not touching either switch).
M400                                                                                                                 ; Wait for the retraction to finish.
G90                                                                                                                  ; Switch back to absolute positioning mode.

; --- Cleanup and Setup Extruder ---
G4 P500                                                                                                              ; Pause for 500 milliseconds.
M574 'f2 P"nil" S1                                                                                                   ; De-assign the physical pin from the 'F' axis endstop configuration.
G4 P500
M400
M98 P"0:/sys/AFC/Macros/extruder_setup.g" A{var.tool_number} B1                                                      ; Execute a macro to configure the physical extruder/toolhead for the current lane. (B1 likely indicates 'mixing' or 'enabled').
M400
M584 P{#move.axes-1}                                                                                             ; Reconfigure the axis mapping string to hide the temporary 'F' axis from the user interface.