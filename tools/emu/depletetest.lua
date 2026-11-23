-- Depletion test: New Game; 3 jumps (safe space: no encounters) restock a
-- port (a step back to normal, its glut down one) and give a planet one
-- creature back; a barren planet won't be landed on; a planet with one left
-- has one. tools/test_deplete.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end
local out, bad = {}, {}
local function check(name, ok, detail) table.insert(out, string.format("%s: %s%s", name, ok and "ok" or "WRONG", detail and (" (" .. detail .. ")") or "")); if not ok then table.insert(bad, name) end end
local steps, si, t0, f = {}, 1, 0, 0
local function step(wait, press, fn) table.insert(steps, {wait, press, fn}) end
local class
step(300, nil, nil)
step(100, "P1 Button 1", nil)                                  -- New Game
step(5, nil, function() local m = mem()
  for x = 0, 63 do                                              -- no encounters: tier 0, no nebulae
    local i = m:read_u8(0x2680 + x) & 0x3F
    if i & 3 == 3 then i = i & 0x3C end
    m:write_u8(0x2680 + x, i)
  end
  class = (m:read_u8(0x2680) >> 2) & 7
  for k = 0, 2 do m:write_u8(0x25A9 + k, (class & (1 << k)) ~= 0 and 5 or 9) end
  m:write_u8(0x25CA, 2)                                         -- home's glut
  m:write_u8(0x25D5, 0x02)                                      -- sector 0's planet: 2 taken
  m:write_u8(0x25FC, 0); m:write_u8(0x25FD, 0)
  m:write_u8(0x27F7, 1) end)
for j = 1, 3 do
  step(20, nil, function() local m = mem(); m:write_u8(0x22FB, m:read_u8(0x22FA) - 1); m:write_u8(0x27F7, 1) end)
  step(40, "P1 Button 1", nil)
end
step(10, nil, function() local m = mem()
  local ok = true
  for k = 0, 2 do
    local want = (class & (1 << k)) ~= 0 and 6 or 8
    if m:read_u8(0x25A9 + k) ~= want then ok = false end
  end
  check("a port restocks", ok and m:read_u8(0x25CA) == 1, string.format("stock %d %d %d, glut %d", m:read_u8(0x25A9), m:read_u8(0x25AA), m:read_u8(0x25AB), m:read_u8(0x25CA)))
  check("a planet's creatures come back", m:read_u8(0x25D5) & 15 == 1, string.format("taken %d", m:read_u8(0x25D5) & 15))
  check("no encounter on the way", m:read_u8(0x259B) == 0)
  -- this sector becomes a barren planet
  local x = m:read_u8(0x2590)
  m:write_u8(0x2680 + x, 2)
  local b = 0x25D5 + (x >> 1)
  m:write_u8(b, (x & 1) == 1 and 0x40 or 0x04)
  m:write_u8(0x22FB, 0); m:write_u8(0x27F7, 1) end)
step(40, "P1 Button 1", nil)
step(10, nil, function() local m = mem()
  check("a barren planet: no landing", m:read_u8(0x259B) == 0 and m:read_u8(0x259D) == 3, string.format("go %d, message %d", m:read_u8(0x259B), m:read_u8(0x259D)))
  local x = m:read_u8(0x2590)
  m:write_u8(0x25D5 + (x >> 1), (x & 1) == 1 and 0x30 or 0x03)  -- one left
  m:write_u8(0x27F7, 1) end)
step(40, "P1 Button 1", nil)
step(200, nil, nil)
step(10, nil, function() local m = mem()
  check("one left: one there", m:read_u8(0x2572) == 1 and m:read_u8(0x2717) == 1, string.format("pop %d, on the planet %d", m:read_u8(0x2572), m:read_u8(0x2717))) end)
emu.register_frame_done(function()
  f = f + 1
  local held = {}
  local st = steps[si]
  if st then
    if f - t0 == 1 and st[3] then st[3]() end
    if st[2] and f - t0 >= 2 and f - t0 <= 6 then held[st[2]] = true end
    if f - t0 >= st[1] then si = si + 1; t0 = f end
  else
    print("deplete: " .. table.concat(out, "; "))
    print("result " .. ((#bad == 0 and #out >= 5) and 1 or 0))
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
