-- Departure test: docking at a port (an outer-rim sector, 5 jumps from safe
-- space) over and over; leaving, an encounter some of the time (60%), each
-- a wave for 5 jumps (5 or 6). Encounters are cleared at once (the rocks and
-- pirates taken away). tools/test_depart.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local f, phase, t0, docks, encs, waves, badwave = 0, "start", 0, 0, 0, {}, false
emu.register_frame_done(function()
  f = f + 1
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  local held = {}
  local ctrl, bank = m:read_u8(0x2107), m:read_u8(0x23EE)
  if f >= 300 and f <= 305 then held["P1 Button 1"] = true end
  if phase == "start" and f == 400 then phase = "map"; t0 = f end
  if phase == "map" then
    local s = m:read_u8(0x2590)
    m:write_u8(0x2680 + s, 0xC0 | 1); m:write_u8(0x26C0 + s, (5 << 2) | 1)
    if f - t0 == 5 then m:write_u8(0x22FB, 0); m:write_u8(0x27F7, 1) end
    if f - t0 >= 20 and f - t0 <= 24 then held["P1 Button 1"] = true end
    if f - t0 == 40 then
      docks = docks + 1
      if bank == 2 then encs = encs + 1; phase = "space"; t0 = f
      else t0 = f end
      if docks >= 12 and phase == "map" then phase = "done" end
    end
  elseif phase == "space" then
    if f - t0 == 30 then
      local w = m:read_u8(0x238A); table.insert(waves, w)
      if w < 5 or w > 6 then badwave = true end
    end
    if f - t0 > 30 then                                       -- clear it
      m:write_u8(0x2386, 96)
      for i = 0, 9 do m:write_u8(0x2300 + i, 0) end
      for i = 0, 5 do m:write_u8(0x2460 + i, 0) end
      m:write_u8(0x238E, 0); m:write_u8(0x24C1, 0); m:write_u8(0x24C2, 0)
    end
    if ctrl == 0x43 and bank == 4 and f - t0 > 60 then
      phase = docks >= 12 and "done" or "map"; t0 = f
    end
    if f - t0 > 3000 then phase = "done" end
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
  if phase == "done" then
    print(string.format("%d departures from an outer-rim port 5 jumps out: %d encounters, waves %s",
      docks, encs, table.concat(waves, " ")))
    print("result " .. ((encs >= 3 and encs <= 11 and not badwave and docks >= 12) and 1 or 0))
    manager:machine():exit()
  end
end)
