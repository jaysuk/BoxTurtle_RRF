; === AFC LED Control Macro (leds.g) ===
; Paints every unit's neopixel strips from global.AFC_LED_array with ONE M150 per lane segment (all LEDs of a lane share a
; colour), so a refresh costs one CAN command per lane instead of one per LED (B50).
;
; --- Status code reference (AFC_LED_array[u][l]) ---
; 0: Red       (Error / Empty)
; 1: Green     (Ready / Loaded) - shows the lane's filament colour (AFC_lane_hex) when one is set
; 2: Blue      (Busy / filament in the toolhead)
; 3: White     (General / Unknown)
; 4: Yellow    (Warning / Needs attention)
; 5: Magenta   (Selection / Change Pending)
; 6: Cyan      (Maintenance / Disabled)
; any other value: off
;
; Strip layout (AFC_neopixel[u]): [1] strip number, [3] LEDs in the strip, [4] LEDs per lane, [5] reversed, [6] brightness.
; A strip holds floor(LEDs / perLane) lane segments, in lane order along the strip (reverse order when the strip is reversed);
; the strips of a unit continue each other (strip 1 starts at the lane after the last lane of strip 0).

var colours = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255], [255, 128, 0], [255, 0, 128], [0, 255, 255]]
var u = 0
var port = 0
var seg = 0
var segs = 0
var rest = 0
var base_lane = 0
var lane = 0
var code = 0
var red = 0
var green = 0
var blue = 0
var more = 1
var prev = 0

while iterations < #global.AFC_unit_CAN_ids
    set var.u = iterations
    set var.base_lane = 0
    while iterations < global.AFC_neopixel_port_qty[var.u]
        set var.port = iterations
        if global.AFC_neopixel[var.u][4][var.port] < 1
            continue
        set var.segs = floor(global.AFC_neopixel[var.u][3][var.port] / global.AFC_neopixel[var.u][4][var.port])
        set var.rest = global.AFC_neopixel[var.u][3][var.port] - var.segs * global.AFC_neopixel[var.u][4][var.port]

        while iterations < var.segs
            set var.seg = iterations
            if global.AFC_neopixel[var.u][5][var.port]
                set var.lane = var.base_lane + var.segs - 1 - var.seg      ; reversed strip: the first segment is the last lane
            else
                set var.lane = var.base_lane + var.seg
            set var.red = 0
            set var.green = 0
            set var.blue = 0
            if var.lane < global.AFC_unit_total_lanes[var.u]
                set var.code = global.AFC_LED_array[var.u][var.lane]
                if var.code >= 0 && var.code <= 6
                    set var.red = var.colours[var.code][0]
                    set var.green = var.colours[var.code][1]
                    set var.blue = var.colours[var.code][2]
                if var.code == 1 && global.AFC_lane_hex[var.u][var.lane] != ""   ; ready: show the filament colour
                    M98 P"0:/sys/AFC/Macros/hex_to_rgb.g" A{global.AFC_lane_hex[var.u][var.lane]}
                    if global.AFC_rgb[0] >= 0
                        set var.red = global.AFC_rgb[0]
                        set var.green = global.AFC_rgb[1]
                        set var.blue = global.AFC_rgb[2]
            set var.more = 1
            if var.seg == var.segs - 1 && var.rest == 0
                set var.more = 0                                           ; last command of the strip flushes it
            M150 E{global.AFC_neopixel[var.u][1][var.port]} R{var.red} U{var.green} B{var.blue} W0 P{global.AFC_neopixel[var.u][6][var.port]} S{global.AFC_neopixel[var.u][4][var.port]} F{var.more}

        if var.rest > 0                                                    ; LEDs beyond the last whole lane segment stay off
            M150 E{global.AFC_neopixel[var.u][1][var.port]} R0 U0 B0 W0 P{global.AFC_neopixel[var.u][6][var.port]} S{var.rest} F0
        set var.base_lane = var.base_lane + var.segs
