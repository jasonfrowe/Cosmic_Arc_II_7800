-- Escape pod test: New Game; home made a planet, land; the Ark's energy to
-- 0 on the planet: the escape scene, then fire: home in a new Ark with a
-- tenth of the credits, the bank kept. Screenshots during the scene when
-- SNAP_DIR is set (with -snapshot_directory). tools/test_pod.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end
local function bcd(b) return (b >> 4) * 10 + (b & 15) end
local function rd3(a) local m = mem(); return bcd(m:read_u8(a)) * 10000 + bcd(m:read_u8(a + 1)) * 100 + bcd(m:read_u8(a + 2)) end
local out, bad = {}, {}
local function check(name, ok, detail) table.insert(out, string.format("%s: %s%s", name, ok and "ok" or "WRONG", detail and (" (" .. detail .. ")") or "")); if not ok then table.insert(bad, name) end end
local steps, si, t0, f = {}, 1, 0, 0
local function step(wait, press, fn) table.insert(steps, {wait, press, fn}) end
local snap = os.getenv("SNAP_DIR")
step(300, nil, nil)
step(100, "P1 Button 1", nil)                                  -- New Game
step(5, nil, function() local m = mem()
  m:write_u8(0x2680, 2)                                         -- home: a planet (VERDA, safe)
  m:write_u8(0x2594, 0x00); m:write_u8(0x2595, 0x12); m:write_u8(0x2596, 0x34)   -- 1234 credits
  m:write_u8(0x25A6, 0x00); m:write_u8(0x25A7, 0x05); m:write_u8(0x25A8, 0x00)   -- 500 in the bank
  m:write_u8(0x2588, 2); m:write_u8(0x2585, 3); m:write_u8(0x256B, 2); m:write_u8(0x25A0, 1)
  m:write_u8(0x2591, 7)
  m:write_u8(0x22FB, 0); m:write_u8(0x27F7, 1) end)
step(40, "P1 Button 1", nil)                                   -- land
step(200, nil, function() end)
step(2, nil, function() local m = mem(); m:write_u8(0x2386, 0); m:write_u8(0x2714, 6); m:write_u8(0x2715, 10) end)   -- the Ark lost (PL_LOST)
local scene = 0
step(400, nil, function() scene = f end)
step(40, "P1 Button 1", nil)
step(10, nil, function() local m = mem()
  check("home again", m:read_u8(0x2590) == 0, "sector " .. m:read_u8(0x2590))
  check("a tenth of the credits", rd3(0x2594) == 123, rd3(0x2594) .. "")
  check("the bank kept", rd3(0x25A6) == 500, rd3(0x25A6) .. "")
  check("a new Ark", m:read_u8(0x2588) == 0 and m:read_u8(0x2585) == 0 and m:read_u8(0x256B) == 0 and m:read_u8(0x25A0) == 0
    and m:read_u8(0x2591) == 20 and m:read_u8(0x2386) == 100)
  check("the message", m:read_u8(0x259D) == 4) end)
emu.register_frame_done(function()
  f = f + 1
  if snap and scene > 0 and (f - scene == 50 or f - scene == 90 or f - scene == 115 or f - scene == 260) then
    manager:machine().screens[":screen"]:snapshot()
  end
  local held = {}
  local st = steps[si]
  if st then
    if f - t0 == 1 and st[3] then st[3]() end
    if st[2] and f - t0 >= 2 and f - t0 <= 6 then held[st[2]] = true end
    if f - t0 >= st[1] then si = si + 1; t0 = f end
  else
    print("pod: " .. table.concat(out, "; "))
    print("result " .. ((#bad == 0 and #out >= 5) and 1 or 0))
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
