; --- Macro Parameters ---
; param.A = lane number                              ; The index of the active filament lane.
; param.B = total number of axes                      ; The total number of configured motion axes.

; --- AFC Feature Flags (Reference) ---
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

; --- Variable Assignment ---
var lane_number = param.A                                                                     ; Store the active lane number locally.
var total_axis = param.B                                                                      ; Store the total axis count locally.

; --- Final Filament Loading Move ---
; G1: Linear move command. 'f' refers to the temporary filament axis (E-motor/stepper).
; F: Sets the feedrate (mm/min).
G1 'f{(global.AFC_lane_total_length[var.lane_number])} F{global.AFC_load_retract_speed[0]*60} ; Feeds the filament forward by a distance equal to the total length stored for this lane. This move aims to push the filament from the buffer, through the hotend path, and to the nozzle.
M400                                                                                          ; Wait for the previous move (filament push) to completely finish.

; --- Extruder Setup ---
; M98: Macro call.
M98 P"0:/sys/AFC/Motors/Extruder_setup.g" A{var.lane_number} B1                               ; Executes a macro to configure the main extruder drives (E-axes) for the current lane. The B1 parameter likely indicates the mode (e.g., enable mixing/select drive).
M400                                                                                          ; Wait for the extruder setup macro to complete.

; --- Cleanup ---
; M584: Define axes mapping. P parameter specifies which logical drives are currently visible/active.
M584 P{var.total_axis-1}                                                                      ; Hides the temporary 'F' axis from the system interface by reverting the axis count to the original number (total_axis - 1).