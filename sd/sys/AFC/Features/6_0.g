M574 'f2 P{global.TN_switches[0]} S1                                                                              ; This sets the TN Advance pin as a homing switch for loading the filament
G1 H4 'f20000 F{global.AFC_load_retract_speed[0]*60}                                                              ; This is an arbitory load distance to cover the length of the buffer tube
M400                                                                                                              ; finish all moves
G91                                                                                                               ; relative mode
G4 P500
G1 H2 'f{-global.AFC_tn_retract_distance} F{global.AFC_load_retract_speed[1]*60}                                  ; This retracts 15mm of filament to ensure the buffer is somewhere in the middle and not triggering either the trailing or advance switches
M400                                                                                                              ; finish all moves
G90                                                                                                               ; absolute mode
G4 P500
M574 'f2 P"nil" S1                                                                                                ; free up the endstop pin for this axis
G4 P500
M400
M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B1                                                   ; setup the mixing extruder
M400
M584 P{var.total_axis-1}                                                                                          ; hide all the BT axes