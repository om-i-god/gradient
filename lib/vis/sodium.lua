-- sodium: a street at night, looking down it. a road narrows to a vanishing
-- point under a hazy sodium sky, rooflines running in on both sides with a
-- few lit windows, and street lamps on alternating sides, each with an arm,
-- a head and a pool of light on the tarmac, drifting slowly towards you as
-- if on a walk (faster with the energy). the hats dip a lamp for an instant
-- (a flicker), ticks make a lamp buzz (a jitter of sparks and moths around
-- the head), the pump makes the tarmac breathe, and a stab flares the four
-- nearest lamps. kick thumps the glow at the vanishing point, clap sends a
-- car's headlights down the road, perc lights a window, bass lifts the
-- centre line, arps set cat's-eyes in the kerb (note = distance), the pad
-- hangs in the sky as haze with a soft light at each note. mids lift the
-- lamps, highs glitter on the wet tarmac, lows the pools, the level the sky
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local VX, VY = 64, 25                  -- the vanishing point
  local GH = 38                          -- ground depth at s = 1 (y = VY + GH)
  local SP = 1.3                         -- z between lamps (alternating sides)
  local cum = 0                          -- travelled z

  local function scale(z) return 1 / (1 + z * 0.3) end

  local flick, fi = {}, 0                -- hat dips: lamp id, start
  for i = 1, 6 do flick[i] = {m = -1, t = -99} end
  local buzz, bzi = {}, 0                -- tick buzz: lamp id, start, kind
  for i = 1, 5 do buzz[i] = {m = -1, t = -99, k = 1} end
  local flare = {m = 0, t = -99}         -- the stabs' four lamps
  local cars = {}
  for i = 1, 2 do cars[i] = {t = -99, side = 0} end
  local ci = 0
  local studs = {}
  for i = 1, 8 do studs[i] = {t = -99, z = 3, side = 1} end
  local sti = 0
  local wins = {}
  for i = 1, 6 do wins[i] = {t = -99, side = 1, z = 4} end
  local wi = 0
  local kick_t, pump_t, bass_t = -99, -99, -99
  local hats_n, tick_n, perc_n, arp_n = 0, 0, 0, 0
  local pad_notes = {}
  local pdz = 0
  local nearest = 0

  -- the fades follow the trails setting; at fine it acts at half strength and never moves them by more than 15% or 10%
  local function TR() return K.detail ~= "classic" and math.min(1.1, math.max(0.85, K.trail ^ 0.5)) or K.trail end
  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    return v < 0.03 and 0 or v
  end

  -- the lamp ids on screen: from the first one ahead of us
  local function first_id() return math.ceil((cum - 0.2) / SP) end

  function M.init()
    cum = 0
    for i = 1, 6 do flick[i].t = -99 end
    for i = 1, 5 do buzz[i].t = -99 end
    flare.t = -99
    for i = 1, 2 do cars[i].t = -99 end
    for i = 1, 8 do studs[i].t = -99 end
    for i = 1, 6 do wins[i].t = -99 end
    kick_t, pump_t, bass_t = -99, -99, -99
    hats_n, tick_n, perc_n, arp_n = 0, 0, 0, 0
    pad_notes = {}
    pdz = 0
  end
  M.clear = M.init

  function M.kick() kick_t = K.NOW end
  function M.pump() pump_t = K.NOW end
  function M.hat()
    hats_n = hats_n + 1
    fi = fi % #flick + 1
    flick[fi].m = first_id() + (hats_n * 3) % 5
    flick[fi].t = K.NOW
  end
  function M.clap()
    ci = ci % #cars + 1
    cars[ci].t = K.NOW
    cars[ci].side = (math.floor(K.NOW * 5) % 2 == 0) and -1 or 1
  end
  function M.perc(voice, note)
    perc_n = perc_n + 1
    voice = clamp(math.floor(K.num(voice, 1)), 1, 4)
    wi = wi % #wins + 1
    local w = wins[wi]
    w.t, w.side, w.z = K.NOW, ((voice + perc_n) % 2 == 0) and -1 or 1, 1.5 + ((voice * 3 + perc_n * 2) % 7) * 1.1
  end
  function M.tick(kind)
    kind = clamp(math.floor(K.num(kind, 1)), 1, 4)
    tick_n = tick_n + 1
    bzi = bzi % #buzz + 1
    buzz[bzi].m = first_id() + (kind * 2 + tick_n * 3) % (K.detail == "classic" and 5 or 3)   -- fine: a nearer lamp, so it reads
    buzz[bzi].t = K.NOW
    buzz[bzi].k = kind
  end
  function M.stab(notes)
    flare.m = first_id()
    flare.t = K.NOW
  end
  function M.bass(note) bass_t = K.NOW end
  function M.arp(lane, note, step)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    arp_n = arp_n + 1
    sti = sti % #studs + 1
    local s = studs[sti]
    s.t = K.NOW
    s.z = 0.4 + clamp((K.num(note, 72) - 48) / 48, 0, 1) * 7 + (arp_n % 3) * 0.7 + (K.num(step, 1) % 2) * 0.4
    s.side = (lane % 2 == 0) and -1 or 1
  end
  function M.pad(notes)
    pad_notes = {}
    if type(notes) == "table" then
      for i = 1, #notes do pad_notes[i] = K.num(notes[i], 50) end
    end
  end
  function M.bar() end

  local function flick_of(m)
    for i = 1, #flick do
      if flick[i].m == m then return fade(flick[i].t, 0.2) end
    end
    return 0
  end

  -- one lamp at depth z on side sd (-1 left, 1 right); lm = brightness
  local function lamp(z, sd, lm)
    local s = scale(z)
    local g = VY + GH * s
    local bx = VX + sd * 54 * s
    local top = g - 50 * s
    local hx = VX + sd * 36 * s
    if K.detail ~= "classic" then
      -- the lamps drift towards us a fraction of a pixel a frame
      K.line_sub(1 + 0.6 * s, bx, g, bx, top)
      K.line_sub(1 + 0.6 * s, bx, top, hx, top)
    else
      line(1 + 0.6 * s, bx, g, bx, top)
      line(1 + 0.6 * s, bx, top, hx, top)
    end
    if lm >= 0.6 then
      -- the head with its glare, and the pool of light on the tarmac
      local hw = math.max(2, math.floor(12 * s + 0.5))
      local hh = math.max(1, math.floor(3 * s + 0.5))
      put(math.min(11, lm * 1.4), hx - hw / 2, top, hw, hh)
      if lm > 1.5 then
        put(lm * 0.6, hx - hw, top - 1, hw * 2, 1)
        put(lm * 0.5, hx - hw * 0.6, top + hh, hw * 1.2, 1)
        if s > 0.3 then put(lm * 0.3, hx - hw * 1.6, top - 2, hw * 3.2, 1) end
      end
      local pw = math.max(3, math.floor(40 * s * (0.8 + A[K.LO] * 0.6)))
      local py = math.floor(g)
      local pl = lm * 0.55
      put(pl, hx - pw * 0.15, py - 1, pw * 0.3, 1)
      put(pl, hx - pw * 0.3, py, pw * 0.6, 1)
      put(pl * 0.75, hx - pw * 0.42, py + 1, pw * 0.84, 1)
      if s > 0.25 then put(pl * 0.5, hx - pw / 2, py + 3, pw, 1); put(pl * 0.35, hx - pw * 0.4, py + 5, pw * 0.8, 1) end
    end
  end

  function M.draw(S)
    local T, DT, NOW, e = K.T, K.DT, K.NOW, K.energy
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    local fine, dense, RT = K.detail ~= "classic", K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.4 end      -- eased above 1: the lit bound is tight here
    local fp = fine and K.playing                   -- time-driven fine detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RT, 13) or l end
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local kk, pf, bt = fade(kick_t, 0.3), fade(pump_t, 0.3), fade(bass_t, 0.3)
    local fl = fade(flare.t, 0.35)

    cum = cum + (0.12 + 0.5 * e) * (1 - 0.6 * K.kickless) * K.DTS
    local m0 = first_id()

    -- the sky: sodium haze that thickens toward the horizon
    for y = 3, VY do
      local v = 0.2 + (y / VY) * (0.6 + 1.0 * amp)
      if y % 4 == 1 and v > 0.7 then K.dashes(v, y, 3, 7, y * 3 + T * 1.5, 0, 128) end
    end
    if dense and fp then      -- a few stars through the haze
      for i = 1, 16 do
        K.put_sub(0.4 + 1.4 * math.max(0, math.sin(T * (0.5 + 0.07 * i) + i * 1.9)), 4 + K.hash(i, 31) * 120, 2 + K.hash(i, 32) * 10, 1, 1)
      end
    end
    if pdz > 0.03 then
      K.haze(0, 2, 128, VY - 2, pdz * 0.7, 2.2 * pdz + 0.6, T * 4)
      for i = 1, #pad_notes do
        local x = K.px(pad_notes[i])
        put(4.5 * pdz, x - 3, 4, 7, 2); put(3 * pdz, x - 5, 6, 11, 1)
      end
    end

    -- the glow at the vanishing point, thumped by the kick
    local gl = 2 + (fine and 6.4 or 4) * kk
    put(gl, VX - 2, VY - 1, 5, 2)
    put(gl * 0.5, VX - 6 - 4 * kk, VY, 13 + 8 * kk, 1)
    if kk > 0.03 then
      put(2.5 * kk, VX - 14, VY + 1, 29, 1); put(2 * kk, VX - 10, VY - 2, 21, 1)
      for r = 0, 5 do put(3.2 * kk * (1 - r / 7), VX - 20 - r * 3, VY + 2 + r * 2, 41 + r * 6, 1) end
      put(2 * kk, VX - 30, VY - 4, 61, 2)
      if fine then put(E(2.6 * kk), VX - 44, VY, 89, 1); put(E(3.4 * kk), VX - 8, VY - 3, 17, 4); put(E(2.8 * kk), VX - 26, VY + 3, 53, 1) end
    end

    -- rooflines running in, with a few windows on the facades
    line(1.3, 0, 8, VX - 6, VY - 2); line(1.3, 128, 8, VX + 6, VY - 2)
    for k = 0, 6 do
      local z = k * 1.5 + (1 - ((cum / 1.5) % 1)) * 1.5
      local s = scale(z)
      for sd = -1, 1, 2 do
        local id = math.floor((cum + z) / 1.5) * 2 + (sd > 0 and 1 or 0)
        if K.hash(id, 9) < 0.55 then
          local wx = VX + sd * (50 * s + 4 * s)
          local wy = VY - 4 * s - 14 * s * K.hash(id, 4)
          if fine then K.put_sub(1.8 + mid * 1.5, wx - 1, wy, math.max(1, math.floor(3 * s + 1)), math.max(1, math.floor(3 * s)))
          else put(1.8 + mid * 1.5, wx - 1, wy, math.max(1, math.floor(3 * s + 1)), math.max(1, math.floor(3 * s))) end
        end
      end
    end

    -- the road: edges, kerbs, the centre line in dashes, breathing with the pump
    local rl = 1.2 + (fine and 4.6 or 3) * pf
    line(rl, VX - 2, VY + 1, -20, 63); line(rl, VX + 2, VY + 1, 148, 63)
    line(0.8 + (fine and 2.6 or 1.5) * pf, VX - 1, VY + 1, 20, 63); line(0.8 + 1.5 * pf, VX + 1, VY + 1, 108, 63)
    if pf > 0.04 then
      for y = VY + 2, 62, 2 do
        local s = (y - VY) / GH
        local hw = (50 * s)
        if y % 3 == 2 then put((fine and 4.2 or 3) * pf * (0.4 + s * 0.6), VX - hw, y, hw * 2, 1) end
      end
    end
    local cl = 1.6 + (fine and 7 or 5.5) * bt + lo * 2
    for k = 0, 8 do
      local z = k * 1.4 + (1 - ((cum / 1.4) % 1)) * 1.4
      local s, s2 = scale(z), scale(z + 0.7)
      local y1, y2 = VY + GH * s, VY + GH * s2
      if y2 < 63 then
        put(cl * math.min(1, s * 2.5), VX - (bt > 0.05 and 1 or 0), y2, 1 + (bt > 0.05 and 2 or 0) + (s > 0.5 and 1 or 0), math.max(1, math.floor(y1 - y2)))
      end
    end

    if bt > 0.04 then
      for k = 0, 6 do
        local s = scale(k * 1.5)
        put((fine and 6.4 or 5) * bt * (0.4 + s), VX - 40 * s - 4, VY + GH * s, 80 * s + 8, 1)
      end
    end

    -- cat's-eyes in the kerb: the arps
    for i = 1, #studs do
      local st = studs[i]
      local f = fade(st.t, 0.45)
      if f > 0 then
        local s = scale(st.z)
        local y = VY + GH * s
        local x = VX + st.side * 24 * s
        put((fine and 7.5 or 6) * f, x - 1, y - 1, 3, 3)
        put((fine and 5 or 4) * f, x - 4, y - 2, 9, 5)
        put(3 * f, x - 9, y, 19, 1)
        put(2.5 * f, x - 6, y + 3, 13, 1)
        put(3.2 * f, VX - 46 * s, y, 92 * s, 1)
        put(2 * f, VX - 40 * s, y + 1, 80 * s, 1)
      end
    end

    -- lit windows: perc
    for i = 1, #wins do
      local w = wins[i]
      local f = fade(w.t, 0.4)
      if f > 0 then
        local s = scale(w.z)
        local wx = VX + w.side * 40 * s + w.side * 12
        local wy = VY - 9 * s - 3
        put(6.5 * f, wx - 1, wy - 1, 4, 4)
        put(4 * f, wx - 4, wy - 3, 10, 8)
        put(2.5 * f, wx - 7, wy + 6, 16, 1)
        if fine then put(E(4 * f), wx - 2, wy - 2, 6, 6); put(E(2.6 * f), wx - 9, wy + 7, 20, 1) end
      end
    end

    -- the lamps, far to near so the near ones draw over
    for j = 7, 0, -1 do
      local m = m0 + j
      local z = m * SP - cum
      if z >= -0.2 then
        local sd = (m % 2 == 0) and -1 or 1
        local s = scale(z)
        local lm = (4.6 + (fine and 2.0 or 1.6) * mid + (fine and 1.6 or 1.2) * amp) * (0.5 + 0.5 * s)
        local dip = flick_of(m)
        if dip > 0 then lm = lm * (1 - 0.95 * dip) + (fine and 8 or 5) * (1 - dip) * dip end
        local rel = m - flare.m
        if fl > 0 and rel >= 0 and rel < 4 then lm = lm + (fine and 5.6 or 4.5) * fl * (1 - rel * 0.12) end
        lamp(z, sd, lm)
        if dip > 0.05 then
          local hx = VX + sd * 36 * s
          local top = VY + GH * s - 50 * s
          put(5 * (1 - dip) * dip * 2, hx - 3, top + 2, 7, 1)
          put(3 * dip, hx - 1, VY + GH * s + 1, 3, 1)
          if fine then
            -- the light drops on the pole and the pool flickers with it
            line(E(4.5 * dip * (1 - dip) * 3), hx, top + 1, hx, VY + GH * s)
            put(E(3 * dip), hx - 5 * s - 2, VY + GH * s - 1, 10 * s + 5, 2)
          end
        end
        if fl > 0 and rel >= 0 and rel < 4 then
          local hx = VX + sd * 36 * s
          local top = VY + GH * s - 50 * s
          local r = math.max(2, math.floor(10 * s))
          put(3 * fl, hx - r, top + 2, r * 2 + 1, 1); put(2 * fl, hx - r - 2, top + 4, r * 2 + 5, 1)
          put(2 * fl, hx - r * 1.4, VY + GH * s - 1, r * 2.8, 2)
        end
        -- buzz: sparks and moths around a humming lamp
        for i = 1, #buzz do
          local b = buzz[i]
          if b.m == m then
            local bf = fade(b.t, 0.3)
            if bf > 0 then
              local hx = VX + sd * 36 * s
              local top = VY + GH * s - 50 * s
              local r = math.max(2, math.floor(9 * s)) + 2
              for q = 0, (fine and 5 or 3) do
                local a = (T * 14 + q * (fine and 1.05 or 1.57) + b.k)
                put(E(7 * bf), hx + math.cos(a) * r, top + 2 + math.sin(a) * r * 0.7, 1, 1)
              end
              if fine then line(E(4 * bf), VX + sd * 54 * s, top + 1, VX + sd * 54 * s, VY + GH * s) end
              put(4 * bf, hx - 1, top + 1, 3, math.max(2, math.floor(14 * s)))
              put(3.5 * bf, hx - r, top + 2, r * 2 + 1, 2)
              put(2.5 * bf, hx - r - 3, top + 4, r * 2 + 7, 2)
            end
          end
        end
      end
    end

    -- a car's headlights coming down the road: the clap
    for i = 1, #cars do
      local c = cars[i]
      local a = NOW - c.t
      if a < 0.6 then
        local u = a / 0.6
        local z = 12 * (1 - u) ^ 1.5
        local s = scale(z)
        local y = VY + GH * s
        local sp = 6 * s + 1
        local l = 6 * (1 - u * 0.5)
        local cx = VX + c.side * 14 * s
        put(l, cx - sp, y - 2 * s - 1, math.max(1, 2 + 3 * s), math.max(1, 2 * s + 1))
        put(l, cx + sp, y - 2 * s - 1, math.max(1, 2 + 3 * s), math.max(1, 2 * s + 1))
        put(l * 0.4, cx - sp - 2, y, sp * 2 + 6, 1)
        put(l * 0.3, cx - sp - 5, y + 1 + s * 2, sp * 2 + 12, 1)
        if fine then
          -- the beams spread down the road, the glare round each lamp
          line(E(l * 0.55), cx - sp, y, VX + c.side * 4 + (cx - VX) * 0.3 - 6, VY + 2)
          line(E(l * 0.55), cx + sp + 1, y, VX + c.side * 4 + (cx - VX) * 0.3 + 6, VY + 2)
          put(E(l * 0.6), cx - sp - 1, y - 2 * s - 2, math.max(3, 4 + 3 * s), 3)
          put(E(l * 0.6), cx + sp - 1, y - 2 * s - 2, math.max(3, 4 + 3 * s), 3)
        end
      end
    end

    -- dense: the lamps' reflections shimmer in the wet road
    if dense and fp then
      for j = 5, 0, -1 do
        local m = m0 + j
        local z = m * SP - cum
        if z >= 0.2 then
          local s = scale(z)
          local hx = VX + ((m % 2 == 0) and -1 or 1) * 36 * s
          local py = VY + GH * s
          for r = 1, 4 do
            K.put_sub(1.4 * (1 - r / 5) * (0.6 + 0.4 * math.sin(T * 3 + r * 1.7 + m)), hx + math.sin(T * 1.3 + r + m) * 1.5 * s, py + 4 + r * 2, 2, 1)
          end
        end
      end
    end

    if hi > 0.04 then
      for y = VY + 6, 62, 4 do K.dashes(hi * (fine and 4.6 or 3.5), y, 2, 6, y * 7 + T * 6, VX - (y - VY) * 1.3, VX + (y - VY) * 1.3) end
    end
    -- the highs glitter on the wet tarmac
    K.grain(function(u, v) return VX + (u - 0.5) * (30 + 90 * v), VY + 2 + v * 36 end, hi * (fine and 80 or 60), 7)
  end

  M.init()
  return M
end
