; afc_log.g - append one line to the AFC log (when Machine_log is true)
; param.S message
; The log is 0:/sys/AFC/Status/afc.log. AFC.g moves the previous one to afc.old.log at every boot, so it never grows unbounded.
if !exists(param.S)
    M99
if exists(global.Machine_log) && global.Machine_log
    var stamp = "up " ^ state.upTime ^ "s"
    if state.time != null
        set var.stamp = state.time
    echo >>"0:/sys/AFC/Status/afc.log" var.stamp, param.S
