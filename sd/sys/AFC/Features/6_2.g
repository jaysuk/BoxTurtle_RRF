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