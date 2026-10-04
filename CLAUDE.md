# BoxTurtle_RRF – guide for Claude

RepRapFirmware (RRF) G-code macros that drive one or more BoxTurtle AFC (automated filament changer) units over CAN.
There is no compiled code: everything is RRF meta-G-code (`if/while/var/global/set`) executed on a Duet. Nothing here can
be run or unit-tested locally – reason from the code, the docs below and RRF semantics, and flag anything that needs
hardware verification.

## Read before changing anything
| File | Contents |
|---|---|
| [docs/maintainers/ARCHITECTURE.md](docs/maintainers/ARCHITECTURE.md) | Concepts (unit/lane/tool, AFC mixing extruder, `'f` axis, filament coordinate model), boot / tool change / insert / runout flows, persistence formats, call graph |
| [docs/maintainers/MACROS.md](docs/maintainers/MACROS.md) | Every file: purpose, params, callers, callees, side-effects, issue IDs |
| [docs/maintainers/GLOBALS.md](docs/maintainers/GLOBALS.md) | Every global: shape, index meanings, defaults, writers/readers |
| [docs/maintainers/HARDWARE_RESOURCES.md](docs/maintainers/HARDWARE_RESOURCES.md) | Pin map, trigger/J/output numbering, bind/free lifecycle |
| [docs/maintainers/RRF_NOTES.md](docs/maintainers/RRF_NOTES.md) | RRF language rules, OM units, 3.6/3.7 behaviour this code depends on |
| [docs/AUDIT.md](docs/AUDIT.md) | Issue tracker: bugs `Bxx`, improvements `Ixx`, gaps `Gxx`, RRF 3.7 adoption `Rxx`, doc errors `Dxx` |
| [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) | **Ordered task list for fixing/extending the macros** – follow it, ask the D1-D6 decisions first |

`README.md` and `DOCUMENTATION.md` are user-facing and partly wrong (AUDIT §5) – don't use them as a source of truth.

## Key invariants
- Tool `t` ↔ lane: `global.Tool_to_AFC[t] = {u,l}` is the static numbering (a lane's *native tool*), `global.AFC_lane_to_tool[u][l] = t` its inverse. Tool-change macros resolve the lane an RRF tool really uses through `global.AFC_tool_map[t]`; lane macros and `afc_error.g T` use the native tool. Never compute tool numbers by summing lane counts.
- Per-unit arrays are `[u]`, per-lane `[u][l]`. `#global.AFC_unit_CAN_ids` is the unit count.
- `AFC_lanes[u][l] = {loaded, firstLen, totalLen, continuous, {type, colour}}`; `spool_active_data[u][l]` always has **12** fields.
- `Machine_features` indices: 0 brush, 1 cut, 2 kick, 3 park, 4 poop, 5 purge, 6 start check, 7 spool tracking, 8 initial unload. `AFC_features[u]` = {useDC, unloadMethod, loadMethod}. Header comments in many macros list these wrongly – trust GLOBALS.md.
- Every macro that binds a pin (`M950 J/P/S`, `M574 'f… P`) must free it on **every** exit path. Filament moves on `'f` go through `lane_motion_begin.g`/`lane_motion_end.g` (the only places that unhide/hide the axis besides axis_setup); the OM index of `'f` is `global.AFC_f_axis`.
- **No `abort` in anything that can run during a print** (it cancels the print). Failures call `afc_error.g S"…" T<lane tool> Q1 [F1]` and then `M99`. The pause flag is `Q`: `M98` never forwards `P`. A macro that ran a nested step compares `global.AFC_error_count` before/after.
- Driver ids are floats `CAN.lane + 0.0001` – **keep the offset**: it forces a float, and an integer driver id in an array is read as main-board driver N (`119` → `0.119`). Write lane offsets as `0.0, 0.1, …`, never `0, 1, …`. Local drivers ≥10 can't be written as floats; strings are rejected.
- Object-model extruder `jerk`/`speed` are mm/s; `M566`/`M203` take mm/min.
- `sys/` files are copied to `0:/sys/`, `macros/` to `0:/macros/`. Paths are case-sensitive in SBC mode – match file names exactly.

## Verified RRF behaviour that is easy to get wrong (sources in RRF_NOTES.md)
- `abort` while printing **cancels the print** (also from tool-change macros) – use `afc_error.g` + `M226`/`M25` instead (plan P2-01).
- `M291 … J1` cancel ends the macro; `J2` cancel sets **`result` = -1** (`input` is undefined).
- `M581 … R2` triggers do not fire while a print is paused. `R-1` disables a trigger.
- `0:/sys/filament-error.g` is the only event file RRF runs (`param.D` = extruder); RRF does not pause when it exists.
- A normal `G1` to a target outside `M208` limits is an error in 3.7; H-moves are exempt.
- One endstop per axis: any `M574 'f… P"nil"` frees whatever `'f` endstop exists.
- Don't issue `T` inside tpre/tpost/tfree.

- Parameter values handed to a macro must start with a digit, `"`, `{`, `.`, `-` or `+`; `[ ]` is the array literal (3.7) – `{a,b}` still works but new code uses `[ ]`. `&&`/`||`/`?:` short-circuit.

## Verification tools (run before and after every change)
```
cd docs/maintainers/tools && npm install && node lint.mjs   # dwc-gcode-core lint at RRF 3.7.0-rc.2; baseline is now 0 findings – keep it there (new files are linted even when untracked)
python docs/maintainers/tools/check_locals.py        # undeclared var.x (the lint does not check locals)
python docs/maintainers/tools/xref_globals.py NAME   # who declares/sets/reads a global
node docs/maintainers/tools/cmd.mjs M591             # verified parameter list for a G/M code
```
For a question the tools can't answer, read RRF source (`Duet3D/RepRapFirmware`, `src/GCodes/…`) and the wiki
(`Duet3D/wiki-content`, `User_manual/Reference/Gcodes.md`) – see RRF_NOTES §6. Source wins over the wiki.

## Editing conventions
- Match the file's indentation style (spaces in `sys/AFC` and `macros/`, tabs in `sys/start_print.g`, `stop.g`, `start_after_delay.g`) and CRLF line endings. Indentation is block structure.
- G-code string parameters with concatenation go inside braces: `P{"Lane "^var.l}`.
- Check `exists(param.X)` before reading optional params; abort messages use `M291 P{"Aborting macro. Line "^line} R"<path>" S1` then `abort` (house style; see I07 for the planned replacement).
- Release-default files (`AFC_Units_Setup.g`, `Machine_Vars_Setup.g`) define every global; user files only `set` them. A new setting needs a default there, an entry in the matching `.example` and a row in GLOBALS.md.
- Generated files (`0:/sys/tpre.g`, `tpost.g`, `tfree.g`, `trigger*.g`, `home'f.g`, `filament-error*.g`) come from `macros/Create System Files` – fix the generator, not the output.
- **Minimum firmware is RRF 3.7** (user decision D1, 2026-10-04). Use `[ ]` arrays, array `^`, `move.motionSystems[0].*` and `pressAdv` in code you write or touch.
- The user's other decisions (pause on failure, boot check instead of silent tool reselect, tool→lane mapping, multi-tool/IDEX support, "spool tracking" naming) are in IMPLEMENTATION_PLAN.md §0.4.

## Keeping the docs true (do this in the same change)
1. Behaviour/params/callers changed → update the file's entry in MACROS.md (and ARCHITECTURE.md if a flow changed).
2. Global added/removed/re-shaped → update GLOBALS.md. Verify with `python docs/maintainers/tools/xref_globals.py [NAME…]`.
3. Pin/trigger/J/output usage changed → HARDWARE_RESOURCES.md.
4. Fixed an audit item → set its Status to `fixed <short-sha or description>` in docs/AUDIT.md; new problem found → add a row with the next free ID.
5. Line numbers in AUDIT.md drift – re-locate by searching for the quoted code, not by line number.

## Roadmap context
The audit (2026-10-04) is RRF-only and the whole IMPLEMENTATION_PLAN is implemented in the working tree (see the status block at its top
for deviations). **Nothing has run on a printer**: AUDIT §7 is the hardware checklist. Next planned phase: a feature-by-feature
comparison with the Klipper AFC implementation (ArmoredTurtle AFC-Klipper-Add-On); the open gaps (AUDIT §3) are the starting point.
