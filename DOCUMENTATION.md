# BoxTurtle RRF - Full Documentation

## Table of Contents

1. [Overview](#overview)
2. [Hardware Requirements](#hardware-requirements)
3. [Software Requirements](#software-requirements)
4. [File Reference](#file-reference)
5. [Setup Guide](#setup-guide)
6. [Configuration Reference](#configuration-reference)
7. [Slicer Setup](#slicer-setup)
8. [System Architecture](#system-architecture)
9. [Feature Notes](#feature-notes)

---

## Overview

BoxTurtle_RRF is a RepRapFirmware (RRF) implementation of the BoxTurtle Automated Filament Control (AFC) system. It enables
multi-material printing on RRF-based printers by automating filament loading, unloading, tool changing, cutting, and purging
across multiple lanes.

Each lane holds one filament spool. Every lane is an RRF tool (`T0`, `T1`, …). When the slicer asks for a tool change, the system
unloads the current filament (cutting or forming a tip first), loads the new filament from its lane through the bowden tube to the
hotend, primes it and cleans the nozzle before the print resumes.

> Multiple AFC units are supported via CAN bus. Up to 8 units can be configured, each with its own CAN address and lane count.

> **Status:** this code has been reviewed against the RRF source and checked with a linter. Several parts have not yet run on a
> printer (see the README, "Hardware status"). Report problems with the console output and `0:/sys/AFC/Status/afc.log`.

---

## Hardware Requirements

- A Duet 3 mainboard running RepRapFirmware 3.7 or later (the AFC unit is a CAN expansion board)
- One or more BoxTurtle AFC units (AFC-Lite v1.0/v1.1 or Longboi variant), flashed with a compatible version of RRF
- CAN bus connection between the mainboard and the AFC units
- Per lane:
  - Stepper motor for filament drive
  - Prep switch (filament inserted) and load switch (filament at the lane exit)
  - Neopixel LEDs (status indication)
- Per unit:
  - Hub switch (detects filament at the hub)
  - Turtleneck (TN) buffer with advance and trailing switches
- Optional hardware:
  - Extruder input switch (used by load method 2 and by initial unload method 1)
  - DC motor for filament drive assist
  - Filament cutting blade/pin, or tip forming
  - Purge bucket with wiper (kick)
  - Nozzle brush (manual or servo-driven)

---

## Software Requirements

- **RepRapFirmware 3.7 or later.** The macros use 3.7 array literals (`[ ]`), `M574 E` extruder endstops, `M581.1` expression
  triggers, `move.motionSystems[]` and `pressAdv`.
- **DuetWebControl** — for running setup/calibration macros from the web interface
- **OrcaSlicer** (recommended) — other RRF-compatible slicers can be used with manual G-code configuration
- Your own `config.g` must define the printer (axes, heaters, fans, tool 0 or your IDEX tools) before it calls `AFC.g`
- For runout recovery and for the cut/kick/purge moves, a `pause.g`/`resume.g` pair that saves and restores the head position

---

## File Reference

### Root Files

| File | Description |
|------|-------------|
| `README.md` | Quick-start guide |
| `DOCUMENTATION.md` | This file |
| `LICENSE` | Project license |
| `btncmd.json` | BtnCmd (DuetWebControl plugin) button layout for unit 0 / 4 lanes: Unload, Mark Unloaded, Measure per lane, Measure Main Length. |
| `.gitignore` | Keeps your own configuration (`AFC_Unit_Count.g`, `AFC_user_vars.g`, `Machine_user_vars.g`) and the generated `Status/` folder out of git |

---

### sys/AFC/ — Core System

These files live in `0:/sys/AFC/` on the printer's SD card and form the core of the AFC system.

#### `AFC.g`
**Primary initialization macro.** Called once at startup from `config.g`. Loads the defaults, your overrides, initialises the motor
drivers and lane triggers, defines one tool per lane, restores the saved lane and spool state, paints the LEDs and checks the
configuration. Add the following at the very end of `config.g`:
```
G4 S2
M98 P"0:/sys/AFC/AFC.g"
```

#### `AFC_Units_Setup.g` and `Machine_Vars_Setup.g`
**Release files with every default. Do not edit them** (updates overwrite them): put your settings in the user files below.
`AFC_Units_Setup.g` builds the per-unit arrays (pins, trigger and input numbers, speeds, lane lengths, tool maps…);
`Machine_Vars_Setup.g` holds the printer-wide settings. See [Configuration Reference](#configuration-reference).

#### Your configuration files (create them from the examples)

| Example | Your file | Description |
|------|------|-------------|
| `AFC/AFC_Unit_Count.example` | `AFC/AFC_Unit_Count.g` | CAN address and lane count of each unit, e.g. `[119]` / `[4]` (single-element arrays are written `[x]`) |
| `AFC/0/AFC_user_vars-AFC_Lite-4_lanes.example` | `AFC/0/AFC_user_vars.g` | Per-unit settings for an AFC-Lite. One folder per unit (`0`, `1`, …) |
| `AFC/0/AFC_user_vars-Longboi-4_lanes.example` | `AFC/0/AFC_user_vars.g` | Per-unit settings for a Longboi |
| `AFC/Machine/Machine_user_vars.example` | `AFC/Machine/Machine_user_vars.g` | Printer geometry, feature flags and positions. **Every line is active**: delete the lines you do not want to change |

#### `AFC/Status/status.g`, `spool_status.g` *(auto-generated)*
`status.g` records lane state, LEDs, the loaded tool, the tool→lane map, backup lanes and filament colours; `spool_status.g` the
spool assigned to each lane. Do not edit them. `afc.log` / `afc.old.log` in the same folder are the AFC event log.

---

### sys/AFC/Macros/ — Operation Macros

Internal macros. They are not meant to be called directly (the user macros call them).

#### Tool change core (called by the generated `tpre.g`, `tpost.g`, `tfree.g`)

| File | Description |
|------|-------------|
| `tfree.g` | **Unload** the current tool: heat if needed, update spool usage, cut (or form a tip) and park, retract from the hotend, pull the filament back to the lane's park position. |
| `tpre.g` | **Load**: feed the lane to the hub switch (retrying), then load with the unit's load method up to the toolhead. |
| `tpost.g` | **Prime and clean**: heat, prime, poop/kick, arm the buffer sensors and the runout monitor, park/purge/brush, restore the print position (including Z). |
| `load_with_turtleneck.g`, `load_with_length.g`, `load_with_preload.g` | Load methods 0 (feed to the TN advance switch), 1 (feed a measured length), 2 (feed to the extruder input switch). Every search move is bounded and verified. |
| `lane_motion_begin.g`, `lane_motion_end.g` | Every filament move on the temporary `'f` axis is wrapped in these: map and unhide the axis, disarm the Longboi triggers; and the reverse (free the endstop, hide the axis, re-arm the triggers). |
| `afc_error.g` | **The single error exit.** Cleans up (DC motor, pins, axis), turns the lane LED red, logs, shows a message and — during a print — **pauses** the print. Nothing in the tool change calls `abort`, because that would cancel the print. |
| `tool_map_swap.g` | Makes a tool use another lane (see Tool → lane mapping). |

#### Filament operations

| File | Description |
|------|-------------|
| `cut.g` | Executes a filament cut against a fixed blade/pin (multi-pass, optional rip-back, current boost and pushback). The configuration is validated before anything moves; the pressure advance is saved and restored. |
| `tip_form.g` | Tip forming for printers without a cutter (ramming, cooling moves, optional skinny dip). Off by default (`Machine_tip_forming`). |
| `poop.g` | Purges filament into a bucket with coordinated Z movement. The length comes from the slicer (tuned by `Machine_purge_length_modifier` / `_addition`) or the default, plus the old filament stub when a cutter is used. |
| `purge.g` | Final prime of the tip. Runs only when park or poop moved the head to a safe place. |
| `kick.g` | Sweeps the toolhead to knock the purge blob off the nozzle. |
| `brush.g` | Wipes the nozzle. If your brush needs deploy/retract moves, create `brush_deploy.g` / `brush_retract.g` (and the `brush_safe_*` pair) in this folder from the `*.g.example` files. |
| `park.g` | Moves the toolhead to the park position. |

#### Hardware control

| File | Description |
|------|-------------|
| `leds.g` | Paints the Neopixels from `AFC_LED_array`: one command per lane segment. Colours: red = empty/error, green (or the lane's filament colour) = ready, blue = busy / in the toolhead, yellow = needs attention. |
| `hex_to_rgb.g` | Converts `#RRGGBB` for the LEDs. |
| `dc_motors.g` | Optional DC motor assist (speed from `AFC_dc_speed`; PWM below full speed). |
| `axis_setup.g` | Points the temporary `'f` axis at a lane's stepper. |
| `extruder_setup.g` | Maps a lane's stepper to the AFC extruder of the tool's printer head and sets the mix (1:1 on load, 0 on unload). |
| `buffer_mix.g` | Sets the lane's share of the mix for the buffer (TurtleNeck) triggers. |

#### Initialization, checks and persistence

| File | Description |
|------|-------------|
| `AFC_setup.g` | Applies the driver direction and the lane prep-switch triggers for each lane. |
| `gather_machine_info.g`, `calculate_tools.g` | Snapshot of your printer's tools (extruders, heaters, fans, axis mapping, offsets) and creation of one tool per lane — one AFC extruder per printer head. |
| `config_check.g` | At boot: lists settings that would fail during a tool change (positions, missing switches, unmeasured lanes, wrong driver ids, missing CAN boards…). |
| `boot_check.g`, `startup_check.g` | Run by `sys/daemon.g` after boot: ask what to do with a tool that was loaded at power-off or filament left in a hub; with the "start check" feature also verify every lane against its switches. |
| `validate_job.g` | Called by `start_print.g`: checks that the lanes the job needs are loaded, measured and (with spool tracking) have enough filament. |
| `save_status.g`, `spool_save_status.g`, `spool_read_all.g`, `spool_write.g` | Persistence of lane state and spool data. |
| `afc_log.g`, `debug.g` | Event log and optional debug output (`Machine_debug`). |
| `set_temp_global.g` | Called by the slicer's change-filament G-code: stores the next tool's temperature (and purge length). |
| `triggers.g`, `unload.g`, `filament-error.g`, `tool_load_no_files.g`, `step_through_macro.g` | Lane insertion, lane unload, runout recovery, restoring the extruder mapping of an already selected tool, and a debugging aid. |

---

### sys/ — Print Workflow

| File | Description |
|------|-------------|
| `start_print.g` | Called at the start of every print. Checks the lanes, sets temperatures, soaks if needed, homes and selects the first tool. |
| `stop.g` | Called when a print ends or is cancelled: fans off, raise, park, unload (`Machine_unload_on_cancel`), heaters and motors off. |
| `start_after_delay.g` | Used by `start_print.g` for a chamber soak. |
| `daemon.g` | Runs in the background every ~10 s: boot checks (once), spool usage tracking and the low-spool value. It replaces any `daemon.g` you have; merge your own if you need one. |

---

### macros/ — User-Facing Macros

Shown in DuetWebControl. Copy the folder to `0:/macros/`.

| Macro | Description |
|-------|-------------|
| `Create System Files` | Generates `tpre.g`, `tpost.g`, `tfree.g`, the trigger files (lane, buffer, fault, low spool), `home'f.g` and `filament-error.g`. **Run it after the first setup and whenever the unit/lane count changes.** |
| `Lane - Measure First` | Measures the load switch → hub distance and stores the park position. Run for every lane. |
| `Lane - Measure Main Length` | Measures hub → toolhead sensor (or lets you type it in for load method 1). Run once per unit. |
| `Lane - Report First Lengths`, `Lane - Report Main Lengths`, `Lane - Reset First Length` | Show / reset the stored lengths. |
| `Lane - Mark Loaded`, `Lane - Mark Unloaded` | Fix the record of a lane by hand. |
| `Lane - Unload`, `Lane - Unload to Hub` | Pull a lane's filament back onto the spool / just clear the hub. |
| `Lane - Park` | Re-park a lane after handling it by hand, or park every lane whose prep switch sees filament. |
| `Lane - Set Filament` | Type, colour name, `#RRGGBB` and temperature of a lane. |
| `Lane - Map Tool` | Choose which lane a slicer tool uses (swap), show or reset the mapping. |
| `Lane - Set Backup` | Choose the lane that takes over when a lane runs out (infinite spool). |
| `Spool - Create`, `Delete`, `Assign to Lane`, `Unassign`, `Inventory`, `Report` | Spool records in `0:/spools/<id>.g`. |
| `Test - DC Motor`, `Test - Hub Switch`, `Test - LEDs`, `Test - Turtleneck` | Hardware tests. |

---

## Setup Guide

### 1. Flash the AFC unit
Use a version of RRF that matches your mainboard and the BoxTurtle documentation. The mainboard needs RRF 3.7 or later.

### 2. Copy the files
Copy `sys/` to `0:/sys/` and `macros/` to `0:/macros/`. The repository does not contain your own configuration files.

### 3. CAN addressing
Copy `0:/sys/AFC/AFC_Unit_Count.example` to `0:/sys/AFC/AFC_Unit_Count.g` and set the CAN ID and lane count of each unit.

### 4. Per-unit settings
For each unit create `0:/sys/AFC/<unit>/AFC_user_vars.g` (unit 0 → folder `0`) from the matching `.example` (AFC-Lite or Longboi) and
edit: driver numbers (**always written `0.0, 0.1, 0.2, 0.3`**, never `0,1,2,3`), motion settings, switch pins, load/unload method
(`AFC_features[unit] = [useDC, unloadMethod, loadMethod]`), and `tool_and_motion` for an IDEX printer.

### 5. Machine settings
Copy `0:/sys/AFC/Machine/Machine_user_vars.example` to `Machine_user_vars.g`. Enable the features you have (`brush`, `cut`, `kick`,
`park`, `poop`, `purge`, `start`, `spool_tracking`, `initial_unload` at the top of the file) and set their positions. Positions
that are still `-1` for an enabled feature, or outside the axis limits, are reported at boot.

### 6. config.g
Add `G4 S2` and `M98 P"0:/sys/AFC/AFC.g"` at the **very end** of `config.g`.

### 7. Reboot, then run **Create System Files** (All)

### 8. Load and calibrate each lane
Insert filament until the lane parks it. Run **Lane - Measure First** for each lane, then **Lane - Measure Main Length** once per unit.

### 9. Test
Use the **Test -** macros, then do a manual `T0`, `T1`, `T-1` cycle before printing. Reboot once more: `config_check` reports remaining problems.

### 10. Brush (optional)
Copy the `*.g.example` brush files in `0:/sys/AFC/Macros/` to the same names without `.example` and edit them for your printer.

---

## Configuration Reference

### Per-unit settings (`AFC_user_vars.g`)

| Parameter | Description |
|-----------|-------------|
| `tool_and_motion` | `[printerTool, motionSystem]`: the printer tool (head) the unit feeds. Default `[0, 0]`; IDEX: left head `0`, right head `1` |
| `AFC_mainboard` | 0 = AFC-Lite, 1 = Longboi |
| Driver ids, microsteps, steps/mm, current, jerk, speed, acceleration | Per lane stepper settings |
| `AFC_load_retract_speed` | `[load, unload, extruderLoad]` mm/s |
| `AFC_hub_retract_distance`, `AFC_hub_load_distance`, `AFC_tn_retract_distance` | Back-off after the hub / TN trigger; first hub probe move (must be larger than the retract distance) |
| `AFC_features` | `[useDC, unloadMethod (0 hub switch, 1 lengths), loadMethod (0 turtleneck, 1 lengths, 2 extruder switch)]` |
| Pins | prep, load, hub, TN switches, SLP/DC pins, neopixel strips |
| Trigger / input numbers | allocated automatically (see `docs/maintainers/HARDWARE_RESOURCES.md`) |
| `AFC_dcm_out_no`, `AFC_dc_speed`, `AFC_dc_freq`, `AFC_dc_load_assist` | Output numbers for the DC motor pins (must be free in `config.g`), duty cycle, PWM frequency, assist while loading |

### Per-machine settings (`Machine_user_vars.g`)

| Parameter | Description |
|-----------|-------------|
| `Machine_travel_speed` | XY and Z speed of the cleaning moves (mm/s) |
| `Machine_debug` | Verbose debug output |
| `Machine_log` | AFC event log in `0:/sys/AFC/Status/afc.log` |
| `Machine_extruder_measurements` | Input → nozzle, input → cutter, cutter → nozzle (mm) |
| `Machine_extruder_switches` | Extruder input / output switch pins (main board), `"nil"` if none |
| Features (`var brush … var initial_unload`) | Enable brush, cut, kick, park, poop, purge, start check, spool tracking, initial unload |
| `Machine_cut_*` | Cut position, direction, distances, speeds, passes, rip, pushback, stepper currents |
| `Machine_purge_*`, `Machine_part_cooling_fan` | Poop position, speed, length, modifier/addition, fan |
| `Machine_kick`, `Machine_brush`, `Machine_park` | Positions and speeds |
| `Machine_tip_forming`, `Machine_tip_*` | Tip forming without a cutter |
| `Machine_unload_on_cancel` | Unload the tool when a print is cancelled |
| `Machine_low_spool` | Warn when a spool has less than this many mm left (0 = off) |
| `Machine_soak_time`, `Machine_filament_soak`, `Machine_nozzle_diameter` | Used by `start_print.g` |

---

## Slicer Setup

OrcaSlicer is the recommended slicer. Follow the BoxTurtle initial startup guide for general slicer configuration:
https://github.com/ArmoredTurtle/BoxTurtle/blob/main/Initial_Startup.md#configuring-your-slicer

### Machine Start G-Code

```
M104 S0 ; Stops OrcaSlicer from sending temperature waits separately
M140 S0 ; Stops OrcaSlicer from sending temperature waits separately
M98 P"start_print.g" A{first_layer_bed_temperature[0]} B"{filament_type[0]}" C{first_layer_temperature[0]} D{nozzle_diameter[0]} E{first_layer_print_min[0]} F{first_layer_print_max[0]} H{first_layer_print_min[1]} J{first_layer_print_max[1]} K{initial_tool}
```
Optionally add `L"…"` (one character per tool, `1` = used) to name the tools the job uses; otherwise the filament usage in the file
header is used.

### Change Filament G-Code

```
M98 P"0:/sys/AFC/Macros/set_temp_global.g" A[next_extruder] B[new_filament_temp] C[flush_length]
T[next_extruder]
```
`A` and `B` set the next tool's temperature, `C` (optional) the purge length in mm for this change; check which placeholder your
slicer version provides.

---

## System Architecture

A longer description for maintainers is in `docs/maintainers/ARCHITECTURE.md`.

### Boot Sequence

```
config.g
  └─ AFC.g
       ├─ gather_machine_info.g   (snapshot of your printer's tools)
       ├─ AFC_Units_Setup.g       (loads AFC_Unit_Count.g, builds the per-unit arrays)
       ├─ Machine_Vars_Setup.g    (printer defaults)
       ├─ <unit>/AFC_user_vars.g, Machine/Machine_user_vars.g   (your settings)
       ├─ AFC_setup.g             (driver direction, lane triggers)
       ├─ calculate_tools.g       (one AFC extruder per head, one tool per lane)
       ├─ Status/status.g, Status/spool_status.g, spool_read_all.g
       ├─ leds.g
       └─ config_check.g          (lists configuration problems)

sys/daemon.g (every ~10 s):  boot_check.g once (loaded tool / hub occupied), then startup_check.g if "start check" is on;
                             spool usage tracking
```

### Tool Change Sequence

RRF runs `tfree.g` (old tool) → `tpre.g` (new tool) → `tpost.g` (new tool).

```
T[n]
  └─ tfree.g  (unload the previous filament)
       ├─ heat if too cold
       ├─ spool usage → spool_write.g
       ├─ cut.g / tip_form.g, park.g
       ├─ retract from the hotend
       └─ pull the filament back to the lane (lane_motion_begin/end), save_status.g

  └─ tpre.g   (load the lane the tool is mapped to)
       ├─ lane to the hub switch (retries)
       └─ load_with_turtleneck.g | load_with_length.g | load_with_preload.g

  └─ tpost.g  (prime and clean)
       ├─ heat, prime
       ├─ poop.g, kick.g (if enabled)
       ├─ arm buffer sensors and the runout monitor
       ├─ park.g, purge.g, brush.g (if enabled)
       └─ restore the print position (X Y, then Z)
```

A failure anywhere calls `afc_error.g`: the lane LED turns red, the print is **paused** with a message, and the rest of that tool
change is skipped. Fix the problem, reselect the tool and resume.

### Filament runout

The load switch of the current lane is the runout sensor. When it opens during a print, `0:/sys/filament-error.g` runs
`filament-error.g`: pause, unload the tail (`T-1`), mark the lane empty, then either continue on the lane's backup lane (infinite
spool) or ask: reload this lane / use another lane / leave it paused. The tool is then reselected and the print resumes.

### Tool → lane mapping and backup lanes

`Tool_to_AFC` is the fixed numbering (tool 3 = lane 3). `AFC_tool_map` is the lane a tool actually uses (default the same). **Lane -
Map Tool** swaps two tools' lanes, for example to change which spool a colour comes from without re-slicing. Both lanes must feed
the same printer head. **Lane - Set Backup** names the lane that takes over when a lane runs out. Both are saved in `status.g`.

### LED Status Colours

| Colour | Meaning |
|--------|---------|
| Green / the filament colour | Lane ready, filament loaded |
| Blue | Busy, or the lane in the toolhead |
| Red | Empty or error |
| Yellow | Needs attention (for example a tool left loaded at power-off) |

### Persistence

| File | Contents |
|------|----------|
| `0:/sys/AFC/Status/status.g` | Lane state and lengths, LEDs, loaded tool, tool map, backup lanes, filament colours |
| `0:/sys/AFC/Status/spool_status.g` | Spool-to-lane assignments |
| `0:/spools/[id].g` | Per-spool record and remaining length |
| `0:/sys/AFC/Status/afc.log` | AFC event log (previous boot: `afc.old.log`) |

---

## Feature Notes

### Cutting and tip forming
A cutter is recommended. Without one, enable `Machine_tip_forming` and tune the `Machine_tip_*` values; `tfree.g` then forms a
tip before it retracts.

### Brush
See `brush.g` above: the shipped deploy/retract macros are examples of the author's printer.

### Spool tracking
With `spool_tracking` enabled, filament used by each lane is deducted from the spool record assigned to it (`Spool - Assign to
Lane`) and saved to the SD card. There is no connection to a Spoolman server: the data is local. `Machine_low_spool` adds a warning.

### Filament runout
See the section above. It needs a `resume.g` that moves the head back to the pause position.

### Multi-tool / IDEX
Give each unit the printer tool (head) it feeds in `tool_and_motion[unit][0]`. Each head gets its own AFC extruder and each lane
tool inherits that head's heater, fans, offsets and axis mapping. One motion system is supported.

### Debug and log
Set `Machine_debug = true` for step-by-step console output. Errors, tool change times and runouts are written to the AFC log when
`Machine_log` is true.
