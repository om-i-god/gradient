-- carpark: a multi-storey car park at night, seen side-on. three concrete
-- decks and an open roof stand on columns, with a zigzag ramp climbing the
-- left bays, dim parked cars on every deck, a stairwell tower on the right
-- with its tall lit window, and the exit barrier and its booth at the
-- ground-floor mouth. strip lights run under each deck ceiling: the kick
-- catches them (a fluorescent flare and a pool on the floor below), the
-- pump breathes them, and one failing tube flickers on the hats. the bass
-- hums in the lowest deck, ticks blink the barrier light, stabs send a
-- car's headlights sweeping up the ramp, arps are brake lights on the
-- parked cars (note = which car). the clap swings the stairwell door open
-- on its spill of light, perc is a dropped echo on a landing (voice =
-- floor). the pad is sodium fog drifting through the open sides and the
-- roof lamps. mids lift the concrete, highs glint on the windscreens, the
-- level lights the sky over the town
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local GY = 58                          -- the ground
  local X0, X1 = 12, 100                 -- the decks' left and right edges
  local SLAB = {16, 30, 44}              -- slab tops: the roof, deck 2, deck 1
  local FLOORS = {16, 30, 44, GY}        -- what cars stand on, roof first
  local COLS = {12, 34, 56, 78, 100}
  local SX0, SX1 = 101, 117              -- the stairwell tower
  local STOP = 7
  -- the ramp: a zigzag in the left bays, ground to roof
  local RAMP = {{14, GY}, {32, 44}, {14, 30}, {32, 16}}
  -- parked cars: floor index, x of the nose (facing right)
  local CARS = {{1, 62}, {1, 84}, {2, 40}, {2, 66}, {2, 86}, {3, 44}, {3, 60}, {3, 82}, {4, 46}, {4, 70}}
  local TUBE_X = {16, 38, 60, 82}        -- strip lights under each slab, 6 long
  local FAIL_D, FAIL_X = 2, 60           -- the failing tube: under deck 2
  -- fine / dense: the far town behind the roof, block tops picked once, and its windows
  local TOWN = K.profile(function(x)
    local b = x // 9
    return 6 + math.floor(K.hash(b, 21) * 5.5) + ((x % 9 == 0) and 1 or 0)
  end)
  local TWIN = {}
  for x = 1, 126, 3 do
    if x < 100 or x > 118 then
      for y = K.at(TOWN, x) + 2, 11, 3 do
        local h = K.hash(x * 31 + y, 22)
        if h > 0.55 then TWIN[#TWIN + 1] = {x, y, h} end
      end
    end
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
  local sweeps = {}
  for i = 1, 3 do sweeps[i] = -99 end
  local swi = 0
  local brakes = {}
  for i = 1, #CARS do brakes[i] = 0 end
  local echoes = {}
  for i = 1, 3 do echoes[i] = {t = -99, f = 1} end
  local eci = 0
  local pad_notes = {}
  local pdz = 0
  -- hits pile up and drain: each one adds, so it shows whenever it lands
  local acc = {bass = 0, hat = 0, tick = 0, perc = 0, pump = 0}
  local function add(k, v) acc[k] = math.min(1.6, acc[k] + v) end

  function M.init()
    kick_t, pump_t, clap_t = -99, -99, -99
    for i = 1, 3 do sweeps[i] = -99; echoes[i].t = -99 end
    for i = 1, #CARS do brakes[i] = 0 end
    for k in pairs(acc) do acc[k] = 0 end
    pad_notes = {}
    pdz = 0
  end
  M.clear = M.init

  function M.kick() kick_t = K.NOW end
  function M.pump() pump_t = K.NOW; add("pump", 0.4) end
  function M.bass() add("bass", 0.45) end
  function M.hat() add("hat", 0.6) end
  function M.clap() clap_t = K.NOW end
  function M.perc(voice)
    voice = clamp(math.floor(K.num(voice, 1)), 1, 3)
    add("perc", 0.7)
    eci = eci % #echoes + 1
    echoes[eci].t, echoes[eci].f = K.NOW, voice
  end
  function M.tick() add("tick", 0.8) end
  function M.stab()
    swi = swi % #sweeps + 1
    sweeps[swi] = K.NOW
  end
  function M.arp(lane, note)
    local n = math.floor(K.num(note, 72)) + clamp(math.floor(K.num(lane, 1)), 1, 4) * 3
    local i = n % #CARS + 1
    brakes[i] = math.min(1.6, brakes[i] + 0.7)
  end
  function M.pad(notes)
    pad_notes = {}
    if type(notes) == "table" then
      for i = 1, math.min(#notes, 4) do pad_notes[i] = K.num(notes[i], 50) end
    end
  end
  function M.bar() end

  -- a point along the ramp, u = 0 at the ground mouth .. 1 on the roof
  local function ramp_at(u)
    local s = clamp(u, 0, 0.999) * (#RAMP - 1)
    local i = math.floor(s)
    local a, b, f = RAMP[i + 1], RAMP[i + 2], s - i
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, b[1] > a[1] and 1 or -1
  end

  -- a parked car, nose to the right, standing on y
  local function car(l, x, y)
    put(l, x, y - 3, 13, 2)
    put(l * 0.8, x + 4, y - 5, 5, 1)
    put(l * 0.55, x + 3, y - 4, 8, 1)
    put(l * 0.7, x + 1, y - 1, 3, 1); put(l * 0.7, x + 9, y - 1, 3, 1)
  end

  function M.draw()
    local T, DT, NOW, e = K.T, K.DT, K.NOW, K.energy
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    local dense, RT = K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.4 end      -- eased above 1: the lit bound
    local fp = K.playing                            -- time-driven detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point
    local function E(l) return math.min(l * RT, 13) end
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local kk = fade(kick_t, 0.22) * rise(kick_t)
    local pf = fade(pump_t, 0.3) * rise(pump_t)
    local dk = math.exp(-DT / (0.3 * TR()))
    for k, v in pairs(acc) do acc[k] = v < 0.01 and 0 or v * dk end
    local bk = math.exp(-DT / (0.55 * TR()))
    for i = 1, #CARS do brakes[i] = brakes[i] < 0.01 and 0 or brakes[i] * bk end
    local bt, ap = acc.bass, acc.pump

    local cls = K.detail == "classic"
    -- fine / dense: the energy scales the music's marks (calm .. unmistakable),
    -- and a kickless stretch turns the car park over to its night lighting
    local ge = cls and 1 or (0.7 + 0.5 * e)
    local kl = cls and 0 or K.kickless
    local function G(l) return E(l * ge) end

    if cls then
      -- the sky over the town: a glow that rises with the level
      K.haze(0, 0, 128, 10, 0.04 + 0.22 * amp, 1 + 1.4 * amp, T * 2)
      if amp > 0.15 then K.dashes(math.min(2.6, amp * 2.6), 10, 3, 9, T * 3, 0, 128) end
    else
      -- the far town behind the roof: a dark mass, its windows lit by the level,
      -- and a thin glow over it
      -- (roofline solid, the walls in every other row: a dark mass that costs half)
      for b = 0, 14 do
        local x0 = b * 9
        if x0 < 100 or x0 > 110 then
          local top = K.at(TOWN, x0 + 1)
          local w = math.min(9, 128 - x0)
          put(1 + 1.4 * amp, x0, top, w, 1)
          for y = top + 2, 12, 2 do put(1, x0, y, w, 1) end
        end
      end
      for i = 1, #TWIN do
        local w = TWIN[i]
        put(1.6 + 3.2 * amp * w[3] + (dense and fp and 1.4 * math.max(0, math.sin(T * 0.7 + i * 2.1)) or 0), w[1], w[2], 1, 1)
      end
      K.haze(0, 0, 128, 4, 0.03 + 0.16 * amp, 1 + 1.2 * amp, T * 2)
    end

    -- the pad: sodium fog in the open sides of the decks (fine / dense: and the
    -- kickless night, breathing with the pump)
    for d = 1, 3 do
      K.haze(X0 + 1, SLAB[d] + 4, X1, FLOORS[d + 1] - 1, (cls and 0.03 or 0) + 0.4 * pdz + kl * (0.1 + 0.08 * ap),
        1.1 + 1.6 * pdz + 1.4 * kl, T * (1.5 + d * 0.4))
    end

    -- the concrete: slabs, the roof parapet, the columns, the ground
    -- (the pump breathes the ceilings' undersides). fine / dense: a step down,
    -- so the lights stand off it
    local cl = cls and (1.7 + 1.4 * mid) or (1.5 + 1.1 * mid)
    local s1, s2 = cl + 0.5, 1.2 + 0.8 * mid + 1.4 * hi + E(1.6 * pf + 2.2 * ap)
    local cv = 1.2 + 0.7 * mid
    for d = 1, 3 do
      local y = SLAB[d]
      line(s1, X0 - 2, y, X1, y)
      line(s2, X0 - 2, y + 1, X1, y + 1)
    end
    line(1.6 + 1.2 * mid + 1.6 * hi, X0 - 2, SLAB[1] - 3, X1, SLAB[1] - 3)
    for x = X0, X1, 8 do line(1.2, x, SLAB[1] - 3, x, SLAB[1]) end
    for i = 1, #COLS do
      local x = COLS[i]
      for d = 1, 3 do line(cv, x, SLAB[d] + 2, x, FLOORS[d + 1] - 1) end
    end
    line(2, 0, GY, 127, GY)
    K.dashes(0.9, GY + 3, 4, 11, 2, 0, 128)

    -- the roof lamps: one post per pad note, a sodium head on top
    for i = 1, #pad_notes do
      local x = clamp(K.px(pad_notes[i]), X0 + 6, X1 - 4)
      line(1.3, x, SLAB[1] - 3, x, SLAB[1] - 9)
      put(2 + 4 * pdz, x - 1, SLAB[1] - 10, 3, 1)
      put(1.8 * pdz, x - 5, SLAB[1] - 8, 11, 1)
    end

    -- the ramp: the sloped slab and its kerb
    for i = 1, #RAMP - 1 do
      local a, b = RAMP[i], RAMP[i + 1]
      line(cl, a[1], a[2] - 1, b[1], b[2] - 1)
      line(1.2, a[1], a[2] - 3, b[1], b[2] - 3)
    end

    -- the lowest deck hums with the bass and the low band
    local hum = 0.3 * lo + 0.8 * bt
    if hum > 0.03 then
      for r = cls and 0 or 1, 2 do
        local y = SLAB[3] + 5 + r * 3
        local wob = math.sin(T * 6 + r * 1.7) * 2
        K.dashes(E(1 + 3.2 * hum), y, 3, 7, wob + r * 4 + T * 3, X0 + 2, X1)
      end
      put(E(3 * bt), X0, GY - 2, X1 - X0, 1)
      if cls then put(E(2.5 * bt), X0, SLAB[3] + 2, X1 - X0, 1) end
    end
    line(1 + 2.4 * lo + E(4 * bt), X0, GY - 1, X1, GY - 1)

    -- the strip lights under each ceiling: the kick catches them, the pump breathes them
    local hf = acc.hat
    for d = 1, 3 do
      local y = SLAB[d] + 2
      local fl = FLOORS[d + 1] - 1
      for i = 1, #TUBE_X do
        local x = TUBE_X[i]
        local l
        if cls then
          l = math.min(13, 4 + 1.2 * mid + E(7 * kk) + E(1.4 * pf + 2 * ap))
        else
          -- night power at rest, waking with the energy; a kickless stretch dims
          -- them to every other tube, and the pump breathes those
          local base = (2.6 + 2.4 * e + 1.2 * mid) * (1 - 0.45 * kl * ((i + d) % 2))
          l = math.min(13, base + G(8 * kk) + E(1.4 * pf + 2 * ap) + kl * E(2.4 * pf) * ((i + d + 1) % 2))
        end
        if d == FAIL_D and x == FAIL_X then
          -- the failing tube: dark but for a slow guttering, caught by the hats
          local g = 0.5 + 0.5 * math.sin(T * 0.9) * math.sin(T * 2.3)
          l = math.min(13, 1.2 + 1.4 * g + E(7 * hf) + E(3 * kk))
          if hf > 0 then
            put(E(4 * hf), x - 3, y + 1, 12, 1)
            put(E(3 * hf), x - 6, fl, 18, 1)
            put(E(2.2 * hf), x - 1, fl - 1, 8, 1)
            put(E(2.2 * hf), x + 1, y + 2, 4, fl - y - 3)
            -- the bay it hangs in flickers with it: slab edges and columns
            local c0, c1 = COLS[3], COLS[4]
            line(s1 + E(3 * hf), c0, y - 2, c1, y - 2)
            line(s2 + E(3 * hf), c0, y - 1, c1, y - 1)
            line(s1 + E(2.6 * hf), c0, fl + 1, c1, fl + 1)
            line(cv + E(2.6 * hf), c0, y, c0, fl); line(cv + E(2.6 * hf), c1, y, c1, fl)
          end
        end
        put(l, x, y, 6, 1)
        if kk > 0.04 then
          if cls then put(E(3.6 * kk), x - 2, y + 1, 10, 1) else put(G(4 * kk), x - 1, y + 1, 8, 1) end
          put(cls and E(3.2 * kk) or G(4.6 * kk), x - 4, fl, 14, 1)
          if not cls and kk > 0.12 then
            -- fine / dense: the flare throws its light down through the bay
            put(G(2.4 * kk), x - 2, y + math.floor((fl - y) * 0.55), 10, 1)
          end
        end
        if not cls and kl > 0.05 and (i + d) % 2 == 0 then
          -- the kickless night: the lit tubes' pools breathe on the pump
          put(E(kl * (1.4 + 2.6 * pf)), x - 3, fl, 12, 1)
        end
      end
    end

    -- the parked cars, dim; their brake lights are the arps
    for i = 1, #CARS do
      local c = CARS[i]
      local x, y = c[2], FLOORS[c[1]]
      local cb = cls and (1.7 + 0.6 * mid) or (1.3 + 0.5 * mid)
      car(cb, x, y)
      put(1 + 3.5 * hi, x + 8, y - 5, 1, 1)                 -- the windscreen glint
      local f = brakes[i]
      if f > 0 then
        car(cb + E(3 * f), x, y)
        put(G(9 * f), x - 1, y - 3, 1, 2)
        put(E(5 * f), x - 6, y - 1, 6, 1)
        if cls then
          put(E(3.5 * f), x - 16, y - 1, 10, 1)
          if c[1] > 1 then put(E(2.4 * f), x - 4, SLAB[c[1] - 1] + 3, 18, 1) end
        end
        put(E(3 * f), x - 3, y - 4, 3, 1)
        put(E(2.4 * f), x - 6, y - 6, 9, 1)
      end
    end
    K.grain(function(u, v) return X0 + 2 + u * (X1 - X0 - 4), FLOORS[1 + math.floor(v * 3.99)] - 4 end, hi * 80, 7)
    if hi > 0.04 then K.dashes(hi * 3.4, GY + 1, 1, 7, T * 6, 0, 128) end

    -- stabs: a car climbs the ramp, its headlights sweeping ahead
    for i = 1, #sweeps do
      local a = NOW - sweeps[i]
      local life = 1.1 * TR()
      if a >= 0 and a < life then
        local u = a / life
        local x, y, dir = ramp_at(u * 0.9)
        local v = math.min(1, (1 - u) * 2.2) * math.min(1, a / 0.05 + 0.5)
        local ahead = dir > 0 and x + 2 or x - 16
        put(2.4, dir > 0 and x - 7 or x + 1, y - 4, 7, 2)
        put(G(11 * v), x, y - 4, 1, 1)
        for k = 1, 4 do
          put(G((7 - k) * v), x + dir * (k * 4), y - 4 - k * 0.6, 4, 1)
        end
        put(E(3.5 * v), ahead, y - 1, 14, 1)
        put(E(3 * v), ahead, y - 7, 14, 1)
      end
    end

    -- the stairwell: the tower, its tall lit window with the flights inside
    line(2.2, SX0, STOP, SX1, STOP)
    line(1.8 + 0.6 * mid, SX0, STOP, SX0, GY)
    line(1.8 + 0.6 * mid, SX1, STOP, SX1, GY)
    put(cls and (2.6 + 1.2 * mid + E(1.5 * pf + 2 * acc.perc)) or (1.8 + 0.7 * mid + E(1.2 * pf) + G(3.4 * acc.perc)), SX0 + 6, STOP + 4, 5, 38)
    for y = STOP + 6, STOP + 40, 6 do line(1.2, SX0 + 6, y + 5, SX0 + 10, y) end
    for d = 1, 3 do put(1.6, SX0 + 1, SLAB[d], SX1 - SX0 - 1, 1) end

    -- perc: a dropped echo on a landing, rings sliding out of the tower
    for i = 1, #echoes do
      local ec = echoes[i]
      local a = NOW - ec.t
      local f = fade(ec.t, 0.35)
      if f > 0 then
        local y = SLAB[4 - ec.f] - 2
        put(E(8 * f), SX0 + 6, y - 2, 5, 3)
        local r = 3 + a * 26
        put(E(4 * f), SX0 + 8 - r, y - 1, 1, 3); put(E(4 * f), SX0 + 8 + r, y - 1, 1, 3)
        put(E(2.5 * f), SX0 + 8 - r * 0.6, y - 4, r * 1.2, 1)
        put(E(2.5 * f), SX0 + 8 - r * 0.6, y + 2, r * 1.2, 1)
      end
    end

    -- the clap: the stairwell door swings open on its spill of light
    local cf = fade(clap_t, 0.3)
    local dl = 1.8 + E(9 * cf)
    put(dl, SX0 + 5, GY - 8, 7, 8)
    if cf > 0 then
      put(E(5 * cf), SX0 + 4, GY + 1, 10, 1)
      put(E(3.5 * cf), SX0 + 1, GY + 2, 18, 1)
      put(E(2.5 * cf), SX0 - 3, GY + 4, 28, 1)
      line(E(4 * cf), SX0 + 12, GY - 8, SX0 + 15, GY - 6)
    end

    -- the exit barrier: booth, arm, and the light the ticks blink
    line(1.8, 1, GY - 10, 7, GY - 10); line(1.6, 1, GY - 10, 1, GY); line(1.6, 7, GY - 10, 7, GY)
    put(1.4 + 1.2 * mid, 3, GY - 7, 3, 3)
    local barm = 2 + 1.5 * mid
    line(barm, 8, GY - 5, 26, GY - 5)
    K.dashes(barm + 1, GY - 5, 2, 4, 0, 10, 26)
    local tf = acc.tick
    local idle = (math.floor(T * 0.5) % 2 == 0) and 2.4 or 1.4
    put(math.min(13, idle + E(9 * tf)), 3, GY - 12, 2, 2)
    if tf > 0 then
      put(E(4.5 * tf), 0, GY - 12, 9, 1)
      put(E(3 * tf), 1, GY - 15, 6, 1)
      put(E(3.5 * tf), 9, GY - 6, 17, 1)
      put(E(3.5 * tf), 9, GY - 4, 17, 1)
      put(E(2.5 * tf), 0, GY + 1, 26, 1)
      put(E(2.5 * tf), 2, GY - 9, 5, 2)
    end

    -- fine / dense, kickless: a night patrol car winds slowly up the ramp, its
    -- headlights feeling ahead along each flight
    if not cls and kl > 0.05 and fp then
      local u = (T * 0.07) % 1
      local x, y, dir = ramp_at(u)
      local v = kl * math.min(1, u * 8, (1 - u) * 8)
      put(1.6 * v + 0.6, dir > 0 and x - 7 or x + 1, y - 4, 7, 2)
      K.put_sub(math.min(12, 2 + 8 * v), x, y - 4, 1, 1)
      K.put_sub(E(4 * v), x + dir * 3, y - 4.5, 6, 1)
      K.put_sub(E(2.2 * v), (dir > 0 and x + 2 or x - 14), y - 1, 12, 1)
    end
    -- dense: bay lines on every floor, an exit sign by the stairs on each deck
    -- (the pump breathes them), a drip of oil under each parked car
    if dense and not cls then
      for f = 1, 4 do
        local y = FLOORS[f]
        for x = X0 + 6, X1 - 4, 11 do put(1.4, x, y - 2, 1, 2) end
      end
      for d = 1, 3 do put(3 + E(1.6 * pf), X1 - 4, SLAB[d] + 4, 3, 1) end
      for i = 1, #CARS do
        local c = CARS[i]
        put(1, c[2] + 3, FLOORS[c[1]], 6, 1)
      end
    end
    -- dense: a moth at the failing tube and a slow drip off the roof edge
    if dense and fp then
      local ph = T * 2.4
      K.put_sub(2, FAIL_X + 3 + math.cos(ph) * 4, SLAB[FAIL_D] + 4 + math.sin(ph * 1.3) * 2, 1, 1)
      local u = (T * 0.4) % 1
      K.put_sub(2.2 * (1 - u), X1 + 1, SLAB[1] + 2 + u * (GY - SLAB[1] - 4), 1, 1)
    end
    -- the street: far cars pass slowly along it, whatever the music
    for i = 1, 2 do
      local x = (T * (5 + i * 2.5) + i * 70) % 170 - 20
      K.put_sub(2.2, x, GY + 4 + i, 3, 1)
      K.put_sub(1.2, x - 6, GY + 4 + i, 2, 1)
    end
    -- the energy wakes a far beacon on the town's skyline
    if e > 0.05 then put(1 + 2.5 * e, 124, 3, 1, 1) end
  end

  M.init()
  return M
end
