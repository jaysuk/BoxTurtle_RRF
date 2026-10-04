# BoxTurtle_RRF – Architecture

How the macro system fits together. Read this first, then [MACROS.md](MACROS.md) for per-file detail,
[GLOBALS.md](GLOBALS.md) for every global variable, [HARDWARE_RESOURCES.md](HARDWARE_RESOURCES.md) for
pin/trigger/input allocation, and [RRF_NOTES.md](RRF_NOTES.md) for RepRapFirmware language rules.
Known defects are tracked in [../AUDIT.md](../AUDIT.md) by ID (e.g. `B05`).

Audit baseline: branch `Next`, commit `cb3c7ad` (2026-10-04).

---

## 1. Core concepts

| Concept | Meaning |
|---|---|
| **Unit** | One BoxTurtle AFC board on CAN. Index `u` = position in `global.AFC_unit_CAN_ids` (0-based). Up to 8. |
| **Lane** | One spool slot in a unit. Index `l` = 0..`AFC_unit_total_lanes[u]-1`. |
| **Tool** | One RRF tool per lane, numbered sequentially across units: unit 0 lanes first, then unit 1, etc. `Tool_to_AFC[t] = {u, l}` and `AFC_lane_to_tool[u][l] = t`. There is **no tool→lane remapping yet**: T3 is always that physical lane (P3-03 adds it). |
| **Head / printer tool** | The printer tool (`tool_and_motion[u][0]`) a unit feeds: its heater, fans, offsets and axis mapping. Single-tool printers have one head; an IDEX printer has two (see §1.2). |
| **AFC extruder** | One extra RRF extruder **per head**, appended after the printer's own extruders in order of first use (`AFC_head_extruder[printerTool]`; single head = `#global.Machine_extruder_info`, i.e. usually **E1**). Every tool is a *mixing tool* `D{the head's printer extruders…, its AFC extruder}`. At load time the AFC extruder's *driver* is remapped (`M584 E`) to the lane's stepper and the mix is set to 1 per drive, so the lane motor pushes in sync with the toolhead extruder. On unload the AFC extruder's ratio becomes 0. |
| **`'f` axis** | A lowercase temporary axis. `axis_setup.g` re-points it at the current lane's driver for non-printing filament moves (load to hub, homing to switches, unload). **All moves go through `lane_motion_begin.g` (map, unhide, disarm Longboi triggers, find the OM index → `AFC_f_axis`) and `lane_motion_end.g` (free the endstop, hide, re-arm)**; failures use `afc_error.g`, which calls `lane_motion_end.g`. The same driver can be assigned to `'f` and the AFC extruder at the same time; only one of them is moved at once. |
| **Machine vs AFC settings** | `Machine_*` globals = printer geometry/features (one set). `AFC_*` globals = per-unit arrays indexed `[u]` or `[u][l]`. |

### 1.1 Filament coordinate model (`'f` axis, per lane)

All lane lengths are measured with the `'f` axis and share this frame:

```
 spool ── prep sw ── LOAD SW ─────────── HUB SW ───────── bowden ───────── TN sw / extruder sw ── extruder ── cutter ── nozzle
                       0                    │                                   │
                       │<── AFC_lanes[u][l][1] "first length" (park) ──>│       │
                       │                (= load→hub − AFC_hub_retract_distance) │
                       │<────────── AFC_lanes[u][l][2] "total length" ────────────────>│
                                     (= park→TN trigger − AFC_tn_retract_distance, method 0/1;
                                        = park→extruder switch, method 2)
```

* `Lane - Measure First` sets 0 at the load switch and stores `[1]`.
* `Lane - Measure Main Length` measures from `[1]` to the toolhead sensor and adds the same offset to every lane of that unit (`[2] = [1] + offset`).
* Idle lane = filament parked at `[1]` (just behind the hub switch).
* Loaded tool = filament at `[2]` plus whatever the toolhead extruder pulled in.

Toolhead distances (printer-wide) are in `Machine_extruder_measurements = {input→nozzle, input→cutter, cutter→nozzle}`.

### 1.2 Heads and multi-tool / IDEX (P2-06, decision D5)

* A unit feeds **one** printer tool: `tool_and_motion[u][0]` (set in `<u>/AFC_user_vars.g`; default 0). On an IDEX printer put the units of the left head on T0 and the right head on T1.
* `gather_machine_info.g` snapshots every printer tool (extruders, fans, heaters, `tools[].axes`, `tools[].offsets`) before `calculate_tools.g` redefines tools `0..N-1` as AFC tools.
* `calculate_tools.g` gives each head its own AFC extruder (`AFC_head_extruder[pt]`), so both heads can hold filament at once, and defines every lane tool with `D{printer tool's extruders…, head AFC ext}`, the printer tool's `H`/`F`, its **axis mapping** (`X`/`Y`, e.g. U also moves X on IDEX) and its **offsets** (`G10 X Y Z`).
* `extruder_setup.g` remaps only the AFC extruder of the tool's head (it re-issues the whole `M584 E` list, the other extruders keep their current OM values), then `M567` with one ratio per drive.
* tpost/tfree address the AFC extruder as the tool's **last drive**.
* Stage 1 (done): IDEX in **one motion system** (classic U-axis IDEX; all tool changes on the job channel). Stage 2 (not done, needs an IDEX tester): motion system 1 – `'f` must not be used by both systems at once (lock global), tool changes for system 1 on File2. `tool_and_motion[u][1]` is reserved for it; config_check warns when it is not 0.
* Needs hardware verification: `M584 E` list with several AFC extruders; `G10`/`M563 X Y` on the redefined tools; `M567` per tool.

---

## 2. File layout on the SD card

```
0:/sys/
├── config.g                    (user's; must end with  G4 S2 / M98 P"0:/sys/AFC/AFC.g")
├── daemon.g                    ← repo sys/daemon.g  (spool-usage tracker)   [repo root daemon.g is a dead duplicate, B12]
├── start_print.g, start_after_delay.g, stop.g
├── tpre.g / tpost.g / tfree.g  ← GENERATED by macros/Create System Files (thin wrappers)
├── trigger<N>.g                ← GENERATED (lane prep triggers + buffer triggers)
├── home'f.g                    ← GENERATED
├── filament-error<N>.g         ← GENERATED (never executed by RRF ≥3.4, B09)
└── AFC/
    ├── AFC.g                   boot entry point
    ├── AFC_Units_Setup.g       per-unit defaults + derived numbering (release file, don't edit)
    ├── AFC_Unit_Count.g        user: CAN ids + lane counts (copied from .example)
    ├── Machine_Vars_Setup.g    printer defaults (release file, don't edit)
    ├── <u>/AFC_user_vars.g     user per-unit overrides (from 0/…example), called with A<u>
    ├── Machine/Machine_user_vars.g  user printer overrides
    ├── Status/status.g         GENERATED persistence (lanes, LEDs, current tool)
    ├── Status/spool_status.g   GENERATED persistence (spool id per lane)
    └── Macros/*.g              internal macros
0:/macros/                       user-facing DWC macros (Lane -, Spool -, Test -, Create System Files)
0:/spools/<id>.g                 one file per spool (JSON comment line + `set global.spool_load_temp = {…}`)
```

---

## 3. Boot sequence

```
config.g (end)
 └─ G4 S2 ; M98 AFC/AFC.g
     ├─ if !exists(global.AFC_settings_loaded):            (only first run after reset)
     │    ├─ Macros/gather_machine_info.g   snapshot tools[] and move.extruders[] → Machine_actual_tools, Machine_extruder_info
     │    ├─ AFC_Units_Setup.g              loads AFC_Unit_Count.g (or defaults {119,},{4,}); builds ALL AFC_* arrays,
     │    │                                  tool↔lane maps, trigger/input numbering, pin strings, M291 menus, spool arrays
     │    ├─ Machine_Vars_Setup.g           Machine_* defaults, Machine_features, Machine_axis_number, Gcode_* globals
     │    └─ global AFC_settings_loaded = true
     ├─ for u: <u>/AFC_user_vars.g A<u>     (if present)
     ├─ Machine/Machine_user_vars.g          (if present)  ← NOTE: re-declares `var brush…` and re-sets Machine_features
     ├─ for u: Macros/AFC_setup.g A<u>      M569 dir per lane; M950 J prep switch; M581 lane trigger (R2 = only when NOT printing)
     ├─ Macros/calculate_tools.g            one AFC extruder per head; M584/M350/M92/M906/M566/M203/M201 E…; M563 one tool per lane (+ X/Y mapping, G10 offsets)
     ├─ (Machine_features[8]==1) M950 J<AFC_unload_input_numbers[0]> C<extruder switch>; M574 E<i> P<J> for every extruder
     ├─ for u, port: M950 E… (neopixels)
     ├─ Status/status.g                     restore AFC_lanes, AFC_LED_array, AFC_loaded_tool (nothing is reselected silently, D3)
     ├─ Status/spool_status.g               restore global.spool_tracking[u][l] = {id, flag} (old files: global.spoolman → migrated and rewritten)
     ├─ Macros/spool_read_all.g             load 0:/spools/<id>.g → spool_active_data; sync AFC_lanes[..][4]
     ├─ Macros/leds.g                       paint LEDs
     ├─ AFC_boot_check_pending = true
     └─ Macros/config_check.g               one M118 per configuration problem + one summary box (never blocks)

sys/daemon.g (≥10 s after boot, no job): Macros/boot_check.g  → dialog: keep / unload / leave a tool that was loaded at power-off,
                                           or offer Lane - Unload to Hub for an occupied hub
```

`startup_check.g` is **not** part of boot in practice (B11; replaced in P3-02).

---

## 4. Tool change sequence (`T<n>`)

RRF runs: `tfree.g` (old tool, if one is active) → `tpre.g` (new) → tool becomes current → `tpost.g` (new).
The generated `0:/sys/t*.g` files only forward to `0:/sys/AFC/Macros/t*.g` with `A{state.nextTool}` /
`A{state.currentTool}`.

### 4.0 Failure handling (P2-01)

No macro in the tool-change path calls `abort` (it would cancel the print). A failure calls `afc_error.g S"…" T<tool> Q1 [F1]` and then `M99`:
the lane's DC motor stops, its hub J is freed, `'f` is released/hidden and the Longboi triggers re-armed (`lane_motion_end.g`), LED red, message, and during a print the print is **paused** (`M226` on the job channel – deferred until the tool-change macros have returned – or `M25` elsewhere).
`F1` sets `Machine_tpre_failed`; tpre and tpost then skip, so a failed unload never loads the next tool on top of it. Recovery is manual (fix, reselect the tool, resume).

### 4.1 Unload – `Macros/tfree.g A<t> [B<dc>] [C]`

```
resolve u,l from Tool_to_AFC; clear Machine_tpre_failed
heat to the lane temp (or 220) if the ACTUAL nozzle temperature is below lane temp-20 (≥180)
spool tracking (Machine_features[7]): deduct extruded since baseline, spool_write.g
home if needed
unless C: cut.g (Machine_features[1]); park.g A0 (Machine_features[3])
disarm buffer triggers (M581 R-1) + unmap TN pins
LED → blue (2), leds.g
retract out of hotend:
   Machine_features[8]==0: G1 E-(input→cutter or input→nozzle)+5
   Machine_features[8]==1: G1 H1 E-(input→nozzle+20): stops when the extruder input switch (bound at boot, M574 E) goes inactive; verified, else afc_error
M591 D<tool's last drive> P0  (disable filament monitor)
extruder_setup.g A<t> B0   (AFC extruder ratio 0)
lane_motion_begin.g A<t>   ('f → lane driver, unhidden, Longboi triggers off)
G92 'f{[2]}
optional DC motor reverse
unload method AFC_features[u][1]:
   0 (hub switch): M574 'f1 = inverted hub; G1 H4 'f{[1]-100} until hub opens (verified); G1 'f-hub_retract
   1 (lengths):    G1 'f{[1]}; then M574 'f2 = hub; H4 forward ≤[1]+hub_retract+50, verified; back off hub_retract (B49)
DC off; LED green (1); save_status.g A1; lane_motion_end.g (frees the 'f endstop, hides 'f); Machine_last_tool = currentTool
```

### 4.2 Load – `Macros/tpre.g A<t>`

```
skip if Machine_tpre_failed (tfree failed)
resolve u,l; home if needed; M568 A2
lane not loaded → afc_error "No filament loaded in Unit u Lane l" (B15)
hub switch must read empty, else afc_error
set temp from AFC_extruder_temp[u][l] or 220; M116
lane_motion_begin.g; G92 'f{[1]}; LED blue
G1 'f+hub_load_distance[0]; check hub switch; up to 5 retries of +hub_load_distance[1]; afc_error on failure
load method AFC_features[u][2] (each bounded to [2]+100 mm and verified with sensors.endstops[AFC_f_axis]):
   0 load_with_turtleneck.g  H4 to TN advance switch, back off tn_retract (H2), extruder_setup B1
   1 load_with_length.g      G1 'f{[2]} absolute, extruder_setup B1
   2 load_with_preload.g     H4 to Machine_extruder_switches[0] (afc_error if "nil"), extruder_setup B1
lane_motion_end.g
```

### 4.3 Prime/clean – `Macros/tpost.g A<t> [B1 = skip heating]`

```
if Machine_tpre_failed: clear flag, M568 A0, message, M99   (never T, never abort)
heat; M116
G92 E0; spool tracking baseline snapshot (before the prime, B30)
prime: input→cutter (cut enabled) or input→nozzle: fast to distance-10, last 10 mm at AFC_load_retract_speed[u][2] (B47)
poop.g (features[4]); kick.g (features[2])
LED blue; leds.g
map TN advance/trail pins to buffer J inputs; M581 R1 S1 + S0 (only while printing) → trigger<buffer>.g sets M567 0.95 / 1.05 / 1.0
M591 P1 on the tool's AFC extruder with lane LOAD switch as runout sensor
park.g A1 (features[3]); purge.g A<park||poop> (features[5]); brush.g (features[0])
report time
save_status.g  (status.g records AFC_loaded_tool)
G1 R2 X0 Y0 Z5, then G1 R2 Z0   (B07)
```

---

## 5. Lane insertion (auto-load to park)

```
prep switch rises (filament inserted)  ── only when NOT printing (M581 R2)
 └─ 0:/sys/trigger<N>.g  (generated): if !AFC_lanes[u][l][0] → Macros/triggers.g A<t>
     ├─ axis_setup.g; (Longboi: disable all lane triggers during motion)
     ├─ M574 'f1 = load switch; if not already triggered: G1 H1 'f500 F2100 → G92 'f0
     │    └─ if triggered: AFC_lanes[u][l][0]=true; move to 'f{[1]} (park); LED green; save_status
     └─ cleanup endstop, M18 'f, hide, (Longboi: re-arm triggers)
```

## 6. Runout / filament error (P3-01, P3-03, P3-04)

```
tpost: M591 P1 D<the tool's AFC extruder> C<lane load switch> S1
load switch opens while printing → RRF filament event → runs 0:/sys/filament-error.g (generated; D = extruder number)
   → Macros/filament-error.g: M25 (RRF does not pause when the file exists) and wait for 'paused'
   → T-1 (tfree pulls the tail back), lane marked empty (LED red, spool unassigned)
   → infinite spool: AFC_lane_backup[u][l] loaded?  tool_map_swap (the same T number now draws from the backup lane)
     else menu: reload this lane (prep switch polled; R2 triggers do not fire while paused) / use another lane / leave paused
   → T<n> (tpre/tpost for the mapped lane) → M24
```

### 6.1 Tool → lane map (P3-03)

`AFC_tool_map[t] = {u,l}` is the lane RRF tool `t` draws from (default = `Tool_to_AFC`). tpre/tpost/tfree/extruder_setup/load_with_* and the buffer triggers resolve lanes through it; lane macros (Measure, Unload, triggers, dc_motors, afc_error) use the static lane identity (`Tool_to_AFC` / `AFC_lane_to_tool`). `Lane - Map Tool` swaps two tools' lanes (only lanes of units feeding the same head); it is persisted in status.g.

## 7. Buffer (TurtleNeck) during print

Two TN switches per unit (advance = `AFC_TN_switches[u][0]`, trailing = `[1]`) are mapped to
`AFC_buffer_input_numbers[u]` in tpost and armed with `M581 … R1 S1` **and `S0`** (both edges; only while printing). The generated
`trigger<buffer0>.g` reads the input: active → `buffer_mix.g` factor 0.95 (feed less), released → 1.0; `trigger<buffer1>.g`: active → 1.05, released → 1.0.
An M581.1 expression trigger per unit (`AFC_buffer_fault_triggers`) pauses the print when both switches are active at once.
A low-spool M581.1 trigger (`AFC_lowspool_trigger`, `Machine_low_spool`) warns once when the current spool is nearly empty.

## 8. Spool tracking (feature flag `Machine_features[7]`)

* Spool records: `0:/spools/<id>.g` (ids 0–99 are scanned). Schema (12 fields, see GLOBALS.md `spool_active_data`).
* Assignment per lane: `global.spool_tracking[u][l] = {spoolId, trackingActiveFlag}` persisted in `Status/spool_status.g` (an old file that sets `global.spoolman` is migrated at boot).
* `tpost` snapshots `move.extruders[filamentExtruder].position` into `spool_extrusion_baseline[t]` after `G92 E0`, before the prime.
* `sys/daemon.g` (every ~10 s) deducts extrusion beyond the high-water mark `spool_extrusion_baseline[t]` from `spool_active_data[u][l][5]`, writes the spool file every 1000 mm.
* `tfree` deducts the remainder and writes the spool file.
* No network Spoolman integration exists (despite docs).

## 9. Persistence formats

`0:/sys/AFC/Status/status.g` (rewritten by `save_status.g` on most state changes):
```
; This records the status of each lane
set global.AFC_lanes[0][0] = {true,512.3,1890.4,0,{"PLA","Red"}}
…
set global.AFC_LED_array[0] = {1,1,0,0}            (single unit)  |  set global.AFC_LED_array = {{…},{…}}  (multi)
set global.AFC_loaded_tool = 2                         (-1 when no tool is loaded)
```
`0:/sys/AFC/Status/spool_status.g` (rewritten by `spool_save_status.g`, called at the end of `save_status.g`):
```
; Automatically generated spool assignments
set global.spool_tracking[0][0] = {7, false}
```
`0:/spools/<id>.g` (written by `Spool - Create`, `spool_write.g`):
```
; {"id": 7, "type": "PLA", "color": "Red", "manuf": "eSUN", "initial": 330000, "remaining": 254123.4, "first": "…", "last": "…", "hex": "#FF0000", "price": 0.0, "empty": 200.0, "density": 1.24}
set global.spool_load_temp = {7, "PLA", "Red", "eSUN", 330000, 254123.4, "…", "…", "#FF0000", 0.0, 200.0, 1.24}
```

## 10. Call graph (who calls whom)

```
AFC.g → gather_machine_info, AFC_Units_Setup(→AFC_Unit_Count), Machine_Vars_Setup, <u>/AFC_user_vars, Machine_user_vars,
        AFC_setup, calculate_tools, Status/status.g, Status/spool_status.g,
        spool_read_all(→0:/spools/<id>.g), leds, config_check
sys/daemon.g → boot_check(→tool_load_no_files→extruder_setup, T<n> P0 / T-1, Lane - Unload to Hub), spool_write
sys/tfree.g(gen) → tfree → spool_write, cut, park, leds, extruder_setup, lane_motion_begin(→axis_setup), dc_motors, save_status(→spool_save_status), lane_motion_end
sys/tpre.g(gen)  → tpre  → lane_motion_begin(→axis_setup), debug, load_with_turtleneck|load_with_length|load_with_preload (→extruder_setup), lane_motion_end
every failure in the above → afc_error(→dc_motors, lane_motion_end, leds)
sys/tpost.g(gen) → tpost → poop(→debug), kick(→debug), leds, park(→debug, brush_safe_deploy), purge, brush(→debug, brush_deploy, brush_retract, brush_safe_retract), save_status
sys/trigger<N>.g(gen) → triggers → lane_motion_begin/end, leds, save_status
filament-error.g (not wired) → tfree, unload(→axis_setup, dc_motors, "Spool - Unassign", leds, save_status), tpre, tpost
start_print.g → start_after_delay, T<n>      stop.g → T-1
macros/Lane - Unload → unload               macros/Lane - Mark Unloaded → Spool - Unassign, leds, save_status
macros/Lane - Measure First / Main Length → lane_motion_begin/end, dc_motors, save_status, afc_error
macros/Lane - Unload to Hub → lane_motion_begin/end, dc_motors, leds, save_status, afc_error
macros/Spool - Assign → 0:/spools/<id>.g, save_status;  Spool - Unassign → save_status;  Spool - Inventory → 0:/spools/*.g
macros/Test - DC Motor → dc_motors;  Test - LEDs → leds
root daemon.g (dead) → startup_check (broken) → T…, Lane - Mark Unloaded, Spool - Unassign
```

Unreferenced: `step_through_macro.g` (no callers), `AFC_unload_input_numbers` (allocated, never used),
`Machine_tip_*` (no tip-forming implementation).
