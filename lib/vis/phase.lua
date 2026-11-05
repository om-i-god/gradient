-- phase: two chain-link fences, one behind the other, under a floodlight on
-- waste ground at the edge of the city. where their wires fall in step the
-- moire swims as broad bands of light; where they fall out of step the
-- fence goes dark. the gap between arp lanes 1 and 2 turns the far fence
-- against the near one (the v1 idea), the pump squeezes the far fence's
-- spacing so the bands swing on every beat, stabs brighten the bands at
-- the chord voices' heights, the bass glows on the ground under the lamp
-- and the highs glint on the wire. kickless stretches sway the fences and
-- let the haze in
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp
  local TAU = K.TAU

  local X0, X1, Y0, Y1 = 0, 127, 7, 50      -- the fence box
  local GROUND = 51
  local CX, CY = 64, 30                     -- the gratings' common centre
  local LX, LY = 15, 2                      -- the floodlight
  local SEG = 12                            -- px per shaded segment

  -- the city beyond, low behind the fence
  local city = K.profile(function(x)
    local b = x // 9
    local h = 40 + K.hash(b, 3) * 7 - (K.hash(b, 4) > 0.8 and 6 or 0)
    return math.floor(h)
  end)

  local rot, gap, sq, sw, bs, lk1, lk2, lamp
  local vk, vy = {}, {}

  function M.init()
    rot, gap, sq, sw, bs, lk1, lk2, lamp = 0.35, 0, 0, 0, 0, 0, 0, 0
    for i = 1, 4 do vk[i], vy[i] = 0, 30 end
  end

  local function cycle(l)
    if not l then return 0 end
    return K.num(l.tick, 0) / math.max(1, K.num(l.len, 1) * math.max(1, K.num(l.div, 1)))
  end

  -- grating g's phase at a point (wires sit on whole numbers)
  local G = {{}, {}}
  local function gset(g, th, s, ph)
    local o = G[g]
    o.c, o.s, o.sp, o.ph = math.cos(th), math.sin(th), s, ph
  end
  local function gph(o, x, y) return ((x - CX) * o.c + (y - CY) * o.s) / o.sp - o.ph end

  -- the light between the fences at (x, y): the moire band (0..1), lifted by
  -- the lamp's falloff and the stabbed voices
  local TH = {0, 4, 2, 6, 1, 5, 3, 7}
  local function band(x, y)
    local b = 0.5 + 0.5 * math.cos(TAU * (gph(G[1], x, y) - gph(G[2], x, y)))
    return b
  end
  local function lift(x, y)
    local dx, dy = x - LX, y - LY
    local v = 0
    for i = 1, 4 do
      local d = (y - vy[i]) / 4
      v = v + vk[i] * math.exp(-d * d)
    end
    return (0.55 + 0.7 / (1 + (dx * dx + dy * dy) / 3000)) * (0.6 + 0.5 * lamp), v
  end

  -- the bands as dithered 4x2 cells, equal neighbours merged
  local CW, CH = 4, 2
  local cell = {}
  local function bands(gain)
    for row = 0, (Y1 - Y0) // CH - 1 do
      local y = Y0 + row * CH
      for col = 0, 31 do
        local x = col * CW
        local b = band(x + 2, y + 1)
        local f, v = lift(x + 2, y + 1)
        local u = (b - 0.8 + v * 0.05) / 0.2
        local l = 0
        if u > 0 then
          local val = math.min(8, u * u * (gain * f + v * 3) * 1.6)
          local th = (TH[(row + col * 3) % 8 + 1] + 0.5) / 8
          if val < 1 then l = (val > th) and -1 or 0
          else
            l = math.floor(val)
            if val - l > th then l = l + 1 end
          end
        end
        cell[col] = l
      end
      cell[32] = -99
      local run, rl = 0, cell[0]
      for col = 1, 32 do
        local l = cell[col]
        if l ~= rl then
          if rl > 0 then put(rl, run * CW, y, (col - run) * CW, CH)
          elseif rl < 0 then put(1, run * CW, y + (row % 2), (col - run) * CW, 1) end
          run, rl = col, l
        end
      end
    end
  end

  -- one grating, clipped to the fence box, each wire cut into segments: lit
  -- inside the bands, a faint `dim` outside
  local function grating(g, base, dim)
    local o = G[g]
    local dx, dy = -o.s, o.c
    local reach = math.ceil(80 / o.sp)
    for m = -reach, reach do
      local off = (m + o.ph) * o.sp
      local ox, oy = CX + o.c * off, CY + o.s * off
      local t0, t1 = -300, 300
      if math.abs(dx) > 1e-6 then
        local a, b = (X0 - ox) / dx, (X1 - ox) / dx
        if a > b then a, b = b, a end
        t0, t1 = math.max(t0, a), math.min(t1, b)
      elseif ox < X0 or ox > X1 then t1 = -1e9 end
      if math.abs(dy) > 1e-6 then
        local a, b = (Y0 - oy) / dy, (Y1 - oy) / dy
        if a > b then a, b = b, a end
        t0, t1 = math.max(t0, a), math.min(t1, b)
      elseif oy < Y0 or oy > Y1 then t1 = -1e9 end
      if t1 > t0 + 1 then
        local n = math.ceil((t1 - t0) / SEG)
        local st = (t1 - t0) / n
        local rl, rs = 0, t0
        for j = 0, n do
          local l = 0
          if j < n then
            local tm = t0 + (j + 0.5) * st
            local x, y = ox + dx * tm, oy + dy * tm
            local b = band(x, y)
            if b > 0.6 then
              local f, v = lift(x, y)
              l = math.min(11, math.floor((base * f + v * 3) * (b - 0.6) / 0.4 + 1.5))
            elseif (m + j) % 4 == 0 then l = dim end
          end
          if l ~= rl then
            local te = t0 + j * st
            if rl >= 1 then line(rl, ox + dx * rs, oy + dy * rs, ox + dx * te, oy + dy * te) end
            rl, rs = l, te
          end
        end
      end
    end
  end

  function M.draw(S)
    local T, DT, kl = K.T, K.DT, K.kickless
    -- the turn between the fences: the phase gap of lanes 1 and 2
    local d = (cycle(K.lane(S, 1)) - cycle(K.lane(S, 2))) % 1
    gap = K.follow(gap, math.sin(d * TAU) * 0.07, 1.2, DT)
    rot = rot + 0.012 * K.DTS * (1 + kl)
    sw = K.follow(sw, kl, 1, DT)
    sq = K.follow(sq, K.duck, 0.14, DT)
    bs = K.follow(bs, math.max(K.env.bass * 0.8, A[K.LO]) * (K.gain(S, "bass") > 0 and 1 or 0.5), 0.08, DT)
    lamp = K.follow(lamp, 0.75 * (1 - K.duck * 0.7) + 0.3 * A[K.AMP] + K.env.kick * 0.2, 0.08, DT)
    lk1 = K.follow(lk1, K.lane_kick[1], 0.05, DT)
    lk2 = K.follow(lk2, K.lane_kick[2], 0.05, DT)
    local c = K.chord
    for i = 1, 4 do
      vk[i] = K.follow(vk[i], K.voice_kick[i] * (K.gain(S, "chords") > 0 and 1 or 0.6), 0.12, DT)
      vy[i] = K.follow(vy[i], clamp(Y1 - (K.num(c[i], 60) - 44) * 1.25, Y0 + 3, Y1 - 3), 0.3, DT)
    end
    local e = K.energy
    local s1 = 6.4 - e * 0.6 - A[K.LO] * 0.5
    local sway = math.sin(T * 0.37) * 0.05 * (0.3 + sw)
    gset(1, 1.2 + math.sin(rot) * 0.25 + sway, s1, T * 0.11)
    gset(2, 1.2 + math.sin(rot) * 0.25 + 0.12 + gap - sway * 0.6,
      s1 * (1.17 + gap * 0.3) * (1 - 0.035 * sq), -T * 0.07)

    -- the sky: a sodium glow over the city, the blocks dark against it
    local glow = 0.8 + 0.3 * e + bs * 0.5
    K.gradient(38, GROUND - 1, function(y)
      local u = (GROUND - y) / 13
      return glow * (1 - u) * (1 - u)
    end, city)
    for c = 0, 63 do
      local t = city[c]
      if c % 2 == 0 or t ~= city[c - 1] then put(2 + bs, c * 2, t, 2, 1) end
    end
    for b = 0, 13 do
      if K.hash(b, 9) > 0.45 then
        local x = b * 9 + 2 + math.floor(K.hash(b, 10) * 5)
        local y = K.at(city, x) + 2
        if y < GROUND - 1 then put(1.5 + 1.5 * K.hash(b, 11) * (0.6 + 0.4 * math.sin(T * 0.2 + b)), x, y, 1, 1) end
      end
    end
    -- haze in the floodlight, thicker when the kick is away
    K.haze(0, Y0, 128, GROUND, 0.02 + 0.14 * kl + 0.08 * K.throw, 1, T * 3)

    -- the far fence then the near one
    bands(2.3 + 0.3 * e)
    grating(2, 3 + lk2 * 4 + A[K.HI] * 2, 0)
    grating(1, 4 + lk1 * 4 + A[K.HI] * 2, 1)

    -- posts and top rail
    for p = 0, 2 do
      local x = 21 + p * 43 + math.floor(math.sin(T * 0.37 + p) * sw * 1.5 + 0.5)
      put(2, x, Y0 - 2, 2, GROUND - Y0 + 2)
      put(3 + lamp, x, Y0 - 2, 1, GROUND - Y0 + 2)
    end
    line(3 + lamp * 1.5, 0, Y0 - 1, 127, Y0 - 1)

    -- the floodlight on its pole, breathing with the pump
    put(2, LX + 1, LY + 2, 1, Y0 - LY - 3)
    put(5 + lamp * 6, LX - 3, LY, 7, 2)
    put(2 + lamp * 2, LX - 5, LY + 2, 11, 1)

    -- the ground: the lamp's pool, the bass glowing in it, the fence's
    -- shadow raked across
    put(2 + K.bar_pulse * 2, 0, GROUND, 128, 1)
    K.gradient(GROUND + 1, 63, function(y)
      return (0.3 + bs * 1.8) * math.exp(-(y - GROUND) / (1 + bs * 1.6))
    end)
    for r = 0, 3 do
      local y = GROUND + 3 + r * 3
      K.dashes(1.2 + lamp * 1.2 + bs, y, 2, 7 + r, T * 2 + r * 5 - (G[1].ph % 1) * 7, 0, 128)
    end

    -- the highs glint on the wire
    K.grain(function(u, v)
      local x, y = u * 127, Y0 + v * (Y1 - Y0)
      return x, y
    end, A[K.HI] * 70, 10)
  end

  M.init()
  return M
end
