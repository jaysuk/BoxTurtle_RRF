; === Conditional Debugging Output Macro ===
; param.A is the string message to be displayed.

if global.AFC_debug || global.Machine_debug ; Machine_debug is the user setting (Machine_user_vars.g); AFC_debug is kept for old files.
    M118 S{"AFC: " ^ param.A} ; If debugging is enabled, execute M118. M118 sends a message (S parameter) back to the host/console.