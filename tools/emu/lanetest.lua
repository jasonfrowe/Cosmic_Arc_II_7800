-- Lane test: an autopilot shoots rocks (so they split) while this measures
-- how far each rock's centre strays from its lane (pixels across the lane,
-- in 160A pixels), per lane and size. Energy is held full. tools/test_lanes.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local CX = {4, 4, 2}; local CY = {8, 6, 4}   -- a rock's centre from its corner
local D = {[0]={"P1 Up"},{"P1 Up","P1 Right"},{"P1 Right"},{"P1 Down","P1 Right"},
  {"P1 Down"},{"P1 Down","P1 Left"},{"P1 Left"},{"P1 Up","P1 Left"}}
local f, stats, worst = 0, {}, 0
emu.register_frame_done(function()
  f = f + 1
  manager:machine().devices[":maincpu"].spaces["program"]:write_u8(0x23EF, 1)   -- no planets
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  local hold = {}
  if f >= 300 and f <= 305 then hold["P1 Button 1"] = true end
  if f > 400 then
    m:write_u8(0x2386, 96)
    local best, bd
    for i = 0, 9 do
      local t = m:read_u8(0x2300 + i)
      if t == 1 or t == 2 then
        local dx = (m:read_u8(0x230A + i) + CX[t] - 80) * 2
        local dy = m:read_u8(0x231E + i) + CY[t] - 95
        local d = dx * dx + dy * dy
        if not bd or d < bd then bd, best = d, {dx, dy} end
      end
    end
    if best then
      local a = math.floor((math.atan(best[1], -best[2]) / (2 * math.pi) * 8 + 8.5)) % 8
      for _, n in ipairs(D[a]) do hold[n] = true end
      hold["P1 Button 1"] = (f % 2 == 0)
    end
  end
  for name, field in pairs(fields) do
    if name:match("^P1 ") then field:set_value(hold[name] and 1 or 0) end
  end
  for i = 0, 9 do
    local t = m:read_u8(0x2300 + i)
    if f > 400 and t >= 1 and t <= 3 then     -- (in a game: RAM is noise before)
      local lane = m:read_u8(0x23E4 + i)
      local dx = m:read_u8(0x230A + i) + CX[t] - 80     -- pixels
      local dy = m:read_u8(0x231E + i) + CY[t] - 95     -- lines
      local off
      if lane == 0 or lane == 4 then off = dx
      elseif lane == 2 or lane == 6 then off = dy / 2   -- (lines -> pixels)
      elseif lane == 1 or lane == 5 then off = (dx + dy / 2) / 2
      else off = (dx - dy / 2) / 2 end
      local k = lane .. ":" .. t
      local s = stats[k] or {n = 0, min = 99, max = -99}
      s.n = s.n + 1; s.min = math.min(s.min, off); s.max = math.max(s.max, off)
      stats[k] = s
      worst = math.max(worst, math.abs(off))
    end
  end
  if f > 30000 then
    local keys = {}
    for k in pairs(stats) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local s = stats[k]
      print(string.format("lane %s size %s: %5d samples, off the lane %.1f .. %.1f px",
        k:sub(1, 1), k:sub(3), s.n, s.min, s.max))
    end
    print(string.format("worst %.1f", worst))
    manager:machine():exit()
  end
end)
