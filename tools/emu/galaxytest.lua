-- Galaxy test: New Game with the seed's timing bytes set (SEED), then the
-- galaxy checked against docs/DESIGN.md 3.2's rules. tools/test_galaxy.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local seed = tonumber(os.getenv("SEED") or "1")
local f = 0
emu.register_frame_done(function()
  f = f + 1
  local m = manager:machine().devices[":maincpu"].spaces["program"]
  if f >= 296 and f <= 306 then m:write_u8(0x2575, seed % 256); m:write_u8(0x2579, (seed * 7) % 256) end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value((f >= 300 and f <= 305 and name == "P1 Button 1") and 1 or 0) end end
  if f == 420 then
    local cell, warp, info, sec = {}, {}, {}, {}
    local bad = {}
    for k = 0, 63 do
      cell[k], warp[k], info[k] = m:read_u8(0x2640 + k), m:read_u8(0x2600 + k), m:read_u8(0x2680 + k)
      if (cell[k] >> 4) > 7 or (cell[k] & 15) > 11 then table.insert(bad, "cell off the grid " .. k) end
      if sec[cell[k]] then table.insert(bad, "two sectors in one cell") end
      sec[cell[k]] = k
    end
    local dc = {[0]=0,1,1,1,0,-1,-1,-1}; local dr = {[0]=-1,-1,0,1,1,1,0,-1}
    local out, inn, oneway, links = {}, {}, 0, 0
    for k = 0, 63 do out[k] = {}; inn[k] = inn[k] or {} end
    for k = 0, 63 do
      for d = 0, 7 do if warp[k] & (1 << d) ~= 0 then
        local r, c = (cell[k] >> 4) + dr[d], (cell[k] & 15) + dc[d]
        local n = sec[r * 16 + c]
        if r < 0 or r > 7 or c < 0 or c > 11 or not n then table.insert(bad, "a warp to nowhere from " .. (k + 1))
        else
          table.insert(out[k], n); inn[n] = inn[n] or {}; table.insert(inn[n], k); links = links + 1
          if warp[n] & (1 << ((d + 4) % 8)) == 0 then oneway = oneway + 1 end
        end
      end end
    end
    local function reach(adj)
      local seen, q, n = {[0] = true}, {0}, 1
      local dist = {[0] = 0}
      local i = 1
      while q[i] do
        for _, v in ipairs(adj[q[i]]) do if not seen[v] then seen[v] = true; dist[v] = dist[q[i]] + 1; n = n + 1; table.insert(q, v) end end
        i = i + 1
      end
      return n, dist
    end
    local nf, dist = reach(out)
    local nb = reach(inn)
    if nf ~= 64 then table.insert(bad, "only " .. nf .. " reachable from home") end
    if nb ~= 64 then table.insert(bad, "home unreachable from " .. (64 - nb)) end
    for k = 1, 63 do if dist[k] and dist[k - 1] and dist[k] < dist[k - 1] then table.insert(bad, "numbering not by distance at " .. (k + 1)) break end end
    -- jumps back to safe space (sectors 1-10), following the warps
    local ds = {}
    for k = 0, 63 do ds[k] = k < 10 and 0 or 99 end
    local changed = true
    while changed do
      changed = false
      for k = 10, 63 do for _, v in ipairs(out[k]) do
        if ds[v] + 1 < ds[k] then ds[k] = ds[v] + 1; changed = true end
      end end
    end
    local maxd = 0
    for k = 0, 63 do
      local g = m:read_u8(0x26C0 + k) >> 2
      if g ~= ds[k] then table.insert(bad, string.format("sector %d: %d jumps to safe space, stored %d", k + 1, ds[k], g)) break end
      if ds[k] > maxd then maxd = ds[k] end
    end
    local ports, tierports, nebsafe = 0, {[0] = 0, 0, 0, 0}, 0
    for k = 0, 63 do
      local t, tier = info[k] & 3, info[k] >> 6
      if t == 1 then ports = ports + 1; tierports[tier] = tierports[tier] + 1 end
      if t == 3 and k < 10 then nebsafe = nebsafe + 1 end
    end
    if info[0] & 3 ~= 1 then table.insert(bad, "home isn't a port") end
    if tierports[0] < 2 then table.insert(bad, "fewer than 2 ports in safe space") end
    for t = 1, 3 do if tierports[t] < 1 then table.insert(bad, "no port in tier " .. t) end end
    if nebsafe > 0 then table.insert(bad, "a nebula in safe space") end
    if ports ~= 11 then table.insert(bad, ports .. " ports, not 11") end
    if (info[0] >> 2) & 7 ~= 0 then table.insert(bad, "home isn't BBB") end
    local sss = false
    for k = 1, 9 do if info[k] & 3 == 1 and (info[k] >> 2) & 7 == 7 then sss = true end end
    if not sss then table.insert(bad, "no SSS port in safe space") end
    print(string.format("seed %d: %d warps (%d one-way), ports %d/%d/%d/%d, farthest %d hops, %d from safe space: %s",
      seed, links, oneway, tierports[0], tierports[1], tierports[2], tierports[3], dist[63] or -1, maxd,
      #bad == 0 and "ok" or table.concat(bad, "; ")))
    print("result " .. (#bad == 0 and 1 or 0))
    manager:machine():exit()
  end
end)
