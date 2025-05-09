
; stop.g
; called when M0 (Stop) is run (e.g. when a print from SD card is cancelled)
; 
M106 P0 S0																								; turn off the print cooling fan
M220 S100 																								; reset speed factor override percentage to 100%
M221 D0 S100																							; reset extrude factor override percentage to 100%
M290 R0 S0
M83
G1 E-5 F2400 																						; retract the filament a bit before lifting the nozzle to release some of the pressure
G90 																									; absolute positioning
if {(move.axes[2].machinePosition) < (move.axes[2].max - 10)} 											; check if there's sufficient space to raise head
	M291 P{"Raising head to...  " ^ move.axes[2].machinePosition+5}  R"Raising head" S0 T5				; message box to announce movement
	G1 Z{move.axes[2].machinePosition+5} F9000 															; move Z up a bit
G1 X60 Y115 																							; move print head to the back centre
M400 																									; wait for current moves to finish
T-1
if !global.overrideHotendOff																			; check if hotend should be turned off
	M568 P0 R0 S0 A0 																					; set T0 and temps off
if !global.overrideBedOff																				; check if bed should be turned off
	M140 S-273.1 																						; set heated bed heater off 
G92 E0																									; reset extrusion position
M84 																									; steppers off
set global.slicerHotendTempOverride = 0																	; reset extruder temp override
set global.slicerBedTempOverride = 0																	; reset bed temp override
set global.AFC_extruder_temp = {0,0,0,0}