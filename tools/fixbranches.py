#!/usr/bin/env python3
"""Fix "Branch out of range" errors from the last build (build/work/build.log):
each such branch becomes the opposite branch round a JMP, in src/asm/.

    tools/fixbranches.py && tools/build.sh     (repeat until it builds)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INV = {"bcc": "bcs", "bcs": "bcc", "beq": "bne", "bne": "beq", "bpl": "bmi",
       "bmi": "bpl", "bvc": "bvs", "bvs": "bvc"}

log = (ROOT / "build" / "work" / "build.log").read_text()
todo = {}
for f, n in re.findall(r"^(\w+\.asm) \((\d+)\): error: Branch out of range", log, re.M):
    todo.setdefault(f, set()).add(int(n))
fixed = 0
for f, lines in todo.items():
    p = ROOT / "src" / "asm" / f
    if not p.exists():
        print(f"{f}: not in src/asm, skipped")
        continue
    L = p.read_text().split("\n")
    for n in sorted(lines, reverse=True):
        m = re.match(r"(\s*)(b\w\w)\s+(\w+)(.*)", L[n - 1])
        if not m or m.group(2).lower() not in INV:
            print(f"{f}:{n}: not a branch: {L[n - 1]!r}")
            continue
        ind, op, tgt, rest = m.groups()
        lab = f"{tgt}_far{n}"
        L[n - 1:n] = [f"{ind}{INV[op.lower()]} {lab}{rest}", f"{ind}jmp {tgt}", lab]
        fixed += 1
    p.write_text("\n".join(L))
print(f"fixbranches: {fixed} fixed")
sys.exit(0)
