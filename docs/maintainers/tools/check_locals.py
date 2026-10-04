"""Flag `var.x` uses with no `var x` declaration in the same file (dwc-gcode-core does not check locals).

Usage (from repo root): python docs/maintainers/tools/check_locals.py
File-level check only: it does not model block scope, so also confirm the declaration is in an enclosing block.
.example templates are skipped: their optional `var` overrides are deliberately guarded by `exists(var.x...)`.
Exit code 1 if anything is found.
"""
import re
import subprocess
import sys

bad = 0
for f in subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard"]).decode().splitlines():
    if not (f.startswith("sys/") or f.startswith("macros/")) or f.endswith((".md", ".json", ".py", ".mjs", ".example")):
        continue
    text = open(f, encoding="utf-8", errors="replace").read()
    code_lines = [(i, "" if l.lstrip().startswith(";") else l.split(";")[0]) for i, l in enumerate(text.splitlines(), 1)]
    declared = {m.group(1) for _, l in code_lines for m in re.finditer(r"^\s*var\s+(\w+)", l)}
    for i, l in code_lines:
        for m in re.finditer(r"\bvar\.(\w+)", l):
            if m.group(1) not in declared:
                print(f"{f}:{i}: var.{m.group(1)} is never declared in this file")
                bad += 1
print(f"{bad} undeclared local(s)")
sys.exit(1 if bad else 0)
