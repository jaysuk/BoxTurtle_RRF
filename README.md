# BoxTurtle_RRF

RepRapFirmware (RRF) support for the BoxTurtle Automated Filament Control (AFC). One or more BoxTurtle units on CAN
(up to 8) feed your printer through ordinary RRF tool changes (`T0`, `T1`, …).

**Requires RRF 3.7 or later** (the macros use 3.7 arrays, `M574 E`, `M581.1` and the `move.motionSystems` object model).
This is community software: it has been written against the RRF source and wiki and checked with a linter, but parts of it still
need testing on real hardware. Treat the first prints with care and read [Hardware status](#hardware-status).

## Features

* Automatic load / unload of every lane through `tpre.g`, `tfree.g` and `tpost.g` (turtleneck, measured-length or
  preload-switch loading; hub-switch or measured-length unloading)
* Filament cutter, kick, poop bucket, purge, park, brush (see Notes), and tip forming for printers without a cutter
* Per-lane temperatures and purge lengths from the slicer
* Failures **pause the print** with a message and a red LED instead of cancelling it
* Filament runout: pause, unload, then reload the lane, use another lane, or continue automatically on a **backup lane
  (infinite spool)**
* Tool → lane mapping: choose which physical lane a slicer tool uses
* Boot check: if a tool was loaded at power-off you are asked what to do (nothing is reselected silently)
* Spool tracking: each lane can have a spool record on the SD card; usage is deducted, with a low-spool warning
* Pre-print check of the lanes a job needs, LED colours that follow the filament colour, buffer (TurtleNeck) mix control
* IDEX / multi-head printers: each head gets its own AFC extruder (one motion system)

## How to use

1. Flash the AFC unit(s) and connect them to the printer's CAN bus.
2. Copy the repository's `sys/` folder to `0:/sys/` and `macros/` to `0:/macros/`.
   The files you edit yourself are **not** in the repository (they are in `.gitignore`); create them from the examples:
   * `0:/sys/AFC/AFC_Unit_Count.example` → `AFC_Unit_Count.g` (CAN address and lane count per unit)
   * `0:/sys/AFC/0/AFC_user_vars-<board>-4_lanes.example` → `0:/sys/AFC/0/AFC_user_vars.g` (one folder per unit: `0`, `1`, …)
   * `0:/sys/AFC/Machine/Machine_user_vars.example` → `Machine_user_vars.g` (printer geometry and the features you use)
3. Add the following to the very end of `config.g` (your own tools, heaters, fans and axes must be defined before it):

```text
G4 S2

M98 P"0:/sys/AFC/AFC.g"
```

4. Reboot. Run the macro **Create System Files** and select **All**.
5. Insert filament in each lane. Run **Lane - Measure First** for each lane, then **Lane - Measure Main Length** once per unit.
6. Reboot. Any problem with your settings is listed in the console (`AFC config: …`) after boot.

`start_print.g` and `stop.g` are included and are suitable for most printers.

## Slicer setup

OrcaSlicer is the recommended slicer; configure it as described in the
[BoxTurtle guide](https://github.com/ArmoredTurtle/BoxTurtle/blob/main/Initial_Startup.md#configuring-your-slicer).

Machine start G-code:

```text
M104 S0 ; Stops OrcaSlicer from sending temperature waits separately
M140 S0 ; Stops OrcaSlicer from sending temperature waits separately
M98 P"start_print.g" A{first_layer_bed_temperature[0]} B"{filament_type[0]}" C{first_layer_temperature[0]} D{nozzle_diameter[0]} E{first_layer_print_min[0]} F{first_layer_print_max[0]} H{first_layer_print_min[1]} J{first_layer_print_max[1]} K{initial_tool}
```

Change-filament G-code (`C` is optional: the purge length in mm for this tool change; use the placeholder your slicer offers):

```text
M98 P"0:/sys/AFC/Macros/set_temp_global.g" A[next_extruder] B[new_filament_temp] C[flush_length]
T[next_extruder]
```

`start_print.g` checks that every tool the job uses has a loaded, measured lane (and enough spool left); you can pass the used
tools explicitly with `L"1011"` (one character per tool).

## Notes

* **Brush:** if your brush needs deploy/retract moves, copy the `*.g.example` files in `0:/sys/AFC/Macros/`
  (`brush_deploy`, `brush_retract`, `brush_safe_deploy`, `brush_safe_retract`) to the same name without `.example` and edit them.
  They are the author's printer, not defaults.
* **Cutter:** strongly recommended. Without one, set `Machine_tip_forming = true` and tune the `Machine_tip_*` values.
* **Runout and recovery** need a `resume.g` that returns the head to the position saved by the pause (the unload moves the head).
* **Logging:** AFC events go to `0:/sys/AFC/Status/afc.log` (`Machine_log`).
* **Upgrading from an older version:** the first boot migrates `spool_status.g` automatically. An old `Status/status.g` that still
  selects a tool at boot will make the boot check ask what to do with it.
* The full reference is in [DOCUMENTATION.md](DOCUMENTATION.md); maintainers should read `docs/maintainers/` and `docs/AUDIT.md`.

## Hardware status

Verified by reading the RRF source and by lint only (not yet on a printer): the new error handling and pause, bounded search
moves, the extruder-input-switch unload (`G1 H1 E` with `M574 E` on a mixing tool), IDEX tool definitions, the runout handler,
the buffer triggers, the LED batching and tip forming. Please report what you find; the hardware test checklist for each change is
in `docs/IMPLEMENTATION_PLAN.md`.
