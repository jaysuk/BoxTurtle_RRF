// Lint every macro in this repo with dwc-gcode-core, as one project with SD-card paths.
// usage (from docs/maintainers/tools):  npm install  then  node lint.mjs [--fw 3.7.0-rc.2] [--raw] [--file <substring>]
// Exit code 1 if any error-severity finding remains after filtering.
import { readFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { loadProject } from "dwc-gcode-core/project";
import { diagnoseProject } from "dwc-gcode-core/diagnostics/diagnose";

const args = process.argv.slice(2);
const opt = (name, dflt) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : dflt; };
const fw = opt("--fw", "3.7.0-rc.2");
const raw = args.includes("--raw");
const only = opt("--file", null);
const repo = execSync("git rev-parse --show-toplevel").toString().trim();

const files = [];
for (const f of execSync("git ls-files --cached --others --exclude-standard", { cwd: repo }).toString().trim().split("\n")) {
  if (!f.startsWith("sys/") && !f.startsWith("macros/")) continue;
  if (/\.(md|json|example|py|mjs)$/.test(f)) continue;
  files.push({ path: "0:/" + f, text: readFileSync(repo + "/" + f, "utf8") });
}
// Stub of the user's config.g: AFC.g is called at the end of it.
files.push({ path: "0:/sys/config.g", text: 'M98 P"0:/sys/AFC/AFC.g"\n' });

const project = loadProject(files, { firmwareVersion: fw });
let diags = diagnoseProject(project, { firmwareVersion: fw });

// Known false positives / out-of-scope findings (see docs/maintainers/RRF_NOTES.md §5). --raw shows everything.
const declared = new Set(files.flatMap((f) => [...f.text.matchAll(/^\s*global\s+(\w+)/gm)].map((m) => m[1])));
const userOrGenerated = /sys\/(homeall|pause|resume|tpre|tpost|tfree|config)\.g|afc\/status\/|machine_user_vars\.g|afc_user_vars\.g|afc_unit_count\.g|macros\/brush_(safe_)?(deploy|retract)\.g/i;
const ignore = (d) =>
  // gcode-core 1.36.0 bug: an indexed use global.X[i] of a declared global is reported undefined
  // (only ignored when X really is declared somewhere - a misspelt name still shows)
  (d.rule === "project/undefined-symbol" && declared.has((/^global (\w+)\[\]/.exec(d.message) ?? [])[1])) ||
  // X/Y/Z/E etc. are defined in the user's config.g, which isn't in the repo
  (d.rule === "project/undefined-symbol" && /^axis [XYZ] /.test(d.message)) ||
  (d.rule === "project/undefined-symbol" && /^(tool|fan) (-1|0) /.test(d.message)) ||
  // bind/unbind (M950 J… C"nil", M574 … P"nil") is the house pattern; RRF allows re-definition
  d.rule === "project/duplicate-definition" ||
  // files that are the user's or are generated at runtime by Create System Files / save_status.g
  (d.rule === "project/missing-macro-file" && userOrGenerated.test(d.message)) ||
  // gcode-core 1.36.0 dictionary gaps, verified against RRF 3.7 source: M591 P0 needs no C; M591 has S
  (d.rule === "dictionary/missing-required" && /M591 needs a C/.test(d.message)) ||
  (d.rule === "dictionary/unknown-parameter" && /M591 doesn't have a S/.test(d.message)) ||
  // gcode-core 1.36.0 lexer bug: lines indented with exactly three tabs are mis-read as text
  (d.rule === "syntax/text-after-command" && /start_after_delay\.g/.test(d.file ?? ""));

if (!raw) diags = diags.filter((d) => !ignore(d));
if (only) diags = diags.filter((d) => (d.file ?? "").includes(only));

let errors = 0;
for (const d of diags) {
  if (d.severity === "error") errors++;
  console.log(`${d.severity.padEnd(7)} ${d.rule.padEnd(32)} ${(d.file ?? "") + ":" + ((d.line ?? 0) + 1)}  ${d.message}`);
}
console.log(`\n${diags.length} finding(s), ${errors} error(s) at RRF ${fw}${raw ? " (raw)" : ""}`);
process.exitCode = errors ? 1 : 0;
