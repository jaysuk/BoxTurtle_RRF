# BoxTurtle_RRF – Implementation plan (bug fixes and feature work)

For: Claude Sonnet (or any maintainer) implementing the items in [AUDIT.md](AUDIT.md).
Written 2026-10-04 against branch `Next` @ `cb3c7ad`. Every RRF behaviour this plan relies on is verified in
[maintainers/RRF_NOTES.md](maintainers/RRF_NOTES.md) (RRF source `3.7-dev` @ `72032c5`, wiki-content, dwc-gcode-core 1.36.0).

---

## Implementation status (updated after the implementation pass)

All phases are implemented in the working tree (nothing committed). Gates at the end: `lint.mjs` **0 findings / 0 errors**
(baseline 49/34), `check_locals.py` **0** (baseline 14), `xref_globals.py` clean for every touched global. **Nothing has run on a
printer**: see AUDIT.md §7 for the hardware checklist. Deviations from the plan text, and why:

| Task | Deviation |
|---|---|
| P1-01 | Generated tfree.g uses `move.motionSystems[0].currentTool` and the tool map instead of `state.currentTool` / `Tool_to_AFC` |
| P1-06 | `AFC_Unit_Count.g` was untracked with `git rm --cached` (file kept on disk), as the user chose |
| P2-01 | The pause flag of `afc_error.g` is **`Q`**, not `P`: RRF never forwards `P` through `M98 P"file"` (`StringParser::AddParameters`), so the plan's `P1` could not work. `T` is the lane's native tool number. `F1` marks the tool change failed; `AFC_error_count` lets callers detect a failed nested step |
| P2-02 | `lane_motion_end.g` checks `move.axes[].visible` before hiding; `Machine_om_axis_number` stays declared (= -1) only so old user files do not fail |
| P2-03 | Searches are bounded to `[2]+100` (the old 20 m only for an unmeasured lane); initial unload binds the input to **every** extruder (a mixing tool's AFC extruder would otherwise get a stall-detection endstop) |
| P2-06 | Extruder arrays are filled by index instead of `^` so driver ids keep their OM type; stage 2 (second motion system) not done |
| P2-07 | No `AFC_lane_type_saved` (DWC type edits are not persisted by the daemon) |
| P3-01/03/04 | Backup lane lives in a new `AFC_lane_backup` (not `AFC_lanes[u][l][3]`) because old status files hold 0 there; tool map swap instead of one-way remap |
| P3-02 | startup_check = switch comparison + bounded hub probe (no automatic retract); root `daemon.g` deleted |
| P3-05 | Purge length arrives through `set_temp_global.g C` (`Machine_slicer_purge`), customInfo not used |
| P3-08 | Used tools come from `job.file.filament`, optional `L"1011"` |
| P3-10 | B35: warning in config_check instead of changing the output numbers; G07: `Machine_unload_on_cancel`, park position, all tools off (no pause/resume hooks); G11: `Lane - Park` (eject-on-release not done); I15: PWM below `AFC_dc_speed` 1 and `AFC_dc_load_assist` |
| P4-01 | `[ ]` conversion done for every `set`/`var`/`global` line (script, string-aware); G-code parameters (`K{…}`), `echo` text and two TN lines in the user-vars examples keep `{ }` |
| P4-02 | Per-lane `echo` of arrays for status.g; spool files keep their own quoting; `"` rejected in text inputs |
| P4-06 | Not done (RRF 3.7.0 final / dwc-gcode-core release not available here) |

---

## 0. How to work through this plan

### 0.1 Before every task
1. Read `CLAUDE.md`, then the task's files **in full**, plus their entries in `maintainers/MACROS.md` and any globals in `maintainers/GLOBALS.md`.
2. Re-locate code by searching for the quoted text – line numbers in this plan and AUDIT.md drift.
3. The user's decisions are in §0.4 – follow them; ask only about something they don't cover.

### 0.2 Gates every task must pass (Sonnet can't run a printer, so these are the automated checks)
```
cd docs/maintainers/tools && npm install         # once per checkout
node lint.mjs              # RRF 3.7.0-rc.2 (minimum firmware, D1) – findings must not increase; the task's own findings must disappear
cd ../../.. && python docs/maintainers/tools/check_locals.py     # no new undeclared var.x
python docs/maintainers/tools/xref_globals.py <GLOBAL…>           # for any global you touched
```
Baseline (before Phase 1): `lint.mjs` → **49 findings / 34 errors**; `check_locals.py` → **14** (B02, B11).
Record the new numbers in the commit message.

### 0.3 Rules
- One task = one focused change set. Commit only when the user asks; suggested message: `fix(<area>): <what> (B01)`.
- RRF meta-G-code rules that bite (all verified, RRF_NOTES §1): indentation is structure; string concatenation inside `{}` only;
  `var` names must be unique across nested scopes; `abort` during a print **cancels the print**; `M291 J2` → test `result`, not `input`.
- Match file style: spaces in `sys/AFC` and `macros/`, tabs in `sys/start_print.g`, `stop.g`, `start_after_delay.g`; CRLF.
- **RRF 3.7 is the minimum (D1).** In code you write or touch: `[ ]` array literals (`[x]`, `[]`), `^` to append to arrays,
  `move.motionSystems[0].currentTool` instead of `state.currentTool`, `pressAdv` instead of `pressureAdvance`. Don't
  rewrite untouched files just for syntax – P4-01 does that in one pass.
- Never hand-edit generated printer files – change `macros/Create System Files` and tell the user to re-run it.
- Docs in the same change: MACROS.md / GLOBALS.md / HARDWARE_RESOURCES.md as affected, and the AUDIT.md Status cell → `fixed (<task id>)`.
- Each task ends with a **Hardware test** section: copy it into your final message so the user can run it.

### 0.4 Decisions (answered by the user, 2026-10-04)
| ID | Question | Decision | Consequence in this plan |
|---|---|---|---|
| D1 | Minimum firmware | **RRF 3.7 only** | Lint gate at 3.7 only; 3.7 syntax allowed everywhere; Phase 4 is scheduled, and `M574 E` is used directly in P2-03 |
| D2 | Recoverable failure during a print | **Pause** | P2-01: `afc_error.g` pauses (`M226` on the job channel, `M25` elsewhere) |
| D3 | Tool loaded at shutdown | **Check, don't silently reselect** | New P2-11 boot-state check (asks the user from the daemon after boot); P3-02 extends it |
| D4 | Tool → lane remapping | **Yes** | P3-03 in scope; runout swap (P3-01/P3-04) uses it |
| D5 | Multi-tool / IDEX | **Support** | P2-04 checks the configuration instead of refusing; P2-06 is rewritten as real multi-tool support (needs an IDEX tester) |
| D6 | Rename `spoolman` | **Rename to spool tracking** | New P2-10 with a migration for existing status files |

---

## Phase 0 – Tooling (done in the audit; verify only)

- [ ] **P0-01** `cd docs/maintainers/tools && npm install && node lint.mjs` reproduces 49/34. If not, stop and report: the dictionary or repo changed.

---

## Phase 1 – Critical, surgical fixes
Small, low-risk edits that unbreak core operation. No refactoring here.

### P1-01 Generated tfree.g references an undeclared variable (B01)
- **File:** `macros/Create System Files` (the `tfree.g` block, `echo >>{var.filename} "if global.AFC_features[var.unit_number][0]"`).
- **Change:** emit `if global.AFC_features[global.Tool_to_AFC[state.currentTool][0]][0]` (tfree only runs while a tool is current).
- **Accept:** lint unchanged; read the echo'd lines and confirm the output file would contain no `var.`.
- **Hardware test:** run *Create System Files → tfree*, open `0:/sys/tfree.g`, then `T0` → `T-1`: no "unknown variable" error.

### P1-02 tool_load_no_files.g never declares `var.tool_number` (B02)
- **File:** `sys/AFC/Macros/tool_load_no_files.g`. Add `var tool_number = param.A` after the `param.A` check.
- **Accept:** `check_locals.py` drops to 10 (only startup_check left).
- **Hardware test:** load a tool (`T0`), reboot; console shows no error from `status.g`; `M567 P0` shows `E1:1`.

### P1-03 Spool record shape corrupted by Unassign (B03)
- **Files:** `sys/AFC/AFC_Units_Setup.g`, `macros/Spool - Unassign`, `macros/Spool - Assign to Lane`, `macros/Spool - Inventory`, `sys/AFC/Macros/spool_read_all.g`.
- **Change:**
  1. In AFC_Units_Setup.g, before `spool_load_temp`, add
     `global spool_empty_record = {-1, "", "", "", 0.0, 0.0, "", "", "", 0.0, 0.0, 1.24}` (guard with `if !exists(...)` like its neighbour).
  2. Replace every literal 12-field reset (`spool_load_temp` resets, `spool_active_data` defaults) **and** the 9-field one in Unassign with `global.spool_empty_record`. Arrays are copy-on-write, so sharing is safe (RRF_NOTES §2).
  3. Unassign: before clearing, if `global.spool_active_data[u][l][0] != -1` call `M98 P"0:/sys/AFC/Macros/spool_write.g" U{u} L{l}` so the last metre isn't lost.
- **Accept:** `grep -n '{-1, ""' -r sys macros` returns only the new global; lint unchanged.
- **Docs:** GLOBALS.md §5 (add `spool_empty_record`).
- **Hardware test:** Create spool 1 → assign to U0L0 → Unassign → Assign again: no "index out of range".

### P1-04 Spool tracking arrays sized before tools exist (B05)
- **File:** `sys/AFC/AFC_Units_Setup.g` (`spool_extrusion_baseline`, `spool_unsaved_extrusion`).
- **Change:** `vector(global.AFC_unit_total_available_lanes, 0.0)` (AFC tools are 0..N-1 and are the only tools after calculate_tools).
- **Hardware test:** enable spool tracking (`Machine_features[7]=1`), `T3`, extrude 50 mm, wait 15 s: no daemon error; `T-1` writes the spool file.

### P1-05 Printer extruder jerk/speed set 60× too low (B06)
- **Files:** `sys/AFC/Macros/calculate_tools.g`, `sys/AFC/Macros/extruder_setup.g`.
- **Change:** wherever an OM extruder value feeds `M566`/`M203`, multiply by 60:
  - calculate_tools.g and extruder_setup.g first loop: `set var.jerk[iterations] = global.Machine_extruder_info[iterations][3] * 60` and `set var.speed[iterations] = global.Machine_extruder_info[iterations][5] * 60`.
  - extruder_setup.g multi-tool branch: `move.extruders[…].jerk * 60` and `move.extruders[…].speed * 60` (4 places).
  - Add a comment: `; OM extruder jerk/speed are mm/s; M566/M203 take mm/min`.
- **Accept:** `grep -n "\[3\]\|\[5\]\|\.jerk\|\.speed" calculate_tools.g extruder_setup.g` – every OM jerk/speed use is ×60.
- **Hardware test:** note `M566`/`M203` output for E0 from config.g; reboot; `M566` and `M203` show the **same** E0 values; same after `T0`.

### P1-06 Shipped configs that break installs (B51, B52)
- **Files:** `sys/AFC/Machine/Machine_user_vars.example` (set `var initial_unload = 0`), delete tracked `sys/AFC/AFC_Unit_Count.g` (`git rm`), add `.gitignore` entries:
  `sys/AFC/AFC_Unit_Count.g`, `sys/AFC/[0-9]*/AFC_user_vars.g`, `sys/AFC/Machine/Machine_user_vars.g`, `sys/AFC/Status/`.
- **Ask first:** deleting `AFC_Unit_Count.g` removes the user's own dev config from git – confirm they have a copy.
- **Docs:** README/DOCUMENTATION install steps (D11).

### P1-07 tpost leaves the nozzle 5 mm high (B07)
- **File:** `sys/AFC/Macros/tpost.g` last line. After `G1 R2 X0 Y0 Z5 F…` add `G1 R2 Z0 F{global.Machine_travel_speed[1]*60}`.
- **Hardware test:** mid-print tool change; first move after the change prints at layer height.

### P1-08 Per-lane temperatures (B04, D01)
- **Files:** `sys/AFC/Macros/set_temp_global.g`, `sys/start_print.g`, `README.md`, `DOCUMENTATION.md`.
- **Change:**
  ```
  ; set_temp_global.g – param.A tool number, param.B temperature (from the slicer's change-filament G-code)
  if !exists(param.A) || !exists(param.B)
      M118 S"set_temp_global.g needs A (tool) and B (temperature)"
      M99
  set global.AFC_extruder_temp[global.Tool_to_AFC[param.A][0]][global.Tool_to_AFC[param.A][1]] = param.B
  ```
  start_print.g: add `var lane_number = global.Tool_to_AFC[var.tool_number][1]` and index `[var.unit_number][var.lane_number]`.
  README/DOCUMENTATION: path `0:/sys/AFC/Macros/set_temp_global.g`.
- **Hardware test:** slice a 2-colour print with different temps; console shows tpre heating to each slicer temp.

### P1-09 Parse-level errors the lint reports (B24, B26, B28, B39, B54, B20, B27)
One commit, all mechanical:
| Where | Fix |
|---|---|
| `cut.g` "Invalid cut direction" | `R"0:/sys/AFC/Macros/cut.g"` (remove the stray `{`); Y-limit message says "Y" |
| `Lane - Measure First` failure message | `M291 P{"The measurement for Unit "^var.unit_number^…^" … investigate!"} S1` (braces) |
| `start_after_delay.g:99` | `M118 S{"Print start time is " ^ var.RunTime}` |
| `start_after_delay.g` cancel check | `global.Cancelled` → `global.Machine_cancelled` (both lines) |
| `Create System Files` | **Delete** `M47 "0:/spools"` (`M47` doesn't exist). Don't replace it with `M470`: that errors when the folder already exists, and writing a spool file creates the folder anyway (RRF_NOTES §2) |
| `tpost.g`, `tfree.g` | `LEDs.g` → `leds.g`; `Extruder_setup.g` → `extruder_setup.g`; `Axis_setup.g` → `axis_setup.g` |
| `tfree.g` homing check | third test uses `Machine_axis_number[2]` |
- **Accept:** lint loses the `cut.g:49`, `Measure First:111`, `start_after_delay.g:99/102/103`, `M47` findings.

---

## Phase 2 – Robustness foundation
Shared helpers first, then the fixes that use them. Do these in order.

### P2-01 Central error handler and no `abort` mid-print (B44, B15, I07; Decision D2)
- **New file:** `sys/AFC/Macros/afc_error.g`
  ```
  ; afc_error.g – report an AFC failure and leave the machine recoverable
  ; param.S message (required), param.T tool number (optional), param.P 1 = pause the print if one is running
  if !exists(param.S)
      M118 S"afc_error.g called without S"
      M99
  if exists(param.T) && param.T >= 0
      set global.AFC_LED_array[global.Tool_to_AFC[param.T][0]][global.Tool_to_AFC[param.T][1]] = 0
  M98 P"0:/sys/AFC/Macros/lane_motion_end.g"          ; from P2-02; frees 'f endstop, hides 'f, re-arms triggers
  M98 P"0:/sys/AFC/Macros/leds.g"
  M118 S{"AFC error: " ^ param.S}
  if exists(param.P) && param.P == 1 && job.file.fileName != null && state.status != "paused" && state.status != "pausing"
      if inputs[state.thisInput].name == "File" || inputs[state.thisInput].name == "File2"
          M226                                          ; job channel: deferred until the tool-change macros unwind
      else
          M25                                           ; other channels: RRF defers it itself if the job is inside a macro
  M291 P{param.S} R"AFC error" S1 T0
  ```
  Verified: `M226` in a non-restartable macro on the job channel is deferred until the macro stack returns; `M226` on any
  other channel is an error; `M25` from another channel becomes a deferred `M226` when the job is inside a macro
  (`GCodes2.cpp` 1254-1314). `state.thisInput` exists in 3.6.3 and 3.7 (`RepRap.cpp` 373).
  (If you do P2-01 before P2-02, call nothing for cleanup yet and add it in P2-02.)
- **Replace** every `M291 P{"Aborting macro…"} … abort` in the tool-change path (`tpre.g`, `tfree.g`, `tpost.g`, `cut.g`, `kick.g`, `load_with_*.g`, `extruder_setup.g`, `axis_setup.g`) with:
  `M98 P"0:/sys/AFC/Macros/afc_error.g" S"<what failed>" T{var.tool_number} P1` then `set global.Machine_tpre_failed = true` (tpre/load paths) then `M99`.
  Keep `abort` only in idle-only user macros (`macros/…`) where cancelling is intended.
- **tpre.g, lane not loaded (B15):** add the missing `else` → afc_error with "No filament loaded in Unit u Lane l" (the unused `var.warning_text`).
- **tpost.g, tpre failed:** replace `T-1 P0` + `abort` with: clear the flag, `M568 P{var.tool_number} A0`, message, `M99`. Never issue `T` inside a tool-change macro (RRF_NOTES §2).
- **Accept:** `grep -rn "^\s*abort" sys/AFC/Macros` lists only files that never run during a print (document them in the commit).
- **Hardware test:** start a print with the lane for T1 marked empty; at the T1 change the print **pauses** with a message, LED red; mark loaded, resume → continues.

### P2-02 Lane-motion helpers + `'f` index auto-detect (I03, I04, B34, B16-cleanup)
- **New files:**
  - `lane_motion_begin.g A<tool>` – `axis_setup.g A`, `M584 P{#move.axes}`, Longboi trigger disarm loop (copy the existing block), then sets `global.AFC_f_axis` = index of the axis whose `letter == "f"` (loop over `move.axes`).
  - `lane_motion_end.g [A<tool>]` – `M574 'f1 P"nil" S1` (one endstop per axis, so this frees any `'f` endstop – RRF_NOTES §2), `M584 P{#move.axes - 1}` only if `'f` is visible, Longboi re-arm loop.
- **Global:** `global AFC_f_axis = -1` in AFC_Units_Setup.g; replace every `global.Machine_om_axis_number` read with `global.AFC_f_axis`; keep `Machine_om_axis_number` as deprecated (document) or remove from examples.
- **Refactor callers** to begin/end: `triggers.g`, `unload.g`, `Lane - Measure First`, `Lane - Measure Main Length`, `Lane - Unload to Hub`, `tpre.g`, `tfree.g`, `load_with_*.g`. Delete their inline Longboi loops and `M584 P` pairs.
- **Accept:** `grep -c "M584 P{#move.axes" -r sys macros` only in the two helpers + axis_setup; `grep -rn Machine_om_axis_number sys macros` only in docs/deprecation note.
- **Docs:** MACROS.md (new entries), HARDWARE_RESOURCES.md §3-4, GLOBALS.md.
- **Hardware test:** with a U axis configured (or `Machine_om_axis_number` deliberately wrong), insert filament → trigger load still stops at the load switch.

### P2-03 Bounded, verified search moves (B16, B17, B24, B25, I06)
- For every `G1 H4`/`H1` search on `'f`: set the distance to expected + margin (e.g. `AFC_lanes[u][l][2] + 100` for toolhead sensors, `[1] + 100` for the hub, 300 for the load switch) instead of `AFC_max_min_axes[1]`, and afterwards check `sensors.endstops[global.AFC_f_axis].triggered`; on failure → afc_error (P2-01).
- `tfree.g` initial unload (D1 → 3.7): bind the extruder input switch once at boot (`M950 J<n> C"…"`, `M574 E<ext> P<n>`)
  and replace the `while … G1 E-5` loop with one `G1 H1 E-{Machine_extruder_measurements[0] + 20} F600` (an unloading
  `H1 E` move stops when the input goes inactive – RRF_NOTES §2), then verify the switch reads clear; afc_error if not.
- `load_with_preload.g` and Measure Main Length method 2: refuse with afc_error if `Machine_extruder_switches[0] == "nil"`.
- `Lane - Measure First`: move the max-distance check before the back-off (compare against `safety_dist - 0.5`).
- `Lane - Measure Main Length`: verify trigger; for load method 1 offer manual entry (`M291 S5`) when no TN switch is configured.
- **Hardware test:** unplug the hub switch, run a load: stops after first-length+100 mm with a red LED instead of grinding.

### P2-04 Boot-time configuration check (I05, B41, B46, B53)
- **New file:** `sys/AFC/Macros/config_check.g`, called at the end of `AFC.g`. Collect problems into one message (`M291 S2` if any) – don't abort boot. Checks:
  - each enabled feature's position (`Machine_cut_location`, `Machine_purge_location`, `Machine_kick`, `Machine_brush`, `Machine_park`) is not `-1` and lies within `move.axes[].min/max` (3.7 rejects out-of-limit moves);
  - load method 2 / initial unload 1 ⇒ `Machine_extruder_switches[0] != "nil"`;
  - `AFC_hub_load_distance[u][0] > AFC_hub_retract_distance[u]`;
  - loaded lanes have `[1] > 0` and `[2] > [1]`;
  - every unit CAN id appears in `boards[].canAddress`;
  - every driver id in `AFC_steppers[u][l][0]` still carries the float offset (B55): `x - floor(x * 10) / 10` is about
    0.0001 – this catches user overrides written as integers (`{0,1,2,3}`), which would select the wrong board;
  - multi-tool (D5): each `tool_and_motion[u][0]` is a printer tool that exists in `Machine_actual_tools`; a motion system
    other than 0 only on boards that support it (`boards[0].shortName` is `"MB6HC"` or `"MB6XD"` – RRF 3.7 dropped
    multiple motion systems on the Duet 3 Mini).
- Change default `AFC_hub_load_distance` to `{45, 5}` (B46); update the example comments' trigger/J numbers to "auto-allocated – see HARDWARE_RESOURCES.md" (B53).
- **Hardware test:** enable kick with default `-1` coordinates → one clear boot message, no crash at the first tool change.

### P2-05 Menus: graceful cancel (I16)
- Every `M291 … S4|S5|S6|S7 … J1` followed by `if input == -1` → change to `J2` and test `if result == -1` **on the next line** (wiki: `result` must be tested immediately). Remove dead `input == -1` checks after J1 where cancelling should abort.
- **Accept:** `grep -rn "input == -1" macros sys` returns nothing.

### P2-06 Multi-tool / IDEX support and extruder mapping (B18, B19, B56, I20, I21; D5)
Write a short design note first (in ARCHITECTURE.md §1), then implement.
**Model:** a unit feeds one printer tool (`tool_and_motion[u][0]`, from the user's config.g – e.g. IDEX left head T0,
right head T1). Each printer tool that has AFC units gets **its own AFC extruder**, appended after the printer's
extruders in order of first use, so both heads can hold filament at the same time.
- `gather_machine_info.g`: also record each printer tool's axis mapping (`tools[t].axes`) and offsets (`tools[t].offsets`).
- `calculate_tools.g` (rewrite the multi-tool half; build arrays with `^` – no `extra_to_add`, no second `var D`):
  - `global AFC_head_extruder` `[printerTool]` = index of that head's AFC extruder (-1 if no unit feeds it);
  - per AFC tool t (lane of unit u): `D` = the printer tool's extruders `^ [AFC_head_extruder[pt]]`, `H`/`F` from the
    printer tool, **`X`/`Y` axis mapping from `tools[pt].axes`** and **`G10` offsets from `tools[pt].offsets`** (B56 –
    today every AFC tool gets `X0 Y0 Z0` and the default axis mapping, which loses tool offsets and IDEX's U-as-X mapping);
  - one `M584 E` list covering all extruders; params ×60 as in P1-05.
- `extruder_setup.g`: remap only the AFC extruder of the tool's head (`AFC_head_extruder[pt]`) to the lane's driver;
  `M567 P<t>` with one ratio per drive of that tool (`[1, …, 1]` built with `^`).
- `tpost`/`tfree`: `M591` on the head's AFC extruder (this replaces P2-09's single `afc_ext`).
- Motion systems: stage 1 supports IDEX in **one motion system** (classic U-axis IDEX; all tool changes on the job
  channel). Stage 2 (separate commit, only with a tester): motion system 1 – the `'f` axis must not be used by both
  systems at once, so lane moves take a lock global; tool changes for system 1 run on File2.
- **Accept:** lint loses `extruder_setup.g:84`; `check_locals.py` clean; a single-tool config produces exactly today's
  `M563` lines plus the printer tool's offsets and axis mapping.
- **Hardware test (single tool):** boot; `M563` for every AFC tool matches T0's heaters, fans and offsets; print 2 colours.
- **Hardware test (IDEX, needs a user with IDEX):** two units on the T0/T1 heads; `T0` then `T4` (lanes on different
  heads) – both heads keep their filament, offsets are correct, `M567` shows the right ratio per tool.

### P2-07 `AFC_lanes[u][l][4]` = `{type, colour}` everywhere (B14)
- Delete the `[4][1] = [4][0]` loop at the end of `AFC.g`. If DWC/btncmd type edits must be persisted, add `global AFC_lane_type_saved` (`[u][l]` string) and a daemon check that saves when `[4][0]` differs.
- Re-enable the `AFC_lanes[..][4]` sync in `Spool - Assign to Lane` (B42).

### P2-08 Cleaning moves (B21, B22, B23)
- `kick.g`: drop to `Machine_kick[3]` for the sweep, raise to `Machine_kick[8]` after, apply `[5]` with `M204` (save/restore) when > 0.
- `purge.g`: remove the brush/servo block; extrude only when park or poop ran this tool change (pass a flag from tpost), at the current unit's `[2]` speed.
- Brush files: rename the four author-specific files to `*.g.example`; brush.g only calls `brush_deploy.g`/`brush_retract.g` if they exist (already does) – document in README; in `brush_safe_*` use `Machine_brush[18]`.

### P2-09 tfree / tpost / daemon details (B13, B30, B31, B32, B47, B49, B38)
- daemon.g (B13): keep `global spool_extrusion_max[t]`; deduct only `position - max` when positive; reset max on a negative jump > 50 mm (G92). Same rule in tfree.
- tpost (B30): `G92 E0` before snapshotting; count prime + poop length into the spool.
- tfree (B31): if `heat.heaters[tools[t].heaters[0]].current < 180` (or below the lane temp − 20) set the lane temp and `M116`.
- M591 (B32): compute `var afc_ext = #global.Machine_extruder_info` once (that's the AFC extruder index) and use it in both tpost and tfree.
- tpost prime (B47): `G1 E{distance - 10} F{fast}` then `G1 E10 F{global.AFC_load_retract_speed[u][2]*60}`.
- tfree method 1 (B49): back off the same `AFC_hub_retract_distance` used by Measure First; use `'f2` consistently (B08 cosmetic).
- Buffer triggers (B38): generate falling-edge (`S0`) triggers that restore `E1:1`.

### P2-10 Rename "spoolman" to spool tracking (D6, I11)
- Globals: `spoolman` → `spool_tracking` (`[u][l] = {spoolId, trackingActive}`); keep `Machine_features[7]` (index
  unchanged; called "spool tracking" in every comment and doc). Update tfree, tpost, spool_save_status, spool_read_all,
  Spool - Assign/Unassign/Delete and sys/daemon.g.
- Migration: existing `Status/spool_status.g` files contain `set global.spoolman[...]`. In `AFC_Units_Setup.g` also declare
  a deprecated `global spoolman` with the same shape; after `AFC.g` runs `spool_status.g`, if any `spoolman` id is not -1
  and every `spool_tracking` id is -1, copy across and call `spool_save_status.g` (rewrites the file with the new name).
  Remove the shim in a later release; note it in AUDIT.
- User files: `Machine_user_vars.g` builds `Machine_features` itself, so an old `var spoolman` there keeps working;
  rename it in `Machine_Vars_Setup.g` and the example.
- **Accept:** `grep -rn spoolman sys macros` only finds the shim; xref shows `spool_tracking` declared, set and read.
- **Hardware test:** with an old `spool_status.g` on the card, reboot – assignments survive and the file is rewritten.

### P2-11 Boot-state check (D3, part of G04)
- `save_status.g` stops writing `T<n> P0` + `tool_load_no_files.g` into status.g; it writes
  `set global.AFC_loaded_tool = <n>` (-1 when none) instead. (P1-02's fix still matters: tool_load_no_files.g is used below.)
- `AFC.g` sets `global AFC_boot_check_pending = true`. `sys/daemon.g` runs `boot_check.g` once while the flag is set
  (a blocking `M291` in config.g would stall boot; the daemon channel can wait for the user).
- `boot_check.g`: read every unit's hub switch (bind `M950 J`, read, free). If `AFC_loaded_tool != -1` or a hub is
  occupied, ask with `M291 S4 … J2` and test `result`:
  "Tool n was loaded at power-off: **Keep it loaded**" (`T<n> P0` – fine from the daemon, it is not inside a tool-change
  macro – then `tool_load_no_files.g`), "**Unload it now**" (`T<n> P0`, then `T-1`; tfree heats), or
  "**Leave it** – I'll sort it out" (`AFC_loaded_tool = -1`, LED yellow).
- If a hub is occupied but no tool was recorded, offer the lane menu to unload that lane.
- **Hardware test:** load T1 and power-cycle; the dialog appears about 10 s after boot; each choice does what it says.

---

## Phase 3 – Features (each needs a short design note in the PR/commit before coding)

### P3-01 Runout handling wired end-to-end (B09, B10, G02 part 1)
- Create System Files writes **`0:/sys/filament-error.g`**: `M98 P"0:/sys/AFC/Macros/filament-error.g" D{param.D} P{param.P} B{param.B}` (remove the `filament-error<N>.g` generator).
- Rewrite the handler: tool = `state.currentTool` (param.D is the AFC **extruder**); `M25` first (RRF does not pause when the file exists; from this async channel M25 becomes a deferred M226 if a macro is running – RRF_NOTES §2); unload with `T-1`-equivalent logic after the pause completes; menu with `J2`/`result`; reload detection by polling the prep/load switch (R2 triggers are off while paused); resume with `M24`.
- Use the tool→lane map from P3-03 for "continue with another lane" (needs D4) – until then offer only "reload this lane".

### P3-02 Full startup lane verification (B11, G04; builds on P2-11)
Replace `startup_check.g` (don't patch it): after P2-11's boot check, when `Machine_features[6]` is on, verify every lane
marked loaded with a bounded probe to the hub (P2-03) and correct `AFC_lanes[..][0]`; report a summary. Delete the root
`daemon.g` (B12) and fix README/DOCUMENTATION (D02, D04).

### P3-03 Tool → lane mapping (G03; D4)
`global AFC_tool_map` (`[t] = {u, l}`, default = identity from `Tool_to_AFC`), macro `Lane - Map Tool` (menu), persisted in status.g.
With multi-tool (D5) a tool may only map to a lane of a unit that feeds the same printer head (`tool_and_motion[u][0]`). All tool-change macros resolve lanes through the map; `Tool_to_AFC` stays the static tool numbering. Then filament-error "continue with another lane" = remap current tool + reload without changing the slicer's T numbers.

### P3-04 Infinite spool (G02 part 2)
`AFC_lanes[u][l][3]` becomes "backup lane tool index or -1"; menu macro to set it; runout handler swaps via P3-03.

### P3-05 Slicer-driven purge (G06, R13)
Accept a purge length from the slicer (Orca change-filament G-code passes a value to `set_temp_global.g`-style macro, or `;customInfo` → `job.file.customInfo`). Apply `Machine_purge_length_modifier`/`_addition`; account for the cutter stub (B48).

### P3-06 Buffer control (G08)
Proportional mix (e.g. 0.97/1.03 steps with falling-edge return to 1.0), stuck-buffer detection with `M581.1` expression triggers (3.7, D1).

### P3-07 Lane metadata & LEDs (G09, G14, I02)
`Lane - Set Filament` macro (type/colour/hex/temp); LED shows filament hex colour when ready, blue when in toolhead, red on error; batch `M150 … S<count>` per lane using a precomputed LED map (one helper used by leds.g and Test - LEDs).

### P3-08 Pre-print validation (G05)
start_print takes the used tools (Orca `{is_extruder_used[n]}` list or customInfo) and checks each lane is loaded, measured and has `remaining > estimate` when spool tracking is on.

### P3-09 Tip forming (G01)
Implement the `Machine_tip_*` sequence (ramming, cooling moves, skinny dip) as `tip_form.g`, used by tfree when cut is disabled.

### P3-10 Pause/resume/cancel hooks (G07), DC PWM (I15, G13), convenience macros (G11), logging (G16)
Small independent items; one commit each.

---

## Phase 4 – RRF 3.7 adoption (scheduled – D1 = 3.7-only)
Order: P4-01 straight after Phase 1 (user-facing files get the simpler syntax early); P4-03 is folded into P2-03/P2-09
(use `M574 E` there directly instead of bounded loops); P4-04 is done by whichever task edits cut.g/tfree.g; P4-02 and
P4-05 come after Phase 2.

| Task | Change | Notes |
|---|---|---|
| P4-01 (R01, R02) | `[ ]` literals everywhere (`AFC_Unit_Count` becomes `[119]`); build arrays with `^` (`M291_data[2][u] = M291_data[1][u] ^ ["All"]`) | Remove trailing-comma advice from examples and README |
| P4-02 (R03) | Persistence one line **per lane**: `echo >>f "set global.AFC_lanes[0][1] = ", global.AFC_lanes[0][1]` | ≤255 chars per line, no `"` in user strings (validate in Spool - Create) |
| P4-03 (R05) | `M950 J<n> C<extruder switch>` + `M574 E0 P<n>` → `G1 H1 E-200` retract until clear (tfree initial unload), load to toolhead sensor | Bind the J input once at boot |
| P4-04 (R10, R11) | cut.g saves/restores `pressAdv.k0/k1/d`; `state.*Tool` → `move.motionSystems[0].*Tool` | lint's deprecated-path findings disappear |
| P4-05 (R07) | `M581.1` low-spool warning / hub-stuck triggers | Expression must return bool |
| P4-06 | When RRF 3.7.0 final ships: move the lint gate to it, bump `dwc-gcode-core` to a release containing the 2026-10-04 fixes, and delete the matching filters in `lint.mjs` | RRF_NOTES §5 |

---

## Phase 5 – User documentation
Fix README.md / DOCUMENTATION.md items D01-D12 after the behaviour they describe has changed (do it last so the docs
describe the fixed system). Regenerate btncmd.json guidance for multi-unit setups (G09).

---

## Appendix A – Task ↔ audit map
| Audit IDs | Task |
|---|---|
| B01 | P1-01 |
| B02 | P1-02 |
| B03, B42 | P1-03, P2-07 |
| B04, D01 | P1-08 |
| B05 | P1-04 |
| B06 | P1-05 |
| B07 | P1-07 |
| B08 | P2-09 (cosmetic) |
| B09, B10 | P3-01 |
| B11, B12 | P3-02 |
| B13, B30, B31, B32, B38, B47, B49 | P2-09 |
| B14 | P2-07 |
| B15, B44 | P2-01 |
| B16, B17, B24, B25 | P2-03 |
| B18, B19 | P2-06 |
| B20, B26, B27, B28, B39, B54 | P1-09 |
| B21, B22, B23 | P2-08 |
| B33 | P2-02 (triggers.g rewrite) |
| B34 | P2-02 |
| B35 | P3-10 (move DC outputs to configurable high numbers) |
| B36 | P2-01 (Lane - Unload refuses when the lane is the current tool) |
| B37, B43, B45, B50, B53, B55 | fold into the task that edits the file; B50 → P3-07 |
| B40 | P3-10 |
| B41, B46 | P2-04 |
| B48 | P3-05 |
| B51, B52 | P1-06 |
| B56 | P2-06 |
| G01-G17 | Phase 3 |
| R01-R15 | Phase 4 |
| D01-D12 | Phase 5 |

## Appendix B – Hardware test log template (give this to the user)
```
Task:            Firmware: RRF x.y.z   Board(s):        Units/lanes:
Steps run:
Console output (copy):
Result: pass / fail – notes:
```
