; === Conditional Debugging Output Macro ===
; param.A is the string message to be displayed.

if global.AFC_debug ; Check if the global variable 'AFC_debug' (Automatic Filament Changer Debug flag) is set to true.
    M118 S{param.A} ; If debugging is enabled, execute M118. M118 sends a message (S parameter) back to the host/console.