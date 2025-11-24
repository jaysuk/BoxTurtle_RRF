; === AFC Lane Filament Status Persistence Macro (RepRapFirmware G-Code) ===
; Purpose: Converts the current state of the global array global.AFC_lane_filament_type
;          into a formatted string and saves it to a file for automatic reloading on startup.

var s = "{"                                                                                 ; Initialize a local string variable 's' with the opening brace for the array definition.

while iterations < #global.AFC_lane_filament_type                                           ; Loop through each element in the global array (using '#' for array length).
  set var.s = var.s ^ """" ^ global.AFC_lane_filament_type[iterations] ^ """"               ; Append the current filament type element, enclosed in double quotes ("") as strings must be quoted in RRF arrays.

  if iterations+1 < #global.AFC_lane_filament_type                                          ; Check if the current element is NOT the last element in the array.
    set var.s = var.s ^ ","                                                                 ; Append a comma to separate elements, preventing a trailing comma error.

set var.s = var.s ^ "}"                                                                     ; Finalize the string with the closing brace for the array definition.

; --- Write to File ---
echo >"0:/sys/AFC/AFC-info/lane_filament.g" " ; lane filament"                              ; Overwrite the file with a comment line (';') for human readability.
echo >>"0:/sys/AFC/AFC-info/lane_filament.g" "set global.AFC_lane_filament_type = " ^ var.s ; Append the final, executable G-Code command that re-defines the global array upon file execution.