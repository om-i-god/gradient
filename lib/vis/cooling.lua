-- cooling: two cooling towers on the horizon at night, the near one on the
-- left and a smaller, farther one on the right, both with the waisted
-- hyperbolic shell (wide base, narrow throat, a slight flare to the rim),
-- ridged with faint vertical ribs. steam plumes rise from the rims as
-- drifting dithered puffs that spread as they climb; the pad and the energy
-- thicken them, the pump squeezes them in. the kick sends a ring up the
-- plume. hats are the aircraft warning lights on the rims (one tower each,
-- alternating), the bass lights the base of the towers and the ground
-- beneath. clap bursts a fan of vapour off a rim, perc lights a lamp on
-- a shell's ladder (voice = side, height), ticks drip from the base, stabs
-- floodlight horizontal bands across the shells (note = height), arps are
-- vents hissing on the plain (note = where). mids lift the shell ribs,
-- highs glitter in the steam, lows swell the plume, the level lights the sky
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local RIBS = {-0.62, -0.25, 0.25, 0.62}
  local RIBS_DENSE = {-0.8, -0.62, -0.43, -0.25, 0, 0.25, 0.43, 0.62, 0.8}      -- dense: a rib between each pair
  local SIDES = {-1, 1}
  local GY = 52                          -- the horizon
  -- cx, top, throat, half width at the throat, half width at the base
  local TW = {
    {cx = 36, top = 14, thr = 27, wt = 11, wb = 20},
    {cx = 98, top = 27, thr = 36, wt = 7, wb = 13},
  }
  for i = 1, #TW do
    local t = TW[i]
    t.k = (t.wb * t.wb - t.wt * t.wt) / ((GY - t.thr) ^ 2)
  end
  local function hw(t, y)
    local d = y - t.thr
    return math.sqrt(t.wt * t.wt + t.k * d * d)
  end

  -- the fades follow the trails setting; at fine it acts at half strength and never moves them by more than 15% or 10%
  local function TR() return K.detail ~= "classic" and math.min(1.1, math.max(0.85, K.trail ^ 0.5)) or K.trail end
  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    return v < 0.03 and 0 or v
  end

  local NP = 9                           -- puffs per plume
  local kick_t, pump_t, bass_t = -99, -99, -99
  local rings = {{t = -99, tw = 1}, {t = -99, tw = 2}, {t = -99, tw = 1}}
  local rgi = 0
  local lights = {-99, -99}
  local light_n = 0
  local clap_t, clap_tw = -99, 1
  local lamps = {}
  for i = 1, 4 do lamps[i] = {t = -99, tw = 1, side = 1, y = 30} end
  local lpi = 0
  local drips = {}
  for i = 1, 4 do drips[i] = {t = -99, x = 30, k = 1} end
  local dri, tick_n = 0, 0
  local bands = {}
  for i = 1, 4 do bands[i] = {t = -99, y = 30} end
  local bni = 0
  local vents = {}
  for i = 1, 5 do vents[i] = {t = -99, x = 60} end
  local vni = 0
  local pad_notes = {}
  local pdz = 0

  function M.init()
    kick_t, pump_t, bass_t, clap_t = -99, -99, -99, -99
    lights = {-99, -99}
    light_n, tick_n = 0, 0
    for i = 1, 3 do rings[i].t = -99 end
    for i = 1, 4 do lamps[i].t = -99; drips[i].t = -99; bands[i].t = -99 end
    for i = 1, 5 do vents[i].t = -99 end
    pad_notes = {}
    pdz = 0
  end
  M.clear = M.init

  function M.kick()
    kick_t = K.NOW
    rgi = rgi % #rings + 1
    rings[rgi].t, rings[rgi].tw = K.NOW, 1
    rgi = rgi % #rings + 1
    rings[rgi].t, rings[rgi].tw = K.NOW + 0.08, 2
  end
  function M.pump() pump_t = K.NOW end
  function M.bass(note) bass_t = K.NOW end
  function M.hat()
    light_n = light_n + 1
    lights[light_n % 2 + 1] = K.NOW
  end
  function M.clap()
    clap_t = K.NOW
    clap_tw = (math.floor(K.NOW * 4) % 2) + 1
  end
  function M.perc(voice, _)
    voice = clamp(math.floor(K.num(voice, 1)), 1, 4)
    lpi = lpi % #lamps + 1
    local l = lamps[lpi]
    l.t, l.tw, l.side = K.NOW, (voice % 2) + 1, (voice > 2) and 1 or -1
    local t = TW[l.tw]
    l.y = t.top + 3 + (voice * 5 + lpi * 3) % math.max(1, GY - t.top - 8)
  end
  function M.tick(kind)
    kind = clamp(math.floor(K.num(kind, 1)), 1, 4)
    tick_n = tick_n + 1
    dri = dri % #drips + 1
    local d = drips[dri]
    d.t, d.k = K.NOW, kind
    local t = TW[(tick_n + kind) % 2 + 1]
    d.x = t.cx - t.wb + 2 + (tick_n * 7 + kind * 5) % (t.wb * 2 - 3)
  end
  function M.stab(notes)
    if type(notes) ~= "table" then notes = {60} end
    for i = 1, math.min(#notes, 4) do
      local n = K.num(notes[i], 60)
      bni = bni % #bands + 1
      bands[bni].t = K.NOW
      bands[bni].y = 16 + clamp((n - 40) / 50, 0, 1) * 32
    end
    if #notes == 0 then bands[1].t = K.NOW end
  end
  function M.arp(_, note, _)
    vni = vni % #vents + 1
    vents[vni].t = K.NOW
    vents[vni].x = K.px(K.num(note, 72))
  end
  function M.pad(notes)
    pad_notes = {}
    if type(notes) == "table" then
      for i = 1, math.min(#notes, 6) do pad_notes[i] = K.num(notes[i], 50) end
    end
  end
  function M.bar() end

  -- a bar w wide whose left edge sits at a fractional x: the end pixels share the level
  local function sbar(l, x, y, w)
    local ix = math.floor(x)
    local fx = x - ix
    if fx == 0 then put(l, ix, y, w, 1); return end
    if w > 1 then put(l, ix + 1, y, w - 1, 1) end
    put(l * (1 - fx), ix, y, 1, 1)
    put(l * fx, ix + w, y, 1, 1)
  end
  -- K.dashes with each whole dash placed on the sub-pixel (the clipped ones at the ends stay whole)
  local function sdash(l, y, w, gap, off, x0, x1)
    for x = x0 + (off % gap) - gap, x1 - 1, gap do
      local a, b = math.max(x0, x), math.min(x1, x + w)
      if b > a then
        if a == x and b == x + w then sbar(l, x, y, w) else put(l, a, y, b - a, 1) end
      end
    end
  end

  -- a flat ring (an ellipse) at (cx, y), half width r
  local function ring(l, cx, y, r)
    local px, py = cx - r, y
    for i = 1, 8 do
      local a = math.pi * (1 - i / 8)
      local nx, ny = cx + math.cos(a) * r, y - math.sin(a) * r * 0.3
      line(l, px, py, nx, ny)
      px, py = nx, ny
    end
    px, py = cx - r, y
    for i = 1, 8 do
      local a = math.pi * (1 - i / 8)
      local nx, ny = cx + math.cos(a) * r, y + math.sin(a) * r * 0.3
      line(l, px, py, nx, ny)
      px, py = nx, ny
    end
  end

  function M.draw(S)
    local T, DT, NOW, e = K.T, K.DT, K.NOW, K.energy
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    local fine, dense, RT = K.detail ~= "classic", K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.25 end     -- barely above 1: the frame-change bound is tight here
    local fp = fine and K.playing                   -- time-driven fine detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RT, 13) or l end
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local kk, pf, bt = fade(kick_t, 0.3), fade(pump_t, 0.3), fade(bass_t, 0.3)
    local thick = clamp(0.35 + 0.5 * e + 0.5 * pdz + 0.3 * lo, 0, 1.4)

    -- the sky: a faint glow low over the plain, thicker with the level
    K.haze(0, 38, 128, GY, 0.1 + 0.3 * amp + 0.3 * pdz, 1.2 + pdz, T * 2)
    for y = 8, 36, 7 do
      if amp > 0.2 then K.dashes(math.min(fine and 2.5 or 1.5, amp * (fine and 2.5 or 1.5)), y, 2, 11, y * 5 + T * 4, 0, 128) end
    end
    -- the pad: a soft lamp-glow on the horizon under each note
    for i = 1, #pad_notes do
      local x = K.px(pad_notes[i])
      put(1.5 + (fine and 3.6 or 3) * pdz, x - 1, GY - 3, 3, 1)
      put((fine and 1.9 or 1.5) * pdz, x - 6, GY - 2, 13, 1)
    end

    if hi > 0.04 then
      K.dashes(hi * 3.5, GY + 4, 1, 6, T * 7, 0, 128); K.dashes(hi * 3, GY + 8, 1, 8, -T * 5, 0, 128)
      K.dashes(hi * 3, 30, 1, 9, T * 6, 0, 128)
    end
    -- the horizon, a few far lights on the plain
    line(1.5, 0, GY, 127, GY)
    K.dashes(0.8, GY + 3, 2, 10, 3, 0, 128)
    K.dashes(0.8, GY + 6, 1, 8, 1, 0, 128)
    for i = 1, 5 do
      local x = 4 + (i * 53) % 120
      if (x < TW[1].cx - 24 or x > TW[1].cx + 24) and (x < TW[2].cx - 16 or x > TW[2].cx + 16) then
        put(1.5 + (math.floor(T * 0.8 + i) % 3 == 0 and 1.5 or 0), x, GY - 1 - i % 2, 1, 1)
      end
    end

    for ti = 2, 1, -1 do
      local t = TW[ti]
      local sc = ti == 1 and 1 or 0.7
      -- the shell: both outlines, the rim, faint ribs
      local lx, ly, rx, ry
      for y = t.top, GY, 3 do
        local yy = math.min(y, GY)
        local w = hw(t, yy)
        if lx then
          line((fine and 2 or 2.4) + (fine and 2.6 or 1.5) * kk, lx, ly, t.cx - w, yy)
          line((fine and 2.8 or 2.4) + (fine and 2.6 or 1.5) * kk, rx, ry, t.cx + w, yy)     -- fine: the horizon's glow on the right
        end
        lx, ly, rx, ry = t.cx - w, yy, t.cx + w, yy
      end
      local w = hw(t, GY)
      line(2.4, lx, ly, t.cx - w, GY); line(2.4, rx, ry, t.cx + w, GY)
      local wr = hw(t, t.top)
      line(3.2, t.cx - wr, t.top, t.cx + wr, t.top)
      line(1.4, t.cx - wr + 1, t.top + 1, t.cx + wr - 1, t.top + 1)
      for _, f in ipairs(dense and RIBS_DENSE or RIBS) do
        local px, py = t.cx + f * wr, t.top + 2
        for y = t.top + 6, GY, 6 do
          local nx = t.cx + f * hw(t, y)
          line(0.6 + (fine and 1.8 * mid + 0.9 * hi or 1.2 * mid), px, py, nx, y)
          px, py = nx, y
        end
      end
      -- the base: the arches, lit by the bass
      local bw = hw(t, GY)
      line(1.5 + (fine and 6.5 or 5) * bt, t.cx - bw, GY - 3, t.cx + bw, GY - 3)
      for x = t.cx - bw + 3, t.cx + bw - 2, 5 do
        put(1.2 + (fine and 7.5 or 6) * bt, x, GY - 2, 3, 2)
      end
      if bt > 0.04 then
        put(E(3.5 * bt), t.cx - bw - 2, GY + 1, bw * 2 + 5, 1)
        put(E(2.5 * bt), t.cx - bw - 6, GY + 2, bw * 2 + 13, 1)
        put(E(1.8 * bt), t.cx - bw - 10, GY + 4, bw * 2 + 21, 1)
        put(E(4 * bt), t.cx - bw, GY - 5, bw * 2, 1)
        if fine then put(E(3 * bt), t.cx - bw, GY - 7, bw * 2, 1) end
      end

      -- the plume: puffs climbing from the rim, spreading and drifting
      local n = math.min(NP, 3 + math.floor(thick * 6))
      for k = 0, n - 1 do
        local u = ((T * (0.05 + 0.04 * e) * sc + k / NP + ti * 0.31) % 1)
        local y = t.top - 2 - u * 30 * (0.7 + 0.3 * thick)
        local r = (wr * 0.6 + 14 * u * (0.6 + 0.6 * thick)) * (1 - 0.5 * pf)
        local x = t.cx + math.sin(T * 0.4 + k * 1.7 + ti) * 5 * u + 12 * u * u
        local l = (2.2 + 2.4 * thick) * (1 - u * 0.6)
        if y > 0 and l > 0.5 then
          if fine then
            -- the puff's grain slides on the sub-pixel
            sdash(l * 1.1, y, 2, 3, k * 3 + T * 5, x - r, x + r)
            sdash(l * 0.8, y + 2, 2, 3, k * 5 - T * 4, x - r * 0.7, x + r * 0.7)
          else
            K.dashes(l, y, 2, 3, k * 3 + T * 5, x - r, x + r)
            K.dashes(l * 0.7, y + 2, 2, 3, k * 5 - T * 4, x - r * 0.7, x + r * 0.7)
          end
          if r > 9 then K.dashes(l * 0.6, y - 2, 2, 4, k - T * 3, x - r * 0.5, x + r * 0.5) end
        end
      end
      -- dense: wisps of vapour peel off the plume and drift up on the sub-pixel
      if dense and fp then
        for k = 1, 5 do
          local u = (T * 0.025 + k * 0.2 + ti * 0.13) % 1
          K.put_sub(1.8 * (1 - u * 0.7), t.cx + math.sin(T * 0.3 + k * 2.1) * 6 * u + 14 * u * u, t.top - 2 - u * 36, 1, 1)
        end
      end
      -- glitter in the steam
      K.grain(function(a, b) return t.cx + (a - 0.5) * 30, t.top - 4 - b * 26 end, hi * (fine and 95 or 70), 8)
      if hi > 0.04 then
        K.dashes(hi * 4, t.top - 8, 1, 6, T * 8, t.cx - 14, t.cx + 14)
        K.dashes(hi * 3.5, t.top - 16, 1, 7, -T * 6, t.cx - 16, t.cx + 16)
      end
      if pf > 0.04 then
        local w = hw(t, t.thr)
        put(E(5 * pf), t.cx - w - 2, t.thr, w * 2 + 5, 1)
        put(E(3 * pf), t.cx - w - 5, t.thr - 1, w * 2 + 11, 1)
        put(E(3 * pf), t.cx - w - 5, t.thr + 1, w * 2 + 11, 1)
        put(E(4 * pf), t.cx - wr, t.top - 4, wr * 2, 1)
      end

      -- the kick's ring, up the plume
      for i = 1, #rings do
        local g = rings[i]
        local a = NOW - g.t - (ti - 1) * 0.1
        if a >= 0 and a < 0.7 then
          local u = a / 0.7
          local y = t.top - 1 - u * 24
          local r = wr * (0.9 + 0.6 * u)
          local l = (fine and 7.8 or 6) * (1 - u) * (g.tw == ti and 1 or 0.75)
          if y > 0 then
            ring(math.max(1, l), t.cx + 12 * u * u, y, r)
            put(math.max(1, l * 0.4), t.cx - r - 3 + 12 * u * u, y, r * 2 + 7, 1)
          end
        end
      end
    end

    -- aircraft warning lights on the rims: the hats
    for ti = 1, 2 do
      local t = TW[ti]
      local f = fade(lights[ti], 0.14)
      local wr = hw(t, t.top)
      local idle = (math.floor(T * 0.7 + ti * 0.5) % 4 == 0) and 3 or 1.3
      for _, sx in ipairs(SIDES) do
        local x = t.cx + sx * wr
        put(idle + (fine and 9.5 or 8) * f, x - 1, t.top - 2, 2, 2)
        if f > 0 then
          put(E(5 * f), x - 4, t.top - 1, 9, 1)
          put(E(3 * f), x - 7, t.top, 15, 1)
          put(E(3 * f), x, t.top - 5, 1, 7)
          if fine then put(E(2.6 * f), x - 2, t.top - 4, 5, 5) end
        end
      end
    end

    -- the clap: a fan of vapour off the near rim of one tower
    local cf = fade(clap_t, 0.2)
    if cf > 0 then
      local t = TW[clap_tw]
      local wr = hw(t, t.top)
      for i = -3, 3 do
        local a = i * 0.32
        local len = 12 * (1 - cf * 0.4)
        line((fine and 7 or 6) * cf, t.cx + i * wr / 3.5, t.top - 3, t.cx + i * wr / 3.5 + math.sin(a) * len * 1.8, t.top - 3 - math.cos(a) * len)
      end
      put(E(3 * cf), t.cx - wr - 4, t.top - 4, wr * 2 + 9, 1)
    end

    -- lamps on the shells: the perc
    for i = 1, #lamps do
      local l = lamps[i]
      local f = fade(l.t, 0.4)
      if f > 0 then
        local t = TW[l.tw]
        local x = t.cx + l.side * hw(t, l.y)
        put(E(7 * f), x - 1, l.y, 3, 2)
        put(E(4 * f), x - 5, l.y, 11, 1)
        put(E(3 * f), x - 3, l.y + 2, 7, 1)
        put(E(3 * f), x, l.y - 4, 1, 9)
        if fine then
          -- the ladder up the shell lights rung by rung round the lamp
          local ya, yb = math.max(t.top + 2, l.y - 11), math.min(GY - 1, l.y + 11)
          line(E(4.4 * f), t.cx + l.side * hw(t, ya), ya, t.cx + l.side * hw(t, yb), yb)
          for ry = ya, yb, 3 do put(E(5 * f), t.cx + l.side * hw(t, ry) - 2, ry, 5, 1) end
          put(E(3 * f), x - 8, l.y - 1, 17, 3)
        end
      end
    end

    -- floodlit bands across the shells: the stabs
    for i = 1, #bands do
      local b = bands[i]
      local f = fade(b.t, 0.4)
      if f > 0 then
        for ti = 1, 2 do
          local t = TW[ti]
          if b.y > t.top + 1 then
            local w = hw(t, b.y)
            put(E((fine and 5.6 or 5) * f), t.cx - w, b.y, w * 2, 1)
            put(E((fine and 3.4 or 3) * f), t.cx - w * 0.8, b.y + 2, w * 1.6, 1)
            put(E(2 * f), t.cx - w * 0.6, b.y - 2, w * 1.2, 1)
          end
        end
      end
    end

    -- drips from the base: the ticks
    for i = 1, #drips do
      local d = drips[i]
      local a = NOW - d.t
      local life = fine and 0.5 * TR() or 0.35
      if a < life then
        local u = a / life
        local y = GY - 6 + u * 9
        local v = fine and E(1.3 * (1 - u)) or (1 - u)
        put(8 * v, d.x, y, 1, 4)
        put(5 * v, d.x - 1, y - 6, 3, 1)
        put(3 * v, d.x - 7, GY - 1, 15, 1)
        put(3 * v, d.x - 5, GY - 12, 11, 1)
        put(4 * v, d.x, GY - 8, 1, 2)
        put(4 * v, d.x - 3 - d.k, GY + 3, 7 + d.k * 2, 1)
        put(3 * v, d.x - 1, y - 4, 1, 3)
        if fine then
          -- the drop's streak down the shell and its splash on the plain
          line(2.6 * v, d.x, GY - 16, d.x, GY - 7)
          put(3.4 * v, d.x - 2, GY + 1, 5, 2)
          put(2.6 * v, d.x - 5 - d.k, GY + 5, 11 + d.k * 2, 1)
        end
      end
    end

    -- vents on the plain: the arps
    for i = 1, #vents do
      local v = vents[i]
      local f = fade(v.t, 0.4)
      if f > 0 then
        local a = NOW - v.t
        if fine then
          -- the jet rises on the sub-pixel: its top and bottom pixels share the level
          local vy = GY - 3 - a * 10
          local iy = math.floor(vy)
          local fy = vy - iy
          put(E(6 * f), v.x, iy + 1, 1, 3)
          put(E(6 * f) * (1 - fy), v.x, iy, 1, 1)
          put(E(6 * f) * fy, v.x, iy + 4, 1, 1)
        else
          put(5 * f, v.x, GY - 3 - a * 10, 1, 4)
        end
        put(E(3 * f), v.x - 2, GY - 6 - a * 14, 5, 1)
        put(E(2.5 * f), v.x - 4, GY - 9 - a * 18, 9, 1)
        put(E(3 * f), v.x - 3, GY, 7, 1)
        put(E(4 * f), v.x - 1, GY - 12 - a * 20, 3, 1)
        put(E(2.5 * f), v.x - 7, GY - 4 - a * 6, 15, 1)
        put(E(2 * f), v.x, GY - 22 - a * 20, 1, 8)
        if fine then put(E(4 * f), v.x - 5, GY + 1, 11, 1); put(E(3 * f), v.x - 2, GY - 15 - a * 22, 5, 1); put(E(3.2 * f), v.x - 1, GY - 3, 3, 3) end
      end
    end
  end

  M.init()
  return M
end
