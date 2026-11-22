-- Arrival test: no shots; each large rock timed from appearing to hitting
-- the Ark, by lane kind (up/down, diagonal, across). They must match.
-- tools/test_arrival.sh
local f, born, lane = 0, {}, {}
local sum, n = {0, 0, 0}, {0, 0, 0}
local kind = {[0] = 1, 2, 3, 2, 1, 2, 3, 2}       -- 1 vertical, 2 diagonal, 3 across
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
emu.register_frame_done(function()
  f = f + 1
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  m:write_u8(0x23EF, 1)
  local held = {}
  if f >= 300 and f <= 305 then held["P1 Button 1"] = true end
  if f > 330 then
    m:write_u8(0x2386, 96)
    for i = 0, 9 do
      local t = m:read_u8(0x2300 + i)
      if t == 1 and not born[i] then born[i] = f; lane[i] = m:read_u8(0x23E4 + i) end
      if t ~= 1 and born[i] then
        local k = kind[lane[i]]
        sum[k] = sum[k] + (f - born[i]); n[k] = n[k] + 1
        born[i] = nil
      end
    end
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
  if f == 3600 then
    local avg = {}
    for k = 1, 3 do avg[k] = n[k] > 0 and sum[k] / n[k] or -1 end
    print(string.format("frames to the Ark: up/down %.0f (%d), diagonal %.0f (%d), across %.0f (%d)",
      avg[1], n[1], avg[2], n[2], avg[3], n[3]))
    print(string.format("result %.1f %.1f %.1f", avg[1], avg[2], avg[3]))
    manager:machine():exit()
  end
end)
