; stop.g
; called when M0 (Stop) is run (e.g. when a print from SD card is cancelled)
; 
var unit_number = 0
var lane_number = 0

while iterations < #fans
	M106 P{iterations} S0																		; turn off every fan
M220 S100                                                                                                             ; reset speed factor override percentage to 100%
M221 D0 S100                                                                                                          ; reset extrude factor override percentage to 100%
M290 R0 S0
M83
G1 E-5 F2400                                                                                                          ; retract the filament a bit before lifting the nozzle to release some of the pressure
G90                                                                                                                   ; absolute positioning
if {(move.axes[global.Machine_axis_number[2]].machinePosition) < (move.axes[global.Machine_axis_number[2]].max - 10)} ; check if there's sufficient space to raise head
	M291 P{"Raising head to...  " ^ move.axes[global.Machine_axis_number[2]].machinePosition+5}  R"Raising head" S0 T5   ; message box to announce movement
	G1 Z{move.axes[global.Machine_axis_number[2]].machinePosition+5} F9000                                               ; move Z up a bit
if global.Machine_features[3] && global.Machine_park[0] != -1
	G1 X{global.Machine_park[0]} Y{global.Machine_park[1]} F{global.Machine_travel_speed[0]*60}				; move print head to the AFC park position
M400                                                                                                                  ; wait for current moves to finish
if global.Machine_unload_on_cancel																	; Machine_unload_on_cancel = false leaves the filament where it is
	T-1
if !global.Machine_override_hotend_off                                                                                ; check if hotend should be turned off
	while iterations < #tools
		M568 P{iterations} R0 S0 A0													; all tools off (the AFC tools share the heater)
if !global.Machine_override_bed_off                                                                                   ; check if bed should be turned off
	M140 S-273.1                                                                                                         ; set heated bed heater off 
G92 E0                                                                                                                ; reset extrusion position
M18                                                                                                                   ; steppers off
set global.Gcode_hotend_temp_override = 0                                                                             ; reset extruder temp override
set global.Gcode_bed_temp_override = 0                                                                                ; reset bed temp override
while iterations < #global.AFC_unit_CAN_ids
	set var.unit_number = iterations
	while iterations < global.AFC_unit_total_lanes[var.unit_number]
		set var.lane_number = iterations
		set global.AFC_extruder_temp[var.unit_number][var.lane_number] = 0