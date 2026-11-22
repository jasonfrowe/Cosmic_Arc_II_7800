-- Storm test: the clock runs out; a rock comes at the Ark.
--  DOCKED=1: the shuttle stays aboard; the stick fires the Ark's laser at
--  the rock's side: it must be shot down, the Ark unhurt, the planet over.
--  DOCKED=0: the shuttle stays out: the rock must hit the Ark (16) and the
--  planet end. tools/test_storm.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local docked = os.getenv("DOCKED") == "1"
local f, e0, stormseen, shot, hit, over = 0, nil, false, false, false, false
emu.register_frame_done(function()
  f = f + 1
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  local held = {}
  if f >= 290 and f <= 296 then held["Select"] = true end
  if f > 340 then m:write_u8(0x27BC, 200) end            -- no pulses: just the storm
  if f == 345 then m:write_u8(0x2712, 3) end            -- the storm in 3 s
  local st, ss = m:read_u8(0x2709), m:read_u8(0x27D2)
  if f > 345 and m:read_u8(0x2714) == 0 then
    if not docked and st == 0 then held["P1 Down"] = true end
    if docked and ss == 2 then
      local d = m:read_u8(0x27D9)
      local k = ({[0] = "P1 Up", "P1 Left", "P1 Right"})[d]
      if f % 8 < 4 then held[k] = true end              -- fresh pushes
    end
    if ss == 1 and not e0 then e0 = m:read_u8(0x2386); stormseen = true end
  end
  if ss == 3 and not over then
    over = true
    local e = m:read_u8(0x2386)
    hit = e < (e0 or 0)
  end
  for name, field in pairs(fields) do if name:match("^P1 ") or name == "Select" then field:set_value(held[name] and 1 or 0) end end
  if over and (m:read_u8(0x2714) == 3 or m:read_u8(0x2714) == 5) or f > 3000 then
    print(string.format("%s: storm %s, the Ark %s (%d -> %d), the planet %s",
      docked and "docked, firing" or "shuttle out", stormseen and "came" or "never came",
      hit and "hit" or "unhurt", e0 or -1, m:read_u8(0x2386), over and "over" or "NOT over"))
    print(string.format("result %d %d %d", stormseen and 1 or 0, hit and 1 or 0, over and 1 or 0))
    manager:machine():exit()
  end
end)
