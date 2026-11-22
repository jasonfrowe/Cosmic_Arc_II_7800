-- Planet test: Select on the title (a planet at once), then the planet
-- autopilot (snap.lua's AUTOPLANET, copied here): catches creatures, docks.
-- Checks: creatures caught, the planet ends and play goes back to deep
-- space, and the planet loop ran every frame. tools/test_planet.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local f, ran, frames, lastt, caught, back = 0, 0, 0, nil, 0, false
emu.register_frame_done(function()
  f = f + 1
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  local held = {}
  if f >= 290 and f <= 296 then held["Select"] = true end
  local onplanet = f > 340 and m:read_u8(0x2714) < 3
  if onplanet then
    m:write_u8(0x2386, 96)
    local wx = m:read_u8(0x2700) + 256 * m:read_u8(0x2701)
    local sy, hold, st = m:read_u8(0x2707), m:read_u8(0x270A), m:read_u8(0x2709)
    if hold > 0 then held["P1 Up"] = true
    else
      local best, bd, by
      for i = 0, 3 do
        local t, cs = m:read_u8(0x2720 + i), m:read_u8(0x2740 + i)
        if t > 0 and cs ~= 4 and cs ~= 3 then
          local cx = m:read_u8(0x2724 + i) + 256 * m:read_u8(0x2728 + i) + 4
          local dx = (cx - wx + 512) % 1024 - 512
          if not bd or math.abs(dx) < math.abs(bd) then bd, best, by = dx, i, m:read_u8(0x2730 + i) end
        end
      end
      if best then
        if bd > 2 then held["P1 Right"] = true elseif bd < -2 then held["P1 Left"] = true end
        if math.abs(bd) < 24 and sy < by - 14 then held["P1 Down"] = true end
        if math.abs(bd) < 6 then held["P1 Button 1"] = true end
        if st == 0 then held["P1 Down"] = true end
      end
    end
    local t = m:read_u8(0x271B)
    frames = frames + 1
    if t ~= lastt then ran = ran + 1 end
    lastt = t
    caught = m:read_u8(0x2716)
  end
  if f > 400 and m:read_u8(0x2714) == 3 and m:read_u8(0x238C) ~= 4 then back = true end
  for name, field in pairs(fields) do
    if name:match("^P1 ") or name == "Select" then field:set_value(held[name] and 1 or 0) end
  end
  if f == 4400 or back then
    print(string.format("caught %d of %d; planet loop ran %d of %d frames; back to deep space: %s",
      caught, m:read_u8(0x2717), ran, frames, tostring(back)))
    print(string.format("result %d %d %d %d", caught, ran, frames, back and 1 or 0))
    manager:machine():exit()
  end
end)
