-- Journey test: the map's loop. New Game; every sector an outer-rim nebula,
-- warps till one's an encounter (deep space, the autopilot clears it) and the Ark arrives
-- on the map at its destination (320A again); a planet here: land, the
-- planet ends, back on the map. tools/test_journey.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local f, phase, t0 = 0, "start", 0
local r = {}
local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end
local DIRF = {[0] = {"P1 Up"}, {"P1 Up", "P1 Right"}, {"P1 Right"}, {"P1 Down", "P1 Right"},
  {"P1 Down"}, {"P1 Down", "P1 Left"}, {"P1 Left"}, {"P1 Up", "P1 Left"}}
emu.register_frame_done(function()
  f = f + 1
  local m = mem()
  local held = {}
  local ctrl, go, ss = m:read_u8(0x2107), m:read_u8(0x259B), m:read_u8(0x238C)
  if phase == "start" then
    if f >= 300 and f <= 305 then held["P1 Button 1"] = true end
    if f == 400 then
      r.map = (ctrl == 0x43); r.from = m:read_u8(0x2590)
      for x = 0, 63 do m:write_u8(0x2680 + x, 0xC3) end       -- every sector an outer-rim nebula (85%)
      m:write_u8(0x27F7, 1)
      phase = "warp"; t0 = f
    end
  elseif phase == "warp" then
    if f - t0 == 10 then held["P1 Right"] = true end          -- a warp (item 1)
    if f - t0 >= 30 and f - t0 <= 35 then held["P1 Button 1"] = true end
    if go == 1 or ss ~= 0 and m:read_u8(0x23EE) == 2 and ctrl == 0x50 then
      r.enc = true; r.dest = m:read_u8(0x259C); phase = "space"; t0 = f
    end
    if f - t0 > 150 then                                      -- no encounter: warp again
      r.tries = (r.tries or 0) + 1; t0 = f; m:write_u8(0x27F7, 1)
      if r.tries > 8 then phase = "done" end
    end
  elseif phase == "space" then
    m:write_u8(0x2386, 96)
    -- the laser autopilot: the nearest rock or pirate
    local best, bd
    for i = 0, 9 do local t = m:read_u8(0x2300 + i)
      if t >= 1 and t <= 3 then local dx, dy = (m:read_u8(0x230A + i) + 4 - 80) * 2, m:read_u8(0x231E + i) + 6 - 95
        if not bd or dx * dx + dy * dy < bd then bd, best = dx * dx + dy * dy, {dx, dy} end end end
    for i = 0, 5 do local t = m:read_u8(0x2460 + i)
      if t >= 1 and t <= 3 then local dx, dy = (m:read_u8(0x2466 + i) - 80) * 2, m:read_u8(0x2472 + i) - 95
        if not bd or dx * dx + dy * dy < bd then bd, best = dx * dx + dy * dy, {dx, dy} end end end
    if best then
      local d = math.floor((math.atan(best[1], -best[2]) / (2 * math.pi) * 8 + 8.5)) % 8
      for _, n in ipairs(DIRF[d]) do held[n] = true end
      held["P1 Button 1"] = (f % 2) == 0
    end
    if ctrl == 0x43 and m:read_u8(0x23EE) == 4 and f - t0 > 60 then
      r.back = true; r.arrived = (m:read_u8(0x2590) == r.dest); r.spacetime = (f - t0) / 60
      -- make this sector a planet (VERDA), and land
      local s = m:read_u8(0x2590)
      m:write_u8(0x2680 + s, 2)                               -- a planet, safe (no encounter leaving)
      m:write_u8(0x27F7, 1); m:write_u8(0x22FB, 0)
      phase = "land"; t0 = f
    end
    if f - t0 > 9000 then phase = "done" end
  elseif phase == "land" then
    if f - t0 >= 20 and f - t0 <= 25 then held["P1 Button 1"] = true end
    if m:read_u8(0x23EE) == 3 and ctrl == 0x50 and f - t0 > 30 then
      r.landed = true; phase = "planet"; t0 = f
    end
    if f - t0 > 300 then phase = "done" end
  elseif phase == "planet" then
    if f - t0 == 120 then m:write_u8(0x2714, 3) end           -- the planet's done
    if ctrl == 0x43 and m:read_u8(0x23EE) == 4 then r.home = true; phase = "done" end
    if f - t0 > 1200 then phase = "done" end
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
  if phase == "done" then
    print(string.format("map after New Game: %s; a warp: %s; back on the map: %s (%s, after %.0f s); landed: %s; back from the planet: %s",
      r.map and "yes" or "NO", r.enc and "an encounter" or "NO ENCOUNTER", r.back and "yes" or "NO",
      r.arrived and "at its destination" or "NOT AT ITS DESTINATION", r.spacetime or -1,
      r.landed and "yes" or "NO", r.home and "yes" or "NO"))
    print("result " .. ((r.map and r.enc and r.back and r.arrived and r.landed and r.home) and 1 or 0))
    manager:machine():exit()
  end
end)
