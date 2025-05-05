M574 'f2 P{global.extruder_switches[0]} S1                                                                        ; set pre-extruder input pin as endstop for 'f
M400
G1 H4 'f20000 F{global.AFC_load_retract_speed[0]*60}                                                              ; Load filament until the endstop is triggered
M400
M574 'f2 P"nil" S1                                                                                                ; Unset 'f endstop pin
G4 P500
M400
M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B1                                                   ; setup the mixing extruder
M400
M584 P{var.total_axis-1}                                                                                          ; hide all the BT axes