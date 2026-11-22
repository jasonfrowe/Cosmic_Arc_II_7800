#!/usr/bin/env python3
"""The soundtrack and the sound effects: writes src/gen/music.asm (the music,
bank 5: the NMI's player switches it in while it plays) and src/gen/sfx.asm
(the effects, the fixed bank).

From Super Mega Pinball 7800's tools/music.py (the same stream format, see
src/asm/sound.asm). Six voices on the two POKEYs:
  0 lead      POKEY 1 channels 1+2, 16 bits
  1 bass      POKEY 1 channels 3+4, 16 bits
  2 harmony   POKEY 2 channel 1, 8 bits, the 64 kHz clock (an arpeggio)
  3 pad       POKEY 2 channel 2, 8 bits, the 64 kHz clock
  4 drums     POKEY 2 channel 3: kick, snare, tom
  5 hats      POKEY 2 channel 4: closed and open hats
The 8-bit voices are in tune to a few cents from C3 to about A5; notes
outside that are folded in by octaves.

Hand-written songs (below), and generated ones: tools/musicgen (vendored
from RPMegaChopperII's gtools/musicgen, the OPL2 composer) composes, and
song_generated turns its rows into these voices' streams (each 64-row chunk
a subroutine). GENERATED lists them: a seed and a style each (see
musicgen/compose.py STYLE_NAMES); change one and rebuild to hear another.
The songs:

  MUS_TITLE    generated (GENERATED): the title and the hardware check
               (the old hand-written Arc theme, song_title, is kept but unused)
  MUS_ROCKS    deep space, A minor, driving: rocks
  MUS_PIRATES  E Phrygian, faster, a menacing bass: pirates about (and a
               planet's storm coming)
  MUS_PLANET   D Dorian, plucked and curious: exploring a planet
  MUS_MAP      generated (GENERATED): the sector map
"""

from __future__ import annotations

import sys
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
    ("stab", [14, 12, 9, 7, 5, 4, 3, 2, 1, 0], None),
    # the generated songs' (the composer writes its own arpeggios)
    ("glead", [11, 12, 11, 10, 10, 9, 9, 9, 8, 8, 8, 8, 8, 7], None),
    ("gbass", [13, 12, 11, 10, 10, 9, 9, 8, 8, 8, 7], None),
    ("garp", [9, 8, 7, 6, 5, 5, 4, 4, 3], None),
    ("gpad", [2, 3, 4, 5, 6, 6, 6, 6, 6, 5], None),
]
INS = {n: i for i, (n, _, _) in enumerate(INSTR)}

# Drums on POKEY 2 channels 3 (kick, snare, tom) and 4 (hats), at the 64 kHz
# clock: (AUDC, AUDF) a frame. AUDC: $A_ pure tone, $C_ poly4 (a low buzz),
# $8_ noise; AUDF: the pitch, 64 kHz / 2 / (AUDF + 1). The kick: a poly4
# thump, then a tone falling to 125 Hz.
DRUMS = [
    ("kick", [(0xCF, 50), (0xAE, 150), (0xAC, 185), (0xAA, 215), (0xA8, 240), (0xA6, 255), (0xA4, 255), (0xA2, 255)]),
    ("snare", [(0x8F, 5), (0x8D, 7), (0x8B, 9), (0x89, 10), (0x87, 11), (0x85, 12), (0x83, 13), (0x82, 14), (0x81, 15)]),
    ("hat", [(0x85, 0), (0x83, 0), (0x81, 0)]),
    ("ohat", [(0x85, 0), (0x84, 0), (0x84, 0), (0x83, 0), (0x83, 0), (0x82, 0), (0x82, 0), (0x81, 0)]),
    ("tom", [(0xAD, 100), (0xAB, 120), (0xA9, 140), (0xA7, 160), (0xA5, 180), (0xA3, 200)]),
]
HATS = {"hat", "ohat"}
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


SPEED = [7]       # the song being written's frames a sixteenth (Stream.notes)


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

    def notes(self, seq, maxd=None):
        """notes (n, sixteenths): the stream holds frames (sixteenths * the
        song's speed, SPEED[0]), at most 255 a byte"""
        sp = SPEED[0]
        maxd = 255 // sp
        for n, d in seq:
            while d > 0:
                dd = min(d, maxd)
                if n is None:
                    self.lines.append(f"    .byte $80,{dd * sp}")
                else:
                    self.lines.append(f"    .byte {n},{dd * sp}")
                d -= dd

    def call(self, label):
        self.lines.append(f"    .byte $83,<{label},>{label}")

    def jump(self, name):
        self.lines.append(f"    .byte $82,<{self.label}_{name},>{self.label}_{name}")

    def end(self):
        self.lines.append("    .byte $86")

    def ret(self):
        self.lines.append("    .byte $84")




ROOT_OF.update({"F": "F", "G": "G", "E": "E", "Em": "E", "B": "B"})


def bars(text):
    """One bar a line: check each is 16 sixteenths."""
    out = []
    for ln in text.strip().splitlines():
        seq = parse(ln)
        assert sum(d for _, d in seq) == 16, ln
        out += seq
    return out


def bass_low(r):
    """The bass's root and octave: low roots an octave down."""
    if r in ("A", "A#", "G", "B", "G#"):
        return note(r + "1"), note(r + "2")
    return note(r + "2"), note(r + "3")


def song(pre, form, lead, lead_ins, bass_bar, harm_bar, drums):
    """A looping song: form (chords a bar), the lead (bars), a bass bar and a
    harmony bar for a chord, drum phrase names a bar."""
    v0, v1, v2, v3, v4, v5 = (Stream(f"{pre}_v{k}") for k in range(6))
    seq = bars(lead)
    assert sum(d for _, d in seq) == 16 * len(form), pre
    v0.ins(lead_ins)
    v0.mark("loop")
    v0.notes(seq)
    v0.jump("loop")
    v1.ins("bass")
    v1.mark("loop")
    for ch in form:
        v1.notes(bass_bar(ch))
    v1.jump("loop")
    v2.mark("loop")
    cur = None
    for ch in form:
        ins = "arpmin" if ch in MINOR else "arpmaj"
        if ins != cur:
            v2.ins(ins)
            cur = ins
        v2.notes(harm_bar(note(ROOT_OF[ch] + "4")))
    v2.jump("loop")
    v3.end()                          # (no pad)
    v4.mark("loop")
    v5.mark("loop")
    for i in range(len(form)):
        v4.call(drums(i) + "_k")      # kick, snare, tom
        v5.call(drums(i) + "_h")      # the hats
    v4.jump("loop")
    v5.jump("loop")
    return [v0, v1, v2, v3, v4, v5]


def song_title():
    def bass(ch):
        lo, hi = bass_low(ROOT_OF[ch])
        return [(lo, 4), (lo, 2), (hi, 2), (lo, 4), (hi, 2), (lo, 2)]
    return song("mt", FORM, LEAD.strip().replace("\n\n", "\n"), "lead", bass,
                lambda n: [(n, 8), (n, 8)],
                lambda i: "drum_fill" if i % 4 == 3 else "drum_main")


# Deep space, rocks: A minor, driving eighths in the bass
ROCKS_FORM = ["Am", "Am", "F", "G", "Am", "Am", "F", "E",
              "Dm", "Dm", "Am", "Am", "F", "G", "E", "E"]
ROCKS_LEAD = """
A4:2 C5:2 E5:2 A5:4 G5:2 E5:2 C5:2
D5:2 E5:4 C5:2 A4:6 r:2
F4:2 A4:2 C5:2 F5:4 E5:2 C5:2 A4:2
G4:2 B4:2 D5:2 G5:6 r:4
A5:2 G5:2 E5:2 A5:4 C6:2 B5:2 A5:2
E5:4 D5:2 C5:2 E5:8
F5:2 E5:2 C5:2 A4:4 C5:2 F5:4
E5:4 G#5:4 B5:4 G#5:4
D5:2 F5:2 A5:4 D6:4 C6:2 A5:2
F5:4 E5:2 D5:2 A4:8
C5:2 E5:2 A5:4 E5:2 C5:2 A4:4
B4:2 C5:2 D5:2 E5:10
F5:2 A5:2 C6:4 A5:2 F5:2 C5:4
G5:2 B5:2 D6:4 B5:2 G5:2 D5:4
E5:2 G#5:2 B5:2 E6:4 D6:2 B5:2 G#5:2
B5:4 G#5:4 E5:8
"""
DRUM_ROCK = "kick:2 hat:2 snare:2 hat:2 kick:2 hat:2 snare:2 hat:1 hat:1"
DRUM_ROCKFILL = "kick:2 hat:2 snare:2 hat:2 snare:1 snare:1 tom:2 tom:2 snare:2"


def song_rocks():
    def bass(ch):
        lo, hi = bass_low(ROOT_OF[ch])
        return [(lo, 2), (hi, 2)] * 4
    return song("mr", ROCKS_FORM, ROCKS_LEAD, "lead", bass,
                lambda n: [(n, 4)] * 4,
                lambda i: "drum_rockfill" if i % 4 == 3 else "drum_rock")


# Pirates: E Phrygian (the F over E), stabs, a chugging bass, toms
PIR_FORM = ["Em", "F", "Em", "F", "Dm", "C", "B", "B"]
PIR_LEAD = """
E5:2 r:2 E5:2 r:2 F5:2 E5:2 B4:4
F5:2 r:2 F5:2 r:2 G5:2 F5:2 C5:4
E5:2 G5:2 B5:4 A5:2 G5:2 F5:4
F5:2 A5:2 C6:4 B5:2 A5:2 G5:2 F5:2
D5:2 F5:2 A5:2 D6:2 C6:4 A5:4
C5:2 E5:2 G5:2 C6:2 B5:4 G5:4
B4:2 D#5:2 F#5:2 B5:2 A5:2 F#5:2 D#5:4
B5:4 A5:2 G5:2 F#5:2 E5:2 D#5:4
"""
DRUM_PIR = "kick:2 kick:2 snare:2 hat:2 kick:2 kick:2 snare:2 tom:2"
DRUM_PIRFILL = "tom:2 tom:2 tom:2 tom:2 snare:2 snare:2 snare:2 snare:2"


def song_pirates():
    def bass(ch):
        lo, hi = bass_low(ROOT_OF[ch])
        return [(lo, 2), (lo, 2), (hi, 2), (lo, 2)] * 2
    return song("mp", PIR_FORM, PIR_LEAD, "stab", bass,
                lambda n: [(n, 2)] * 8,
                lambda i: "drum_pirfill" if i % 4 == 3 else "drum_pir")


# A planet: D Dorian, a plucked lead with space in it, a bouncing bass
PLAN_FORM = ["Dm", "G", "Dm", "C", "F", "C", "Gm", "A"]
PLAN_LEAD = """
D5:2 r:2 F5:2 A5:2 r:2 G5:2 F5:2 E5:2
D5:2 r:2 B4:2 D5:2 G5:4 r:4
A5:2 r:2 A5:2 G5:2 F5:2 E5:2 D5:4
E5:2 G5:2 C6:4 r:2 B5:2 G5:4
A5:2 r:2 C6:2 A5:2 F5:4 G5:2 A5:2
G5:2 r:2 E5:2 G5:2 C5:4 r:4
D5:2 G5:2 A#5:2 D6:2 C6:2 A#5:2 A5:2 G5:2
A5:4 E5:2 C#5:2 A4:4 r:4
"""
DRUM_PLAN = "kick:2 hat:2 hat:2 hat:2 snare:2 hat:2 hat:2 hat:2"
DRUM_PLANFILL = "kick:2 hat:2 snare:2 hat:2 tom:2 hat:2 tom:2 tom:2"


def song_planet():
    def bass(ch):
        lo, hi = bass_low(ROOT_OF[ch])
        return [(lo, 2), (None, 2), (hi, 2), (lo, 2)] * 2
    return song("mn", PLAN_FORM, PLAN_LEAD, "pluck", bass,
                lambda n: [(n, 8), (n, 8)],
                lambda i: "drum_planfill" if i % 4 == 3 else "drum_plan")


# ---------------------------------------------------------------------------
# Generated songs (tools/musicgen). Each: its label prefix, the seed, the
# style (musicgen/compose.py STYLE_NAMES: 1 kraftwerk, 7 synthwave, 11
# eurobeat, 12 chiparcade, ...), its mood.
# skip_intro: start at the first section with all its parts but one, and
# loop back there (no build-up, no fade-out): for a song that has to come
# in strong (the composer's intro brings one part in at a time).
GENERATED = {
    "title": dict(pre="mg", seed=7800, style=9, skip_intro=True,
                  mood=dict(key_root=2, scale="minor", bpm=118, intensity=0.55, target_seconds=80)),
    "map": dict(pre="mm", seed=2026, style=7,
                mood=dict(key_root=9, scale="minor", bpm=108, intensity=0.35, target_seconds=70)),
}


def _composer():
    sys.path.insert(0, str(ROOT / "tools"))
    from musicgen import compose
    from musicgen.tracks import MoodPreset
    from musicgen.furwriter import FurInstrument, FurOp, NOTE_OFF
    # the composer picks OPL2 patches from a bank; the POKEY has none, so a
    # stand-in (only the picks' random draws matter, to keep a seed's song)
    bank = [FurInstrument(name=str(i), alg=0, fb=0, op0=FurOp(mult=1), op1=FurOp(mult=1)) for i in range(256)]
    return compose, MoodPreset, NOTE_OFF, bank


def _fold(n, lo, hi):
    """our note (0 = C1) into lo..hi by octaves"""
    while n > hi:
        n -= 12
    while n < lo:
        n += 12
    return n


def song_generated(name):
    g = GENERATED[name]
    compose, MoodPreset, NOTE_OFF, bank = _composer()
    song, _ = compose.generate_track(name, MoodPreset(**g["mood"]), g["seed"], bank, style=g["style"])
    pre, plen = g["pre"], song.pattern_len
    SPEED[0] = song.speed
    if g.get("skip_intro"):
        # the sections with all their parts, or all but one
        empty = max(p for (_, p) in song.patterns)
        roles = compose.ROLE_TO_CHANNEL.values()
        active = [sum(1 for c in roles if song.orders[c][k] != empty and song.patterns[(c, song.orders[c][k])])
                  for k in range(len(song.orders[0]))]
        full = [k for k, a in enumerate(active) if a >= max(active) - 1]
        a, b = full[0], full[-1] + 1
        song.orders = [o[a:b] for o in song.orders]
    maxd = max(1, 255 // song.speed)          # the player's wait: sixteenths * speed < 256
    ch = compose.ROLE_TO_CHANNEL
    # Furnace note values: C-4 (MIDI 60) is 108; ours: C1 (MIDI 24) is 0
    conv = lambda v: v - 72
    ranges = {"lead": (0, 95), "bass": (0, 95), "arp": (24, 57), "pad": (24, 57)}   # 8-bit: C3-A5
    subs = []

    def events(cells):
        """a pattern's cells -> [(note or None, sixteenths)]"""
        out, cur, start = [], None, 0
        for row in sorted(cells):
            c = cells[row]
            if c.note is None:
                continue
            if row > start:
                out.append((cur, row - start))
            cur = None if c.note >= NOTE_OFF else c.note
            start = row
        out.append((cur, plen - start))
        merged = []
        for n, d in out:
            if merged and n is None and merged[-1][0] is None:
                merged[-1] = (None, merged[-1][1] + d)
            elif d > 0:
                merged.append((n, d))
        return merged

    def sub_label(voice, key):
        return f"{pre}_s{voice}_{key}"

    made = set()

    def melodic(voice, role, ins):
        st = Stream(f"{pre}_v{voice}")
        st.ins(ins)
        st.mark("loop")
        c = ch[role]
        lo, hi = ranges[role]
        for pidx in song.orders[c]:
            lab = sub_label(voice, pidx)
            if lab not in made:
                made.add(lab)
                sub = Stream(lab)
                sub.lines.append(lab)
                seq = [(None if n is None else _fold(conv(n), lo, hi), d) for n, d in events(song.patterns[(c, pidx)])]
                sub.notes(seq, maxd)
                sub.ret()
                subs.append(sub)
            st.call(lab)
        st.jump("loop")
        return st

    def drums(voice, roles):
        st = Stream(f"{pre}_v{voice}")
        st.mark("loop")
        for k in range(len(song.orders[ch[roles[0]]])):
            pids = tuple(song.orders[ch[r]][k] for r in roles)
            lab = sub_label(voice, "_".join(str(p) for p in pids))
            if lab not in made:
                made.add(lab)
                hits = {}
                for r, p in zip(roles, pids):
                    for row, cell in song.patterns[(ch[r], p)].items():
                        if cell.note is not None and cell.note < NOTE_OFF:
                            if r == "snare" or row not in hits:
                                hits[row] = r
                rows = sorted(hits)
                seq = []
                if not rows or rows[0] > 0:
                    seq.append((None, rows[0] if rows else plen))
                for i, row in enumerate(rows):
                    gap = (rows[i + 1] if i + 1 < len(rows) else plen) - row
                    r = hits[row]
                    if r == "hat":
                        r = "ohat" if gap >= 4 else "hat"       # a long gap: let it ring
                    seq.append((DR[r], gap))
                sub = Stream(lab)
                sub.lines.append(lab)
                sub.notes(seq, maxd)
                sub.ret()
                subs.append(sub)
            st.call(lab)
        st.jump("loop")
        return st

    voices = [melodic(0, "lead", "glead"), melodic(1, "bass", "gbass"),
              melodic(2, "arp", "garp"), melodic(3, "pad", "gpad"),
              drums(4, ("kick", "snare")), drums(5, ("hat",))]
    return voices, subs, song.speed


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
    ("LAUNCH", 1, 4, sweep(4, 20, 4, 12, 6, 14)),       # the fighter launches
    ("DOCK", 1, 4, sweep(4, 4, 20, 10, 4, 14)),         # ... docks
    ("FSHOT", 0, 1, sweep(4, 2, 8, 9, 3, 5)),           # twin blasters
    ("FHIT", 1, 5, sweep(3, 10, 24, 14, 3, 12)),        # the fighter is hit
    ("PSHOT", 0, 2, sweep(12, 6, 14, 8, 2, 8)),         # a pirate shoots
    ("MISSILE", 1, 3, sweep(8, 20, 6, 6, 10, 16)),      # a missile launches
    ("POD", 1, 6, notes_fx(4, [11, 9, 7, 5], 3, 11)),   # a pod picked up
    ("BEAM", 0, 1, [(6, 28, 4), (6, 26, 4), (6, 28, 3), (6, 30, 3)] * 4),  # the tractor beam hums
    ("CAPTURE", 1, 5, notes_fx(4, [14, 11, 9], 3, 12)),  # a creature in the shuttle
    ("DELIVER", 1, 6, notes_fx(4, [17, 14, 11, 8, 6], 3, 12)),  # handed over to the Ark
    ("STUN", 1, 4, sweep(8, 2, 16, 14, 2, 14)),          # the stun pulse
    ("KLAXON", 1, 7, notes_fx(1, [10, 14], 8, 12)),      # time's nearly up
    ("CHIP", 1, 2, sweep(2, 4, 8, 9, 2, 5)),             # a rock chipped, not broken
    ("ARRIVE", 1, 3, sweep(4, 28, 12, 6, 10, 40)),      # the Ark comes in
    ("DEPART", 1, 3, sweep(4, 12, 28, 10, 4, 40)),      # ... and leaves
]


def f8(n):
    """the 8-bit voices: POKEY's 64 kHz clock (1.79 MHz / 28)"""
    f = 440.0 * 2 ** ((n + BASE - 69) / 12)
    v = round(1789773 / 28 / (2 * f) - 1)
    return max(0, min(255, v))


def f16(n):
    f = 440.0 * 2 ** ((n + BASE - 69) / 12)
    v = round(1789773 / (2 * f) - 7)
    return max(0, min(65535, v))


def main():
    out = ["; Generated by tools/music.py. Do not edit. The music: bank 5 (the",
           "; player in sound.asm switches it in to read it).", ""]
    sfx = ["; Generated by tools/music.py. Do not edit. The effects (the fixed bank).", ""]
    hand = [("rocks", 6, "mr", song_rocks),
            ("pirates", 5, "mp", song_pirates), ("planet", 7, "mn", song_planet)]
    gen = [("title",), ("map",)]
    # the songs' numbers (MUS_*) stay put, however each is made
    names = ["title", "rocks", "pirates", "planet", "map"]
    assert sorted(names) == sorted([h[0] for h in hand] + [g[0] for g in gen])
    for i, nm in enumerate(names):
        sfx.append(f"MUS_{nm.upper()} = {i}")
    out.append("song_lo .byte " + ",".join(f"<song_{i}" for i in range(len(names))))
    out.append("song_hi .byte " + ",".join(f">song_{i}" for i in range(len(names))))
    streams, heads = [], []
    for nm, speed, p, fn in hand:
        heads.append((names.index(nm), speed, p))
        SPEED[0] = speed
        streams += fn()
    for k, (nm,) in enumerate(gen):
        voices, subs, speed = song_generated(nm)
        heads.append((names.index(nm), speed, GENERATED[nm]["pre"]))
        streams += voices + subs
    for i, speed, p in sorted(heads):
        out.append(f"song_{i} .byte {speed},$3F")
        out.append("    .word " + ",".join(f"{p}_v{k}" for k in range(6)))
    for st in streams:
        if not (st.lines and st.lines[0] == st.label):
            out.append(st.label)
        out += st.lines
    # the hand-written songs' drum phrases: kick/snare/tom (_k), hats (_h);
    # each its song's speed (waits are in frames)
    for name, txt, sp in (("drum_rock", DRUM_ROCK, 6), ("drum_rockfill", DRUM_ROCKFILL, 6),
                          ("drum_pir", DRUM_PIR, 5), ("drum_pirfill", DRUM_PIRFILL, 5),
                          ("drum_plan", DRUM_PLAN, 7), ("drum_planfill", DRUM_PLANFILL, 7)):
        seq = drum_parse(txt)
        assert sum(d for _, d in seq) == 16, name
        hats = {DR[h] for h in HATS}
        for suffix, keep in (("_k", lambda n: n is not None and n not in hats),
                             ("_h", lambda n: n is not None and n in hats)):
            part = []
            for n, d in seq:
                n = n if keep(n) else None
                if part and n is None and part[-1][0] is None:
                    part[-1] = (None, part[-1][1] + d)
                else:
                    part.append((n, d))
            out.append(name + suffix)
            for n, d in part:
                out.append(f"    .byte {'$80' if n is None else n},{d * sp}")
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
    # frequencies: 16 bits (1.79 MHz), 8 bits (64 kHz)
    fr = [f16(n) for n in range(96)]
    out.append("f16lo")
    for i in range(0, 96, 16):
        out.append("    .byte " + ",".join(str(v & 255) for v in fr[i:i + 16]))
    out.append("f16hi")
    for i in range(0, 96, 16):
        out.append("    .byte " + ",".join(str(v >> 8) for v in fr[i:i + 16]))
    out.append("f8tab")
    for i in range(0, 96, 16):
        out.append("    .byte " + ",".join(str(f8(n)) for n in range(i, i + 16)))
    # effects (id 0 = none)
    for i, (nm, ch, pri, data) in enumerate(SFX):
        sfx.append(f"SFX_{nm} = {i + 1}")
        sfx.append(f"sfxd_{i + 1}")
        for k in range(0, len(data), 12):
            sfx.append("    .byte " + ",".join(f"{c},{f},{v}" for c, f, v in data[k:k + 12]))
        sfx.append("    .byte $FF")
    ids = range(len(SFX) + 1)
    sfx.append("sfx_chan .byte 0," + ",".join(str(s[1]) for s in SFX))
    sfx.append("sfx_pri .byte 0," + ",".join(str(s[2]) for s in SFX))
    sfx.append("sfx_dlo .byte 0," + ",".join(f"<sfxd_{i}" for i in ids if i))
    sfx.append("sfx_dhi .byte 0," + ",".join(f">sfxd_{i}" for i in ids if i))
    GEN.mkdir(parents=True, exist_ok=True)
    (GEN / "music.asm").write_text("\n".join(out) + "\n")
    (GEN / "sfx.asm").write_text("\n".join(sfx) + "\n")
    size = sum(len(l.split(",")) for l in out if ".byte" in l)
    print(f"music: about {size} bytes (bank 5); {len(names)} songs")


if __name__ == "__main__":
    main()
