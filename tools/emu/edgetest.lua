-- Edge test: pirates must stay on the screen. Many pirates (waves of them,
-- energy held full, the laser autopilot); every frame, check each pirate's
-- centre is inside the playfield and never jumps (wraps) 20+ pixels.
-- tools/test_edges.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local f, out, jumps, samples = 0, 0, 0, 0
local px, py = {}, {}
emu.register_frame_done(function()
  f = f + 1
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  local hold = {}
  if f >= 300 and f <= 305 then hold["P1 Button 1"] = true end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(hold[name] and 1 or 0) end end
  if f > 330 then
    m:write_u8(0x2386, 96)
    if m:read_u8(0x24C1) == 0 and f % 300 == 0 then m:write_u8(0x24C1, 2); m:write_u8(0x24C2, 1); m:write_u8(0x24C3, 2) end
    for i = 0, 5 do
      local t = m:read_u8(0x2460 + i)
      if t >= 1 and t <= 3 then
        local x, y = m:read_u8(0x2466 + i), m:read_u8(0x2472 + i)
        samples = samples + 1
        if x < 4 or x > 155 or y < 20 or y > 170 then out = out + 1 end
        if px[i] and (math.abs(x - px[i]) > 20 or math.abs(y - py[i]) > 20) then jumps = jumps + 1 end
        px[i], py[i] = x, y
      else
        px[i] = nil
      end
    end
  end
  if f == 15000 then
    print(string.format("pirate samples %d: off the screen %d, jumps (wraps) %d", samples, out, jumps))
    print(string.format("edges %d %d", out, jumps))
    manager:machine():exit()
  end
end)
