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
var lane_number = param.A                                       ; Store the active lane number locally.
var total_axis = param.B                                        ; Store the total axis count locally.

; --- Filament Loading to Sensor ---
; M574: Define endstop configuration for the temporary 'F' axis (motor).
; 'f2' sets the Max Endstop; 'P' specifies the pin; 'S1' sets the active-low/normal mode.
M574 'f2 P{global.extruder_switches[0]} S1                      ; Assigns the pin for the pre-extruder filament sensor (extruder_switches[0]) as the maximum endstop for the 'F' axis.
M400                                                            ; Wait for the M574 command to be fully processed.
; G1 H4: Homing move for the specified axis. Stops immediately upon endstop trigger.
G1 H4 'f20000 F{global.AFC_load_retract_speed[0]*60}            ; Drives the filament forward (20000mm arbitrary max distance) until the pre-extruder sensor is triggered, confirming the filament is staged. Speed is in mm/min.
M400                                                            ; Wait for the homing move to finish.

; --- Endstop Cleanup and Tool Activation ---
M574 'f2 P"nil" S1                                              ; De-assign the physical pin (P"nil") from the 'F' axis endstop, freeing the pin.
G4 P500                                                         ; Pause for 500 milliseconds.
M400
M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B1 ; Execute a macro to configure and enable the main extruder drives (E-axes) for the current lane, ready for printing.
M400
M584 P{var.total_axis-1}                                        ; Revert the axis configuration to hide the temporary 'F' axis from the user interface.