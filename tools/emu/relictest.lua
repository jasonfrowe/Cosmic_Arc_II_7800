-- Relic test: New Game; home made a barren planet with the relic: RELIC
-- SIGNAL on the sector view, and it can still be landed on; on the planet
-- the relic's there (one creature); carried, a quarter speed across; docked,
-- it's aboard; at a port, 2000 credits; RELIC earned. tools/test_relic.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end
local function bcd(b) return (b >> 4) * 10 + (b & 15) end
local function credits() local m = mem(); return bcd(m:read_u8(0x2594)) * 10000 + bcd(m:read_u8(0x2595)) * 100 + bcd(m:read_u8(0x2596)) end
local out, bad = {}, {}
local function check(name, ok, detail) table.insert(out, string.format("%s: %s%s", name, ok and "ok" or "WRONG", detail and (" (" .. detail .. ")") or "")); if not ok then table.insert(bad, name) end end
local steps, si, t0, f = {}, 1, 0, 0
local function step(wait, press, fn, untilfn) table.insert(steps, {wait, press, fn, untilfn}) end
local snap = os.getenv("SNAP_DIR")
local maxv, c0 = 0, 0
local function txt(row) local m = mem(); local base = (row < 6) and (0x2200 + row * 40) or (0x2700 + (row - 6) * 40)
  local t = {}; for i = 0, 39 do local c = m:read_u8(base + i) // 2 + 32; t[#t + 1] = (c >= 32 and c < 96) and string.char(c) or "." end
  return table.concat(t) end
step(300, nil, nil)
step(100, "P1 Button 1", nil)                                  -- New Game
step(5, nil, function() local m = mem()
  m:write_u8(0x2680, 2)                                         -- home: a planet (safe), barren
  m:write_u8(0x25FA, 0); m:write_u8(0x25FB, 0); m:write_u8(0x25D5, 0x04)
  m:write_u8(0x22FB, 0); m:write_u8(0x27F7, 1) end)
step(20, nil, function() check("RELIC SIGNAL on the sector view", txt(1):find("RELIC SIGNAL") ~= nil, txt(1)) end)
step(40, "P1 Button 1", nil)                                   -- land
step(260, nil, function() local m = mem()
  check("down on the barren planet, the relic there", m:read_u8(0x27C0) == 1 and m:read_u8(0x2717) == 1, string.format("relic %d, creatures %d", m:read_u8(0x27C0), m:read_u8(0x2717))) end)
step(120, "P1 Down", nil)                                      -- out of the Ark (held: see below)
step(2, nil, function() local m = mem()
  m:write_u8(0x270A, 3); m:write_u8(0x270B, 1); m:write_u8(0x2761, 4) end)   -- the relic in the shuttle
step(120, "P1 Right", function() maxv = 0 end)
step(2, nil, function() check("a quarter speed across", maxv > 0 and maxv <= 128, "top " .. maxv) end)
step(2, nil, function() local m = mem(); m:write_u8(0x2700, 0); m:write_u8(0x2701, 2); m:write_u8(0x2703, 0); m:write_u8(0x2704, 0) end)
step(900, "P1 Up", nil, function() return mem():read_u8(0x2709) == 0 end)   -- up into the Ark
step(10, nil, function() local m = mem()
  check("docked: the relic aboard", m:read_u8(0x25FB) == 1, "state " .. m:read_u8(0x25FB))
  m:write_u8(0x2714, 3) end)                                    -- the planet's done
step(120, nil, function() local m = mem()
  m:write_u8(0x2680, 1 | (2 << 2)); m:write_u8(0x22FB, 0); m:write_u8(0x27F7, 1); c0 = credits() end)  -- home: a port again
step(40, "P1 Button 1", nil)                                   -- dock
step(10, nil, function() local m = mem()
  check("the port pays 2000", credits() - c0 == 2000 and m:read_u8(0x25FB) == 2, string.format("+%d, state %d", credits() - c0, m:read_u8(0x25FB)))
  if snap then manager:machine().screens[":screen"]:snapshot() end
  m:write_u8(0x22FB, 3); m:write_u8(0x27F7, 1) end)             -- LEAVE PORT (commodities: line 3)
step(40, "P1 Button 1", nil)
step(30, nil, function() local m = mem()
  check("RELIC earned", m:read_u8(0x25F5) & 64 ~= 0, string.format("%02x", m:read_u8(0x25F5))) end)
emu.register_frame_done(function()
  f = f + 1
  local m = mem()
  if m:read_u8(0x23EE) == 3 then m:write_u8(0x27BC, 200) end     -- on the planet: no pulses (this tests the relic)
  local v = m:read_u8(0x2703) + 256 * m:read_u8(0x2704)
  if v < 32768 and v > maxv then maxv = v end
  local held = {}
  local st = steps[si]
  if st then
    if f - t0 == 1 and st[3] then st[3]() end
    local long = st[2] and st[2]:match("^P1 [UDLR]")          -- the stick: held throughout
    if st[2] and f - t0 >= 2 and (long or f - t0 <= 6) then held[st[2]] = true end
    if f - t0 >= st[1] or (st[4] and f - t0 > 2 and st[4]()) then si = si + 1; t0 = f end
  else
    print("relic: " .. table.concat(out, "; "))
    print("result " .. ((#bad == 0 and #out >= 6) and 1 or 0))
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
