-- Zone test: play late waves (the autopilot, energy held full, the wave set
-- high) and record how full each zone's display list gets (7800basic's
-- dlend, zero page from $65: the next free byte in each zone's list).
-- Prints the most each zone held and the space it has. tools/test_zones.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local NZ = tonumber(os.getenv("ZONES") or "12")
local CAP = tonumber(os.getenv("ZONECAP") or "160")
local CX = {4, 4, 2}; local CY = {8, 6, 4}
local D = {[0]={"P1 Up"},{"P1 Up","P1 Right"},{"P1 Right"},{"P1 Down","P1 Right"},
  {"P1 Down"},{"P1 Down","P1 Left"},{"P1 Left"},{"P1 Up","P1 Left"}}
local f, most, waves = 0, {}, 0
local lastticks, stalled, stall = nil, 0, 0   -- the game loop must keep running
emu.register_frame_done(function()
  f = f + 1
  manager:machine().devices[":maincpu"].spaces["program"]:write_u8(0x23EF, 1)   -- no planets
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  local hold = {}
  if f >= 300 and f <= 305 then hold["P1 Button 1"] = true end
  if f == 320 then m:write_u8(0x238A, 11) end           -- wave 1 -> 12 next
  if f > 400 then
    m:write_u8(0x2386, 96)
    local best, bd
    for i = 0, 9 do local t = m:read_u8(0x2300 + i)
      if t >= 1 and t <= 3 then
        local dx = (m:read_u8(0x230A + i) + CX[t] - 80) * 2; local dy = m:read_u8(0x231E + i) + CY[t] - 95
        local d = dx*dx + dy*dy; if not bd or d < bd then bd, best = d, {dx, dy} end end end
    -- shoot only now and then: let rocks pile up
    if best and f % 40 < 8 then
      local a = math.floor((math.atan(best[1], -best[2]) / (2*math.pi) * 8 + 8.5)) % 8
      for _, n in ipairs(D[a]) do hold[n] = true end
      hold["P1 Button 1"] = true
    end
    local t = m:read_u8(0x239F)
    if t == lastticks then stalled = stalled + 1 else stalled = 0 end
    lastticks = t
    if stalled > stall then stall = stalled end
    for z = 0, NZ - 1 do
      local v = m:read_u8(0x65 + z)
      if v > (most[z] or 0) then most[z] = v end
    end
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(hold[name] and 1 or 0) end end
  if f == 9000 then
    local worst, wz = 0, 0
    local line = ""
    for z = 0, NZ - 1 do
      line = line .. string.format("%d:%d ", z, most[z] or 0)
      if (most[z] or 0) > worst then worst, wz = most[z], z end
    end
    print("zone fill (bytes): " .. line)
    print(string.format("wave %d; fullest zone %d: %d of %d bytes", m:read_u8(0x238A), wz, worst, CAP))
    print(string.format("longest stall %d frames", stall))
    print(string.format("worst %d cap %d stall %d", worst, CAP, stall))
    manager:machine():exit()
  end
end)
