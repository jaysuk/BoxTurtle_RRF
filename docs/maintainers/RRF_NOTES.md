# RepRapFirmware notes for maintaining these macros

Facts that matter when editing this repo, **verified against RRF source** (`Duet3D/RepRapFirmware` branch `3.7-dev`
@ `72032c5`, 2026-10-02), the wiki (`Duet3D/wiki-content` `User_manual/Reference/Gcodes.md`) and
**dwc-gcode-core 1.36.0** (`jaysuk/dwc-gcode-core`, RRF baseline 3.7.0-rc.2). File:line references are to that RRF
commit. Re-verify after an RRF upgrade (see §6).

## 1. Meta-command language

| Rule | Source |
|---|---|
| Indentation is block structure. Mixed spaces/tabs inside one block only warns. Comment-line indentation is ignored (3.6+). | `StringParser.cpp` 392-441 |
| `if` sets the block to *ifTrue* or skips to the end of its indented body. A plain statement (`set`, G/M code) at the **same** indent does not reset that state, but finishing a skipped block does. So `if` + non-indented lines + `elif` works only when the `if` was **true**; when it was false RRF throws `'elif' did not follow 'if'` (extruder_setup.g:76-84, B18). | `StringParser.cpp` 405-420, 586-653 |
| `var x` inside a `while` body is deleted at the end of every iteration (`EndBlock` → `variables.EndScope`), so re-declaring per iteration is fine. Declaring a name that already exists in **any** enclosing scope throws `variable 'x' already exists` (calculate_tools.g:138, B19). | `GCodeMachineState.cpp` 376-386; `StringParser.cpp` 738-746 |
| `abort` → `GCodes::AbortPrint`: aborts **every** nested file on that channel, and if the channel is the print file (tool-change macros during a job run there) it calls `StopPrint(abort)` → **the print is cancelled**. | `StringParser.cpp` 851-878; `GCodes.cpp` 3507-3522 |
| Operators: `=`/`==`, `!=` (also `!==`, the extra `=` is swallowed), `&`/`&&`, `|`/`||`, `^` concatenation. | `ExpressionParser.cpp` ~395-420 |
| Arrays: `{e}` is a bracketed expression, **not** an array; `{e,}` single-element array; `{a,b}`; 3.7: `[e]`, `[]`, `[a,b]`. | `ExpressionParser.cpp` ParseExpectKet |
| `^` with two arrays concatenates them (3.7). Any other `^` converts both sides to text: arrays become `[…]` with string elements in `"…"` (embedded `"` **not** escaped). A string expression is limited to **256** chars (`MaxStringExpressionLength`); a G-code line to **255** usable chars. | `ExpressionParser.cpp` Concat 704-799; `ObjectModel.cpp` 30-182; `Configuration.h` 165 |
| `echo` prints each comma-separated expression with a space between; `>` overwrite, `>>` append, `>>>` append without newline. Opening a file for write creates missing folders. | `StringParser.cpp` ProcessEchoCommand; `FileStore.cpp` 85-95 |
| Inside quoted strings (G-code params and expressions): `""` → `"`; `''` → `'`; `'` + letter → that letter lower-cased and the apostrophe dropped ("Don't" → "Dont"). So `"home''f.g"` → `home'f.g`. | `StringParser.cpp` InternalGetQuotedString; `ExpressionParser.cpp` ParseQuotedString |
| Parameter letters: unescaped lowercase matches uppercase (`M208 … s1` = `S1`); `'f` selects lowercase axis f. | `StringParser.cpp` Seen 1276-1330 |
| A G-code parameter is either a literal or one `{expression}` – text after a closing quote is parsed as more parameters. `P"Lane "^{x}` is wrong; use `P{"Lane "^x}`. | gcode-core lint (`dictionary/wrong-kind`, `unknown-parameter`) |
| `M98 P"name"` relative path resolves to `0:/sys/`. **`P` is the file name and is never forwarded to the macro** (`StringParser::AddParameters`: `letter != 'P' \|\| codeRunning != 98`), so a macro cannot take a `P` parameter via M98. Parameter values must start with a digit, `"`, `{`, `.`, `-` or `+`. |
| `&&`, `\|\|`, `?:` short-circuit; `[e]` is a one-element array, `[]` empty, `{e}` a plain expression; `#` gives the length of a string or array. | `ExpressionParser.cpp` 248-272, 420-470, ApplyLengthOperator |
| `G1 H1/H4 E…` enables the input endstop of every extruder in the mix that has one (`M574 E<n> P<J>`) and a **stall-detection** endstop for every other moving extruder; extruders with mix 0 do not move. `M584` does not clear the `M574 E` inputs. | `GCodes.cpp` LoadExtrusionFromGCode, `EndstopsManager.cpp` 251-298, 395-430 |
| Triggers: one `M581` trigger holds a set of rising and a set of falling inputs, so `M581 P<J> T<n> S1` plus `S0` fires on both edges; `M581.1` expression triggers fire when the expression turns true and are disabled for good if it throws. | `TriggerItem.cpp` | Paths are case-insensitive on SD, case-sensitive in SBC mode. | – |

## 2. Commands used by this repo (verified)

| Command | Fact | Source |
|---|---|---|
| `M291` | `J1` = Cancel button; on cancel the **current macro** returns (if issued from the job file itself the print stops). Wiki says the whole file stack is terminated – source shows a single `FileMacroCyclesReturn`; don't rely on callers continuing. `J2` (3.6+) = Cancel, execution continues with **`result` = -1** (`input` undefined). `if input == -1` is never right. S3 cancel behaves like J1. | `GCodes7.cpp` 33-40, 120-154; `GCodeBuffer.cpp` 1306-1320; `GCodes.cpp` 530-555 |
| `M581` | `T` trigger, `P` J-input list (`P-1` deletes), `S1` rising / `S0` falling / `S-1` remove inputs, `R0` always, `R1` only when printing, `R2` only when not printing, **`R-1` disables** (keeps inputs). "Printing" = a job is active, **including while paused**, so R2 lane triggers never fire during a pause. T0/T1 can't have trigger files. | `TriggerItem.cpp` 39, 134-230; `PrintMonitor.cpp` 346-358; wiki M581 |
| `M574` | Exactly **one endstop object per axis**; any `M574 <axis><1|2> P…` deletes the previous one. So `M574 'f1 P"nil"` also releases a pin bound with `'f2`. 3.7: `M574 E<ext> P<J>` binds a `M950 J` input to terminate `G1 H1 E` (load stops when active, unload when inactive); `P-1` reverts; must come after the `M950 J`. | `EndstopsManager.cpp` HandleM574; wiki M574 |
| `G1 H1–H4` | Raw/homing moves skip axis-limit checks. 3.7: a normal move whose target is outside M208 limits (on a homed axis) **throws** "target position outside machine limits"; relative moves are still clamped unless `M564 R0`. | `GCodes.cpp` 2598-2662 |
| Driver ids from expressions | A float is converted with `lrintf(10*x)` and accepted if within 0.002 → `119.1` → 119.1 (rounding, not truncation, since 3.4). A number literal **without a decimal point is an integer** (`NumericConverter::FitsInInt32`), and an integer driver id read through an array (`M584 E{array}`) becomes **main-board driver N** (`DriverId(0, n)`) – so `119` would mean `0.119`. The `+0.0001` in `AFC_steppers` forces a float and must stay; write lane offsets as `0.0, 0.1, …`. Strings are rejected; local driver ≥10 cannot be written as a float. OM `move.extruders[].driver` values pass through as DriverId. | `StringParser.cpp` 2055-2080; `ExpressionParser.cpp` ConvertToDriverId; RRFLibraries `NumericConverter.cpp` 292-295 |
| `M584` | Locks all motion systems and waits for standstill before remapping. `P` = number of visible axes. | `GCodes3.cpp` DoDriveMapping |
| `M591` | `D` extruder, `P` type (`P0` deletes – **no C needed**), `C` pin (required when creating), `S0/1/2` enable (off / printing / always). A switch monitor must be on the **same CAN board as the extruder driver, or the main board**; the driver is captured at creation, so recreate after `M584 E` remaps (tpost does). | `FilamentMonitor.cpp` 110-113, 203-296 |
| Filament error event | RRF runs `0:/sys/filament-error.g` (event name, `_`→`-`, no extruder suffix) with `param.D` = **extruder**, `B` = board, `P` = status, `S` = text. If the file exists RRF does **not** pause – the macro must. It runs on an async system channel (an `abort` there doesn't cancel the print). Without the file RRF pauses. | `Event.cpp` 91-112; `GCodes3.cpp` 1408-1450 |
| Tool change | Order `tfree<N>.g`→`tfree.g` (old), `tpre<N>.g`→`tpre.g` (new; **current tool is null** here), select new tool, `tpost<N>.g`→`tpost.g`. No guard against a `T` inside these macros – it starts a second change and overwrites `newToolNumber`; avoid. | `GCodes4.cpp` 420-520; `GCodes2.cpp` HandleTcode |
| Homing file | Axis `f` → `home'f.g`; all → `homeall.g`. | `Kinematics.cpp` 171-195 |
| `daemon.g` | Re-run 10 s after it finishes (1 s the first time). | `GCodes.cpp` 615-629 |
| `M470 P"dir"` / `M471 S"old" T"new" [D1]` / `M30 {expr}` | mkdir / rename / delete. **`M47` does not exist** (RRF would look for `/sys/M47.g`). | `GCodes2.cpp` 1382, 3380-3420 |
| `M150` | `E` strip, `R U B W`, `P` brightness 0-255, **`S` number of LEDs**, `F1` more to follow. | gcode-core dictionary (reviewed 3.7.0-rc.1) |
| `M567` | `E` ratio count must equal the tool's drive count. | gcode-core dictionary |
| `M566` / `M205` / `M203` | `M566` jerk is **always mm/min** (`M205` is the mm/s form); `M203` is mm/min unless `S1` (mm/s). | `GCodes2.cpp` 2686-2702, 3860-3883 |
| Arrays are copy-on-write | `set x[i] = …` makes the array (and each nested level) unique first, so assigning a shared template (`set a = global.template`) and editing it later never changes the template. | `ArrayHandle.cpp` 72-100 |
| 3.7 `M563` | Refuses a tool whose `H` heater is also a bed/chamber heater. | gcode-core release scan |

## 3. Object model (all paths used here exist in 3.6.3 and 3.7 – gcode-core OM check)

| Field | Unit / note |
|---|---|
| `move.extruders[].jerk`, `.speed` | **mm/s** (`M566`/`M203` take mm/min → ×60; B06) |
| `move.axes[].jerk`, `.speed` | mm/min |
| `move.extruders[].pressureAdvance` | deprecated 3.7 → `pressAdv.k0/k1/d` |
| `state.nextTool` (and the other `state.*Tool`) | deprecated 3.7 → `move.motionSystems[].nextTool` |
| `move.extruders[].position` | mm incl. M221 factor; goes backwards on retract (B13) |
| `sensors.gpIn[J]` | `null` when J not configured |
| `sensors.filamentMonitors[].filamentPresent` | 3.7.0-beta.3+ |

## 4. RRF 3.7 features worth adopting (targets in AUDIT.md §4)

`[ ]` arrays; array `^`; arrays round-trip through `echo` **within the 255-char line limit**; `exists(E[n])` false
instead of error; `M574 E` extruder endstops; `M950 J C"fm<N>.switch"`; `M581.1 T P"expr" R…` expression triggers;
`M116 P` tool lists; two-slope PA; `move.motionSystems[]`.

## 5. Tooling: dwc-gcode-core lint

```
cd docs/maintainers/tools && npm install      # once
node lint.mjs                 # RRF 3.7.0-rc.2, filtered; exit 1 on errors
node lint.mjs --raw           # unfiltered
node lint.mjs --file tpost    # one file
node scan.mjs 3.6.3 3.7.0-rc.2  # release-impact scan
node cmd.mjs M591 M574        # dictionary query (parameters, since/until, reviewed release)
```
Baseline at audit time was 49 findings / 34 errors; after the implementation pass it is **0 / 0**. A change must not add findings (the lint reads untracked files too).
Minimum firmware is RRF 3.7 (D1), so the gate is `--fw 3.7.0-rc.2` (the default) until 3.7.0 final ships.

Known gcode-core 1.36.0 false positives (filtered in `lint.mjs`). **Fixed in the local `dwc-gcode-core` checkout on
2026-10-04 (uncommitted, unreleased – see its CHANGELOG "Unreleased")**, together with `T-1` being read as a use of
"tool -1". When a release containing them is published, bump `tools/package.json` and delete these filters (plan P4-06):
1. `project/undefined-symbol` for an indexed use `global.X[i]` of a declared `global X` (repro: `global X = {1,2}` / `echo global.X[0]`).
2. `syntax/text-after-command` for a quoted string on a line indented with exactly three tabs.
3. `M591`: `S` reported unknown; `C` reported required with `P0`.
4. Dictionary text for `M291 J1/J2` is swapped and `M581 R-1` is undocumented (doesn't affect lint).
5. `project/duplicate-definition` for the bind/unbind (`C"nil"`) pattern; release scan's "`^` concatenates arrays" fires on string concatenation.

Not covered by the lint: **undeclared `var.` locals** (it missed B02), anything dynamic (pin strings built at runtime,
numeric indices into globals, array lengths, units of values). Check locals by hand: every `var.x` must have a `var x`
earlier in the same file and enclosing block.
Use [GLOBALS.md](GLOBALS.md), `xref_globals.py` and the RRF source for those.

## 6. Re-verifying against a new RRF release

1. `git clone --depth 1 -b <tag> https://github.com/Duet3D/RepRapFirmware.git` into a temp dir; `git grep` the handlers
   named in §1-2 (`StringParser.cpp`, `ExpressionParser.cpp`, `GCodes*.cpp`, `TriggerItem.cpp`, `EndstopsManager.cpp`,
   `FilamentMonitor.cpp`, `Event.cpp`).
2. Wiki: `git clone --depth 1 https://github.com/Duet3D/wiki-content.git` → `User_manual/Reference/Gcodes.md`,
   `Gcode_meta_commands.md` (the per-command pages are redirects). Source wins over wiki on conflict.
3. Bump `dwc-gcode-core` in `tools/package.json`, run `node scan.mjs <old> <new>` and `node lint.mjs --fw <new>`.
