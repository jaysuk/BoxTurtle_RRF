
; When using a macro as custom gcode, do not use G, M, N or T as parameters in a custom 'G' gcode file
; param.A is the first layer bed temperature
; param.B is filament type
; param.c is first layer temperature
; param.D is the nozzle diameter the model was sliced for
; param.E is the first layer min X
; param.F is the first layer max X
; param.H is the first layer min Y
; param.J is the first layer max Y
; param.K is the initial tool

var tool_number = param.K
var unit_number = global.Tool_to_AFC[var.tool_number][0]                                              ; Get Unit ID

var length_filament_soak = 0

set global.Machine_cancelled = false                                                ; reset the cancelled global value to false

set global.Gcode_bed_temp = param.A                                          ; this updates the global variable slicerBedTemp to be equal to param.A
set global.Gcode_hotend_temp = param.C                                       ; this updates the global variable slicerHotendTemp to be equal to param.C

if global.Machine_nozzle_diameter != param.D                                ; this checks the gcode to ensure it matches the nozzle size installed in the printer
	abort "This gcode is for a different nozzle diameter"                     ; abort the gcode as the nozzle size doesn't match

if global.Gcode_bed_temp_override != 0										
	M190 S{global.Gcode_bed_temp_override}															; set Bed Temperature to whatever is set in slicer
else
	M190 S{param.A}										; set bed temperature to the override temperature set in btncmd instead

set var.length_filament_soak = #global.Machine_filament_soak
while iterations < var.length_filament_soak
	if param.B = global.Machine_filament_soak[{iterations}]
		if !global.Machine_soak_time_override & global.Machine_soak_time != 0                        ; check whether the chamber temperature soak time should be overriden
			M98 P"start_after_delay.g" S{global.Machine_soak_time}							; chamber Soak

if global.Machine_cancelled = true                                                  ; allows print to be cancelled at this point
	M291 P"Print has been cancelled" S0 T3
		G4 S3
		M291 P{"Aborting macro. Line "^line} R"0:/sys/start_print.g" S1
		abort "Print cancelled."
else  
	if !move.axes[global.Machine_axis_number[0]].homed || !move.axes[global.Machine_axis_number[1]].homed || !move.axes[global.Machine_axis_number[2]].homed
		G28                                                                       ; home the printer
	
if global.Machine_cancelled = true                                                  ; allows print to be cancelled at this point
	M291 P"Print has been cancelled" S0 T3
	G4 S3
	M291 P{"Aborting macro. Line "^line} R"0:/sys/start_print.g" S1
	abort "Print cancelled."

set global.AFC_extruder_temp[var.unit_number][var.tool_number] = param.C

T{param.K}

if global.Gcode_hotend_temp_override == 0										; check whether the hotend temperature should be overriden
	M568 P{param.K} S{param.C} R{param.C} A2		                                                ; set hotend Temperature to whatever is set in slicer
else
	M568 P{param.K} S{global.Gcode_hotend_temp_override} R{global.Gcode_hotend_temp_override} A2							    ; set hotend temperature to the override temperature set in btncmd instead
M116 P{param.K}                                                                     ; wait for this temperature to be reached
