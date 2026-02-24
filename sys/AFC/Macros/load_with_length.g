; === AFC Load Method 1: Measured Lengths ===
; Macro Parameters:
; param.A = tool number 
; param.B = total number of axes (for cleanup)

; --- Machine Feature Flags (Reference) ---
; 6 = load method (0=Switch/TN, 1=Lengths, 2=Preload)

; --- Variable Assignment ---
var tool_number = param.A                                                                                              ; Assign parameter to local variable for cleaner syntax
var unit_number = global.Tool_to_AFC[var.tool_number][0]
var lane_number = global.Tool_to_AFC[var.tool_number][1]
var total_axis = param.B                                                                                               ; Store the total axis count locally.

; --- Final Filament Loading Move ---
; G1: Linear move command. 'f' refers to the temporary filament axis (E-motor/stepper).
; F: Sets the feedrate (mm/min).
; We access the Total Length at index [2] of the AFC_lanes array for this specific unit and lane.
G1 'f{(global.AFC_lanes[var.unit_number][var.lane_number][2])} F{global.AFC_load_retract_speed[var.unit_number][0]*60} ; Feeds filament forward by total stored length.
M400                                                                                                                   ; Wait for the previous move (filament push) to completely finish.
; This next move is to prime the turtleneck
G91                                                                                                            ; Wait for the homing move to finish.
G1  'f{global.AFC_tn_retract_distance[var.unit_number]} F{global.AFC_load_retract_speed[var.unit_number][0] * 60}                                                                                                            ; Wait for the homing move to finish.
G90
; --- Extruder Setup ---
; M98: Macro call.
M98 P"0:/sys/AFC/Macros/extruder_setup.g" A{var.tool_number} B1                                                         ; Executes a macro to configure the main extruder drives (E-axes) for the current lane. The B1 parameter likely indicates the mode (e.g., enable mixing/select drive).
M400                                                                                                                   ; Wait for the extruder setup macro to complete.

; --- Cleanup ---
; M584: Define axes mapping. P parameter specifies which logical drives are currently visible/active.
M584 P{var.total_axis-1}                                                                                               ; Hides the temporary 'F' axis from the system interface by reverting the axis count to the original number (total_axis - 1).