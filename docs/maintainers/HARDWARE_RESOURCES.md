# Hardware resource allocation

RRF resources are global and finite: GPIO input numbers (`M950 J`), triggers (`M581 T`), output numbers (`M950 P`),
servo numbers (`M950 S`), LED strips (`M950 E`), endstops per axis (`M574`). A pin can only be bound to **one**
resource at a time. Most AFC bugs that look like "pin already in use" come from a macro exiting without freeing a pin.

## 1. Default pin map (per unit, `<CAN>` = `AFC_unit_CAN_ids[u]`)

| Function | AFC-Lite (default) | Longboi example | Prefix | Global |
|---|---|---|---|---|
| Lane drivers | `<CAN>.0 … <CAN>.3` | same | – | `AFC_steppers[u][l][0]` (float + 0.0001) |
| DC sleep | `SLP1..4` | | | `AFC_SLP_pins` |
| DC in1 / in2 | `dc11..14` / `dc21..24` | | | `AFC_DC_pins` |
| Prep switch (entry) | `SW2..5` | `SW1,4,5,8` | `^!` | `AFC_prep_switch` |
| Load switch | `SW7..10` | `SW2,3,6,7` | `^` | `AFC_load_switch` |
| TN advance / trailing | `SW11` / `SW12` | `SW15` / `SW16` | none | `AFC_TN_switches[u]` |
| Hub switch | `SW1` | `SW14` | `^` | `AFC_hub_switch[u]` |
| Neopixels | `neopixel1`, 4 LEDs, 1/lane, type 2 | `neopixel2`,`neopixel3`, 12 LEDs each, 6/lane, type 1, port 0 reversed | | `AFC_neopixel` |
| Extruder input/output switch | main board, user-set | | | `Machine_extruder_switches` |
| Brush servo | `0.PE6` default | | | `Machine_brush[9]` |

## 2. Number allocation (computed in `AFC_Units_Setup.g`)

Allocated sequentially across units in this order. Example: **one 4-lane unit** / **two 4-lane units**.

| Block | Rule | 1×4 | 2×4 |
|---|---|---|---|
| Lane triggers `AFC_trigger_numbers` (M581 T) | start 2, one per lane | 2-5 | 2-9 |
| Buffer triggers `AFC_buffer_trigger_numbers` | 2 per unit after last lane trigger | 6,7 | 10,11 / 12,13 |
| Buffer fault triggers `AFC_buffer_fault_triggers` (M581.1) | 1 per unit after the last buffer trigger | 8 | 14 / 15 |
| Low-spool trigger `AFC_lowspool_trigger` (M581.1) | 1, after the fault triggers | 9 | 16 |
| Lane prep inputs `AFC_trigger_input_numbers` (M950 J) | start 0, one per lane | 0-3 | 0-7 |
| Buffer inputs `AFC_buffer_input_numbers` | 2 per unit after last lane J | 4,5 | 8,9 / 10,11 |
| Hub inputs `AFC_hub_input_numbers` | 1 per unit after last buffer J | 6 | 12 / 13 |
| Unload inputs `AFC_unload_input_numbers` | 1 per unit after hubs | 7 (unused) | 14/15 (unused) |
| DC outputs `AFC_dcm_out_no` (M950 P) | fixed `{0,1,2}` shared by all lanes | 0,1,2 | 0,1,2 |
| Neopixel strips (M950 E) | start 0, one per port | 0 | 0 / 1 |
| Brush servo (M950 S) | `Machine_brush[12]` | 10 | 10 |

Triggers 0 and 1 are left for RRF's emergency stop / pause. **Users with their own `M950 J`, `M581`, `M950 P` in
config.g must check for collisions** (the example user-vars comments show stale numbers, B53).

## 3. Lifecycle of each binding

| Resource | Bound | Freed | Notes |
|---|---|---|---|
| Prep switch → J lane, trigger R2 | AFC_setup.g (boot) | Longboi only: disarmed by `lane_motion_begin.g`, re-armed by `lane_motion_end.g` (tpre, tfree, triggers, unload, Measure*, Unload to Hub) | R2 → trigger only when not printing |
| Hub switch → J hub | tpre, Measure Main Length, Unload to Hub, boot_check, Test - Hub Switch, startup_check | same macro; afc_error frees it for its tool's unit | must be free before used as `'f` endstop |
| Hub switch → `'f` endstop | tfree (both methods), Measure First, Unload to Hub, startup_check | same macro / `lane_motion_end.g` | an axis has one endstop object, so any `M574 'f… P"nil"` frees it (B08 was a false alarm) |
| Load switch → `'f1` endstop | triggers.g, unload.g, Measure First | `lane_motion_end.g` | inverted (`!`) when retracting |
| Load switch → filament monitor (M591 P1) | tpost (`D` = the tool's last drive) | tfree (`M591 D<same> P0`) | B32 fixed |
| TN switches → J buffer + trigger R1 (**S1 and S0**, both edges) | tpost | tfree | the generated buffer trigger reads the input and sets 0.95 / 1.05 / 1.0 |
| TN advance → `'f2` endstop | load_with_turtleneck, Measure Main Length | same macro / `lane_motion_end.g` | conflicts with J buffer binding if a tool is still active – tfree frees first |
| Extruder switch → `'f2` endstop | load_with_preload, Measure Main Length | same / `lane_motion_end.g` | |
| Extruder switch → J `AFC_unload_input_numbers[0]` + `M574 E<i>` for **every** extruder | AFC.g (boot), when `Machine_features[8]==1` | never (stays bound) | tfree: `G1 H1 E-x` stops when the input goes inactive. Every extruder needs it: a moving extruder without an input endstop gets a stall-detection endstop (EndstopsManager::EnableExtruderEndstops). One switch is shared by all heads |
| DC pins → P0..2 | dc_motors F/R | dc_motors O | |
| Servo → S | brush.g / purge.g | brush.g / purge.g | |
| `'f` axis | axis_setup (created once, remapped every call); unhidden by lane_motion_begin | never deleted; hidden by lane_motion_end (also on every afc_error path) | |

## 4. The `'f` axis

* Created by the first `M584 'f<driver>`; afterwards each call re-points it to a different lane driver.
* The OM index of `'f` is detected at run time by lane_motion_begin.g (`move.axes[i].letter == "f"` → `global.AFC_f_axis`); no
  user setting (B34 fixed).
* Visible-axis count is toggled only in axis_setup, lane_motion_begin (`M584 P{#move.axes}`) and lane_motion_end
  (`M584 P{#move.axes-1}`, only while `'f` is visible). afc_error calls lane_motion_end, so no failure path leaves `'f` visible (B44).
* Limits `M208 'f-500 S1` / `'f20000 S0`. Several macros command `G1 H4 'f-20000` from `G92 'f20000`; H-moves are
  exempt from limit checks, also under RRF 3.7's "out-of-limit moves are errors" rule (verified, RRF_NOTES §2).
