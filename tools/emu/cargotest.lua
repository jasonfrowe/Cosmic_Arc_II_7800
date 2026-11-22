-- Cargo test (the planet): a crate under the shuttle, beamed up (button 1);
-- top speed across with the ore aboard vs without; button 2 drops it (it
-- falls and lands). tools/test_cargo.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local f, phase, t0 = 0, "out", 0
local r = {}
emu.register_frame_done(function()
  f = f + 1
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  local held = {}
  if f >= 290 and f <= 296 then held["Select"] = true end
  local st, auto, y, hold = m:read_u8(0x2709), m:read_u8(0x2777), m:read_u8(0x2707), m:read_u8(0x270A)
  local vx = m:read_u8(0x2704) * 256 + m:read_u8(0x2703); if vx >= 32768 then vx = vx - 65536 end
  if f > 340 then m:write_u8(0x27BC, 200); m:write_u8(0x2712, 40); m:write_u8(0x2386, 96) end
  if f > 345 then
    if phase == "out" then
      held["P1 Down"] = true
      if st == 1 and auto == 0 and y >= 148 then
        local wx = m:read_u8(0x2700) + 256 * m:read_u8(0x2701) - 4
        m:write_u8(0x2760, 1); m:write_u8(0x2762, wx % 256); m:write_u8(0x2764, wx // 256); m:write_u8(0x2766, 150)
        phase = "beam"; t0 = f
      end
    elseif phase == "beam" then
      held["P1 Button 1"] = true
      if hold == 2 then r.got = (f - t0) / 60; phase = "ore"; t0 = f; r.vore = 0 end
      if f - t0 > 600 then phase = "done" end
    elseif phase == "ore" then
      held["P1 Right"] = true
      r.vore = math.max(r.vore, math.abs(vx))
      if f - t0 > 120 then phase = "drop"; t0 = f end
    elseif phase == "drop" then                             -- up 20 lines, then drop
      if y > 128 then held["P1 Up"] = true; t0 = f
      else
        if f - t0 >= 2 and f - t0 <= 5 then held["P1 Button 2"] = true end
        if f - t0 > 5 and m:read_u8(0x2760) == 2 then r.falling = true end
        if f - t0 == 10 then r.dropped = (hold == 0) end
        if f - t0 > 10 and m:read_u8(0x2760) == 1 then r.landed = true end
        if f - t0 > 240 then phase = "empty"; t0 = f; r.vempty = 0 end
      end
    elseif phase == "empty" then
      held["P1 Right"] = true
      r.vempty = math.max(r.vempty, math.abs(vx))
      if f - t0 > 120 then phase = "done" end
    end
  end
  for name, field in pairs(fields) do if name:match("^P1 ") or name == "Select" then field:set_value(held[name] and 1 or 0) end end
  if phase == "done" or f > 3000 then
    print(string.format("ore beamed up: %s; top speed across with ore %.2f, empty %.2f px a frame; button 2: %s, it %s and %s",
      r.got and string.format("%.1f s", r.got) or "NEVER", (r.vore or 0) / 256, (r.vempty or 0) / 256,
      r.dropped and "dropped" or "NOT DROPPED", r.falling and "fell" or "DIDN'T FALL", r.landed and "landed" or "DIDN'T LAND"))
    local ok = r.got and r.dropped and r.falling and r.landed and r.vore > 0 and r.vore * 2 <= r.vempty + 8
    print("result " .. (ok and 1 or 0))
    manager:machine():exit()
  end
end)
