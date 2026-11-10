-- beams: club lights through haze. a truss across the top carries four
-- moving heads and a mirror ball. each head is an arp lane: its beam leans
-- slowly toward where the lane's notes fall and warms a little on each one;
-- a stab swells them all, slowly, never a flash. the kick lands as a low
-- glow off the floor, the bass under it, and the crowd stands against it.
-- the mirror ball throws its spots round the room, brighter with out_hi.
-- haze rolls through the beams, thicker with dub; in kickless stretches the
-- beams open wide and drift; a throw leaves ghost beams behind, one per echo,
-- fainter by the feedback
return function(K)
  local M = {}
  local put, line, A, clamp, follow = K.put, K.line, K.A, K.clamp, K.follow
  local TAU = K.TAU

  local FLOOR = 54
  local TOP = 8                            -- the lenses' row
  local FX = {22, 50, 78, 106}             -- the heads along the truss
  local BX, BY = 64, 12                    -- the mirror ball
  local NSPOT = 24
  local TH8 = {0, 4, 2, 6, 1, 5, 3, 7}

  local tx, bi = {}, {}                    -- each beam's floor point, brightness
  local sw, glow, vb = 0, 0, 0             -- stab swell, floor glow, bass
  local past, pn = {}, 0                   -- recent floor points, for ghosts

  local heads = {}
  for h = 1, 16 do
    heads[h] = {x = (h - 0.5) / 16 * 128 + (K.hash(h, 21) - 0.5) * 5,
      y = 56.5 + K.hash(h, 22) * 2.5, w = 2 + K.hash(h, 23) * 1.2, arm = K.hash(h, 24)}
  end
  local prof = {}

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own
  local hit, arps, percs = {}, {-99, -99, -99, -99}, {}
  local pdz, mz = 0, 0  -- the pad, eased in
  -- the fades follow the trails setting; at fine it acts at half strength and never moves them by more than 15% or 10%
  -- (round 4: the whole range, about 0.45x at 0 to 2x at 100, so the slider shows)
  local function TR() return K.detail ~= "classic" and math.min(2.0, math.max(0.45, K.trail ^ 0.9)) or K.trail end
  -- pz: the music's presence, eased in and out (fine, while playing). it sinks
  -- the static rig into the dark so the light the music makes stands out
  local pz = 0
  local hz_ph = 0        -- the haze's roll down the beams, quickened by the mids (fine)
  local gobo = 0         -- the gobo wheel's turn (dense)
  local function mark(k) hit[k] = K.NOW end
  local function fade(k, tau)
    local t = hit[k]
    if not t then return 0 end
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    if v < 0.02 then hit[k] = nil; return 0 end
    return v
  end
  function M.pump() mark("pump") end
  function M.kick() mark("kick") end
  function M.hat() mark("hat"); hit.hn = (hit.hn or 0) + 1 end
  function M.clap() mark("clap") end
  function M.bass() mark("bass"); hit.bn = (hit.bn or 0) + 1 end
  function M.tick(kind) mark("tick"); hit.tk = clamp(math.floor(K.num(kind, 1)), 0, 99) % 4 + 1 end
  function M.arp(lane)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    arps[lane] = K.NOW
  end
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, v = clamp(math.floor(K.num(voice, 1)), 1, 4),
      n = math.floor(K.num(note, 60)) % 12}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    for i = 1, 4 do tx[i], bi[i] = FX[i] + (i - 2.5) * 6, 0.5 end
    sw, glow, vb = 0, 0, 0
    past, pn = {}, 0
    hit, arps, percs, pdz, mz = {}, {-99, -99, -99, -99}, {}, 0, 0
    hz_ph = 0
    pz = 0
  end
  M.clear = M.init

  -- one beam from its lens to floor point x1, half-width hw at the floor,
  -- brightness v (~0..4): a dithered body in haze, crisper edges
  local function beam(i, x1, hw, v, T, ghost, edge, bk, gobo)
    local x0 = FX[i]
    local fp = K.detail ~= "classic" and K.playing
      local n = FLOOR - TOP
    if ghost then
      line(v, x0, TOP + 1, x1 - hw * 0.6, FLOOR)
      line(v, x0, TOP + 1, x1 + hw * 0.6, FLOOR)
      return
    end
    for y = TOP + 1, FLOOR - 1 do
      local t = (y - TOP) / n
      local cx = x0 + (x1 - x0) * t
      local w = 0.6 + hw * t
      -- haze in the beam: slow bands rolling down it
      local hz
      if fp then
        hz = 0.65 + (0.35 + 0.3 * mz) * math.sin(y * 0.31 - hz_ph + i * 1.7) * math.sin(y * 0.11 + T * 0.4 + i)
      else
        hz = 0.65 + 0.35 * math.sin(y * 0.31 - T * 0.9 + i * 1.7) * math.sin(y * 0.11 + T * 0.4 + i)
      end
      local lv = v * hz * (1.2 - 0.9 * t)
      if bk then
        lv = math.min(12, lv * bk)
        -- dense: the gobo's bars turning in the light, rolling down the beam
        if gobo and (y + math.floor(gobo * (1 + i * 0.13) + i * 3)) % 7 < 2 then lv = math.min(11, lv * 1.6 + 0.6) end
      end
      local th = (TH8[(y + i) % 8 + 1] + 0.5) / 8
      local l
      if lv < 1 then l = lv > th and 1 or 0
      else l = math.floor(lv); if lv - l > th then l = l + 1 end end
      if l > 0 then
        if fp then
          -- sub-pixel edges: the row's end is dithered by its threshold, so a slow lean
          -- moves the edge a row at a time instead of the whole beam at once
          local xl, xr = math.floor(cx - w + th), math.floor(cx + w + 0.5 + th)
          put(l, xl, y, math.max(1, xr - xl), 1)
        else
          put(l, cx - w, y, 2 * w + 1, 1)
        end
      end
    end
    local el = v * 0.45 + edge
    if bk then el = el * (1 - 0.4 * pz) end     -- the edges sink, the body carries the light
    line(el, x0, TOP + 1, x1 - hw, FLOOR - 1)
    line(el, x0, TOP + 1, x1 + hw, FLOOR - 1)
  end

  function M.draw(S)
    local T, DT, env = K.T, K.DT, K.env
    local kl, e = K.kickless, K.energy
    local hi = A[K.HI]
    local fine, dense, RT = K.detail ~= "classic", K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.15 end     -- eased above 1: the lit / frame-change bounds are tight here
    local fp = fine and K.playing          -- time-driven fine detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RT, 13) or l end
    pz = fine and K.follow(pz, K.playing and 1 or 0, 0.8, DT) or 0
    local live = pz > 0.001
    local dimS = 1 - 0.5 * pz               -- the static rig, sunk while the music plays
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    mz = K.follow(mz, A[K.MID], 1.0, DT)
    if fp then hz_ph = hz_ph + DT * (0.9 + 0.9 * mz); gobo = gobo + DT * (3 + 4 * e) * (1 - 0.6 * kl) end
    local pu, hh, cl, bh, tk = fade("pump", 0.3), fade("hat", 0.25), fade("clap", 0.3), fade("bass", 0.4), fade("tick", 0.4)
    local kk = fade("kick", 0.5)
    -- the floor's kick and the truss's pump come up over a couple of frames, not in one
    local function rise(k) return math.min(1, (K.NOW - (hit[k] or -99)) / 0.07) end
    kk = kk * rise("kick")
    local pd, mid = pdz, A[K.MID]
    -- the truss and the heads on it
    put(2 * dimS, 4, 2, 120, 1)
    put(2 * dimS, 4, 5, 120, 1)
    for x = 4, 118, 6 do line(1, x, 3, x + 3, 4); line(1, x + 3, 4, x + 6, 3) end
    -- the stab swell: in over a fifth of a second, out over a second
    local st = env.stab * (K.gain(S, "chords") > 0 and 1 or 0.6)
    sw = follow(sw, st, st > sw and 0.12 or 0.9, DT)
    -- the beams: lean slowly toward their lane's notes, warm on each note
    local spread = 1 + kl * 0.45 + (1 - e) * 0.25
    for i = 1, 4 do
      local note = K.lane_note[i]
      local drift = 34 * math.sin(T * (0.11 + 0.035 * i) * (1 - 0.4 * kl) + i * 1.9)
      local target = FX[i] + drift
      if note then target = target * 0.45 + K.px(note) * 0.55 end
      tx[i] = follow(tx[i], clamp(target, -10, 138), 1.4 + kl, K.DTS)
      local g = K.gain(S, "lane" .. i)
      local want = 0.7 + 0.8 * e + (g > 0 and (0.5 + K.lane_kick[i] * 0.9) or 0) + sw * 1.4
      want = want * (1 - 0.12 * K.duck) * (1 + 0.1 * A[K.AMP])
      bi[i] = follow(bi[i], want, want > bi[i] and 0.15 or 0.5, DT)
    end
    -- ghosts of where the beams were, one per echo, while a throw is on
    pn = pn + 1
    past[pn] = {t = T, tx[1], tx[2], tx[3], tx[4]}
    local keep = T - 3.4 * K.echo_t - 0.2
    local drop = 0
    while drop < pn - 1 and past[drop + 1].t < keep do drop = drop + 1 end
    if drop > 0 then
      table.move(past, drop + 1, pn, 1)
      for j = pn - drop + 1, pn do past[j] = nil end
      pn = pn - drop
    end
    if K.throw > 0.05 then
      for k = 1, 3 do
        local tt = T - k * K.echo_t
        local p
        for j = pn, 1, -1 do if past[j].t <= tt then p = past[j]; break end end
        if p then
          local l = (1 + 3 * K.throw) * K.echo_fb ^ k
          for i = 1, 4 do beam(i, p[i], 6 * spread, l * (live and 1 + 0.6 * pz or 1), T, true) end
        end
      end
    end
    for i = 1, 4 do
      local hw = (4 + 2 * ((i % 2 == 0) and 1 or 0)) * spread + sw * 2
      local ar = math.exp(-(K.NOW - arps[i]) / ((fine and 0.5 or 0.3) * TR()))
      -- a note warms its own beam through (fine)
      -- (fine, playing) the body takes the energy: dim and soft when it is low, full at
      -- the peak; kickless opens it out but thins it, the ball takes the room
      local bk = live and (1 + pz * (0.35 * e - 0.1 - 0.3 * kl)) or nil
      beam(i, tx[i], hw, bi[i] * 1.35 + (fine and E(5.8 * ar * math.min(1, (K.NOW - arps[i]) / 0.07)) or 0), T, false, 0.6 + hi * 2.2,
        bk, dense and live and gobo or nil)
      if live then
        -- the shaft's hot core, the thing the eye follows: it climbs with the energy
        local cl2 = pz * (0.6 + bi[i] * (0.8 + 0.8 * e) * (1 - 0.45 * kl))
        line(math.min(9, cl2), FX[i], TOP + 1, FX[i] + (tx[i] - FX[i]) * 0.7, TOP + 1 + (FLOOR - TOP) * 0.7)
      end
      put(2 * dimS, FX[i] - 2, 6, 5, 2)
      local lens = 4 + bi[i] * 2.5 * (1 + 0.5 * pz * e)
      put(live and math.min(lens, 12 + (lens - 12) * (1 - pz)) or lens, FX[i] - 1, TOP, 3, 1)
      -- a pump swells each lens housing's halo
      if pu > 0.03 then put(E(5 * pu), FX[i] - 4, 5, 9, 5) end
      -- an arp note flares its own beam down its core
      if ar > 0.03 then
        -- over the brighter shafts while playing the flare climbs with them, over a few frames
        local ab = live and (1 + 0.6 * pz) * math.min(1, (K.NOW - arps[i]) / 0.12) or 1
        line(E(6 * ar * ab), FX[i], TOP + 1, tx[i], FLOOR - 1)
        put(E(5 * ar * ab), tx[i] - 4, FLOOR - 1, 9, 2)
        if fine then                      -- the core doubled, the lens flared, the pool splashed
          line(E(5 * ar * ab), FX[i] + 1, TOP + 1, tx[i] + 1, FLOOR - 1)
          if live then line(E(4 * ar * ab), FX[i] - 1, TOP + 1, tx[i] - 1, FLOOR - 1) end
          put(E(7 * ar), FX[i] - 2, 5, 5, 5)
          put(E(6 * ar), tx[i] - 7, FLOOR + 1, 15, 1)
          put(E(4 * ar), tx[i] - 9, FLOOR + 2, 19, 1)
        end
      end
    end
    -- a tick glints one head's lens
    if tk > 0.03 then put(E(6 * tk), FX[hit.tk] - 3, 12, 7, 3) end
    -- a pump lights the truss's rails from end to end
    if fine and pu > 0.03 then local pr = E(3.6 * pu * rise("pump")); put(pr, 4, 2, 120, 1); put(pr, 4, 5, 120, 1) end
    -- a hat glints along the truss
    if hh > 0.03 then K.dashes(E(6 * hh), 3, 2, 5, (hit.hn or 0) * 2, 4, 124) end
    -- a clap swells the mirror ball
    if cl > 0.03 then
      for dy = -4, 4 do
        local hw = math.floor(math.sqrt(math.max(0.5, 21 - dy * dy)) + 0.5)
        put(E(6 * cl), BX - hw, BY + dy, 2 * hw, 1)
      end
    end
    -- a perc throws a spot of the ball on the wall: its voice sets the
    -- row, its note the place along it
    for i = #percs, 1, -1 do
      local p = percs[i]
      local v = math.exp(-(K.NOW - p.t) / (0.35 * TR()))
      if v < 0.03 then table.remove(percs, i)
      else put(E(6 * v), 6 + p.n * 10, 14 + p.v * 8, 7, 3) end
    end
    -- the mirror ball and its spots round the room
    line(1, BX, 6, BX, BY - 4)
    -- (fine, playing) the ball warms with the energy and glows in kickless stretches
    local bl = live and pz * (1.2 * e + 3.4 * kl + 1.5 * hi) or 0
    for dy = -3, 3 do
      local hw = math.floor(math.sqrt(12 - dy * dy) + 0.5)
      put(2.5 - math.abs(dy) * 0.3 + bl * (1 - math.abs(dy) * 0.22), BX - hw, BY + dy, 2 * hw, 1)
    end
    -- facets: a grid turning with the ball, catching the light
    for f = 0, 7 do
      local fx = ((f * 2 + T * 1.6) % 7) - 3.5
      local fy = (f % 3) * 2 - 2
      local tw = 0.5 + 0.5 * math.sin(T * 2.3 + f * 1.9)
      local fl = 2.5 + (1.5 + hi * 6) * tw * (1 - math.abs(fx) / 4)
      if fp then K.put_sub(fl * 1.25, BX + fx, BY + fy, 1, 1) else put(fl, BX + fx, BY + fy, 1, 1) end
    end
    for j = 1, NSPOT do
      local az = K.hash(j, 31) * TAU + T * 0.35
      local c = math.cos(az)
      if c > 0.15 then
        local x = BX + 74 * math.sin(az)
        local y = 16 + K.hash(j, 32) * 34
        if fp then
          -- kickless: the spots swell one by one into round patches and slow
          local big = kl * 1.4 > (j % 8) / 8 + 0.15
          K.put_sub((1.6 + hi * 6 + kl * 3) * c * 1.2, x, y, 1 + ((j % 3 == 0 or big) and 1 or 0), big and 2 or 1)
        else put((1.6 + hi * 6) * c, x, y, 1 + (j % 3 == 0 and 1 or 0), 1) end
      end
    end
    -- the floor: a low glow the kick lands on, the bass under it
    vb = follow(vb, math.max(env.bass, A[K.LO] * 0.6) * (K.gain(S, "bass") > 0 and 1 or 0.5), 0.08, DT)
    local g = math.max(env.kick * (1 - kl), K.duck * (0.25 + 0.2 * kl), A[K.LO] * 0.7, vb * 0.6, 0.1)
    glow = follow(glow, g, g > glow and 0.05 or 0.3, DT)
    for c = 0, 64 do prof[c] = 64 end
    for _, h in ipairs(heads) do
      local top = h.y + (1 - kl) * e * 1.4 * K.duck
      local cx = h.x + kl * 1.2 * math.sin(T * 0.8 + h.arm * TAU)
      for c = math.max(0, math.floor((cx - h.w - 4) / 2)), math.min(64, math.floor((cx + h.w + 4) / 2)) do
        local d = math.abs(c * 2 + 1 - cx)
        local y = d <= h.w and top + (d / h.w) ^ 2 * 1.5 or d <= h.w + 4 and top + 4 + (d - h.w) * 0.5 or 64
        if y < prof[c] then prof[c] = y end
      end
      -- a raised hand, now and then, in the swell
      if h.arm > 0.55 and (sw + e * 0.5) > h.arm then
        local c = math.floor((cx + 4) / 2)
        if c >= 0 and c <= 64 then prof[c] = math.min(prof[c], top - 4 - (h.arm - 0.55) * 6) end
      end
    end
    -- the pools where the beams land
    K.gradient(FLOOR + 1, 63, function(y)
      local d = y - FLOOR - 1
      return (1 + glow * (fp and 5.3 or 4.5)) * math.exp(-d / ((3 + glow * 3) * (fp and 0.8 or 1)))
    end, prof)
    -- a bass note rolls along the front of the floor
    if bh > 0.03 then
      for y = FLOOR + 1, FLOOR + 5, 2 do K.dashes(E(5 * bh), y, 8, 4, (hit.bn or 0) * 3 + y * 3, 0, 128) end
      if fine then                        -- and on down the dim front of the floor
        K.dashes(E(7 * bh), FLOOR + 8, 4, 8, (hit.bn or 0) * 3 + 6, 0, 128)
      end
    end
    -- a kick lands in each beam's pool
    if fine and kk > 0.03 then
      for i = 1, 4 do
        local hw = 5 * spread + sw * 2
        put(E(6 * kk), tx[i] - hw, FLOOR + 1, 2 * hw, 1)
        put(E(4.8 * kk), tx[i] - hw * 1.2, FLOOR + 2, 2.4 * hw, 1)
        put(E(3.4 * kk), tx[i] - hw * 1.4, FLOOR + 3, 2.8 * hw, 1)
      end
      put(E(2.6 * kk), 0, FLOOR + 4, 128, 1); put(E(2.2 * kk), 0, FLOOR + 5, 128, 1)
    end
    -- (fine, playing) the crowd's heads catch the pools' light along their tops, the
    -- kick lifting them: the room's people, rim-lit, in front of the light
    if live then
      for _, h in ipairs(heads) do
        local lt = 0
        for i = 1, 4 do
          local d = math.abs(h.x - tx[i]) / (6 * spread + 4)
          if d < 1 then lt = lt + (1 - d) * bi[i] end
        end
        local top = h.y + (1 - kl) * e * 1.4 * K.duck
        local cx = h.x + kl * 1.2 * math.sin(T * 0.8 + h.arm * TAU)
        local rl = pz * (0.6 + lt * (1.1 + 0.8 * e) + kk * 2.5 + vb * 1.5)
        if rl > 0.6 then K.put_sub(math.min(9, rl), cx - h.w + 0.5, top, math.max(1, math.floor(2 * h.w - 1)), 1) end
      end
    end
    for i = 1, 4 do
      local hw = 5 * spread + sw * 2
      local lo2 = fp and A[K.LO] * 2.4 or 0              -- the lows brighten the pools (fine)
      put(1.2 + bi[i] * 1.6 + lo2, tx[i] - hw, FLOOR, 2 * hw, 1)
      put(0.8 + bi[i] * 0.9 + lo2, tx[i] - hw * 0.7, FLOOR + 1, 1.4 * hw, 1)
    end
    -- haze through it all
    if fp then
      -- the haze, less of its own so the mids and the pad can show: the pad lifts a veil
      -- round the heads, the mids thicken it
      K.haze(0, 10, 128, FLOOR, 0.04 * K.dub + 0.05 * kl + 0.03 * K.throw + 0.06 * mz, 1, T * (5 + 4 * kl))
      if pd > 0.03 then K.haze(0, 6, 128, 26, 0.5 * pd, 1, T * 3) end
    else
      K.haze(0, 10, 128, FLOOR, 0.05 + 0.13 * K.dub + 0.15 * kl + 0.08 * K.throw + 0.13 * mz + 0.1 * pd, 1, T * (5 + 4 * kl))
    end
    -- dense: a fan of thin lasers off the ball, dotted, sweeping slowly; brighter with the highs
    if dense and live then
      for k = 1, 5 do
        local a = math.sin(T * (0.21 + 0.04 * k) + k * 1.3) * 1.1
        local ll = pz * (1.5 + 2.5 * hi + 2 * e) * (0.6 + 0.4 * math.sin(T * 0.7 + k * 2.1))
        local dx, dy = math.sin(a), math.cos(a)
        for q = 6, 46, 3 do
          local x, y = BX + dx * q, BY + 2 + dy * q
          if y < FLOOR then put(ll, x, y, 1, 1) end
        end
      end
    end
    -- dense: dust turning in the beams, falling slowly down each
    if dense and fp then
      for i = 1, 4 do
        for k = 1, 3 do
          local t = (T * (0.05 + 0.02 * k) + K.hash(i * 5 + k, 33)) % 1
          local y = TOP + 3 + t * (FLOOR - TOP - 6)
          local cx = FX[i] + (tx[i] - FX[i]) * ((y - TOP) / (FLOOR - TOP)) + (K.hash(i * 7 + k, 34) - 0.5) * 3 * (0.6 + ((y - TOP) / (FLOOR - TOP)) * 3)
          K.put_sub(2.2 + bi[i] * 0.8, cx, y, 1, 1)
        end
      end
    end
  end

  M.init()
  return M
end
