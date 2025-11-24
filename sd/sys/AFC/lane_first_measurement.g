; === AFC Lane First Length Persistence Macro (RepRapFirmware G-Code) ===
; Purpose: Saves the filament length used on the first load for each lane to a file.
; This allows the system to recall the exact load distance required for subsequent loads.

; --- Write to File (Header) ---
; The '>' operator overwrites the entire file.
echo >"0:/sys/AFC/AFC-info/lane_first_length.g" "; lane first lengths"                                          ; Overwrite the file and write a comment line (';') for human readability.

; --- Write to File (Data) ---
; The '>>' operator appends to the file.
; RRF automatically converts the global array {global.lane_first_length} into a string format suitable for re-execution.
echo >>"0:/sys/AFC/AFC-info/lane_first_length.g" {"set global.lane_first_length = " ^ global.lane_first_length} ; Append the executable G-Code command that defines the global array upon file execution.