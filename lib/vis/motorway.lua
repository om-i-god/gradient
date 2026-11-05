-- motorway: a night motorway seen from a bridge, the road running away to
-- a far city glow. lamp posts recede along both verges, their sodium heads
-- and pools of light flickering down on each pump; a gantry spans the road
-- with four signs, lit by the chord stabs (a voice each). the four arp lanes
-- are four traffic lanes: each note sends a car, tail lights receding on
-- the left carriageway, headlights coming on the right, a higher note a
-- faster car. the bass is a lorry grinding up the slow lane, its markers
-- glowing with out_lo; the highs glint on the wet road. throws streak the
-- lights into long exposures; kickless stretches slow the traffic and fog
-- the road
return function(K)
  local M = {}
  local put, line, A, clamp, follow = K.put, K.line, K.A, K.clamp, K.follow

  local HY = 18                           -- the horizon
  local VX = 64                           -- the vanishing point's x
  local W = 20                            -- road unit at depth 1, px
  local OFF = 0.55                        -- we stand over the left carriageway
  local DFAR = 60
  -- arp lane -> road lane offset and direction (+1 away, -1 oncoming)
  local LX = {-0.8, 0.8, -2.0, 2.0}
  local DIR = {1, -1, 1, -1}
  local EDGE, SEP = 2.75, 1.4
  local GANTRY_D = 1.15

  local cars, lorries = {}, {}
  local last = {-9, -9, -9, -9}           -- K.T of each lane's last car
  local ambient = 0
  local vk = {0, 0, 0, 0}
  local sod, lo, bs, hs = 0, 0, 0, 0
  local sign_seed = 1

  local function sy(d) return HY + 46 / d end
  local function sx(lx, d) return VX + (lx + OFF) * W / d end

  -- the skyline beyond the horizon, and its lit windows
  local SKY = K.profile(function(x)
    local b = math.floor(x / 6)
    local h = 1 + K.hash(b, 3) * 3 + (K.hash(b, 5) > 0.8 and 3 + K.hash(b, 6) * 3 or 0)
    if math.abs(x - VX) < 6 then h = h * 0.4 end
    return HY - h
  end)

  function M.init()
    cars, lorries, ambient = {}, {}, 0
    last = {-9, -9, -9, -9}
    vk = {0, 0, 0, 0}
    sod, lo, bs, hs = 0, 0, 0, 0
    sign_seed = 1
  end

  local function spawn(i, note, lv)
    -- notes faster than the traffic can take brighten the last car instead
    if K.T - last[i] < 0.22 then
      for n = #cars, 1, -1 do
        if cars[n].i == i then cars[n].lv = math.min(1.3, cars[n].lv + 0.15); return end
      end
    end
    last[i] = K.T
    if #cars >= 60 then table.remove(cars, 1) end
    local dir = DIR[i]
    local v = 7 + clamp((K.num(note, 72) - 60) / 30, -0.5, 1) * 4
    cars[#cars + 1] = {
      i = i, dir = dir, v = v * (1 - K.kickless * 0.45),
      d = dir > 0 and 1.15 or DFAR, lv = lv or 1,
      j = (K.rnd() - 0.5) * 0.25,                 -- a little drift within the lane
    }
  end

  function M.arp(lane, note)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    spawn(lane, note, 0.6 + 0.4 * K.gain(K.S or {}, "lane" .. lane))
  end

  function M.bass()
    -- a lorry when the slow lane is clear; otherwise the bass is its engine
    local near = false
    for _, l in ipairs(lorries) do if l.d < 7 then near = true end end
    if not near and #lorries < 2 then
      lorries[#lorries + 1] = {d = 1.05, v = 2.2 * (1 - K.kickless * 0.4)}
    end
  end

  function M.bar() sign_seed = sign_seed + 1 end

  -- a car's lights: a pair at near range, one point far off
  local function lights(lx, d, l, dir)
    local x, y = sx(lx, d), sy(d)
    local half = 0.32 * W / d
    local h = d < 1.6 and 2 or 1
    if half < 1 then
      put(l, x, y - 1, 1, 1)
    else
      local w = d < 2.2 and 2 or 1
      put(l, x - half - w * 0.5, y - h, w, h)
      put(l, x + half - w * 0.5, y - h, w, h)
      if dir < 0 and d < 5 then
        -- the beams on the road in front of it
        local n = math.floor(5 / d)
        for k = 1, n do
          put(l * 0.18 * (1 - k / (n + 1)), x - half - k, y + k - 1, 2 * half + 2 * k, 1)
        end
      end
    end
  end

  function M.draw(S)
    local T, DT, DTS = K.T, K.DT, K.DTS
    for i = 1, 4 do vk[i] = follow(vk[i], K.voice_kick[i], 0.15, DT) end
    -- the sodium heads breathe with the pump (eased: a flicker, not a flash)
    sod = follow(sod, K.duck, 0.04, DT)
    lo = follow(lo, A[K.LO], 0.1, DT)
    bs = follow(bs, K.env.bass, 0.05, DT)
    local hi = A[K.HI]
    hs = follow(hs, hi, 0.5, DT)           -- the highs, slow: a sheen on the paint
    local fog = 0.1 + K.kickless * 0.35 + K.dub * K.throw * 0.15
    local lamp = (6 + K.energy * 1.5) * (1 - sod * 0.55)
    local pool = (2.4 + K.energy) * (1 - sod * 0.8)
    local breathe = 1 - sod * 0.35          -- the whole road breathes with the pump

    -- the sky: the city's glow over the horizon, more with the low end
    local glow = 1.4 + lo * 2.2 + K.bar_pulse * 0.5
    -- the skyline: a dark mass, its roofs catching the glow, and a few
    -- windows in it
    K.mass(1, SKY, HY)
    for c = 0, 63 do
      local t = math.floor(SKY[c] + 0.5)
      put(glow * (0.8 + 0.4 * K.hash(c, 21)), c * 2, t, 2, 1)
      if t < HY - 3 and K.hash(c, 22) < 0.3 + lo * 0.2 then
        put(1.5 + 1.5 * math.sin(T * 0.4 + c * 2.3) ^ 2, c * 2 + (c % 2), t + 2 + math.floor(K.hash(c, 23) * (HY - t - 3)), 1, 1)
      end
    end

    -- the road: verges, the central barrier, lane dashes
    local dnear = 1.0
    local dend = 14                       -- past here the road is lost in the dark
    line(2, sx(-EDGE, dnear), sy(dnear), sx(-EDGE, dend), sy(dend))
    line(2, sx(EDGE, dnear), sy(dnear), sx(EDGE, dend), sy(dend))
    line(1.6 + hs, sx(0, dnear), sy(dnear), sx(0, dend), sy(dend))
    for k = 0, 6 do
      local d0 = 1.2 + k * 1.6
      local d1 = d0 + 0.55
      for _, s in ipairs({-SEP, SEP}) do
        line(1.2 + hs * 1.5, sx(s, d0), sy(d0), sx(s, d1), sy(d1))
      end
    end

    -- lamp posts along both verges, taller than the bridge: their heads
    -- run in from the top corners to the far end of the road. each throws
    -- a cone of sodium down and a band of it across the tarmac
    for k = 0, 8 do
      local d = 1.9 + k * 2.2
      local ybase = sy(d)
      local ph = 62 / d                   -- pole height on screen
      local top = math.floor(ybase - ph)
      local far = math.min(1, 2.5 / d)
      local arm = 0.6 * W / d
      if d < 5 then
        local rows = math.max(1, math.floor(5 / d))
        local x0, x1 = sx(-EDGE + 0.1, d), sx(EDGE - 0.1, d)
        for r = 0, rows - 1 do
          put(pool * far * (1 - r / (rows + 1)), x0, math.floor(ybase) - r, x1 - x0, 1)
        end
      end
      for _, side in ipairs({-1, 1}) do
        local px = sx(side * (EDGE + 0.3), d)
        local hx = px - side * arm
        if d < 5 then
          put(1 + far * 0.4, px, top, 1, ph)                                -- the pole
          put(1 + far * 0.4, math.min(px, hx), top, math.abs(px - hx) + 1, 1)   -- the arm
        end
        local big = d < 4
        put(lamp * (0.55 + 0.45 * far), hx - (big and 1 or 0), top + 1, big and 2 or 1, big and 2 or 1)
        -- the cone of light down to the road
        if d < 3 then
          local y0, y1 = top + 3, math.floor(ybase) - 1
          local spread = arm * 1.1
          line(pool * far * 0.55, hx - 1, y0, hx - spread, y1)
          line(pool * far * 0.55, hx + 1, y0, hx + spread, y1)
          for yy = y0 + 4, y1, 4 do
            local u = (yy - y0) / math.max(1, y1 - y0)
            local w = math.floor(u * spread) - 1
            if w > 0 then K.dashes(pool * far * 0.5, yy, 1, 3, yy, hx - w, hx + w + 1) end
          end
        end
      end
    end

    -- the near road, washed by the lamps behind us (on the bridge): a
    -- dithered sodium glow that dips on each pump
    local TH = {0, 4, 2, 6, 1, 5, 3, 7}
    for y = 51, 63 do
      local v = pool * 0.6 * (y - 50) / 13
      local th = (TH[y % 8 + 1] + 0.5) / 8
      local l = math.floor(v)
      if v - l > th then l = l + 1 end
      if l > 0 then
        local d = 46 / (y - HY)
        local x0, x1 = sx(-EDGE, d) + 1, math.min(128, sx(EDGE, d))
        put(l, x0, y, x1 - x0, 1)
      end
    end

    -- the traffic
    local streak = 0.15 + K.throw * 1.4 + K.echo_fb * 0.3       -- world units of trail
    local any = K.playing and #cars > 0
    -- a little traffic of its own when the music leaves the road empty
    ambient = ambient + DTS * (any and 0.1 or 0.9)
    while ambient >= 1 do
      ambient = ambient - 1
      spawn(1 + math.floor(K.rnd() * 4), 60 + K.rnd() * 20, 0.45)
    end
    for n = #cars, 1, -1 do
      local c = cars[n]
      c.d = c.d + c.dir * c.v * DTS * (c.dir > 0 and (0.35 + c.d * 0.12) or (0.3 + c.d * 0.1))
      if c.d > DFAR or c.d < 0.95 then
        table.remove(cars, n)
      else
        local lx = LX[c.i] + c.j
        local fade = c.dir > 0 and (1 - c.d / DFAR) or 1
        local l
        if c.dir > 0 then l = (2.5 + 6 / c.d ^ 0.6) * c.lv
        else l = (3 + 9 / c.d ^ 0.7) * c.lv end
        l = math.min(l * fade, 13) * breathe
        -- the long exposure: the trail the lights leave behind them
        if streak > 0.3 and c.d < 5 then
          local d2 = c.d - c.dir * streak * (0.4 + c.d * 0.1)
          if d2 > 0.95 then
            local half = 0.32 * W / c.d
            local ofs = half >= 1 and half or 0
            for _, s in ipairs(ofs > 0 and {-1, 1} or {0}) do
              line(l * 0.35, sx(lx, c.d) + s * ofs, sy(c.d) - 1, sx(lx, d2) + s * 0.32 * W / d2 * (ofs > 0 and 1 or 0), sy(d2) - 1)
            end
          end
        end
        lights(lx, c.d, l, c.dir)
      end
    end

    -- the lorry: a box with marker lights, grinding up the slow lane
    for n = #lorries, 1, -1 do
      local lr = lorries[n]
      lr.d = lr.d + lr.v * DTS * (0.3 + lr.d * 0.08)
      if lr.d > 30 then table.remove(lorries, n)
      else
        local d = lr.d
        local x, y = sx(-2.0, d), sy(d)
        local hw = 0.55 * W / d
        local hh = 1.3 * W / d
        local body = (1.5 + bs * 2) * math.min(1, 4 / d)
        if hh >= 2 then
          put(body, x - hw, y - hh, 2 * hw, 1)           -- the roof edge
          put(body, x - hw, y - hh, 1, hh)               -- the sides
          put(body, x + hw - 1, y - hh, 1, hh)
          K.dashes(body * 0.6, math.floor(y - hh * 0.5), 1, 3, 0, x - hw + 2, x + hw - 2)
        end
        local mk = (3 + lo * 5 + bs * 3) * math.min(1, 5 / d)
        put(mk, x - hw, y - hh - 1, 1, 1)                 -- marker lights
        put(mk, x + hw - 1, y - hh - 1, 1, 1)
        if hw > 3 then put(mk * 0.8, x - 1, y - hh - 1, 2, 1) end
        lights(-2.0, d, (4 + bs * 4) * math.min(1, 6 / d), 1)
      end
    end

    -- the gantry: two legs, a beam and four signs lit by the stabs
    local gy = sy(GANTRY_D)
    local gh = 30 / GANTRY_D
    local top = math.floor(gy - gh)
    local xl, xr = math.floor(sx(-EDGE - 0.1, GANTRY_D)), math.floor(sx(EDGE + 0.1, GANTRY_D))
    put(1.5, xl, top, 1, math.floor(gh))
    put(1.5, xr, top, 1, math.floor(gh))
    put(1.5, xl, top, xr - xl + 1, 1)
    local pw = math.floor((xr - xl - 9) / 4)
    for i = 1, 4 do
      local x0 = xl + 3 + (i - 1) * (pw + 1)
      local lit = vk[i]
      put(1.3 + lit * 0.7, x0, top + 1, pw, 7)               -- the panel
      -- its legend: dashes from the chord note and the bar
      local h = K.hash(math.floor(K.num(K.chord[i], 60)) + sign_seed * 31, i)
      for r = 0, 1 do
        local w = 4 + math.floor(K.hash(r + i * 7, sign_seed + math.floor(h * 9)) * (pw - 11))
        K.dashes(3 + lit * 6, top + 3 + r * 2, 3, 4, 0, x0 + 2, x0 + 2 + w)
      end
      -- an arrow down to its lane
      local ax = x0 + pw - 4
      put(3 + lit * 6, ax, top + 2, 1, 5)
      put(3 + lit * 6, ax - 1, top + 5, 3, 1)
    end

    -- the wet road: glints under the lights, as much as the highs ask for
    K.grain(function(u, v)
      local d = 1.3 + v * v * 10
      return sx((u - 0.5) * 2 * EDGE, d), sy(d) - 0.5
    end, hi * 45, 7)
    -- fog over the road: kickless and dub
    K.haze(0, HY - 6, 128, 50, fog, 1, T * 4)
  end

  M.init()
  return M
end
