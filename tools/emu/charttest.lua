-- Chart test: the map's pages (DESIGN.md 3.6b). New Game; the sector view
-- lists a warp with its way and, with its way back cut, a red > (one way);
-- button 2: the star chart, its cursor on the Ark; fire on a far cell does
-- nothing; the stick moves the cursor a cell onto the warp's sector, the
-- panel offers FIRE: WARP; fire warps there (still on the chart, the cursor
-- on the Ark again); button 2 on through the close-up and the achievements,
-- back to the sector view. Screenshots with SNAP_DIR (and
-- -snapshot_directory). tools/test_chart.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end
local out, bad = {}, {}
local function check(name, ok, detail) table.insert(out, string.format("%s: %s%s", name, ok and "ok" or "WRONG", detail and (" (" .. detail .. ")") or "")); if not ok then table.insert(bad, name) end end
local steps, si, t0, f = {}, 1, 0, 0
local function step(wait, press, fn) table.insert(steps, {wait, press, fn}) end
local snap = os.getenv("SNAP_DIR")
local function shot() if snap then manager:machine().screens[":screen"]:snapshot() end end
local DCOL = {[0] = 0, 1, 1, 1, 0, -1, -1, -1}
local DROW = {[0] = -1, -1, 0, 1, 1, 1, 0, -1}
local DIRF = {[0] = {"P1 Up"}, {"P1 Up", "P1 Right"}, {"P1 Right"}, {"P1 Down", "P1 Right"},
  {"P1 Down"}, {"P1 Down", "P1 Left"}, {"P1 Left"}, {"P1 Up", "P1 Left"}}
local CH = function(c) return (string.byte(c) - 32) * 2 end
local d, target, tcell                                           -- home's first warp
local pressdir = nil
step(300, nil, nil)
step(100, "P1 Button 1", nil)                                    -- New Game
step(20, nil, function() local m = mem()
  local w, cell = m:read_u8(0x2600), m:read_u8(0x2640)
  for k = 0, 7 do if w & (1 << k) ~= 0 then d = k; break end end
  tcell = ((cell >> 4) + DROW[d]) * 16 + (cell & 15) + DCOL[d]
  for s = 0, 63 do if m:read_u8(0x2640 + s) == tcell then target = s end end
  m:write_u8(0x2600 + target, m:read_u8(0x2600 + target) & ~(1 << ((d + 4) % 8)))   -- no way back
  m:write_u8(0x27F7, 1) end)
step(10, nil, function() local m = mem()
  -- home's a port: item 0 DOCK, item 1 the first warp (row 4, column 20)
  local way = string.sub("N NEE SES SWW NW", d * 2 + 1, d * 2 + 2)
  check("the warp's way", m:read_u8(0x22B5) == CH(way:sub(1, 1)) and m:read_u8(0x22B6) == CH(way:sub(2, 2)), way)
  check("one way: >", m:read_u8(0x22B8) == CH(">"), string.format("%d", m:read_u8(0x22B8)))
  shot() end)
step(30, "P1 Button 2", nil)                                     -- the star chart
step(10, nil, function() local m = mem()
  local cell = m:read_u8(0x2640)
  check("the chart, the cursor on the Ark", m:read_u8(0x22FC) == 1 and m:read_u8(0x237E) == (cell & 15) and m:read_u8(0x237F) == (cell >> 4),
    string.format("view %d, cursor %d,%d", m:read_u8(0x22FC), m:read_u8(0x237E), m:read_u8(0x237F)))
  m:write_u8(0x237E, ((cell & 15) + 6) % 12); m:write_u8(0x237F, ((cell >> 4) + 4) % 8); m:write_u8(0x27F7, 1) end)
step(30, "P1 Button 1", nil)                                     -- fire on a far cell
step(10, nil, function() local m = mem()
  check("a far cell: no warp", m:read_u8(0x2590) == 0 and m:read_u8(0x22FC) == 1 and m:read_u8(0x2592) == 0,
    string.format("sector %d, view %d", m:read_u8(0x2590), m:read_u8(0x22FC)))
  local cell = m:read_u8(0x2640)
  m:write_u8(0x237E, cell & 15); m:write_u8(0x237F, cell >> 4); m:write_u8(0x27F7, 1)
  pressdir = d end)
step(30, nil, function() pressdir = nil end)                     -- (the stick, 5 frames)
step(10, nil, function() local m = mem()
  check("the cursor a cell over", m:read_u8(0x237E) == (tcell & 15) and m:read_u8(0x237F) == (tcell >> 4),
    string.format("%d,%d (want %d,%d)", m:read_u8(0x237E), m:read_u8(0x237F), tcell & 15, tcell >> 4))
  check("the panel: FIRE: WARP", m:read_u8(0x2778 + 29) == CH("F") and m:read_u8(0x2778 + 35) == CH("W"))
  shot() end)
step(30, "P1 Button 1", nil)                                     -- warp
step(20, nil, function() local m = mem()
  check("warped there, still on the chart", m:read_u8(0x2590) == target and m:read_u8(0x22FC) == 1 and m:read_u8(0x2592) == 1,
    string.format("sector %d (want %d), view %d, date %d", m:read_u8(0x2590), target, m:read_u8(0x22FC), m:read_u8(0x2592)))
  check("the cursor on the Ark again", m:read_u8(0x237E) == (tcell & 15) and m:read_u8(0x237F) == (tcell >> 4))
  shot() end)
step(30, "P1 Button 2", nil)                                     -- the close-up
step(10, nil, function() local m = mem()
  check("the close-up", m:read_u8(0x259B) == 3 and m:read_u8(0x22F7) == 0); shot() end)
step(30, "P1 Button 2", nil)                                     -- the achievements
step(10, nil, function() local m = mem()
  check("the achievements", m:read_u8(0x259B) == 3 and m:read_u8(0x22F7) == 1); shot() end)
step(30, "P1 Button 2", nil)                                     -- round to the sector view
step(20, nil, function() local m = mem()
  check("back to the sector view", m:read_u8(0x259B) == 0 and m:read_u8(0x22FC) == 0 and m:read_u8(0x2590) == target)
  shot() end)
emu.register_frame_done(function()
  f = f + 1
  local held = {}
  local st = steps[si]
  if st then
    if f - t0 == 1 and st[3] then st[3]() end
    if st[2] and f - t0 >= 2 and f - t0 <= 6 then held[st[2]] = true end
    if pressdir and f - t0 >= 2 and f - t0 <= 6 then for _, n in ipairs(DIRF[pressdir]) do held[n] = true end end
    if f - t0 >= st[1] then si = si + 1; t0 = f end
  else
    print("chart: " .. table.concat(out, "; "))
    print("result " .. ((#bad == 0 and #out >= 10) and 1 or 0))
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
