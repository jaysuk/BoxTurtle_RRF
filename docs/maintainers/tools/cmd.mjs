// Query the dwc-gcode-core command dictionary (each reviewed entry is cited to RRF source).
// usage: node cmd.mjs M591 M574 G1 ...
import { commandSpec } from "dwc-gcode-core/dictionary/commands";

for (const code of process.argv.slice(2)) {
  const s = commandSpec(code);
  if (!s) { console.log(`${code}: not in dictionary (RRF would try /sys/${code}.g)`); continue; }
  console.log(`${code}  reviewed=${s.reviewed ?? "draft"}${s.since ? " since=" + s.since : ""}${s.until ? " until=" + s.until : ""}${s.deprecated ? " DEPRECATED" : ""}`);
  for (const p of s.parameters ?? []) {
    const flags = [p.list && "list", p.required && "required", p.since && "since " + p.since, p.until && "until " + p.until].filter(Boolean).join(", ");
    console.log(`  ${p.letter}  ${p.kind}${flags ? " (" + flags + ")" : ""}  ${p.description ?? ""}`);
  }
}
