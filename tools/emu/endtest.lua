-- Deep space endings. tools/test_spaceend.sh
--  MODE=saucer: the saucer out when the wave's cleared: the Ark mustn't
--   leave (ST_DEPART) until it's back aboard, and must leave once it is.
--  MODE=over: pirates about when the Ark is lost: they must leave (not go on
--   attacking where it was): none left within 6 s.
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local mode = os.getenv("MODE") or "saucer"
local f, t0, bad, departed, overf, gonef, prevft = 0, nil, 0, nil, nil, nil, 0
emu.register_frame_done(function()
  manager:machine().devices[":maincpu"].spaces["program"]:write_u8(0x259F, 1)   -- (test: fire on the title, straight into deep space)
  f = f + 1
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  local held = {}
  if f >= 300 and f <= 305 then held["P1 Button 1"] = true end
  local ss, ft = m:read_u8(0x238C), m:read_u8(0x2400)
  if mode == "saucer" and f > 420 then
    m:write_u8(0x2386, 96); m:write_u8(0x240C, 96)
    if not t0 then
      if ft == 0 and f % 20 < 6 then held["P1 Button 2"] = true end     -- launch
      if ft == 1 then t0 = f end
    else
      held[(f // 60) % 2 == 0 and "P1 Up" or "P1 Left"] = true          -- fly about
      for i = 0, 9 do m:write_u8(0x2300 + i, 0) end                     -- the wave cleared
      m:write_u8(0x238E, 0); m:write_u8(0x24C1, 0); m:write_u8(0x24C2, 0)
      if ss == 6 and not departed then
        departed = f
        if ft ~= 0 or prevft == 1 then bad = 1 end   -- (flown home, not snapped in from out)
      end
    end
  end
  if mode == "over" and f > 420 then
    if not overf then
      m:write_u8(0x240C, 0)                                              -- (no saucer)
      if f == 430 then m:write_u8(0x24C1, 3); m:write_u8(0x24C3, 1) end -- raiders, now
      local live = 0
      for i = 0, 5 do local t = m:read_u8(0x2460 + i); if t == 1 or t == 2 then live = live + 1 end end
      if live >= 2 then m:write_u8(0x2386, 1) end                       -- one more hit and it's over
      if ss == 2 then overf = f end
    else
      local live = 0
      for i = 0, 5 do local t = m:read_u8(0x2460 + i); if t >= 1 and t <= 3 then live = live + 1 end end
      if live == 0 and not gonef then gonef = f end
    end
  end
  prevft = ft
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
  if mode == "saucer" and (departed and f > departed + 10 or f > 3000) then
    print(string.format("saucer out at the wave's end: the Ark %s", not departed and "NEVER LEFT" or (bad == 1 and "LEFT WITHOUT IT" or string.format("waited, left %.1f s after the clear", (departed - t0) / 60))))
    local mm = manager:machine().devices[":maincpu"].spaces["program"]
    local c1, c2, c3 = mm:read_u8(0x23F0), mm:read_u8(0x2576), mm:read_u8(0x2577)
    local starsok = (c1 == 126 and c2 == 144 and c3 == 146)
    print(string.format("the stars' glyph cells after flying the saucer: %d %d %d (%s)", c1, c2, c3, starsok and "intact" or "OVERWRITTEN"))
    if not starsok then bad = 1 end
    print(string.format("result %d %d", departed and 1 or 0, bad))
    manager:machine():exit()
  end
  if mode == "over" and (gonef or (overf and f > overf + 600) or f > 6000) then
    print(string.format("the Ark lost with pirates about: %s", not overf and "NEVER LOST" or (gonef and string.format("they left in %.1f s", (gonef - overf) / 60) or "STILL THERE after 10 s")))
    print(string.format("result %d %d", overf and 1 or 0, (gonef and (gonef - overf) <= 360) and 1 or 0))
    manager:machine():exit()
  end
end)
