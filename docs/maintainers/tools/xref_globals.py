"""Cross-reference every global.* in the repo: where it is declared, set and read.

Usage (from repo root):  python docs/maintainers/tools/xref_globals.py [GLOBAL_NAME ...]
Flags globals that are never declared or never read. Comments (';' to end of line) are ignored,
so a ';' inside a quoted string can hide the rest of that line - check by hand if a result looks odd.
"""
import collections
import os
import re
import subprocess
import sys

files = [f for f in subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard"]).decode().splitlines()
         if not f.endswith((".md", "LICENSE", ".json", ".py"))]
decl, setw, read = (collections.defaultdict(set) for _ in range(3))
for f in files:
    for line in open(f, encoding="utf-8", errors="replace"):
        code = "" if line.lstrip().startswith(";") else line.split(";")[0]
        if not code.strip():
            continue
        for m in re.finditer(r"^\s*global\s+(\w+)", code):
            decl[m.group(1)].add(f)
        for m in re.finditer(r"^\s*set\s+global\.(\w+)", code):
            setw[m.group(1)].add(f)
        for m in re.finditer(r"global\.(\w+)", re.sub(r"^\s*set\s+global\.\w+", "", code)):
            read[m.group(1)].add(f)

wanted = set(sys.argv[1:])
names = sorted(set(decl) | set(setw) | set(read))
fmt = lambda s: ", ".join(sorted(os.path.basename(x) for x in s)) or "-"
for g in names:
    if wanted and g not in wanted:
        continue
    flag = "  !!NEVER DECLARED" if g not in decl else ("  !!NEVER READ" if not read[g] else "")
    print(f"{g}{flag}\n   decl: {fmt(decl[g])}\n   set : {fmt(setw[g])}\n   read: {fmt(read[g])}")
