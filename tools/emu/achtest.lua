-- Achievements test: New Game (none earned); a pair of each kind kept: PAIRS
-- announced on the map; the star chart, then button 2: the achievements'
-- screen (bank 6), the cursor moves, button 2: back to the map. Screenshots
-- with SNAP_DIR (and -snapshot_directory). tools/test_ach.sh
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
local function ach() local m = mem(); return m:read_u8(0x25E5) | (m:read_u8(0x25E6) << 8) end
step(300, nil, nil)
step(100, "P1 Button 1", nil)                                  -- New Game
step(20, nil, function() check("none at the start", ach() == 0, string.format("%04x", ach()))
  local m = mem()
  for k = 0, 5 do m:write_u8(0x25A0 + k, 2) end                 -- a pair of each kept
  m:write_u8(0x25E7, 50)                                        -- 50 pirates
  m:write_u8(0x25E9, 2)                                         -- 2 storm rocks
  m:write_u8(0x27F7, 1) end)
step(20, nil, function() local m = mem()
  check("PAIRS, SURVEY, ACE earned", ach() & 7 == 7, string.format("%04x", ach()))
  check("one announced", m:read_u8(0x259D) == 5 and m:read_u8(0x25F8) == 0, string.format("message %d, which %d", m:read_u8(0x259D), m:read_u8(0x25F8)))
  shot() end)
step(30, "P1 Button 2", nil)                                   -- the star chart
step(30, "P1 Button 2", nil)                                   -- the achievements
step(10, nil, function() local m = mem()
  check("the achievements' screen", m:read_u8(0x259B) == 3 and m:read_u8(0x23EE) == 6, string.format("go %d, bank %d", m:read_u8(0x259B), m:read_u8(0x23EE))) end)
step(30, "P1 Right", nil)
step(30, "P1 Down", nil)
step(30, "P1 Right", nil)
step(10, nil, function() local m = mem()
  check("the cursor", m:read_u8(0x22FB) == 6, "on " .. m:read_u8(0x22FB))
  m:write_u8(0x22FB, 9); m:write_u8(0x27F7, 1) end)             -- STORMS: 2/5
step(10, nil, function() shot() end)
step(30, "P1 Button 2", nil)                                   -- back
step(20, nil, function() local m = mem()
  check("back to the map", m:read_u8(0x259B) == 0 and m:read_u8(0x22FC) == 0 and m:read_u8(0x23EE) == 4, string.format("go %d, view %d, bank %d", m:read_u8(0x259B), m:read_u8(0x22FC), m:read_u8(0x23EE))) end)
emu.register_frame_done(function()
  f = f + 1
  local held = {}
  local st = steps[si]
  if st then
    if f - t0 == 1 and st[3] then st[3]() end
    if st[2] and f - t0 >= 2 and f - t0 <= 6 then held[st[2]] = true end
    if f - t0 >= st[1] then si = si + 1; t0 = f end
  else
    print("ach: " .. table.concat(out, "; "))
    print("result " .. ((#bad == 0 and #out >= 6) and 1 or 0))
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
