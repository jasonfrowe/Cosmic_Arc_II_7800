-- Take screenshots at the frames listed in SNAP_FRAMES (comma separated),
-- then exit after the last one. Used by tools/snap.sh.
-- POKES (optional): "frame:addr:value,..." (hex addr/value) writes memory
-- at those frames, e.g. "30:2502:0C" to solo POKEY 2 in the music mask.
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
local f = 0
emu.register_frame_done(function()
  f = f + 1
  for _, p in ipairs(pokes) do
    if p[1] == f then
      manager:machine().devices[":maincpu"].spaces["program"]:write_u8(p[2], p[3])
    end
  end
  if frames[f] then manager:machine().screens[":screen"]:snapshot() end
  if f > last then manager:machine():exit() end
end)
