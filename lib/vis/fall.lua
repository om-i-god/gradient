-- fall: under a railway arch at night, looking through to the lit street
-- beyond. the arp notes drip from the soffit at their pitch, each lane at
-- its own depth, and splash on the wet floor; stabs fall heavier, four
-- voices at once, and land with a wide splash. the bass glows in the
-- puddle, the kick rings it, the pump breathes the street lamp through the
-- far opening. dub throws repeat the splashes at the echo time, fading by
-- the feedback; the highs are a spray of mist in the far light; in kickless
-- stretches the drops float slowly down through a thicker haze
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local VX, VY = 64, 34                 -- vanishing point
  local S0, KZ = 56, 1.7               -- near scale (px per unit), depth falloff
  local FLOORY = 0.52                   -- the floor, in section units below the springing
  local RISE = 0.6                      -- the arch's crown above the springing

  local function scale(z) return S0 / (1 + KZ * z) end
  local function arch(X) local u = 1 - X * X; return u > 0 and -RISE * math.sqrt(u) or 0 end

  -- the near arch as a profile: brick above it, the tunnel below
  local face = K.profile(function(x)
    local X = (x + 1 - VX) / S0
    if X <= -1 or X >= 1 then return 64 end
    return VY + arch(X) * S0
  end)

  -- the far opening (z = 1) and the street beyond it
  local SF = scale(1)
  local FAR_FLOOR = VY + FLOORY * SF
  -- the street beyond: blocks of 4..8 px, some tall, against the glow
  local BLK = {}
  do
    local x, i = 42, 0
    while x < 86 do
      local w = 4 + 2 * math.floor(K.hash(i, 5) * 3)
      BLK[#BLK + 1] = {x = x, w = w, top = 30 + math.floor(K.hash(i, 3) * 9) - (K.hash(i, 9) > 0.7 and 4 or 0)}
      x, i = x + w, i + 1
    end
  end
  local city = K.profile(function(x)
    for _, b in ipairs(BLK) do if x >= b.x and x < b.x + b.w then return b.top end end
    return 44
  end)
  -- windows on the blocks: fixed, a few lit at a time
  local WIN = {}
  for i, b in ipairs(BLK) do
    for y = b.top + 2, math.floor(VY + FLOORY * SF) - 3, 2 do
      for x = b.x + 1, b.x + b.w - 2, 2 do
        if K.hash(x * 64 + y, 7) > 0.5 then WIN[#WIN + 1] = {x, y, K.hash(x + y, 8) * 6.28} end
      end
    end
  end

  local drops, splashes, ripples = {}, {}, {}
  local glow, lamp, mist_t = 0, 0.6, 0
  local pe, cone = 0, 0                   -- fine: the playing, eased in; the lamp's cone, slow
  local drip_acc = 0

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own
  local hit, percs = {}, {}
  local pdz = 0                           -- the pad, eased in
  local function mark(k) hit[k] = K.NOW end
  local function fade(k, tau)
    local t = hit[k]
    if not t then return 0 end
    local v = math.exp(-(K.NOW - t) / (tau * K.trail))
    if v < 0.02 then hit[k] = nil; return 0 end
    return v
  end
  function M.pump() mark("pump") end
  function M.hat() mark("hat") end
  function M.clap() mark("clap") end
  function M.bass() mark("bass") end
  function M.tick(kind) mark("tick"); hit.tk = clamp(math.floor(K.num(kind, 1)), 0, 99) % 2 end
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, z = 0.1 + (clamp(math.floor(K.num(voice, 1)), 1, 4) - 1) * 0.2,
      X = ((math.floor(K.num(note, 60)) % 12) / 12 - 0.5) * 1.6}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    drops, splashes, ripples = {}, {}, {}
    glow, lamp, drip_acc = 0, 0.6, 0
    hit, percs, pdz = {}, {}, 0
    pe, cone = 0, 0
  end

  local function drop(X, z, heavy, lv)
    if #drops >= 40 then return end
    drops[#drops + 1] = {X = clamp(X, -0.9, 0.9), z = z, Y = arch(clamp(X, -0.9, 0.9)) + 0.02,
      v = 0, heavy = heavy, lv = lv, sway = K.rnd() * 6.28}
  end

  -- a splash, and its echoes when the dub is up
  local function splash(X, z, size, lv)
    local fb, et = K.echo_fb, K.echo_t * K.SP
    local amt = 0.35 + 0.65 * K.throw
    local a = 1
    for k = 0, 3 do
      if #splashes >= 40 then return end
      if k > 0 then a = a * fb; if a * amt < 0.18 then return end end
      local parts = {}
      if k == 0 then
        for p = 1, size > 1.5 and 6 or 3 do parts[p] = {(K.rnd() - 0.5) * 1.6 * size, 0.6 + K.rnd() * 0.8} end
      end
      splashes[#splashes + 1] = {X = X, z = z, size = size, lv = lv * (k == 0 and 1 or a * amt),
        t0 = K.T + k * et, parts = parts}
    end
  end

  function M.arp(lane, note)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    local X = (K.px(note) - 64) / 64 * 0.9
    drop(X, 0.08 + (lane - 1) * 0.2, false, 10 - lane)
  end

  function M.stab(notes)
    local c = K.chord
    local mid = (c[1] + c[2] + c[3] + c[4]) / 4
    for i = 1, 4 do
      drop((c[i] - mid) / 12 + (i - 2.5) * 0.18, 0.12 + (i % 2) * 0.06, true, 11)
    end
  end

  function M.kick()
    if #ripples < 6 then ripples[#ripples + 1] = {t0 = K.T, a = 1} end
  end

  -- an ellipse on the floor, as 8 segments
  local function ring(l, cx, cy, rx, ry)
    if l < 0.5 or rx < 0.5 then return end
    local px, py = cx + rx, cy
    local n = rx < 4 and 4 or 8
    if K.detail ~= "classic" and K.playing then n = rx < 4 and 6 or (rx < 9 and 8 or 10) end
    for k = 1, n do
      local a = k / n * K.TAU
      local x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
      line(l, px, py, x, y)
      px, py = x, y
    end
  end

  function M.draw(S)
    local T, DT, e = K.T, K.DT, K.energy
    local kl = K.kickless
    local fine, dense, RX = K.detail ~= "classic", K.detail == "dense", K.react
    if RX > 1 then RX = 1 + (RX - 1) * 0.2 end     -- eased above 1: the lit / frame-change bounds are tight here
    local fp = fine and K.playing          -- time-driven fine detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RX, 13) or l end
    -- the street lamp beyond breathes with the pump; the bass fills the puddle
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local cl, hh, bh, tk = fade("clap", 0.3), fade("hat", 0.25), fade("bass", 0.4), fade("tick", 0.4)
    local pd, mid = pdz, A[K.MID]
    local pf = fine and E(fade("pump", 0.3)) or 0
    lamp = K.follow(lamp, (0.55 + 0.45 * e) * (1 - K.duck * 0.55) * (1 - kl * 0.3) * (1 + 0.3 * A[K.AMP]) + pd * 0.2, 0.06, DT)
    glow = K.follow(glow, math.max(K.env.bass * (K.gain(S, "bass") > 0 and 1 or 0.4), A[K.LO] * 0.85, bh * (fine and 1.6 or 1.3)), 0.08, DT)
    -- fine: once the music plays the stone steps back (eased, so a start never jumps)
    pe = fine and K.follow(pe, K.playing and 1 or 0, 0.6, DT) or 0

    -- the brick face of the near arch: courses, joints, the voussoirs
    for y = 1, 63, 4 do K.row_above(1, y, face) end
    for y = 2, 62, 4 do
      local o = ((y // 4) % 2) * 6
      for x = o, 127, 12 do
        if y + 2 < K.at(face, x) then put(1, x, y, 1, 3) end
      end
    end
    local px0, py0
    for k = 0, 16 do
      local X = -1 + k / 8
      local x, y = VX + X * S0, VY + arch(X) * S0
      if px0 then line(3, px0, py0, x, y) end
      if k % 2 == 1 then                          -- the voussoirs' joints
        local nx, ny = X, arch(X) / RISE
        local len = 1 / math.sqrt(nx * nx + ny * ny + 0.01) * 2.5
        line(2 - 0.7 * pe, x, y, x + nx * len, y + ny * len)
      end
      px0, py0 = x, y
    end
    -- a clap swells the arch's rim
    if cl > 0.03 then
      local qx, qy
      for k = 0, 16 do
        local X = -1 + k / 8
        local x, y = VX + X * S0, VY + arch(X) * S0
        if qx then line(E(7 * cl), qx, qy, x, y) end
        qx, qy = x, y
      end
    end

    -- the far opening: the street's glow over a dark skyline, a lamp
    local fl = lamp
    for y = math.floor(VY - RISE * SF) + 1, math.floor(FAR_FLOOR) do
      local Yu = (y - VY) / SF
      local hw = Yu >= 0 and SF or SF * math.sqrt(math.max(0, 1 - (Yu / RISE) ^ 2))
      local v = (1 + 2.6 * fl) * (0.35 + 0.65 * clamp((y - (VY - RISE * SF)) / 11, 0, 1))
      local th = ((y * 5) % 8 + 0.5) / 8
      local l = math.floor(v) + ((v % 1) > th and 1 or 0)
      if l > 0 and hw > 1 then K.row_above(l, y, city, math.floor(VX - hw + 0.5), math.floor(VX + hw + 0.5)) end
    end
    for i, w in ipairs(WIN) do                        -- lit windows across the street
      local v = math.sin(T * 0.07 + w[3])
      if v > -0.3 then put(1.2 + fl * 1.2 + v * 0.8 + A[K.HI] * 1.2 + hh * 4, w[1], w[2], 1, 1) end
    end
    K.mass(1, city, math.floor(FAR_FLOOR) - 1, math.floor(VX - SF + 2), math.floor(VX + SF - 1))
    put(2 + fl * 2.5 - 1.5 * pf, VX - SF + 1, math.floor(FAR_FLOOR) - 1, 2 * SF - 2, 1)  -- the street's own light
    line(1, 57, 32, 57, FAR_FLOOR - 2)                 -- a lamp post, its head
    put(7 + 4 * fl - 3 * pf, 58, 32, 1, 1)
    put(1.5 + fl * 1.5, 57, 33, 3, 1)
    -- fine: the lamp is the street's heart: a halo round its head and a cone of
    -- light on the road, swelling with the level and the kick, ducking with the pump;
    -- in kickless stretches the street fills with fog and the lamp blooms in it
    if fp then
      local hl = pe * (2.5 + 2.5 * fl + 2 * A[K.AMP] + 2.5 * K.env.kick) * (1 - 0.4 * pf / 13)
      put(hl, 56, 31, 5, 1); put(hl, 56, 33, 1, 1); put(hl, 60, 33, 1, 1)
      put(hl * 0.6, 57, 30, 3, 1)
      local fy = math.floor(FAR_FLOOR) - 1
      cone = K.follow(cone, fl, 0.35, DT)
      for y = 35, fy, 1 do
        local u = (y - 34) / (fy - 34)
        local w = 2 + u * 9
        put(pe * (2 + 2.5 * cone) * (1 - 0.45 * u) + 2.4 * kl, 58.5 - w / 2, y, w, 1)
      end
      if kl > 0.05 then
        K.haze(math.floor(VX - SF + 3), math.floor(VY - RISE * SF) + 3, math.floor(VX + SF - 3), math.floor(FAR_FLOOR) - 1,
          0.45 * kl, 2 + 1.5 * fl, T * 1.5)
        put(kl * (2 + 2 * fl), 54, 29, 9, 1); put(kl * (2 + 2 * fl), 54, 35, 9, 1)
      end
    end

    -- dense: rain coming down in the street beyond, lit by the lamp, slanting in kickless air
    if dense and fp then
      local top, bot = VY - RISE * SF + 4, FAR_FLOOR - 2
      for k = 0, 10 do
        local x0 = VX - SF + 4 + K.hash(k, 61) * (2 * SF - 8)
        local y = top + ((T * (14 - 6 * kl) + K.hash(k, 62) * 40) % (bot - top))
        local near = 1 - math.min(1, math.abs(x0 - 58.5) / 14)
        put(2 + 1.5 * fl + 3 * near * pe, x0 + (y - top) * 0.15 * kl, y, 1, 3)
      end
    end
    -- dense: the soffit sweats, a bead hanging at each voussoir, glinting on the wet
    if dense and K.playing then
      for k = 1, 15, 2 do
        local X = -1 + k / 8
        local x, y = VX + X * S0, VY + arch(X) * S0
        put(2 + 1.5 * math.sin(T * 0.8 + k * 1.7), x, y + 2, 1, 1)
      end
    end
    -- a pump traces the far opening's rim as the lamp ducks
    if pf > 0.05 then
      local qx, qy
      for k = 0, 12 do
        local X = -1 + k / 6
        local x, y = VX + X * SF, VY + arch(X) * SF
        if qx then line(5 * pf, qx, qy, x, y) end
        qx, qy = x, y
      end
    end

    -- the tunnel: ribs, the crown and springing lines, the floor's joints
    for zi, z in ipairs({0.22, 0.5}) do
      local s = scale(z)
      local px0, py0
      for k = 0, 10 do
        local X = -1 + k / 5
        local x, y = VX + X * s, VY + arch(X) * s
        if px0 then line(1 + (hit.tk == zi - 1 and E(5 * tk) or 0), px0, py0, x, y) end
        px0, py0 = x, y
      end
      line(1, VX - s, VY, VX - s, VY + FLOORY * s)
      line(1, VX + s, VY, VX + s, VY + FLOORY * s)
    end
    line(1, VX - S0, VY, VX - SF, VY)
    line(1, VX + S0, VY, VX + SF, VY)
    for k = -4, 4 do
      local X = k / 4
      line(1 + E(10 * bh) + (fine and bh or 0), VX + X * SF, FAR_FLOOR + 1, VX + X * S0 * 1.25, 63)
    end

    -- hats throw a mist of spray across the far light
    if hh > 0.03 then
      if fine then      -- and a few fine flecks high in the light
        for k = 0, 5 do put(E(6 * hh), VX - SF + 3 + math.floor(K.hash(k, math.floor(T * 8)) * (2 * SF - 6)), VY - 14 + k * 4, 1, 1) end
      end
      for y = VY - 16, math.floor(FAR_FLOOR) - 2, 3 do
        K.dashes(E(5 * hh), y, 1, 3, T * 25 + y * 5, VX - SF + 2, VX + SF - 2)
      end
    end

    -- the wet floor: the far light streaked down it, shivering
    local shiver = (0.6 + 1.5 * kl + 0.8 * A[K.LO]) * (1 + 0.8 * mid)
    for y = math.floor(FAR_FLOOR) + 2, 63, 2 do
      local d = (y - FAR_FLOOR) / (63 - FAR_FLOOR)
      local hw = SF * (1 + d * 1.4) + math.sin(T * 1.7 + y * 0.9) * shiver
      K.dashes((1 + fl * 1.8) * (1 - d * 0.5), y, 2, 6 + (y % 3), (T * (0.3 + (y % 4) * 0.15) + K.duck * (2 + d * 3)) * (y % 2 == 0 and 1 or -1) + y * 7,
        math.floor(VX - hw), math.floor(VX + hw))
    end

    -- the puddle: glows with the bass, ringed by the kick
    local PX, PY, PRX, PRY = 64, 55, 24, 4
    if glow > 0.04 then
      for dy = -PRY, PRY do
        local u = dy / (PRY + 0.5)
        local hw = math.floor(PRX * math.sqrt(1 - u * u) * (0.6 + 0.4 * glow))
        put(0.6 + glow * 4.5 * (1 - math.abs(u) * 0.5), PX - hw, PY + dy, 2 * hw, 1)
      end
    end
    if dense and K.playing then       -- and the puddle's rim, dotted
      for k = 0, 23 do
        local a = k / 24 * K.TAU
        put(1 + glow, PX + math.cos(a) * (PRX + 2), PY + math.sin(a) * (PRY + 1), 1, 1)
      end
    end
    for i = #ripples, 1, -1 do
      local r = ripples[i]
      local u = (T - r.t0) / 0.9
      if u >= 1 or u < 0 then table.remove(ripples, i)
      else
        local l = (2 + E(6 * r.a) + (fine and 1.5 * r.a or 0)) * (1 - u) ^ 1.5 * (0.7 + 0.5 * A[K.LO])
        ring(l, PX, PY, 3 + u * PRX * 1.2, 0.8 + u * PRY * 1.2)
        if u > 0.15 and r.a > 0.9 then ring(l * 0.6, PX, PY, 3 + (u - 0.15) * PRX * 1.2, 0.8 + (u - 0.15) * PRY * 1.2) end
      end
    end

    -- a perc strikes a ring on the floor, placed by its voice and note
    for i = #percs, 1, -1 do
      local p = percs[i]
      local f = math.exp(-(K.NOW - p.t) / (0.5 * K.trail))
      if f < 0.03 then table.remove(percs, i)
      else
        local s = scale(p.z)
        local u = 1 - f
        ring(E(6 * f), VX + p.X * s, VY + FLOORY * s, (2 + u * 9) * s / S0 * 1.6, (2 + u * 9) * s / S0 * 0.45)
        if fine then      -- the bead lifts off smoothly and a second ring follows it out
          K.put_sub(E(7 * f), VX + p.X * s, VY + FLOORY * s - 1 - u * 5 * s / S0, 1, 2)
          ring(E(3.5 * f), VX + p.X * s, VY + FLOORY * s, (1 + u * 6) * s / S0 * 1.6, (1 + u * 6) * s / S0 * 0.45)
        else
          put(7 * f, VX + p.X * s, VY + FLOORY * s - 1 - u * 5 * s / S0, 1, 2)
        end
      end
    end

    -- ambient drips from the soffit, even in silence
    drip_acc = drip_acc + K.DTS * (0.6 + 1.2 * kl)
    if drip_acc >= 1 then
      drip_acc = drip_acc - 1
      drop((K.rnd() - 0.5) * 1.6, 0.1 + K.rnd() * 0.7, false, 5)
    end

    -- the drops: fall in section units (gravity), drawn in perspective with
    -- a streak behind; kickless stretches let them drift down slowly
    local g = (2.6 - 1.4 * kl) * K.SP
    for i = #drops, 1, -1 do
      local d = drops[i]
      d.v = d.v + g * (d.heavy and 1.3 or 1) * K.DT
      d.Y = d.Y + d.v * K.DT * K.SP
      d.X = d.X + math.sin(T * 1.3 + d.sway) * 0.05 * kl * K.DTS
      local s = scale(d.z)
      local x, y = VX + d.X * s, VY + d.Y * s
      if d.Y >= FLOORY then
        splash(d.X, d.z, d.heavy and 2 or 1, d.lv)
        table.remove(drops, i)
      else
        local near = s / S0
        local trail = math.min(d.v * s * 0.09, 9)
        if fp then trail = math.min(d.v * s * 0.09 * (0.35 + 0.65 * K.trail), 15) end   -- fine: the trails set the streak
        local lv = d.lv * (0.55 + 0.45 * near) + A[K.HI] * 1.5
        if d.heavy then
          if trail >= 1 then put(lv * (fp and 0.5 or 0.35), x, y - trail, 1, trail) end
          put(lv, x, y, 2, 2)
        else
          if trail >= 1 then put(lv * (fp and 0.5 or 0.3), x, y - trail, 1, trail) end
          if fp and trail < 2 then K.put_sub(lv, x, y, 1, near > 0.6 and 2 or 1)
          elseif fp and near > 0.3 then put(lv, x, y, 1, near > 0.6 and 2 or 1); put(lv * 0.5, x + 1, y, 1, 1)
          else put(lv, x, y, 1, near > 0.6 and 2 or 1) end
        end
        -- its reflection rising to meet it on the wet floor
        local fy = VY + FLOORY * s
        local gap = fy - y
        if gap < 12 then put(lv * 0.25 * (1 - gap / 12), x, fy + gap * 0.4, d.heavy and 3 or 1, 1) end
      end
    end

    -- splashes: a ring spreading on the floor, droplets thrown up
    for i = #splashes, 1, -1 do
      local p = splashes[i]
      local u = (T - p.t0) / (0.45 + 0.2 * p.size)
      if u >= 1 then table.remove(splashes, i)
      elseif u >= 0 then
        local s = scale(p.z)
        local x, y = VX + p.X * s, VY + FLOORY * s
        local rx = (1 + u * 5 * p.size) * s / S0 * 1.6
        ring(p.lv * (1 - u) * 0.8, x, y, rx, rx * 0.28)
        for _, q in ipairs(p.parts) do
          local h = q[2] * 4 * u * (1 - u) * 4 * s / S0
          if fp then K.put_sub(E(p.lv * (1 - u) * 0.9), x + q[1] * u * 4 * s / S0, y - h, 1, 1)
          else put(p.lv * (1 - u) * 0.9, x + q[1] * u * 4 * s / S0, y - h, 1, 1) end
        end
      end
    end

    -- haze in the arch, heavier with the dub's throws and kickless stretches
    K.haze(20, 14, 108, 48, fp and ((0.08 + 0.12 * K.dub * K.throw + 0.15 * kl) * 0.5 + 0.33 * mid + 0.2 * pd)
      or (0.08 + 0.12 * K.dub * K.throw + 0.15 * kl + 0.3 * mid + 0.2 * pd), 1, T * 3)
    -- the highs: a mist of fine spray caught in the far light
    K.grain(function(u, v)
      return VX - SF + u * 2 * SF, VY - 6 + v * 26
    end, A[K.HI] * 150, 7)
  end

  M.init()
  return M
end
