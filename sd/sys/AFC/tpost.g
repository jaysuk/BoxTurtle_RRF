; param.A - This is the lane number
; param.B - This is so the heaters aren't turned on

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

if !exists(param.A)
    echo "Missing the lane number"
    abort

var tpost_time=0
var tpre_time=global.AFC_time
var time=0
var time_seconds=0
var time_minutes=0
var lane_number=param.A

if !exists(param.B) || param.B != 1
    if global.AFC_extruder_temp[{var.lane_number}] != 0
        M568 P{var.lane_number} S{global.AFC_extruder_temp[{var.lane_number}]} R{global.AFC_extruder_temp[{var.lane_number}]}
    else
        M568 P{var.lane_number} S220 R220                                                        ; Enable the hotend to this temperature
    M116 P{var.lane_number}                                                                              ; Wait for it to reach that temperature
if global.AFC_features[1]
    G1 E{global.main_extruder_measurements[1]} F{global.AFC_load_retract_speed[0]*60} 
else
    G1 E{global.main_extruder_measurements[0]} F{global.AFC_load_retract_speed[0]*60}                                                     ; This gets the filament to the nozzle

M400
if global.AFC_features[4]
    M98 P"0:/sys/AFC/poop.g"

if global.AFC_features[2]
    M98 P"0:/sys/AFC/kick.g"

set global.AFC_LED_array[{var.lane_number}]=1                                            ; This sets the colour back to green
M950 J{global.AFC_buffer_input_numbers[0]} C{global.TN_switches[0]}                      ; Advance
M950 J{global.AFC_buffer_input_numbers[1]} C{global.TN_switches[1]}                      ; Trail
M581 P{global.AFC_buffer_input_numbers[0]} R1 T{global.AFC_buffer_trigger_numbers[0]} S1 ; TN Advance trigger5.g
M581 P{global.AFC_buffer_input_numbers[1]} R1 T{global.AFC_buffer_trigger_numbers[1]} S1 ; TN Trailing trigger6.g
M591 P1 D1 C{global.AFC_load_switch[var.lane_number]} S1                                 ; This enables a filament sensor

M400
if global.AFC_features[3]
    M98 P"0:/sys/AFC/park.g"

if global.AFC_features[5]
    M98 P"0:/sys/AFC/purge.g"

if global.AFC_features[0]
    M98 P"0:/sys/AFC/brush.g"

M400

set var.tpost_time=state.upTime
set var.time=var.tpost_time-var.tpre_time
set var.time_minutes=floor(var.time/60)
set var.time_seconds=var.time-(var.time_minutes*60)

echo "The tool load time was "^var.time^" seconds ("^var.time_minutes^" minutes and "^var.time_seconds^" seconds)"

if global.AFC_features[10] == 1
    set global.spoolman_capture_extrusion[{var.lane_number}] = true
    G92 E0

G1 R2 X0 Y0 Z5 F{global.AFC_travel_speed[0]*60}