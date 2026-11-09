-- dubplate: a record turning under a lamp, seen from the side of the deck.
-- the vinyl is black; its grooves show only where they catch the lamp, in
-- two wedges of sheen either side of the centre. the record turns once a
-- bar, locked to the bar phase, so the label's mark passes under the stylus
-- on every downbeat, and the tonearm creeps inward over the phrase. stabs
-- catch a glint along the groove at each chord voice's radius that rides
-- round with the record; arp notes drop dust on their lane's ring of the
-- groove where the stylus is, which comes round each revolution and
-- crackles as it passes under it. the strobe dots on the platter's rim
-- stand still (the deck is in time) and flicker with the pump; the bass
-- makes the plate ride its warp and glows under the plinth; the highs are
-- crackle. kickless stretches let the haze into the lamp light and widen
-- the sheen
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp
  local TAU = K.TAU

  local CX, CY, RX, RY = 54, 33, 44, 18   -- the record
  local PX, PY = 116, 13                  -- the tonearm's pivot
  local SA = -0.25                        -- the stylus's angle on the plate
  local LMX, LMY = 6, 3                   -- the lamp
  local MAXD = 24
  local GR = {0.44, 0.5, 0.56, 0.62, 0.71, 0.77, 0.83, 0.89, 0.95}

  local dust, glints
  local rot, armr, bs, lamp, sw, warp

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own
  local hit, percs = {}, {}
  local pdz = 0                           -- the pad, eased in
  local function mark(k) hit[k] = K.NOW; hit[k .. "n"] = (hit[k .. "n"] or 0) + 1 end
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
  function M.tick(kind) mark("tick"); hit.tk = clamp(math.floor(K.num(kind, 1)), 0, 99) % 2 end
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, a = -rot + (math.floor(K.num(note, 60)) % 12) / 12 * TAU,
      r = 0.45 + (clamp(math.floor(K.num(voice, 1)), 1, 4) - 1) * 0.15}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    dust, glints = {}, {}
    rot, armr, bs, lamp, sw, warp = 0, 0.93, 0, 0.6, 0, 0
    hit, percs, pdz = {}, {}, 0
  end
  M.clear = M.init

  local function wrap(a) return (a + math.pi) % TAU - math.pi end

  -- a point on the plate at radius r (0..1) and screen angle a
  local function pt(r, a, dy)
    return CX + math.cos(a) * r * RX, CY + math.sin(a) * r * RY + (dy or 0)
  end

  -- an arc of the plate at radius r from a0 to a1, in n segments
  local function arc(l, r, a0, a1, n, dy)
    local x0, y0 = pt(r, a0, dy)
    for k = 1, n do
      local x1, y1 = pt(r, a0 + (a1 - a0) * k / n, dy)
      line(l, x0, y0, x1, y1)
      x0, y0 = x1, y1
    end
  end

  function M.stab(notes)
    for i = 1, 4 do
      local n = K.num(notes[i], 60)
      -- low voices on the outer grooves, high toward the label
      local r = clamp(0.95 - (n - 44) / 36 * 0.5, 0.45, 0.95)
      glints[i] = {r = r, a = SA - rot + 0.15 * i, t0 = K.T}
    end
  end

  function M.arp(lane, note)
    mark("arp")
    if #dust >= MAXD then table.remove(dust, 1) end
    local r = 0.5 + lane * 0.1 + (K.num(note, 72) % 5) * 0.012
    dust[#dust + 1] = {r = r, a = SA - rot, t0 = K.T, lane = lane, hit = 0, last = 0}
  end

  function M.draw(S)
    local T, DT, DTS = K.T, K.DT, K.DTS
    local kl = K.kickless
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local kk, hh, cl, bh, tk = fade("kick", 0.3), fade("hat", 0.3), fade("clap", 0.3), fade("bass", 0.4), fade("tick", 0.4)
    local pd = pdz
    -- once a bar, locked to the bar phase while playing
    local rate = TAU / ((K.beats or 4) * K.beat_sec)
    rot = rot + rate * DTS
    if K.playing then rot = rot + wrap(K.bar_ph * TAU - rot) * math.min(1, DT * 2) end
    rot = rot % TAU
    local prog = 0
    if type(S) == "table" then
      prog = clamp((K.num(S.track_bar, 1) % math.max(1, K.num(S.phrase_len, 32))) / math.max(1, K.num(S.phrase_len, 32)), 0, 1)
    end
    armr = K.follow(armr, 0.93 - prog * 0.42, 1.5, DT)
    bs = K.follow(bs, math.max(K.env.bass * 0.8, A[K.LO]) * (K.gain(S, "bass") > 0 and 1 or 0.5), 0.07, DT)
    lamp = K.follow(lamp, (1 - K.duck * 0.6) * (0.7 + 0.3 * A[K.AMP]) + K.env.kick * 0.3 + 0.4 * pd, 0.05, DT)
    sw = K.follow(sw, kl, 1.5, DT)
    warp = math.sin(rot) * (0.3 + bs * 1.2)

    -- the plinth and the lamp's light falling across it
    line(1.2, 5, 6, 122, 6)
    line(1.2, 5, 6, 1, 57)
    line(1.2, 122, 6, 126, 57)
    line(2, 0, 58, 127, 58)
    line(1.5, 0, 61, 127, 61)
    -- start / stop lit while playing; the pitch fader at the tempo
    put(K.playing and (3 + 3 * lamp) or 1.5, 5, 51, 5, 3)
    put(1.5, 118, 39, 1, 15)
    -- a tick blinks the start / stop light or the pitch fader
    if tk > 0.03 then
      if hit.tk == 0 then put(6 * tk, 3, 49, 9, 7) else put(4 * tk, 114, 38, 9, 17) end
    end
    local tp = clamp((K.num(S.tempo, 124) - 100) / 50, 0, 1)
    put(4, 116, 52 - tp * 12, 5, 2)
    K.gradient(59, 63, function(y) return bs * 1.6 * (y - 58) / 5 end)
    -- a bass note lights the plinth's underside in dashes that step along
    if bh > 0.03 then
      for y = 59, 63 do K.dashes(5 * bh, y, 10, 4, (hit.bassn or 0) * 3 + y * 2, 0, 128) end
    end
    put(4 + lamp * 5, LMX - 3, LMY, 8, 2)
    put(2, LMX - 1, 0, 2, LMY)
    K.haze(0, 4, 70, 44, 0.04 + 0.16 * sw + 0.08 * K.throw + 0.14 * pd, 1, T * 2)

    -- the platter's rim under the record, its strobe dots standing still
    -- and flickering with the pump
    local pr = 1.07
    arc(2, pr, 0.05, math.pi - 0.05, 12, 3)
    arc(2.5, pr, -0.15, math.pi + 0.15, 14, 0)
    for k = 0, 35 do
      local a = k / 36 * TAU + 0.04
      if math.sin(a) > 0.15 then
        local x, y = pt(pr, a, 1.5)
        put((2 + 6 * lamp) * (k % 2 == 0 and 1 or 0.55), x, y, 2, 1)
        -- a kick lights every third dot, a different third each time
        if kk > 0.03 and (k + (hit.kickn or 0)) % 3 == 0 then put(6 * kk, x - 1, y - 1, 4, 3) end
      end
    end
    if kk > 0.03 then arc(4 * kk, pr, 0.05, math.pi - 0.05, 12, 3) end

    -- the record: its edge, the gaps between tracks, the grooves where they
    -- catch the light
    arc(2.5, 1, 0, TAU, 28, warp)
    arc(1.5, 0.66, 0, TAU, 20, warp * 0.66)
    arc(1.2, 0.8, 0, TAU, 22, warp * 0.8)
    local wd = (0.42 + sw * 0.25 + A[K.MID] * 0.1) * (1.15 - 0.35 * K.duck)
    local sl = 0.25 + 0.9 * lamp
    local hi = A[K.HI]
    for wedge = 0, 1 do
      local c = -2.5 + wedge * math.pi + math.sin(T * 0.07) * 0.08
      for gi, r in ipairs(GR) do
        local g = sl * (wedge == 0 and 1 or 0.7) * (0.7 + 0.3 * ((gi * 7) % 3) / 2)
        local dy = warp * r
        arc(1.5 + 2 * g, r, c - wd, c - wd * 0.35, 2, dy)
        arc(2.5 + 4 * g + hi * 2.5 * ((gi + wedge) % 2), r, c - wd * 0.35, c + wd * 0.35, 2, dy)
        arc(1.5 + 2 * g, r, c + wd * 0.35, c + wd, 2, dy)
      end
    end

    -- the label, turning: its paper, two lines of print, the spindle
    local lr = 0.34
    for dy = -math.floor(lr * RY), math.floor(lr * RY) do
      local u = dy / (lr * RY)
      local hw = math.floor(lr * RX * math.sqrt(math.max(0, 1 - u * u)) + 0.5)
      if hw > 0 then put(2 + lamp * 1.2, CX - hw, CY + dy + warp * 0.3, 2 * hw, 1) end
    end
    -- an arp note lights the next pilot along the plinth's top
    local af = fade("arp", 0.4)
    if af > 0.03 then put(6 * af, 16 + ((hit.arpn or 1) - 1) % 8 * 11, 8, 7, 3) end
    -- a clap swells the label's paper
    if cl > 0.03 then
      put(5 * cl, 0, 0, 14, 8)                       -- and the lamp's shade
      for dy = -math.floor(lr * RY), math.floor(lr * RY) do
        local u = dy / (lr * RY)
        local hw = math.floor(lr * RX * math.sqrt(math.max(0, 1 - u * u)) + 0.5)
        if hw > 0 then put(4.5 * cl, CX - hw, CY + dy + warp * 0.3, 2 * hw, 1) end
      end
    end
    for k = 0, 1 do
      local a = -rot + k * math.pi
      local x0, y0 = pt(0.12, a, warp * 0.3)
      local x1, y1 = pt(0.28, a + 0.5, warp * 0.3)
      line(5 + lamp * 2, x0, y0, x1, y1)
    end
    local mx, my = pt(0.3, -rot + 0.9, warp * 0.3)
    put(7, mx, my, 2, 1)
    put(9, CX, CY + warp * 0.3, 1, 1)

    -- dust: on its ring where it landed, round with the record; it
    -- crackles as it passes under the stylus
    for i = #dust, 1, -1 do
      local d = dust[i]
      local age = T - d.t0
      local life = 16 * K.beat_sec
      if age > life then table.remove(dust, i)
      else
        local a = d.a + rot
        local off = wrap(a - SA)
        if off >= 0 and off < 0.5 and d.last < 0 then d.hit = 1 end
        d.last = off
        d.hit = d.hit * math.exp(-DT / 0.12)
        local x, y = pt(d.r, a, warp * d.r)
        local l = (2 + 1.5 * K.lane_kick[d.lane]) * (1 - age / life) + d.hit * 9
        put(l, x, y, 1, 1)
        if d.hit > 0.3 then put(l * 0.4, x - 1, y, 3, 1) end

      end
    end

    -- a hat scatters specks over the record, new places each time
    if hh > 0.03 then
      local hn = hit.hatn or 0
      for j = 1, 6 do
        local x, y = pt(0.4 + K.hash(hn * 6 + j, 95) * 0.55, K.hash(hn * 6 + j, 96) * TAU - rot, 0)
        put(6 * hh, x - 1, y - 1, 3, 3)
      end
    end
    -- a perc leaves a speck on the groove, round with the record
    for i = #percs, 1, -1 do
      local p = percs[i]
      local v = math.exp(-(K.NOW - p.t) / 0.35)
      if v < 0.03 then table.remove(percs, i)
      else
        local x, y = pt(p.r, p.a + rot, warp * p.r)
        put(6 * v, x - 3, y - 2, 7, 5)
      end
    end
    -- the stabs' glints, riding the groove round
    for i = 1, 4 do
      local g = glints[i]
      if g then
        local age = T - g.t0
        local v = math.exp(-age / 0.5)
        if v < 0.05 then glints[i] = nil
        else
          local a = g.a + rot
          arc(3 + 9 * v * (0.6 + 0.4 * K.voice_kick[i]), g.r, a - 0.25, a + 0.25, 2, warp * g.r)
        end
      end
    end

    -- the tonearm: pivot and counterweight, the arm, the headshell on the
    -- groove, a little light on the stylus
    local sx, sy = pt(armr, SA, warp * armr)
    put(3, PX - 3, PY - 3, 7, 6)
    put(4 + lamp, PX + 3, PY - 2, 5, 4)
    local bx, by = PX - 10, PY + 14
    line(5, PX, PY, bx, by)
    line(5, bx, by, sx + 4, sy - 2)
    line(7, sx + 4, sy - 2, sx, sy)
    put(4, sx - 1, sy - 3, 4, 2)
    put(6 + K.env.kick * 5 + bs * 2, sx, sy, 1, 1)
    put(3, PX - 2, 30, 2, 6)                         -- the arm rest

    -- crackle: the highs as sparks over the record
    K.grain(function(u, v)
      local a, r = u * TAU, 0.4 + v * 0.58
      local x, y = pt(r, a)
      return x, y
    end, A[K.HI] * 70, 9)
  end

  M.init()
  return M
end
