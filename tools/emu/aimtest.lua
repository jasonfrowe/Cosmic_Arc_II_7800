-- Input test: hold each of the 8 directions in deep space and print the
-- aim it gives (0 up, clockwise). Expect 0-7 in order. tools/test_aim.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local combos = {{"P1 Up"},{"P1 Up","P1 Right"},{"P1 Right"},{"P1 Down","P1 Right"},{"P1 Down"},{"P1 Down","P1 Left"},{"P1 Left"},{"P1 Up","P1 Left"}}
local f=0
emu.register_frame_done(function()
  f=f+1
  local hold = {}
  if f>=300 and f<=305 then hold["P1 Button 1"]=true end
  local k = math.floor((f-400)/30)
  if f>=400 and k>=0 and k<8 then for _,n in ipairs(combos[k+1]) do hold[n]=true end
    if (f-400)%30==20 then print(table.concat(combos[k+1],"+").." -> aim "..manager:machine().devices[":maincpu"].spaces["program"]:read_u8(0x2382)) end
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(hold[name] and 1 or 0) end end
  if f>650 then manager:machine():exit() end
end)
