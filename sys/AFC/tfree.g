; param.A - This is the lane number
; param.B - This determines if the DC motors should run. B1 is yes

M98 P"0:/sys/AFC/park.g"

if !exists(param.A)
    echo "Missing the lane number"
    abort

var tfree_time1=0
var tfree_time=state.upTime
var time=0
var time_seconds=0
var time_minutes=0
var DC_motor=0

var total_axis = #move.axes
var retract = global.extruder_to_nozzle+5
var lane_number = param.A

if exists(param.B)
    set var.DC_motor=param.B
else
    set var.DC_motor=0

; This is for feeding the filament away from the extruder and back into the lane

; Disable the buffer
M581 P{global.AFC_buffer_input_numbers[0]} R-1 T{global.AFC_buffer_trigger_numbers[0]}
M581 P{global.AFC_buffer_input_numbers[1]} R-1 T{global.AFC_buffer_trigger_numbers[1]}
M400
M950 J{global.AFC_buffer_input_numbers[0]} C"nil"                                                                     ; Advance
M950 J{global.AFC_buffer_input_numbers[1]} C"nil"                                                                     ; Trail

; This sets the colour of for this lane to blue to indicate a tool change is being under taken
set global.AFC_LED_array[{var.lane_number}]=2

;M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{param.A} B1 ; setup the mixing extruder

; This move retracts the filament out of the extruder
M83
G1 E{-var.retract} F120
M400

; This is to unmap the filament monitor
;M591 P1 D0 C"nil" S1

; This is to unmap the extruder
M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B0

M98 P"0:/sys/AFC/Motors/Axis_setup.g" A{var.lane_number}

G92 's{global.AFC_lane_total_length[var.lane_number]}

; This is for retracting the filament out of the tube
if var.DC_motor==1
    M98 P"0:/sys/AFC/Motors/dc_motors.g" A"R" B{var.lane_number}                       ; This sets the DC motor in reverse to wind the filament up
G1 's{global.AFC_lane_first_length[{var.lane_number}]} F{global.AFC_retract_speed} ; This retracts the filament
M400
if var.DC_motor==1
    M98 P"0:/sys/AFC/Motors/dc_motors.g" A"O" B{var.lane_number}                       ; This turns the DC motor off

; Need to add a check of the hub here!!!

; This sets the LED colour back to green
set global.AFC_LED_array[{var.lane_number}]=1

; This hides the axes again
M584 P{var.total_axis-1}

M400

set var.tfree_time1=state.upTime
set var.time=var.tfree_time1-var.tfree_time
set var.time_minutes=floor(var.time/60)
set var.time_seconds=var.time-(var.time_minutes*60)

echo "The tool unload time was "^var.time^" seconds ("^var.time_minutes^" minutes and "^var.time_seconds^" seconds)"