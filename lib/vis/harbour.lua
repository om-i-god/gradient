-- harbour: a container berth at night. two quay cranes lean their booms
-- out over a moored ship (hull, stacked boxes, a bridge with cabin windows,
-- a funnel) on dark water, a low string of far-shore lights behind. every
-- light has a long rippled reflection in the water, which sways with the
-- bass and the low band. the hats blink the crane lights (one crane after
-- another), the pad lies on the water as slow bands at its notes' columns.
-- kick thumps the hull's waterline, the pump lifts the dock's glow, clap
-- throws a searchlight pool on the water, perc lights a porthole, ticks
-- are welding sparks at the crane feet, stabs fill the bridge windows (the
-- notes as bars), the bass sends a ring across the water, arps blink buoys
-- (one lane each). mids lift the portholes, highs glint on the water, lows
-- widen the ripple, the level lights the quay lamps
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local WL = 38                          -- the waterline
  local N_SRC = 0

  -- fixed lights: x, y, kind (1 crane, 2 porthole, 3 quay lamp, 4 far shore)
  local src = {}
  local function add(x, y, kind, grp) N_SRC = N_SRC + 1; src[N_SRC] = {x = x, y = y, k = kind, g = grp} end
  -- crane A (left): top light, boom tip; crane B (right)
  add(18, 8, 1, 1); add(58, 11, 1, 1); add(112, 8, 1, 2); add(76, 11, 1, 2)
  add(14, 21, 1, 1); add(116, 21, 1, 2)
  for i = 0, 7 do add(34 + i * 7, 35, 2, 0) end      -- portholes along the hull
  for i = 0, 3 do add(78 + i * 4, 27, 2, 0) end      -- bridge windows (stab)
  add(6, 30, 3, 0); add(26, 30, 3, 0); add(104, 30, 3, 0); add(124, 30, 3, 0)
  for i = 1, 14 do add(2 + math.floor(i * 9 + K.hash(i, 3) * 6), 33, 4, 0) end

  local blink = {-99, -99}                   -- crane groups' blink, per group
  local hats_n, tick_n, perc_n, bass_n = 0, 0, 0, 0
  local kick_t, pump_t, clap_t = -99, -99, -99
  local clap_x = 64
  local port = {}                        -- lit portholes: index -> start
  local bridge = {0, 0, 0, 0}            -- bridge windows' height 0..1 and start
  local bridge_t = -99
  local buoys = {}
  for i = 1, 8 do buoys[i] = {t = -99, n = 0, x = 64, lane = 1} end
  local bi = 0
  local rings = {}
  for i = 1, 5 do rings[i] = {t = -99, x = 64} end
  local ri = 0
  local sparks = {}
  for i = 1, 6 do sparks[i] = {t = -99, x = 20, y = 33} end
  local si = 0
  local pad_notes = {}
  local pdz = 0

  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / tau)
    return v < 0.03 and 0 or v
  end

  function M.init()
    blink = {-99, -99}
    hats_n, tick_n, perc_n, bass_n = 0, 0, 0, 0
    kick_t, pump_t, clap_t = -99, -99, -99
    port = {}
    bridge = {0, 0, 0, 0}; bridge_t = -99
    for i = 1, 8 do buoys[i].t = -99 end
    for i = 1, 5 do rings[i].t = -99 end
    for i = 1, 6 do sparks[i].t = -99 end
    pad_notes = {}
    pdz = 0
  end
  M.clear = M.init

  function M.kick() kick_t = K.NOW end
  function M.pump() pump_t = K.NOW end
  function M.hat()
    hats_n = hats_n + 1
    local g = hats_n % 2 + 1
    blink[g] = K.NOW
  end
  function M.clap()
    clap_t = K.NOW
    clap_x = 20 + (math.floor(K.NOW * 7) % 5) * 22
  end
  function M.perc(voice, note)
    perc_n = perc_n + 1
    voice = clamp(math.floor(K.num(voice, 1)), 1, 4)
    port[7 + ((voice * 3 + perc_n * 2) % 8)] = K.NOW
  end
  function M.tick(kind)
    kind = clamp(math.floor(K.num(kind, 1)), 1, 4)
    tick_n = tick_n + 1
    si = si % #sparks + 1
    local s = sparks[si]
    s.t = K.NOW
    s.x = (tick_n % 2 == 0) and (13 + kind * 2) or (110 + kind * 2)
  end
  function M.stab(notes)
    bridge_t = K.NOW
    for i = 1, 4 do
      bridge[i] = clamp((K.num(K.chord[i], 55) - 40) / 36, 0.2, 1)
    end
  end
  function M.bass(note)
    bass_n = bass_n + 1
    ri = ri % #rings + 1
    rings[ri].t = K.NOW
    rings[ri].x = 20 + ((K.num(note, 36) % 12) * 7 + bass_n * 23) % 90
  end
  function M.arp(lane, note, step)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    bi = bi % #buoys + 1
    local b = buoys[bi]
    b.t, b.lane, b.x = K.NOW, lane, K.px(note)
    b.n = clamp((K.num(note, 72) - 48) / 48, 0, 1)
  end
  function M.pad(notes)
    pad_notes = {}
    if type(notes) == "table" then
      for i = 1, #notes do pad_notes[i] = K.num(notes[i], 50) end
    end
  end
  function M.bar() end

  -- a light's reflection: a rippled streak under the waterline
  local function refl(l, x, y, sway, len)
    local d = WL - y
    if d < 0 then d = 0 end
    local ym = WL + 2 + d * 0.75
    for r = 0, len do
      local yy = ym + r * 2
      if yy < 63 then
        local off = math.sin(yy * 0.9 + K.T * 1.7 + x * 0.3) * sway
        put(l * (1 - r / (len + 1.5)), x + off - 0.5, yy, 2, 1)
      end
    end
  end

  function M.draw(S)
    local T, DT, NOW, e = K.T, K.DT, K.NOW, K.energy
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local kk, pf, cf = fade(kick_t, 0.3), fade(pump_t, 0.3), fade(clap_t, 0.35)
    local bf = fade(bridge_t, 0.35)
    local sway = 0.5 + 3.5 * lo + 1.5 * K.env.bass

    -- the dock's glow on the horizon: a few dashed rows, lifted by the pump
    for y = 28, 33, 2 do
      K.dashes(0.8 + 3.5 * pf * (y - 26) / 7, y, 3, 8, y * 5 + T * 2, 0, 128)
      if pf > 0.05 then K.dashes(3.2 * pf, y + 1, 5, 7, y * 3 - T * 3, 0, 128) end
    end
    if pf > 0.05 then put(3 * pf, 28, 38, 72, 1); put(2 * pf, 0, 37, 128, 1) end

    -- the quay, behind the ship at both ends
    put(1.6, 0, 34, 30, 1); put(1.6, 100, 34, 28, 1)
    K.dashes(1, 36, 4, 8, 0, 0, 28); K.dashes(1, 36, 4, 8, 3, 100, 128)

    -- the cranes: legs, cross beams, booms with stays
    for c = 1, 2 do
      local cx = c == 1 and 18 or 112
      local dir = c == 1 and 1 or -1
      local tipx = c == 1 and 58 or 76
      line(2, cx - 4, 34, cx - 4, 12); line(2, cx + 4, 34, cx + 4, 12)
      line(1.5, cx - 4, 12, cx + 4, 12); line(1.5, cx - 4, 22, cx + 4, 22)
      line(1.2, cx - 4, 34, cx + 4, 22); line(1.2, cx + 4, 34, cx - 4, 22)
      line(2, cx - 4, 12, tipx, 11); line(2, cx, 8, tipx, 11)
      line(1.3, cx, 8, cx + dir * 14, 11)
      line(1.5, cx, 8, cx, 12)
      -- the hoist cable dropping from the boom
      line(1.2, tipx - dir * 8, 11, tipx - dir * 8, 24)
    end

    -- the ship: hull, boxes, bridge, funnel
    local hl = 2 + 3.5 * kk
    line(hl, 28, 31, 100, 31)
    line(hl * 0.8, 28, 31, 34, 38); line(hl * 0.8, 100, 31, 96, 38)
    line(hl, 34, 38, 96, 38)
    for x = 30, 68, 8 do
      put(1.4, x, 24, 7, 1); put(1.4, x, 30, 7, 1); put(1.4, x, 24, 1, 7); put(1.4, x + 6, 24, 1, 7)
      if x < 54 then put(1.4, x + 1, 18, 6, 1); put(1.4, x + 1, 18, 1, 6); put(1.4, x + 6, 18, 1, 6) end
    end
    put(1.6, 76, 22, 20, 1); put(1.6, 76, 22, 1, 9); put(1.6, 95, 22, 1, 9)
    put(1.6, 84, 15, 1, 7); put(1.6, 88, 15, 1, 7)
    line(1.8, 83, 15, 89, 15)
    put(0.9 + 5 * kk, 28, 38, 72, 1)
    if kk > 0.03 then
      put(2.5 * kk, 30, 32, 66, 6)
      put(3 * kk, 24, 39, 80, 1); put(2 * kk, 20, 40, 88, 1)
    end

    -- lights and their reflections
    local lamp = 2 + 2.5 * amp
    for i = 1, N_SRC do
      local s = src[i]
      local l, len
      if s.k == 1 then
        local b = fade(blink[s.g], 0.28)
        l = 2.5 + 4.5 * b; len = 3 + math.floor(b * 3)
      elseif s.k == 2 then
        local p = port[i]
        local pv = p and fade(p, 0.4) or 0
        if i > 6 + 8 then
          -- bridge windows: stabs fill them from the bottom as bars
          local j = i - 14
          local h = bridge[j] * bf
          l = 1.5 + mid * 1.5
          if h > 0.05 then
            local hh = math.max(1, math.floor(h * 4 + 0.5))
            put(5.2 * bf + 1.5, s.x, s.y + 4 - hh, 3, hh)
          end
          put(l, s.x, s.y, 3, 4)
          if bf > 0.03 then put(3.5 * bf, 76, 22, 20, 9) end
          len = 2 + math.floor(bf * 2)
          l = l + 4 * bf
        else
          l = 1.6 + mid * 2.2 + 5.5 * pv
          if K.hash(i, 5) < 0.25 and pv < 0.05 then l = 0 end
          len = 2 + math.floor(pv * 2)
          if l > 0 then put(l, s.x, s.y, 2, 2) end
          if pv > 0.05 then put(4 * pv, s.x - 3, s.y - 3, 8, 8); put(3 * pv, s.x - 6, s.y + 2, 14, 1) end
        end
      elseif s.k == 3 then
        l = lamp; len = 3
        put(l, s.x - 1, s.y, 3, 1); line(1.2 + amp * 2, s.x, s.y + 1, s.x, 34); put(amp * 4, s.x - 4, s.y + 2, 9, 1); put(amp * 3, s.x - 3, s.y + 3, 7, 3)
      else
        l = 1.5; len = 1
        put(l, s.x, s.y, 1, 1)
      end
      if s.k == 1 then put(l, s.x - 1, s.y, 3, 2) end
      if l and l > 0.6 then refl(l * 0.7, s.x, s.y, sway, len) end
    end

    -- welding sparks at the crane feet
    for i = 1, #sparks do
      local sp = sparks[i]
      local a = NOW - sp.t
      if a < 0.4 then
        local l = 7 * (1 - a / 0.4)
        put(l * 0.6, sp.x - 7, 34 - a * 4, 14, 1)
        for q = -3, 3 do line(l * 0.7, sp.x, 33, sp.x + q * 3, 33 - 9 * (1 - math.abs(q) / 5)) end
        put(l, sp.x, 32 - a * 10, 2, 2); put(l * 0.7, sp.x - 3 - a * 14, 30 + a * 8, 1, 1)
        put(l * 0.7, sp.x + 3 + a * 14, 31 + a * 8, 1, 1)
        refl(l * 0.5, sp.x, 32, sway, 2)
      end
    end

    -- the water: wave lines that drift, wider apart as they come near
    for k = 0, 9 do
      local y = WL + 3 + k * k * 0.25 + k * 1.4
      if y < 63 then
        K.dashes(1 + (k % 2) * 0.5 + lo * 2 + hi * 3, math.floor(y), 5 + k, 14 + 2 * k,
          T * (4 + k) * (k % 2 == 0 and 1 or -1) + k * 17, 0, 128)
      end
    end

    -- the pad lies on the water: slow bands at its notes' columns
    if pdz > 0.03 then
      for i = 1, #pad_notes do
        local x = K.px(pad_notes[i])
        for r = 0, 5 do
          local w = 6 + r * 4 + math.floor(math.sin(T * 0.6 + i + r) * 4)
          put(pdz * (3.4 - r * 0.45), x - w / 2, 44 + r * 3, w, 1)
        end
      end
    end

    -- bass rings spread across the water
    for i = 1, #rings do
      local r = rings[i]
      local a = NOW - r.t
      if a < 0.9 then
        local u = a / 0.9
        local w = 6 + u * 50
        local y = 44 + u * 12
        local l = 6 * (1 - u)
        put(l, r.x - w / 2, y, w, 1)
        put(l * 0.5, r.x - w / 2 - 3, y + 1, w + 6, 1)
      end
    end

    -- the clap's searchlight pool
    if cf > 0.03 then
      for r = 0, 3 do
        local w = 30 - r * 6
        put(4.5 * cf, clap_x - w / 2, 42 + r * 2, w, 1)
      end
      put(3 * cf, clap_x - 1, 34, 2, 4)
    end

    -- buoys out on the water, one per lane
    for i = 1, 8 do
      local b = buoys[i]
      local f = fade(b.t, 0.5)
      local by = 46 + b.lane * 3 + math.floor(b.n * 3)
      if f > 0 then put(1.2 + 6 * f, b.x, by, 2, 2) end
      if f > 0.05 then put(2.5 * f, b.x - 3, by + 2, 8, 1); line(4 * f, b.x, by - 10, b.x, by); put(1.8 * f, b.x - 12, by + 4, 24, 1); refl(4 * f, b.x, by - 6, sway, 1) end
    end

    -- the highs glint on the water
    K.grain(function(u, v) return u * 124 + 2, 41 + v * 22 end, hi * 40, 7)
  end

  M.init()
  return M
end
