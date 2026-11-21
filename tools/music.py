#!/usr/bin/env python3
"""The soundtrack and the sound effects: writes src/gen/music.asm.

From Super Mega Pinball 7800's tools/music.py (the same stream format, see
src/asm/sound.asm). For now one song: the M0 test theme, a sketch in
D minor that puts the lead and bass on POKEY 1 ($0450) and the arpeggios
and drums on POKEY 2 ($0440), so the boot screen can solo either chip.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GEN = ROOT / "src" / "gen"

NAMES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
BASE = 24          # note 0 = C1


def midi(s):
    s = s.strip()
    name, octv = s[:-1], int(s[-1])
    return 12 * (octv + 1) + NAMES[name]


def note(s):
    return midi(s) - BASE


def parse(text):
    """'E5:2 A5:2 r:4' -> [(note or None, sixteenths)]"""
    out = []
    for tok in text.split():
        n, d = tok.split(":")
        out.append((None if n == "r" else note(n), int(d)))
    return out


# ---------------------------------------------------------------------------
# Instruments: envelope (volumes a frame, last held), arpeggio (offsets a frame, looped)
INSTR = [
    ("lead", [12, 13, 12, 11, 10, 10, 9, 9, 9, 8, 8, 8, 8, 7], None),
    ("bass", [13, 12, 11, 10, 9, 8, 7, 7, 6], None),
    ("arpmin", [7, 7, 6, 6, 6, 5, 5, 5, 5, 4], [0, 0, 3, 3, 7, 7, 12, 12]),
    ("arpmaj", [7, 7, 6, 6, 6, 5, 5, 5, 5, 4], [0, 0, 4, 4, 7, 7, 12, 12]),
    ("pluck", [13, 11, 9, 7, 6, 5, 4, 3, 2, 0], None),
    ("pad", [3, 4, 5, 6, 6, 6, 6, 5], None),
]
INS = {n: i for i, (n, _, _) in enumerate(INSTR)}

# Drums on POKEY 2 channel 3 at the 15 kHz clock: (AUDC, AUDF) a frame
DRUMS = [
    ("kick", [(0xAF, 18), (0xAD, 30), (0xAB, 46), (0xA9, 66), (0xA7, 92), (0xA5, 120), (0xA3, 150), (0xA1, 180)]),
    ("snare", [(0x8C, 5), (0x8B, 6), (0x8A, 7), (0x88, 8), (0x86, 8), (0x84, 9), (0x83, 9), (0x82, 10), (0x81, 10)]),
    ("hat", [(0x86, 0), (0x83, 0), (0x81, 0)]),
    ("ohat", [(0x86, 0), (0x85, 0), (0x84, 0), (0x83, 0), (0x82, 0), (0x81, 0)]),
    ("tom", [(0xAC, 40), (0xAA, 46), (0xA8, 52), (0xA6, 58), (0xA4, 64), (0xA2, 70)]),
]
DR = {n: i for i, (n, _) in enumerate(DRUMS)}

# ---------------------------------------------------------------------------
# The test theme. Chords a bar; a sixteenth = 7 frames.
FORM = ["Dm", "Bb", "C", "Am", "Dm", "Bb", "Gm", "A"]
ROOT_OF = {"Dm": "D", "Bb": "A#", "C": "C", "Am": "A", "Gm": "G", "A": "A"}
MINOR = {"Dm", "Am", "Gm"}

LEAD = """
D5:4 F5:2 A5:2 D6:6 C6:2
A#5:4 A5:2 F5:2 D5:8
E5:2 G5:2 C6:4 E6:4 D6:2 C6:2
A5:12 r:4
D6:2 C6:2 A5:4 F5:2 A5:2 D6:4
F6:6 E6:2 D6:4 A#5:4
G5:2 A#5:2 D6:4 G6:4 F6:2 E6:2
E6:4 C#6:4 A5:8
"""

DRUM_MAIN = "kick:2 hat:2 snare:2 hat:2 kick:2 kick:2 snare:2 hat:2"
DRUM_FILL = "kick:2 hat:2 snare:2 hat:2 tom:2 tom:2 snare:2 snare:2"


def drum_parse(text):
    out = []
    for tok in text.split():
        n, d = tok.split(":")
        out.append((None if n == "r" else DR[n], int(d)))
    return out


class Stream:
    def __init__(self, label):
        self.label = label
        self.lines = []
        self.marks = {}

    def mark(self, name):
        self.lines.append(f"{self.label}_{name}")

    def ins(self, name):
        self.lines.append(f"    .byte $81,{INS[name]}")

    def trans(self, t):
        self.lines.append(f"    .byte $85,{t & 255}")

    def notes(self, seq):
        for n, d in seq:
            while d > 0:
                dd = min(d, 32)
                if n is None:
                    self.lines.append(f"    .byte $80,{dd}")
                else:
                    self.lines.append(f"    .byte {n},{dd}")
                d -= dd

    def call(self, label):
        self.lines.append(f"    .byte $83,<{label},>{label}")

    def jump(self, name):
        self.lines.append(f"    .byte $82,<{self.label}_{name},>{self.label}_{name}")

    def end(self):
        self.lines.append("    .byte $86")




def song_theme():
    v0, v1, v2, v3 = Stream("mt_v0"), Stream("mt_v1"), Stream("mt_v2"), Stream("mt_v3")
    seq = parse(LEAD)
    assert sum(d for _, d in seq) == 16 * len(FORM)
    v0.ins("lead")
    v0.mark("loop")
    v0.notes(seq)
    v0.jump("loop")

    v1.ins("bass")
    v1.mark("loop")
    for ch in FORM:
        r = ROOT_OF[ch]
        lo, hi = note(r + "2"), note(r + "3")
        if r in ("A", "A#", "G"):
            lo, hi = note(r + "1"), note(r + "2")
        v1.notes([(lo, 4), (lo, 2), (hi, 2), (lo, 4), (hi, 2), (lo, 2)])
    v1.jump("loop")

    v2.mark("loop")
    cur = None
    for ch in FORM:
        ins = "arpmin" if ch in MINOR else "arpmaj"
        if ins != cur:
            v2.ins(ins)
            cur = ins
        n = note(ROOT_OF[ch] + "4")
        v2.notes([(n, 8), (n, 8)])
    v2.jump("loop")

    v3.mark("loop")
    for i in range(len(FORM)):
        v3.call("drum_fill" if i % 4 == 3 else "drum_main")
    v3.jump("loop")
    return [v0, v1, v2, v3]


# ---------------------------------------------------------------------------
# TIA effects: (AUDC, AUDF, AUDV) a frame; channel; priority
def notes_fx(c, fs, each, v):
    out = []
    for f in fs:
        out += [(c, f, v)] * each
    return out


def sweep(c, f0, f1, v0, v1, n):
    return [(c, round(f0 + (f1 - f0) * i / (n - 1)), round(v0 + (v1 - v0) * i / (n - 1))) for i in range(n)]


SFX = [
    ("BEEP", 0, 1, notes_fx(4, [12, 9], 3, 10)),
    ("ZAP", 0, 1, sweep(4, 3, 14, 10, 3, 6)),           # a laser bolt
    ("BOOM", 1, 3, sweep(8, 8, 28, 13, 1, 18)),         # a rock breaks
    ("HIT", 1, 5, sweep(3, 18, 31, 15, 2, 24)),         # a rock hits the Ark
    ("CLEAR", 1, 6, notes_fx(4, [17, 13, 11, 8], 5, 10)),  # wave clear
    ("LOST", 1, 8, sweep(8, 10, 31, 15, 0, 70)),        # the Ark is lost
]


def f16(n):
    f = 440.0 * 2 ** ((n + BASE - 69) / 12)
    v = round(1789773 / (2 * f) - 7)
    return max(0, min(65535, v))


def main():
    out = ["; Generated by tools/music.py. Do not edit.", ""]
    out.append("MUS_THEME = 0")
    songs = [("theme", 7, 15)]
    out.append("song_lo .byte " + ",".join(f"<song_{i}" for i in range(len(songs))))
    out.append("song_hi .byte " + ",".join(f">song_{i}" for i in range(len(songs))))
    pre = {"theme": "mt"}
    for i, (nm, speed, mask) in enumerate(songs):
        p = pre[nm]
        out.append(f"song_{i} .byte {speed},{mask}")
        out.append("    .word " + ",".join(f"{p}_v{k}" for k in range(4)))
    for s in song_theme():
        out.append(s.label)
        out += s.lines
    for name, txt in (("drum_main", DRUM_MAIN), ("drum_fill", DRUM_FILL)):
        seq = drum_parse(txt)
        assert sum(d for _, d in seq) == 16, name
        out.append(name)
        for n, d in seq:
            out.append(f"    .byte {'$80' if n is None else n},{d}")
        out.append("    .byte $84")
    # instruments
    for i, (nm, env, arp) in enumerate(INSTR):
        out.append(f"ins_env_{i} .byte " + ",".join(str(v) for v in env) + ",$FF")
        if arp:
            out.append(f"ins_arp_{i} .byte " + ",".join(str(v) for v in arp) + ",$FF")
    out.append("ins_env_lo .byte " + ",".join(f"<ins_env_{i}" for i in range(len(INSTR))))
    out.append("ins_env_hi .byte " + ",".join(f">ins_env_{i}" for i in range(len(INSTR))))
    out.append("ins_arp_lo .byte " + ",".join(f"<ins_arp_{i}" if a else "0" for i, (_, _, a) in enumerate(INSTR)))
    out.append("ins_arp_hi .byte " + ",".join(f">ins_arp_{i}" if a else "0" for i, (_, _, a) in enumerate(INSTR)))
    for i, (nm, mac) in enumerate(DRUMS):
        out.append(f"drum_{i} .byte " + ",".join(f"${c:02X},{f}" for c, f in mac) + ",0")
    out.append("drum_lo .byte " + ",".join(f"<drum_{i}" for i in range(len(DRUMS))))
    out.append("drum_hi .byte " + ",".join(f">drum_{i}" for i in range(len(DRUMS))))
    # frequencies
    fr = [f16(n) for n in range(96)]
    out.append("f16lo")
    for i in range(0, 96, 16):
        out.append("    .byte " + ",".join(str(v & 255) for v in fr[i:i + 16]))
    out.append("f16hi")
    for i in range(0, 96, 16):
        out.append("    .byte " + ",".join(str(v >> 8) for v in fr[i:i + 16]))
    # effects (id 0 = none)
    for i, (nm, ch, pri, data) in enumerate(SFX):
        out.append(f"SFX_{nm} = {i + 1}")
        out.append(f"sfxd_{i + 1}")
        for k in range(0, len(data), 12):
            out.append("    .byte " + ",".join(f"{c},{f},{v}" for c, f, v in data[k:k + 12]))
        out.append("    .byte $FF")
    ids = range(len(SFX) + 1)
    out.append("sfx_chan .byte 0," + ",".join(str(s[1]) for s in SFX))
    out.append("sfx_pri .byte 0," + ",".join(str(s[2]) for s in SFX))
    out.append("sfx_dlo .byte 0," + ",".join(f"<sfxd_{i}" for i in ids if i))
    out.append("sfx_dhi .byte 0," + ",".join(f">sfxd_{i}" for i in ids if i))
    GEN.mkdir(parents=True, exist_ok=True)
    (GEN / "music.asm").write_text("\n".join(out) + "\n")
    print(f"music: {sum(1 for l in out if '.byte' in l)} data lines")


if __name__ == "__main__":
    main()
