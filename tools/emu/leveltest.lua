-- Planet levels: a planet far out (sector 61) is level 5 (L5 on the sector
-- view) with only rare kinds (gliders, blinkers); one at home is level 1
-- with only common ones (walkers, hoppers, runners). tools/test_level.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end
local out, bad = {}, {}
local function check(name, ok, detail) table.insert(out, string.format("%s: %s%s", name, ok and "ok" or "WRONG", detail and (" (" .. detail .. ")") or "")); if not ok then table.insert(bad, name) end end
local steps, si, t0, f = {}, 1, 0, 0
local function step(wait, press, fn) table.insert(steps, {wait, press, fn}) end
local function txt(row) local m = mem(); local base = (row < 6) and (0x2200 + row * 40) or (0x2700 + (row - 6) * 40)
  local t = {}; for i = 0, 39 do local c = m:read_u8(base + i) // 2 + 32; t[#t + 1] = (c >= 32 and c < 96) and string.char(c) or "." end
  return table.concat(t) end
local function kinds() local m = mem(); local t = {}
  for i = 0, m:read_u8(0x2717) - 1 do t[#t + 1] = m:read_u8(0x2720 + i) - 1 end
  return t end
local function within(t, lo, hi) for _, k in ipairs(t) do if k < lo or k > hi then return false end end return #t > 0 end
local function land(sec) return function() local m = mem()
  m:write_u8(0x2590, sec); m:write_u8(0x259C, sec)
  m:write_u8(0x2680 + sec, 2)                                   -- a planet, no easy bit, tier 0 (no encounter after)
  m:write_u8(0x25D5 + (sec >> 1), 0)
  m:write_u8(0x22FB, 0); m:write_u8(0x27F7, 1) end end
step(300, nil, nil)
step(100, "P1 Button 1", nil)                                  -- New Game
step(20, nil, land(60))
step(20, nil, function() check("sector 61: L5 on the sector view", txt(1):find("L5") ~= nil, txt(1)) end)
step(40, "P1 Button 1", nil)
step(260, nil, function() local m = mem(); local k = kinds()
  check("level 5: rare kinds only", m:read_u8(0x258E) == 5 and within(k, 4, 5), "level " .. m:read_u8(0x258E) .. ", kinds " .. table.concat(k, " "))
  m:write_u8(0x2714, 3) end)                                    -- the planet's done
step(150, nil, land(0))
step(20, nil, function() check("home: L1", txt(1):find("L1") ~= nil, txt(1)) end)
step(40, "P1 Button 1", nil)
step(260, nil, function() local m = mem(); local k = kinds()
  check("level 1: common kinds only", m:read_u8(0x258E) == 1 and within(k, 0, 2), "level " .. m:read_u8(0x258E) .. ", kinds " .. table.concat(k, " ")) end)
emu.register_frame_done(function()
  f = f + 1
  local held = {}
  local st = steps[si]
  if st then
    if f - t0 == 1 and st[3] then st[3]() end
    if st[2] and f - t0 >= 2 and f - t0 <= 6 then held[st[2]] = true end
    if f - t0 >= st[1] then si = si + 1; t0 = f end
  else
    print("level: " .. table.concat(out, "; "))
    print("result " .. ((#bad == 0 and #out >= 4) and 1 or 0))
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
