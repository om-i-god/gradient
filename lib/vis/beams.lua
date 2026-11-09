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
  local function mark(k) hit[k] = K.NOW end
  local function fade(k, tau)
    local t = hit[k]
    if not t then return 0 end
    local v = math.exp(-(K.NOW - t) / tau)
    if v < 0.02 then hit[k] = nil; return 0 end
    return v
  end
  function M.pump() mark("pump") end
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
  end
  M.clear = M.init

  -- one beam from its lens to floor point x1, half-width hw at the floor,
  -- brightness v (~0..4): a dithered body in haze, crisper edges
  local function beam(i, x1, hw, v, T, ghost, edge)
    local x0 = FX[i]
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
      local hz = 0.65 + 0.35 * math.sin(y * 0.31 - T * 0.9 + i * 1.7) * math.sin(y * 0.11 + T * 0.4 + i)
      local lv = v * hz * (1.2 - 0.9 * t)
      local th = (TH8[(y + i) % 8 + 1] + 0.5) / 8
      local l
      if lv < 1 then l = lv > th and 1 or 0
      else l = math.floor(lv); if lv - l > th then l = l + 1 end end
      if l > 0 then put(l, cx - w, y, 2 * w + 1, 1) end
    end
    line(v * 0.45 + edge, x0, TOP + 1, x1 - hw, FLOOR - 1)
    line(v * 0.45 + edge, x0, TOP + 1, x1 + hw, FLOOR - 1)
  end

  function M.draw(S)
    local T, DT, env = K.T, K.DT, K.env
    local kl, e = K.kickless, K.energy
    local hi = A[K.HI]
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    mz = K.follow(mz, A[K.MID], 1.0, DT)
    local pu, hh, cl, bh, tk = fade("pump", 0.3), fade("hat", 0.25), fade("clap", 0.3), fade("bass", 0.4), fade("tick", 0.4)
    local pd, mid = pdz, A[K.MID]
    -- the truss and the heads on it
    put(2, 4, 2, 120, 1)
    put(2, 4, 5, 120, 1)
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
          for i = 1, 4 do beam(i, p[i], 6 * spread, l, T, true) end
        end
      end
    end
    for i = 1, 4 do
      local hw = (4 + 2 * ((i % 2 == 0) and 1 or 0)) * spread + sw * 2
      beam(i, tx[i], hw, bi[i] * 1.35, T, false, 0.6 + hi * 2.2)
      put(2, FX[i] - 2, 6, 5, 2)
      put(4 + bi[i] * 2.5, FX[i] - 1, TOP, 3, 1)
      -- a pump swells each lens housing's halo
      if pu > 0.03 then put(5 * pu, FX[i] - 4, 5, 9, 5) end
      -- an arp note flares its own beam down its core
      local ar = math.exp(-(K.NOW - arps[i]) / 0.3)
      if ar > 0.03 then
        line(6 * ar, FX[i], TOP + 1, tx[i], FLOOR - 1)
        put(5 * ar, tx[i] - 4, FLOOR - 1, 9, 2)
      end
    end
    -- a tick glints one head's lens
    if tk > 0.03 then put(6 * tk, FX[hit.tk] - 3, 12, 7, 3) end
    -- a hat glints along the truss
    if hh > 0.03 then K.dashes(6 * hh, 3, 2, 5, (hit.hn or 0) * 2, 4, 124) end
    -- a clap swells the mirror ball
    if cl > 0.03 then
      for dy = -4, 4 do
        local hw = math.floor(math.sqrt(math.max(0.5, 21 - dy * dy)) + 0.5)
        put(6 * cl, BX - hw, BY + dy, 2 * hw, 1)
      end
    end
    -- a perc throws a spot of the ball on the wall: its voice sets the
    -- row, its note the place along it
    for i = #percs, 1, -1 do
      local p = percs[i]
      local v = math.exp(-(K.NOW - p.t) / 0.35)
      if v < 0.03 then table.remove(percs, i)
      else put(6 * v, 6 + p.n * 10, 14 + p.v * 8, 7, 3) end
    end
    -- the mirror ball and its spots round the room
    line(1, BX, 6, BX, BY - 4)
    for dy = -3, 3 do
      local hw = math.floor(math.sqrt(12 - dy * dy) + 0.5)
      put(2.5 - math.abs(dy) * 0.3, BX - hw, BY + dy, 2 * hw, 1)
    end
    -- facets: a grid turning with the ball, catching the light
    for f = 0, 7 do
      local fx = ((f * 2 + T * 1.6) % 7) - 3.5
      local fy = (f % 3) * 2 - 2
      local tw = 0.5 + 0.5 * math.sin(T * 2.3 + f * 1.9)
      put(2.5 + (1.5 + hi * 6) * tw * (1 - math.abs(fx) / 4), BX + fx, BY + fy, 1, 1)
    end
    for j = 1, NSPOT do
      local az = K.hash(j, 31) * TAU + T * 0.35
      local c = math.cos(az)
      if c > 0.15 then
        local x = BX + 74 * math.sin(az)
        local y = 16 + K.hash(j, 32) * 34
        put((1.6 + hi * 6) * c, x, y, 1 + (j % 3 == 0 and 1 or 0), 1)
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
      return (1 + glow * 4.5) * math.exp(-d / (3 + glow * 3))
    end, prof)
    -- a bass note rolls along the front of the floor
    if bh > 0.03 then
      for y = FLOOR + 1, FLOOR + 5, 2 do K.dashes(5 * bh, y, 8, 4, (hit.bn or 0) * 3 + y * 3, 0, 128) end
    end
    for i = 1, 4 do
      local hw = 5 * spread + sw * 2
      put(1.2 + bi[i] * 1.6, tx[i] - hw, FLOOR, 2 * hw, 1)
      put(0.8 + bi[i] * 0.9, tx[i] - hw * 0.7, FLOOR + 1, 1.4 * hw, 1)
    end
    -- haze through it all
    K.haze(0, 10, 128, FLOOR, 0.05 + 0.13 * K.dub + 0.15 * kl + 0.08 * K.throw + 0.13 * mz + 0.1 * pd, 1, T * (5 + 4 * kl))
  end

  M.init()
  return M
end
