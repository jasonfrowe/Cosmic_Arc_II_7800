-- Defence test: the shuttle hovers at a line (HOVER); count pulses, shuttles
-- lost, and the planet loop's rate. tools/test_defense.sh
-- the defence: the shuttle sits at a height; how often pulses kill it; the
-- loop's rate while pulses fire
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local f, pulses, deaths, ran, n, lastt, prevp, prevst = 0, 0, 0, 0, 0, nil, 0, 1
local Y = tonumber(os.getenv("HOVER") or "120")
emu.register_frame_done(function()
  f = f + 1
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  local held = {}
  if f >= 290 and f <= 296 then held["Select"] = true end
  if f > 340 and m:read_u8(0x2714) == 0 then
    m:write_u8(0x2386, 96); m:write_u8(0x2712, 50)
    local st, y = m:read_u8(0x2709), m:read_u8(0x2707)
    if st == 0 then held["P1 Down"] = true
    elseif m:read_u8(0x2777) == 0 then
      if f < 420 then held["P1 Right"] = true end
      if y < Y then held["P1 Down"] = true elseif y > Y then held["P1 Up"] = true end
    end
    local p = m:read_u8(0x27BD)
    if p > 0 and prevp == 0 then pulses = pulses + 1 end
    prevp = p
    if prevst == 1 and st == 2 then deaths = deaths + 1 end
    prevst = st
    local t = m:read_u8(0x271B); n = n + 1; if t ~= lastt then ran = ran + 1 end; lastt = t
  end
  for name, field in pairs(fields) do if name:match("^P1 ") or name == "Select" then field:set_value(held[name] and 1 or 0) end end
  if f == 2700 then
    print(string.format("hovering at line %d: %d pulses, %d shuttles lost; loop ran %d of %d frames", Y, pulses, deaths, ran, n))
    manager:machine():exit()
  end
end)
