-- Recall test (deep space): launch the saucer into a busy wave, call it
-- home (button 2), again and again; count how often it dies on the way home
-- (it mustn't: going home is safe). tools/test_recall.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local f, trips, deaths, prev, dirs = 0, 0, 0, 0, {"P1 Up", "P1 Left", "P1 Right", "P1 Down"}
emu.register_frame_done(function()
  f = f + 1
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  m:write_u8(0x23EF, 1)
  local held = {}
  if f >= 300 and f <= 305 then held["P1 Button 1"] = true end
  if f == 330 then m:write_u8(0x238A, 9) end                 -- late waves: many rocks
  if f > 400 then
    m:write_u8(0x2386, 96); m:write_u8(0x240C, 96)
    local st = m:read_u8(0x2400)
    local k = f % 240
    if st == 0 and k < 6 then held["P1 Button 2"] = true end            -- launch
    if st == 1 then held[dirs[(f // 240) % 4 + 1]] = true end           -- fly off somewhere
    if st == 1 and k >= 120 and k < 126 then held["P1 Button 2"] = true end  -- call it home
    if prev == 1 and st == 2 then
      trips = trips + 1
      -- a large rock, still, right in the way home (halfway to the bay)
      local fx, fy = m:read_u8(0x2401), m:read_u8(0x2403)
      local rx, ry = (fx + 80) // 2 - 4, (fy + 104) // 2 - 8
      m:write_u8(0x2300, 1); m:write_u8(0x230A, rx); m:write_u8(0x231E, ry)
      m:write_u8(0x2332, 0); m:write_u8(0x233C, 0); m:write_u8(0x2346, 0); m:write_u8(0x2350, 0)
      m:write_u8(0x23F2, 2); m:write_u8(0x23E4, 0)
    end
    if prev == 2 and st == 3 then deaths = deaths + 1 end
    prev = st
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
  if f == 12400 then
    print(string.format("trips home %d, deaths on the way %d", trips, deaths))
    print(string.format("result %d %d", trips, deaths))
    manager:machine():exit()
  end
end)
