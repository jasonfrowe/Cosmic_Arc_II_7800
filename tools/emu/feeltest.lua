-- Feel test (the planet): what a player notices.
--  1. (Bullets: gone with the shuttle's blasters; the defences' pulse is
--     dodged instead.)
--  2. Docking: about 20 pixels off the Ark's middle, not lined up, just push
--     up: it must dock within 2 s.
--  3. Undocking: hold down: within 2 s it's out of the tunnel and can move.
-- Turrets are held out. tools/test_feel.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local f, phase, t0 = 0, "launch", 0
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
      local want = -20
      if dx > want + 3 then held["P1 Left"] = true elseif dx < want - 3 then held["P1 Right"] = true
      else phase = "dock"; t0 = f end
    elseif phase == "dock" then
      held["P1 Up"] = true                                  -- just push up
      if st == 0 then results.dock = (f - t0) / 60; phase = "undock"; t0 = f end
      if f - t0 > 600 then results.dock = -1; phase = "undock"; t0 = f end
    elseif phase == "undock" then
      held["P1 Down"] = true
      if st == 1 and auto == 0 then results.undock = (f - t0) / 60; phase = "done" end
      if f - t0 > 300 then results.undock = -1; phase = "done" end
    end
  end
  for name, field in pairs(fields) do
    if name:match("^P1 ") or name == "Select" then field:set_value(held[name] and 1 or 0) end
  end
  if phase == "done" or f > 4000 then
    print(string.format("bullets pulling away from the shuttle: %d frames of shots", ahead))
    print(string.format("docking from 20 px off, just pushing up: %s", results.dock and results.dock >= 0 and string.format("%.1f s", results.dock) or "FAILED"))
    print(string.format("undocking, holding down: %s", results.undock and results.undock >= 0 and string.format("%.1f s", results.undock) or "FAILED"))
    print(string.format("result %d %.2f %.2f", ahead, results.dock or -1, results.undock or -1))
    manager:machine():exit()
  end
end)
