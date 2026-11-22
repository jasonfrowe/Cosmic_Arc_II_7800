#!/usr/bin/env python3
"""Check that no code in one switched bank calls into another.

Banks 2-16 share $8000-$BFFF: only one is in at a time, so a JSR or JMP
from a bank-3 file to a label defined in a bank-2 file lands in whatever
bank-3 holds there. Which bank a file is in comes from the inline lines
in src/cosmicarc.bas (after "bank N"; before any, bank 1). Fixed banks
(1 and the last) can be called from anywhere.

    tools/bankcheck.py     (tools/build.sh runs it)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
bas = (ROOT / "src" / "cosmicarc.bas").read_text().splitlines()
bank, file_bank = 1, {}
for ln in bas:
    m = re.match(r"\s*bank\s+(\d+)", ln)
    if m:
        bank = int(m.group(1))
    m = re.match(r"\s*inline\s+(\S+\.asm)", ln)
    if m:
        file_bank[m.group(1)] = bank
romk = next(int(m.group(1)) for m in (re.match(r"\s*set romsize\s+(\d+)k", l) for l in bas) if m)
last = romk // 16          # the last bank, fixed at $C000 (272K: bank 17)
label_bank = {}
for f, b in file_bank.items():
    p = ROOT / "src" / "asm" / f
    if not p.exists():
        p = ROOT / "src" / "gen" / f
    for ln in p.read_text().splitlines():
        m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\b(?!\s*=)", ln)
        if m and not ln.startswith((" ", "\t")):
            label_bank[m.group(1)] = (b, f)
bad = 0
for f, b in file_bank.items():
    if b in (1, last):
        continue
    p = ROOT / "src" / "asm" / f
    if not p.exists():
        continue
    for n, ln in enumerate(p.read_text().splitlines(), 1):
        m = re.match(r"\s+(jsr|jmp)\s+([A-Za-z_][A-Za-z0-9_]*)", ln, re.I)
        if not m:
            continue
        tgt = m.group(2)
        if tgt in label_bank:
            tb, tf = label_bank[tgt]
            if tb not in (1, last, b):
                print(f"{f}:{n} (bank {b}): {m.group(1)} {tgt} -> {tf} (bank {tb})")
                bad += 1
print(f"bankcheck: {bad} cross-bank call{'s' if bad != 1 else ''}")
sys.exit(1 if bad else 0)
