# BoxTurtle RRF - Full Documentation

## Table of Contents

1. [Overview](#overview)
2. [Hardware Requirements](#hardware-requirements)
3. [Software Requirements](#software-requirements)
4. [File Reference](#file-reference)
   - [Root Files](#root-files)
   - [sys/AFC/ — Core System](#sysafc--core-system)
   - [sys/AFC/Macros/ — Operation Macros](#sysafcmacros--operation-macros)
   - [sys/ — Print Workflow](#sys--print-workflow)
   - [macros/ — User-Facing Macros](#macros--user-facing-macros)
5. [Setup Guide](#setup-guide)
6. [Configuration Reference](#configuration-reference)
7. [Slicer Setup](#slicer-setup)
8. [System Architecture](#system-architecture)
9. [Feature Notes](#feature-notes)

---

## Overview

BoxTurtle_RRF is a RepRapFirmware (RRF) implementation of the BoxTurtle Automated Filament Control (AFC) system. It enables multi-material printing on RRF-based printers by automating filament loading, unloading, tool changing, cutting, and purging across multiple lanes.

Each lane holds one filament spool. When a tool change is requested by the slicer, the system retracts and cuts the current filament, loads the new filament from its lane through the bowden tube to the hotend, primes it, and cleans the nozzle before resuming the print.

> Multiple AFC units are supported via CAN bus. Up to 8 units can be configured, each with its own CAN address and lane count.

---

## Hardware Requirements

- A RepRapFirmware-compatible mainboard (Duet 3 series recommended)
- One BoxTurtle AFC unit (AFC-Lite v1.0/v1.1 or Longboi variant), flashed with a compatible version of RRF
- CAN bus connection between the mainboard and AFC unit
- Per lane:
  - Stepper motor for filament drive
  - Load switch (detects filament presence at lane entry)
  - Neopixel LED (status indication)
- Per unit:
  - Hub switch (detects filament at the extruder hub)
- Optional hardware:
  - Turtleneck sensor (at extruder entrance)
  - Preload switch (detects filament compression)
  - DC motor for filament drive assist
  - Filament cutting blade/pin
  - Purge bucket with wiper (kick)
  - Nozzle brush (manual or servo-driven)
  - Buffer advance/trail sensors (bowden pressure monitoring)

---

## Software Requirements

- **RepRapFirmware 3.6 or later** — earlier versions lack required features
- Required RRF features:
  - Conditional macro execution (`if`/`while` statements)
  - Global variable support (`global`)
  - Trigger system (`M581`, `M950`)
  - Tool definitions and switching (`T` commands)
  - Neopixel LED support (`M950 E`)
  - Filament monitors (`M591`)
  - CAN communication
- **DuetWebControl** — for running setup/calibration macros from the web interface
- **OrcaSlicer** (recommended) — for slicer integration. Other RRF-compatible slicers can be used with manual gcode configuration.

---

## File Reference

### Root Files

| File | Description |
|------|-------------|
| `README.md` | Quick-start guide |
| `DOCUMENTATION.md` | This file |
| `LICENSE` | Project license |
| `btncmd.json` | DuetWebControl button/menu configuration. Provides quick-access buttons in the web interface for common AFC operations. |
| `daemon.g` | RRF daemon macro. Runs in the background on a timed loop, monitoring filament status and triggering alerts. Copy to `0:/sys/daemon.g`. |

---

### sys/AFC/ — Core System

These files live in `0:/sys/AFC/` on the printer's SD card and form the core of the AFC system.

#### `AFC.g`
**Primary initialization macro.** Called once at startup from `config.g`. Loads all sub-configurations, initializes motor drivers, configures LEDs, restores lane states from saved status files, and makes the system ready for operation.

Add the following at the very end of your `config.g` to invoke it:
```
G4 S2
M98 P"0:/sys/AFC/AFC.g"
```

#### `AFC_Units_Setup.g`
Defines the physical hardware layout: how many AFC units are present, their CAN addresses, how many lanes each has, and how motor axes are mapped. Edit this file to match your hardware.

#### `Machine_Vars_Setup.g`
Defines machine-specific parameters that apply to the printer as a whole rather than the AFC unit itself. This includes travel speeds, hotend/extruder geometry, debug mode, and feature enable/disable flags. See [Configuration Reference](#configuration-reference) for the full list of settings.

#### Configuration Examples

| File | Description |
|------|-------------|
| `AFC/0/AFC_user_vars-AFC_Lite-4_lanes.example` | Example per-unit config for AFC-Lite with 4 lanes. Copy to `AFC/0/AFC_user_vars.g` and edit. |
| `AFC/0/AFC_user_vars-Longboi-4_lanes.example` | Example per-unit config for the Longboi variant with 4 lanes. |
| `AFC/AFC_Unit_Count.example` | Template for defining CAN IDs and lane counts for up to 8 units. Copy to `AFC/AFC_Unit_Count.g` and edit. |
| `AFC/Machine/Machine_user_vars.example` | Template for machine-specific overrides. Copy to `AFC/Machine/Machine_user_vars.g` and edit. |

#### `AFC/Status/status.g` *(auto-generated)*
Stores the current load state and measured lengths for each lane. Written automatically by the system. Do not edit manually.

#### `AFC/Status/spool_status.g` *(auto-generated)*
Stores which spool is assigned to which lane. Written automatically by the system.

---

### sys/AFC/Macros/ — Operation Macros

These are internal macros called by the system during operation. They are not intended to be called directly by the user.

#### Tool Change Core (called by the slicer)

| File | Description |
|------|-------------|
| `tpre.g` | **Tool Pre-Change.** Maps the target lane's stepper to a temporary axis, homes it to the load switch, feeds filament through the bowden tube, detects it at the hub switch, then hands off to the appropriate load method macro. |
| `tpost.g` | **Tool Post-Change.** Heats the nozzle to target temperature, primes filament from the extruder input to the nozzle, then runs any enabled cleaning routines (poop, kick, brush). Re-enables buffer sensors and restores print position with a Z-hop. |
| `tfree.g` | **Tool Unload.** Disables buffer sensors, retracts filament from the melt zone, runs the cutter if enabled, withdraws filament back to the lane, updates spool tracking with the amount of filament used, saves system state, and sets the lane LED green. |

#### Load Methods

One of these is called by `tpre.g` depending on the configured `load_method`:

| File | `load_method` value | Description |
|------|---------------------|-------------|
| `load_with_turtleneck.g` | `0` | Feeds filament until the turtleneck sensor triggers. Requires a turtleneck sensor fitted. |
| `load_with_length.g` | `1` | Feeds a fixed, calibrated length of filament. No additional sensor needed beyond the hub switch. |
| `load_with_preload.g` | `2` | Feeds filament until the preload switch triggers, indicating filament has been compressed into the extruder. |

#### Filament Operations

| File | Description |
|------|-------------|
| `cut.g` | Executes a filament cut against a fixed blade/pin. Performs multiple passes with progressively increased motor current for clean cuts. Supports an optional rip-back move after cutting. |
| `poop.g` | Purges filament into a waste bucket with coordinated Z movement to form a "blob" that can be knocked free. Includes pressure release moves. |
| `purge.g` | Basic purge routine. Complements `poop.g` for simpler purge scenarios. |
| `kick.g` | Engages a mechanical wiper to knock the purge blob clear of the nozzle. |
| `brush.g` | Deploys and retracts the nozzle brush for wiping. If your brush has its own deploy/retract logic (e.g., servo-based), create `brush_deploy.g` and `brush_retract.g` in the AFC folder and they will be called automatically. |
| `park.g` | Moves the toolhead to a safe park position. |

#### Hardware Control

| File | Description |
|------|-------------|
| `leds.g` | Controls the Neopixel LED strip. Sets lane colours based on status: green = ready, blue = active, red = error. |
| `dc_motors.g` | Controls optional DC motor assists during loading and unloading. |
| `axis_setup.g` | Temporarily maps a lane's stepper motor to a virtual axis (`f`) so it can be moved with standard motion commands during a tool change. |
| `extruder_setup.g` | Maps extruder drive numbers to tool numbers for multi-tool setups. |

#### Initialization & Calculation

| File | Description |
|------|-------------|
| `AFC_setup.g` | Applies motor driver configuration (`M569`) for each lane based on the unit settings. Called by `AFC.g` at startup. |
| `calculate_tools.g` | Builds internal mappings between tool numbers, AFC units, and lane numbers. Also handles IDEX setups. |
| `gather_machine_info.g` | Reads tool, extruder, heater, and fan configuration from the running firmware and stores it for use by other macros. |
| `startup_check.g` | Checks system state at boot. If filament is detected at the hub when no lane is loaded, triggers an automatic unload to clear the path. |

#### Spool & Status Persistence

| File | Description |
|------|-------------|
| `spool_read_all.g` | Reads all active spool assignments and filament lengths from SD card into RAM at startup. |
| `spool_write.g` | Writes a single spool's updated filament length back to its file on SD card after a tool change. |
| `spool_save_status.g` | Saves the full spool assignment table for all lanes. |
| `save_status.g` | Saves lane load state and measured lengths to `Status/status.g`. |

#### Monitoring & Diagnostics

| File | Description |
|------|-------------|
| `triggers.g` | Handles real-time filament runout and buffer sensor triggers during printing. |
| `filament-error.g` | Called when a filament detection failure occurs. Pauses the print and alerts the user. |
| `debug.g` | Conditional debug logging. When debug mode is enabled in `Machine_user_vars.g`, macros emit detailed output to the console. |
| `step_through_macro.g` | Allows manually stepping through a macro one command at a time. Used for debugging and development. |

---

### sys/ — Print Workflow

These files live directly in `0:/sys/` and are called by the slicer or by other macros.

| File | Description |
|------|-------------|
| `start_print.g` | Called at the start of every print by the slicer. Accepts parameters for bed temperature, first layer hotend temperature, filament type, nozzle diameter, and print area. Sets temperatures, soaks the chamber if needed, and loads the initial tool. |
| `stop.g` | Called at the end of every print (or on cancel). Retracts filament, parks the toolhead, turns off heaters and motors, and saves system state. |
| `start_after_delay.g` | Used internally by `start_print.g` when a chamber soak delay is configured. |

---

### macros/ — User-Facing Macros

These macros are shown in DuetWebControl and are intended to be run manually during setup, calibration, and maintenance. Copy the entire `macros/` folder to `0:/macros/` on the SD card.

#### System Setup

| Macro | Description |
|-------|-------------|
| `Create System Files` | Auto-generates `tpre.g`, `tpost.g`, `tfree.g`, trigger files, and homing files based on your current configuration. **Run this first after initial setup.** |

#### Lane Calibration

These macros must be run for each lane before printing. Load filament into a lane before running them.

| Macro | Description |
|-------|-------------|
| `Lane - Measure First` | Moves filament from the load switch to the hub switch and records the distance. This must be run for every lane. |
| `Lane - Measure Main Length` | Measures the full bowden tube length from lane to extruder. Only needs to be run once — choose any lane. |
| `Lane - Report First Lengths` | Displays the calibrated first-segment lengths for all lanes. |
| `Lane - Report Main Lengths` | Displays the full tube lengths for all lanes. |
| `Lane - Reset First Length` | Resets a lane's first-segment measurement. Use before re-measuring. |
| `Lane - Mark Loaded` | Manually marks a lane as having filament loaded. |
| `Lane - Mark Unloaded` | Manually marks a lane as empty. |
| `Lane - Unload` | Fully unloads filament from a lane back to the spool. |
| `Lane - Unload to Hub` | Retracts filament only as far as the hub switch, leaving it partially loaded. |

#### Spool Management

| Macro | Description |
|-------|-------------|
| `Spool - Create` | Creates a new spool record with a given ID and initial filament length. |
| `Spool - Delete` | Removes a spool record from the system. |
| `Spool - Assign to Lane` | Associates a spool ID with a specific lane so filament usage is tracked against it. |
| `Spool - Unassign` | Removes the spool assignment from a lane. |
| `Spool - Inventory` | Displays all spools in the system with their IDs and remaining lengths. |
| `Spool - Report` | Displays detailed information for a specific spool. |

#### Hardware Testing

Run these macros to verify that components are working correctly before printing.

| Macro | Description |
|-------|-------------|
| `Test - DC Motor` | Runs the optional DC motor assist briefly to confirm it responds. |
| `Test - Hub Switch` | Reads and reports the state of the hub switch sensor. |
| `Test - LEDs` | Cycles colours on the Neopixel LEDs to verify they are wired correctly. |
| `Test - Turtleneck` | Tests the turtleneck sensor by checking its input state. |

---

## Setup Guide

Follow these steps in order when setting up BoxTurtle_RRF for the first time.

### 1. Flash the AFC Unit

Ensure the BoxTurtle AFC unit is flashed with a version of RRF compatible with this firmware package. Refer to the BoxTurtle hardware documentation for the correct firmware version.

### 2. Copy Files to the Printer

- Copy everything in the repository's `sys/` folder to `0:/sys/` on the printer's SD card.
- Copy everything in the repository's `macros/` folder to `0:/macros/` on the printer's SD card.

### 3. Configure CAN Addressing

Rename `0:/sys/AFC/AFC_Unit_Count.example` to `0:/sys/AFC/AFC_Unit_Count.g` and edit it to set the correct CAN ID and lane count for your AFC unit.

### 4. Configure the AFC Unit

For each AFC unit, create a per-unit user vars file:

- Navigate to `0:/sys/AFC/0/` (for the first unit)
- Choose the example file that matches your hardware variant:
  - `AFC_user_vars-AFC_Lite-4_lanes.example` for AFC-Lite
  - `AFC_user_vars-Longboi-4_lanes.example` for Longboi
- Rename it to `AFC_user_vars.g`
- Edit it to match your motor driver numbers, current settings, speeds, sensor pin numbers, and feature flags

### 5. Configure Machine Settings

- Copy `0:/sys/AFC/Machine/Machine_user_vars.example` to `0:/sys/AFC/Machine/Machine_user_vars.g`
- Edit it to match your printer geometry (extruder distances, cut position, purge position, brush position, etc.)

### 6. Update config.g

Add the following to the **very end** of your `config.g`, after all other configuration:

```
G4 S2
M98 P"0:/sys/AFC/AFC.g"
```

### 7. Enable Features

In your `Machine_user_vars.g`, set the global feature flags to enable the options you have fitted:

| Feature | Flag | Notes |
|---------|------|-------|
| Brush | `global.AFC_brush` | Requires brush hardware |
| Cut | `global.AFC_cut` | Strongly recommended |
| Kick | `global.AFC_kick` | Requires purge bucket wiper |
| Park | `global.AFC_park` | Safe position moves |
| Poop | `global.AFC_poop` | Requires purge bucket |
| Purge | `global.AFC_purge` | Basic purge |
| Startup check | `global.AFC_startup_check` | Clears hub blockages at boot |
| Spoolman | `global.AFC_spoolman` | External spool tracking |

Also set your load and unload methods:

| Setting | Value | Description |
|---------|-------|-------------|
| `global.AFC_load_method` | `0` | Load using turtleneck sensor |
| `global.AFC_load_method` | `1` | Load using calibrated length |
| `global.AFC_load_method` | `2` | Load using preload switch |
| `global.AFC_unload_method` | `0` | Unload using hub switch |
| `global.AFC_unload_method` | `1` | Unload using measured lengths |

### 8. Reboot and Generate System Files

Reboot the printer. Once AFC.g has run successfully, open DuetWebControl, go to the Macros panel, and run **Create System Files**, selecting all options. This generates the tool change files (`tpre.g`, `tpost.g`, `tfree.g`) and trigger files tailored to your configuration.

### 9. Load and Calibrate Each Lane

For each lane:

1. Load filament manually until it reaches the load switch.
2. Run **Lane - Measure First** for that lane.

Then run **Lane - Measure Main Length** once (any lane). This calibrates the full bowden tube length used by the length-based load method.

### 10. Configure the Brush (if applicable)

If your brush uses a servo or motor for deployment, create two macros in the AFC folder:

- `0:/sys/AFC/brush_deploy.g` — commands to deploy the brush
- `0:/sys/AFC/brush_retract.g` — commands to retract the brush

The AFC system calls these automatically. If your brush is always deployed or controlled by other means, you do not need these files.

### 11. Reboot and Test

Reboot the printer. Use the **Test -** macros to verify LEDs, hub switch, and any other sensors. Then perform a manual tool change to verify the full load/unload cycle before starting a multi-material print.

---

## Configuration Reference

### Per-Unit Settings (`AFC_user_vars.g`)

| Parameter | Description |
|-----------|-------------|
| Motor driver numbers | Which RRF driver numbers are assigned to each lane's stepper |
| Microstepping | Stepper microstepping resolution |
| Motor current | Run and hold current for lane steppers |
| Jerk / speed / acceleration | Motion limits for filament moves |
| Load speed / distance | How fast and how far to move filament during loading |
| Unload speed / distance | How fast and how far to move filament during unloading |
| Trigger numbers | RRF trigger indices for each sensor input |
| Input pin mappings | Which GPIO pins the sensors are connected to |
| DC motor enable | Whether DC motor assist is present on this unit |
| Load method | Which loading strategy to use (0/1/2) |
| Unload method | Which unloading strategy to use (0/1) |

### Per-Machine Settings (`Machine_user_vars.g`)

| Parameter | Description |
|-----------|-------------|
| XY travel speed | Speed for non-printing moves |
| Z travel speed | Speed for Z moves |
| Debug mode | Enables verbose console output for troubleshooting |
| Input-to-nozzle distance | Length from extruder input to nozzle tip |
| Input-to-cutter distance | Length from extruder input to cutter blade |
| Cutter-to-nozzle distance | Length from cutter blade to nozzle tip |
| Cut location (X/Y) | Toolhead position for cutting |
| Cut direction | Which axis the cut move is on |
| Cut passes | Number of cutting passes |
| Purge location (X/Y/Z) | Toolhead position for purging |
| Purge amount | Volume (mm³) of filament to purge |
| Kick location | Position for wiper engagement |
| Brush location | Position for nozzle brushing |
| Brush passes | Number of brush strokes |
| Soak time | Chamber heat soak duration in seconds |
| Soak filament types | Which filament types trigger a chamber soak |
| Nozzle diameter | Expected nozzle size for validation |

---

## Slicer Setup

OrcaSlicer is the recommended slicer. Follow the BoxTurtle initial startup guide for general slicer configuration:
https://github.com/ArmoredTurtle/BoxTurtle/blob/main/Initial_Startup.md#configuring-your-slicer

### Machine Start G-Code

Add the following to your machine start G-code in OrcaSlicer. This suppresses OrcaSlicer's own temperature commands (the AFC start macro handles heating) and passes all required parameters to `start_print.g`:

```
M104 S0 ; Stops OrcaSlicer from sending temperature waits separately
M140 S0 ; Stops OrcaSlicer from sending temperature waits separately
M98 P"start_print.g" A{first_layer_bed_temperature[0]} B"{filament_type[0]}" C{first_layer_temperature[0]} D{nozzle_diameter[0]} E{first_layer_print_min[0]} F{first_layer_print_max[0]} H{first_layer_print_min[1]} J{first_layer_print_max[1]} K{initial_tool}
```

### Change Filament G-Code

Add the following to the change filament G-code section. This sets the upcoming tool's target temperature and then triggers the tool change:

```
M98 P"0:/sys/AFC/set_temp_global.g" A[next_extruder] B[new_filament_temp]
T[next_extruder]
```

---

## System Architecture

### Boot Sequence

```
config.g
  └─ AFC.g
       ├─ AFC_Unit_Count.g        (how many units, CAN IDs)
       ├─ AFC_Units_Setup.g       (lane/motor layout)
       ├─ Machine_Vars_Setup.g    (machine geometry and features)
       ├─ gather_machine_info.g   (reads tool/extruder/heater info)
       ├─ calculate_tools.g       (builds tool-to-lane mappings)
       ├─ AFC_setup.g             (applies motor driver config)
       ├─ leds.g                  (initializes LEDs)
       ├─ spool_read_all.g        (loads spool data from SD)
       └─ startup_check.g         (clears hub if blocked)

daemon.g  (runs periodically in background)
```

### Tool Change Sequence

```
Slicer emits T[n]
  └─ tpre.g  (load next filament)
       ├─ axis_setup.g
       ├─ load_with_turtleneck.g  OR
       │  load_with_length.g      OR
       │  load_with_preload.g
       └─ (filament now at extruder input)

  └─ tpost.g  (prime and clean)
       ├─ (heat nozzle)
       ├─ (prime)
       ├─ poop.g   (if enabled)
       ├─ kick.g   (if enabled)
       ├─ brush.g  (if enabled)
       └─ park.g   (if enabled)

  └─ tfree.g  (unload previous filament, runs before tpre on next change)
       ├─ (retract from melt zone)
       ├─ cut.g    (if enabled)
       ├─ park.g   (if enabled)
       ├─ (unload to lane)
       ├─ spool_write.g
       └─ save_status.g
```

### LED Status Colours

| Colour | Meaning |
|--------|---------|
| Green | Lane ready, filament loaded |
| Blue | Lane active (currently in use) |
| Red | Error — filament detection failure |

### Persistence

The system saves state to the SD card so it survives reboots:

| File | Contents |
|------|----------|
| `0:/sys/AFC/Status/status.g` | Lane load states and calibrated lengths |
| `0:/sys/AFC/Status/spool_status.g` | Spool-to-lane assignments |
| `0:/spools/[id].g` | Per-spool remaining filament length |

---

## Feature Notes

### Cutting

A cutter is **strongly recommended**. Without one, there is no tip forming, and tool changes are likely to produce poor results. The `cut.g` macro performs multiple passes against a fixed blade with progressively increased motor current. An optional rip-back move helps seat the filament cleanly after cutting.

### Brush

If your brush is servo-controlled or otherwise needs active deployment, create `brush_deploy.g` and `brush_retract.g` in `0:/sys/AFC/`. These are called automatically by `brush.g`. If your brush is always in position (e.g., a fixed wiper), you do not need these files.

### Spoolman

When the Spoolman feature is enabled, the system tracks filament consumption per spool and can update a Spoolman server with remaining lengths after each tool change. Configure the Spoolman server address in `Machine_user_vars.g`.

### Filament Runout

Runout detection is handled by `triggers.g` via RRF's trigger system. When a runout is detected during printing, the print is paused and the user is alerted. This feature is implemented but currently untested.

### Debug Mode

Set `global.AFC_debug = true` in `Machine_user_vars.g` to enable verbose logging. All major macros emit step-by-step output to the DuetWebControl console when this is enabled. Disable for normal printing to reduce console noise.
