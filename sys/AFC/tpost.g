; param.A - This is the lane number

if !exists(param.A)
    echo "Missing the lane number"
    abort

var lane_number=param.A

M568 P{var.lane_number} S210                                  ; Enable the hotend to this temperature
M116 P0                                               ; Wait for it to reach that temperature
G1 E{global.extruder_to_nozzle} F120                  ; This gets the filament to the nozzle
set global.AFC_LED_array[{var.lane_number}]=1                 ; This sets the colour back to green
M98 P"0:/sys/AFC/LEDs.g"
M950 J{global.AFC_buffer_input_numbers[0]} C{global.TN_switches[0]}                      ; Advance
M950 J{global.AFC_buffer_input_numbers[1]} C{global.TN_switches[1]}                      ; Trail
M581 P{global.AFC_buffer_input_numbers[0]} R1 T{global.AFC_buffer_trigger_numbers[0]} S1 ; TN Advance trigger5.g
M581 P{global.AFC_buffer_input_numbers[1]} R1 T{global.AFC_buffer_trigger_numbers[1]} S1 ; TN Trailing trigger6.g