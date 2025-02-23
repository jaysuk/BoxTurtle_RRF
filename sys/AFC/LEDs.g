; This sets the correct colour for each neopixel depending on whats set in the global.AFC_LED_array
; Once it has set the correct colour, it then writes the LED colours to a file so they can be recalled at system reboot

var red=0
var blue=0
var green=0

while iterations < 4
    if global.AFC_LED_array[iterations] == 0        ; This check would see if any LEDs should be Red
        set var.red=255
        set var.green=0
        set var.blue=0
    if global.AFC_LED_array[iterations] == 1        ; This check would see if any LEDs should be Green
        set var.red=0
        set var.green=255
        set var.blue=0
    if global.AFC_LED_array[iterations] == 2        ; This check would see if any LEDs should be Blue
        set var.red=0
        set var.green=0
        set var.blue=255
    if global.AFC_LED_array[iterations] == 3
        set var.red=255
        set var.green=255
        set var.blue=255
    if iterations < 3
        M150 R{var.red} U{var.green} B{var.blue} W0 F1
    else
        M150 R{var.red} U{var.green} B{var.blue} W0 F0

if fileexists("0:/sys/AFC/AFC-info/LEDs.g")
    M472 P"0:/sys/AFC/AFC-info/LEDs.g"
echo >"0:/sys/AFC/AFC-info/LEDs.g" "; LED status"
echo >>"0:/sys/AFC/AFC-info/LEDs.g" {"set global.AFC_LED_array = {" ^ global.AFC_LED_array[0] ^ "," ^ global.AFC_LED_array[1] ^ "," ^ global.AFC_LED_array[2] ^ "," ^ global.AFC_LED_array[3] ^ "}"}