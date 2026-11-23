-- Leaving a planet early: docked, button 2 held 30 frames: LEAVING IN 3,
-- 2, 1, then the Ark goes (back to the map); a short press does nothing;
-- not with the storm coming; fire stops the count.
-- tools/test_leave.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end
local out, bad = {}, {}
local function check(name, ok, detail) table.insert(out, string.format("%s: %s%s", name, ok and "ok" or "WRONG", detail and (" (" .. detail .. ")") or "")); if not ok then table.insert(bad, name) end end
local steps, si, t0, f = {}, 1, 0, 0
local function step(wait, press, fn, hold) table.insert(steps, {wait, press, fn, hold}) end
local tstart
step(300, nil, nil)
step(100, "P1 Button 1", nil)                                  -- New Game
step(5, nil, function() local m = mem()
  m:write_u8(0x2680, 2); m:write_u8(0x25D5, 0); m:write_u8(0x22FB, 0); m:write_u8(0x27F7, 1) end)
step(40, "P1 Button 1", nil)                                   -- land
step(260, nil, nil)
step(30, "P1 Button 2", nil, 10)                               -- a short press: nothing
step(5, nil, function() local m = mem()
  check("a short press: nothing", m:read_u8(0x27C1) == 0 and m:read_u8(0x2714) == 0) end)
step(40, "P1 Button 2", function() mem():write_u8(0x27D2, 1) end, 40)   -- held, the storm coming
step(5, nil, function() local m = mem()
  check("the storm coming: no leaving", m:read_u8(0x27C1) == 0 and m:read_u8(0x2714) == 0)
  m:write_u8(0x27D2, 0) end)
step(40, "P1 Button 2", nil, 40)                               -- held
step(5, nil, function() local m = mem()
  check("held 30 frames: the countdown", m:read_u8(0x27C1) > 0, "frames to go " .. m:read_u8(0x27C1)) end)
step(20, "P1 Button 1", nil, 3)                                -- fire: off
step(5, nil, function() local m = mem()
  check("fire stops it", m:read_u8(0x27C1) == 0 and m:read_u8(0x2714) == 0) end)
step(40, "P1 Button 2", nil, 40)                               -- again
step(5, nil, function() local m = mem()
  check("again: the countdown", m:read_u8(0x27C1) > 0) end)
step(400, nil, nil)
step(5, nil, function() local m = mem()
  check("the Ark's gone: back on the map", m:read_u8(0x22FC) == 0 and m:read_u8(0x23EE) == 4, string.format("bank %d", m:read_u8(0x23EE))) end)
emu.register_frame_done(function()
  f = f + 1
  local held = {}
  local st = steps[si]
  if st then
    if f - t0 == 1 and st[3] then st[3]() end
    if st[2] and f - t0 >= 2 and f - t0 <= 1 + (st[4] or 5) then held[st[2]] = true end
    if f - t0 >= st[1] then si = si + 1; t0 = f end
  else
    print("leave: " .. table.concat(out, "; "))
    print("result " .. ((#bad == 0 and #out >= 6) and 1 or 0))
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
