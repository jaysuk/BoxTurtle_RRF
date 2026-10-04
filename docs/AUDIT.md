# BoxTurtle_RRF – Macro Audit (RRF only)

Baseline: branch `Next` @ `cb3c7ad`, audited 2026-10-04. Every file in `sys/`, `macros/`, root `daemon.g` and
`btncmd.json` was read. Architecture and references: [maintainers/](maintainers/). A Klipper comparison is a separate,
later pass.

**Status column:** `open` until fixed; when fixing, change it to `fixed <commit>` so this list stays the single tracker.
**Verification (2026-10-04):** every RRF-behaviour claim was checked against RRF source (`3.7-dev` @ `72032c5`), the
Duet wiki (`wiki-content`) and dwc-gcode-core 1.36.0 – see [maintainers/RRF_NOTES.md](maintainers/RRF_NOTES.md) for the
citations and §6 below for the outcome. The implementation plan is [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).
Lint baseline at audit time: `docs/maintainers/tools/lint.mjs` → 49 findings / 34 errors, all listed here. **After the implementation pass (IMPLEMENTATION_PLAN Phases 1-5): 0 findings, `check_locals.py` 0 – the remaining work is hardware verification (see §7).**

## 0. Fix-first shortlist

| # | ID | Why first |
|---|---|---|
| 1 | B01 | Generated `tfree.g` errors on every tool change |
| 2 | B06 | Printer's own extruder jerk & max speed set 60× too low at boot and on every load |
| 3 | B02 | Boot error whenever the printer was shut down with a tool loaded |
| 4 | B03 | Spool unassign corrupts the record shape → next assign/write errors |
| 5 | B51 / B52 | Copying the shipped example/dev configs breaks unload / declares 3 units |
| 6 | B05 | Spool tracking indexes arrays sized for the printer's original tool count |
| 7 | B44 | Any `abort` in a tool-change macro during a print cancels the whole print (verified in source) |
| 8 | B07 | tpost leaves the nozzle 5 mm high unless the slicer re-sends Z |
| 9 | B04 | Per-lane temperatures from the slicer never work (and can corrupt state) |
| 10 | B09/B10 | Runout handling is not wired and its logic loads the wrong lane |

---

## 1. Bugs

### 1.1 Critical

| ID | Location | Problem | Impact | Suggested fix | Status |
|---|---|---|---|---|---|
| B01 | `macros/Create System Files:41` | Generated `0:/sys/tfree.g` contains `if global.AFC_features[var.unit_number][0]` – `var.unit_number` does not exist when tfree.g runs. | "unknown variable" error on every tool unload (tool change / T-1 / stop.g). | Emit `if global.AFC_features[global.Tool_to_AFC[state.currentTool][0]][0]`. | fixed (P1-01) |
| B02 | `sys/AFC/Macros/tool_load_no_files.g:6-13`; written by `save_status.g:34-36` | Uses `var.tool_number` but never declares it (only `param.A` checked). status.g contains `T<n> P0` + this call whenever a tool was loaded. | Error during boot (inside config.g → AFC.g → status.g); lane→extruder mapping not restored; tool selected at boot without verification. | `var tool_number = param.A`. Also reconsider auto-reselecting a tool at boot without checking the hub/toolhead (G04). | fixed (P1-02) |
| B03 | `macros/Spool - Unassign:44` | Resets `spool_active_data[u][l]` to a **9**-element array; schema is 12. | `Spool - Assign to Lane:93-95` (`[9]..[11]`) and `spool_write.g:37-39` → index out of range. Unassign is auto-called by `unload.g`, `Lane - Mark Unloaded`, `startup_check`. | Reset to the full 12-element default (better: a single `global.spool_empty_record`). | fixed (P1-03) |
| B05 | `sys/AFC/AFC_Units_Setup.g:341,344` vs `AFC.g:13,34` | `spool_extrusion_baseline`/`spool_unsaved_extrusion` = `vector(#tools, …)` evaluated **before** `calculate_tools.g` creates one tool per lane. | With spool tracking on, `tpost.g:103`, `tfree.g:54`, `sys/daemon.g:20` index out of range for any tool ≥ printer's original tool count. | Size by `global.AFC_unit_total_available_lanes` (or create after calculate_tools). | fixed (P1-04) |
| B06 | `calculate_tools.g:59-75,103-107`; `extruder_setup.g:49-65,93-107,116-123` | Printer extruder params are read from the OM (`jerk`, `speed` in **mm/s**) and re-applied with `M566`/`M203` (expect **mm/min**). AFC lane values are correctly ×60. Interpolation flag is also dropped from `M350`. | Printer's own extruder(s) end up with jerk and max speed 1/60th of configured, at boot and every lane load: slow retractions, capped volumetric flow. | Multiply OM jerk/speed by 60 when re-applying (or avoid re-issuing params for untouched extruders: only `M584 E` remap + set params for the AFC extruder index). | fixed (P1-05) |
| B08 | `tfree.g:170-175` | ~~Unload method 1 binds `M574 'f2 … P<hub>` but clears `M574 'f1 P"nil"`, leaving the pin bound.~~ **Not a bug:** RRF keeps one endstop object per axis and any `M574 'f… P` replaces it (EndstopsManager::HandleM574), so the pin is released. Cosmetic only – use `'f2` for consistency. | none | Optional tidy-up. | invalid (verified in source) |
| B51 | `sys/AFC/Machine/Machine_user_vars.example` (`var initial_unload = 1`, `Machine_extruder_switches = "nil"`) → `tfree.g:125-129` | Example enables initial-unload-to-switch but leaves the switch unset. | `M950 J… C"!nil"` error, then `sensors.gpIn[...]` null → tfree fails for anyone who copies the example. | Default example to `initial_unload = 0`; validate switch ≠ "nil" when 1. | fixed (P1-06) |
| B52 | `sys/AFC/AFC_Unit_Count.g` (tracked) | Repo ships a developer config `{119,120,121}` / `{4,4,2}`; docs say copy the `.example`. | Users who copy `sys/` get 3 units → CAN timeouts/errors for absent boards. | Delete from repo; `.gitignore` user files (`AFC_Unit_Count.g`, `*/AFC_user_vars.g`, `Machine_user_vars.g`, `Status/`). | fixed (P1-06) |
### 1.2 High

| ID | Location | Problem | Impact | Suggested fix | Status |
|---|---|---|---|---|---|
| B04 | `set_temp_global.g:1`; `README.md:66`, `DOCUMENTATION.md:478`; `start_print.g:52` | (a) `set global.AFC_extruder_temp[param.A] = param.B` writes a scalar into the unit row (tool used as unit index). (b) README path `0:/sys/AFC/set_temp_global.g` doesn't exist (file is in `Macros/`). (c) start_print indexes `[unit][tool]` instead of `[unit][lane]`. | Slicer per-lane temps never apply (always 220 °C or first-tool temp); if the path were fixed, tpre/tpost would error indexing a number; multi-unit → index out of range at print start. | `set global.AFC_extruder_temp[global.Tool_to_AFC[param.A][0]][global.Tool_to_AFC[param.A][1]] = param.B`; fix README path; start_print use lane index. | fixed (P1-08) |
| B07 | `tpost.g:113` | `G1 R2 X0 Y0 Z5` – never returns to R2 Z. RRF ≥3.4 no longer restores position after tool change. | Prints resume 5 mm high unless the slicer emits Z after the change. | Append `G1 R2 Z0 F…` (Duet's recommended pattern). | fixed (P1-07) |
| B09 | `Create System Files:105-119`; `sys/AFC/Macros/filament-error.g` | RRF ≥3.4 only runs `0:/sys/filament-error.g` (no extruder suffix, no automatic pause). Generator writes `filament-error<N>.g`; handler lives in `sys/AFC/Macros/`. | AFC runout handler never runs; RRF just pauses. Feature advertised as "untested" is actually disconnected. | Generate `0:/sys/filament-error.g` forwarding to the AFC handler; handler must pause itself (`M25`). | fixed (P3-01) |
| B10 | `filament-error.g` | Treats `param.D` (extruder number – always the AFC extruder) as tool (L12); `&&` should be `||` (L42); uses failed lane instead of `curLane` (L45,48); hand-rolled tool-index `countdown` loops wrong for unit ≥2 (L47-51, 69-73, 93-97, 117-121); passes lane index instead of tool to tpre/tpost (L100-101, 124-125); string concat outside braces in `M291 R"…"^{…}` (L65, syntax error); no `break` after a swap (L52-55); loads via `M98 tpre/tpost` so RRF's current tool/mixing don't change – old tool has mix `E1:0` from tfree so the new lane motor is never driven; reload check depends on prep trigger which is R2 – **verified: R2 never fires while a job is paused** (PrintMonitor `isPrinting` stays true); menu cancel checks read `input` instead of `result`. | Runout recovery would load the wrong lane, error, or print with an undriven lane. | Rewrite: tool = `state.currentTool`; use `AFC_lane_to_tool`; use real `T<n>` (or remap tool→lane, G03); `M25` pause; poll switches directly. | fixed (P3-01) |
| B12 | root `daemon.g`; `DOCUMENTATION.md:148` | Two daemons. Root one has typos (`Macine_startup_check`, `itertions`, sets undeclared `AFC_startup_check`) so its body never runs; docs tell users to copy it to `0:/sys/daemon.g`, which would replace the spool tracker. | Lost spool tracking / confusion. | Delete root `daemon.g`; merge any needed logic into `sys/daemon.g`. | fixed (P3-02) |
| B13 | `sys/daemon.g:22-25` | Negative diff resets baseline; the following un-retract counts as consumption. | Spool usage over-counted by total un-retract distance (thousands of retracts → metres). | Track a high-water mark: count only `position - maxSeen` when positive; reset only on large negative jumps (G92). | fixed (P2-09) |
| B14 | `AFC.g:60-65`, root `daemon.g:14-15`, `spool_read_all.g:44`, `spool_write.g:56`, `AFC_Units_Setup.g:313` | `AFC_lanes[u][l][4]` is documented/used as `{type, colour}` by spool code but `AFC.g` copies `[4][0]` into `[4][1]` (old "previous type" change-detector). | Colour replaced by type on every boot. | Decide one meaning; if change detection is needed, add a separate field. | fixed (P2-07) |
| B15 | `tpre.g:31,63-100` | If lane not marked loaded, tpre does nothing and exits normally (`warning_text` unused). | tpost primes air; print continues without filament. | `else` → message + `Machine_tpre_failed` + pause. | fixed (P2-01) |
| B16 | `load_with_preload.g:12,16`; `load_with_turtleneck.g:21`; `tfree.g:148-150`; `Lane - Measure Main Length:78,96` | Homing-style moves up to `AFC_max_min_axes[1]` (20 m) with no check that the endstop actually triggered; preload method uses `Machine_extruder_switches[0]` which defaults to `"nil"`. | Lane motor can grind for minutes; wrong lengths saved. | Bound distance to expected length + margin; verify `sensors.endstops[…]`/position after move; validate pins at boot. | fixed (P2-03) |
| B17 | `tfree.g:127-129` | `while switch != 1 { G1 E-5 }` has no iteration cap. | Endless retraction if the switch fails. | Cap at (input→nozzle + margin)/5 iterations, then error. | fixed (P2-03) |
| B20 | `tpost.g:61`, `tfree.g:117,135,136,180`, `startup_check.g:102,106,122,128,178` | Wrong file-name case (`LEDs.g`, `Extruder_setup.g`, `Axis_setup.g`) / wrong folders. | Works on SD (FAT), fails in SBC mode (case-sensitive). | Use exact names. | fixed (P1-09, P3-02) |
| B23 | `brush_deploy.g`, `brush_retract.g`, `brush_safe_deploy.g`, `brush_safe_retract.g`; `brush.g:48,81`; `README.md:22` | Shipped files are the author's machine (U axis 59.5/1, `G1 X115 Y200`). brush.g runs them whenever `Machine_brush[8]` is true; README says to create them in `0:/sys/AFC/` but code looks in `Macros/`. safe_* move Z to `[2]` instead of `[18]`. | Servo-brush users get unexpected U/XY moves or errors. | Ship as `.example`; fix README path; use `[18]`. | fixed (P2-08) |
| B36 | `macros/Lane - Unload:40-49` | No check that the lane is the active tool. | Pulls filament through a loaded extruder. | If `state.currentTool == t` → `T-1` first (or refuse). | fixed (P2-01, in unload.g) |
| B44 | every `abort` in `tpre.g`, `tpost.g`, `tfree.g`, `cut.g`, `kick.g`, `load_with_*`, `extruder_setup.g`, `axis_setup.g` | **Verified:** `abort` → `GCodes::AbortPrint` aborts all nested files and, on the print-file channel (where tool-change macros run during a job), calls `StopPrint` – the print is **cancelled**, not paused. The abort paths also leave `'f` visible, pins/endstops bound, LED blue. | A recoverable failure mid-print destroys the job instead of letting the user fix it and resume. | Central error handler (I07): clean up, `M25` pause when printing, message; reserve `abort` for idle-only macros. | fixed (P2-01) |
| B41 | `park.g:15,32-33`, `poop.g:48`, `kick.g:28-29`, `cut.g:73`, `brush.g:55`; defaults `-1` in `Machine_Vars_Setup.g` | No validation of positions; `park.g` reads `param.A` without `exists`. RRF 3.7 makes unreachable G1 targets an **error** (previously clamped). | Feature enabled with defaults → crash into limits (3.6) or error mid tool-change (3.7). | Boot-time config validation (I05). | fixed (P2-04 config_check; park.g still reads param.A unchecked) |
### 1.3 Medium

| ID | Location | Problem | Suggested fix | Status |
|---|---|---|---|---|
| B11 | `startup_check.g` (whole file); root `daemon.g` | Undeclared `AFC_hub_input_number` (L40…), `var.curLane` (L157); paths `0:/sys/AFC/Motors/…`, `0:/sys/AFC/LEDs.g`; `M291 P"…"^…` outside braces (L58); scalar assigned to vector (L139); `iterations` used for lane in message (L196); only caller is the dead root daemon, which keys it off `Machine_features[7]` (spool tracking) instead of `[6]`. | Rewrite as a boot-time check called from AFC.g (or daemon first run) when `Machine_features[6]`. | fixed (P3-02) |
| B18 | `extruder_setup.g:76-84`, `:14,44-47` | `if !global.multiple_tools` followed by **non-indented** body, then `elif`. **Verified:** single-tool → the `if` is true, lines 77-83 run, `elif` is skipped (works by accident); multi-tool → RRF throws `'elif' did not follow 'if'` (gcode-core lint flags line 84). `var.count` is always 0 so `extra_to_add=1` even for multi-tool, then index `total_extruders+2` is written → out of range. | Indent; compute array with `^` (R02). | fixed (P2-06) |
| B19 | `calculate_tools.g:20-43,94-100,138` | Distinct-tool counting is order-dependent; `var.different_tool` (a tool number) used as a **unit** index into `AFC_steppers`; `var D = {…}:{…}` is not a valid expression; **verified:** re-declaring `var D` (line 138) while the loop-body `var D` (line 122) exists throws `variable 'D' already exists`. | IDEX / multi-tool path is broken – document as unsupported or rewrite. | fixed (P2-06) |
| B21 | `kick.g:33-38` | Drops to `Machine_kick[2]` (approach Z) instead of `[3]` (kick height); `[5]` accel and `[8]` post-kick Z unused. | Use `[3]` for the sweep, `[8]` after; apply `[5]` via M204. | fixed (P2-08) |
| B22 | `purge.g:6,11-23,30` | Contains brush servo deploy code (copy/paste), de-assigns the servo pin while deployed, uses unit 0's speed, extrudes wherever the head is. | Remove brush code; require park/poop location; use current unit's speed. | fixed (P2-08) |
| B24 | `Lane - Measure First:104-111` | "Hit max distance" check runs after the 35 mm back-off, so never true; message uses string concat outside braces. | Check before retract (`machinePosition >= safety_dist - 0.1`) or check endstop. | fixed (P1-09, P2-03) |
| B25 | `Lane - Measure Main Length:70-99,106` | No trigger verification (20 m could be stored); load method 1 (lengths, no sensor) still requires the TN switch; Longboi triggers not disabled during motion. | Verify; allow manual length entry for method 1. | fixed (P2-03) |
| B26 | `cut.g:49,120,26,53,203` | Unbalanced brace `R{"…cut.g" S1` (parse error on invalid-direction path); Y error says "X"; PA captured from obsolete `pressureAdvance` and restored with `M572 D0 S…` (loses 3.7 two-slope PA, hard-coded D0); `Machine_cut_safe_margin`/`_restore_pos` unused. | Fix brace/messages; restore with `pressAdv` k0/k1/d; implement or drop unused settings. | fixed (P1-09, P4-04: pressAdv restored) |
| B30 | `tpost.g:33,101-106` | Baseline snapshotted **before** `G92 E0`; `tpost_start_extrusion` unused; prime/purge consumption never counted. | Do `G92 E0` first (or snapshot after); include purge length in usage. | fixed (P2-09) |
| B31 | `tfree.g:43-45` | Heats only when `nextTool == -1` and uses the *setpoint* (`active[0]`) not actual temp; fixed 220 °C. | Check `heat.heaters[h].current`, use lane temp, always ensure min retract temp. | fixed (P2-09) |
| B32 | `tpost.g:72`, `tfree.g:134` | Monitor created on `tools[t].extruders[1]`, removed with hard-coded `M591 D1`. | Use the same computed index. | fixed (P2-09) |
| B33 | `triggers.g:43-61` | If filament already sits on the load switch, lane is not marked loaded; failed 500 mm search is silent; hard-coded 500 mm / F2100; uses `!==` (verified valid – RRF swallows the extra `=` – but non-idiomatic). | Handle both branches; message on failure; use configured speed; `!=`. | fixed (P2-02) |
| B34 | `triggers.g:43,46`, `unload.g:65,91`, `Lane - Measure First:110,120`, `Measure Main Length:106` | `'f` OM index taken from user-set `Machine_om_axis_number` (default 3, example 4). | Detect at runtime: find `move.axes[i].letter == "f"`. | fixed (P2-02) |
| B35 | `AFC_Units_Setup.g:302`, `dc_motors.g:14-16,32-34` | DC motor outputs default to `M950 P0/P1/P2` – usually already used in config.g; re-binding silently steals them. | Default to high numbers (e.g. 20-22) and document. | mitigated (P3-10: config_check warns when an output is already used; the default numbers are unchanged) |
| B38 | `Create System Files:63-93` | Buffer triggers set mix 0.95/1.05 on rising edges only; never return to 1:1. | Add falling-edge triggers (S0) that restore 1.0, or proportional logic (G08). | fixed (P2-09) |
| B39 | `start_after_delay.g:102`; `start_print.g:37-41` | Checks `global.Cancelled` (never declared) instead of `Machine_cancelled`; over-indented lines after `M291`. | Use `Machine_cancelled`; fix indentation. | fixed (P1-09) |
| B40 | `stop.g:7,17,21` | Hard-coded `M106 P0`, `G1 X60 Y115`, `M568 P0` only. | Use park location / tool fan / all tools. | fixed (P3-10) |
| B46 | `AFC_Units_Setup.g:185-186` | Default `hub_load_distance[0]` (35) equals `hub_retract_distance` (35); comment says it should be 5–10 mm larger. | Default `{45,5}`. | fixed (P2-04) |
| B47 | `tpost.g:45-48` | Prime of up to 125 mm at lane load speed (35 mm/s) straight through a hot nozzle when cut is disabled. | Fast to melt zone, then extruder-limited speed. | fixed (P2-09) |
| B48 | `tpost.g:45-46` + `poop.g:40-43` | With cut enabled, prime only reaches the cutter; the old stub (cutter→nozzle minus retract, ~60 mm) is pushed out first, so a 72 mm poop purges only ~12 mm of new filament. | Define purge as "new filament through nozzle" and add stub length. | fixed (P3-05) |
| B56 | `calculate_tools.g:122-141` | Every AFC tool is created with `G10 P<t> X0 Y0 Z0` and no `X`/`Y` axis mapping, so the printer tool's offsets (`tools[t].offsets`) and IDEX axis mapping (`tools[t].axes`, e.g. U used as X) are lost when the AFC tools replace it. | Copy both from the printer tool the unit feeds (plan P2-06). | fixed (P2-06, needs IDEX hardware check) |
| B49 | `tfree.g:173` vs `Lane - Measure First:105` | Method-1 unload backs off `hub_retract-10`; measurement used full `hub_retract` → park position differs from `[1]`. | Use the same distance. | fixed (P2-09) |
### 1.4 Low / cosmetic

| ID | Location | Problem | Status |
|---|---|---|---|
| B27 | `tfree.g:81` | Homing check tests X twice, never Z. | fixed (P1-09) |
| B28 | `Create System Files:137` | `M47 "0:/spools"` is not an RRF command (`M470 P"0:/spools"`). | fixed (P1-09) |
| B29 | `debug.g:4`, `AFC_Units_Setup.g:384`, `Machine_Vars_Setup.g:20` | debug.g reads `AFC_debug` (hard-coded false); user `Machine_debug` is never read. Messages prefixed "Line Number". | fixed (P5, debug.g reads Machine_debug) |
| B37 | `unload.g:2,37` | `param.B` documented but ignored; `first_length` holds total length. | fixed (P2: unload.g header documents that B is ignored) |
| B42 | `Spool - Assign to Lane:102` | `AFC_lanes[..][4]` sync commented out → type/colour show only after reboot or first spool write. | fixed (P2-07) |
| B43 | `AFC_setup.g:26-28` | Comment says R2 = rising edge; R2 = only when not printing. | fixed (P5) |
| B45 | `tpre.g:3-12`, `tpost.g:9-11`, `tfree.g:5-14`, `triggers.g:6-17`, `unload.g:4-15`, `startup_check.g:7-16`, `Lane - Unload:3-14`; `Lane - Mark Loaded:2,25,39`; `Lane - Measure First:28`, `Report*:37` | Header feature-index lists don't match `Machine_features`; copy/paste prompts ("mark as Empty" in Mark Loaded / Measure First); M291 `F0` comment wrong. | fixed (P5; the stale feature lists and copy/paste prompts were corrected) |
| B50 | `leds.g:104-107` | One `M150` per LED over CAN (24+ commands per refresh on Longboi). | fixed (P3-07) |
| B53 | `AFC_user_vars-*.example:111-135` | Commented example trigger/J numbers don't match the automatic allocation. | fixed (P2-04) |
| B54 | `sys/start_after_delay.g:99` | `M118 S"Print start time is " ^ var.RunTime` – concatenation outside braces; RRF reads the rest as parameters (gcode-core lint: unknown parameters V, A, U, N, I). | fixed (P1-09) |
| B55 | `AFC_Units_Setup.g:115`, user-vars examples:298 | **Keep the `+0.0001`.** RRF rounds `10*x` to the nearest driver (±0.002, so truncation was never the issue), but a number written without a decimal point is an **integer**, and an integer driver id inside an array (`M584 E{array}`) is read as main-board driver *N* (`ConvertToDriverId`: `DriverId(0, n)`) – `119` becomes driver `0.119`. The offset guarantees a float so the `.0` lane survives. Remaining gap: user overrides written as integers (`{0,1,2,3}`) break lanes 1-3 (119+1 = board 120) – document "always write `0.0, 0.1, …`" in the examples and check it in config_check (P2-04). | info |

---

## 2. Improvements (code quality, robustness, maintainability)

| ID | Improvement | Where |
|---|---|---|
| I01 | Replace every hand-rolled "countdown" tool-index loop with `global.AFC_lane_to_tool[u][l]`. | filament-error, startup_check |
| I02 | Precompute an LED→lane map once at boot; leds.g and Test - LEDs use it; batch contiguous LEDs per lane with `M150 … S<count>`. | leds.g, Test - LEDs |
| I03 | `lane_motion_begin.g A<t>` / `lane_motion_end.g`: axis_setup + unhide + Longboi trigger disable, and the inverse (free endstops, hide, re-arm triggers, M18). Removes ~8 copies and guarantees cleanup. | triggers, unload, Measure*, Unload to Hub, tpre, tfree |
| I04 | Auto-detect the `'f` axis index; drop `Machine_om_axis_number`. | B34 sites |
| I05 | `config_check.g` at boot: positions ≠ -1 for enabled features, pins ≠ "nil" for chosen load/unload methods, lengths measured for loaded lanes, unit count vs CAN boards present (`boards[]`), output/J/trigger collisions. | AFC.g |
| I06 | Bound every search move (expected length + margin) and verify the switch state afterwards. | load_with_*, tfree, Measure* |
| I07 | Single `afc_error.g A"<msg>" T<t>`: red LED, free pins/endstops, hide `'f`, `M25` if printing, M291 message. Replace bare `abort`. | all |
| I08 | Move spool unassign logic into `sys/AFC/Macros/spool_unassign.g` (sys code must not depend on `0:/macros/` names with spaces). | unload, Mark Unloaded, startup_check |
| I09 | Spool id index (`0:/spools/index.g` or `global.spool_next_id`) instead of 100 `fileexists()` per menu; allow ids >99. | Spool - * |
| I10 | daemon: high-water-mark accounting (B13), `while true` + `G4 S2` loop for finer tracking, flush on pause/stop. | sys/daemon.g |
| I11 | Rename the "spoolman" globals/flags to `spool_tracking` (no Spoolman integration exists); keep a migration shim for status files. | everywhere |
| I12 | Named index globals for magic indices (e.g. `global.MF_CUT = 1`) or at least one canonical table referenced from every header (remove the wrong copies, B45). | headers |
| I13 | Generated files: write correct tfree (B01), `0:/sys/filament-error.g` (B09), and optionally `pause.g`/`resume.g`/`cancel.g` hooks (G07). | Create System Files |
| I14 | Two-stage prime in tpost (B47); `G1 R2 Z0` finish (B07). | tpost |
| I15 | DC motors: PWM speed (`M950 P… Q<freq>`, `M42 S0.x`), also assist during loading. | dc_motors |
| I16 | Use `M291 … J2` and test **`result == -1`** on the next line (verified: J2 cancel sets `result` = -1, `input` is undefined; J1 cancel ends the macro, so current `if input == -1` checks after J1 are dead code). | all menus |
| I17 | Ship `Machine_user_vars.example` fully commented like the unit example, so copying it overrides nothing by default (B51). | example |
| I18 | Consolidate cut.g: compute direction vector once, final pass = last loop iteration with rip flag; delete the triplicated direction blocks. | cut.g |
| I19 | Remove unused globals/vars (`AFC_current_tool`, `AFC_unload_input_numbers`, `Machine_last_tool`, `Gcode_bed_temp`, `Gcode_hotend_temp`, unused locals) or implement them. | various |
| I20 | Calculate E-driver arrays by concatenation (R02) – removes `extra_to_add`/index arithmetic that caused B18/B19. | calculate_tools, extruder_setup |
| I21 | Avoid re-issuing `M584 E` + all E params on every load; only remap the AFC extruder driver and set its params (also fixes B06 exposure). *(verify M584 E partial remap semantics)* | extruder_setup |

## 3. Missing or incomplete features

**Implementation status (after the plan):** G01 tip forming (P3-09) · G02 runout + infinite spool (P3-01, P3-04) · G03 tool→lane map (P3-03) ·
G04 boot check + startup check (P2-11, P3-02) · G05 pre-print validation (P3-08) · G06 slicer purge length (P3-05) · G07 cancel behaviour
(`Machine_unload_on_cancel`, park position; pause/resume hooks left to the user's pause.g/resume.g) · G08 buffer control (both edges,
fault trigger; P3-06) · G09 lane metadata (`Lane - Set Filament`, LED colours; btncmd still unit 0) · G11 `Lane - Park` (auto-eject not
done) · G13 DC speed/PWM and load assist (the hub-recovery part of G13 is `boot_check`/`Lane - Unload to Hub`) · G14 LED states (red on
error, yellow attention, filament colour) · G15 IDEX stage 1 (one motion system) · G16 `afc.log` · open: G10 weight-based tracking /
Spoolman, G12 jam detection (only the buffer fault trigger), G17 per-filament defaults.

| ID | Gap | Notes |
|---|---|---|
| G01 | **Tip forming** for printers without a cutter | All `Machine_tip_*` settings exist but nothing uses them. README says "highly recommended to run with a cutter". |
| G02 | **Runout + infinite spool** end-to-end | Not wired (B09), broken logic (B10), `AFC_lanes[..][3]` continuous flag has no UI/config. |
| G03 | **Tool → lane remapping** | Tool n is hard-wired to lane n; no way to map slicer T0 to an arbitrary lane or swap lanes for a job. Needed for G02. |
| G04 | **Boot consistency / power-loss recovery** | startup_check broken (B11); status.g tool restore broken (B02); no interplay with `resurrect.g`. |
| G05 | **Pre-print validation** | start_print doesn't check that every tool the job uses has a loaded, measured lane with enough filament (could pass used tools from the slicer or use `job.file.customInfo`, R13). |
| G06 | **Slicer-driven purge volumes** | poop uses a fixed length; `purge_length_modifier/addition` unused; no flush matrix. |
| G07 | **Pause / resume / cancel awareness** | No AFC pause.g/resume.g/cancel.g handling; cancel → stop.g → T-1 full unload. |
| G08 | **Buffer control** | Bang-bang ±5 % mix only while printing, never returns to 1:1 (B38); no TN fault detection (both switches / stuck). |
| G09 | **Lane metadata UI** | No macro to set type/colour/temperature per lane; LED doesn't show filament colour (`hex` stored, unused); btncmd covers unit 0 only and needs `filamentList.json` (not in repo). |
| G10 | **Weight-based spool tracking / Spoolman** | density/empty weight stored but no mm→g conversion; DOCUMENTATION claims a Spoolman server integration that doesn't exist (RRF has no HTTP client; would need an SBC/DSF plugin). |
| G11 | **Lane convenience ops** | "Load all lanes to park", "Unload all", eject when prep switch released, re-park after manual handling. |
| G12 | **Jam/clog detection** during print | Only load-switch runout; no motion monitoring. |
| G13 | **Hub recovery in tpre** | Hub occupied → abort; could identify and retract the offending lane. |
| G14 | **LED states** | No error-red on failure paths, no blinking/attention, no distinct "loaded in toolhead". |
| G15 | **Multi-tool / IDEX / motion systems** | Partially scaffolded (`tool_and_motion`), broken (B19); RRF 3.7 drops multiple motion systems on Duet 3 Mini. |
| G16 | **Event logging** | No `M929`/file log of AFC events for diagnosis. |
| G17 | **Per-filament defaults** | No temperature/purge defaults by filament type when the slicer doesn't supply them. |

## 4. RRF 3.6 / 3.7 features to adopt

**Adopted:** R01/R02 `[ ]` literals everywhere in the macros (the maintained files; user files written in the old style still work), R03 per-lane
persistence with array `echo` (spool files keep their own escaping), R05 `M574 E` (initial unload), R07 `M581.1` (buffer fault, low spool),
R09 limit validation (config_check, cut/kick), R10 `pressAdv`, R11 `move.motionSystems[0]`. Not used: R04, R06, R08, R12-R15 (optional).

**Decided (D1, 2026-10-04): RRF 3.7 is the minimum firmware**, so everything below may be used. Order in IMPLEMENTATION_PLAN.md Phase 4.

| ID | Feature (version) | Use it for | Targets |
|---|---|---|---|
| R01 | `[ ]` array literals; empty `[]`; single `[x]` without trailing comma (3.7) | Remove the "must be followed by a comma" rule from user files; clearer defaults. | AFC_Unit_Count(.example), all user-vars examples, every `{…}` literal |
| R02 | `^` concatenates arrays (3.7) | Build arrays instead of pre-sizing + index arithmetic: `M291_data[2][u] = M291_data[1][u] ^ ["All"]`; E-driver lists `= printerDrivers ^ [laneDriver]`; spool id lists; LED runs. | AFC_Units_Setup, calculate_tools, extruder_setup (fixes B18/B19 class), Spool - * |
| R03 | `echo` writes arrays as `[…]` with quoted strings (3.7) | Per-**lane** persistence lines: `echo >>f "set global.AFC_lanes[0][1] = ", global.AFC_lanes[0][1]` → drops manual `""""` quoting. **Verified limits:** a string expression is capped at 256 chars and a line at 255, and embedded `"` are not escaped – so never echo a whole multi-unit array on one line, and keep `"` out of user strings. | save_status, spool_save_status, spool_write, Spool - Create |
| R04 | `exists(E[n])`/`exists(E.f)` return false; `null` propagation (3.7) | Simplify user-override merge loops and optional-field checks. | AFC_user_vars examples, OM probing |
| R05 | `M574 E` binds a `M950 J` input to stop `G1 H1 E` moves (3.7) | Native "extrude until toolhead sensor" / "retract until clear": replace tfree's unbounded `G1 E-5` loop (B17); allow loading to a toolhead sensor then a fixed distance to nozzle. | tfree, load_with_preload, tpost prime |
| R06 | `M950 J C"fm<N>.switch"`; `sensors.filamentMonitors[].filamentPresent` (3.7) | Read lane/toolhead presence through the filament-monitor object without re-binding pins. | tpost/tfree monitor handling, runout |
| R07 | `M581.1` trigger on an OM expression becoming true (3.7) | Event-driven: low-spool warning, buffer stuck detection, hub-occupied detection, replacing parts of daemon polling *(verify syntax)*. | sys/daemon.g, buffer |
| R08 | `M116 P` with multiple tools (3.7) | Wait for all tools a job uses at start. | start_print |
| R09 | Out-of-limit G1 is an error (3.7) | Must validate configured positions (B41/I05); check `'f` H4 moves past `M208`. | park, poop, kick, cut, brush, tfree |
| R10 | Two-slope PA `move.extruders[].pressAdv` (3.7) | Save/restore k0/k1/d in cut.g (B26). | cut.g |
| R11 | `move.motionSystems[]` (3.7; `state.currentTool` obsolete) | Future-proof tool queries (low priority). | all |
| R12 | `take/drop/find` (3.6), `M291 J2` (3.6) | Pin-prefix handling; graceful cancel (I16). | pins, menus |
| R13 | `;customInfo key=value` in job header → `job.file.customInfo` (3.6) | Slicer can pass used tools, purge volumes or lane mapping to start_print (G03, G05, G06). | start_print, poop |
| R14 | `fileread()` (3.5) | Read spool/index files without executing them. | spool macros |
| R15 | Error messages include file name (3.7) | Reduce the "Aborting macro. Line …" M291 boilerplate. | all |

## 5. Documentation inaccuracies (README.md / DOCUMENTATION.md)

| ID | Statement | Reality |
|---|---|---|
| D01 | Slicer change-filament G-code calls `0:/sys/AFC/set_temp_global.g` | File is `0:/sys/AFC/Macros/set_temp_global.g` and is broken (B04). Fixed in P1-08 (README/DOCUMENTATION path corrected). |
| D02 | Copy root `daemon.g` to `0:/sys/daemon.g` | Would replace the working `sys/daemon.g` (B12). **Fixed (P5).** |
| D03 | Feature flags `global.AFC_brush`, `global.AFC_cut`, …; `global.AFC_load_method`/`AFC_unload_method`; `global.AFC_debug` in Machine_user_vars | Real config: `Machine_features[0..8]` array; load/unload method per unit in `AFC_features[u][1..2]`; debug flag not user-settable (B29). **Fixed (P5).** |
| D04 | Boot sequence lists `startup_check.g` | Never runs (B11). **Fixed (P5).** |
| D05 | Spoolman server integration, "configure server address" | Local SD spool tracking only (G10). **Fixed (P5).** |
| D06 | cut.g "progressively increased motor current" | Fixed optional current boost. |
| D07 | Brush deploy/retract files go in `0:/sys/AFC/` | Code looks in `0:/sys/AFC/Macros/`; shipped files are machine-specific (B23). **Fixed (P5).** |
| D08 | Tool-change diagram shows tfree after tpost | RRF order is tfree → tpre → tpost. **Fixed (P5).** |
| D09 | README: rename `AFC_user_vars_example.g` in the AFC folder | Files are `sys/AFC/0/AFC_user_vars-<board>-4_lanes.example` → `sys/AFC/0/AFC_user_vars.g`. **Fixed (P5).** |
| D10 | Filament runout "implemented but untested" | Not connected (B09). **Fixed (P5).** |
| D11 | Copy all of `sys/` | Overwrites user config with the dev `AFC_Unit_Count.g` (B52). **Fixed (P5).** |
| D12 | Requires RRF 3.6+ | Now **RRF 3.7+** (decision D1); 3.7 also changes out-of-limit move behaviour (R09) – state the tested versionns. **Fixed (P5).** |

## 6. Verification results (RRF 3.7-dev @ 72032c5, wiki-content, dwc-gcode-core 1.36.0)

| # | Question | Result | Evidence |
|---|---|---|---|
| 1 | if / non-indented lines / elif (extruder_setup.g) | Works only when the `if` is true; throws `'elif' did not follow 'if'` otherwise (multi-tool). B18 confirmed. | StringParser.cpp 405-420, 630-653; gcode-core `structure/document-error` |
| 2 | `abort` in a tool-change macro during a print | **Cancels the print** (AbortPrint → StopPrint). B44 raised to High. | StringParser.cpp 851-878; GCodes.cpp 3507-3522 |
| 3 | `T-1 P0` inside tpost.g | No guard: starts a nested tool change and overwrites `newToolNumber`. Avoid (plan task P1-07). | GCodes2.cpp HandleTcode |
| 4 | `G1 H4 'f-20000` beyond `M208 'f-500` on 3.7 | Safe: H-moves skip limit checks. Normal G1 to out-of-limit targets now throws (B41). | GCodes.cpp 2598-2662 |
| 5 | Float driver ids | Rounded to nearest (`lrintf(10*x)`, ±0.002) since 3.4. An **integer** value in an array is board-0 driver N, so the `+0.0001` (which forces a float) stays (B55). | StringParser.cpp 2055-2080; ExpressionParser ConvertToDriverId; NumericConverter FitsInInt32 |
| 6 | echo round-trip of arrays (3.7) | Works with `[…]` and quoted strings, but 256-char expression / 255-char line limits and no `"` escaping (R03 revised). | ObjectModel.cpp 30-182; Configuration.h 165 |
| 7 | `M584 E` mid-print | M584 waits for standstill on all motion systems first. Effect on extruder 0 position/PA still needs a hardware check. | GCodes3.cpp DoDriveMapping |
| 8 | `var` inside `while` | Fine per iteration; re-declaring an outer name errors (B19). | GCodeMachineState.cpp 376-386; StringParser.cpp 738-746 |
| 9 | `M581 … R-1` disarm | Valid – sets condition -1, trigger skipped. R2 triggers don't fire while paused. | TriggerItem.cpp 39, 220-226; PrintMonitor.cpp 346-358 |
| 10 | `M574 'f1 P"nil"` after `'f2` | Releases the pin (one endstop per axis). B08 invalid. | EndstopsManager.cpp HandleM574 |
| 11 | filament-error.g | `0:/sys/filament-error.g`, D = extruder, no auto-pause. B09/B10 confirmed. | Event.cpp 91-112; GCodes3.cpp 1408-1450 |
| 12 | `M291` cancel | J1 ends the current macro (or stops the print from a job file); J2 → `result` = -1. I16 revised. | GCodes7.cpp 33-40, 151-154; GCodeBuffer.cpp 1306-1320 |
| 13 | `M47`, `M470` | `M47` unknown; `M470 P"…"` mkdir; file writes create folders anyway. B28 confirmed. | GCodes2.cpp 3380; FileStore.cpp 92 |
| 14 | `!==`, `&`, `{e}` vs `{e,}` | All as documented in RRF_NOTES §1. | ExpressionParser.cpp |
| 15 | `home'f.g`, `''` in strings | Correct. | Kinematics.cpp 184-195; StringParser InternalGetQuotedString |

Still hardware-only: #7; Longboi trigger/interrupt behaviour; actual mixing-extruder and buffer behaviour during a print;
CAN timing of per-LED `M150`; physical lengths and sensor polarities.

## 7. Hardware verification checklist (nothing below could be run without a printer)

Give each item to a tester with the template in IMPLEMENTATION_PLAN.md (Appendix B). Everything was checked by reading the RRF source
and with the linter only.

| # | Test | Covers |
|---|---|---|
| H1 | Run *Create System Files → tfree*, open `0:/sys/tfree.g`, `T0` → `T-1`: no "unknown variable" | B01 |
| H2 | Note `M566`/`M203` for E0 from config.g; reboot; same values at boot and after `T0` | B06 |
| H3 | Load `T0`, reboot: no error from status.g; boot dialog appears ~10 s after boot; each of Keep / Unload / Leave does what it says | B02, P2-11 |
| H4 | Spool: create → assign → unassign → assign again; `T3` + 50 mm extrusion + 15 s: no daemon error; `T-1` writes the spool file | B03, B05, B13 |
| H5 | Mid-print tool change: the first move after it prints at layer height | B07 |
| H6 | Slice two colours with different temperatures; tpre heats to each slicer temperature | B04 |
| H7 | Start a print with T1's lane marked empty: the print **pauses** at the change with a message and a red LED; mark loaded, resume | B44, B15 |
| H8 | Unplug the hub switch and run a load: it stops after first-length + 100 mm with an error, not grinding | B16 |
| H9 | Enable kick with the default `-1` positions: one boot message, no crash | B41 |
| H10 | With a 4th axis added (or `Machine_om_axis_number` wrong) the trigger load still stops at the load switch | B34 |
| H11 | Initial unload 1 with an extruder input switch: `G1 H1 E-x` stops when the switch clears (mixing tool!) | B17 |
| H12 | Boot with an old `spool_status.g`: assignments survive and the file is rewritten | D6 migration |
| H13 | Multi-tool/IDEX: `M584 E` with several AFC extruders, offsets and axis mapping per tool, `M567` per tool (T0 then T4) | B18/B19/B56 |
| H14 | Pull filament out of the current lane during a print: pause, unload, backup lane takes over (or the menu); resume prints again | B09/B10, P3-04 |
| H15 | `Lane - Map Tool` swap, then a print with both tools | P3-03 |
| H16 | Buffer: advance switch → 0.95, released → 1.0; both switches at once → pause | B38, P3-06 |
| H17 | LEDs: colours per lane, reversed strip, filament colour, `Test - LEDs` | B50, P3-07 |
| H18 | Tip forming without a cutter; slicer purge length (`C`); low-spool warning | P3-09, P3-05, P4-05 |
| H19 | DC motor at `AFC_dc_speed` < 1 (PWM) and `AFC_dc_load_assist` | P3-10 |
| H20 | Cancel a print: stop.g unloads (or not with `Machine_unload_on_cancel = false`) | G07 |
