
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
var length_filament_soak = 0

set global.Cancelled = false                                                ; reset the cancelled global value to false

set global.slicerBedTemp = param.A                                          ; this updates the global variable slicerBedTemp to be equal to param.A
set global.slicerHotendTemp = param.C                                       ; this updates the global variable slicerHotendTemp to be equal to param.C

if global.nozzleDiameterInstalled != param.D                                ; this checks the gcode to ensure it matches the nozzle size installed in the printer
	abort "This gcode is for a different nozzle diameter"                     ; abort the gcode as the nozzle size doesn't match

if global.slicerBedTempOverride != 0										
	M190 S{global.slicerBedTempOverride}															; set Bed Temperature to whatever is set in slicer
else
	M190 S{param.A}										; set bed temperature to the override temperature set in btncmd instead

var.length_filament_soak = #global.filamentSoak
while iterations < var.length_filament_soak
	if param.B = global.filamentSoak[{iterations}]
		if !global.soakTimeOverride & global.soakTime != 0                        ; check whether the chamber temperature soak time should be overriden
			M98 P"start_after_delay.g" S{global.soakTime}							; chamber Soak

if global.Cancelled = true                                                  ; allows print to be cancelled at this point
	M291 P"Print has been cancelled" S0 T3
		G4 S3
		abort "Print cancelled."
else  
    if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed
		G28                                                                       ; home the printer
	
if global.Cancelled = true                                                  ; allows print to be cancelled at this point
	M291 P"Print has been cancelled" S0 T3
	G4 S3
	abort "Print cancelled."

set global.AFC_extruder_temp[{param.K}] = param.C

T{param.K}

if global.slicerHotendTempOverride == 0										; check whether the hotend temperature should be overriden
	M568 P{param.K} S{param.C} R{param.C} A2		                                                ; set hotend Temperature to whatever is set in slicer
else
	M568 P{param.K} S{global.slicerHotendTempOverride} R{global.slicerHotendTempOverride} A2							    ; set hotend temperature to the override temperature set in btncmd instead
M116 P{param.K}                                                                     ; wait for this temperature to be reached
