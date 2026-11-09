-- signalbox: a railway junction at night, seen from beside the line. the
-- raised signal box stands on the left, its long lit window showing the
-- lever frame and the block instruments on their shelf. two tracks run
-- past it and fan out: points send the near line down to a third track,
-- the far line away up a branch, and a crossover joins them. point rodding
-- runs from the box along the ballast, semaphore arms stand on a post and
-- a bracket, colour-light heads stand further down the line, and a line
-- of telegraph wires sags along the horizon. the kick sends a pulse of
-- light running along the rails, the bass hums through them (the rails
-- ring and the sleepers glow), hats twinkle on the semaphore lamps, ticks
-- are the block instruments' indicator lights, a stab pulls a lever (it
-- lights, and its arm lifts to clear), arps are the colour-light aspects
-- (note = which head and lamp). the clap is a train's lit windows
-- flickering past on the horizon, perc throws a set of points over with
-- sparks at the blade (voice = which). the pad is mist lying over the
-- junction, the pump breathes the box window. mids lift the box and the
-- posts, highs shine on the rail heads, lows glow in the ballast, the
-- level lights the sky over the far town
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local BX0, BX1 = 4, 38                 -- the box's walls
  local CAB, FLR, BASE = 12, 26, 40      -- the cabin's eaves, its floor, the base's foot
  local WY0, WH = 14, 10                 -- the window: top row, height
  local HZ = 31                          -- the horizon
  local RAILS = {43, 45, 52, 55}         -- the far track's rails, then the near track's
  local LEV0, NLEV = 8, 10               -- the lever frame: first lever x, levers 3 px apart
  local BELLS = {9, 17, 25, 33}          -- the block instruments on their shelf
  local POLES = {46, 62, 78, 94, 110, 126}
  -- semaphore arms: post x, pivot y (the home signal, then the bracket's two dolls)
  local ARMS = {{48, 13}, {84, 5}, {94, 5}}
  -- colour-light heads: x, head top, foot
  local HEADS = {{66, 30, 41}, {104, 28, 41}, {116, 23, 35}, {124, 33, 50}}
  -- points: toe x, rail y, which way the blade swings
  local POINTS = {{54, 55, 1}, {72, 43, -1}, {96, 52, -1}}

  -- the fades follow the trails setting at half strength, held within 15% / 10%
  local function TR() return math.min(1.1, math.max(0.85, K.trail ^ 0.5)) end
  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    return v < 0.03 and 0 or v
  end
  -- a hit eases in over a frame or so: big areas never jump
  local function rise(t) return math.min(1, 0.4 + (K.NOW - t) / 0.08) end

  local kick_t, pump_t, clap_t = -99, -99, -99
  local pulses = {}                      -- the kick's runs along the rails
  for i = 1, 3 do pulses[i] = -99 end
  local pui = 0
  local levers = {}                      -- per lever: when the stab pulled it
  for i = 1, NLEV do levers[i] = -99 end
  local arms = {}                        -- per arm: when its lever was pulled
  for i = 1, #ARMS do arms[i] = -99 end
  local heads = {}                       -- per head: the arp's light, the lamp lit
  for i = 1, #HEADS do heads[i] = {f = 0, asp = 1} end
  local points = {}                      -- per set: when it was thrown, which way it lies
  for i = 1, #POINTS do points[i] = {t = -99, s = 0} end
  local tick_k = 1
  local pdz = 0
  -- hits pile up and drain: each one adds, so it shows whenever it lands
  local acc = {kick = 0, bass = 0, hat = 0, tick = 0, pump = 0}
  local function add(k, v) acc[k] = math.min(1.6, acc[k] + v) end

  function M.init()
    kick_t, pump_t, clap_t = -99, -99, -99
    for i = 1, #pulses do pulses[i] = -99 end
    for i = 1, NLEV do levers[i] = -99 end
    for i = 1, #ARMS do arms[i] = -99 end
    for i = 1, #HEADS do heads[i].f, heads[i].asp = 0, 1 end
    for i = 1, #POINTS do points[i].t, points[i].s = -99, 0 end
    for k in pairs(acc) do acc[k] = 0 end
    tick_k, pdz = 1, 0
  end
  M.clear = M.init

  function M.kick()
    kick_t = K.NOW; add("kick", 0.5)
    pui = pui % #pulses + 1
    pulses[pui] = K.NOW
  end
  function M.pump() pump_t = K.NOW; add("pump", 0.4) end
  function M.bass() add("bass", 0.45) end
  function M.hat() add("hat", 0.75) end
  function M.clap() clap_t = K.NOW end
  function M.perc(voice)
    local p = points[clamp(math.floor(K.num(voice, 1)), 1, #POINTS)]
    p.t, p.s = K.NOW, 1 - p.s
  end
  function M.tick(kind)
    tick_k = clamp(math.floor(K.num(kind, 1)), 1, #BELLS)
    add("tick", 0.8)
  end
  function M.stab(notes)
    local n = type(notes) == "table" and notes[1] or 60
    local i = math.floor(K.num(n, 60)) % NLEV + 1
    levers[i] = K.NOW
    arms[(i - 1) % #ARMS + 1] = K.NOW
  end
  function M.arp(lane, note)
    local n = math.floor(K.num(note, 72))
    local h = heads[(n + clamp(math.floor(K.num(lane, 1)), 1, 4) * 3) % #HEADS + 1]
    h.f, h.asp = math.min(2, h.f + 0.9), n % 3 + 1
  end
  function M.bar() end

  function M.draw()
    local T, DT, NOW, e = K.T, K.DT, K.NOW, K.energy
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    local dense, RT = K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.4 end      -- eased above 1: the lit bound
    local fp = K.playing                            -- time-driven detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point
    local function E(l) return math.min(l * RT, 13) end
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local pf = fade(pump_t, 0.3) * rise(pump_t)
    local dk = math.exp(-DT / (0.3 * TR()))
    for k, v in pairs(acc) do acc[k] = v < 0.01 and 0 or v * dk end
    local hk = math.exp(-DT / (0.5 * TR()))
    for i = 1, #HEADS do local h = heads[i]; h.f = h.f < 0.01 and 0 or h.f * hk end
    local kk, bt, ap, hf, tf = acc.kick * rise(kick_t), acc.bass, acc.pump, acc.hat, acc.tick

    -- the sky over the far town: a glow the level lifts, and the horizon
    K.haze(44, 16, 128, HZ - 1, 0.04 + 0.22 * amp, 1 + 1.4 * amp, T * 2)
    line(1 + 1.6 * amp, 40, HZ, 127, HZ)

    -- the wires: telegraph poles along the horizon, two sagging wires between
    local wl = 1.2 + 0.8 * mid + 1.2 * hi
    for i = 1, #POLES do
      local x = POLES[i]
      line(1.2 + 0.5 * mid, x, HZ - 1, x, HZ - 12)
      line(1.2, x - 2, HZ - 11, x + 2, HZ - 11)
      if i > 1 then
        local x0 = POLES[i - 1]
        local xm = (x0 + x) / 2
        line(wl, x0 + 2, HZ - 11, xm, HZ - 9); line(wl, xm, HZ - 9, x - 2, HZ - 11)
        line(wl * 0.8, x0 - 2, HZ - 11, xm, HZ - 8); line(wl * 0.8, xm, HZ - 8, x + 2, HZ - 11)
      end
    end

    -- the clap: a train's lit windows flickering past along the horizon
    local cf = fade(clap_t, 0.4) * rise(clap_t)
    if cf > 0 then
      local tx = 42 + (NOW - clap_t) * 70
      line(E(2.6 * cf), tx, HZ - 1, tx + 46, HZ - 1)
      for k = 0, 11 do
        local fl = K.hash(k + math.floor((NOW - clap_t) * 8), 7) > 0.3 and 1 or 0.45
        put(E(8 * cf * fl), tx + 1 + k * 4, HZ - 3, 2, 1)
      end
      put(E(3.4 * cf), tx - 6, HZ + 1, 58, 1)
    end

    -- the pad: mist lying over the junction
    K.haze(0, 34, 128, 64, 0.03 + 0.42 * pdz, 1.1 + 1.6 * pdz, T * 1.2)
    if pdz > 0.05 then
      K.dashes(E(2.4 * pdz), 48, 5, 7, T * 1.5, 0, 128)
      K.dashes(E(2 * pdz), 58, 4, 9, -T, 0, 128)
    end

    -- the ballast and the sleepers: the lows glow in the stones, the bass
    -- lights the sleepers
    local hum = 0.3 * lo + 0.9 * bt
    local bl = 0.9 + 1.6 * lo + E(2.4 * bt)
    K.dashes(bl, 46, 2, 5, 1, 0, 128)
    K.dashes(bl, 57, 2, 6, 3, 0, 128)
    K.dashes(bl * 0.8, 63, 3, 7, 0, 0, 128)
    local sl = 1.3 + E(2.4 * bt)
    K.dashes(sl, 44, 1, 4, 0, 0, 128)
    K.dashes(sl, 53, 1, 5, 2, 0, 128)
    K.dashes(sl, 54, 1, 5, 2, 0, 128)
    K.dashes(sl * 0.8, 59, 1, 5, 0, 76, 128)
    K.dashes(sl * 0.8, 60, 1, 5, 0, 76, 128)

    -- the rails: the highs shine on their heads, the bass makes them ring
    -- (a shimmer sliding beside each), the kick runs a pulse along them
    local rl = 1.8 + 0.6 * mid + 2 * hi + E(2.6 * bt) + E(1.4 * kk)
    for i = 1, #RAILS do line(rl, 0, RAILS[i], 127, RAILS[i]) end
    -- the branch away from the far line, the turnout down from the near one,
    -- the crossover between them
    line(rl * 0.9, 72, 43, 127, 34); line(rl * 0.9, 80, 45, 127, 37)
    line(rl, 54, 55, 92, 61); line(rl, 92, 61, 127, 61)
    line(rl, 62, 52, 96, 58); line(rl, 96, 58, 127, 58)
    line(rl * 0.9, 96, 52, 110, 45); line(rl * 0.9, 102, 55, 116, 45)
    if hum > 0.05 then
      local ring = E(0.6 + 2.2 * hum)
      for i = 1, #RAILS do
        K.dashes(ring, RAILS[i] + (i % 2 == 0 and 1 or -1), 5, 11, T * 6 + i * 3, 0, 128)
      end
    end
    for i = 1, #pulses do
      local a = NOW - pulses[i]
      if a >= 0 and a < 0.7 then
        local v = (1 - a / 0.7) * math.min(1, a / 0.05 + 0.4)
        local x = -6 + a * 200
        for r = 1, #RAILS do
          line(E(10 * v), x, RAILS[r], x + 7, RAILS[r])
          line(E(4.5 * v), x - 14, RAILS[r], x - 1, RAILS[r])
        end
        put(E(2.6 * v), x - 8, RAILS[1] - 2, 16, 1)
        put(E(2.6 * v), x - 8, RAILS[3] - 2, 16, 1)
      end
    end
    -- the point rodding: a dim rod along the six-foot from the box, with its cranks
    line(1.1 + 0.5 * mid, 30, 48, 100, 48)
    K.dashes(1, 49, 1, 8, 2, 30, 100)

    -- perc: a set of points thrown over, sparks off the switch blade
    for i = 1, #POINTS do
      local q, p = POINTS[i], points[i]
      local x, y, d = q[1], q[2], q[3]
      local f = fade(p.t, 0.35)
      local off = p.s * d
      line(2.2 + E(8 * f), x, y + off, x + 8, y + off * 0.3)
      line(1.4, x - 2, y + 2, x + 2, y + 2)                     -- the stretcher
      if f > 0 then
        local a = NOW - p.t
        put(E(5 * f), x - 2, y - 2, 7, 1)
        for k = 0, 3 do
          local ang = 0.6 + k * 0.6
          local r = 2 + a * 34
          K.put_sub(E(9 * f), x + 3 + math.cos(ang) * r * d, y - 1 - math.sin(ang) * r + a * a * 60, 1, 1)
          K.put_sub(E(4 * f), x + 3 + math.cos(ang) * r * 0.5 * d, y - 1 - math.sin(ang) * r * 0.5, 1, 1)
        end
      end
    end

    -- the colour-light heads: the arps' aspects along the line
    for i = 1, #HEADS do
      local c, h = HEADS[i], heads[i]
      local x, ty, fy = c[1], c[2], c[3]
      line(1.3 + 0.6 * mid, x + 1, ty + 7, x + 1, fy)
      put(1, x, ty, 3, 7)
      for k = 1, 3 do
        local lit = k == h.asp
        put(math.min(13, (lit and 2.2 or 1.4) + (lit and E(9 * h.f) or 0)), x + 1, ty + k * 2 - 1, 1, 1)
      end
      if h.f > 0 then
        -- the lit aspect: a halo round the head, its light on the hood and the ballast
        local ly = ty + h.asp * 2 - 1
        put(E(4.5 * h.f), x - 2, ly - 1, 7, 3)
        put(E(3 * h.f), x - 1, ty - 2, 5, 1)
        put(E(3 * h.f), x - 4, fy + 1, 11, 1)
        put(E(2.2 * h.f), x - 3, fy + 3, 9, 1)
      end
    end

    -- the semaphores: the home signal's post, the bracket, the arms and lamps
    local pl = 1.6 + 0.8 * mid
    line(pl, 48, 12, 48, 50); line(1.8, 47, 11, 49, 11)
    line(pl, 89, 12, 89, 41); line(pl, 83, 12, 95, 12)
    line(pl, 84, 4, 84, 12); line(pl, 94, 4, 94, 12)
    line(1.8, 83, 3, 85, 3); line(1.8, 93, 3, 95, 3)
    for i = 1, #ARMS do
      local x, y = ARMS[i][1], ARMS[i][2]
      local f = fade(arms[i], 0.6)
      -- a pulled lever lifts the arm to clear (45 degrees), then it drops back
      local ang = -0.8 * K.ease(math.min(1, (NOW - arms[i]) / 0.12)) * math.min(1, f * 2)
      local dx, dy = math.cos(ang) * 8, math.sin(ang) * 8
      local al = 2.4 + 0.8 * mid + E(7 * f)
      line(al, x + 1, y, x + 1 + dx, y + dy)
      line(al * 0.7, x + 1, y + 1, x + 1 + dx, y + 1 + dy)
      -- the lamp: lit dim, the hats twinkle on it
      local lx, ly = x - 2, y + 2
      put(math.min(13, 2.6 + E(8 * hf)), lx, ly, 1, 1)
      if hf > 0.02 then
        -- a four-point star round the lamp, and its beam thrown down the line
        put(E(5.5 * hf), lx - 3, ly, 3, 1); put(E(5.5 * hf), lx + 1, ly, 3, 1)
        put(E(5.5 * hf), lx, ly - 3, 1, 3); put(E(5.5 * hf), lx, ly + 1, 1, 3)
        put(E(2.6 * hf), lx - 2, ly - 2, 1, 1); put(E(2.6 * hf), lx + 2, ly - 2, 1, 1)
        put(E(2.6 * hf), lx - 2, ly + 2, 1, 1); put(E(2.6 * hf), lx + 2, ly + 2, 1, 1)
        put(E(3.4 * hf), lx - 16, ly, 12, 1)
      end
    end

    -- the box: gable roof, cabin, the long window, the locking room below
    local sl1 = 2 + 0.8 * mid
    line(sl1, BX0 - 3, CAB, 21, 5); line(sl1, 21, 5, BX1 + 3, CAB)
    line(sl1, BX0 - 3, CAB, BX1 + 3, CAB)
    line(sl1, BX0, CAB, BX0, BASE); line(sl1, BX1, CAB, BX1, BASE)
    line(sl1, BX0 - 1, FLR, BX1 + 1, FLR)
    line(1.4, BX0 - 1, BASE, BX1 + 1, BASE)
    -- the window breathes with the pump; levers, bars and the shelf stand against it
    local wy1 = WY0 + WH - 1
    local wlv = math.min(13, 2.8 + 0.8 * mid + E(2.2 * pf + 2.6 * ap))
    put(wlv, BX0 + 2, WY0, BX1 - BX0 - 3, WH)
    put(1 + E(1.6 * pf + 1.8 * ap), BX0 - 2, FLR + 1, BX1 - BX0 + 5, 1)
    for x = 14, 30, 8 do line(1.2, x, WY0, x, wy1) end
    line(1.2, BX0 + 2, WY0 + 2, BX1 - 2, WY0 + 2)
    line(1.1, LEV0 - 1, wy1, LEV0 + NLEV * 3 - 2, wy1)
    for i = 1, NLEV do
      local x = LEV0 + (i - 1) * 3
      local f = fade(levers[i], 0.6)
      if f > 0 then
        -- the pulled lever: lit, leaning the other way, its slot glowing
        put(math.min(13, wlv + E(4 * f)), x - 1, WY0 + 3, 3, WH - 3)
        line(E(11 * f), x, wy1, x + 1, wy1 - 5)
      else
        line(1.1, x, wy1, x - 1, wy1 - 5)
      end
    end
    -- the block instruments: the ticks light their indicators
    for k = 1, #BELLS do
      local x = BELLS[k]
      local il = math.min(13, 1.2 + E(8 * tf) + (k == tick_k and E(4 * tf) or 0))
      line(il, x, WY0, x + 1, WY0); line(il, x, WY0 + 1, x + 1, WY0 + 1)
      if tf > 0.02 then put(math.min(13, wlv + E((k == tick_k and 4.5 or 3) * tf)), x - 2, WY0 + 3, 6, 2) end
    end
    -- the locking room: brick courses, two small dark windows, the stair up
    for y = FLR + 3, BASE - 2, 4 do K.dashes(1, y, 3, 5, y, BX0 + 1, BX1) end
    put(1.6, 11, 30, 3, 3); put(1.6, 28, 30, 3, 3)
    line(1.6 + 0.5 * mid, BX1 + 1, FLR, BX1 + 12, BASE)
    line(1.2, BX1 + 1, FLR - 3, BX1 + 12, BASE - 3)
    line(1.3, BX1 + 12, BASE - 3, BX1 + 12, BASE)

    -- highs: glints on the rail heads
    K.grain(function(u, v) return u * 128, RAILS[1 + math.floor(v * 3.99)] - 1 end, hi * 80, 7)

    -- dense: a bat round the home signal's lamp, a slow drip off the eaves
    if dense and fp then
      local ph = T * 2.6
      K.put_sub(2, 46 + math.cos(ph) * 5, 10 + math.sin(ph * 1.4) * 3, 1, 1)
      local u = (T * 0.35) % 1
      K.put_sub(2.2 * (1 - u), BX1 + 2, CAB + 1 + u * 12, 1, 1)
    end
    -- far lamps creep along the horizon and the branch, whatever the music
    K.put_sub(1.8, (T * 4) % 90 + 40, HZ - 1, 2, 1)
    K.put_sub(1.4, 127 - (T * 2.5) % 40, 34 + ((T * 2.5) % 40) * 0.16, 1, 1)
    -- the energy wakes a far junction's lamp
    if e > 0.05 then put(1 + 2.5 * e, 120, HZ - 4, 1, 1) end
  end

  M.init()
  return M
end
