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

G1 'f{(global.AFC_lane_total_length[var.lane_number])} F{global.AFC_load_retract_speed[0]*60}                     ; This is an arbitory load distance to cover the length of the buffer tube
M400                                                                                                              ; finish all moves
M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B1                                                   ; setup the mixing extruder
M400
M584 P{var.total_axis-1}                                                                                          ; hide all the BT axes