-- Feel test (the planet): what a player notices.
--  1. (Bullets: gone with the shuttle's blasters; the defences' pulse is
--     dodged instead.)
--  2. Docking: a few pixels off the Ark's middle (in its doorway, twice the
--     shuttle's width), stopped, just push up: it must dock within 2 s.
--  3. Undocking: hold down: within 2 s it's out of the tunnel and can move.
--  4. No accident: just out, fly up and away (up + left) for a second: it
--     must not dock again.
--  5. Docking with up held: the Ark mustn't fire until the stick's let go.
--  6. Docking on the move: from 70 px off and down in the band, fly at the
--     Ark and, from 40 px off, hold up and towards it (a diagonal): it must
--     dock within 3 s, from the right (up-left) and from the left (up-right).
-- Turrets are held out. tools/test_feel.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local f, phase, t0, side = 0, "launch", 0, 1
local shots, ahead = {}, 0
local results = {}
local function m() return manager:machine().devices[":maincpu"].spaces["program"] end
emu.register_frame_done(function()
  f = f + 1
  local mm = m()
  local held = {}
  if f >= 290 and f <= 296 then held["Select"] = true end
  if f > 340 then
    mm:write_u8(0x27BC, 200)                               -- no pulses
    mm:write_u8(0x2386, 96); mm:write_u8(0x2712, 50)       -- energy and time held
  end
  local st, y, auto = mm:read_u8(0x2709), mm:read_u8(0x2707), mm:read_u8(0x2777)
  local wx = mm:read_u8(0x2700) + 256 * mm:read_u8(0x2701)
  local dx = (wx - 512 + 512) % 1024 - 512
  if f > 340 and mm:read_u8(0x2714) == 0 then
    if phase == "launch" then
      held["P1 Down"] = true
      if st == 1 and auto == 0 then phase = "fly"; t0 = f end
    elseif phase == "fly" then
      -- out to the right, at full speed, low; then fire right
      held["P1 Right"] = true
      if y < 120 then held["P1 Down"] = true end
      if f - t0 > 60 then held["P1 Button 1"] = true end
      if f - t0 > 60 and f - t0 < 75 then
        for i = 0, 3 do
          if mm:read_u8(0x22BC + i) == 1 then
            local sx = mm:read_u8(0x22B8 + i)
            if shots[i] then
              if sx > shots[i] + 1 then ahead = ahead + 1 end
            end
            shots[i] = sx
          else shots[i] = nil end
        end
      end
      if f - t0 > 200 then phase = "back"; t0 = f end
    elseif phase == "back" then
      -- back to about 20 px left of the Ark's middle, then up to the ceiling
      local want = -4
      local vx = mm:read_u8(0x2704)                         -- (the whole-pixel speed)
      if dx > want + 1 then held["P1 Left"] = true elseif dx < want - 1 then held["P1 Right"] = true
      elseif vx == 0 then phase = "dock"; t0 = f end         -- lined up and stopped
    elseif phase == "dock" then
      held["P1 Up"] = true                                  -- just push up
      if st == 0 and not results.dock then results.dock = (f - t0) / 60; t1 = f end
      if results.dock and mm:read_u8(0x27DC) > 0 then results.fired = 1 end   -- the Ark's bolt
      if results.dock and f - t1 > 20 then phase = "undock"; t0 = f end
      if f - t0 > 600 and not results.dock then results.dock = -1; phase = "undock"; t0 = f end
    elseif phase == "undock" then
      held["P1 Down"] = true
      if st == 1 and auto == 0 then results.undock = (f - t0) / 60; phase = "away"; t0 = f end
      if f - t0 > 300 then results.undock = -1; phase = "done" end
    elseif phase == "away" then
      held["P1 Up"] = true; held["P1 Left"] = true             -- off up and away
      if st == 0 or auto == 1 then results.accident = 1 end
      if f - t0 > 60 then phase = "out"; side = 1; t0 = f end
    elseif phase == "out" then                               -- off to one side, low
      local k = side > 0 and "P1 Right" or "P1 Left"
      if st == 0 then held["P1 Down"] = true
      elseif auto == 0 then
        if y < 124 then held["P1 Down"] = true end
        if dx * side < 70 then held[k] = true end
        if y >= 124 and dx * side >= 70 then phase = "pass"; t0 = f end
      end
      if f - t0 > 600 then results["pass" .. side] = -1; phase = side > 0 and "out" or "done"; side = -side; t0 = f end
    elseif phase == "pass" then                              -- at it; up and in on the way
      held[side > 0 and "P1 Left" or "P1 Right"] = true
      if dx * side < 40 then held["P1 Up"] = true end
      if st == 0 then
        results["pass" .. side] = (f - t0) / 60
        if side > 0 then side = -1; phase = "out"; t0 = f else phase = "done" end
      elseif f - t0 > 180 then
        results["pass" .. side] = -1
        if side > 0 then side = -1; phase = "out"; t0 = f else phase = "done" end
      end
    end
  end
  for name, field in pairs(fields) do
    if name:match("^P1 ") or name == "Select" then field:set_value(held[name] and 1 or 0) end
  end
  if phase == "done" or f > 6000 then
    print(string.format("bullets pulling away from the shuttle: %d frames of shots", ahead))
    print(string.format("docking from 4 px off, just pushing up: %s", results.dock and results.dock >= 0 and string.format("%.1f s", results.dock) or "FAILED"))
    print(string.format("undocking, holding down: %s", results.undock and results.undock >= 0 and string.format("%.1f s", results.undock) or "FAILED"))
    print(string.format("flying up and away just out of the Ark: %s", results.accident and "DOCKED BY ACCIDENT" or "no dock"))
    print(string.format("docking with up still held: the Ark %s", results.fired and "FIRED" or "held its fire"))
    local function pr(v) return v and v >= 0 and string.format("%.1f s", v) or "FAILED" end
    print(string.format("docking on the move, from the right (up-left): %s", pr(results.pass1)))
    print(string.format("docking on the move, from the left (up-right): %s", pr(results["pass-1"])))
    print(string.format("result %d %.2f %.2f %d %d %.2f %.2f", ahead, results.dock or -1, results.undock or -1, results.accident or 0, results.fired or 0, results.pass1 or -1, results["pass-1"] or -1))
    manager:machine():exit()
  end
end)
