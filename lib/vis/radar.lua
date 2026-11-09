-- radar: a round scope at night, top-down. rings and a bearing cross on
-- black, a sweep arm turning about once a bar and leaving a phosphor
-- wake. every hit leaves a blip that flares, then glows again each time
-- the arm passes and fades over a few seconds, so the scope fills with
-- what is playing. the bass sits on the inner ring (its note the bearing),
-- the arps on the next, the stabs and percs on the middle rings, the hats
-- and ticks on the outer rim. a kick pings a ring out from the centre, a
-- pump swells the range rings, a clap flares a sector, the pad is weather
-- drifting over the scope. the lows light the centre, the mids the rings,
-- the highs speckle the clutter, the level brightens the arm
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp
  local TAU = K.TAU
  local CX, CY = 64, 32
  local R = 30
  local RING = {8, 14, 20, 26}

  -- circles as polylines, built once
  local NSEG = 40
  local function circle(r)
    local c = {}
    for i = 0, NSEG do
      local a = i / NSEG * TAU
      c[i] = {CX + math.cos(a) * r, CY + math.sin(a) * r}
    end
    return c
  end
  local CIRC = {}
  for i, r in ipairs(RING) do CIRC[i] = circle(r) end
  local RIM = circle(R)
  local function draw_circle(l, c)
    local p = c[0]
    for i = 1, NSEG do
      local q = c[i]
      line(l, p[1], p[2], q[1], q[2])
      p = q
    end
  end

  local function arc(l, a0, a1, r)
    local n = math.max(2, math.floor(math.abs(a1 - a0) * r / 3))
    local px, py = CX + math.cos(a0) * r, CY + math.sin(a0) * r
    for j = 1, n do
      local a = a0 + (a1 - a0) * j / n
      local x, y = CX + math.cos(a) * r, CY + math.sin(a) * r
      line(l, px, py, x, y)
      px, py = x, y
    end
  end

  local sa = -TAU / 4                    -- the arm's bearing
  local blips, bi = {}, 0
  for i = 1, 40 do blips[i] = {on = false, a = 0, r = 0, t = 0, lv = 0, sz = 1, sp = false} end
  local pings = {}                       -- kick rings: start times
  local sector = {a = 0, t = -99}        -- a clap's wedge
  local cells = {{a = 0, t = -99, w = 0.5}, {a = 0, t = -99, w = 0.5}}
  local ci = 0
  local pump_t, kick_t, bass_t, arp_t = -99, -99, -99, -99
  local hats_n, tick_n, bass_n = 0, 0, 0
  local pdz = 0

  local function blip(a, r, lv, sz, spoke)
    bi = bi % #blips + 1
    local b = blips[bi]
    b.on, b.a, b.r, b.t, b.lv, b.sz, b.sp = true, a, r, K.NOW, lv, sz or 1, spoke
  end
  local function bearing(n) return (K.num(n, 60) % 12) / 12 * TAU - TAU / 4 end

  function M.init()
    sa = -TAU / 4
    for _, b in ipairs(blips) do b.on = false end
    bi = 0
    pings = {}
    sector.t = -99
    for _, c in ipairs(cells) do c.t = -99 end
    bass_n = 0
    ci, pump_t, kick_t, bass_t, arp_t, hats_n, tick_n, pdz = 0, -99, -99, -99, -99, 0, 0, 0
  end
  M.clear = M.init

  function M.kick() kick_t = K.NOW; pings[#pings + 1] = K.NOW; if #pings > 3 then table.remove(pings, 1) end end
  function M.pump() pump_t = K.NOW end
  function M.hat()
    hats_n = hats_n + 1
    blip(hats_n * 2.399, RING[4], 7, 4)
  end
  function M.clap()
    sector.a = sa + math.pi * (0.4 + 0.6 * K.hash(math.floor(K.NOW * 10), 5)); sector.t = K.NOW
  end
  function M.perc(voice, note)
    voice = clamp(math.floor(K.num(voice, 1)), 1, 4)
    blip(bearing(note), RING[2] + (voice - 1) * 3, 7, 3)
  end
  function M.tick(kind)
    kind = clamp(math.floor(K.num(kind, 1)), 1, 4)
    tick_n = tick_n + 1
    blip((kind + tick_n * 0.07) * TAU / 4 + 0.3, RING[3] + 3, 7, 2)
  end
  function M.stab(notes)
    for i = 1, 4 do blip(bearing(K.chord[i]), RING[3], 6, 2) end
  end
  function M.bass(note)
    bass_t = K.NOW; bass_n = bass_n + 1
    blip(bearing(note) + 0.12 * (bass_n % 5), RING[1], 7, 4, true)
    blip(bearing(note) - 0.18, RING[1] - 3, 5, 2)
  end
  function M.arp(lane, note, step)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    arp_t = K.NOW
    blip(bearing(note) + lane * 0.4, RING[2] - 3 + lane * 0.5, 7, 3, true)
  end
  function M.pad(notes)
    ci = ci % 2 + 1
    local c = cells[ci]
    c.a = bearing(notes and notes[1] or 50); c.t = K.NOW
    c.w = 0.45 + 0.1 * K.hash(math.floor(K.NOW * 7), 9)
  end
  function M.bar() end

  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / tau)
    return v < 0.03 and 0 or v
  end

  function M.draw(S)
    local T, DT, e, NOW = K.T, K.DT, K.energy, K.NOW
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    local kl = K.kickless
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)

    -- the arm: once a bar, a little quicker as the set builds
    sa = sa + K.DTS * TAU / (K.beat_sec * 4) * (0.9 + 0.2 * e)
    if sa > 1e4 then sa = sa - 1e4 * 0 - math.floor(sa / TAU) * TAU end

    local pmp = fade(pump_t, 0.3)
    local bt, at = fade(bass_t, 0.3), fade(arp_t, 0.3)
    if bt > 0.03 then draw_circle(4 * bt, CIRC[1]); draw_circle(2 * bt, CIRC[1]) end
    if at > 0.03 then draw_circle(3.5 * at, CIRC[2]) end
    local kk = fade(kick_t, 0.3)

    -- the scope: rim, range rings, bearing cross, rim ticks
    draw_circle(1.5 + 0.5 * amp, RIM)
    for i = 1, 4 do
      draw_circle(0.8 + mid * 1.2 + 4.5 * pmp * (i == 2 and 1 or 0.7) + (i == 1 and lo * 2 or 0), CIRC[i])
    end
    local cl = 1 + 0.8 * K.duck + 0.5 * mid
    line(cl, CX - R, CY, CX + R, CY); line(cl, CX, CY - R, CX, CY + R)
    for k = 0, 23 do
      local a = k / 24 * TAU + T * 0.12
      local c, s = math.cos(a), math.sin(a)
      local len = (k % 6 == 0) and 3 or 1.5
      line(k % 6 == 0 and 3 or 1.5, CX + c * (R + 1), CY + s * (R + 1), CX + c * (R + 1 + len), CY + s * (R + 1 + len))
    end

    -- weather: dither drifting over the mid rings with the pad
    for ci2 = 1, 2 do
      local c = cells[ci2]
      local age = NOW - c.t
      if age >= 0 and age < 14 then
        local lv = math.min(1, age / 1.5) * math.exp(-age / 6) * (1 + 0.8 * pdz)
        if lv > 0.1 then
          local a0 = c.a + T * 0.05
          for ri = 0, 3 do
            local r = 12 + ri * 4.5
            local n = math.floor(c.w * r / 1.6)
            for j = 0, n do
              local a = a0 + (j / n - 0.5) * c.w
              if (j + ri) % 2 == 0 then
                put(1.6 * lv, CX + math.cos(a) * r, CY + math.sin(a) * r, 1, 1)
              end
            end
          end
        end
      end
    end

    for ci2 = 1, 2 do
      local c = cells[ci2]
      local f = fade(c.t, 0.35)
      if f > 0.03 then arc(5 * f, c.a - c.w, c.a + c.w, R - 2); arc(3 * f, c.a - c.w, c.a + c.w, R - 5) end
    end
    -- the pad itself, before any cell: a faint cloud at the rim
    if pdz > 0.03 then
      local a = T * 0.3
      put(2 * pdz, CX + math.cos(a) * 28, CY + math.sin(a) * 28, 2, 2)
    end

    -- a clap's sector: a wedge of lines from the hub
    local sc = fade(sector.t, 0.3)
    if sc > 0.03 then
      for k = -3, 3 do
        local a = sector.a + k * 0.07
        line(5 * sc * (1 - math.abs(k) / 5), CX + math.cos(a) * 6, CY + math.sin(a) * 6,
          CX + math.cos(a) * R, CY + math.sin(a) * R)
      end
    end

    -- kick pings: a ring spreading out from the hub
    for i = #pings, 1, -1 do
      local age = NOW - pings[i]
      if age > 0.3 then table.remove(pings, i)
      else
        local r = 2 + age / 0.3 * (R - 2)
        local lv = 6.5 * (1 - age / 0.3)
        local prev
        local n = 24
        local px, py = CX + r, CY
        for j = 1, n do
          local a = j / n * TAU
          local x, y = CX + math.cos(a) * r, CY + math.sin(a) * r
          line(lv, px, py, x, y)
          local x2, y2 = CX + math.cos(a) * (r - 1.5), CY + math.sin(a) * (r - 1.5)
          line(lv * 0.5, px, py, x2, y2)
          px, py = x, y
        end
      end
    end

    if lo > 0.03 then draw_circle(lo * 3.5, CIRC[1]); draw_circle(lo * 2.5, CIRC[2]); arc(lo * 3, 0, TAU, 6); arc(lo * 2.5, 0, TAU, 4) end
    -- the hub: lit by the lows and the kick
    put(2 + 4 * kk + 2 * lo + 2 * K.duck, CX - 2, CY - 2, 5, 5)

    -- the wake and the arm
    local lenw = 0.35 + 0.35 * e
    for k = 0, 3 do
      local a = sa - k / 3 * lenw
      local l = (1.8 + 2.4 * amp) * (1 - k / 4) ^ 2 + (k == 0 and 1.5 or 0)
      local ca, sn = math.cos(a), math.sin(a)
      line(l, CX + ca * 3, CY + sn * 3, CX + ca * R, CY + sn * R)
    end

    -- the blips: a flare when struck, then the phosphor of the last pass
    for _, b in ipairs(blips) do
      if b.on then
        local age = NOW - b.t
        if age > 9 then b.on = false
        else
          local since = (sa - b.a) % TAU
          local ph = 3.2 * math.exp(-since / 2.4) * (1 - age / 9)
          local fl = b.lv * math.exp(-age / 0.3)
          local l = math.max(fl, ph) + 0.4 * math.min(fl, ph)
          if l > 0.5 then
            local x, y = CX + math.cos(b.a) * b.r, CY + math.sin(b.a) * b.r
            local s = b.sz
            if fl > 1.5 and b.r < RING[4] - 0.5 then
              put(fl * 0.5, x - s // 2 - 1, y - s // 2 - 1, s + 2, s + 2)
              arc(fl * 0.7, b.a - 0.16, b.a + 0.16, b.r + 2.5)
              arc(fl * 0.7, b.a - 0.16, b.a + 0.16, b.r - 2.5)
            end
            if b.sp and fl > 0.8 then line(fl * 0.7, CX, CY, x, y) end
            put(l, x - s // 2, y - s // 2, s, s)
          end
        end
      end
    end

    -- the highs glitter on the rim and the outer ring
    if hi > 0.03 then
      for k = 0, 35 do
        local ph = math.sin(T * (0.8 + K.hash(k, 3) * 1.4) + k * 1.7)
        if ph > -0.2 then
          local a = (k + K.hash(k, 4)) / 36 * TAU
          put(hi * 6 * ph, CX + math.cos(a) * (R - 0.5 * (k % 3)), CY + math.sin(a) * (R - 0.5 * (k % 3)), 2, 2)
          put(hi * 4 * ph, CX + math.cos(a) * RING[4], CY + math.sin(a) * RING[4], 2, 2)
        end
      end
    end

    -- clutter: the highs speckle the scope, kickless stretches more so
    K.grain(function(u, v)
      local a, r = u * TAU, 6 + v * 22
      return CX + math.cos(a) * r, CY + math.sin(a) * r
    end, hi * 30 + kl * 5, 3.5)
  end

  M.init()
  return M
end
