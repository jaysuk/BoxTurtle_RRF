// Release-impact scan: which lines use something that changed between two RRF versions.
// usage: node scan.mjs <fromVersion> <toVersion>     e.g. node scan.mjs 3.6.3 3.7.0-rc.2
import { readFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { scanFile } from "dwc-gcode-core/releases/scan";

const [from = "3.6.3", to = "3.7.0-rc.2"] = process.argv.slice(2);
const repo = execSync("git rev-parse --show-toplevel").toString().trim();
const byMessage = new Map();
for (const f of execSync("git ls-files", { cwd: repo }).toString().trim().split("\n")) {
  if ((!f.startsWith("sys/") && !f.startsWith("macros/")) || /\.(md|json|example|py|mjs)$/.test(f)) continue;
  const s = scanFile({ path: "0:/" + f, text: readFileSync(repo + "/" + f, "utf8") }, from, to);
  for (const x of s?.findings ?? []) {
    if (!byMessage.has(x.message)) byMessage.set(x.message, []);
    byMessage.get(x.message).push(`${f}:${x.line + 1}`);
  }
}
for (const [m, locs] of byMessage) console.log(`${m}\n    ${locs.length}x: ${locs.slice(0, 8).join(", ")}${locs.length > 8 ? " ..." : ""}\n`);
