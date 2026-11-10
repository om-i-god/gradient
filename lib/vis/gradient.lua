-- gradient: the chord as soft bands of light at each voice's pitch, seen
-- through a haze over a floor. each band breathes with the pump and swells
-- when its voice is stabbed; calm sections widen and soften them, the peak
-- tightens them. the bass is a glow along the floor and its reflection; the
-- highs are a fine grain in the light; in kickless stretches the bands
-- drift apart and the haze thickens
return function(K)
  local M = {}
  local put, A, clamp = K.put, K.A, K.clamp

  local FLOOR = 56
  local ys = {40, 30, 22, 14}             -- each band's eased row
  local vk = {0, 0, 0, 0}                 -- each voice's stab, eased in
  local bs = 0                            -- the bass glow, eased in
  local wobs, gains = {}, {}              -- per-frame scratch
  -- fine, playing: each band's lit core (a stab flares it, the trails decide
  -- how long it glows), a ghost of its row that lags behind voice leading,
  -- and the lamp in the haze that rides the top band
  local cg, gy = {0, 0, 0, 0}, {40, 30, 22, 14}
  local lampx = 64

  -- the fade scale: at fine, while it plays, the trails param reaches further
  -- (0.25x at 0, ~4x at 100, before the kit's lit clamp)
  local function TRf()
    if K.detail ~= "classic" and K.playing then return K.trail ^ 1.5 end
    return K.trail
  end

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own
  local hit, hn = {}, 0
  local arps, percs = {}, {}
  local function mark(k) hit[k] = K.NOW end
  local function fade(k, tau)
    local t = hit[k]
    if not t then return 0 end
    local v = math.exp(-(K.NOW - t) / (tau * TRf()))
    if v < 0.02 then hit[k] = nil; return 0 end
    return v
  end
  local function push(list, e, cap)
    list[#list + 1] = e
    while #list > cap do table.remove(list, 1) end
  end
  local function live(list, tau)
    for i = #list, 1, -1 do
      local f = math.exp(-(K.NOW - list[i].t) / (tau * TRf()))
      if f < 0.02 then table.remove(list, i) else list[i].f = f end
    end
  end

  function M.init()
    ys = {40, 30, 22, 14}; vk = {0, 0, 0, 0}; bs = 0
    cg, gy, lampx = {0, 0, 0, 0}, {40, 30, 22, 14}, 64
    hit, hn, arps, percs = {}, 0, {}, {}
  end

  function M.kick() mark("kick") end
  function M.hat() mark("hat"); hn = hn + 1 end
  function M.clap() mark("clap") end
  function M.tick(kind) mark("tick"); hit.tickx = 8 + (math.floor(K.num(kind, 1)) * 37) % 112 end
  function M.perc(voice, note)
    local v = clamp(math.floor(K.num(voice, 1)), 1, 4)
    push(percs, {t = K.NOW, x = v * 28 - 12, y = 6 + (math.floor(K.num(note, 60)) * 7) % 40}, 4)
  end
  function M.arp(lane, note, step)
    push(arps, {t = K.NOW, i = clamp(math.floor(K.num(lane, 1)), 1, 4),
      x = (math.floor(K.num(step, 1)) * 13) % 118 + 5}, 6)
  end

  function M.draw(S)
    local T, e, c = K.T, K.energy, K.chord
    local fine, dense, R = K.detail ~= "classic", K.detail == "dense", K.react
    -- an event's level: scaled by the reactivity, never a white point
    local fp, dp = fine and K.playing, dense and K.playing
    local hz = fp and 0.65 or 1     -- the events carry the light now
    if fp then hz = hz * (1 - 0.3 * K.kickless) * (dp and 0.75 or 1) end    -- the kickless lamp (and dense's texture) take the haze's room
    -- the body's share of the glow: the peak tightens it, a sparse bar lets it lie low
    local body = 0.28 + 0.1 * e
    local function ev(l) return math.min(l * R, 13) end
    local breathe = 1 - K.duck * (0.18 + 0.1 * (1 - K.kickless))
    local kk, cl, pd = fade("kick", 0.25), fade("clap", 0.3), K.env.pad
    local width = (1.2 + (1 - e) * 1.6 + K.kickless * 0.4)
    local loose = 1.5 + (1 - e) * 3 + K.kickless * 3
    -- the chord spread over the sky around its own centre, so voice leading
    -- moves the bands wherever the chord sits
    for i = 1, 4 do
      ys[i] = K.follow(ys[i], K.clamp(27 - (c[i] - (c[1] + c[2] + c[3] + c[4]) / 4) * 2.6, 3, FLOOR - 5), 0.35, K.DT)
      vk[i] = K.follow(vk[i], K.voice_kick[i], 0.05, K.DT)
    end
    -- the highs lift the upper voices
    local hi = A[K.HI]
    -- the bands, in 4-px columns of 2-px cells, equal neighbours merged
    local lv = {}
    for col = 0, 31 do wobs[col] = math.sin(T * 0.6 + col * 0.22) * loose end
    for i = 1, 4 do gains[i] = (2.2 + i * 0.5) * (1 + vk[i] * 0.45 + (i >= 3 and hi * 0.5 or 0))
      * (1 + kk * 0.3 + ((i == 2 or i == 3) and cl * 0.15 or 0)) end
    for row = 0, FLOOR // 2 - 1 do
      local y = row * 2
      for col = 0, 31 do
        local wob = wobs[col]
        local v = 0
        for i = 1, 4 do
          local d = (y - ys[i] - wob * (i % 2 == 0 and 1 or -1)) / width
          -- past 3 widths a band adds nothing visible
          if d > -3 and d < 3 then v = v + math.exp(-d * d) * gains[i] end
        end
        v = v * breathe * (0.75 + 0.35 * A[K.MID]) * (1 + 0.05 * A[K.AMP])
        -- soft knee: close voices merge into a glow, not a flat slab; the
        -- tails thin to a dither so the black stays black
        local l = 12 * (1 - math.exp(-v * v * 0.045))
        if l >= 1.6 then
          -- fine, playing: the glow is the body (2..~7), so the cores read over it
          if fp then l = 2 + (l - 1.6) * body end
          l = K.B > 0.05 and math.floor(l * K.B + 0.5) / K.B or 0
        elseif l >= 0.8 and (row + col) % 2 == 0 then l = -1
        else l = 0 end
        lv[col] = l
      end
      local run, rl = 0, lv[0]
      for col = 1, 32 do
        local l = lv[col]
        if l ~= rl then
          if rl > 0 and dp and rl >= 3 then
            -- dense: the glow is drawn in scanlines, a darker row under each
            put(rl, run * 4, y, (col - run) * 4, 1)
            put(math.max(1, math.floor(rl * 0.5)), run * 4, y + 1, (col - run) * 4, 1)
          elseif rl > 0 then put(rl, run * 4, y, (col - run) * 4, 2)
          elseif rl < 0 then put(1, run * 4, y, (col - run) * 4, 1) end
          run, rl = col, l
        end
      end
    end
    -- fine: a hairline at each band's centre, riding the eased row to the
    -- sub-pixel so the bands glide instead of stepping two pixels at a time
    if fp then
      local tr = TRf()
      local kl = K.kickless
      for i = 1, 4 do
        -- the core: a stab flares it and it glows on as long as the trails say;
        -- the top voices take the highs, the peak lifts them all
        -- (it swells in over a few frames, so a stab across the sky never jumps)
        local vkk = K.voice_kick[i]
        if vkk > cg[i] then cg[i] = K.follow(cg[i], vkk, 0.07, K.DT)
        else cg[i] = cg[i] * math.exp(-K.DT / (0.45 * tr)) end
        -- (the reactivity scales the flare only, and the pump barely touches
        -- it: a whole-width line dipping on every beat would flicker)
        local l = (4.5 + 4 * e + cg[i] * (4.5 + 2 * e) * math.min(R, 1.3) + (i >= 3 and hi * 1.5 or 0) + kk * 1.5)
          * (1 - K.duck * 0.08) * (1 - 0.15 * kl)
        l = math.min(13, math.max(l, math.min(4.5, gains[i] * 0.55) * breathe))
        local sg = i % 2 == 0 and 1 or -1
        local step = dense and 4 or 8
        -- kickless: the core comes apart into beads, a gap every other cell
        local skip = kl > 0.5 and 2 or 1
        for col = 0, 31, step // 4 * skip do
          put(l, col * 4, math.floor(ys[i] + wobs[col] * sg + 0.5), step, 1)
        end
        -- the ghost: where the band was, lagging behind as the voices lead on
        gy[i] = K.follow(gy[i], ys[i], 0.5 * tr, K.DT)
        local gd = math.abs(gy[i] - ys[i])
        if gd > 1 then
          K.dashes(math.min(4, 1.5 + gd * 0.4), math.floor(gy[i] + 0.5), 2, 6, i * 3 + T * 2)
        end
      end
      -- the lamp in the haze: a light riding the top band, slowly across.
      -- the kick drives it; kickless, it spreads wide and breathes with the pump
      local top = 1
      for i = 2, 4 do if ys[i] < ys[top] then top = i end end
      lampx = 64 + 46 * math.sin(T * 0.06)
      local lx, ly = math.floor(lampx + 0.5), math.floor(ys[top] + wobs[math.floor(lampx / 4) % 32] * (top % 2 == 0 and 1 or -1) + 0.5)
      local lk = ev((6.5 + 4 * e + kk * 5 + cg[top] * 2) * (1 - 0.1 * kl) * (1 - K.duck * 0.15))
      local hw = math.floor(3 + 2 * e + kl * 5 + 0.5)
      put(lk * 0.3, lx - hw - 2, ly - 1, 2 * hw + 5, 3)
      put(lk * 0.45, lx - hw, ly, 2 * hw + 1, 1)
      put(lk * 0.7, lx - 2, ly - 1, 5, 3)
      put(lk * 0.6, lx, ly - 2, 1, 5)
      put(lk, lx - 1, ly, 3, 1)
      if dp then
        -- dense: motes drifting through the light, caught where they cross a band
        for k = 1, 16 do
          local mx = (K.hash(k, 21) * 128 + T * (2 + K.hash(k, 22) * 3)) % 128
          local bi = 1 + k % 4
          local my = ys[bi] + (K.hash(k, 23) - 0.5) * width * 3 + math.sin(T * 0.5 + k) * 1.5
          K.put_sub(4 + 4 * cg[bi] + hi * 2, mx, my, 1, 1)
        end
      end
    end
    -- the floor: a horizon line, the bass glowing along it and reflected
    bs = K.follow(bs, math.max(K.env.bass, A[K.LO] * 0.8) * (K.gain(S, "bass") > 0 and 1 or 0.4), 0.06, K.DT)
    local bass = bs
    put(2 + bass * 4 + K.bar_pulse * 2 + kk * 3 + A[K.AMP] * 1.5, 0, FLOOR, 128, 1)
    K.gradient(FLOOR + 1, 63, function(y)
      local d = y - FLOOR
      return (0.5 + bass * 3.5) * math.exp(-d / (1.5 + bass * 3))
    end)
    -- the bands come back in the floor, broken by the pump
    for i = 1, 4 do
      local l = 1.5 + K.voice_kick[i] * 3
      local off = T * (6 + i * 3) + i * 17
      K.dashes(l * breathe, FLOOR + 2 + i, 3 + i, 10 + i * 2, off)
      -- dense: each reflection doubled lower down, its core's light in it
      if dp then K.dashes((1 + cg[i] * 3) * breathe * (1 - K.kickless), FLOOR + 6 + i, 2, 9 + i * 2, -off * 0.7) end
    end
    -- haze: a light bank low down, heavier with dub and kickless
    K.haze(0, 36, 128, FLOOR, (0.12 + 0.2 * K.dub * K.throw + 0.18 * K.kickless + 0.25 * pd) * hz, 1, T * 4)
    -- the pad: a slow fog that climbs the whole sky and thins again
    if pd > 0.05 then K.haze(0, 4, 128, 36, 0.12 * pd, 1, -T * 3) end
    -- the hats: a few fine sparks that catch in the light
    local hh = fade("hat", 0.25)
    if hh > 0 then
      if fine then
        for k = 1, 22 do
          local x, y = K.hash(k, hn) * 126, ys[1 + k % 4] + (K.hash(k, hn + 7) - 0.5) * 5
          K.put_sub(ev(7 * hh), x, y, 1, 1)
          if k % 2 == 0 then put(ev(3 * hh), math.floor(x) - 1, math.floor(y), 3, 1) end
        end
      else
      for k = 1, 18 do
        put(5 * hh, K.hash(k, hn) * 126, ys[1 + k % 4] + (K.hash(k, hn + 7) - 0.5) * 5, 1, 1)
      end
      end
    end
    -- a tick: a hairline of dew that catches in the haze
    local tf = fade("tick", 0.3)
    if tf > 0 then
      if fine then
        for y = 4, FLOOR - 2, 2 do
          put(ev(6.5 * tf), hit.tickx, y, 1, 1)
          put(ev(3 * tf), hit.tickx + (y % 4 == 0 and 1 or -1), y, 1, 1)
        end
      else
      for y = 4, FLOOR - 2, 2 do put(5 * tf, hit.tickx, y, 1, 1) end
      end
    end
    -- a perc: a small bead with a drip under it, placed by voice and note
    live(percs, 0.5)
    for _, p in ipairs(percs) do
      local x, y, f = math.floor(p.x), math.floor(p.y), p.f
      if fine then
        -- a bead with a halo, and a drip that falls as it fades
        put(ev(11 * f), x, y + 1, 3, 1)
        put(ev(8 * f), x + 1, y - 1, 1, 1); put(ev(8 * f), x - 1, y + 1, 1, 1); put(ev(8 * f), x + 3, y + 1, 1, 1)
        put(ev(7 * f), x, y, 1, 1); put(ev(7 * f), x + 2, y, 1, 1)
        put(ev(7 * f), x, y + 2, 1, 1); put(ev(7 * f), x + 2, y + 2, 1, 1)
        local fall = (1 - f) * 4
        for d = 3, 11, 2 do
          K.put_sub(ev(8 * f * (1 - (d - 3) / 12)), x + 1, y + d + fall, 1, 1)
        end
      else
      put(7 * f, x, y + 1, 3, 1)
      put(5 * f, x, y, 1, 1); put(5 * f, x + 2, y, 1, 1)
      for d = 3, 11, 2 do put(4.5 * f, x + 1, y + d, 1, 1) end
      end
    end
    -- an arp note: a streak across its voice's band
    live(arps, 0.4)
    for _, a in ipairs(arps) do
      if fine then
        local y = ys[a.i] + 0.5
        K.put_sub(ev(11 * a.f), a.x - 6, y, 13, 1)
        put(ev(5 * a.f), a.x - 3, math.floor(y) - 1, 7, 1); put(ev(5 * a.f), a.x - 3, math.floor(y) + 1, 7, 1)
      else
      local y = math.floor(ys[a.i] + 0.5)
      put(8 * a.f, a.x - 5, y, 11, 1)
      put(3.5 * a.f, a.x - 3, y - 1, 7, 1); put(3.5 * a.f, a.x - 3, y + 1, 7, 1)
      end
    end
    -- grain in the light, as much as the highs ask for
    K.grain(function(u, v)
      local i = 1 + math.floor(u * 4) % 4
      return v * 127, ys[i] + (K.rnd() - 0.5) * width * 2
    end, hi * 90, 9)
  end

  M.init()
  return M
end
