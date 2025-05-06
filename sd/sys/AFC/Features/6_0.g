; param.A = lane number
; param.B = total number of axes

; AFC Feature Numbers
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

var lane_number = param.A
var total_axis = param.B

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