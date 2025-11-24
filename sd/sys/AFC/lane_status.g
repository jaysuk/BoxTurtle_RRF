; === AFC Lane Loaded Status Persistence Macro (RepRapFirmware G-Code) ===
; Purpose: Saves the current boolean array showing which AFC lanes are loaded to a file.
; This allows the system to recall the operational state after a power cycle.

; --- Write to File (Header) ---
; The '>' operator overwrites the entire file.
echo >"0:/sys/AFC/AFC-info/lane_status.g" "; lane status"                                     ; Overwrite the file and write a comment line (';') for human readability.

; --- Write to File (Data) ---
; The '>>' operator appends to the file.
; The curly braces {} automatically serialize the global array into a parsable string.
echo >>"0:/sys/AFC/AFC-info/lane_status.g" {"set global.lane_loaded = " ^ global.lane_loaded} ; Append the executable G-Code command that re-defines the global array (e.g., {true, false, true, false}) upon file execution.