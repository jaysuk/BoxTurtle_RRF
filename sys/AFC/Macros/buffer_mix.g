; buffer_mix.g - set the AFC extruder's share of the mix of a tool (called by the generated buffer trigger<N>.g files)
; param.A tool number (a RRF tool, normally the current tool)
; param.B factor for the AFC extruder (the lane motor): 1 = in step with the toolhead extruder, 0.95 = feeds 5% less, 1.05 = 5% more
; M567 needs one ratio per drive of the tool, so every drive gets 1 and the AFC extruder (the tool's last drive) gets B.
if !exists(param.A) || !exists(param.B)
    M99
if param.A < 0 || param.A >= #tools
    M99

var ratios = vector(#tools[param.A].extruders, 1)
set var.ratios[#tools[param.A].extruders - 1] = param.B
M567 P{param.A} E{var.ratios}
