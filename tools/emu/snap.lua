-- Take screenshots at the frames listed in SNAP_FRAMES (comma separated),
-- then exit after the last one. Used by tools/snap.sh.
--
-- POKES (optional): "frame:addr:value,..." (hex addr/value) writes memory
--   at those frames, e.g. "300:2502:0C" to solo POKEY 2 in the music mask.
-- INPUTS (optional): "from-to:Field Name;..." holds a control down over a
--   frame range, e.g. "300-305:P1 Button 1;400-900:P1 Right".
-- AUTOPLAY (optional, a frame): from then on, aim at the nearest rock and
--   fire (deep space, space.asm's tables). Prints the wave, score and
--   energy every 600 frames.
local frames = {}
local last = 0
for n in string.gmatch(os.getenv("SNAP_FRAMES") or "120", "%d+") do
  frames[tonumber(n)] = true
  if tonumber(n) > last then last = tonumber(n) end
end
local pokes = {}
for fr, a, v in string.gmatch(os.getenv("POKES") or "", "(%d+):(%x+):(%x+)") do
  table.insert(pokes, {tonumber(fr), tonumber(a, 16), tonumber(v, 16)})
end
local inputs = {}
for a, b, name in string.gmatch(os.getenv("INPUTS") or "", "(%d+)-(%d+):([^;]+)") do
  table.insert(inputs, {tonumber(a), tonumber(b), name})
end
local autoplay = tonumber(os.getenv("AUTOPLAY") or "")

local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end

local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end

-- the nearest rock's direction (0 up, clockwise) from the Ark's centre
local DIRS = {}
local function aim()
  local m = mem()
  local best, bd = nil, 1e9
  for i = 0, 9 do
    local t = m:read_u8(0x2300 + i)
    if t >= 1 and t <= 3 then
      local dx = (m:read_u8(0x230A + i) + 4 - 80) * 2
      local dy = m:read_u8(0x231E + i) + 6 - 95
      local d = dx * dx + dy * dy
      if d < bd then bd, best = d, {dx, dy} end
    end
  end
  if not best then return nil end
  local a = math.atan(best[1], -best[2])       -- 0 = up, clockwise
  return math.floor((a / (2 * math.pi) * 8 + 8.5)) % 8
end
local DIRF = {
  [0] = {"P1 Up"}, {"P1 Up", "P1 Right"}, {"P1 Right"}, {"P1 Down", "P1 Right"},
  {"P1 Down"}, {"P1 Down", "P1 Left"}, {"P1 Left"}, {"P1 Up", "P1 Left"},
}

local f = 0
emu.register_frame_done(function()
  f = f + 1
  for _, p in ipairs(pokes) do
    if p[1] == f then mem():write_u8(p[2], p[3]) end
  end
  local held = {}
  for _, i in ipairs(inputs) do
    if f >= i[1] and f <= i[2] then held[i[3]] = true end
  end
  if autoplay and f >= autoplay then
    local d = aim()
    if d then
      for _, n in ipairs(DIRF[d]) do held[n] = true end
      held["P1 Button 1"] = (f % 2) == 0
    end
    -- the game loop's pace: frames in which it ran (60 a second = full speed)
    local t = mem():read_u8(0x239F)
    if t ~= lastticks then ran = (ran or 0) + 1 end
    lastticks = t
    local live = 0
    for i = 0, 9 do if mem():read_u8(0x2300 + i) > 0 then live = live + 1 end end
    maxlive = math.max(maxlive or 0, live)
    if f % 600 == 0 then
      local m = mem()
      print(string.format("frame %d: wave %d score %02X%02X%02X energy %d state %d; loop ran %d/600 frames, most rocks %d",
        f, m:read_u8(0x238A), m:read_u8(0x2387), m:read_u8(0x2388), m:read_u8(0x2389),
        m:read_u8(0x2386), m:read_u8(0x238C), ran or 0, maxlive))
      ran, maxlive = 0, 0
    end
  end
  for name, field in pairs(fields) do
    if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end
  end
  if frames[f] then manager:machine().screens[":screen"]:snapshot() end
  if f > last then manager:machine():exit() end
end)
