#!/usr/bin/env python3
"""Build Cosmic Arc II's manual: a 5 x 7 inch booklet (docs/manual/manual.html,
laid out like the RP6502 port's), its images and its PDF.

    .venv/bin/python tools/make_manual.py            # images from the shots, the PDF
    .venv/bin/python tools/make_manual.py --shots    # take the screenshots again first
    .venv/bin/python tools/make_manual.py --no-pdf   # images only

--shots runs the a7800 fork headless (A7800, as the tests): the map's and
port's screens from tools/emu/manualshots.lua (two runs on a SaveKey), deep
space and a planet from tools/emu/snap.lua with fixed inputs (the emulation
is deterministic, so the frames below are always the same picture). The raw
snapshots go in build/manual/; the cropped ones in docs/manual/img/.
Sprites are drawn from src/gfx/*.png in the game's palettes (A7800_PAL: the
emulator's colours, read off the screen for each value). Needs Pillow (the
project's .venv) and, for the PDF, Google Chrome.
"""

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ROM = ROOT / "build" / "cosmicarc.a78"
GFX = ROOT / "src" / "gfx"
MAN = ROOT / "docs" / "manual"
IMG = MAN / "img"
RAW = ROOT / "build" / "manual"
A7800 = Path(os.environ.get("A7800", Path.home() / "Software" / "a7800" / "mame64"))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# the 7800's 256 colours as the emulator shows them (RGB, value 0-255)
A7800_PAL = (
    "0000001e1e1e333333454545575757676767767676858585939393a1a1a1afafafbcbcbcc9c9c9d6d6d6e3e3e3efefef"
    "2715003a2b004c3e005d50006d61007c70008b7f00998e00a79c17b4aa2dc2b740cfc452dbd162e8de72f4ea81fff78f"
    "460000570f00672700773b00854d00945d00a26d00af7c13bd8b2aca993dd7a74fe3b55fefc26ffccf7effdb8dffe89b"
    "560000660000760d00842500933900a14b1aae5c30bc6c43c97b54d68a64e29874efa683fbb491ffc19fffceadffdbba"
    "560000660005760020851535932c47a13f58af5168bc6178c97187d68095e38fa3ef9db1fbaabeffb8cbffc5d8ffd2e4"
    "47003e58004f68006078117087297f953c8da34e9bb05fa9be6fb7cb7ec4d88cd1e49addf0a8eafdb6f6ffc3ffffd0ff"
    "29006e3c007d4e008c5f1c9a6f31a87e44b58c55c29b65cfa875dcb684e8c392f5d0a0ffddaeffe9bbfff5c8ffffd5ff"
    "0000861300942a19a23e2fb04f42bd6053ca7064d77f73e48d82f09c91fca99fffb7adffc4baffd1c7ffddd4ffeae0ff"
    "000086001d950032a31745b02d56bd4166cb5276d76285e47293f081a1fc90afff9ebcffabc9ffb9d6ffc6e3ffd3efff"
    "00216e00367d00488c00599a0f69a82778b53b87c34d96d05da3dc6db1e97cbef58bcbff99d8ffa7e5ffb5f1ffc2fdff"
    "00343e00465000576100687000777f1c868e31949c44a2aa55b0b765bdc475cad184d7de92e4eaa0f0f7aefcffbbffff"
    "003c00004e07005f21006e360d7e48258c59399a694ba8795cb6876cc3967bd0a48adcb198e9bea6f5cbb4ffd8c1ffe5"
    "003a00004c00005d00156c002b7c003e8a1b50993161a64370b4557fc1658ece759cdb83aae792b7f4a0c4ffaed1ffbb"
    "002d001040002751003b62004d71005e81006d8f007d9d138bab2a9ab83da7c54fb5d260c2df70cfeb7fdcf88de8ff9b"
    "2615003a2b004c3f005d50006d61007c71008b8000998e00a79c17b4aa2dc1b840cec552dbd262e7de72f4eb81fff78f"
    "450000571000672700763b00854d00945e00a26d00af7d12bc8b29ca993dd6a74ee3b55fefc26ffbcf7effdc8dffe89b"
)
PAL = [tuple(int(A7800_PAL[i * 6 + k * 2:i * 6 + k * 2 + 2], 16) for k in range(3)) for i in range(256)]

# The display's 192 lines in a snapshot (320 x 243): from line TOP; a
# 16-line row r at TOP + 16 r
TOP = 26


def emu(args, env=None, cwd=None):
    e = dict(os.environ)
    e.update(env or {})
    subprocess.run([str(A7800), "a7800", "-cart", str(ROM), "-video", "none", "-sound", "none",
                    "-nothrottle", "-skip_gameinfo", "-nomouse"] + args,
                   cwd=str(A7800.parent), env=e, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def snap(out, frames, env):
    """tools/snap.sh's run: snapshots at the frames (in order) -> list of paths"""
    d = RAW / out
    shutil.rmtree(d, ignore_errors=True)
    d.mkdir(parents=True)
    env = dict(env, SNAP_FRAMES=",".join(str(f) for f in frames))
    emu(["-seconds_to_run", "120", "-snapshot_directory", str(d),
         "-autoboot_script", str(ROOT / "tools" / "emu" / "snap.lua")], env)
    return sorted((d / "a7800").glob("*.png"))


def take_shots():
    RAW.mkdir(parents=True, exist_ok=True)
    # the map and the ports: two runs on one SaveKey
    d = RAW / "map"
    shutil.rmtree(d, ignore_errors=True)
    d.mkdir()
    with tempfile.TemporaryDirectory() as nv:
        for phase in "AB":
            emu(["-joy2", "savekey", "-nvram_directory", nv, "-snapshot_directory", str(d),
                 "-autoboot_script", str(ROOT / "tools" / "emu" / "manualshots.lua")], {"PHASE": phase})
    # deep space: energy held full, the stick and fire by hand (rocks pile up)
    a = snap("space", [700, 2900], {"NOPLANET": "1", "TESTMODE": "1", "WAVELOG": "1",
        "INPUTS": "300-305:P1 Button 1;500-560:P1 Up;700-2000:P1 Button 1;700-900:P1 Right;"
                  "1000-1200:P1 Down;1300-1500:P1 Left;1600-1800:P1 Up"})
    b = snap("fighter", [1500], {"NOPLANET": "1", "TESTMODE": "1", "WAVELOG": "1",
        "AUTOFIGHTER": "1100", "INPUTS": "300-305:P1 Button 1"})
    # a planet (Select on the title), its autopilot
    c = snap("planet", [390, 870, 1740], {"AUTOPLANET": "420", "INPUTS": "290-296:Select"})
    for src, name in zip(a + b + c, ["space_pirates", "space_raid", "space_fighter",
                                     "planet_orbit", "planet_pulse", "planet_beam"]):
        shutil.copy(src, d / (name + ".png"))


def crop(name, rows=None, out=None, scale=1):
    """a shot without the overscan (or rows a-b of it), into img/"""
    im = Image.open(RAW / "map" / (name + ".png")).convert("RGB")
    a, b = rows or (0, 12)
    im = im.crop((0, TOP + 16 * a, 320, TOP + 16 * b))
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(IMG / ((out or name) + ".png"))


# sprites: the PNG's colour indexes 1-3 -> the palette's colours (0 clear)
SPRITES = {
    "spr_ark": ("ark", (0x44, 0x42, 0x4C)),
    "spr_rock_l": ("rock_l", (0x62, 0x66, 0x6A)),
    "spr_rock_m": ("rock_m", (0x62, 0x66, 0x6A)),
    "spr_rock_s": ("rock_s", (0x62, 0x66, 0x6A)),
    "spr_raider": ("raider0", (0x04, 0x36, 0x1E)),
    "spr_gunship": ("gunship", (0x04, 0x36, 0x1E)),
    "spr_missile": ("missile0", (0x04, 0x36, 0x1E)),
    "spr_pod": ("pod0", (0x98, 0x9A, 0x0F)),
    "spr_saucer": ("saucer0", (0xD4, 0xDC, 0x0F)),
    "spr_crate": ("crate", (0xC6, 0x22, 0xE4)),
    "spr_relic": ("crate", (0x98, 0xAC, 0x0E)),
}
for k in range(6):                       # the creatures: kind x 4 (P2 on a planet)
    SPRITES["spr_c%d" % k] = ("creature%02d" % (k * 4), (0x1C, 0x4A, 0x9C))


def sprite(out, src, cols, scale=6):
    im = Image.open(GFX / (src + ".png"))
    w, h = im.size
    px = im.load()
    o = Image.new("RGBA", (w * 2, h), (0, 0, 0, 0))       # 160A: a pixel two wide
    for y in range(h):
        for x in range(w):
            i = px[x, y]
            if i:
                o.putpixel((2 * x, y), PAL[cols[i - 1]] + (255,))
                o.putpixel((2 * x + 1, y), PAL[cols[i - 1]] + (255,))
    o.resize((w * 2 * scale, h * scale), Image.NEAREST).save(IMG / (out + ".png"))


def images():
    IMG.mkdir(parents=True, exist_ok=True)
    for n in ["title", "voyages", "sector", "chart", "closeup", "achieve", "port_trade",
              "port_bounty", "port_yard", "port_bank", "space_pirates", "space_raid",
              "space_fighter", "planet_orbit", "planet_pulse", "planet_beam"]:
        crop(n)
    crop("space_pirates", (0, 1), "space_hud_top", 2)
    crop("space_pirates", (11, 12), "space_hud_bot", 2)
    crop("planet_beam", (0, 2), "planet_hud_top", 2)
    crop("planet_beam", (11, 12), "planet_hud_bot", 2)
    for out, (src, cols) in SPRITES.items():
        sprite(out, src, cols)


def pdf():
    out = MAN / "Cosmic_Arc_II_Manual_5x7.pdf"
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-pdf-header-footer",
                    "--print-to-pdf=" + str(out), (MAN / "manual.html").as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("wrote", out.relative_to(ROOT))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shots", action="store_true", help="take the screenshots again")
    ap.add_argument("--no-pdf", action="store_true")
    a = ap.parse_args()
    if a.shots or not (RAW / "map" / "title.png").exists():
        take_shots()
    images()
    if not a.no_pdf:
        pdf()


if __name__ == "__main__":
    main()
