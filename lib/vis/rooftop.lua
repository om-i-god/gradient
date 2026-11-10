-- rooftop: a city rooftop at night. a big water tower stands on its stilts
-- on the left, two TV aerials beside it, an air-con unit with its round fan
-- and a satellite dish on a pole in front of the parapet, and a tower block
-- rises close behind on the right. beyond the parapet the far skyline is
-- dotted with lit windows, a second water tower stands on a far roof, a
-- lattice mast carries its aviation lights, and a low cloud hangs over it
-- all. the kick shakes the water towers' rings, the bass spins the air-con
-- fan and makes it hum, hats are the mast's aviation lights, ticks blink
-- windows on the skyline, a stab lights a window in the tower block
-- (note = which), arps are the aerial-tip lights (note = which). the clap
-- is a far searchlight swinging up to the cloud, perc a glint off the
-- dish (voice = where on it). the pad lights the cloud's underside, the
-- pump breathes the lamp on the parapet. mids lift the roof's things, highs
-- glint on the coping and the aerials, lows hum in the roof felt, the level
-- lights the skyline
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local PY = 46                          -- the parapet's coping
  local RY = 58                          -- what stands on the roof stands here
  -- the far skyline: left, right, top
  local BLDG = {{0, 10, 33}, {10, 20, 29}, {20, 30, 35}, {30, 44, 31}, {44, 58, 28},
    {58, 70, 34}, {70, 78, 30}, {78, 92, 37}, {92, 100, 32}}
  local MX = 51                          -- the far mast, on the fifth roof
  local MLIGHTS = {3, 11, 19}            -- its aviation lights
  local TB0, TB1, TBT = 100, 124, 10     -- the tower block: left, right, roof
  local TIPS = {{32, 15, 58}, {42, 25, 58}, {92, 33, 46}, {112, 2, 10}}   -- the aerials: tip x, y, foot
  local FCX, FCY, FR = 55, 51, 4         -- the air-con fan
  local DCX, DCY, DR = 85, 38, 6         -- the dish's cup
  local DA = -0.8                        -- the way the dish looks (up and right)
  local LX = 116                         -- the parapet lamp
  local SLX = 64                         -- the searchlight, on the sixth roof

  -- the skyline's windows, picked once: x, y, level
  local WINS = {}
  for b = 1, #BLDG do
    local x0, x1, top = BLDG[b][1], BLDG[b][2], BLDG[b][3]
    for x = x0 + 2, x1 - 2, 3 do
      for y = top + 3, PY - 2, 3 do
        local h = K.hash(x * 64 + y, 3)
        if h > 0.6 and not (x >= 3 and x <= 25) then WINS[#WINS + 1] = {x, y, 1.1 + 1.6 * (h - 0.6)} end
      end
    end
  end
  -- the tower block's windows: 4 across, 7 down
  local TWINS = {}
  for r = 0, 6 do
    for c = 0, 3 do TWINS[#TWINS + 1] = {TB0 + 3 + c * 5, TBT + 4 + r * 5, K.hash(r * 4 + c, 5) > 0.7} end
  end

  -- the fades follow the trails setting: at classic at half strength, held within
  -- 15% / 10%; at fine and dense nearly in full (0.44x .. 2.2x), so the slider shows
  local function TR()
    if K.detail == "classic" then return math.min(1.1, math.max(0.85, K.trail ^ 0.5)) end
    return math.min(2.2, math.max(0.4, K.trail ^ 0.9))
  end
  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    return v < 0.03 and 0 or v
  end
  -- a hit eases in over a frame or so: big areas never jump
  local function rise(t) return math.min(1, 0.4 + (K.NOW - t) / 0.08) end

  local kick_t, pump_t, clap_t = -99, -99, -99
  local rot = 0                          -- the fan's turn, radians
  local lit = {}                         -- per tower-block window: when a stab lit it
  for i = 1, #TWINS do lit[i] = -99 end
  local tips = {}                        -- per aerial tip: the arp's light
  for i = 1, #TIPS do tips[i] = 0 end
  local runs = {}                        -- each note sends light down its mast: when, which
  for i = 1, 8 do runs[i] = {t = -99, i = 1} end
  local rni = 0
  local glints = {}                      -- the dish's glints
  for i = 1, 3 do glints[i] = {t = -99, v = 1} end
  local gli = 0
  local blink = {}                       -- the skyline windows the last tick blinked
  for i = 1, 6 do blink[i] = i end
  local tick_n = 0
  local pdz = 0
  -- hits pile up and drain: each one adds, so it shows whenever it lands
  local acc = {kick = 0, bass = 0, hat = 0, tick = 0, pump = 0}
  local function add(k, v) acc[k] = math.min(1.6, acc[k] + v) end

  function M.init()
    kick_t, pump_t, clap_t = -99, -99, -99
    rot, tick_n, pdz = 0, 0, 0
    for i = 1, #TWINS do lit[i] = -99 end
    for i = 1, #TIPS do tips[i] = 0 end
    for i = 1, #runs do runs[i].t = -99 end
    for i = 1, #glints do glints[i].t = -99 end
    for i = 1, #blink do blink[i] = i end
    for k in pairs(acc) do acc[k] = 0 end
  end
  M.clear = M.init

  function M.kick() kick_t = K.NOW; add("kick", 0.5) end
  function M.pump() pump_t = K.NOW; add("pump", 0.4) end
  function M.bass() add("bass", 0.45) end
  function M.hat() add("hat", 0.75) end
  function M.clap() clap_t = K.NOW end
  function M.perc(voice)
    gli = gli % #glints + 1
    glints[gli].t, glints[gli].v = K.NOW, clamp(math.floor(K.num(voice, 1)), 1, 3)
  end
  function M.tick()
    tick_n = tick_n + 1
    for k = 1, #blink do blink[k] = math.floor(K.hash(tick_n * 7 + k, 11) * #WINS) + 1 end
    add("tick", 0.8)
  end
  function M.stab(notes)
    local n = type(notes) == "table" and notes[1] or 60
    lit[math.floor(K.num(n, 60)) % #TWINS + 1] = K.NOW
  end
  function M.arp(lane, note)
    local i = (math.floor(K.num(note, 72)) + clamp(math.floor(K.num(lane, 1)), 1, 4)) % #TIPS + 1
    tips[i] = math.min(1.5, tips[i] + 0.8)
    rni = rni % #runs + 1
    runs[rni].t, runs[rni].i = K.NOW, i
  end
  function M.bar() end

  -- a water tower: tank x0..x1 from y0 to y1, its hoops shaken by the kick
  local function tower(ol, rl, shake, x0, x1, y0, y1, nh)
    local cx = (x0 + x1) / 2
    line(ol, x0, y0, cx, y0 - (x1 - x0) * 0.35); line(ol, cx, y0 - (x1 - x0) * 0.35, x1, y0)
    line(ol, x0, y0, x0, y1); line(ol, x1, y0, x1, y1)
    line(ol, x0, y1, x1, y1)
    for k = 1, nh do
      local y = y0 + (y1 - y0) * k / (nh + 1) + (k % 2 == 0 and shake or -shake)
      line(rl, x0 + 1, y, x1 - 1, y)
    end
  end

  function M.draw()
    local T, DT, DTS, NOW, e = K.T, K.DT, K.DTS, K.NOW, K.energy
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    local dense, RT = K.detail == "dense", K.react
    local cls = K.detail == "classic"
    -- fine / dense: the energy scales the music's marks (calm .. unmistakable),
    -- and a kickless stretch sends the searchlight slowly through the cloud
    local ge = cls and 1 or (0.7 + 0.5 * e)
    local kl = cls and 0 or K.kickless
    if RT > 1 then RT = 1 + (RT - 1) * 0.4 end      -- eased above 1: the lit bound
    local fp = K.playing                            -- time-driven detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point
    local function E(l) return math.min(l * RT, 13) end
    local function G(l) return E(l * ge) end
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local pf = fade(pump_t, 0.3) * rise(pump_t)
    local dk = math.exp(-DT / (0.3 * TR()))
    for k, v in pairs(acc) do acc[k] = v < 0.01 and 0 or v * dk end
    local tk = math.exp(-DT / (0.25 * TR()))      -- short: each note steps up and dies away
    for i = 1, #TIPS do tips[i] = tips[i] < 0.01 and 0 or tips[i] * tk end
    local kk, bt, ap, hf, tf = acc.kick * rise(kick_t), acc.bass, acc.pump, acc.hat, acc.tick
    -- the fan: slow at rest, spun up by the bass
    rot = (rot + DTS * (0.8 + 12 * bt)) % K.TAU

    -- the pad: the low cloud, lit from below by the city
    K.haze(0, 0, 128, 13, 0.03 + 0.45 * pdz + 0.14 * kl, 1.1 + 1.8 * pdz + 0.8 * kl, T * 1.4)
    if pdz > 0.05 then
      K.dashes(E(2.8 * pdz), 12, 6, 8, T * 1.2, 0, 128)
      K.dashes(E(2 * pdz), 10, 4, 9, -T, 0, 128)
    end
    -- the city's glow behind the skyline, which the level lifts
    K.haze(0, 20, 100, 34, 0.04 + 0.2 * amp, 1 + 1.2 * amp, T * 2)

    -- the far skyline: roofs, sides and lit windows
    local bl = 1.2 + 0.4 * mid + 0.9 * amp
    for b = 1, #BLDG do
      local x0, x1, top = BLDG[b][1], BLDG[b][2], BLDG[b][3]
      if not cls then
        -- fine / dense: the far blocks as dark masses (every other row), so the
        -- roof's things stand in front of them
        for y = top + 2, PY - 1, 2 do put(1, x0, y, x1 - x0, 1) end
      end
      line(bl, x0, top, x1, top)
      line(bl * 0.8, x1, top, x1, PY)
    end
    local wb = cls and (0.4 + 1.2 * amp) or (0.4 + 1.2 * amp + 1.4 * e)
    for i = 1, #WINS do
      local w = WINS[i]
      put(w[3] + wb, w[1], w[2], 1, 1)
    end
    -- ticks: windows blinking on along the skyline
    if tf > 0.02 then
      for k = 1, #blink do
        local w = WINS[blink[k]]
        put(E(8 * tf), w[1], w[2], 2, 1)
        put(E(3 * tf), w[1] - 1, w[2] - 1, 4, 3)
      end
    end
    K.grain(function(u, v) return u * 100, 30 + v * 14 end, hi * 80, 6)

    -- the far mast: a lattice to its aviation lights, the hats
    local ml = 1.2 + 0.5 * mid
    line(ml, MX - 2, BLDG[5][3], MX, MLIGHTS[1]); line(ml, MX + 2, BLDG[5][3], MX, MLIGHTS[1])
    K.dashes(1, 15, 1, 4, 0, MX - 1, MX + 2)
    K.dashes(1, 23, 1, 4, 2, MX - 1, MX + 2)
    local slow = 1.8 + 0.8 * math.sin(T * 1.3)
    for i = 1, #MLIGHTS do
      local y = MLIGHTS[i]
      line(math.min(13, slow + E(9 * hf)), MX - 1, y, MX + 1, y)
      if hf > 0.02 then
        put(E(4 * hf), MX - 5, y, 11, 1)
        put(E(3 * hf), MX - 2, y - 2, 5, 1); put(E(3 * hf), MX - 2, y + 2, 5, 1)
      end
    end

    -- the clap: a far searchlight swinging up to the cloud
    local cf = fade(clap_t, 0.4) * rise(clap_t)
    if cf > 0 then
      local s = -22 + (NOW - clap_t) * 60
      local top = BLDG[6][3]
      line(E(5 * cf), SLX, top, SLX + s - 3, 13)
      line(E(5 * cf), SLX, top, SLX + s + 3, 13)
      line(E(2.6 * cf), SLX, top, SLX + s, 13)
      put(E(4.5 * cf), SLX + s - 8, 13, 17, 1)
      put(E(3 * cf), SLX + s - 6, 11, 13, 1)
      put(E(9 * cf), SLX - 1, top - 1, 3, 1)
    end

    -- fine / dense, kickless: the searchlight sweeps slowly through the cloud on its own
    if kl > 0.05 and fp then
      local s = math.sin(T * 0.35) * 30
      local top = BLDG[6][3]
      line(E(kl * 2.4), SLX, top, SLX + s - 3, 13)
      line(E(kl * 2.4), SLX, top, SLX + s + 3, 13)
      K.put_sub(E(kl * (2.6 + 2 * pf)), SLX + s - 8, 13, 17, 1)
      K.put_sub(E(kl * 1.6), SLX + s - 5, 11, 11, 1)
      put(E(kl * 5), SLX - 1, top - 1, 3, 1)
    end

    -- the second water tower, on a far roof
    local oc = 1.6 + 0.6 * mid
    local shake = kk > 0.05 and math.sin((NOW - kick_t) * 35) * 1.6 * kk or 0
    local rl = cls and (1.6 + 0.6 * mid + E(6 * kk)) or (1.4 + 0.5 * mid + G(8 * kk))
    tower(oc, rl, shake, 71, 77, 21, 27, 2)
    line(oc, 72, 27, 71, 30); line(oc, 76, 27, 77, 30)

    -- the tower block close behind: its windows, and the stabs lighting one
    line(oc, TB0, TBT, TB1, TBT); line(oc, TB0, TBT, TB0, PY); line(oc, TB1, TBT, TB1, PY)
    if not cls then
      -- fine / dense: the block's floors, a dark band between each row of windows
      for r = 0, 7 do put(1, TB0 + 1, TBT + 2 + r * 5, TB1 - TB0 - 1, 1) end
    end
    for i = 1, #TWINS do
      local w = TWINS[i]
      local f = fade(lit[i], 0.9) * rise(lit[i])
      put(math.min(13, (w[3] and (cls and 2.4 or 2.4 + 1.6 * e) or 1) + (cls and E(10 * f) or G(10 * f))), w[1], w[2], 2, 2)
      if f > 0 then
        put(E(3.5 * f), w[1] - 1, w[2] - 1, 4, 4)
        put(E(2.4 * f), w[1] - 2, w[2] + 3, 6, 1)
      end
    end

    -- the parapet: the coping (the highs glint on it), the wall, the lamp the pump breathes
    line(2 + 0.8 * mid + 1.8 * hi, 0, PY, 127, PY)
    line(1.3, 0, PY + 4, 127, PY + 4)
    K.dashes(1, PY + 2, 4, 6, 0, 0, 128)
    local lamp = E(2.2 * pf + 2.6 * ap)
    put(math.min(13, 3.2 + lamp), LX, PY + 1, 3, 2)
    line(2.6 + 0.8 * mid + 1.8 * hi + lamp, LX - 10, PY, LX + 12, PY)
    put(1 + lamp, LX - 10, PY + 5, 23, 1)
    put(0.8 + lamp * 0.8, LX - 14, PY + 7, 30, 1)
    put(lamp * 0.6, LX - 18, PY + 9, 36, 2)
    put(lamp * 0.5, LX - 6, PY + 1, 15, 3)

    -- the roof felt: the lows hum in it
    local fl = 0.9 + 1.6 * lo + E(1.4 * bt)
    K.dashes(fl, 54, 3, 7, 1, 0, 128)
    K.dashes(fl, 59, 4, 8, 5, 0, 128)
    K.dashes(fl * 0.8, 63, 5, 9, 2, 0, 128)

    -- the big water tower on its stilts: the kick shakes its hoops
    if not cls then
      -- fine / dense: the water inside, filling the tank as the energy rises (low
      -- at rest, brimming at the peak); the kick slops it, the lows hum in it
      local wy = 34 - 13 * e + shake * 1.4
      for y = math.floor(wy) + 2, 35, 2 do put(1.4 + 0.8 * lo, 5, y, 19, 1) end
      local tilt = kk > 0.05 and math.sin((NOW - kick_t) * 22) * 2.4 * kk or 0
      K.line_sub(math.min(13, 2.6 + 2.4 * e + G(8 * kk)), 5, wy - tilt, 23, wy + tilt)
      K.put_sub(E(2.4 * kk + 1.2 * bt), 6, wy + 1, 17, 1)
    end
    tower(1.8 + 0.8 * mid, rl, shake, 4, 24, 16, 36, 4)
    line(oc, 14, 9, 14, 7)
    line(oc, 6, 36, 4, RY); line(oc, 22, 36, 24, RY); line(oc, 14, 36, 14, RY)
    line(1.3, 5, 44, 23, 44); line(1.3, 5, 52, 23, 52)
    line(1.2, 6, 44, 22, 52); line(1.2, 22, 44, 6, 52)
    if kk > 0.05 then
      -- water slopping against the tank's walls, the stilts thrumming
      put(E(3.5 * kk), 6, 33, 17, 2)
      put(E(2.6 * kk), 2, RY + 1, 25, 1)
    end

    -- the aerials: masts, booms and elements (highs glint on them), the arps at the tips
    local al = 1.4 + 0.5 * mid + 1.6 * hi
    line(oc, 32, RY, 32, 16); line(al, 27, 18, 40, 18)
    for x = 28, 39, 3 do line(al, x, 16, x, 20) end
    line(oc, 42, RY, 42, 26); line(al, 38, 28, 47, 28)
    for x = 39, 46, 3 do line(al, x, 26, x, 30) end
    line(oc, 92, PY, 92, 34)
    line(oc, 112, TBT, 112, 3)
    -- each note: a short run of light down its mast from the tip
    for k = 1, #runs do
      local a = NOW - runs[k].t
      if a >= 0 and a < 0.7 then
        local tp = TIPS[runs[k].i]
        local v = (1 - a / 0.7) * math.min(1, a / 0.05 + 0.4)
        local ry = math.min(tp[3] - 4, tp[2] + 2 + a * 45)
        line(math.min(13, 1.6 + E(10 * v)), tp[1], ry, tp[1], ry + 4)
        line(math.min(13, 1.4 + E(5.5 * v)), tp[1], ry - 6, tp[1], ry - 1)
        put(E(3.6 * v), tp[1] - 2, ry + 1, 2, 2); put(E(3.6 * v), tp[1] + 1, ry + 1, 2, 2)
      end
    end
    for i = 1, #TIPS do
      local x, y, f = TIPS[i][1], TIPS[i][2], tips[i]
      put(math.min(13, 1.8 + E(5 * f)), x, y, 1, 1)
      if f > 0 then
        -- the tip light: a small round beacon glow (no rays: that is the dish's
        -- glint), dimmer than a stab's window, its light running down the mast
        -- (a line: the mast would hide a rect)
        put(E(3.2 * f), x - 1, y - 1, 3, 3)
        put(E(1.6 * f), x - 2, y - 1, 5, 3); put(E(1.6 * f), x - 1, y - 2, 3, 5)
        line(math.min(13, 1.6 + E(3 * f)), x, y + 2, x, y + 7)
      end
    end

    -- the air-con unit: its casing, slats, and the fan the bass spins
    local ul = 1.8 + 0.7 * mid + E(1.6 * bt)
    line(ul, 48, PY - 1, 66, PY - 1); line(ul, 48, PY - 1, 48, RY); line(ul, 66, PY - 1, 66, RY)
    line(1.4, 47, RY, 67, RY)
    for y = PY + 1, RY - 2, 2 do line(1.2 + E(1.8 * bt), 61, y, 64, y) end
    local gl = 1.6 + 0.6 * mid + E(3 * bt)
    local px, py = FCX + FR, FCY
    for i = 1, 8 do
      local a = i / 8 * K.TAU
      local nx, ny = FCX + math.cos(a) * FR, FCY + math.sin(a) * FR
      line(gl, px, py, nx, ny)
      px, py = nx, ny
    end
    for k = 0, 2 do
      local a = rot + k * K.TAU / 3
      K.line_sub(2 + E(5 * bt), FCX, FCY, FCX + math.cos(a) * (FR - 1), FCY + math.sin(a) * (FR - 1))
    end
    if bt > 0.05 then
      -- the hum: warm air shimmering off the top
      local wob = math.sin(T * 9) * 2
      K.dashes(E(3 * bt), PY - 3, 3, 5, wob, 49, 66)
      K.dashes(E(2.2 * bt), PY - 5, 2, 5, -wob + 2, 50, 65)
    end

    -- the dish: pole, cup, feed arm, and perc's glint off it
    line(oc, DCX - 1, RY, DCX - 1, DCY + 2)
    line(1.3, DCX - 4, RY, DCX + 2, RY)
    -- the cup: the back half of an ellipse, shallow along the way it looks
    local ux, uy = math.cos(DA), math.sin(DA)
    local dl = 2.4 + 0.6 * mid + 1.2 * hi
    local r0x, r0y = DCX - uy * DR, DCY + ux * DR
    local qx, qy = r0x, r0y
    for i = 1, 6 do
      local t = math.pi / 2 + i / 6 * math.pi
      local c, sn = math.cos(t) * DR * 0.5, math.sin(t) * DR
      local nx, ny = DCX + ux * c - uy * sn, DCY + uy * c + ux * sn
      line(dl, qx, qy, nx, ny)
      qx, qy = nx, ny
    end
    line(dl * 0.7, r0x, r0y, qx, qy)
    local bx, by = DCX - ux * DR * 0.5, DCY - uy * DR * 0.5
    local fx, fy = DCX + ux * 4, DCY + uy * 4
    line(1.4, bx, by, fx, fy)
    put(1.6, fx, fy, 1, 1)
    for i = 1, #glints do
      local g = glints[i]
      local f = fade(g.t, 0.3)
      if f > 0 then
        local gx, gy = r0x, r0y
        if g.v == 2 then gx, gy = qx, qy elseif g.v == 3 then gx, gy = fx, fy end
        put(E(11 * f), gx, gy, 1, 1)
        local r = 3 + (NOW - g.t) * 20
        put(E(3 * f), gx - 1, gy - 1, 3, 3)
        put(E(6 * f), gx - r, gy, r, 1); put(E(6 * f), gx + 1, gy, r, 1)
        put(E(6 * f), gx, gy - r, 1, r); put(E(6 * f), gx, gy + 1, 1, r)
        line(E(3.6 * f), gx - 4, gy - 4, gx + 4, gy + 4); line(E(3.6 * f), gx - 4, gy + 4, gx + 4, gy - 4)
      end
    end

    -- dense: a washing line strung from the aerial to the air-con, its washing
    -- swaying; the pipe run along the roof; a ladder up the tower's stilts
    if dense and not cls then
      local sw = fp and math.sin(T * 1.1) * 0.8 or 0
      line(1.6, 32, 40, 48, 44)
      for k = 1, 4 do
        local x = 33 + k * 3
        local y = 40 + (x - 32) * 0.25
        K.put_sub(2 + 0.8 * mid + E(1.2 * pf), x + sw * (k % 2 == 0 and 1 or 0.6), y + 1, 2, 2 + k % 2)
      end
      line(1.8, 70, RY - 2, 98, RY - 2)
      for x = 72, 96, 8 do put(2.4, x, RY - 3, 1, 3) end
      for y = 38, RY - 2, 3 do line(1.6, 11, y, 13, y) end
    end
    -- dense: a moth round the parapet lamp, a drip off the water tower
    if dense and fp then
      local ph = T * 2.4
      K.put_sub(2, LX + 1 + math.cos(ph) * 4, PY - 2 + math.sin(ph * 1.3) * 2, 1, 1)
      local u = (T * 0.4) % 1
      K.put_sub(2.2 * (1 - u), 9, 37 + u * 20, 1, 1)
    end
    -- far planes crawl under the cloud, whatever the music
    K.put_sub(1.8, (T * 4 + 30) % 170 - 20, 15, 2, 1)
    K.put_sub(1.4, 150 - (T * 3 + 40) % 170, 17, 1, 1)
    -- the energy lights a sign on a far roof
    if e > 0.05 then put(1 + 3 * e, 61, BLDG[6][3] + 2, 7, 1) end
  end

  M.init()
  return M
end
