-- Save test (DESIGN.md 7.5, save.asm): run four times by tools/test_save.sh
-- with a SaveKey and one nvram directory (PHASE):
--   A  a new voyage in slot 1, its state changed, docked (saved: VOYAGE SAVED)
--   B  the voyage screen shows slot 1's summary; Continue: all of it back
--   C  (a byte of the slot broken by the script) damaged; button 2, fire:
--      cleared
--   D  slot 1 empty
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end
local out, bad = {}, {}
local function check(name, ok, detail) table.insert(out, string.format("%s: %s%s", name, ok and "ok" or "WRONG", detail and (" (" .. detail .. ")") or "")); if not ok then table.insert(bad, name) end end
local steps, si, t0, f = {}, 1, 0, 0
local function step(wait, press, fn) table.insert(steps, {wait, press, fn}) end
local CH = function(c) return (string.byte(c) - 32) * 2 end
local function is(v, c) return v == CH(c) or v == CH(c) + 1 end   -- (the selected line: inverse)
local phase = os.getenv("PHASE") or "A"
local watch, wfrom = nil, 0
local function screen()                                          -- the voyage screen: slots' states
  local m = mem()
  return m:read_u8(0x259B), m:read_u8(0x23A0), m:read_u8(0x23A8), m:read_u8(0x23B0)
end
step(300, nil, nil)
step(100, "P1 Button 1", nil)                                    -- the title: the voyage screen
if phase == "A" then
  step(20, nil, function()
    local go, s1, s2, s3 = screen()
    check("the voyage screen, all empty", go == 0 and s1 == 0 and s2 == 0 and s3 == 0, string.format("go %d, %d %d %d", go, s1, s2, s3))
    check("NEW VOYAGE shown", is(mem():read_u8(0x2250 + 12), "N")) end)
  step(30, "P1 Button 1", nil)                                   -- slot 1: a new voyage
  step(30, nil, function() local m = mem()
    check("a new voyage in slot 1", m:read_u8(0x2591) == 1 and m:read_u8(0x22FC) == 0, string.format("slot %d", m:read_u8(0x2591)))
    m:write_u8(0x2594, 0x01); m:write_u8(0x2595, 0x23); m:write_u8(0x2596, 0x45)   -- credits 012345
    m:write_u8(0x2592, 0x23); m:write_u8(0x2593, 0x01)                             -- stardate 291
    m:write_u8(0x2585, 3)                                                          -- ore aboard
    m:write_u8(0x2386, 33)                                                         -- energy
    m:write_u8(0x25F5, 0x05)                                                       -- 2 achievements (docking earns a third)
    m:write_u8(0x25F7, 7)                                                          -- pirates destroyed
    m:write_u8(0x26C5, m:read_u8(0x26C5) | 3)                                      -- sector 6 visited
    m:write_u8(0x25A9, 9)                                                          -- a port's stock
    m:write_u8(0x27F7, 1) end)
  step(30, "P1 Button 1", function() watch = "dock"; wfrom = f end)              -- DOCK (home's a port)
  step(30, nil, function() local m = mem()
    check("docked: VOYAGE SAVED", m:read_u8(0x22FC) == 2 and m:read_u8(0x27FC) == 16, string.format("view %d, message %d", m:read_u8(0x22FC), m:read_u8(0x27FC))) end)
elseif phase == "B" then
  step(20, nil, function() local m = mem()
    local go, s1, s2, s3 = screen()
    check("slot 1 saved, 2 and 3 empty", go == 0 and s1 == 1 and s2 == 0 and s3 == 0, string.format("%d %d %d", s1, s2, s3))
    check("its summary", m:read_u8(0x23A1) == 0 and m:read_u8(0x23A2) == 0x23 and m:read_u8(0x23A3) == 1 and m:read_u8(0x23A4) == 1
      and m:read_u8(0x23A5) == 0x23 and m:read_u8(0x23A6) == 0x45 and m:read_u8(0x23A7) == 3,
      string.format("%02X %02X %02X %02X %02X %02X %02X", m:read_u8(0x23A1), m:read_u8(0x23A2), m:read_u8(0x23A3), m:read_u8(0x23A4), m:read_u8(0x23A5), m:read_u8(0x23A6), m:read_u8(0x23A7)))
    check("on screen: SECTOR, the credits", is(m:read_u8(0x2250 + 12), "S") and m:read_u8(0x2278 + 20) == CH("0") and m:read_u8(0x2278 + 25) == CH("5"))
    check("the cursor on it", m:read_u8(0x22FB) == 0) end)
  step(30, "P1 Button 1", nil)                                   -- Continue
  step(30, nil, function() local m = mem()
    check("on the map, slot 1", m:read_u8(0x259B) == 0 and m:read_u8(0x22FC) == 0 and m:read_u8(0x2591) == 1 and m:read_u8(0x2590) == 0,
      string.format("go %d view %d slot %d sector %d", m:read_u8(0x259B), m:read_u8(0x22FC), m:read_u8(0x2591), m:read_u8(0x2590)))
    check("credits back", m:read_u8(0x2594) == 1 and m:read_u8(0x2595) == 0x23 and m:read_u8(0x2596) == 0x45)
    check("stardate back", m:read_u8(0x2592) == 0x23 and m:read_u8(0x2593) == 1)
    check("aboard, energy back", m:read_u8(0x2585) == 3 and m:read_u8(0x2386) == 33, string.format("ore %d energy %d", m:read_u8(0x2585), m:read_u8(0x2386)))
    check("the long block back", m:read_u8(0x25F5) == 0x15 and m:read_u8(0x25F7) == 7 and m:read_u8(0x25A9) == 9,
      string.format("ach %d kills %d stock %d", m:read_u8(0x25F5), m:read_u8(0x25F7), m:read_u8(0x25A9)))
    check("the galaxy back", m:read_u8(0x26C5) & 3 == 3)
    check("the hull's most", m:read_u8(0x258F) > 0, string.format("%d", m:read_u8(0x258F))) end)
elseif phase == "C" then
  step(20, nil, function()
    local go, s1 = screen()
    check("slot 1 damaged", s1 == 2, string.format("%d", s1))
    check("DAMAGED shown", is(mem():read_u8(0x2250 + 12), "D")) end)
  step(30, "P1 Button 2", nil)
  step(10, nil, function() check("asked", mem():read_u8(0x27FD) == 1) end)
  step(30, "P1 Button 1", nil)
  step(30, nil, function() local m = mem()
    check("cleared", m:read_u8(0x27FD) == 0 and m:read_u8(0x23A0) == 0 and m:read_u8(0x27FC) == 1 and m:read_u8(0x259B) == 0) end)
else
  step(20, nil, function()
    local go, s1 = screen()
    check("slot 1 empty", s1 == 0 and go == 0, string.format("%d", s1)) end)
  step(30, "P1 Down", nil)
  step(30, "P1 Down", nil)
  step(30, "P1 Down", nil)
  step(10, nil, function() check("the last line", mem():read_u8(0x22FB) == 3) end)
  step(30, "P1 Button 1", nil)                                   -- back to the title
  step(60, nil, function() check("the title again", mem():read_u8(0x259B) == 3) end)
  step(100, "P1 Button 1", nil)                                  -- and the voyage screen again
  step(20, nil, function() local go, s1 = screen(); check("the voyage screen again", go == 0 and s1 == 0) end)
end
emu.register_frame_done(function()
  f = f + 1
  local held = {}
  local st = steps[si]
  if watch == "dock" and mem():read_u8(0x27FC) == 16 then
    table.insert(out, string.format("saving took %d frames", f - wfrom - 2)); watch = nil
  end
  if st then
    if f - t0 == 1 and st[3] then st[3]() end
    if st[2] and f - t0 >= 2 and f - t0 <= 6 then held[st[2]] = true end
    if f - t0 >= st[1] then si = si + 1; t0 = f end
  else
    print("save " .. phase .. ": " .. table.concat(out, "; "))
    print("result " .. ((#bad == 0 and #out >= 2) and 1 or 0))
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
