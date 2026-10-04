; This file maps (B1) or unmaps (B0) the lane of a tool on the AFC extruder of its printer head
; param.A is the tool number
; param.B is whether to map (1) or unmap (0)
; The AFC extruder of the head (global.AFC_head_extruder[printerTool]) is driven by the lane's stepper. M584 E always takes
; the complete extruder list, so every other extruder keeps what it has now (read back from the object model) - this also
; leaves the AFC extruder of another IDEX head on its own lane.

if !exists(param.A) || !exists(param.B)
    M98 P"0:/sys/AFC/Macros/afc_error.g" S"extruder_setup.g: missing the A (tool) or B (map/unmap) parameter" Q1 F1
    M99

var tool_number = param.A
var unit_number = global.AFC_tool_map[var.tool_number][0]
var lane_number = global.AFC_tool_map[var.tool_number][1]
var afc_ext = global.AFC_head_extruder[global.tool_and_motion[var.unit_number][0]]   ; AFC extruder of this lane's head

if var.afc_ext < 0 || var.afc_ext >= #move.extruders
    M98 P"0:/sys/AFC/Macros/afc_error.g" S{"extruder_setup.g: no AFC extruder for tool "^var.tool_number} Q1 F1
    M99

if param.B == 1
    ; global.AFC_steppers: 0 = driver number, 1 = direction, 2 = microsteps, 3 = steps per mm, 4 = current, 5 = jerk, 6 = max speed, 7 = acceleration
    var n = #move.extruders
    var driver = vector(var.n, 0)
    var accel = vector(var.n, 0)
    var current = vector(var.n, 0)
    var jerk = vector(var.n, 0)
    var stepping = vector(var.n, 0)
    var speed = vector(var.n, 0)
    var stepspermm = vector(var.n, 0)
    var ratios = vector(#tools[var.tool_number].extruders, 1)                   ; mix: 1 for every drive of the tool except the AFC extruder
    while iterations < var.n
        if iterations == var.afc_ext
            set var.driver[iterations] = global.AFC_steppers[var.unit_number][var.lane_number][0]
            set var.accel[iterations] = global.AFC_steppers[var.unit_number][var.lane_number][7]
            set var.current[iterations] = global.AFC_steppers[var.unit_number][var.lane_number][4]
            set var.jerk[iterations] = global.AFC_steppers[var.unit_number][var.lane_number][5] * 60
            set var.stepping[iterations] = global.AFC_steppers[var.unit_number][var.lane_number][2]
            set var.speed[iterations] = global.AFC_steppers[var.unit_number][var.lane_number][6] * 60
            set var.stepspermm[iterations] = global.AFC_steppers[var.unit_number][var.lane_number][3]
        else
            set var.driver[iterations] = move.extruders[iterations].driver
            set var.accel[iterations] = move.extruders[iterations].acceleration
            set var.current[iterations] = move.extruders[iterations].current
            ; OM extruder jerk/speed are mm/s; M566/M203 take mm/min
            set var.jerk[iterations] = move.extruders[iterations].jerk * 60
            set var.stepping[iterations] = move.extruders[iterations].microstepping.value
            set var.speed[iterations] = move.extruders[iterations].speed * 60
            set var.stepspermm[iterations] = move.extruders[iterations].stepsPerMm
    M584 E{var.driver}
    M350 E{var.stepping}
    M92 E{var.stepspermm}
    M906 E{var.current}
    M566 E{var.jerk}
    M203 E{var.speed}
    M201 E{var.accel}
    M83
    M567 P{var.tool_number} E{var.ratios}                                        ; Mix 1:1 - the toolhead extruder(s) and the AFC motor move together

else                                                                             ; UNMAP (soft disable): the AFC motor stays still
    var ratios_off = vector(#tools[var.tool_number].extruders, 1)
    set var.ratios_off[#tools[var.tool_number].extruders - 1] = 0                ; the AFC extruder is the tool's last drive
    M567 P{var.tool_number} E{var.ratios_off}
    M83                                                                          ; Set relative extrusion mode
