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


# ---------------------------------------------------------------------------
# M3: the planet.

RP6502 = Path.home() / "Software" / "rp6502" / "RP6502-Cosmic-Arc" / "Sprites"

# Creatures: Cosmic Arc (RP6502)'s beasties: 5 kinds, each 2 frames facing
# right then 2 facing left, 8 x 8; one 160A pixel per RP6502 pixel. A sixth
# kind is the first again. Each kind takes one colour of the creatures'
# palette (P2): a, b, c, a, b, c.
CREATURE_ART = [0, 1, 2, 3, 4, 0]
CREATURE_INK = "abcabc"


def creature_frames():
    src = Image.open(RP6502 / "beasties.png").convert("RGBA")
    sp = src.load()
    out = []
    for kind, art_k in enumerate(CREATURE_ART):
        for f in range(4):
            x0 = (art_k * 4 + f) * 8
            out.append(["".join(CREATURE_INK[kind] if sp[x0 + x, y][3] else "." for x in range(8))
                        for y in range(8)])
    return out


# The tractor beam: 8 x 16 segments (one plotsprite a zone), stacked
# shuttle to ground; two frames
BEAM = [["..cbbc..", "..bccb.."] * 8, ["..bccb..", "..cbbc.."] * 8]

# An ore crate, 8 x 8. a band, b box, c ore glints
CRATE = art("""
bbbbbbbb
baaaaaab
bcbbcbbb
bbbcbbcb
bcbbbbbb
bbbbcbbb
baaaaaab
bbbbbbbb
""")

# A defence tower segment (8 x 16, stacked), and the turret that rides it
TOWER = art("""
..aaaa..
..a..a..
..aaaa..
...aa...
..a..a..
..aaaa..
..a..a..
..aaaa..
...aa...
..a..a..
..aaaa..
..a..a..
..aaaa..
...aa...
..a..a..
..aaaa..
""")
TURRET = art("""
...cc...
...cc...
..bccb..
.bbbbbb.
bbabbabb
bbbbbbbb
.bb..bb.
.b....b.
""")

# The stun pulse: a ring, 16 x 16
def ring():
    rows = []
    for y in range(16):
        r = ""
        for x in range(16):
            d = ((x - 7.5) ** 2 / 64 + (y - 7.5) ** 2 / 56) ** 0.5
            r += "c" if 0.82 < d < 1.0 else "."
        rows.append(r)
    return rows


# Terrain: characters after the font (codes 128 on, (64 + n) * 2). The
# ground is one row of these (zone 10): grass along the top, soil under it,
# the surface at the row's top line (y 160). One row only: a row of 21
# doublewide characters costs MARIA about 200 cycles a line, and the zone
# above (where the creatures stand) must keep its time for sprites.
# a grass, b soil, c stones.
# The surface rises and falls within the row: three levels, its top line 0,
# 4 or 8 lines down (FLAT0/4/8), and slopes a level up or down across a
# character (DOWN0: from 0 to 4 ...). tools/planet.py lays them out and
# writes each column's depth and slope for the game (creatures walk on it).
SOIL = ["bbbbbbbb", "bbcbbbbb", "bbbbbbbb", "bbbbbcbb", "bbbbbbbb", "bcbbbbbb", "bbbbbbbb",
        "bbbbbbcb", "bbbbbbbb", "bbbcbbbb", "bbbbbbbb", "cbbbbbbb", "bbbbbbbb", "bbbbbcbb",
        "bbbbbbbb", "bbcbbbbb"]
T_FLAT0, T_FLAT4, T_FLAT8, T_DOWN0, T_DOWN4, T_UP4, T_UP8, T_ROCK0 = range(64, 72)


def ground_tile(depth_at):
    """depth_at(x) -> the surface's line at pixel x (0-7)."""
    rows = []
    for y in range(16):
        r = ""
        for x in range(8):
            d = depth_at(x)
            if y < d:
                r += "."
            elif y == d:
                r += "a"
            elif y == d + 1:
                r += "a" if (x + y) % 3 else "b"
            else:
                r += SOIL[y][x]
        rows.append(r)
    return rows


TILES = {
    T_FLAT0: ground_tile(lambda x: 0),
    T_FLAT4: ground_tile(lambda x: 4),
    T_FLAT8: ground_tile(lambda x: 8),
    T_DOWN0: ground_tile(lambda x: x // 2),         # 0 -> 4 going right
    T_DOWN4: ground_tile(lambda x: 4 + x // 2),     # 4 -> 8
    T_UP4: ground_tile(lambda x: 4 - x // 2),       # 4 -> 0
    T_UP8: ground_tile(lambda x: 8 - x // 2),       # 8 -> 4
}
r0 = ground_tile(lambda x: 0)                         # flat, a stone on top
r0[0] = "..cc...."
TILES[T_ROCK0] = ["..c....."] + r0[1:]
TILES[T_ROCK0][0] = "..cc...."


def font():
    src = Image.open(GFX / "menufont.png")
    sp = src.load()
    first, last = 32, 95
    n = last - first + 1 + len(TILES)
    # 16 lines a glyph (a 16-line zone), the letter in the top 8
    im = Image.new("P", (n * 8, 16), 0)
    im.putpalette(PNG_PALETTE)
    px = im.load()
    for i in range(64):
        for y in range(8):
            for x in range(8):
                px[i * 8 + x, y] = 1 if sp[(first + i) * 8 + x, y] else 0
    for code, rows in TILES.items():
        assert len(rows) == 16 and all(len(r) == 8 for r in rows), code
        for y in range(16):
            for x in range(8):
                px[code * 8 + x, y] = ".abc".index(rows[y][x])
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
    for i, fr in enumerate(creature_frames()):
        save(f"creature{i:02d}", fr)
    for i, fr in enumerate(BEAM):
        save(f"beam{i}", fr)
    save("crate", CRATE)
    save("tower", TOWER)
    save("turret", TURRET)
    save("ring", ring())
    font()
    print("gfx: wrote", ", ".join(sorted(p.stem for p in GFX.glob("*.png"))))


if __name__ == "__main__":
    main()
