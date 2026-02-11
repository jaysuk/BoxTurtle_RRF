; === AFC LED Control and Persistence Macro (RepRapFirmware G-Code) ===

; This macro sets the correct color for each Neopixel/LED based on the numerical status 
; code found in the global.AFC_LED_array. The final action flushes the colors to the 
; strip

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
var curUnit = 0
var curPort = 0
var curLED = 0
var totalLEDs = 0
var curLane = 0
var laneLEDStart = 0
var laneLEDEnd = 0

while iterations < #global.AFC_unit_CAN_ids
    set var.curUnit = iterations
    set var.curPort = 0
    
    while var.curPort < global.AFC_neopixel_port_qty[var.curUnit]
        set var.curLED = 0
        set var.totalLEDs = global.AFC_neopixel[var.curUnit][3][var.curPort]
        
        while var.curLED < var.totalLEDs
            ; Calculate which lane this LED belongs to
            ; System-wide LED index for this unit = (port_index * leds_per_port) + current_led_in_port
            var globalLEDIdx = (var.curPort * global.AFC_leds_per_port[var.curUnit]) + var.curLED
            set var.curLane = floor(var.globalLEDIdx / global.AFC_leds_per_lane[var.curUnit])
            
            if global.AFC_leds_reverse_lane_order[var.curUnit][var.curPort]
                var lanesPerPort = floor(global.AFC_leds_per_port[var.curUnit] / global.AFC_leds_per_lane[var.curUnit])
                var localLane = floor(var.curLED / global.AFC_leds_per_lane[var.curUnit])
                var baseLane = var.curPort * var.lanesPerPort
                set var.curLane = var.baseLane + (var.lanesPerPort - 1) - var.localLane
            
            ; Ensure we don't exceed the total lanes for this unit
            if var.curLane < global.AFC_unit_total_lanes[var.curUnit]
                ; --- Color Assignment based on Status Code ---
                var statusCode = global.AFC_LED_array[var.curUnit][var.curLane]
                
                if var.statusCode == 0 ; Red (Error/Empty)
                    set var.red=255; 
                    set var.green=0; 
                    set var.blue=0
                elif var.statusCode == 1 ; Green (Ready/Loaded)
                    set var.red=0; 
                    set var.green=255; 
                    set var.blue=0
                elif var.statusCode == 2 ; Blue (Active)
                    set var.red=0; 
                    set var.green=0; 
                    set var.blue=255
                elif var.statusCode == 3 ; White
                    set var.red=255; 
                    set var.green=255; 
                    set var.blue=255
                elif var.statusCode == 4 ; Yellow
                    set var.red=255; 
                    set var.green=128; 
                    set var.blue=0
                elif var.statusCode == 5 ; Magenta
                    set var.red=255; 
                    set var.green=0; 
                    set var.blue=128
                elif var.statusCode == 6 ; Cyan
                    set var.red=0; 
                    set var.green=255; 
                    set var.blue=255
                else
                    set var.red=0; 
                    set var.green=0; 
                    set var.blue=0
            else
                ; LED is beyond mapped lanes, turn off
                set var.red=0; set var.green=0; set var.blue=0
            
            ; --- Send Color Command (M150) ---
            if var.curLED < (var.totalLEDs - 1)
                M150 E{global.AFC_neopixel[var.curUnit][1][var.curPort]} R{var.red} U{var.green} B{var.blue} W0 F1
            else
                M150 E{global.AFC_neopixel[var.curUnit][1][var.curPort]} R{var.red} U{var.green} B{var.blue} W0 F0
            
            set var.curLED = var.curLED + 1
            
        set var.curPort = var.curPort + 1