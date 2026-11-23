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
  for k = 0, 2 do m:write_u8(0x25A9 + k, (class & (1 << k)) ~= 0 and 12 or 0) end   -- home's stock (port 0)
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
    local stock = m:read_u8(0x25A9 + k)
    if which == "sell" then
      local price = base[k] - 4 + 8 * tier                    -- (it had bought none)
      check("sell a commodity the port buys", dc == price and dg == -1 and stock == 1, string.format("+%d credits, goods %d, it's bought %d", dc, dg, stock))
    else
      local p = base[k] + 4 * tier                             -- 12 in stock: + p * 3 / 32
      local price = p + (p * 3) // 32
      check("buy a commodity the port sells", dc == -price and dg == 1 and stock == 11, string.format("%d credits (%d), goods %+d, stock %d", dc, price, dg, stock))
    end
    s.k = nil end)
end
-- sold out: none bought
step(20, nil, function() local m = mem()
  if not sellk then return end
  m:write_u8(0x25A9 + sellk, 0); m:write_u8(0x22FB, sellk); m:write_u8(0x27F7, 1); s.c0, s.g0 = credits(), m:read_u8(0x2585 + sellk) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() local m = mem()
  if not sellk then return end
  check("sold out: none bought", credits() == s.c0 and m:read_u8(0x2585 + sellk) == s.g0) end)
-- BIO-BOUNTY: sell a walker; keep a glider (left)
step(20, "P1 Button 2", function() local m = mem(); m:write_u8(0x256B, 2); m:write_u8(0x256F, 1); m:write_u8(0x25A4, 0); m:write_u8(0x25CA, 0) end)
step(20, nil, function() s.c0 = credits() end)
step(30, "P1 Button 1", nil)
step(10, nil, function() local m = mem()
  local b = (30 * (2 + tier)) // 2
  check("sell a creature (walker)", credits() - s.c0 == b and m:read_u8(0x256B) == 1 and m:read_u8(0x25CA) == 1, string.format("+%d, bounty %d", credits() - s.c0, b))
  s.c0, s.b = credits(), b end)
step(30, "P1 Button 1", nil)
step(10, nil, function() local m = mem()
  local b = (s.b * 7) // 8                                     -- it's had one: an eighth less
  check("a second walker: less", credits() - s.c0 == b and m:read_u8(0x256B) == 0, string.format("+%d, expected %d", credits() - s.c0, b))
  m:write_u8(0x22FB, 4); m:write_u8(0x27F7, 1) end)
step(30, "P1 Left", nil)
step(10, nil, function() local m = mem()
  check("keep one for the manifest (glider)", m:read_u8(0x25A4) == 1 and m:read_u8(0x256F) == 0) end)
-- SHIPYARD: refuel, repair, the hull
step(20, "P1 Button 2", function() local m = mem(); m:write_u8(0x2591, 10); m:write_u8(0x2386, 50); setcred(1000) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("refuel (4 a unit at home)", mem():read_u8(0x2591) == 30 and credits() == 920, string.format("fuel %d, credits %d", mem():read_u8(0x2591), credits()))
  mem():write_u8(0x22FB, 1); mem():write_u8(0x27F7, 1) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("repair (4 a point, to 100)", mem():read_u8(0x2386) == 100 and credits() == 720, string.format("energy %d, credits %d", mem():read_u8(0x2386), credits()))
  mem():write_u8(0x22FB, 2); mem():write_u8(0x27F7, 1) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("the hull upgrade (100: +5)", mem():read_u8(0x2588) == 1 and credits() == 620 and mem():read_u8(0x258F) == 105 and mem():read_u8(0x2386) == 105, string.format("level %d, credits %d, max %d, energy %d", mem():read_u8(0x2588), credits(), mem():read_u8(0x258F), mem():read_u8(0x2386))); setcred(100) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("too dear (the next hull, 120)", mem():read_u8(0x2588) == 1 and credits() == 100) end)
-- BANK (home: safe space): deposit 100, deposit all, withdraw 100
local function bank() return bcd(mem():read_u8(0x25A6)) * 10000 + bcd(mem():read_u8(0x25A7)) * 100 + bcd(mem():read_u8(0x25A8)) end
step(20, "P1 Button 2", function() local m = mem(); setcred(1000); m:write_u8(0x25A6, 0); m:write_u8(0x25A7, 0); m:write_u8(0x25A8, 0) end)
step(20, nil, function() check("the bank's tab (safe space)", mem():read_u8(0x27FB) == 3) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("deposit 100", credits() == 900 and bank() == 100, credits() .. "/" .. bank()); mem():write_u8(0x22FB, 1); mem():write_u8(0x27F7, 1) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("deposit all", credits() == 0 and bank() == 1000, credits() .. "/" .. bank()); mem():write_u8(0x22FB, 2); mem():write_u8(0x27F7, 1) end)
step(30, "P1 Button 1", nil)
step(10, nil, function() check("withdraw 100", credits() == 100 and bank() == 900, credits() .. "/" .. bank()) end)
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
    if os.getenv("SNAP_DIR") then manager:machine().screens[":screen"]:snapshot() end
    print("port (tier " .. tier .. ", class " .. class .. "): " .. table.concat(out, "; "))
    print("result " .. ((#bad == 0 and #out >= 14) and 1 or 0))
    manager:machine():exit()
  end
  for name, field in pairs(fields) do if name:match("^P1 ") then field:set_value(held[name] and 1 or 0) end end
end)
