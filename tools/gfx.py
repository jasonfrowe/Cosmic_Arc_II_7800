#!/usr/bin/env python3
"""The game's graphics: writes the 160A PNGs in src/gfx/ that 7800basic imports.

Run it after changing the art (needs Pillow: .venv/bin/python tools/gfx.py).
The PNGs are committed, so a normal build doesn't need Pillow.

Art is ASCII: '.' = transparent (color 0), 'a' 'b' 'c' = colors 1, 2, 3 of
the sprite's palette. 160A pixels are about twice as wide as they are
tall, so a round thing is half as wide (in pixels) as it is tall (in lines).
Widths must be multiples of 4 (one byte holds four 160A pixels).

The font: Spacewar 7800's 8x8 menufont (ASCII), glyphs 32-95, one 160A
pixel per font pixel (doublewide characters, 8 pixels a character), in
color 1. Glyphs 91-95 are redrawn as HUD bar segments and a star:
  [ full  \\ three quarters  ] half  ^ a quarter  _ a star
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
GFX = ROOT / "src" / "gfx"

# Index colors only tell 7800basic which of a palette's colors a pixel uses;
# these RGB values are just for looking at the files.
PNG_PALETTE = [0, 0, 0, 200, 60, 60, 120, 30, 30, 255, 170, 170]


def save(name, rows, width=None):
    rows = [r for r in rows]
    w = width or max(len(r) for r in rows)
    assert w % 4 == 0, f"{name}: width {w} not a multiple of 4"
    im = Image.new("P", (w, len(rows)), 0)
    im.putpalette(PNG_PALETTE)
    px = im.load()
    for y, r in enumerate(rows):
        r = r.center(w, ".") if len(r) < w else r
        assert len(r) == w, f"{name} row {y}: {len(r)} != {w}"
        for x, ch in enumerate(r):
            px[x, y] = ".abc".index(ch)
    im.save(GFX / f"{name}.png", bits=2)


def art(text):
    return [ln.strip() for ln in text.strip().splitlines()]


# ---------------------------------------------------------------------------
# The Ark: a saucer, 48 x 32 (two 16-line zones: drawn at y 80, on a zone
# boundary, it costs one object a zone), its hull's middle line on row 15.
# a hull, b stripes and rim, c lights and dome. The bay underneath is where
# the fighter (M2) launches and docks.
ARK = [""] * 6 + [
    "cccccc",
    "cccccccccccc",
    "ccc.cc.cc.cc.ccc",
    "c" * 20,
    "b" * 28,
    "a" * 34,
    "a" * 40,
    "aa" + "b" * 40 + "aa",
    "a" + "aaac" * 11 + "a",
    "a" * 48,
    "aa" + "b" * 44 + "aa",
    "a" * 44,
    "a" * 38,
    "b" * 32,
    "b" * 8 + "." * 12 + "b" * 8,
    "bbbb.cc" + "." * 6 + "cc.bbbb",
    "bb" + "." * 10 + "bb",
]
ARK = [r if r else "." * 48 for r in ARK]
ARK += ["." * 48] * (32 - len(ARK))

# Asteroids: a dark, b body, c highlight.
ROCK_L = art("""
..bbbb..
.bbbbbb.
bbcbbbbb
bccbbbab
bbbbbbab
bbbabbbb
bbbbbbbb
abbbbbab
bbabbbbb
bbbbbcbb
bbbbbccb
abbbbbbb
bbbbabbb
.bbbbbb.
.abbbba.
..bbbb..
""")
ROCK_M = art("""
..bbb...
.bcbbb..
bccbbab.
bbbbbbb.
bbabbbb.
bbbbbab.
abbbbbb.
bbbbcbb.
bbbbbbb.
.bbabbb.
.abbbb..
..bbb...
""")
ROCK_S = art("""
.bb.
bcbb
bbbb
bbab
babb
bbbb
bbbb
.bb.
""")

# Laser bolts, 4 x 4, one per aim direction: 0 up, then clockwise.
BOLTS = [
    art(".c..\n.c..\n.c..\n.c.."),
    art("...c\n..c.\n.c..\nc..."),
    art("....\ncccc\n....\n...."),
    art("c...\n.c..\n..c.\n...c"),
    art(".c..\n.c..\n.c..\n.c.."),
    art("...c\n..c.\n.c..\nc..."),
    art("....\ncccc\n....\n...."),
    art("c...\n.c..\n..c.\n...c"),
]

# The aim marker, 4 x 4
AIM = art(".a..\naaa.\n.a..\n....")

# An explosion, three frames of 8 x 16: c core, b fire, a smoke
BOOM = [
    art("""
........
........
........
........
...cc...
..cccc..
..cbbc..
.ccbbcc.
.ccbbcc.
..cbbc..
..cccc..
...cc...
........
........
........
........
"""),
    art("""
........
...b....
.b....b.
....b...
..bccb..
.bc..cb.
b.c..c.b
.bc..cb.
.bc..cb.
b.c..c.b
.bc..cb.
..bccb..
....b...
.b....b.
...b..b.
........
"""),
    art("""
.a....a.
....a...
a......a
..a..a..
.a....a.
a..a....
......a.
.a...a.a
a.a.....
....a..a
.a......
a...a.a.
..a....a
.a..a...
a.....a.
...a....
"""),
]


# ---------------------------------------------------------------------------
# M2: the fighter, pirates, shots, pods.

# The fighter: the saucer from Cosmic Arc (RP6502)'s lander, 8 x 7 (each
# 160A pixel two of the RP6502's): a dome above and below, the hull, and a
# rim of lights that runs round in four frames. a rim, b hull, c lights.
def saucer_frames():
    frames = []
    for k in range(4):
        rim = ["a"] * 8
        for d in (0, 1):
            rim[(k * 2 + d) % 8] = "c"
        frames.append(["...bb...", ".bbbbbb.", "bbbbbbbb", "".join(rim),
                       "bbbbbbbb", ".bbbbbb.", "...bb..."])
    return frames


# Raider: a small, fast pirate; two frames (its lights blink). b hull, c lights
RAIDER = [art("""
b......b
bb....bb
.bbaabb.
..bccb..
..bccb..
.bbaabb.
bb....bb
b......b
"""), art("""
b......b
bb....bb
.bbccbb.
..baab..
..baab..
.bbccbb.
bb....bb
b......b
""")]

# Gunship: slow, heavy, launches missiles. 12 x 12
GUNSHIP = art("""
....bbbb....
..bbbbbbbb..
.bbaabbaabb.
bbbbbbbbbbbb
bbccbbbbccbb
bbbbbbbbbbbb
.bbaaaaaabb.
..bbbbbbbb..
...b.bb.b...
..b..bb..b..
.b...bb...b.
............
""")

# Missile: 4 x 4, two frames
MISSILE = [art(".c..\ncac.\n.c..\n...."), art(".a..\naca.\n.a..\n....")]

# A shot (fighter, turret, pirate: the palette tells them apart), 4 x 4
DOT = art("....\n.cc.\n.cc.\n....")

# Salvage pod: 4 x 8, two frames
POD = [art(".bb.\nbaab\nbccb\nbccb\nbccb\nbccb\nbaab\n.bb."),
       art(".bb.\nbaab\nbaab\nbaab\nbaab\nbaab\nbaab\n.bb.")]


def font():
    src = Image.open(GFX / "menufont.png")
    sp = src.load()
    first, last = 32, 95
    n = last - first + 1
    # 16 lines a glyph (a 16-line zone), the letter in the top 8
    im = Image.new("P", (n * 8, 16), 0)
    im.putpalette(PNG_PALETTE)
    px = im.load()
    for i in range(n):
        for y in range(8):
            for x in range(8):
                px[i * 8 + x, y] = 1 if sp[(first + i) * 8 + x, y] else 0
    # HUD bar segments (7 lines high, a gap below) and a star
    special = {
        91: ["aaaaaaa."] * 6,          # [ full
        92: ["aaaaa..."] * 6,          # \ three quarters
        93: ["aaa....."] * 6,          # ] half
        94: ["a......."] * 6,          # ^ a quarter
        95: ["........", "........", "........", "...a....",
             "........", "........"],  # _ a star
    }
    for code, rows in special.items():
        i = code - first
        rows = ["........"] + rows + ["........"] * (7 - len(rows))
        for y in range(8):
            for x in range(8):
                px[i * 8 + x, y] = 1 if rows[y][x] == "a" else 0
    im.save(GFX / "font.png", bits=2)


def main():
    GFX.mkdir(parents=True, exist_ok=True)
    save("ark", ARK, 48)
    save("rock_l", ROCK_L)
    save("rock_m", ROCK_M)
    save("rock_s", ROCK_S)
    for i, b in enumerate(BOLTS):
        save(f"bolt{i}", b)
    save("aim", AIM)
    for i, b in enumerate(BOOM):
        save(f"boom{i}", b)
    for i, fr in enumerate(saucer_frames()):
        save(f"saucer{i}", fr)
    for i, fr in enumerate(RAIDER):
        save(f"raider{i}", fr)
    save("gunship", GUNSHIP)
    for i, fr in enumerate(MISSILE):
        save(f"missile{i}", fr)
    save("dot", DOT)
    for i, fr in enumerate(POD):
        save(f"pod{i}", fr)
    font()
    print("gfx: wrote", ", ".join(sorted(p.stem for p in GFX.glob("*.png"))))


if __name__ == "__main__":
    main()
