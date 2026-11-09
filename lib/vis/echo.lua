-- echo: a railway viaduct at night, side on: a long row of brick arches
-- over a canal, a lamp hanging in each arch. every stab lights the first
-- arch on the left with four bars of light, one per chord voice at its
-- pitch; every echo time a copy appears in the next arch along, fainter by
-- the echo feedback, swaying on a tape wobble, until the echo dies (the v1
-- idea, given a place). throws smear the copies across the arches. the
-- pump ducks the echo return and dims the arch lamps; arp notes are train
-- windows running along the deck at their lane's height; the bass glows
-- on the water, which carries a broken reflection of it all; the highs
-- sparkle on it. kickless stretches fill the arches with haze
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local NA, PITCH, X0 = 6, 21, 2           -- arches, their pitch, first pier
  local OW = 15                            -- an arch's opening width
  local SPRING, R = 28, 7.5                -- where the arch springs, its radius
  local DECK, QUAY = 14, 50                -- the deck's top, the quay edge
  local MAXC, MAXE, MAXW = 26, 10, 14

  local copies, emits, wins
  local lamp, bs, kl

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
  function M.hat() mark("hat") end
  function M.clap() mark("clap") end
  function M.bass() mark("bass") end
  function M.tick(kind) mark("tick"); hit.tk = clamp(math.floor(K.num(kind, 1)), 0, 99) % NA end
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, a = clamp(math.floor(K.num(voice, 1)), 1, 4) - 1,
      b = (math.floor(K.num(note, 60)) % 12) / 12}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    copies, emits, wins = {}, {}, {}
    lamp, bs, kl = 0.6, 0, 0
    hit, percs, pdz = {}, {}, 0
  end
  M.clear = M.init

  local function ax(k) return X0 + k * PITCH + (PITCH - OW) // 2 end   -- opening's left x

  -- half the opening's width at row y (0 above the crown)
  local function half(y)
    if y >= SPRING then return OW / 2 end
    local d = SPRING - y
    if d >= R then return 0 end
    return math.sqrt(R * R - d * d)
  end

  -- voice pitch -> row inside an arch
  local function vrow(n) return 22 + (K.py(n) - 1) / 61 * 25 end

  local function spawn(ys, lv, n)
    if n >= NA then return end
    -- an arch holds one echo: a newer one takes over from a fainter one
    for i = #copies, 1, -1 do
      if copies[i].arch == n then table.remove(copies, i) end
    end
    if #copies >= MAXC then table.remove(copies, 1) end
    copies[#copies + 1] = {ys = ys, lv = lv, arch = n, t0 = K.T, ph = K.rnd() * K.TAU}
  end

  function M.stab(notes)
    local ys = {}
    for i = 1, 4 do ys[i] = vrow(notes[i]) end
    spawn(ys, 12, 0)
    if #emits >= MAXE then table.remove(emits, 1) end
    emits[#emits + 1] = {ys = ys, lv = 12, n = 0, next = K.NOW + K.echo_t}
  end

  function M.arp(lane, note)
    if #wins >= MAXW then table.remove(wins, 1) end
    wins[#wins + 1] = {y = 3 + lane * 2, t0 = K.T, lane = lane, w = 2 + math.floor(K.num(note, 72) % 3)}
  end

  function M.draw(S)
    local T, DT = K.T, K.DT
    kl = K.kickless
    -- the echo: each emitter repeats at the echo time into the next arch
    for i = #emits, 1, -1 do
      local em = emits[i]
      local n = 0
      while K.NOW >= em.next and n < 4 do
        em.lv = em.lv * K.echo_fb
        em.n = em.n + 1
        if em.lv >= 0.8 then spawn(em.ys, em.lv, em.n) end
        em.next = em.next + K.echo_t
        n = n + 1
      end
      if em.lv < 0.8 or em.n >= NA then table.remove(emits, i) end
    end
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local kk, cl, hh, bh, tk = fade("kick", 0.3), fade("clap", 0.3), fade("hat", 0.25), fade("bass", 0.4), fade("tick", 0.4)
    local pd, mid = pdz, A[K.MID]
    lamp = K.follow(lamp, (1 - K.duck * 0.7) * (0.7 + 0.3 * A[K.AMP]) + K.env.kick * 0.3 + pd * 0.15, 0.05, DT)
    bs = K.follow(bs, math.max(K.env.bass * 0.8, A[K.LO], bh * 0.9) * (K.gain(S, "bass") > 0 and 1 or 0.5), 0.07, DT)
    local duckv = 1 - 0.55 * K.duck * K.duck

    -- the sky: a few stars, a low glow of the city behind the deck
    for i = 0, 8 do
      local x = math.floor(K.hash(i, 21) * 126)
      put(1 + 1.2 * K.hash(i, 22) * (0.6 + 0.4 * math.sin(T * 0.5 + i * 1.7)), x, 1 + (i * 5) % 9, 1, 1)
    end

    -- hats glint the stars and run a spark along the overhead wire
    if hh > 0.03 then
      for i = 0, 8 do
        put(5 * hh, math.floor(K.hash(i, 21) * 126), 1 + (i * 5) % 9, 1, 1)
      end
      K.dashes(5 * hh, 3, 3, 9, T * 40, 0, 128)
    end
    -- the overhead wire on its masts over the deck
    line(1.5, 0, 3, 127, 3)
    for k = 0, NA do put(1.5, X0 + k * PITCH - 1, 3, 1, DECK - 3) end
    -- the deck: parapet, the deck's edge
    line(3 + K.bar_pulse * 2, 0, DECK, 127, DECK)
    line(2, 0, DECK + 2, 127, DECK + 2)

    -- the masonry: mortar courses between the openings, pier joints
    for y = DECK + 4, QUAY - 1, 4 do
      local h = half(y)
      local xs = 0
      for k = 0, NA - 1 do
        local c = ax(k) + OW / 2
        local a, b = math.floor(c - h + 0.5), math.floor(c + h + 0.5)
        if h <= 0 then a, b = math.floor(c), math.floor(c) end
        if a > xs then put(1, xs, y, a - xs, 1) end
        xs = b
      end
      if xs < 128 then put(1, xs, y, 128 - xs, 1) end
    end
    -- the arch rings and their lamps
    for k = 0, NA - 1 do
      local x0 = ax(k)
      local c = x0 + OW / 2
      local px, py = c - R, SPRING
      for s = 1, 6 do
        local a = math.pi - s / 6 * math.pi
        local nx, ny = c + math.cos(a) * R, SPRING - math.sin(a) * R
        line(2.5, px, py, nx, ny)
        if cl > 0.03 then line(7 * cl, px, py, nx, ny) end
        px, py = nx, ny
      end
      line(2, x0, SPRING, x0, QUAY)
      line(2, x0 + OW, SPRING, x0 + OW, QUAY)
      -- the lamp under the crown and its pool on the quay
      local ll = lamp * (0.8 + 0.2 * math.sin(T * 0.7 + k * 2.3))
      put(1.5, c, SPRING - R + 1, 1, 2)
      put(3 + 6 * ll, c - 1, SPRING - R + 3, 3, 1)
      put(1 + 2.5 * ll, c - 4, QUAY - 1, 9, 1)
      -- a tick flickers one arch's lamp
      if tk > 0.03 and hit.tk == k then
        put(7 * tk, c - 1, SPRING - R + 3, 3, 1)
        line(6 * tk, x0, SPRING, x0, QUAY)
        line(6 * tk, x0 + OW, SPRING, x0 + OW, QUAY)
        put(4 * tk, c - 4, QUAY - 1, 9, 1)
        for r = 0, 3 do put(3 * tk, c - 1 - r, QUAY + 3 + r * 3, 3 + r * 2, 1) end
      end
    end

    -- haze in the arches, thick when the kick is away
    K.haze(0, SPRING - 6, 128, QUAY, 0.04 + 0.22 * kl + 0.08 * K.throw + 0.15 * mid + 0.2 * pd, 1, T * 2)

    -- the mids thicken the air over the deck
    if mid > 0.05 then K.haze(0, 6, 128, SPRING - 6, 0.25 * mid, 1, -T * 2) end

    -- the quay and the water: the bass glowing on it, the lamps' streaks
    put(2 + bs * 2, 0, QUAY, 128, 1)
    K.gradient(QUAY + 1, 63, function(y)
      return bs * 1.2 * math.exp(-(y - QUAY - 1) / (0.8 + bs))
    end)
    for k = 0, NA - 1 do
      local c = ax(k) + OW / 2
      for r = 0, 3 do
        local y = QUAY + 3 + r * 3
        local w = 3 + r * 2
        local wob = math.sin(T * 1.3 + r * 1.9 + k) * (1 + r * 0.5)
        put((1 + 2.5 * lamp) * (1 - r * 0.18), c - w / 2 + wob, y, w, 1)
      end
    end

    -- the bass thumps the piers' feet into the water
    if bh > 0.03 then
      for k = 0, NA - 1 do
        put(4.5 * bh, ax(k) - 1, QUAY + 1, 2, 11)
        put(4.5 * bh, ax(k) + OW, QUAY + 1, 2, 11)
      end
      put(4 * bh, 0, QUAY, 128, 1)
    end
    -- the kick sends a ring across the canal
    if kk > 0.03 then
      local rx, ry = 4 + (1 - kk) * 56, 1 + (1 - kk) * 6
      local px, py = 64 + rx, QUAY + 7
      for s = 1, 20 do
        local a = s / 20 * K.TAU
        local nx, ny = 64 + math.cos(a) * rx, QUAY + 7 + math.sin(a) * ry
        line(5 * kk, px, py, nx, ny)
        px, py = nx, ny
      end
    end
    -- a perc strikes a spark on the wire at its voice's mast; it falls to the deck
    for i = #percs, 1, -1 do
      local p = percs[i]
      local f = math.exp(-(K.NOW - p.t) / 0.55)
      if f < 0.03 then table.remove(percs, i)
      else
        local x = X0 + p.a * PITCH + p.b * PITCH
        put(6 * f, x - 1, 2, 3, 3)
        put(3 * f, x - 3, 3, 7, 1)
        put(5 * f, x, 4, 2, 4 + (1 - f) * 8)
      end
    end

    -- ripples drifting on the canal
    for r = 0, 2 do
      K.dashes(1, QUAY + 4 + r * 4, 2 + r, 11 + r * 4, T * (3 + r * 2) + r * 5, 0, 128)
    end

    -- train windows on the deck, running right to left at their lane's row
    for i = #wins, 1, -1 do
      local w = wins[i]
      local x = 130 - (T - w.t0) * 70
      if x < -6 then table.remove(wins, i)
      else
        put(3 + 4 * K.lane_kick[w.lane] + 1.5 * lamp, x, w.y, w.w, 1)
      end
    end

    -- the copies: four voice bars in their arch, swaying on the tape's
    -- wobble, fading as they age; smeared back across the arches on a
    -- throw; broken in the water below
    local wow = 0.5 + 2 * K.throw + 1.2 * kl
    local th = K.throw
    for i = #copies, 1, -1 do
      local c = copies[i]
      local age = T - c.t0
      local fade = math.exp(-age / 1.7) * math.min(1, age * 6 + 0.15)
      local lv = c.lv * fade * duckv
      if lv < 0.6 or age > 6 then table.remove(copies, i)
      else
        local x = ax(c.arch) + 2 + math.sin(T * 0.9 + c.ph) * wow * 0.6
        local w = OW - 3
        for k = 1, 4 do
          local y = c.ys[k] + math.sin(T * 1.1 + c.ph + k * 0.7) * wow
          put(lv, x, y, w, 1)
          if th > 0.05 and c.arch > 0 then
            local sl = math.floor(PITCH * 0.7 * th)
            put(lv * 0.2 * th, x - sl, y, sl, 1)
          end
          local ry = QUAY + 1 + (QUAY - y) * 0.45
          if ry < 64 and math.floor(ry) % 2 == 0 then
            put(lv * 0.25, x + 1 + math.sin(T * 3 + ry) * 1.5, ry, w - 2, 1)
          end
        end
      end
    end

    -- the highs: sparkle on the water
    K.grain(function(u, v) return u * 127, QUAY + 2 + v * 11 end, A[K.HI] * 80, 8)
  end

  M.init()
  return M
end
