-- Port test: New Game, dock at home (a port), and trade: credits and goods
-- checked after each action. tools/test_port.sh
local fields = {}
for tag, port in pairs(manager:machine():ioport().ports) do
  for name, field in pairs(port.fields) do fields[name] = field end
end
local function mem() return manager:machine().devices[":maincpu"].spaces["program"] end
local function bcd(b) return (b >> 4) * 10 + (b & 15) end
local function credits() local m = mem(); return bcd(m:read_u8(0x2594)) * 10000 + bcd(m:read_u8(0x2595)) * 100 + bcd(m:read_u8(0x2596)) end
local function setcred(v) local m = mem()
  local function tob(x) return ((x // 10) << 4) | (x % 10) end
  m:write_u8(0x2594, tob(v // 10000)); m:write_u8(0x2595, tob((v // 100) % 100)); m:write_u8(0x2596, tob(v % 100)) end
local out, bad = {}, {}
local function check(name, ok, detail) table.insert(out, string.format("%s: %s%s", name, ok and "ok" or "WRONG", detail and (" (" .. detail .. ")") or "")); if not ok then table.insert(bad, name) end end
-- the steps: {frames to wait, inputs to press, a function to run first}
local steps, si, t0, f = {}, 1, 0, 0
local function step(wait, press, fn) table.insert(steps, {wait, press, fn}) end
local tier, class, s = 0, 0, {}
step(300, nil, nil)
step(100, "P1 Button 1", nil)                                  -- New Game
step(5, nil, function() local m = mem()                        -- home: buys ore and equipment, sells organics
  m:write_u8(0x2680, (m:read_u8(0x2680) & 0xE3) | (2 << 2)); m:write_u8(0x27F7, 1) end)
step(60, "P1 Button 1", function() local m = mem()             -- dock (item 0)
  local i = m:read_u8(0x2680); tier = i >> 6; class = (i >> 2) & 7
  m:write_u8(0x2585, 3); m:write_u8(0x2586, 0); m:write_u8(0x2587, 0); setcred(1000) end)
-- COMMODITIES: the first one the port buys (sell one), the first it sells (buy one)
local buyk, sellk
step(40, nil, function()
  for k = 0, 2 do
    if class & (1 << k) == 0 then buyk = buyk or k else sellk = sellk or k end
  end
end)
local base = {[0] = 20, 30, 50}
for _, which in ipairs({"sell", "buy"}) do
  step(20, nil, function() local m = mem()
    local k = which == "sell" and buyk or sellk
    if not k then return end
    m:write_u8(0x2585 + k, which == "sell" and 3 or 0)
    m:write_u8(0x22FB, k); m:write_u8(0x27F7, 1)
    s.c0, s.g0, s.k = credits(), m:read_u8(0x2585 + k), k end)
  step(30, "P1 Button 1", nil)
  step(10, nil, function() local m = mem()
    if not s.k then return end
    local k = s.k
    local dc, dg = credits() - s.c0, m:read_u8(0x2585 + k) - s.g0
    if which == "sell" then
      local price = base[k] - 4 + 8 * tier
      check("sell a commodity the port buys", dc == price and dg == -1, string.format("+%d credits, goods %d", dc, dg))
    else
      local price = base[k] + 4 * tier
      check("buy a commodity the port sells", dc == -price and dg == 1, string.format("%d credits, goods %+d", dc, dg))
    end
    s.k = nil end)
end
-- BIO-BOUNTY: sell a walker; keep a glider (left)
step(20, "P1 Button 2", function() local m = mem(); m:write_u8(0x256B, 2); m:write_u8(0x256F, 1); m:write_u8(0x2571, 0) end)
step(20, nil, function() s.c0 = credits() end)
step(30, "P1 Button 1", nil)
step(10, nil, function() local m = mem()
  local b = (30 * (2 + tier)) // 2
  check("sell a creature (walker)", credits() - s.c0 == b and m:read_u8(0x256B) == 1, string.format("+%d, bounty %d", credits() - s.c0, b))
  m:write_u8(0x22FB, 4); m:write_u8(0x27F7, 1) end)
step(30, "P1 Left", nil)
step(10, nil, function() local m = mem()
  check("keep one for the manifest (glider)", m:read_u8(0x2571) & 16 ~= 0 and m:read_u8(0x256F) == 0) end)
-- SHIPYARD: refuel, repair, the laser
step(20, "P1 Button 2", function() local m = mem(); m:write_u8(0x2591, 10); m:write_u8(0x2386, 50); setcred(1000) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("refuel", mem():read_u8(0x2591) == 30 and credits() == 900, string.format("fuel %d, credits %d", mem():read_u8(0x2591), credits()))
  mem():write_u8(0x22FB, 1); mem():write_u8(0x27F7, 1) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("repair", mem():read_u8(0x2386) == 96 and credits() == 854, string.format("energy %d, credits %d", mem():read_u8(0x2386), credits()))
  mem():write_u8(0x22FB, 2); mem():write_u8(0x27F7, 1) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("the laser upgrade", mem():read_u8(0x2588) == 1 and credits() == 354, string.format("level %d, credits %d", mem():read_u8(0x2588), credits())) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("too dear (the next laser, 1000)", mem():read_u8(0x2588) == 1 and credits() == 354) end)
step(10, nil, nil)
emu.register_frame_done(function()
  f = f + 1
  local held = {}
  local st = steps[si]
  if st then
    if f - t0 == 1 and st[3] then st[3]() end
    if st[2] and f - t0 >= 2 and f - t0 <= 6 then held[st[2]] = true end
    if f - t0 >= st[1] then si = si + 1; t0 = f end
  else
    print("port (tier " .. tier .. ", class " .. class .. "): " .. table.concat(out, "; "))
    print("result " .. ((#bad == 0 and #out >= 8) and 1 or 0))
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
