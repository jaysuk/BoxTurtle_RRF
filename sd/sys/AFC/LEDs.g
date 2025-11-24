; === AFC LED Control and Persistence Macro (RepRapFirmware G-Code) ===

; This macro sets the correct color for each Neopixel/LED based on the numerical status 
; code found in the global.AFC_LED_array. The final action flushes the colors to the 
; strip and saves the current state to a file for system reboot persistence.

; --- Color Status Code Reference ---
; 0: Red       (Error / Empty)
; 1: Green     (Ready / Loaded)
; 2: Blue      (Loaded / Active)
; 3: White     (General / Unknown)
; 4: Yellow    (Warning / Low Filament)
; 5: Magenta   (Selection / Change Pending)
; 6: Cyan      (Maintenance / Disabled)

; --- Local Color Variable Initialization ---
var red=0
var blue=0
var green=0

; global.AFC_neopixel_settings[2] holds the total number of LEDs/pixels to control.
while iterations < global.AFC_neopixel_settings[2]                                         ; Loop through each individual LED segment/pixel.
; --- Color Assignment based on Status Code ---
    if global.AFC_LED_array[iterations] == 0                                               ; Check if status code is 0 (typically signifies an error or empty state).
        set var.red=255                                                                    ; Set color to Red.
        set var.green=0
        set var.blue=0
    if global.AFC_LED_array[iterations] == 1                                               ; Check if status code is 1 (typically signifies loaded or ready state).
        set var.red=0
        set var.green=255                                                                  ; Set color to Green.
        set var.blue=0
    if global.AFC_LED_array[iterations] == 2                                               ; Check if status code is 2 (typically signifies a waiting or busy state).
        set var.red=0
        set var.green=0
        set var.blue=255                                                                   ; Set color to Blue.
    if global.AFC_LED_array[iterations] == 3                                               ; Check if status code is 3.
        set var.red=255
        set var.green=255
        set var.blue=255                                                                   ; Set color to White.
    if global.AFC_LED_array[iterations] == 4                                               ; Code 4: Warning / Low Filament (Yellow/Amber)
        set var.red=255                                                                    ; 
        set var.green=128                                                                  ; 
        set var.blue=0
    if global.AFC_LED_array[iterations] == 5                                               ; Code 5: Selection / Change Pending (Magenta/Purple)
        set var.red=255                                                                    ; 
        set var.green=0                                                                    ; 
        set var.blue=128
    if global.AFC_LED_array[iterations] == 6                                               ; Code 6: Maintenance / Disabled (Cyan/Aqua)
        set var.red=0                                                                      ; 
        set var.green=255                                                                  ; 
        set var.blue=255
     
                                                                                           ; --- Send Color Command (M150) ---
                                                                                           ; M150: Set LED color. E: Logical LED number (from global.AFC_neopixel_settings[0]).
                                                                                           ; R/U/B/W: Red/Green/Blue/White components. F: Apply factor/brightness.

    if iterations < (global.AFC_neopixel_settings[2] - 1)                                  ; Check if this is NOT the last pixel in the string.
        M150 E{global.AFC_neopixel_settings[0]} R{var.red} U{var.green} B{var.blue} W0 F1  ; Set color, use F1 (Fade: 1 = do not apply yet).
    else
        M150 E{global.AFC_neopixel_settings[0]} R{var.red} U{var.green} B{var.blue} W0 F0  ; Set color for the final pixel, use F0 (Flush: 0 = apply all pending colors now).

; --- Persistence Cleanup and Save ---
echo >"0:/sys/AFC/AFC-info/LEDs.g" "; LED status"                                          ; Overwrite file with a comment header.
echo >>"0:/sys/AFC/AFC-info/LEDs.g" {"set global.AFC_LED_array = " ^ global.AFC_LED_array} ; Append the executable command to define the global array, hardcoding indices 0-3.