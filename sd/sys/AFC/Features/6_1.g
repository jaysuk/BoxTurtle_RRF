G1 'f{(global.AFC_lane_total_length[var.lane_number])} F{global.AFC_load_retract_speed[0]*60}                     ; This is an arbitory load distance to cover the length of the buffer tube
M400                                                                                                              ; finish all moves
M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B1                                                   ; setup the mixing extruder
M400
M584 P{var.total_axis-1}                                                                                          ; hide all the BT axes