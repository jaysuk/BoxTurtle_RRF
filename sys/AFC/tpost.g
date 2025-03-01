; param.A - This is the lane number
; param.B - This is so the heaters aren't turned on

if !exists(param.A)
    echo "Missing the lane number"
    abort

var tpost_time=0
var tpre_time=global.AFC_time
var time=0
var time_seconds=0
var time_minutes=0
var lane_number=param.A

if param.B != 1
    M568 P{var.lane_number} S220                                                         ; Enable the hotend to this temperature
    M116 P{var.lane_number}                                                                              ; Wait for it to reach that temperature
G1 E{global.extruder_to_nozzle} F120                                                     ; This gets the filament to the nozzle
set global.AFC_LED_array[{var.lane_number}]=1                                            ; This sets the colour back to green
M950 J{global.AFC_buffer_input_numbers[0]} C{global.TN_switches[0]}                      ; Advance
M950 J{global.AFC_buffer_input_numbers[1]} C{global.TN_switches[1]}                      ; Trail
M581 P{global.AFC_buffer_input_numbers[0]} R1 T{global.AFC_buffer_trigger_numbers[0]} S1 ; TN Advance trigger5.g
M581 P{global.AFC_buffer_input_numbers[1]} R1 T{global.AFC_buffer_trigger_numbers[1]} S1 ; TN Trailing trigger6.g
;M591 P1 D0 C{global.AFC_load_switch[var.lane_number]} S1                                 ; This enables a filament sensor

M400

set var.tpost_time=state.upTime
set var.time=var.tpost_time-var.tpre_time
set var.time_minutes=floor(var.time/60)
set var.time_seconds=var.time-(var.time_minutes*60)

echo "The tool load time was "^var.time^" seconds ("^var.time_minutes^" minutes and "^var.time_seconds^" seconds)"