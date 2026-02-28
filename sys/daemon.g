; ==========================================================================================
; AFC Daemon (daemon.g)
; Runs continuously in the background to handle periodic tasks.
; Currently handles high-frequency filament tracking for active spools.
; ==========================================================================================

; --- Filament Usage Tracking (RAM & SD Card) ---
; Check if Spool Tracking feature is actually enabled
if exists(global.Machine_features) && global.Machine_features[7] == 1
    
    ; Ensure a tool is currently loaded and active
    if state.currentTool != -1
        var extIdx = tools[state.currentTool].filamentExtruder
        
        ; Verify the tool actually has a valid filament extruder configured
        if var.extIdx != -1
            
            ; Calculate extrusion since the last daemon tick using absolute position
            var current_extrusion = move.extruders[var.extIdx].position
            var diff = var.current_extrusion - global.spool_extrusion_baseline[state.currentTool]
            
            ; If diff is negative, a G92 E0 occurred or someone pulled the filament manually backwards.
            ; Reset the baseline to match the new origin point to resume tracking forward.
            if var.diff < 0
                set global.spool_extrusion_baseline[state.currentTool] = var.current_extrusion
            
            ; Only process if a measurable amount of filament was actually pushed forward
            elif var.diff > 0.05
                var u = global.Tool_to_AFC[state.currentTool][0]
                var l = global.Tool_to_AFC[state.currentTool][1]
                
                ; Verify the lane actually has a physical Spool ID assigned
                if global.spool_active_data[var.u][var.l][0] != -1
                    
                    ; Ensure First Used Date is populated if this is the very first time it's extruded
                    if global.spool_active_data[var.u][var.l][6] == "" && state.time != null
                        set global.spool_active_data[var.u][var.l][6] = state.time
                        
                    ; Always update Last Used Date whenever filament is actively consumed
                    if state.time != null
                        set global.spool_active_data[var.u][var.l][7] = state.time
                    
                    ; 1. RAM / UI HEARTBEAT: Instantly deduct from active memory
                    ; This ensures web dashboards and RRF variables update in real-time
                    set global.spool_active_data[var.u][var.l][5] = global.spool_active_data[var.u][var.l][5] - var.diff
                    
                    ; 2. Advance the baseline forward to capture this deduction
                    set global.spool_extrusion_baseline[state.currentTool] = var.current_extrusion
                    
                    ; 3. Add to the "Unsaved" buffer
                    set global.spool_unsaved_extrusion[state.currentTool] = global.spool_unsaved_extrusion[state.currentTool] + var.diff
                    
                    ; 4. SD CARD HEARTBEAT: Write to the physical SD card every 1000mm (1 meter)
                    ; This prevents micro-stutters and extreme flash wear by batching saves
                    if global.spool_unsaved_extrusion[state.currentTool] >= 1000.0
                        M98 P"0:/sys/AFC/Macros/spool_write.g" U{var.u} L{var.l}
                        set global.spool_unsaved_extrusion[state.currentTool] = 0.0
