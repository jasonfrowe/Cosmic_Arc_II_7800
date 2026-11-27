-- Screenshots for the manual (tools/make_manual.py --shots): the map's and
-- the port's screens, from a voyage given a mid-game state. Two runs with a
-- SaveKey (PHASE): A the title, a new voyage, docked (saved), the port's
-- tabs, then moved to a planet three jumps out: the sector view, the star
-- chart, the close-up, the achievements; B the voyage screen with it saved.
-- Snapshots are named (title.png, port_trade.png ...) in -snapshot_directory.
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end
local steps, si, t0, f = {}, 1, 0, 0
local function step(wait, press, fn) table.insert(steps, {wait, press, fn}) end
local function shot(name) manager:machine().screens[":screen"]:snapshot(name .. ".png") end
local phase = os.getenv("PHASE") or "A"
local DCOL = {[0] = 0, 1, 1, 1, 0, -1, -1, -1}
local DROW = {[0] = -1, -1, 0, 1, 1, 1, 0, -1}
local DIRF = {[0] = {"P1 Up"}, {"P1 Up", "P1 Right"}, {"P1 Right"}, {"P1 Down", "P1 Right"},
  {"P1 Down"}, {"P1 Down", "P1 Left"}, {"P1 Left"}, {"P1 Up", "P1 Left"}}
local pressdir

-- the galaxy's warps: sector -> {direction -> sector}
local function links(m)
  local sec = {}
  for k = 0, 63 do sec[m:read_u8(0x2640 + k)] = k end
  local out = {}
  for k = 0, 63 do
    out[k] = {}
    local c, w = m:read_u8(0x2640 + k), m:read_u8(0x2600 + k)
    for d = 0, 7 do if w & (1 << d) ~= 0 then
      local n = sec[((c >> 4) + DROW[d]) * 16 + (c & 15) + DCOL[d]]
      if n then out[k][d] = n end
    end end
  end
  return out
end

local planet, chartdir
local function setup()
  local m = mem()
  for a, v in pairs({[0x2594] = 0x01, [0x2595] = 0x24, [0x2596] = 0x50,      -- credits 12450
      [0x25A6] = 0x00, [0x25A7] = 0x30, [0x25A8] = 0x00,                     -- bank 3000
      [0x2592] = 42, [0x2593] = 0,                                           -- stardate 42
      [0x2588] = 2, [0x258F] = 110, [0x2386] = 96,                           -- hull 110, energy 96
      [0x2589] = 1, [0x2585] = 3, [0x2586] = 2,                              -- 15 holds; ore, organics
      [0x256B] = 2, [0x256C] = 1, [0x256D] = 1,                              -- in stasis
      [0x25A0] = 2, [0x25A1] = 1, [0x25A3] = 1,                              -- kept
      [0x25F5] = 0x90, [0x25F6] = 0x03, [0x25FE] = 0x90, [0x25FF] = 0x03,    -- TYCOON, UNTOUCHED, SWEEP, STORMS
      [0x25F7] = 23}) do m:write_u8(a, v) end
  -- explored: everything within four jumps of home visited, their neighbours seen
  local out = links(m)
  local dist, q, i = {[0] = 0}, {0}, 1
  while q[i] do
    local k = q[i]
    if dist[k] < 4 then for d, n in pairs(out[k]) do if not dist[n] then dist[n] = dist[k] + 1; table.insert(q, n) end end end
    i = i + 1
  end
  for k, dd in pairs(dist) do
    m:write_u8(0x26C0 + k, m:read_u8(0x26C0 + k) | 3)
    for d, n in pairs(out[k]) do m:write_u8(0x26C0 + n, m:read_u8(0x26C0 + n) | 2) end
  end
  -- a planet three jumps out, and a way to point the chart's cursor
  for k, dd in pairs(dist) do
    if dd == 3 and m:read_u8(0x2680 + k) & 3 == 2 and not planet then
      for d, n in pairs(out[k]) do planet, chartdir = k, d; break end
    end
  end
  planet = planet or 1
end

step(340, nil, nil)
step(20, nil, function() if phase == "A" then shot("title") end end)
step(60, "P1 Button 1", nil)                                     -- the voyage screen
if phase == "B" then
  step(30, nil, function() shot("voyages") end)
else
  step(30, "P1 Button 1", nil)                                   -- a new voyage, slot 1
  step(30, nil, function() setup(); mem():write_u8(0x27F7, 1) end)
  step(30, "P1 Button 1", nil)                                   -- dock (home): saved
  step(40, nil, function() shot("port_trade") end)
  step(30, "P1 Button 2", nil)
  step(20, nil, function() shot("port_bounty") end)
  step(30, "P1 Button 2", nil)
  step(20, nil, function() shot("port_yard") end)
  step(30, "P1 Button 2", nil)
  step(20, nil, function() shot("port_bank") end)
  step(10, nil, function() local m = mem()                       -- out, and on to the planet
    m:write_u8(0x22FC, 0); m:write_u8(0x22FB, 0); m:write_u8(0x27FC, 0)
    m:write_u8(0x2590, planet); m:write_u8(0x259C, planet); m:write_u8(0x27F7, 1) end)
  step(30, nil, function() shot("sector") end)
  step(30, "P1 Button 2", nil)                                   -- the star chart
  step(10, nil, function() pressdir = chartdir end)
  step(30, nil, function() pressdir = nil end)
  step(30, nil, function() shot("chart") end)
  step(30, "P1 Button 2", nil)                                   -- the close-up
  step(20, nil, function() shot("closeup") end)
  step(30, "P1 Button 2", nil)                                   -- the achievements
  step(20, "P1 Down", nil)
  step(20, nil, function() shot("achieve") end)
end
emu.register_frame_done(function()
  f = f + 1
  local held = {}
  local st = steps[si]
  if st then
    if f - t0 == 1 and st[3] then st[3]() end
    if st[2] and f - t0 >= 2 and f - t0 <= 6 then held[st[2]] = true end
    if pressdir and f - t0 >= 2 and f - t0 <= 6 then for _, n in ipairs(DIRF[pressdir]) do held[n] = true end end
    if f - t0 >= st[1] then si = si + 1; t0 = f end
  else
    print("manualshots " .. phase .. ": done")
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
