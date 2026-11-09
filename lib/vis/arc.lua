-- arc: the last sixty bars as a ridge at night, scrolling right to left.
-- each bar is two columns of land as high as the energy was, hatched in
-- light; where the kick was out the land is hollow, only its outline left
-- and still water in the dip. a light hangs over wherever the chord changed, a
-- road runs under the bars held over a pedal bass. the live edge is a lamp
-- on the newest land, pulsing with the kick; a throw leaves fading lamps
-- behind it at the echo time. behind it all a far range stands black
-- against the glow of the horizon, which swells with the stabs; arp notes
-- light windows on the slopes, the bass warms the ground, out_hi the stars.
-- the moon crosses the sky with the track (or the set's swell)
return function(K)
  local M = {}
  local put, line, A, clamp, follow = K.put, K.line, K.A, K.clamp, K.follow

  local GROUND = 54
  local X_NOW = 122                        -- the live edge
  local RISE = 30                          -- ridge height at full energy
  local TH8 = {0, 4, 2, 6, 1, 5, 3, 7}

  local bars = 0                          -- bars seen while on screen
  local lights = {}                       -- arp windows, placed in bars
  local glow, vb, lamp = 0, 0, 0
  local top, hollow, bi = {}, {}, {}      -- per 2-px column, this frame

  -- the far range: fixed, black against the horizon glow
  local far = K.profile(function(x)
    return 38 + 4 * math.sin(x * 0.045 + 1.2) + 2.5 * math.sin(x * 0.13 + 0.4) + 1.2 * math.sin(x * 0.37)
  end)

  local STARS = {}
  for s = 1, 22 do STARS[s] = {x = math.floor(K.hash(s, 41) * 126) + 1, y = 1 + math.floor(K.hash(s, 42) ^ 1.4 * 30), ph = K.hash(s, 43) * 6.3} end

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own
  local hit, percs = {}, {}
  local pdz = 0                           -- the pad, eased in
  local function mark(k) hit[k] = K.NOW end
  local function fade(k, tau)
    local t = hit[k]
    if not t then return 0 end
    local v = math.exp(-(K.NOW - t) / tau)
    if v < 0.02 then hit[k] = nil; return 0 end
    return v
  end
  function M.kick() mark("kick") end
  function M.pump() mark("pump") end
  function M.hat() mark("hat") end
  function M.clap() mark("clap") end
  function M.tick(kind) mark("tick"); hit.tk = clamp(math.floor(K.num(kind, 1)), 0, 99) % 4 end
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, v = clamp(math.floor(K.num(voice, 1)), 1, 4) - 1,
      c = 4 + (math.floor(K.num(note, 60)) % 12) * 4}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    bars, lights = 0, {}
    glow, vb, lamp = 0, 0, 0
    hit, percs, pdz = {}, {}, 0
  end
  M.clear = function() lights = {} end

  function M.bar() bars = bars + 1 end

  function M.arp(lane, note)
    if #lights >= 10 then table.remove(lights, 1) end
    lights[#lights + 1] = {p = bars + K.bar_ph - K.rnd() * 10, d = 2 + (lane or 1) * 2 + K.rnd() * 2, t0 = K.T, lane = lane}
  end

  -- a hist entry's land top
  local function land(h) return GROUND - 3 - h.e * RISE end

  function M.draw(S)
    local T, DT, env = K.T, K.DT, K.env
    local hist, n = K.hist, #K.hist
    local ph = K.playing and K.bar_ph or 0
    local hi = A[K.HI]
    pdz = follow(pdz, env.pad, 0.25, DT)
    local kk, pf, hh, cl, tk = fade("kick", 0.25), fade("pump", 0.3), fade("hat", 0.25), fade("clap", 0.3), fade("tick", 0.4)
    local pd, mid, amp = pdz, A[K.MID], A[K.AMP]
    -- the land, per column: age in bars back from the live edge
    for c = 0, 63 do
      local x = c * 2 + 1
      local a = (X_NOW - x) / 2 - ph
      local t, ho, b
      if a < -0.5 then t, ho, b = 99, false, nil
      else
        local ia = math.floor(a + 0.5)
        local i = n - ia
        local f = a + 0.5 - ia
        local h0 = hist[i]
        if h0 then
          local t0 = land(h0)
          local h1 = hist[i - 1]
          local t1 = h1 and land(h1) or GROUND - 2
          -- slopes between bars, and a roll to the land carried with it
          t = t0 + (t1 - t0) * K.ease(clamp((f - 0.35) / 0.65, 0, 1))
          local p = bars - a
          t = t - (0.3 + 2.2 * (GROUND - 3 - t) / RISE) * (0.6 + 0.6 * math.sin(p * 0.7) + 0.4 * math.sin(p * 2.3 + 1))
          ho, b = h0.kl, i
        else
          t, ho = GROUND - 2 + 0.6 * math.sin((bars - a) * 1.7), false
        end
      end
      top[c], hollow[c], bi[c] = t, ho, b
    end
    -- the horizon glow behind the far range, swelling with the stabs
    local st = env.stab * (K.gain(S, "chords") > 0 and 1 or 0.6)
    glow = follow(glow, st, st > glow and 0.15 or 1, DT)
    -- per column: a glow band over the far range, hidden behind the ridge
    local gl = (1.4 + glow * 2.2 + K.energy * 0.8) * (1 + 0.3 * amp) * (1 - 0.4 * pf) + 1.2 * pd
    for k = 1, 5 do
      local l = gl * math.exp(-(k - 1) / (1.6 + glow * 1.5))
      if l >= 0.75 then
        local run, ry
        for c = 0, 64 do
          local y = c < 64 and math.floor(far[c]) - k
          if y and top[c] <= y then y = nil end
          if y ~= ry then
            if ry then put(l, run * 2, ry, (c - run) * 2, 1) end
            run, ry = c, y
          end
        end
      end
    end
    -- thin cloud drifting across
    K.dashes(1 + 4 * pf, 9, 9, 23, T * 3.1, 0, 128)
    K.dashes(1 + 4 * pf, 11, 14, 31, T * 2.2 + 11, 0, 128)
    -- stars, brighter and quicker with out_hi
    for i, s in ipairs(STARS) do
      if s.y < math.min(far[s.x // 2], top[math.min(63, s.x // 2)]) - 3 then
        local tw = 0.5 + 0.5 * math.sin(T * (1.4 + K.hash(i, 44) * 1.4 + hi * 3) + s.ph)
        put(0.8 + tw * (1.6 + hi * 6) + hh * 5, s.x, s.y, 1, 1)
      end
    end
    -- the moon on its way across with the track
    local pr = clamp(K.num(S.progress, 0), 0, 1)
    local mx, my = 10 + pr * 108, 18 - math.sin(pr * math.pi) * 12
    for dy = -3, 3 do
      local hw = math.floor(math.sqrt(11 - dy * dy) + 0.5)
      put(4.5, mx - hw, my + dy, 2 * hw, 1)
    end
    -- a clap swells a halo round the moon
    if cl > 0.03 then
      for dy = -8, 8 do
        local hw = math.floor(math.sqrt(64 - dy * dy) + 0.5)
        put(5 * cl, mx - hw, my + dy, 2, 1); put(5 * cl, mx + hw - 2, my + dy, 2, 1)
      end
    end
    -- a tick draws a short streak across the sky
    if tk > 0.03 then
      local sx, sy = 14 + hit.tk * 26 + (1 - tk) * 22, 4 + (1 - tk) * 14
      line(6 * tk, sx, sy, sx - 14, sy - 6 * 0.6)
      line(3 * tk, sx - 14, sy - 3.6, sx - 24, sy - 6)
    end
    for dy = -5, 5, 2 do
      local hw = math.floor(math.sqrt(30 - dy * dy) + 0.5)
      if math.abs(dy) > 2 then put(1.2, mx - hw, my + dy, 2 * hw, 1)
      else put(1.2, mx - hw, my + dy, 2, 1); put(1.2, mx + hw - 2, my + dy, 2, 1) end
    end
    -- the ridge: hatched land under a rim, brighter the higher it stands;
    -- hollow where the kick was out
    local kick = env.kick
    local breathe = 1 - 0.15 * K.duck
    local ymin = GROUND
    for c = 0, 63 do if top[c] < ymin then ymin = math.floor(top[c]) end end
    -- the land's body: lit just under the crest, falling to a sparse hatch
    -- toward the ground; equal neighbours merged into one run per row
    for y = ymin + 1, GROUND - 1 do
      local run, rl = 0, 0
      for c = 0, 64 do
        local l = 0
        if c < 64 and not hollow[c] then
          local t = top[c]
          local d = y - math.floor(t)
          if d > 0 then
            local hgt = (GROUND - t) / RISE
            if d <= 2 then l = math.floor((1.6 + 2 * hgt) * breathe + 0.5)
            elseif d <= 8 then l = (y % 2 == 0) and math.floor(1 + 1.3 * hgt + 0.5) or 0
            elseif y % 6 == 0 then l = 1 end
          end
        end
        if l ~= rl then
          if rl > 0 then put(rl, run * 2, y, (c - run) * 2, 1) end
          run, rl = c, l
        end
      end
    end
    for c = 0, 63 do
      local t = top[c]
      if t < GROUND then
        local x = c * 2
        local near = math.exp(-(X_NOW - x) / 10)
        local rl = (3 + (GROUND - t) / RISE * 5 + kick * near * 5) * breathe
        if hollow[c] then
          put(rl * 0.4, x, t, 2, 1)
        else
          put(rl, x, t, 2, 1)
        end
      end
    end
    -- the hollows: water lying in the dips, drifting
    local c = 0
    while c < 64 do
      if hollow[c] then
        local c1 = c
        while c1 < 64 and hollow[c1] do c1 = c1 + 1 end
        for k = 1, 3 do
          K.dashes(2.2 - k * 0.4, GROUND - k * 2, 3, 7, T * (2 + k) + k * 3, c * 2, c1 * 2)
        end
        c = c1
      else c = c + 1 end
    end
    -- masts where the chord changed, a road under the pedal bars
    for cc = 0, 63 do
      local i = bi[cc]
      if i and (cc == 0 or bi[cc - 1] ~= i) then
        local h, hp = hist[i], hist[i - 1]
        local t = math.floor(top[cc])
        if hp and h.ch ~= hp.ch then
          put(3.5 + 1.5 * math.sin(T * 1.3 + i), cc * 2 + 1, t - 4, 1, 1)
        end
        if h.pedal then put(3.5 + vb * 2, cc * 2, GROUND + 2, 2, 1) end
      end
    end
    -- arp windows on the slopes, carried with the land
    for k = #lights, 1, -1 do
      local w = lights[k]
      local age = T - w.t0
      if age > 2.5 then table.remove(lights, k)
      else
        local x = X_NOW - 2 * (bars + ph - w.p)
        local cc = math.floor(x / 2)
        if cc >= 0 and cc < 64 and not hollow[cc] and top[cc] + w.d < GROUND - 1 then
          put((3 + 5 * K.lane_kick[w.lane or 1]) * (1 - age / 2.5), x, top[cc] + w.d, 1, 1)
        end
      end
    end
    -- hats glint along the rim
    if hh > 0.03 then
      for c = 1, 62, 2 do
        if top[c] < GROUND and not hollow[c] then put(6 * hh, c * 2, top[c] - 1, 2, 1) end
      end
      K.dashes(4 * hh, 9, 3, 7, -T * 30, 0, 128)
    end
    -- a perc lights a window on a slope, placed by its note and voice
    for i = #percs, 1, -1 do
      local p = percs[i]
      local f = math.exp(-(K.NOW - p.t) / 0.55)
      if f < 0.03 then table.remove(percs, i)
      else
        local cc = clamp(p.c + p.v, 0, 63)
        local x, y = cc * 2, math.min(top[cc], GROUND - 8) + 3 + p.v
        put(7 * f, x - 1, y - 1, 3, 3)
        put(4 * f, x - 4, y, 9, 1)
        put(4 * f, x, y - 4, 1, 9)
      end
    end
    -- the ground, warmed by the bass
    vb = follow(vb, math.max(env.bass, A[K.LO] * 0.7) * (K.gain(S, "bass") > 0 and 1 or 0.5), 0.06, DT)
    put(2 + vb * 3 + K.bar_pulse * 2, 0, GROUND, X_NOW + 2, 1)
    K.gradient(GROUND + 1, 61, function(y) return (0.4 + vb * 3 + A[K.LO] * 1.2) * math.exp(-(y - GROUND - 1) / 2.5) end)
    -- the live edge: a now-line and the lamp on the newest land
    local lt = top[X_NOW // 2 - 1] or GROUND - 2
    if lt > GROUND then lt = GROUND - 2 end
    for y = 2, math.floor(lt) - 3, 3 do put(1 + 5 * kk, X_NOW, y, 1, 1)
      if kk > 0.03 then put(3 * kk, X_NOW, y + 1, 1, 1) end end
    lamp = follow(lamp, math.max(kick * (1 - K.kickless), K.duck * 0.4), 0.03, DT)
    put(5 + lamp * 7, X_NOW - 1, lt - 2, 2, 2)
    -- the kick sends a ring out from the lamp
    if kk > 0.03 then
      local r = 2 + (1 - kk) * 18
      for k = 0, 23 do
        local a = k / 24 * K.TAU
        put(5 * kk, X_NOW + math.cos(a) * r, lt - 2 + math.sin(a) * r, 1, 1)
      end
    end
    -- a throw: the lamp's echoes left behind on the land
    if K.throw > 0.05 then
      for k = 1, 4 do
        local x = X_NOW - 1 - k * K.echo_t * 8
        local cc = math.floor(x / 2)
        if cc >= 0 and cc < 64 then
          put((2 + 6 * K.throw) * K.echo_fb ^ k, x, math.min(top[cc], GROUND) - 2, 2, 1)
        end
      end
    end
    -- track mode: how far through
    if K.num(S.mode_play, 1) == 2 and S.total_bars then
      put(1.5, 0, 63, 128, 1)
      put(6, 0, 63, math.floor(pr * 128), 1)
    end
    -- the highs glint along the rim
    K.grain(function(u)
      local cc = math.floor(u * 61)
      return cc * 2 + 1, top[cc] - 1
    end, hi * 45, 7)
    -- haze in the valleys, heavier in kickless stretches and with dub
    K.haze(0, 40, 128, GROUND, 0.06 + 0.12 * K.dub * K.throw + 0.2 * K.kickless + 0.2 * mid + 0.15 * pd, 1, T * 3)
    if mid > 0.05 then K.haze(0, 14, 128, 38, 0.2 * mid, 1, -T * 2) end
  end

  M.init()
  return M
end
