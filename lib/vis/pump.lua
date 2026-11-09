-- pump: a city across a flat at night, seen as lines. the sky is ruled in
-- bands that close toward the horizon and the ground is a lit field ruled
-- the same way; on every pump the ghost sidechain squeezes them all in to
-- the skyline and lets them breathe back out, nearest last. the horizon
-- flares with the kick; stabs light the sky's bands (one voice per band),
-- the bass the ground's; the arp notes are lights coming in along the
-- field. in kickless stretches the ground turns to water: the lines go
-- soft and wavy, the field's rays sink, the skyline and its windows
-- reflect, broken by the swell
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local HY = 36                          -- the horizon
  local NMAX = 8                         -- lines per side at the peak

  -- the skyline: low blocks at the edges, the towers mid-right, a mast
  local BLK = {}
  do
    local x, i = 0, 0
    while x < 128 do
      local w = 4 + 2 * math.floor(K.hash(i, 6) * 4)
      local mid = math.exp(-((x + w / 2 - 66) / 48) ^ 2)
      local h = 3 + math.floor(K.hash(i, 1) * 5 + mid * (3 + K.hash(i, 2) * 17))
      if K.hash(i, 8) > 0.85 then h = h // 2 end
      BLK[#BLK + 1] = {x = x, w = w, h = h}
      x, i = x + w, i + 1
    end
  end
  local MAST = 100
  local sky = K.profile(function(x)
    local h = 2
    for _, b in ipairs(BLK) do if x >= b.x and x < b.x + b.w then h = b.h end end
    if x >= MAST and x < MAST + 2 then h = 24 end         -- the mast
    return HY - h
  end)
  local WIN = {}
  for c = 0, 63 do
    local top = sky[c]
    for y = math.floor(top) + 2, HY - 2, 2 do
      if K.hash(c * 97 + y, 4) > 0.72 then WIN[#WIN + 1] = {c * 2 + (y // 2) % 2, y, K.hash(c + y * 7, 5) * 6.28} end
    end
  end

  -- a dashed row, only where it is above the skyline
  local function dash_above(l, y, w, gap, off, xa, xb)
    local run
    local c0, c1 = (xa or 0) // 2, math.min(64, ((xb or 128) + 1) // 2)
    if c0 < 0 then c0 = 0 end
    for c = c0, c1 do
      if c < c1 and y < sky[c] then run = run or c * 2
      elseif run then K.dashes(l, y, w, gap, off, run, c * 2); run = nil end
    end
  end

  -- the fades follow the trails setting; at fine it acts at half strength and never moves them by more than 15% or 10%
  -- (a short trail would make every hit a frame-to-frame jump)
  local function TR() return K.detail ~= "classic" and math.min(1.1, math.max(0.85, K.trail ^ 0.5)) or K.trail end

  local sq, sqs = {}, {}                 -- each line's squeeze: ground, sky (j = 1..NMAX)
  local lv_sky, lv_gnd = {0, 0, 0, 0}, 0 -- the stab bands and the bass, eased in
  local flare, lo = 0, 0                 -- the kick on the horizon; the lows, slow
  local lights = {}                      -- arp notes coming in along the field

  local pump_t = -99                     -- when the last pump came (real time)

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own
  local hit, percs, flashes = {}, {}, {}
  local acc = {bass = 0, hat = 0, arp = 0}  -- hits piling up and draining: each adds, so a hit shows whenever it lands
  local ba = 0                            -- the bass pile, eased
  local pdz, bz = 0, 0                   -- the pad and the bass hit, eased in
  local function mark(k) hit[k] = K.NOW end
  local function fade(k, tau)
    local t = hit[k]
    if not t then return 0 end
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    if v < 0.02 then hit[k] = nil; return 0 end
    return v
  end
  local function add(k, a, cap) acc[k] = math.min(cap, acc[k] + a) end
  function M.hat() mark("hat"); add("hat", 0.3, 2) end
  function M.clap() mark("clap") end
  function M.bass() mark("bass"); add("bass", 0.15, 2) end
  function M.tick() mark("tick") end
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, b = BLK[(math.floor(K.num(note, 60)) + 3 * clamp(math.floor(K.num(voice, 1)), 1, 4)) % #BLK + 1]}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.pump() pump_t = K.NOW end

  function M.init()
    pump_t = -99
    for j = 1, NMAX do sq[j], sqs[j] = 1, 1 end
    lv_sky, lv_gnd, flare, lo, lights = {0, 0, 0, 0}, 0, 0, 0, {}
    hit, percs, flashes, pdz, bz = {}, {}, {}, 0, 0
    acc, ba = {bass = 0, hat = 0, arp = 0}, 0
  end

  function M.arp(lane, note)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    add("arp", 0.15, 2)
    flashes[#flashes + 1] = {t = K.NOW, x = 64 + (K.px(note) - 64) / 64 * 6, lane = lane}
    while #flashes > 4 do table.remove(flashes, 1) end
    local fb, et = K.echo_fb, K.echo_t * K.SP
    local a = 1
    for k = 0, 3 do
      if k > 0 then a = a * fb * (0.3 + 0.7 * K.throw); if a < 0.2 then break end end
      if #lights < 48 then
        lights[#lights + 1] = {dir = (K.px(note) - 64) / 64, lane = lane, t0 = K.T + k * et, a = a}
      end
    end
  end

  -- the spacing of line j of n (1 nearest the horizon), squeezed
  local function dist(j, n, q, ext) local f = j / n; return (f ^ 1.6) * ext * q[j] + 1 end

  function M.draw(S)
    local T, DT, e = K.T, K.DT, K.energy
    local w = K.kickless
    local fine, dense, RX = K.detail ~= "classic", K.detail == "dense", K.react
    if RX > 1 then RX = 1 + (RX - 1) * 0.15 end     -- eased above 1: the lit / frame-change bounds are tight here
    local fp = fine and K.playing          -- time-driven fine detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RX, 13) or l end
    local n = math.floor(5 + e * (NMAX - 5) + 0.5)
    -- the squeeze: the duck takes the near field first, rolls in to the
    -- skyline and up into the sky a moment later; then all spring back
    local rec = K.beat_sec * 0.15
    local amt = 0.2 + 0.08 * (1 - w)
    local function shape(age)
      if age < 0 then return 0 end
      return age < 0.08 and K.ease(age / 0.08) or math.exp(-(age - 0.08) / rec)
    end
    for j = 1, NMAX do
      local f = j / NMAX
      local age = K.NOW - pump_t - (NMAX - j) * 0.015
      sq[j] = 1 - shape(age) * amt * (0.5 + 0.5 * f)
      sqs[j] = 1 - shape(age - 0.04 - (1 - f) * 0.02) * amt * (0.5 + 0.5 * f)
    end
    for i = 1, 4 do lv_sky[i] = K.follow(lv_sky[i], K.voice_kick[i] ^ 2, 0.04, DT) end
    local bassg = K.gain(S, "bass") > 0 and 1 or 0.4
    lv_gnd = K.follow(lv_gnd, K.env.bass * bassg, 0.04, DT)
    lo = K.follow(lo, A[K.LO], 0.5, DT)
    flare = K.follow(flare, K.env.kick, 0.03, DT)
    local hi = A[K.HI]
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local cl, hh, bh, tk = fade("clap", 0.3), fade("hat", 0.25), fade("bass", 0.4), fade("tick", 0.4)
    bz = K.follow(bz, bh, 0.1, DT)
    local dk = math.exp(-DT / (0.3 * TR()))
    for k, v in pairs(acc) do acc[k] = v < 0.01 and 0 or v * dk end
    local pd, mid, amp = pdz, A[K.MID], A[K.AMP]

    -- the city's glow, low on the sky and cut by the skyline
    K.gradient(HY - 26, HY - 1, function(y)
      local u = (HY - y) / 26
      return (0.75 + 0.6 * e) * (1 + 0.3 * amp) * (1 - u) ^ 1.4 + 0.12 + 0.9 * pd * (1 - u)
    end, sky)
    -- the sky: ruled bands stopping at the skyline; each band belongs to a
    -- chord voice, lit when it is stabbed. far bands break into dashes
    local c = K.chord
    local mean = (c[1] + c[2] + c[3] + c[4]) / 4
    for j = 1, n do
      local f = j / n
      local y = math.floor(HY - dist(j, n, sqs, 34) + 0.5)
      if y >= 0 then
        local v = (j - 1) % 4 + 1
        local l = 1 + f * (0.4 + e * 0.7) + (fine and E(cl * 0.4) or cl * 0.25)
        local cx = 64 + clamp((c[v] - mean) * 4, -50, 50) + math.sin(T * 0.21 + v * 1.9) * 12
        local hw = 12 + 8 * f
        local sl = lv_sky[v] * (1.5 + 2 * f) * 1.7
        local off = T * (4 + j * 1.5) + j * 11
        if f < 0.45 then
          dash_above(l + hi * 2.5, y, 5, 7, off)
          if sl > 0.3 then dash_above(l + sl + hi * 2.5, y, 5, 7, off, math.floor(cx - hw), math.floor(cx + hw)) end
        else
          K.row_above(l, y, sky)
          if sl > 0.3 then
            put(l + sl * 0.6, cx - hw, y, 2 * hw, 1)
            put(l + sl, cx - hw * 0.5, y, hw, 1)
          end
        end
      end
    end
    -- a plane crossing high up, its light blinking
    local pu = (T / 47) % 1
    if pu < 0.6 then
      local px = -4 + pu / 0.6 * 136
      if fp then K.put_sub(1.5 + 5 * (math.sin(T * 5) > 0.7 and 1 or 0), px, 5 + pu * 3, 1, 1)
      else put(1.5 + 5 * (math.sin(T * 5) > 0.7 and 1 or 0), px, 5 + pu * 3, 1, 1) end
    end
    -- stars, twinkling with the highs, above the bands' reach
    for i = 0, 9 do
      local x, y = math.floor(K.hash(i, 31) * 126), 1 + math.floor(K.hash(i, 32) * 12)
      local tw = 0.5 + 0.5 * math.sin(T * (0.7 + K.hash(i, 33)) + i * 2.3)
      put(1 + tw * (0.6 + hi * 3) + E(hh * 4), x, y, 1, 1)
    end

    -- the skyline: dark masses with their windows; the mast's red light
    for i, wn in ipairs(WIN) do
      local v = math.sin(T * 0.23 + wn[3])
      if v > -0.4 then
        local wl = (1.5 + v + e * 1.2 + hi * 1.5 + (fp and 1.0 * mid or 0)) * (1 + (fp and 0.7 or 0.4) * amp) + E(hh * 4)
        put(fp and math.min(wl, 12) or wl, wn[1], wn[2], 1, 1)
      end
    end
    put(1 + 7 * (0.5 + 0.5 * math.sin(T * 2.2)) ^ 4, MAST, HY - 25, 1, 1)
    -- dense: the tall towers carry their own slow warning lights
    if dense and K.playing then
      for i, b in ipairs(BLK) do
        if b.h >= 12 then
          put(1 + 5 * (0.5 + 0.5 * math.sin(T * 1.3 + i * 2.1)) ^ 4, b.x + b.w // 2, HY - b.h - 1, 1, 1)
        end
      end
    end
    -- a tick runs a flicker down the mast
    if tk > 0.03 then
      line(E(6 * tk), MAST, HY - 25, MAST, HY - 2)
      put(E(8 * tk), MAST - 1, HY - 26, 3, 1)
      if fine then put(E(4 * tk), MAST - 2, HY - 24, 5, 1) end
    end
    -- a perc fires a beacon on a rooftop, picked by its note
    for i = #percs, 1, -1 do
      local p = percs[i]
      local f = math.exp(-(K.NOW - p.t) / (0.5 * TR()))
      if f < 0.03 then table.remove(percs, i)
      else
        local bx, by = p.b.x + p.b.w // 2, HY - p.b.h - 1
        put(E(7 * f), bx - 1, by - 1, 3, 3)
        put(E(4 * f), bx - 4, by, 9, 1)
        put(E(4 * f), bx, by - 5, 1, 9)
        if fine then put(E(3 * f), bx - 2, by - 2, 5, 5) end
      end
    end
    -- an arp note flashes where its light enters the field
    for i = #flashes, 1, -1 do
      local fl = flashes[i]
      local f = math.exp(-(K.NOW - fl.t) / (0.5 * (fine and 1 or K.trail)))
      if f < 0.03 then table.remove(flashes, i)
      else
        put(E(8 * f), fl.x - 6, HY + 1, 13, 1)
        put(E(6 * f), fl.x - 1, HY - 12 - fl.lane * 4, 3, 12 + fl.lane * 4)
        put(E(3 * f), fl.x - 8, HY + 2, 17, 1)
      end
    end
    -- haze lying along the horizon, thicker in kickless stretches
    K.haze(0, HY - 6, 128, HY + 6, fp and ((0.2 + 0.2 * w + 0.1 * K.dub * K.throw) * 0.6 + 0.1 * mid + 0.24 * pd)
      or (0.2 + 0.2 * w + 0.1 * K.dub * K.throw + 0.1 * mid + 0.15 * pd), 1, T * 4)
    if mid > 0.05 then K.haze(0, 4, 128, HY - 6, 0.2 * mid, 1, -T * 2) end

    -- hats glitter along the horizon
    if hh > 0.03 or acc.hat > 0.03 then
      K.dashes(E(4 * hh) + E(4 * acc.hat), HY - 1, 2, 10, T * 30, 0, 128)
      if fine then K.dashes(E(3 * hh), HY + 3, 1, 8, -T * 20, 36, 92) end
    end
    -- the horizon: flares with the kick (eased, never a slab)
    put(math.min(12, 2 + flare * 7 + K.bar_pulse * 1.5 + 8 * acc.arp), 0, HY, 128, 1)

    -- the ground: the field's rays (sinking into water when kickless)
    if w < 0.95 then
      for k = -6, 6 do
        local x1 = 64 + k * 26
        line((1 + lo * 1.2 + flare * 1.5 + bz * 4) * (1 - w), 64 + k * 3, HY + 1, 64 + k * 22, 63)
      end
    end
    ba = K.follow(ba, acc.bass, 0.06, DT)
    if ba > 0.03 then put(math.min(10, 22 * ba), 32, HY + 2, 64, 1) end
    -- the field's lines: dry, straight rules; wet, a swell of segments
    local swell = 1.2 + 2.2 * A[K.LO]
    for j = 1, n do
      local f = j / n
      local y0 = HY + dist(j, n, sq, 28)
      if y0 <= 63 then
        local l = 1 + f * (0.4 + e * 0.6) + lo * f * 0.9 + (j > n - 3 and lv_gnd * 1.2 or 0)
        if w < 0.05 then
          -- rows of field lights: close-set far off, spaced as they near
          local gap = 2 + math.floor(f * 3)
          K.dashes(l, math.floor(y0 + 0.5), gap // 2 + 1, gap, (j % 2) * 2 + 64 % gap, 0, 128)
        else
          local amp = w * f * swell
          local px0, py0 = 0, y0 + math.sin(T * 1.3 + j) * amp
          for x = 8, 128, 8 do
            local yy = y0 + math.sin(T * 1.3 + x * 0.06 + j) * amp
            line(l, px0, py0, x, yy)
            px0, py0 = x, yy
          end
        end
      end
    end
    -- the skyline in the water: its windows as short broken streaks
    if w > 0.05 then
      for i, wn in ipairs(WIN) do
        if i % 2 == 0 then
          local y = 2 * HY - wn[2] + 1
          local wob = math.sin(T * 1.7 + wn[2] * 0.7 + i) * 1.5 * w
          put((1 + e) * w, wn[1] + wob, y, 1, 2)
        end
      end
      K.dashes(1.5 * w, HY + 2, 3, 6, T * 3, MAST - 3, MAST + 4)               -- the mast's light
    end

    -- the arp notes: lights coming in along the field toward us, faster
    -- for the higher lanes; they leave a short trail
    for i = #lights, 1, -1 do
      local L = lights[i]
      local dur = 1.6 - L.lane * 0.2
      local u = (K.T - L.t0) / dur
      if u >= 1 then table.remove(lights, i)
      elseif u >= 0 then
        local z = u * u
        local y = HY + 1 + z * 27
        local x = 64 + L.dir * (6 + z * 70)
        local lv = L.a * (4 + 7 * z) * (1 - u ^ 6)
        if fine then K.put_sub(lv, x, y, 1, 1) else put(lv, x, y, 1, 1) end
        local zt = math.max(0, u - 0.12) ^ 2
        line(lv * 0.3, 64 + L.dir * (6 + zt * 70), HY + 1 + zt * 33, x, y - 1)
      end
    end
  end

  M.init()
  return M
end
