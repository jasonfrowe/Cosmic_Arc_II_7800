#!/usr/bin/env python3
"""After the build: every group of numbered frames (creature00..23, saucer0..3,
...) must be contiguous: the code finds a frame as the first's address plus
frame * width. 7800basic moves graphics to the next block when a line's 256
bytes fill, which can split a group (the creatures, once the font grew):
then frames read other graphics. Fails the build if any group is split."""
import re
import sys
from collections import defaultdict
from pathlib import Path

asm = Path(sys.argv[1]).read_text()
groups = defaultdict(dict)
for name, num, addr in re.findall(r"^([a-z_]+?)(\d+) = \$([0-9A-F]{4})$", asm, re.M):
    groups[name][int(num)] = int(addr, 16)
bad = 0
for name, fr in sorted(groups.items()):
    nums = sorted(fr)
    if len(nums) < 2 or nums != list(range(nums[0], nums[0] + len(nums))):
        continue
    step = fr[nums[1]] - fr[nums[0]]
    for a, b in zip(nums, nums[1:]):
        if fr[b] - fr[a] != step or step <= 0 or (fr[a] & 0xFF00) != (fr[b] & 0xFF00):
            print(f"gfxcheck: {name}{a} ${fr[a]:04X} -> {name}{b} ${fr[b]:04X}: the group is split")
            bad = 1
            break
print(f"gfxcheck: {len(groups)} frame groups checked")
sys.exit(bad)
