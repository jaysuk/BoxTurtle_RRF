; ==========================================================================================
; AFC Daemon (daemon.g)
; Runs continuously in the background to handle periodic tasks.
; Currently handles high-frequency filament tracking for active spools.
; ==========================================================================================

; --- Boot State Check (once, after boot, never while a job is running) ---
if exists(global.AFC_boot_check_pending) && global.AFC_boot_check_pending && state.upTime > 10 && job.file.fileName == null
    set global.AFC_boot_check_pending = false
    M98 P"0:/sys/AFC/Macros/boot_check.g"
    if exists(global.Machine_features) && global.Machine_features[6]            ; "start check": verify the lanes recorded as loaded
        M98 P"0:/sys/AFC/Macros/startup_check.g"

; --- Filament Usage Tracking (RAM & SD Card) ---
; Check if Spool Tracking feature is actually enabled
if exists(global.Machine_features) && global.Machine_features[7] == 1
    
    ; Ensure a tool is currently loaded and active
    if move.motionSystems[0].currentTool != -1
        var extIdx = tools[move.motionSystems[0].currentTool].filamentExtruder
        
        ; Verify the tool actually has a valid filament extruder configured
        if var.extIdx != -1
            
            ; Calculate extrusion since the last daemon tick using absolute position
            var current_extrusion = move.extruders[var.extIdx].position
            var diff = var.current_extrusion - global.spool_extrusion_baseline[move.motionSystems[0].currentTool]
            
            ; The baseline is a high-water mark: only position beyond it counts as consumption, so a retraction followed
            ; by its un-retract is not counted (B13). A jump of more than 50mm backwards means G92 E0 (or a long manual
            ; retract): restart the high-water mark at the new origin without deducting anything.
            if var.diff < -50
                set global.spool_extrusion_baseline[move.motionSystems[0].currentTool] = var.current_extrusion
            
            ; Only process if a measurable amount of filament was actually pushed forward past the high-water mark
            elif var.diff > 0.05
                var u = global.Tool_to_AFC[move.motionSystems[0].currentTool][0]
                var l = global.Tool_to_AFC[move.motionSystems[0].currentTool][1]
                
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
                    set global.spool_extrusion_baseline[move.motionSystems[0].currentTool] = var.current_extrusion
                    
                    ; 3. Add to the "Unsaved" buffer
                    set global.spool_unsaved_extrusion[move.motionSystems[0].currentTool] = global.spool_unsaved_extrusion[move.motionSystems[0].currentTool] + var.diff
                    
                    ; 4. SD CARD HEARTBEAT: Write to the physical SD card every 1000mm (1 meter)
                    ; This prevents micro-stutters and extreme flash wear by batching saves
                    if global.spool_unsaved_extrusion[move.motionSystems[0].currentTool] >= 1000.0
                        M98 P"0:/sys/AFC/Macros/spool_write.g" U{var.u} L{var.l}
                        set global.spool_unsaved_extrusion[move.motionSystems[0].currentTool] = 0.0

; --- Remaining filament of the current lane's spool, for the low-spool trigger (-1 = none) ---
if exists(global.Machine_features) && global.Machine_features[7] == 1
    set global.AFC_spool_left = -1
    if move.motionSystems[0].currentTool >= 0 && move.motionSystems[0].currentTool < #global.AFC_tool_map
        if global.spool_active_data[global.AFC_tool_map[move.motionSystems[0].currentTool][0]][global.AFC_tool_map[move.motionSystems[0].currentTool][1]][0] != -1
            set global.AFC_spool_left = global.spool_active_data[global.AFC_tool_map[move.motionSystems[0].currentTool][0]][global.AFC_tool_map[move.motionSystems[0].currentTool][1]][5]
