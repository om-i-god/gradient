-- stack: a sound system in a yard at night. two stacks flank the amp rack:
-- bass bins at the bottom, a mid box, a pair of horns and the tweeters on
-- top. the bin cones push out with the kick and out_lo (in kickless
-- stretches only the ghost pump moves them, softer); each chord voice lights
-- its mid cone on a stab and the echo plays it back through the same cones,
-- fainter by the feedback, with a ring of air off the box; the horns
-- shimmer with out_hi, each arp lane has its tweeter. the crowd stands in
-- front against the floor glow the kick throws, nodding on the beat; haze
-- drifts through, thicker with dub
return function(K)
  local M = {}
  local put, line, A, clamp, follow = K.put, K.line, K.A, K.clamp, K.follow
  local TAU = K.TAU

  local FLOOR = 52
  local STACKS = {4, 84}                  -- left edge of each 40-px stack
  local NHEAD = 13

  local ex, vb = 0, 0                     -- bin excursion, bass glow (eased)
  local vk = {0, 0, 0, 0}                 -- mid cones, eased
  local lk = {0, 0, 0, 0}                 -- tweeters, eased
  local glow = 0                          -- the floor glow, eased
  local echoes = {}                       -- stabs, replayed at the echo time

  -- unit polygons for the cone rings
  local POLY = {}
  for _, n in ipairs({8, 12}) do
    local p = {}
    for k = 0, n do p[k] = {math.cos(k / n * TAU), math.sin(k / n * TAU)} end
    POLY[n] = p
  end

  local function ring(l, cx, cy, r, n)
    local p = POLY[n]
    for k = 1, n do
      line(l, cx + p[k - 1][1] * r, cy + p[k - 1][2] * r, cx + p[k][1] * r, cy + p[k][2] * r)
    end
  end

  -- a filled disc from row strokes (small radii), so it layers with the
  -- rings by level (strokes land after all the fills)
  local function disc(l, cx, cy, r)
    local ri = math.floor(r)
    for dy = -ri, ri do
      local hw = math.floor(math.sqrt(math.max(0, r * r - dy * dy)) + 0.5)
      if hw > 0 then line(l, cx - hw, cy + dy, cx + hw - 1, cy + dy) end
    end
  end

  -- a cabinet's outline, from fills
  -- lit (fine, playing): the top edge catches the bulbs, the bottom falls into shadow
  local function box(l, x, y, w, h, lit)
    put(lit and l + 1 + lit or l, x, y, w, 1)
    put(lit and l * 0.7 or l, x, y + h - 1, w, 1)
    put(l, x, y + 1, 1, h - 2)
    put(l, x + w - 1, y + 1, 1, h - 2)
  end

  -- the crowd: fixed heads, each with its own place, size and nod
  local heads = {}
  for h = 1, NHEAD do
    heads[h] = {x = (h - 0.5) / NHEAD * 128 + (K.hash(h, 3) - 0.5) * 6,
      y = 55 + K.hash(h, 5) * 2.5, w = 2.5 + K.hash(h, 7) * 1.5,
      ph = K.hash(h, 9)}
  end
  local prof = {}

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own.
  -- pump, hat, bass and arp take turns between the two stacks
  local hit, percs, pdz = {}, {}, 0
  local pn, hn, bn, an = 0, 0, 0, 0
  local PS, HS, BS, AS = {"pump0", "pump1"}, {"hat0", "hat1"}, {"bass0", "bass1"}, {"arp0", "arp1"}
  local alane = {1, 1}
  -- the fades follow the trails setting: at fine and dense over most of its range (0.45x at 0, 2.2x at 100)
  local function TR() return K.detail ~= "classic" and math.min(2.2, math.max(0.45, K.trail)) or K.trail end
  local function mark(k) hit[k] = K.NOW end
  local function fade(k, tau)
    local t = hit[k]
    if not t then return 0 end
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    if v < 0.02 then hit[k] = nil; return 0 end
    return v
  end
  function M.pump() pn = pn + 1; mark(PS[pn % 2 + 1]) end
  function M.hat() hn = hn + 1; mark(HS[hn % 2 + 1]) end
  function M.bass() bn = bn + 1; mark(BS[bn % 2 + 1]) end
  function M.clap() mark("clap") end
  function M.tick(kind) mark("tick"); hit.tk = clamp(math.floor(K.num(kind, 1)), 0, 99) % 2 end
  function M.arp(lane)
    an = an + 1
    mark(AS[an % 2 + 1])
    alane[an % 2 + 1] = clamp(math.floor(K.num(lane, 1)), 1, 4)
  end
  -- a perc shocks the bin of its voice: a ring of air, as far as its note says
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, bin = (clamp(math.floor(K.num(voice, 1)), 1, 4) - 1) % 4,
      r = 8 + (math.floor(K.num(note, 60)) % 12) / 12 * 1.8}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    ex, vb, glow = 0, 0, 0
    vk, lk, echoes = {0, 0, 0, 0}, {0, 0, 0, 0}, {}
    hit, percs, pdz, pn, hn, bn, an = {}, {}, 0, 0, 0, 0, 0
    alane = {1, 1}
  end
  M.clear = M.init

  function M.stab()
    echoes[#echoes + 1] = {t0 = K.T, s = 0.35 + 0.65 * K.dub * (0.4 + 0.6 * K.throw) + 0.3 * K.throw}
    if #echoes > 6 then table.remove(echoes, 1) end
  end

  function M.draw(S)
    local T, DT, env = K.T, K.DT, K.env
    local fine, dense, RT = K.detail ~= "classic", K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.15 end     -- eased above 1: the lit / frame-change bounds are tight here
    local fp = fine and K.playing          -- time-driven fine detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RT, 13) or l end
    local kl = K.kickless
    -- the bins: a fast push out, a slower return
    local push = math.max(env.kick * (1 - kl), clamp((A[K.LO] - 0.2) / 0.75, 0, 1), K.duck * (0.2 + 0.3 * kl))
    ex = follow(ex, push, push > ex and 0.02 or 0.1, DT)
    vb = follow(vb, math.max(env.bass, A[K.LO] * 0.5) * (K.gain(S, "bass") > 0 and 1 or 0.5), 0.05, DT)
    -- the echo: each stab comes back every echo_t, fainter by the feedback
    local et, fb = K.echo_t, K.echo_fb
    local echo_v, air = 0, {}
    for i = #echoes, 1, -1 do
      local e = echoes[i]
      local age = T - e.t0
      local k = math.floor(age / et)
      local v = (k == 0 and 1 or e.s * fb ^ k)
      if v < 0.05 or k > 8 then table.remove(echoes, i)
      else
        local u = (age - k * et) / et
        echo_v = math.max(echo_v, v * math.exp(-u * 3))
        if k >= 1 and u < 0.7 and (not air[1] or air[1].v < v) then air[1] = {u = u / 0.7, v = v} end
      end
    end
    for i = 1, 4 do
      vk[i] = follow(vk[i], math.max(K.voice_kick[i], echo_v * (0.4 + 0.15 * i)), 0.04, DT)
      lk[i] = follow(lk[i], K.lane_kick[i], 0.03, DT)
    end
    local hi = A[K.HI]
    local mid = A[K.MID]
    pdz = follow(pdz, K.env.pad, 0.25, DT)
    local pd, cl, tkk = pdz, fade("clap", 0.3), fade("tick", 0.4)

    -- playing, the cabinets' top edges catch the light of the bulbs (the energy, the bar)
    local bl = fp and K.energy * 0.8 + K.bar_pulse * 0.6 or nil
    -- the floor glow the kick throws, and the crowd against it
    local g = math.max(env.kick * (1 - kl) * 0.9, K.duck * 0.35, A[K.LO] * 0.55, 0.15)
    glow = follow(glow, g, g > glow and 0.04 or 0.18, DT)
    for c = 0, 64 do prof[c] = 64 end
    for _, h in ipairs(heads) do
      local nod = (1 - kl) * K.energy * 1.6 * K.duck
      local sway = kl * 1.5 * math.sin(T * 0.9 + h.ph * TAU)
      local top = h.y + nod * (0.6 + 0.6 * h.ph)
      local cx = h.x + sway
      for c = math.max(0, math.floor((cx - h.w - 4) / 2)), math.min(64, math.floor((cx + h.w + 4) / 2)) do
        local d = math.abs(c * 2 + 1 - cx)
        local y = d <= h.w and top + (d / h.w) ^ 2 * 1.5
          or d <= h.w + 4 and top + 5 + (d - h.w) * 0.5 or 64
        if y < prof[c] then prof[c] = y end
      end
    end
    K.gradient(FLOOR + 1, 63, function(y)
      local d = y - FLOOR - 1
      return (1.3 + glow * (fp and 4.3 or 4)) * math.exp(-d / ((3.5 + glow * 3) * (fp and 0.82 or 1)))
    end, prof)
    put(2 + glow * 3 + K.bar_pulse, 0, FLOOR, 128, 1)
    if fp then
      -- dense: the bins' light spilling along the stage lip under each stack
      if dense then
        for si = 1, 2 do K.dashes(3 + glow * 5 + ex * 3, FLOOR, 2, 5, T * 6 * (si * 2 - 3), STACKS[si], STACKS[si] + 40) end
      end
      -- playing: the stacks' light catches the tops of the heads, brighter as
      -- the bins push (dense: some heads caught brighter than others)
      for c = 0, 63 do
        local y = math.floor(prof[c] + 0.5)
        if y < 63 then
          put(1 + glow * 2.6 + ex * 1.6 + (dense and (c % 3 == 0 and 1.5 or -0.4) or 0), c * 2, y, 2, 1)
        end
      end
      -- kickless: lighters held up over the crowd, swaying with the pads
      if kl > 0.15 then
        for hI = 2, NHEAD, 3 do
          local h = heads[hI]
          local sw = math.sin(T * 0.8 + h.ph * TAU)
          local lv = kl * (5 + 3 * pd + 1.5 * (0.5 + 0.5 * math.sin(T * 5 + hI)))
          local bx = h.x + kl * 1.5 * math.sin(T * 0.9 + h.ph * TAU)
          local fx, fy = bx + 2 + sw * 1.5, h.y - 9 - 0.6 * math.abs(sw)
          line(1.2 * kl, bx + 2, h.y + 1, fx, fy + 2)                  -- the raised arm
          K.put_sub(lv, fx, fy, 1, 2)                                    -- the flame
          put(lv * 0.3, fx - 1, fy - 1, 3, 1)
        end
      end
    end

    -- the amp rack between the stacks: four meters, the desk lamp on top
    local rx = 54
    box(2, rx, 30, 20, 22, bl)
    local meters = {A[K.AMP], A[K.LO], mid, hi}
    for m = 1, 4 do
      local y = 33 + (m - 1) * 4
      local w = math.floor(clamp(meters[m], 0, 1) * 14 + 0.5)
      if w > 0 then put(3 + meters[m] * 3, rx + 3, y, w, 2) end
    end
    put(3 + K.bar_pulse * 5, rx + 9, 28, 2, 2)
    -- moths round the lamp
    for m = 1, 3 do
      local a = T * (1.7 + m * 0.45) + m * 2.1
      local r = 3 + m * 1.6 + math.sin(T * 0.7 + m) * 1.5
      if fp then K.put_sub(1.6 + (m == 1 and 0.6 or 0), rx + 10 + math.cos(a) * r, 28 + math.sin(a * 1.3) * r * 0.55 - 1, 1, 1)
      else put(1.6 + (m == 1 and 0.6 or 0), rx + 10 + math.cos(a) * r, 28 + math.sin(a * 1.3) * r * 0.55 - 1, 1, 1) end
    end
    -- a string of bulbs slung between the stacks, each glowing on its own
    for k = 0, 16 do
      local u = k / 16
      local x = 44 + u * 40
      local y = 9 + 7 * (1 - (2 * u - 1) ^ 2)
      if k > 0 then line(1, x - 2.5, 9 + 7 * (1 - (2 * u - 1 - 0.125) ^ 2), x, y) end
      if k % 2 == 1 then
        put(2.2 + 1.6 * math.sin(T * (2.2 + 1.5 * K.hash(k, 11)) + k * 2.3) + K.bar_pulse * 1.5 + K.energy, x, y + 1, 1, 1)
      end
    end

    for si, x0 in ipairs(STACKS) do
      local pf, bf, hf, af = fade(PS[si], 0.3), fade(BS[si], 0.4), fade(HS[si], 0.25), fade(AS[si], 0.3)
      -- bass bins: two scoops, one cone each
      for b = 0, 1 do
        local bx = x0 + b * 20
        box(1.6, bx, 32, 20, 20, bl)
        if pf > 0.03 then                                          -- a pump thumps the cabinets
          box(E(fine and 4.6 * pf or 4 * pf), bx, 32, 20, 20)
        end
        local cx, cy = bx + 10, 42
        if bf > 0.03 then                                           -- a bass note lights the rims
          ring(E(fine and 7 * bf or 5 * bf), cx, cy, 8, 12)
        end
        if dense and fp then                                        -- the grille slats, brightening the ring they sit on
          for gy = 36, 48, 12 do put(2.5 + vb * 2.5 + ex * 3, cx - 6, gy == 36 and cy - 6 or cy + 5, 2, 1); put(2.5 + vb * 2.5 + ex * 3, cx + 4, gy == 36 and cy - 6 or cy + 5, 2, 1) end
        end
        ring(2 + ex * 1.5, cx, cy, 8, 12)
        ring(2.5 + ex * (fine and 5.6 or 5) + vb * (fine and 2.5 or 2), cx, cy, 3.9 + ex * 3, 12)
        disc(3.5 + ex * (fine and 7.6 or 7) + vb * (fine and 2.5 or 2), cx, cy, 1.2 + ex * 2.2)
        -- playing: the surround flexes bright on the push, the bin's mouth
        -- shadowed between (the cone stands out of its box)
        if fp and ex > 0.05 then ring(E(2 + ex * 7), cx, cy, 6.2 + ex * 1.2, 12) end
      end
      -- the mid box: a cone per chord voice
      box(1.6, x0, 21, 40, 11, bl)
      for i = 1, 4 do
        local cx, cy = x0 + 5 + (i - 1) * 10, 26
        local v = vk[i]
        ring(2 + v * 5 + mid, cx, cy, 3.6 + v * 0.6, 8)
        if cl > 0.03 then                                              -- a clap swells the mid cones
          ring(E(fine and 7 * cl or 6 * cl), cx, cy, 3.6 + v * 0.6, 8)
        end
        disc(2 + v * 9, cx, cy, 1.2 + v * 0.6)
      end
      -- the echo's air: an arc off the mid box into the yard
      for _, a in ipairs(air) do
        local r = 21 + a.u * 10
        local side = x0 < 64 and 1 or -1
        local l = fine and math.min(13, 1 + 3.4 * a.v * (1 - a.u)) or (1 + 3 * a.v * (1 - a.u))
        local px, py
        for k = -3, 3 do
          local th = k * 0.2
          local x, y = x0 + 20 + side * r * math.cos(th), 26 + r * math.sin(th)
          if px then line(l, px, py, x, y) end
          px, py = x, y
        end
      end
      -- horns: a mouth, a flare, a throat; out_hi shimmers in them
      for j = 0, 1 do
        local hx = x0 + 2 + j * 19
        box(2, hx, 11, 17, 9, bl)
        box(1.5 + hi * 2, hx + 4, 13, 9, 5)
        line(1, hx + 1, 12, hx + 3, 13); line(1, hx + 15, 12, hx + 13, 13)
        line(1, hx + 1, 18, hx + 3, 17); line(1, hx + 15, 18, hx + 13, 17)
        local sh = 0.5 + 0.5 * math.sin(T * 9 + j * 2.1 + x0)
        if hf > 0.03 then                                            -- a hat sprays the horn's mouth
          K.dashes(E(fine and 8 * hf or 5 * hf), 14, 1, 3, T * 40 + j * 3, hx + 2, hx + 15)
          K.dashes(E(fine and 8 * hf or 5 * hf), 16, 1, 3, -T * 40 + j * 3, hx + 2, hx + 15)
        end
        put(3 + hi * (5 + 3 * sh) + env.hat * 2, hx + 7, 15, 3, 1)
        if hi > 0.1 then K.dashes(hi * 3 * sh, 12 + (j + math.floor(T * 7)) % 2 * 6, 2, 5, T * 30 + j * 3, hx + 2, hx + 15) end
      end
      -- tweeters on top: one per arp lane
      box(1.6, x0 + 2, 6, 36, 5, bl)
      for i = 1, 4 do put(2.5 + lk[i] * 9, x0 + 5 + (i - 1) * 9, 8, 2, 1) end
      if af > 0.03 then                                              -- an arp note flares its tweeter
        put(E(6 * af), x0 + 4 + (alane[si] - 1) * 9, 7, 4, 3)
        if fine then                                                 -- the whole tweeter bar rings
          box(E(4 * af), x0 + 2, 6, 36, 5)
        end
      end
    end

    -- a perc shocks its bin with a ring of air
    for i = #percs, 1, -1 do
      local p = percs[i]
      local f = math.exp(-(K.NOW - p.t) / (0.35 * TR()))
      if f < 0.03 then table.remove(percs, i)
      else
        local cx, cy = STACKS[p.bin // 2 + 1] + (p.bin % 2) * 20 + 10, 42
        ring(E(fine and 8 * f or 6 * f), cx, cy, 2 + (1 - f) * (p.r - 2), 12)

      end
    end
    -- the pad lifts a haze over the yard's sky
    if pd > 0.03 then K.haze(0, 0, 128, 44, pd * (fine and 0.46 or 0.4), 1, T * 2) end

    -- haze drifting through, thicker with dub and kickless stretches
    local hz = (0.1 + 0.12 * K.dub * (0.5 + K.throw) + 0.18 * kl) * (fp and 0.12 or 1)
    K.haze(0, 44, 128, FLOOR, hz, 1, T * (6 + 8 * K.throw))
    K.haze(44, 18, 84, 44, hz * 1.3, 1, T * (6 + 8 * K.throw) + 40)
    -- ticks run along the string of bulbs, every other one by their kind
    if tkk > 0.03 then
      for k = 1, 16 do
        local u = k / 16
        local x = 44 + u * 40
        line(E(4 * tkk), x - 2.5, 9 + 7 * (1 - (2 * u - 1 - 0.125) ^ 2), x, 9 + 7 * (1 - (2 * u - 1) ^ 2))
        if (k + (hit.tk or 0)) % 2 == 1 then put(E(8 * tkk), x, 9 + 7 * (1 - (2 * u - 1) ^ 2) + 1, 1, 2) end
      end
    end
    -- the highs as a fine fizz off the horns
    K.grain(function(u, v)
      local x0 = STACKS[1 + math.floor(u * 2) % 2]
      return x0 + 2 + v * 36, 5 + K.rnd() * 3
    end, hi * 40, 7)
  end

  M.init()
  return M
end
