; --- Macro Parameters ---
; param.A = lane number                              ; The index of the active filament lane.
; param.B = total number of axes                      ; The total number of configured motion axes (used for cleanup).

; --- AFC Feature Flags (Reference) ---
; 0 = brush
; 1 = cut
; 2 = kick
; 3 = park
; 4 = poop
; 5 = purge
; 6 = load
; 7 = startup check
; 8 = use the dc motor on unload
; 9 = unload method
; 10 = spoolman support

; --- Variable Assignment ---
var lane_number = param.A                                                        ; Store the active lane number locally.
var total_axis = param.B                                                         ; Store the total axis count locally.

; --- Filament Load to Sensor (Homing Move) ---
; M574: Define endstop configuration for the temporary 'F' axis.
; 'f2' suggests setting up the "maximum" endstop (high end).
M574 'f2 P{global.TN_switches[0]} S1                                             ; Assigns the pin for the **TN Advance Switch** (index 0) as the maximum endstop for the temporary 'F' axis.
; G1 H4: Homing move for the specified axis. Stops upon endstop trigger.
G1 H4 'f20000 F{global.AFC_load_retract_speed[0]*60}                             ; Feeds filament forward (homing move) up to 20000mm (arbitrary distance) until the TN Advance Switch is triggered. Speed is in mm/min.
M400                                                                             ; Wait for the homing move to finish.

; --- Retract to Park Position (Relative Move) ---
G91                                                                              ; Switch to relative positioning mode.
G4 P500                                                                          ; Pause for 500 milliseconds (0.5 seconds).
; G1 H2: Relative move, ignoring software limits (allows retraction outside of defined max boundary).
G1 H2 'f{-global.AFC_tn_retract_distance} F{global.AFC_load_retract_speed[1]*60} ; Retracts the filament by a defined distance to position it safely within the buffer tube (not touching either switch).
M400                                                                             ; Wait for the retraction to finish.
G90                                                                              ; Switch back to absolute positioning mode.

; --- Cleanup and Setup Extruder ---
G4 P500                                                                          ; Pause for 500 milliseconds.
M574 'f2 P"nil" S1                                                               ; De-assign the physical pin from the 'F' axis endstop configuration.
G4 P500
M400
M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B1                  ; Execute a macro to configure the physical extruder/toolhead for the current lane. (B1 likely indicates 'mixing' or 'enabled').
M400
M584 P{var.total_axis-1}                                                         ; Reconfigure the axis mapping string to hide the temporary 'F' axis from the user interface.