-- pylons: power lines striding across a field at night, three towers
-- going away toward a town's glow, fog lying on the ground. four wires,
-- one per arp lane: each note runs along its wire as a spark, tower to
-- tower. the wires hang in a sag that deepens with the bass and dips on
-- every pump, humming with the lows; stabs ring the insulators, one per
-- chord voice, glowing and crackling with the highs. the warning light on
-- the near tower marks the bar. dub throws send the sparks round again at
-- the echo time; kickless stretches raise the fog and set the wires
-- swaying
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local HY = 45                          -- the horizon
  -- the towers: base x, base y, scale
  local TW = {{x = 24, y = 60, s = 1}, {x = 80, y = 48, s = 0.42}, {x = 113, y = 46, s = 0.2}}

  -- the far treeline, a ragged dark edge on the town's glow
  local trees = K.profile(function(x)
    return HY - 1 - math.floor(K.hash(x // 3, 71) * 2.5) - (x > 40 and x < 62 and math.floor(K.hash(x // 2, 72) * 3) or 0)
  end)

  -- where each wire is held: the insulator's foot under each arm tip
  local function tips(t)
    local s = t.s
    local hang = math.max(1, 3 * s)
    return {
      {t.x - 11 * s, t.y - 48 * s, hang}, {t.x + 11 * s, t.y - 48 * s, hang},
      {t.x - 14 * s, t.y - 39 * s, hang}, {t.x + 14 * s, t.y - 39 * s, hang},
    }
  end
  local TIP = {}
  for i, t in ipairs(TW) do TIP[i] = tips(t) end
  -- each wire's four spans, built once: in from the left (only its last
  -- stretch is on screen), tower to tower, and out to the right
  local SPANS = {}
  for i = 1, 4 do
    local p0 = {TIP[1][i][1] - 70, TIP[1][i][2] - 22, 0}
    SPANS[i] = {{p0, TIP[1][i], 1.6}, {TIP[1][i], TIP[2][i], 1}, {TIP[2][i], TIP[3][i], 0.45},
      {TIP[3][i], {TIP[3][i][1] + 40, TIP[3][i][2] + 3, 0}, 0.25}}
  end

  local ring = {0, 0, 0, 0}              -- each insulator's stab, eased
  local sag, sway = 0, 0                 -- the wires' extra sag (bass), eased
  local sparks = {}
  local pump_t = -99

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own
  local hit, arps, percs = {}, {-99, -99, -99, -99}, {}
  local acnt = {0, 0, 0, 0}             -- arp notes so far, per lane
  local pdz, mz = 0, 0  -- the pad, eased in
  -- the fades follow the trails setting; at fine it acts at half strength and never moves them by more than 15% or 10%
  local function TR() return K.detail ~= "classic" and math.min(1.1, math.max(0.85, K.trail ^ 0.5)) or K.trail end
  local function mark(k) hit[k] = K.NOW; hit[k .. "n"] = (hit[k .. "n"] or 0) + 1 end
  local function fade(k, tau)
    local t = hit[k]
    if not t then return 0 end
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    if v < 0.02 then hit[k] = nil; return 0 end
    return v
  end
  function M.kick() mark("kick") end
  function M.stab() mark("stab") end
  function M.hat() mark("hat") end
  function M.clap() mark("clap") end
  function M.tick(kind) mark("tick"); hit.tk = clamp(math.floor(K.num(kind, 1)), 0, 99) % 2 + 2 end
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, v = clamp(math.floor(K.num(voice, 1)), 1, 4),
      n = math.floor(K.num(note, 60)) % 12}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    ring, sag, sway, sparks, pump_t = {0, 0, 0, 0}, 0, 0, {}, -99
    hit, arps, percs, pdz, mz = {}, {-99, -99, -99, -99}, {}, 0, 0
    acnt = {0, 0, 0, 0}
  end

  function M.pump() pump_t = K.NOW end

  function M.arp(lane, note)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    arps[lane] = K.NOW; acnt[lane] = acnt[lane] + 1
    local fb, et = K.echo_fb, K.echo_t * K.SP
    local a = 1
    for k = 0, 3 do
      if k > 0 then a = a * fb * (0.3 + 0.7 * K.throw); if a < 0.2 then break end end
      if #sparks >= 40 then break end
      -- higher notes run faster
      sparks[#sparks + 1] = {lane = lane, t0 = K.T + k * et, a = a,
        dur = clamp(2.2 - (K.num(note, 72) - 60) * 0.03, 0.9, 2.6)}
    end
  end

  -- a wire span's point at u (0..1) between two holds, hung by its sag
  local function span_pt(p, q, u, sg)
    local x = p[1] + (q[1] - p[1]) * u
    local y = p[2] + p[3] + (q[2] + q[3] - p[2] - p[3]) * u + sg * 4 * u * (1 - u)
    return x, y
  end

  -- a lattice tower from lines, its arms and insulators
  local function tower(t, l, rl)
    local x, y, s = t.x, t.y, t.s
    local wy, ty = y - 34 * s, y - 52 * s
    local b, w, h = 9 * s, 3 * s, 2 * s
    line(l, x - b, y, x - w, wy); line(l, x + b, y, x + w, wy)
    line(l, x - w, wy, x - h, ty); line(l, x + w, wy, x + h, ty)
    line(l, x - h, ty, x, ty - 3 * s); line(l, x + h, ty, x, ty - 3 * s)
    -- the bracing: crossed panels up the legs, fewer as the tower shrinks
    local np = s > 0.6 and 4 or (s > 0.3 and 2 or 1)
    for k = 0, np - 1 do
      local u0, u1 = k / np, (k + 1) / np
      local ya, yb = y + (wy - y) * u0, y + (wy - y) * u1
      local ha, hb = b + (w - b) * u0, b + (w - b) * u1
      line(l * 0.8, x - ha, ya, x + hb, yb); line(l * 0.8, x + ha, ya, x - hb, yb)
    end
    -- the arms
    line(l, x - 11 * s, y - 48 * s, x + 11 * s, y - 48 * s)
    line(l, x - 14 * s, y - 39 * s, x + 14 * s, y - 39 * s)
    if s > 0.6 then
      line(l * 0.8, x - 11 * s, y - 48 * s, x - h, y - 44 * s); line(l * 0.8, x + 11 * s, y - 48 * s, x + h, y - 44 * s)
      line(l * 0.8, x - 14 * s, y - 39 * s, x - w, y - 35 * s); line(l * 0.8, x + 14 * s, y - 39 * s, x + w, y - 35 * s)
    end
  end

  function M.draw(S)
    local T, DT, e = K.T, K.DT, K.energy
    local fine, dense, RT = K.detail ~= "classic", K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.15 end     -- eased above 1: the lit / frame-change bounds are tight here
    local fp = fine and K.playing          -- time-driven fine detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RT, 13) or l end
    local kl = K.kickless
    local hi, lo = A[K.HI], A[K.LO]
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    mz = K.follow(mz, A[K.MID], 1.0, DT)
    local kk, hh, cl, tk = fade("kick", 0.3), fade("hat", 0.3), fade("clap", 0.3), fade("tick", 0.4)
    local pd, mid = pdz, A[K.MID]
    for i = 1, 4 do ring[i] = K.follow(ring[i], K.voice_kick[i], 0.05, DT) end
    local bassg = K.gain(S, "bass") > 0 and 1 or 0.4
    sag = K.follow(sag, math.max(K.env.bass * bassg, lo * 0.8), 0.12, DT)
    sway = K.follow(sway, kl, 2, DT)
    -- the pump: every wire dips at once and springs back
    local age = K.NOW - pump_t
    local dip = 0
    if age >= 0 and age < 1 then dip = age < 0.07 and K.ease(age / 0.07) or math.exp(-(age - 0.07) / (K.beat_sec * 0.2)) end

    -- the sky: a town's glow low on the right behind the treeline, a moon
    K.gradient(HY - 16, HY - 1, function(y)
      local u = (HY - y) / 16
      return (0.9 + 0.5 * e) * (1 - u) ^ 1.6 * (1 + 0.8 * pd)
    end, trees, 40, 128)
    K.gradient(HY - 8, HY - 1, function(y)
      return 0.55 * (1 - (HY - y) / 8) * (1 + 0.8 * pd)
    end, trees, 0, 40)
    -- a thin moon: its disc less a second one offset into it
    for dy = -4, 4 do
      local run
      for dx = -4, 5 do
        local inside = dx * dx + dy * dy <= 17 and (dx - 2) ^ 2 + (dy + 1) ^ 2 > 12
        if inside then run = run or dx
        elseif run then put(4, 54 + run, 9 + dy, dx - run, 1); run = nil end
      end
    end
    for i = 0, 11 do
      local x, y = math.floor(K.hash(i, 81) * 127), math.floor(K.hash(i, 82) * (HY - 20))
      if math.abs(x - 54) > 7 or math.abs(y - 9) > 7 then
        put(1 + (0.5 + 0.5 * math.sin(T * (0.5 + K.hash(i, 83)) + i)) * (0.8 + hi * 2), x, y, 1, 1)
      end
    end

    -- the field: faint furrows running away, fog lying on it
    for k = 0, 6 do
      local y = HY + 2 + math.floor(k * k * 0.42)
      if y < 64 then K.dashes(1, y, 2 + k, 5 + k * 3, k * 13 + T * 0.4, 0, 128) end
      -- a kick thumps the furrows
      if y < 64 and kk > 0.03 then K.dashes(E(fine and 4.6 * kk or 4 * kk), y, 2 + k, 5 + k * 3, k * 13 + T * 0.4, 0, 128) end
    end
    if fp then            -- fine: furrows between the furrows, dimmer and shorter, for depth
      for k = 0, 5 do
        local y = HY + 3 + math.floor((k + 0.5) * (k + 0.5) * 0.42)
        if y < 64 then K.dashes(1, y, 1 + k * 0.5, 7 + k * 3, k * 9 - T * 0.3, 0, 128) end
      end
    end
    if dense and fp then  -- dense: a fence along the field and the town's lights on the horizon
      for fx = 3, 124, 8 do put(1.5, fx, HY + 2, 1, 2) end
      line(1, 0, HY + 2, 127, HY + 2)
      for i = 0, 17 do
        local lx = 62 + math.floor(K.hash(i, 85) * 64)
        put(1.2 + (0.5 + 0.5 * math.sin(T * (0.7 + K.hash(i, 86)) + i)) * 1.6, lx, HY - 1 - math.floor(K.hash(i, 87) * 4), 1, 1)
      end
    end
    local fog_top = HY - 2 - kl * 8
    K.haze(0, math.floor(fog_top), 128, 64, 0.16 + 0.18 * kl + 0.1 * K.dub * K.throw + (fp and 0.36 or 0.3) * mz + (fp and 0.19 or 0.15) * pd, 1, T * 2.5)

    -- the towers, far to near; the near one's warning light marks the bar
    tower(TW[3], 1.2, 0)
    tower(TW[2], 1.8, 0)
    tower(TW[1], 2.6, 0)
    if fp then        -- the near tower's legs have thickness
      local t1 = TW[1]
      line(1.3, t1.x - 9 + 1, t1.y, t1.x - 3 + 1, t1.y - 34); line(1.3, t1.x + 9 - 1, t1.y, t1.x + 3 - 1, t1.y - 34)
    end
    put(2 + 7 * K.bar_pulse, TW[1].x, TW[1].y - 56, 1, 1)
    -- a clap swells the moon's halo
    if cl > 0.03 then
      for dy = -6, 6 do
        local hw = math.floor(math.sqrt(math.max(0.5, 42 - dy * dy)) + 0.5)
        put(E(4 * cl), 54 + 1 - hw, 9 + dy, 2 * hw, 1)
      end
    end
    -- a tick blinks a far tower's warning light
    if tk > 0.03 then
      local t = TW[hit.tk]
      put(E(6 * tk), t.x - 2, t.y - 56 * t.s - 1, 5, 3)
      if fine then                             -- and the whole far tower catches it
        tower(t, E(4.6 * tk), 0)
        put(E(8 * tk), t.x - 3, t.y - 56 * t.s - 2, 7, 5)
      end
    end
    -- a perc: a farm light in the dark, its voice the depth, its note the place
    for i = #percs, 1, -1 do
      local p = percs[i]
      local v = math.exp(-(K.NOW - p.t) / (0.35 * TR()))
      if v < 0.03 then table.remove(percs, i)
      else
        local x, y = 6 + p.n * 10, HY + 1 + p.v * 3
        put(E(6 * v), x - 2, y, 5, 3); put(E(6 * v), x, y - 1, 1, 5)
        if fine then                           -- the farm light throws a pool on the ground and a halo in the air
          put(E(4 * v), x - 6, y + 1, 13, 1)
          put(E(3.4 * v), x - 9, y + 3, 19, 1); put(E(2.8 * v), x - 12, y + 5, 25, 1)
          put(E(3.4 * v), x - 4, y - 3, 9, 7)
        end
      end
    end

    -- the wires: four spans' worth each, hung by the sag, humming
    local hum = (0.3 + 1.2 * lo) * math.sin(T * 31)
    local sw = sway * math.sin(T * 0.9) * 2.5
    local function wire_sag(i, near)
      return (2 + (fp and 4.8 or 4) * sag + (fp and 3 or 2.2) * dip) * near + sw * near + (i % 2 == 0 and 0.3 or 0)
    end
    for i = 1, 4 do
      local wl = (1.6 + K.lane_kick[i] * 1.5 + e * 0.5 + hi * 1.3) * (1 + 0.15 * A[K.AMP])
      -- in from the left, toward us (only its last stretch is on screen)
      local spans = SPANS[i]
      for si, sp in ipairs(spans) do
        local p, q, near = sp[1], sp[2], sp[3]
        local sg = wire_sag(i, near)
        local n = si == 4 and 3 or 8
        local px0, py0 = span_pt(p, q, 0, sg)
        for k = 1, n do
          local u = k / n
          local x, y = span_pt(p, q, u, sg)
          y = y + hum * near * 0.5 * math.sin(u * math.pi)
          if fp and si == 1 and sway > 0.1 then K.line_sub(wl * 1.3, px0, py0, x, y)    -- swaying, the near span glides between pixels
          else line(wl * (si == 4 and 0.7 or 1), px0, py0, x, y) end
          px0, py0 = x, y
        end
      end
    end

    -- the insulators: one per chord voice on every tower, ringing on stabs
    for ti = 1, 3 do
      local s = TW[ti].s
      for i = 1, 4 do
        local p = TIP[ti][i]
        local r = ring[i]
        local l = 1.5 + s + r * (5 + 5 * s)
        put(l, p[1], p[2], 1, math.max(1, math.floor(p[3] + 0.5)))
        if r > 0.25 and s > 0.3 then
          put(r * 3 * s, p[1] - 1, p[2] + 1, 3, 1)
        end
      end
    end
    -- a hat snaps the insulators of one tower, a different tower each time
    if hh > 0.03 then
      local ti = (hit.hatn or 0) % 3 + 1
      for i = 1, 4 do
        local p = TIP[ti][i]
        put(E(6 * hh), p[1] - 1, p[2], 3, 3)
      end
      if fine then tower(TW[ti], E(4.8 * hh), 0) end    -- the whole tower crackles
    end
    -- a stab lights the near tower's insulators in a halo
    local sb = fade("stab", 0.4)
    if sb > 0.03 then
      for i = 1, 4 do put(E(5 * sb), TIP[1][i][1] - 2, TIP[1][i][2] - 1, 5, 4) end
    end
    -- an arp note flares its wire's insulator, each on the next tower along
    for i = 1, 4 do
      local ar = math.exp(-(K.NOW - arps[i]) / (0.35 * TR()))
      if ar > 0.03 then
        local q = TIP[acnt[i] % 3 + 1][i]            -- each note on the next tower along
        put(E(fine and 6.6 * ar or 6 * ar), q[1] - 3, q[2] - 2, 7, 7)
      end
    end
    -- the highs crackle round the near insulators
    K.grain(function(u, v)
      local p = TIP[1][1 + math.floor(u * 4) % 4]
      return p[1] + (v - 0.5) * 6, p[2] + (K.rnd() - 0.3) * 5
    end, hi * (20 + 40 * (ring[1] + ring[3])), 7)

    -- the sparks: an arp note running along its wire, tower to tower
    for i = #sparks, 1, -1 do
      local sp = sparks[i]
      local u = (T - sp.t0) / sp.dur
      if u >= 1 then table.remove(sparks, i)
      elseif u >= 0 then
        local L = sp.lane
        -- span 1 (near to mid) takes most of the time: it is the longest
        local pos = u < 0.65 and u / 0.65 or 1 + (u - 0.65) / 0.35
        local function at(q)
          if q < 1 then
            local x, y = span_pt(TIP[1][L], TIP[2][L], q, wire_sag(L, 1))
            return x, y + hum * 0.5 * math.sin(q * math.pi), 1
          end
          local x, y = span_pt(TIP[2][L], TIP[3][L], math.min(q - 1, 1), wire_sag(L, 0.45))
          return x, y, 0.6
        end
        local x, y, near = at(pos)
        local lv = sp.a * (6 + 6 * near) * (1 - u ^ 4)
        local tx, ty = at(math.max(0, pos - 0.08))
        if fp then
          -- the spark glides along the wire between pixels, its tail drawn from where it just was
          K.put_sub(math.min(lv * 1.5, 13), x, y - 1, 1, 1)
          line(lv * 0.35, tx, ty, x, y)
        else
          put(lv, x, y - 1, 1, 1)
          line(lv * 0.35, tx, ty, x, y)
        end
      end
    end
  end

  M.init()
  return M
end
