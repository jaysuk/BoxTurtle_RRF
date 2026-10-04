; hex_to_rgb.g - convert a "#RRGGBB" colour string to red/green/blue 0-255
; param.A the colour string, e.g. "#FF8000" (upper or lower case)
; Result: global.AFC_rgb = [r, g, b], or [-1, -1, -1] when the string is not a valid #RRGGBB colour.

set global.AFC_rgb = [-1, -1, -1]
if !exists(param.A)
    M99
if #param.A != 7 || take(param.A, 1) != "#"
    M99

var value = 0
var digit = 0
var rgb = [0, 0, 0]
while iterations < 6
    set var.digit = find("0123456789abcdef", take(drop(param.A, 1 + iterations), 1))
    if var.digit < 0
        set var.digit = find("0123456789ABCDEF", take(drop(param.A, 1 + iterations), 1))
    if var.digit < 0
        M99                                                         ; not a hex digit: leave the result invalid
    if mod(iterations, 2) == 0
        set var.value = var.digit * 16                              ; high nibble of the colour channel
    else
        set var.rgb[floor(iterations / 2)] = var.value + var.digit  ; low nibble completes the channel
set global.AFC_rgb = var.rgb
