# Macro reference

One entry per file. Format: **purpose** · params · called by · calls · globals written · hardware side-effects · known issues (IDs in [../AUDIT.md](../AUDIT.md)).
Paths are repo paths; on the printer `sys/` = `0:/sys/`, `macros/` = `0:/macros/`.

---

## A. Boot & configuration

### `sys/AFC/AFC.g`
Boot entry (end of config.g). Loads defaults once (`AFC_settings_loaded` guard), user overrides, motor/trigger setup, tool creation, binds the extruder input switch (`M950 J` + `M574 E` for every extruder, when `Machine_features[8]==1`), LEDs, restores status & spools (migrating an old `spool_status.g`, P2-10), paints LEDs, sets `AFC_boot_check_pending`, runs config_check.
Calls: gather_machine_info, AFC_Units_Setup, Machine_Vars_Setup, `<u>/AFC_user_vars.g A<u>`, `Machine/Machine_user_vars.g`, AFC_setup `A<u>`, calculate_tools, `M950 E` per LED port, `Status/status.g`, `Status/spool_status.g`, spool_read_all, spool_save_status (migration only), leds, config_check.
B14 fixed (P2-07): `AFC_lanes[..][4]` is `{type, colour}` everywhere; the old `[4][1]=[4][0]` loop is gone.

### `sys/AFC/AFC_Unit_Count.g` / `.example`
User file: `AFC_unit_CAN_ids`, `AFC_unit_total_lanes`. Copy the `.example` and edit it. The real `AFC_Unit_Count.g` is no longer tracked and is in `.gitignore` together with `*/AFC_user_vars.g`, `Machine/Machine_user_vars.g` and `Status/` (B52, fixed P1-06).

### `sys/AFC/AFC_Units_Setup.g`
Release defaults. Builds every `AFC_*` array (GLOBALS §1-5,8), numbering for triggers/inputs (HARDWARE_RESOURCES §2), pin strings, `M291_data`, spool arrays, `AFC_f_axis`, `AFC_head_extruder`, `AFC_loaded_tool`, `AFC_boot_check_pending`. Sets `AFC_debug=false`, `AFC_time=0`. `AFC_hub_load_distance` default is `{45,5}` (B46 fixed P2-04).
Issues: B35 (`AFC_dcm_out_no`).

### `sys/AFC/Machine_Vars_Setup.g`
Release defaults for `Machine_*`, `Gcode_*`; builds `Machine_features` from local vars; detects `Machine_axis_number` from `move.axes[].letter`. Contains commented-out `Machine_extruder` block.

### `sys/AFC/0/AFC_user_vars-*.example` (AFC-Lite, Longboi)
Per-unit override template, called with `A<u>`. `set` lines override whole per-unit entries; `var` arrays (driver_number, step_dir, microsteps, spm, current, jerk, max_speed, acc, SLP_pins, DC1/DC2_pins, p_s+p_s_p, l_s+l_s_p, turtleneck_switches+tn_s_p, hub_switch+h_s_p, neopixel_*) are merged lane-by-lane by the trailing block using `exists(var.x[i])`. Longboi example sets `AFC_mainboard=1`, its own switch map and 2 LED ports (12 LEDs, 6 per lane, port 0 reversed).
Issues: commented example trigger/J numbers (`{10,11}`, `{8,9}`, hub 10) don't match the auto-allocation (6,7 / 4,5 / 6 for one 4-lane unit) – B53.

### `sys/AFC/Machine/Machine_user_vars.example`
Printer override template; every line is active (copying it overrides all defaults). `initial_unload` is 0 (B51 fixed P1-06); `Machine_om_axis_number` is gone (the `'f` axis index is detected at run time).

### `sys/AFC/Macros/gather_machine_info.g`
Snapshots `tools[]` (extruders, fans, heaters, **axis mapping, offsets**) → `Machine_actual_tools`, `move.extruders[]` → `Machine_extruder_info`. Runs once (guarded by AFC.g), before calculate_tools redefines tools 0..N-1. Note OM units: extruder jerk/speed in **mm/s**.

### `sys/AFC/Macros/AFC_setup.g` (A = unit)
Per lane: `M569 P<driver> S<dir>`; `M950 J<laneJ> C<prep pin>`; `M581 P<laneJ> R2 T<laneTrigger> S1` (R2 = only when **not** printing; comment says "rising edge" – wrong).
Note: only direction is set; current/microstepping are applied later per use.

### `sys/AFC/Macros/calculate_tools.g`
Rewritten in P2-06 (ARCHITECTURE §1.2). 1. Finds the printer tools that have AFC units (`tool_and_motion[u][0]`, order of first use) and gives each its own AFC extruder (`AFC_head_extruder[printerTool]`, appended after the printer's extruders; `multiple_tools` = more than one head). 2. Builds the E arrays (printer extruders from `Machine_extruder_info`, jerk/speed ×60; AFC extruders from the first unit of each head, lane 0) and applies `M584/M350/M92/M906/M566/M203/M201 E…`, `M83`. 3. For every lane: `M563 P<t> D<printer tool's extruders…, head AFC ext> H F X Y` (heater, fans and **axis mapping of the printer tool**), `G10 P<t> X Y Z` (**its offsets**), `G10 P<t> R0 S0`.
Fixes B06, B18/B19 (no `extra_to_add`, no second `var D`), B56. Arrays are filled by index (pre-sized with `vector`) instead of `^` so the driver ids keep their OM type (hardware check).

### `sys/AFC/Macros/extruder_setup.g` (A = tool, B = 1 map / 0 unmap)
B1: rebuild the full E list (`M584 E` always needs all extruders): the AFC extruder of the tool's head (`AFC_head_extruder[tool_and_motion[u][0]]`) gets the lane's driver and params, every other extruder keeps what the object model reports now (jerk/speed ×60); then `M567 P<t> E<1 per drive>`. B0: `M567 P<t>` with the AFC extruder (the tool's last drive) at 0, `M83`.
Called by: load_with_* (B1), tool_load_no_files (B1), tfree (B0). Errors → afc_error (never abort). Fixes B06, B18.

### `sys/AFC/Macros/axis_setup.g` (A = tool)
`M584 'f<driver>`, `M350/M92/M906/M566/M203/M201 'f…`, `M208 'f<min> s1`, `M208 'f<max> s0`; leaves `'f` hidden (it starts and ends with the `M584 P` unhide/hide pair). Normally called through lane_motion_begin.g. Missing A → afc_error. Commented-out `'e` axis variant for motion system 1.

### `sys/AFC/Macros/tool_load_no_files.g` (A = tool)
Restores lane→extruder mapping for a tool that was selected without tpre/tpost (`T<n> P0`). Called by boot_check.g (and by an old-format `status.g`). `var tool_number = param.A` is declared (B02, fixed P1-02); a missing A ends the macro with `M99`.

### `sys/AFC/Macros/afc_error.g` (S message, T lane tool, Q1 = pause, F1 = tool change failed) – P2-01
(`T` is the *native* tool number of the lane, i.e. lane identity, not a remapped tool. Each call also increments `AFC_error_count`, so a caller that ran a nested step can tell whether it failed, and writes the message to the AFC log.)
The one error exit. Never aborts. With T: stops the lane's DC motor, frees the unit's hub J, LED red. Always: lane_motion_end (frees the `'f` endstop, hides `'f`, re-arms Longboi triggers), leds, `M118 "AFC error: …"`. F1 sets `Machine_tpre_failed` (so the rest of the tool change skips). Q1 during a print (the flag is `Q`, not `P`: `M98` uses `P` for the file name, so a `P` parameter is never passed on): `M226` on the job channel (deferred until the tool-change macros return) / `M25` on other channels. Finally an `M291 S1 T0` box. Callers do their own cleanup of pins they bound, call this, then `M99`.

### `sys/AFC/Macros/lane_motion_begin.g` (A = tool) / `lane_motion_end.g` (A = tool, optional) – P2-02
begin: axis_setup, `M584 P{#move.axes}` (unhide `'f`), Longboi: `M581 R-1` + `M950 J C"nil"` for the unit's lane triggers, sets `AFC_f_axis` by searching `move.axes[].letter == "f"`. end: if `'f` is visible `M574 'f1 P"nil" S1` (frees any `'f` endstop, one per axis) and `M584 P{#move.axes-1}`; re-arms the Longboi triggers (the tool's unit, or every Longboi unit without A). Every exit path of a macro that called begin must call end (afc_error does).
Used by: tpre, tfree, triggers, unload, Lane - Measure First / Main Length / Unload to Hub.

### `sys/AFC/Macros/config_check.g` – P2-04
Last step of AFC.g. One `M118 "AFC config: …"` per problem and one non-blocking summary box. Checks: enabled feature positions not -1 and inside the X/Y limits (brush, cut, kick, park, poop); extruder switch for load method 2 / initial unload 1; `hub_load_distance[0] > hub_retract_distance`; loaded lanes measured (`[1]>0`, `[2]>[1]`); driver ids keep the `+0.0001` float offset (B55); unit CAN ids present in `boards[]`; `tool_and_motion[u][0]` is a printer tool; motion system ≠ 0 (unsupported).

### `sys/AFC/Macros/boot_check.g` – P2-11
Run once by `sys/daemon.g` (≥10 s after boot, no job running) while `AFC_boot_check_pending`. Reads every hub switch. If `AFC_loaded_tool` ≠ -1 (or an old status.g reselected a tool): dialog **Keep it loaded** (`T<n> P0` + tool_load_no_files) / **Unload it now** (same, then `T-1`) / **Leave it** (`AFC_loaded_tool=-1`, LED yellow). If only a hub is occupied: offer `Lane - Unload to Hub`.

## B. Tool change

### `sys/AFC/Macros/tpre.g` (A = tool) – see ARCHITECTURE §4.2
Writes: `AFC_time`, `AFC_LED_array`, `Machine_tpre_failed`. Pins: hub switch mapped/unmapped as `J<hubJ>`. Calls lane_motion_begin/end, debug, load_with_*, afc_error.
Skips itself when `Machine_tpre_failed` is set (tfree failed). Lane not loaded → afc_error (B15 fixed); hub occupied / hub not reached → afc_error; load macro failure → returns without touching `'f` (afc_error already cleaned up). B44 fixed: no `abort`.

### `sys/AFC/Macros/load_with_turtleneck.g` (A = tool) – load method 0
`M574 'f2 P<TN advance> S1`; `G1 H4 'f<[2]+100>` (the full `AFC_max_min_axes[1]` only if the lane is unmeasured) at load speed; **verifies `sensors.endstops[AFC_f_axis].triggered`**; `G91 G1 H2 'f-tn_retract`; clear endstop; extruder_setup B1. B16 fixed (P2-03).

### `sys/AFC/Macros/load_with_length.g` (A = tool) – load method 1
`G1 'f{AFC_lanes[u][l][2]}` absolute at load speed (afc_error if `[2]` is 0); extruder_setup B1.

### `sys/AFC/Macros/load_with_preload.g` (A = tool) – load method 2
afc_error if `Machine_extruder_switches[0]` is `"nil"`; `M574 'f2 P<switch> S1`; bounded `G1 H4` + trigger verification; clear; extruder_setup B1. B16 fixed (P2-03).

### `sys/AFC/Macros/tpost.g` (A = tool, B1 = skip heat) – see ARCHITECTURE §4.3
Writes: `AFC_LED_array`, `spool_tracking[u][l][1]`, `spool_extrusion_baseline`, `spool_unsaved_extrusion`, `Machine_tpre_failed`. Pins: TN switches → buffer J inputs + `M581 R1 S1` **and `S0`** triggers (both edges, B38); `M591 P1 D<the tool's last drive>` with the lane load switch (B32).
A failed earlier step (`Machine_tpre_failed`): clears it, tool to standby, message, `M99` (no `T`, no abort). Spool baseline is snapshotted after `G92 E0` and *before* the prime so prime/poop filament is counted (B30). Prime = fast to `distance-10`, last 10 mm at `AFC_load_retract_speed[u][2]` (B47). purge.g only runs with park/poop enabled. Last move: `G1 R2 X0 Y0 Z5` then `G1 R2 Z0` (B07). Open: B48.

### `sys/AFC/Macros/tfree.g` (A = tool or current, B1 = DC assist, C = skip XYZ moves) – see ARCHITECTURE §4.1
Writes: spool data, `AFC_LED_array`, `Machine_last_tool`, `Machine_tpre_failed` (cleared at start; set by afc_error F when a tool is loaded afterwards). Pins: unmaps buffer J/triggers; `'f` endstops on the hub switch via lane_motion_begin/end. Heats from the *actual* nozzle temperature to the lane temp (B31). Initial unload 1: one `G1 H1 E-x` to the extruder input switch bound at boot to every extruder (`J = AFC_unload_input_numbers[0]`, `M574 E<i> P<J>` for each, so a mixing tool's AFC extruder does not fall back to stall detection), then verifies the switch is clear (B17). Hub unload bounded to `[2]-[1]+100` mm with trigger verification; method 1 re-references the hub and backs off `hub_retract_distance` (B49). Monitor removed from the tool's last drive (B32). Needs hardware check: `G1 H1 E` on a mixing tool.

### `sys/AFC/Macros/set_temp_global.g` (A = tool, B = temp)
Sets `AFC_extruder_temp[u][l]` for tool A (resolved through the tool map) to B and, with the optional C, `Machine_slicer_purge` (the slicer's purge length in mm for this tool change); M118 + `M99` if A/B are missing or A is not an AFC tool (B04, fixed P1-08). The slicer calls it as `M98 P"0:/sys/AFC/Macros/set_temp_global.g" A.. B.. [C..]`.

## C. Toolhead operations

### `cut.g`
Rewritten (P2-01, P4-04). Validates direction and that run-up/cut end/pin position are inside the axis limits **before** any state change (afc_error F1 + `M99`, no abort mid-move). Lift Z5 & retract 1; optional pre-retract (+quick tip); run-up position; optional current boost; one loop of `Machine_cut_move[6]` passes (the last one rips); restore currents; optional pushback; restores pressure advance from `move.extruders[e].pressAdv.k0/k1/d` (`M572 D<e> S<k0>[,<k1>] L<d>`). B26 fixed.

### `park.g` (A = 1 from tpost, 0 from tfree)
If A=1 and `Machine_brush[15]`: brush_safe_deploy. Home if needed; Z to max(park Z, current); XY to park.
Issues: param.A unchecked; defaults -1 not validated (B41).

### `poop.g`
Fan to configured speed; M220 100; purge length = the slicer's value (`Machine_slicer_purge`, set by `set_temp_global.g C`) × `Machine_purge_length_modifier` + `Machine_purge_length_addition`, else `purge_length[0]`; at least `[1]`; **plus the old filament stub (cutter→nozzle minus the pre-cut retract) when the cutter is on** (B48, P3-05); XY to purge location (no Z-lift first); segmented E+Z blob loop (40 mm segments, 3 steps per blob, triangular Z taper; F computed in mm/min – correct despite the "seconds" comment); fast Z lift; restore fan/M220.
Issues: modifier/addition/restore unused, no slicer purge volume (G06), first-tool fan hard-coded `tools[0].fans[0]`.

### `kick.g`
Validates the configuration first (afc_error F1). Z to `kick[2]` (approach), XY to kick start, drop to `kick[3]`, optional `M204` with `kick[5]` (restored afterwards), sweep `kick[7]` mm, raise to `kick[8]`. B21 fixed (P2-08).

### `purge.g`
A = 1 only when park or poop ran for this tool change (otherwise it skips with a message), B = tool. Extrudes `Machine_extruder_measurements[2]` at that unit's `AFC_load_retract_speed[u][2]`. The brush servo code is gone (B22 fixed P2-08).

### `brush.g`
Optional Z raise, deploy (custom `brush_deploy.g` or servo via M950 S/M280), centre, Y passes (optional), X passes, return to entry XY, retract, optional brush_safe_retract.

### `brush_deploy.g`, `brush_retract.g`, `brush_safe_deploy.g`, `brush_safe_retract.g`
Shipped as **`.g.example`** (author's machine: U-axis 59.5/1, `G1 X115 Y200`). Copy to `.g` in `sys/AFC/Macros/` and edit; brush.g only calls them if they exist. `brush_safe_*` use `Machine_brush[18]` for Z (B23 fixed P2-08).

## D. Lane mechanics & state

### `triggers.g` (A = tool) – prep-switch auto load (ARCHITECTURE §5)
Rewritten on lane_motion_begin/end: load switch as `'f1`; if the filament is already on the switch the lane is marked loaded too; otherwise a bounded `G1 H1 'f300` at the configured load speed; a message when the switch is not reached; parks at `[1]`. B33/B34 fixed.

### `unload.g` (A = tool, B documented but ignored)
Full unload lane → spool (idle only): refuses when the tool is the current tool (B36); lane_motion_begin; `M574 'f1` inverted load switch, `G92 'f{[2]+50}`, optional DC reverse, `H4 'f0` until load switch opens, 120 mm more; verify via `sensors.endstops[AFC_f_axis]`; one loop with 5 retries; on success mark empty, `Spool - Unassign`, LED red, type "None", save_status; lane_motion_end. Issues: B37; depends on user macro `0:/macros/Spool - Unassign`.

### `dc_motors.g` (A = "F"/"R"/"O", B = tool)
F/R/O: `M950 P0/1/2` = SLP/DC1/DC2 pins (also for O, so `M42` never hits an unassigned pin), `M42` levels. O: all low, free pins. Full power only (no PWM). Issues: B35.

### `leds.g` – P3-07 (rewritten)
For each unit/port: `floor(LEDs/perLane)` lane segments in lane order (reverse order when the port is reversed, ports continue each other), colour from `AFC_LED_array` (0 red, 1 green **or the lane's `AFC_lane_hex`**, 2 blue, 3 white, 4 yellow, 5 magenta, 6 cyan, else off), **one `M150 … S<perLane> F1` per segment** (F0 on the last). B50 fixed; the layout code is shared with `Test - LEDs`.

### `debug.g` (A = message)
`M118` when `global.AFC_debug` (always false, B29). Prefixes "Line Number " to every message.

### `step_through_macro.g` (A = line)
M291 pause if `Machine_step_through_macro`. No callers.

### `startup_check.g` – P3-02 (rewritten)
Run by `sys/daemon.g` right after boot_check.g when `Machine_features[6]` is on. Per lane (except the current tool's): compares the load switch (the hub J is borrowed to read it) with `AFC_lanes[u][l][0]` and corrects the record; probes a loaded, measured lane (hub empty) with a bounded `H4` to the hub switch and backs off to park. One summary box. B11 fixed.

### `filament-error.g` (D = extruder) – P3-01/P3-04 (rewritten)
Run by the generated `0:/sys/filament-error.g` when the AFC extruder's filament monitor fires. Only during a print, only for the current AFC tool. `M25` + wait for `paused`; `T-1` (checked through `AFC_error_count`); marks the lane empty (LED red, spool unassigned, status saved); **infinite spool**: if `AFC_lane_backup[u][l]` names a loaded lane, `tool_map_swap.g` makes the same T number use it; otherwise a menu (J2/`result`): *Reload this lane* (up to 3 tries; detects the new filament by reading the prep switch, then `triggers.g`), *Use another lane* (swap), *Leave it paused*. Then `T<n>` (normal tpre/tpost) and `M24`. B09/B10 fixed. Needs a `resume.g` that returns the head to the pause position.

### `tool_map_swap.g` (A = RRF tool, B = native tool of the target lane) – P3-03
Maps tool A to the lane of tool B; the tool that used that lane gets A's old lane (permutation). Both lanes must feed the same head (`tool_and_motion[u][0]`); neither tool may be the current tool. Failures → afc_error. Saves the status.

### `buffer_mix.g` (A = tool, B = factor) – P3-06
`M567 P<tool> E<ratios>` with 1 for every drive and B for the tool's last drive (the AFC extruder). Called by the generated buffer trigger files.

### `hex_to_rgb.g` (A = "#RRGGBB") – P3-07
Sets `AFC_rgb = [r,g,b]` or `[-1,-1,-1]` (uses `find`/`take`/`drop`).

### `validate_job.g` (L optional) – P3-08
Called by start_print.g. Used tools come from `job.file.filament[t] > 0` (slicer header) or the optional `L"1011"` string. Each used tool's lane (tool map) must be loaded and measured and, with spool tracking, have more spool left than the job needs. One dialog; Cancel sets `Machine_cancelled` and start_print stops the print.

### `tip_form.g` (A = tool) – P3-09
Used by tfree when `Machine_tip_forming` is on and the cutter is off: ramming, optional temperature drop, fast + slow pull-out, cooling moves, optional skinny dip; sets `AFC_tip_retracted` so tfree retracts only the rest.

### `afc_log.g` (S message) – P3-10
Appends a time-stamped line to `0:/sys/AFC/Status/afc.log` when `Machine_log` is true (AFC.g keeps the previous file as `afc.old.log`). Called by afc_error, tpost, tfree.

## E. Persistence

### `save_status.g` (A present = called from tfree, suppresses tool line)
Rewrites `Status/status.g` (lanes, LED array, `set global.AFC_loaded_tool = <n>`), then spool_save_status. It no longer writes `T<n> P0` / tool_load_no_files (D3: nothing is reselected silently; boot_check.g asks). While `AFC_boot_check_pending` the value restored at boot is kept.

### `spool_save_status.g`
Rewrites `Status/spool_status.g` with `set global.spool_tracking[u][l] = {id, flag}`.

### `spool_read_all.g`
For assigned lanes, executes `0:/spools/<id>.g` into `spool_load_temp`, copies 12 fields to `spool_active_data`, syncs `AFC_lanes[..][4]`.

### `spool_write.g` (U = unit, L = lane)
Serialises `spool_active_data[u][l]` to `0:/spools/<id>.g` (JSON comment + `set global.spool_load_temp = {…}`) and syncs `AFC_lanes[..][4]`. Missing params / no spool → message and `M99` (it runs inside tool changes, so it never aborts). Strings containing `"` would break the file.

### `sys/daemon.g` (repo **sys/**daemon.g)
Every ~10 s: (1) once after boot, runs boot_check.g (see above); (2) if spool tracking and a tool is active, deduct extrusion beyond the **high-water mark** `spool_extrusion_baseline` (retract + un-retract is not counted; a jump of more than 50 mm back = `G92 E0`, restart without deducting), update first/last-used dates, flush to SD each 1000 mm. B13 fixed.

### `daemon.g` (repo root) – **deleted** (dead duplicate with typos, B12 fixed in P3-02).

## F. Print workflow (`sys/`)

### `start_print.g` (A bed, B type, C hotend, D nozzle, E/F/H/J first-layer bbox – unused, K initial tool, L optional used-tools string)
Resets `Machine_cancelled`, runs validate_job.g (P3-08), nozzle check (abort), M190 bed (override aware), soak via start_after_delay for listed types, home, sets `AFC_extruder_temp[u][l]` through the tool map (B04), `T<K>`, M568/M116.

### `start_after_delay.g` (S minutes, H hours, R datetime, X test loops)
Third-party countdown/soak macro. Cancel flag mismatch (B39).

### `stop.g`
All fans off, reset factors, retract 5, raise Z, XY to `Machine_park` (only when park is enabled), `T-1` (→ tfree full unload, skipped when `Machine_unload_on_cancel` is false), all tools off, M18, reset overrides and `AFC_extruder_temp`. B40 fixed (P3-10).

## G. User macros (`macros/`)
Unless noted: `A` = tool number (btncmd passes lane index, which equals tool only for unit 0); with no A the macro asks for unit (if >1) then lane via `M291 S4 K{M291_data…}`.

| Macro | What it does | Calls | Issues |
|---|---|---|---|
| Create System Files | Menu: generates `tpre.g`, `tpost.g`, `tfree.g` (checks `AFC_features` through `Tool_to_AFC[currentTool]`, B01), lane `trigger<N>.g`, buffer `trigger<N>.g` (**both edges**: M567 0.95/1.05 while the switch is active, 1.0 when released, B38), `home'f.g`, **`0:/sys/filament-error.g`** (B09), plus the buffer fault and low-spool trigger files; renames `tpre0/tpost0/tfree0.g` to `.unused`; (the `0:/spools` folder is created by the first spool file written) | – | B09 |
| Lane - Mark Loaded | set `[0]=true`, LED green, save | leds, save_status | prompts say "Empty" (copy/paste) |
| Lane - Mark Unloaded | set `[0]=false`, unassign spool, LED red, save | Spool - Unassign, leds, save_status | |
| Lane - Measure First | home back to load switch (=0, verified), forward to hub (verified, max 300 mm), back off, store `[1]` | lane_motion_begin/end, dc_motors, save_status, afc_error | B24, B34 fixed |
| Lane - Measure Main Length | from park to TN (method 0/1) or extruder switch (2) (bounded, trigger verified); offset applied to all lanes of unit → `[2]`; retract to park. Method 1 can also take the length typed in (`M291 S6`); method 2 refuses without `Machine_extruder_switches[0]` | lane_motion_begin/end, dc_motors, save_status, afc_error | B25 fixed |
| Lane - Report First / Main Lengths | M291 list of `[1]` / `[2]` | – | |
| Lane - Reset First Length | zero `[1]` for a lane or all | save_status | |
| Lane - Map Tool | menu / A,B,C: tool → lane (swap), show, reset (P3-03) | tool_map_swap, save_status | |
| Lane - Set Backup | menu / A,B: infinite-spool backup lane of a lane (P3-04) | save_status | |
| Lane - Set Filament | type, colour name, `#RRGGBB`, temperature of a lane without a spool record (P3-07) | hex_to_rgb, leds, save_status | |
| Lane - Park | re-park one lane or every lane whose prep switch sees filament (P3-10, G11) | triggers | |
| Lane - Unload | unload.g for lane or all | unload | B36 |
| Lane - Unload to Hub | retract from hub to hub_retract behind it (hub clear verified); lane stays loaded | lane_motion_begin/end, dc_motors, leds, save_status, afc_error | |
| Spool - Create | prompts id(0-99)/type/colour/manuf/hex/length/density; writes `0:/spools/<id>.g` | – | |
| Spool - Assign to Lane (A unit, B lane) | requires lane loaded; id not already used; load file → `spool_active_data`; set `spool_tracking`; syncs `AFC_lanes[..][4]` | spool file, save_status | B03, B42 fixed |
| Spool - Unassign (A unit, B lane = silent) | clear spool data, `[4]` = None, spool_tracking id -1 | save_status | writes the last remaining length with `spool_write.g` first, then resets to `spool_empty_record` (B03, fixed P1-03) |
| Spool - Delete | refuse if assigned; `M30` | – | |
| Spool - Inventory | execute each spool file, M118 details | – | |
| Spool - Report | per-lane active spool summary (M291 list) | – | |
| Test - DC Motor | timed/continuous F/R/both per lane or all | dc_motors | |
| Test - Hub Switch | interactive empty/present check | – | |
| Test - LEDs | 4 test modes (selected lane / all lanes cycle the status colours, lane sequence, colours per lane) through `AFC_LED_array` + leds.g, state restored afterwards | leds | |
| Test - Turtleneck | interactive advance/trail check | – | |

## H. Other repo files
* `btncmd.json` – BtnCmd (DWC plugin) layout "BoxTurtle 1": per lane Unload / Mark Unloaded / Measure buttons (`M98 P"0:/macros/Lane - …" A<lane>`), Measure Main Length, `AFC_lanes[0][l][0]` displays and `[4][0]` type selectors (from `filamentList.json`, not in repo). Unit 0 / 4 lanes only.
* `README.md`, `DOCUMENTATION.md` – user docs; several inaccuracies (AUDIT §5).
