#!/usr/bin/env python3
"""Finish the .a78 header that 7800basic wrote: add what it can't say.

  - a second POKEY at $0440 beside the one at $0450 (7800basic's
    "set pokeysupport $450" sets cart type bit 6): cart type bit 10, and the
    v4 audio field (byte 67) = 3, $0440 + $0450 (as Super Mega Pinball 7800)
  - the AstroCart math unit: "ACM" at bytes 59-61
  - the save device: byte 58 = 2, SaveKey / AtariVox

usage: a78header.py IN.a78 OUT.a78
"""
import sys

data = bytearray(open(sys.argv[1], "rb").read())
h = data
assert h[1:10] == b"ATARI7800", "not an .a78 file"
cart = (h[53] << 8) | h[54]
assert cart & 0x0040, "expected POKEY at $0450 (set pokeysupport $450)"
assert cart & 0x0002, "expected SuperGame bank switching"
cart |= 0x0400
h[53], h[54] = cart >> 8, cart & 0xFF
h[58] = 2
h[59:62] = b"ACM"
if h[0] >= 4:
    h[67] = 3
open(sys.argv[2], "wb").write(data)
size = (h[49] << 24) | (h[50] << 16) | (h[51] << 8) | h[52]
print(f"{sys.argv[2]}: {size // 1024}K, cart type ${cart:04X}, POKEYs $0450+$0440, math unit, SaveKey")
