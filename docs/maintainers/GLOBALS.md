# Global variable reference

Every `global.*` used by the system: shape, index meaning, defaults, and who writes/reads it.
`[u]` = unit index, `[l]` = lane index, `[t]` = tool number. "Decl" = file containing `global X = …`.
Regenerate the read/write lists with the cross-reference script described in `CLAUDE.md` when you change code.

## 1. Topology & mapping (decl: `AFC_Unit_Count.g` / `AFC_Units_Setup.g`)

| Global | Shape / default | Meaning | Written by | Read by |
|---|---|---|---|---|
| `AFC_unit_CAN_ids` | `[119]` | CAN address per unit. `#` of this = unit count everywhere. | AFC_Unit_Count.g | everything |
| `AFC_unit_total_lanes` | `[4]` | lanes per unit | AFC_Unit_Count.g | everything |
| `AFC_unit_total_available_lanes` | int | Σ lanes = number of AFC tools | Units_Setup | Units_Setup, calculate_tools, Lane - Unload to Hub |
| `Tool_to_AFC` | `[t] = {u, l}` | the **static** numbering: tool `t` is the *native tool* of lane `{u,l}` (lane identity for the lane helpers, afc_error, dc_motors) | Units_Setup | lane macros, calculate_tools |
| `AFC_tool_map` | `[t] = {u, l}`, default = `Tool_to_AFC` | **the lane that RRF tool `t` currently draws from** (P3-03). Tool-change macros resolve lanes through it; persisted in status.g | Units_Setup, tool_map_swap, Lane - Map Tool | tpre, tpost, tfree, extruder_setup, load_with_*, tool_load_no_files, boot_check, purge, set_temp_global, start_print, validate_job, unload, buffer triggers |
| `AFC_lane_backup` | `[u][l]` = native tool number of the backup lane, -1 none | infinite spool (P3-04); persisted | Units_Setup, Lane - Set Backup | filament-error |
| `AFC_lane_to_tool` | `[u][l] = t` | inverse map | Units_Setup | Create System Files, Lane-/Test- macros. **Should replace the hand-rolled `countdown` loops (B10)** |
| `tool_and_motion` | `[u] = {printerTool, motionSystem}` default `{0,0}` | the printer tool (head) whose heater/fans/offsets/axis mapping the unit's lanes use. `[1]` motion system: only 0 is supported (config_check warns) | user vars | calculate_tools, extruder_setup, config_check |
| `AFC_head_extruder` | `[printerTool]` = OM extruder index of that head's AFC extruder, -1 if no unit feeds the tool | one AFC extruder per head, appended after the printer's extruders in order of first use | calculate_tools | extruder_setup |
| `multiple_tools` | bool | true if units feed more than one printer tool (IDEX) | calculate_tools | Create System Files |
| `AFC_mainboard` | `[u]` 0=AFC-Lite, 1=Longboi | Longboi needs lane triggers disabled during motion (STM32 interrupt sharing) | user vars | lane_motion_begin/end |

## 2. Motion (decl: `AFC_Units_Setup.g`)

| Global | Shape / default | Index meaning | Read by |
|---|---|---|---|
| `AFC_steppers` | `[u][l] = {driver, dir, microsteps, steps/mm, current mA, jerk mm/s, maxSpeed mm/s, accel mm/s²}` default `{CAN+0.l+0.0001, 0, 16, 682, 1000, 60, 60, 3000}` | driver id is a **float** `CAN.lane` plus `0.0001`. Keep the offset: RRF rounds `10*x` to the nearest driver, but an integer value in an array is read as main-board driver N, and the offset guarantees a float (B55, RRF_NOTES §2). | AFC_setup (M569), axis_setup, calculate_tools, extruder_setup |
| `AFC_load_retract_speed` | `[u] = {load, unload, extruderLoad}` mm/s, `{35,35,5}` | | many |
| `AFC_max_min_axes` | `[u] = {min, max}` `{-500, 20000}` | `'f` axis M208 limits; `[1]` is only the search distance for a lane that has not been measured | axis_setup, load_with_*, tfree |
| `AFC_hub_retract_distance` | `[u]` 35 | back-off after hub trigger (defines park) | Measure First, tfree, Unload to Hub, startup_check |
| `AFC_hub_load_distance` | `[u] = {initial, retryStep}` `{45,5}` | tpre hub probe; `[0]` must be larger than `AFC_hub_retract_distance` (config_check; B46 fixed) | tpre, config_check |
| `AFC_tn_retract_distance` | `[u]` 15 | back-off after TN advance trigger | load_with_turtleneck, Measure Main Length |
| `AFC_features` | `[u] = {useDC, unloadMethod, loadMethod}` `{true,0,0}` | `[0]` DC assist on unload; `[1]` 0=hub switch 1=lengths; `[2]` 0=turtleneck 1=lengths 2=extruder/preload switch | tfree, tpre, unload, filament-error, Lane-/Test- macros, generated tfree.g |
| `AFC_extruder_temp` | `[u][l]` 0 | per-lane print temp; 0 → 220 °C default | written: start_print, set_temp_global (both index `[u][l]` through `Tool_to_AFC`, B04 fixed P1-08), stop (reset). read: tpre, tpost |

## 3. Pins, triggers, inputs (decl: `AFC_Units_Setup.g`) – see HARDWARE_RESOURCES.md

| Global | Shape | Default for AFC-Lite |
|---|---|---|
| `AFC_SLP_pins` | `[u][l]` string | `"119.SLP1".."SLP4"` (DC driver sleep) |
| `AFC_DC_pins` | `[u][l] = {in1, in2}` | `"119.dc11"/"119.dc21"` … |
| `AFC_prep_switch` | `[u][l]` | `"^!119.SW2".."SW5"` |
| `AFC_load_switch` | `[u][l]` | `"^119.SW7".."SW10"` |
| `AFC_TN_switches` | `[u] = {advance, trailing}` | `"119.SW11","119.SW12"` |
| `AFC_hub_switch` | `[u]` | `"^119.SW1"` |
| `AFC_trigger_numbers` | `[u][l]` | M581 T numbers, start at 2, sequential over all lanes |
| `AFC_buffer_trigger_numbers` | `[u] = {adv, trail}` | after last lane trigger |
| `AFC_trigger_input_numbers` | `[u][l]` | M950 J numbers for prep switches, start at 0 |
| `AFC_buffer_input_numbers` | `[u] = {adv, trail}` | after last lane J (bound in tpost, freed in tfree) |
| `AFC_hub_input_numbers` | `[u]` | after last buffer J |
| `AFC_unload_input_numbers` | `[u]` | allocated per unit; **entry `[0]` is the J of the extruder input switch**, bound once at boot by AFC.g (`M574 E` for every extruder) when `Machine_features[8]==1` and read by tfree |
| `AFC_dcm_out_no` | `[0,1,2]` (global, not per unit) | M950 P output numbers used by dc_motors.g – config_check warns when one is already defined in config.g (B35 mitigated) |
| `AFC_dc_speed`, `AFC_dc_freq`, `AFC_dc_load_assist` | 1.0, 500, false | DC motor duty cycle (PWM on the driven logic pin when < 1) and PWM frequency; whether the DC motor also assists during tpre (P3-10) |
| `AFC_neopixel_port_qty` | `[u]` 1 | |
| `AFC_neopixel` | `[u] = {pins[], ledIdx[], type[], count[], perLane[], reverse[], brightness[]}` each sized by port qty | M950 E / M150 parameters |

## 4. Lane state (decl: `AFC_Units_Setup.g`, persisted in `Status/status.g`)

| Global | Shape | Meaning |
|---|---|---|
| `AFC_lanes` | `[u][l] = {loaded, firstLen, totalLen, reserved, {type, colour}}` default `[false,0,0,0,["None","None"]]` | `[0]` filament present in lane (not "in toolhead"); `[1]`/`[2]` see ARCHITECTURE §1.1; `[3]` reserved (the unused "continuous" flag; the backup lane is `AFC_lane_backup`); `[4]` = `{type, colour}` everywhere (B14 fixed). btncmd edits `[4][0]`. |
| `AFC_lane_hex` | `[u][l]` string `"#RRGGBB"` or `""` | filament colour shown by the LED when the lane is ready; set by Lane - Set Filament / Spool - Assign, cleared on unload/unassign; persisted |
| `AFC_rgb` | `[r,g,b]` | result of hex_to_rgb.g |
| `AFC_LED_array` | `[u][l]` int | 0 red empty/error, 1 green ready, 2 blue busy/active, 3 white, 4 yellow, 5 magenta, 6 cyan |
| `AFC_time` | number | `state.upTime` at tpre start (for timing report) |
| `AFC_f_axis` | -1 | OM index of the `'f` axis, set by lane_motion_begin.g (replaces `Machine_om_axis_number`). Read by every macro that uses `sensors.endstops[]` / `move.axes[]` for `'f` |
| `AFC_error_count` | 0 | incremented by every afc_error call; callers compare before/after a nested step (`T-1`, `T<n>`, `tool_map_swap`) |
| `AFC_tip_retracted` | 0 | mm the filament was pulled back by tip_form.g; tfree retracts only the rest |
| `AFC_buffer_fault_triggers` | `[u]` | M581.1 trigger numbers (both buffer switches active), after the last buffer trigger |
| `AFC_lowspool_trigger`, `AFC_spool_left` | number, -1 | low-spool M581.1 trigger number; mm left on the current lane's spool (kept by sys/daemon.g, -1 = none) |
| `AFC_loaded_tool` | -1 | tool that was loaded at the last status save, persisted in `Status/status.g`; boot_check.g asks what to do with it. Written by save_status, boot_check |
| `AFC_boot_check_pending` | false | true from the end of AFC.g until sys/daemon.g has run boot_check.g |
| `AFC_settings_loaded` | bool (decl AFC.g) | guard so defaults load once per boot |
| `AFC_debug` | false | read by debug.g; **not user-settable** (Machine_debug is never read, B29) |

## 5. Spool tracking (decl: `AFC_Units_Setup.g`)

| Global | Shape | Meaning |
|---|---|---|
| `spool_tracking` | `[u][l] = {spoolId (-1 none), trackingActive}` | lane assignment; persisted in `spool_status.g` (P2-10; renamed from `spoolman`) |
| `spoolman` | same shape | **deprecated migration shim**: an old `spool_status.g` sets it; AFC.g copies it into `spool_tracking` and rewrites the file. Remove in a later release |
| `spool_active_data` | `[u][l]` = 12 fields: `{0 id, 1 type, 2 colour, 3 manufacturer, 4 initial mm, 5 remaining mm, 6 firstUsed, 7 lastUsed, 8 hex, 9 price, 10 emptyWeight g, 11 density}` | **must always be 12 elements**; clear a slot by copying `spool_empty_record` (B03, fixed P1-03) |
| `spool_empty_record` | 12-field array `[-1, "", "", "", 0.0, 0.0, "", "", "", 0.0, 0.0, 1.24]` | the only literal copy of an empty spool record; used to reset `spool_load_temp` and `spool_active_data[u][l]`. Written: never. Read: AFC_Units_Setup, Spool - Assign/Unassign/Inventory, spool_read_all |
| `spool_load_temp` | 12-field vector | scratch target of executing a `0:/spools/<id>.g` file |
| `spool_extrusion_baseline` | `[t]` float | extruder position at last accounting. sized `AFC_unit_total_available_lanes` (AFC tools are `0..N-1`; B05, fixed P1-04) |
| `spool_unsaved_extrusion` | `[t]` float | mm since last SD write (daemon writes at ≥1000); sized like the baseline |

## 6. Machine settings (decl: `Machine_Vars_Setup.g`, user overrides `Machine/Machine_user_vars.g`)

| Global | Default | Meaning / indices | Used by |
|---|---|---|---|
| `Machine_travel_speed` | `{150,5}` mm/s | XY, Z | cleaning macros, tpost |
| `Machine_debug` | false | **unused** (B29) | – |
| `Machine_features` | `{brush,cut,kick,park,poop,purge,startCheck,spoolTracking,initialUnload}` all false/0 | 0 brush, 1 cut, 2 kick, 3 park, 4 poop, 5 purge, 6 start check (**unused**), 7 spool tracking (0/1), 8 initial unload (0 = by measurement, 1 = to extruder input switch) | tpost, tfree, sys/daemon, root daemon (uses [7] wrongly) |
| `Machine_om_axis_number` | -1 | **Deprecated, no longer read** (use `AFC_f_axis`). Kept so old user files that still `set` it don't fail | startup_check (to be replaced) |
| `Machine_axis_number` | `{iX,iY,iZ}` auto-detected | | cut, kick, brush*, park, start_print, stop, tfree |
| `Machine_extruder_measurements` | `{125,40,80}` | input→nozzle, input→cutter, cutter→nozzle | tpost (prime), tfree (retract), purge |
| `Machine_extruder_switches` | `{"nil","nil"}` | switch above / below extruder (main-board pins) | load_with_preload, Measure Main Length, tfree (initial unload) |
| `Machine_soak_time`, `Machine_nozzle_diameter`, `Machine_filament_soak` | 15, 0.4, `{"ABS","ASA"}` | | start_print |
| `Machine_cut_location` | `{-1,-1}` | X/Y where cutter arm touches pin | cut |
| `Machine_cut_direction` | "left" | left/right/front/back | cut |
| `Machine_cut_dist` | `{6.0,8.5}` | park offset, compress distance | cut |
| `Machine_cut_move` | `{32,10,150,50,0.85,25,2}` | fast, slow, evacuate mm/s, dwell ms, fast fraction, E speed mm/s, cut count | cut |
| `Machine_cut_retract_length` 20, `Machine_cut_quick_tip_forming` false, `Machine_cut_rip {1.0,3}`, `Machine_cut_pushback {15,20}`, `Machine_cut_current_stepper {0,0,0}` | | | cut |
| `Machine_cut_restore_pos`, `Machine_cut_safe_margin` | | **unused** | – |
| `Machine_purge_location {-1,-1}`, `Machine_purge_speed 6.5`, `Machine_z_purge_move true`, `Machine_purge_fast_z {200,20}`, `Machine_purge_start 0.6`, `Machine_part_cooling_fan {true,1.0,2}`, `Machine_purge_length {72.111,60.999}` | | | poop |
| `Machine_purge_length_modifier`, `Machine_purge_length_addition` | 1, 0 | applied to the slicer's purge length by poop.g (P3-05) | poop |
| `Machine_purge_restore` | | **unused** | – |
| `Machine_kick` | `{-1,-1,5,1.5,150,0,"right",45,10}` | 0 X, 1 Y, 2 approach Z, 3 kick Z, 4 speed, 5 accel (0 = machine accel), 6 direction, 7 distance, 8 post-kick Z (B21 fixed) | kick |
| `Machine_brush` | 19 fields | 0-2 centre XYZ, 3 speed, 4 width X, 5 depth Y, 6 Y-then-X, 7 passes, 8 servo/motor deploy, 9 servo pin, 10 deployed angle, 11 retracted angle, 12 servo index, 13 accel (**unused**), 14 Z-min required, 15 "safe brush" pre-position required, 16-18 safe XYZ | brush, brush_safe_*, park, purge |
| `Machine_park` | `{-1,-1,0}` | | park |
| `Machine_tip_*` (ramming, toolchange temp, unloading speed, cooling, skinnydip) | | used by tip_form.g when `Machine_tip_forming` is on (P3-09) | tip_form |
| `Machine_step_through_macro`, `Machine_startup_check` | false | step_through_macro (no callers); root daemon (dead) | – |
| `Machine_last_tool` | -1 | written by tfree, **never read** | – |
| `Machine_slicer_purge` | -1 | purge length (mm) from the slicer for the next tool change (set_temp_global C); poop.g uses it once and resets it | set_temp_global | poop |
| `Machine_unload_on_cancel` | true | stop.g runs `T-1` on cancel | – | stop.g |
| `Machine_log` | true | write `Status/afc.log` | – | afc_log |
| `Machine_low_spool` | 0 | mm left on a spool that triggers the low-spool warning (0 = off) | – | AFC.g, trigger file |
| `Machine_tip_forming`, `Machine_filament_diameter` | false, 1.75 | tip forming on (cutter off) / filament diameter for the ramming volume | – | tfree, tip_form |
| `Machine_tpre_failed` | false | "this tool change failed" handshake. Set by afc_error F1 / tpre / load_with_*; cleared at the start of tfree and by tpost. tpre and tpost skip while it is set; tfree clears it itself when no tool follows | afc_error, tfree, tpre, load_with_*, tpost |
| `Machine_actual_tools` | `[t] = {extruders[], fans[], heaters[], axes[][], offsets[]}` (decl gather_machine_info) | printer's tools before AFC redefines them; `[3]` = `tools[t].axes` (axes mapped to X, Y), `[4]` = `tools[t].offsets` | calculate_tools, AFC.g, config_check |
| `Machine_extruder_info` | `[e] = {accel, current, driver, jerk, {interp, microsteps}, speed, steps/mm}` (decl gather_machine_info) | OM snapshot, **jerk/speed are mm/s** (×60 for M566/M203, B06 fixed) | calculate_tools, Create System Files |

## 7. Print workflow (decl: `Machine_Vars_Setup.g`)

| Global | Meaning | Notes |
|---|---|---|
| `Gcode_bed_temp`, `Gcode_hotend_temp` | slicer values | written by start_print, never read |
| `Gcode_bed_temp_override`, `Gcode_hotend_temp_override` | 0 = use slicer | reset in stop.g |
| `Machine_soak_time_override`, `Machine_override_bed_off`, `Machine_override_hotend_off`, `Machine_cancelled` | user toggles (btncmd) | start_after_delay checks `global.Cancelled` instead (B39) |

## 8. UI helpers

| Global | Shape | Meaning |
|---|---|---|
| `M291_data` | `[0] = {"Unit 0",…}`, `[1][u] = {"Lane 0",…}`, `[2][u] = {"Lane 0",…,"All"}` | M291 `K{}` option lists |

## 9. Referenced but never declared (runtime errors if reached)

`AFC_hub_input_number` (startup_check), `AFC_startup_check` & `Macine_startup_check` (root daemon.g), `Cancelled` (start_after_delay, guarded by exists()).
