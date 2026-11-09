-- lighthouse: a headland seen from the sea at night, side-on. a rock
-- headland rises on the right with a banded tower and its lantern; the beam
-- turns in the haze, swinging out over the water to the left and back
-- through the dark (it narrows to a flare as it turns toward you). the turn
-- follows the energy, the kick pulses the beam, the pump lifts the lantern's
-- glow. the waves catch the bass and the low band, stabs light the keeper's
-- window bands (notes as bars), arps are buoys blinking out on the water
-- (one lane each), hats glint on the wave tops, ticks are gulls' sparks
-- off the rocks, clap flashes a thin signal line, perc lights a cottage
-- window, pad lays slow swells. mids lift the haze, highs glint, lows widen
-- the swell, the level lights the lantern
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local LX, LY = 100, 17                 -- the lantern
  local HZ = 36                          -- the horizon

  local kick_t, pump_t, clap_t = -99, -99, -99
  local stab_t = -99
  local win = {0.2, 0.2, 0.2, 0.2}
  local bass_t, bass_x = -99, 40
  local hat_t, hat_x = -99, 30
  local cot = {-99, -99, -99}
  local perc_n = 0
  local sparks = {}
  for i = 1, 5 do sparks[i] = {t = -99, x = 90, y = 40} end
  local si = 0
  local buoys = {}
  for i = 1, 6 do buoys[i] = {t = -99, x = 40, lane = 1, n = 0} end
  local bi = 0
  local pad_notes = {}
  local pdz = 0
  -- hits pile up and drain: each one adds, so it shows whenever it lands
  local acc = {kick = 0, pump = 0, hat = 0, tick = 0, stab = 0, arp = 0}
  local function add(k) acc[k] = math.min(2, acc[k] + 0.3) end
  local ang = 0.3

  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / tau)
    return v < 0.03 and 0 or v
  end

  function M.init()
    kick_t, pump_t, clap_t, stab_t, bass_t, hat_t = -99, -99, -99, -99, -99, -99
    win = {0.2, 0.2, 0.2, 0.2}
    cot = {-99, -99, -99}
    for i = 1, 5 do sparks[i].t = -99 end
    for i = 1, 6 do buoys[i].t = -99 end
    pad_notes = {}
    pdz = 0
    for k in pairs(acc) do acc[k] = 0 end
  end
  M.clear = M.init

  function M.kick() kick_t = K.NOW; add("kick") end
  function M.pump() pump_t = K.NOW; add("pump") end
  function M.hat()
    hat_t = K.NOW; add("hat")
    hat_x = 10 + math.floor(K.NOW * 13) % 6 * 11
  end
  function M.clap() clap_t = K.NOW end
  function M.perc(voice, note)
    perc_n = perc_n + 1
    cot[perc_n % 3 + 1] = K.NOW
  end
  function M.tick(kind)
    kind = clamp(math.floor(K.num(kind, 1)), 1, 4)
    add("tick")
    si = si % #sparks + 1
    local s = sparks[si]
    s.t, s.x, s.y = K.NOW, 78 + kind * 5, 42 - kind
  end
  function M.stab(notes)
    stab_t = K.NOW; add("stab")
    for i = 1, 4 do win[i] = clamp((K.num(K.chord[i], 55) - 40) / 36, 0.25, 1) end
  end
  function M.bass(note)
    bass_t = K.NOW
    bass_x = 10 + (K.num(note, 36) % 12) * 6
  end
  function M.arp(lane, note, step)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    add("arp")
    bi = bi % #buoys + 1
    local b = buoys[bi]
    b.t, b.lane, b.x = K.NOW, lane, clamp(K.px(K.num(note, 72)) * 0.6 + 4, 4, 74)
    b.n = clamp((K.num(note, 72) - 48) / 48, 0, 1)
  end
  function M.pad(notes)
    pad_notes = {}
    if type(notes) == "table" then
      for i = 1, #notes do pad_notes[i] = K.num(notes[i], 50) end
    end
  end
  function M.bar() end

  function M.draw(S)
    local T, DT, NOW, e = K.T, K.DT, K.NOW, K.energy
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    ang = (ang + DT * (0.5 + 1.6 * clamp(e, 0, 1)) * (1 - 0.5 * K.kickless)) % K.TAU
    local kk, pf, cf = fade(kick_t, 0.3), fade(pump_t, 0.3), fade(clap_t, 0.3)
    local sf = fade(stab_t, 0.4)
    local dk = math.exp(-DT / 0.3)
    for k, v in pairs(acc) do acc[k] = v < 0.01 and 0 or v * dk end
    local ak, ap, ah, at, as, aa = acc.kick, acc.pump, acc.hat, acc.tick, acc.stab, acc.arp

    -- stars, a few
    for i = 1, 9 do
      if K.hash(i, 11) > 0.3 then
        put(1 + 1.2 * math.sin(T * 0.4 + i * 2.3) ^ 2, K.hash(i, 5) * 80, 1 + K.hash(i, 6) * 12, 1, 1)
      end
    end

    -- the beam: out over the water to the left when the lamp faces that way
    local c, s = math.cos(ang), math.sin(ang)
    local reach = math.abs(c)
    local face = s                      -- toward the viewer when > 0
    local bl = (2.2 + 3.5 * kk + 1.2 * K.duck + amp * 1.5) * (0.5 + 0.5 * reach)
    local dirx = c < 0 and -1 or 1
    if dirx < 0 then
      local len = 20 + 80 * reach
      local tx = LX - len
      for j = -3, 3 do
        local ty = LY + 5 + j * (1 + 6 * reach) * 0.7 + (1 - reach) * j * 2
        local l = bl * (1 - math.abs(j) / 4.5) * 0.7
        line(l, LX - 3, LY, tx, ty)
      end
      -- haze on the beam: dither in the cone
      K.dashes(bl * 0.5, LY + 3, 2, 4, T * 6, tx + 20, LX - 4)
      K.dashes(bl * 0.4, LY + 6, 2, 5, -T * 5, tx + 10, LX - 6)
      K.dashes(bl * 0.4 + mid, LY + 9, 2, 5, T * 4, tx, LX - 10)
      put(bl * 0.6, tx - 1, LY + 4, 2, 2)
    else
      -- the beam swings away behind the headland: a short stub into the sky
      local len = 8 + 30 * reach
      for j = -1, 1 do line(bl * 0.4, LX + 3, LY, LX + 3 + len, LY - 6 + j * 4) end
    end
    -- the flare when it faces the viewer
    if face > 0.55 then
      local f = (face - 0.55) / 0.45
      put((2 + 3 * kk) * f, LX - 1, LY - 1, 3, 3)
      put(1.5 * f, LX - 4, LY, 9, 1); put(1.5 * f, LX, LY - 4, 1, 9)
    end

    -- the headland: a dim rock mass, a crest and dithered strata below it
    local prev
    for x = 66, 127, 3 do
      local yy = 45 - 7 * math.exp(-((x - 100) / 20) ^ 2) - 2 * K.hash(x, 2)
      if prev then line(2 + 4 * ak, x - 3, prev, x, yy) end
      prev = yy
    end
    for y = 46, 56, 2 do
      local x0 = 70 + (y - 46) * 2.5
      K.dashes(1 + (y % 4 == 0 and 0.6 or 0) + 4 * at, y, 3, 5, y * 7, x0, 128)
    end
    -- the tower: tapered, banded
    line(2, LX - 3, 24, LX - 5, 44); line(2, LX + 3, 24, LX + 5, 44)
    for y = 28, 42, 5 do
      local hw = 3 + (y - 24) / 20 * 2
      line(1.2 + 6 * as, LX - hw, y, LX + hw, y)
    end
    line(1.4, LX - 5, 44, LX + 5, 44)
    -- the gallery and the lantern
    line(2.2, LX - 6, 24, LX + 6, 24)
    line(1.5, LX - 6, 24, LX - 6, 22); line(1.5, LX + 6, 24, LX + 6, 22)
    line(1.5, LX - 3, 20, LX + 3, 20); line(1.5, LX - 3, 20, LX - 3, 22); line(1.5, LX + 3, 20, LX + 3, 22)
    line(1.8, LX - 4, 20, LX, 15); line(1.8, LX + 4, 20, LX, 15)
    local lamp = 3 + 2 * amp + 2.5 * pf + 1.5 * kk
    if kk > 0.05 then
      for q = 0, 7 do
        local a = q * 0.785 + 0.2
        line(3.2 * kk, LX + math.cos(a) * 5, LY + 1 + math.sin(a) * 5, LX + math.cos(a) * (9 + 4 * kk), LY + 1 + math.sin(a) * (9 + 4 * kk))
      end
      line(2.2 * kk, 0, HZ + 1, 76, HZ + 1)
    end
    if pf > 0.05 then
      for y = 8, 26, 2 do K.dashes(3 * pf, y, 2, 3, y * 3, LX - 14, LX + 14) end
    end
    put(lamp, LX - 1, LY + 1, 3, 2)
    for i = 1, 4 do
      local wy = 27 + (i - 1) * 4
      local h = win[i] * sf
      put(1.3, LX - 1, wy, 3, 1)
      if h > 0.05 then put(2.5 + 4.5 * sf, LX - 1, wy, math.max(1, math.floor(h * 3 + 0.5)), 1) end
    end
    if sf > 0.05 then
      line(3 * sf, LX - 6, 25, LX - 6, 44); line(3 * sf, LX + 6, 25, LX + 6, 44)
      for i = 1, 4 do put(3.5 * sf * win[i], LX - 12, 25 + i * 4, 24, 1) end
    end
    -- the cottage at the foot, windows for perc
    line(1.4, 82, 45, 82, 40); line(1.4, 92, 45, 92, 40); line(1.4, 82, 40, 87, 37); line(1.4, 92, 40, 87, 37)
    for i = 1, 3 do
      local f = fade(cot[i], 0.4)
      if f > 0 then put(1.5 + 5.5 * f, 83 + i * 2 - 1, 41, 1, 2) end
      if f > 0.1 then
        put(2.5 * f, 78, 43, 22, 1); put(2 * f, 74, 44, 28, 1); put(1.5 * f, 70, 45, 36, 1)
        line(4 * f, 83 + i * 2, 38, 83 + i * 2 - 4, 30 - i * 3)
      end
    end
    -- the signal line along the horizon, thrown by the clap
    if cf > 0.05 then line(4 * cf, 0, HZ, 76, HZ); put(2 * cf, 0, HZ + 1, 76, 1) end
    line(1.2, 0, HZ, 76, HZ)

    -- sparks off the rocks
    for i = 1, #sparks do
      local sp = sparks[i]
      local a = NOW - sp.t
      if a < 0.4 then
        local l = 7 * (1 - a / 0.4)
        put(l, sp.x - a * 8, sp.y - a * 14, 1, 1)
        put(l * 0.7, sp.x + a * 9, sp.y - a * 10, 1, 1)
        line(l * 0.7, sp.x, sp.y, sp.x - a * 16, sp.y - a * 22)
        line(l * 0.7, sp.x, sp.y, sp.x + a * 18, sp.y - a * 18)
        line(l * 0.5, sp.x - 6, sp.y + 2, sp.x + 6, sp.y + 2)
        put(l * 0.4, sp.x - 14, sp.y + 4, 28, 1); put(l * 0.3, sp.x - 20, sp.y + 6, 40, 1)
        line(l * 0.5, sp.x - 3, sp.y, sp.x - 3, sp.y - 20 * a * 3)
      end
    end

    -- the sea: swell lines that rise with the bass and the low band
    local bf = fade(bass_t, 0.6)
    for k = 0, 8 do
      local y = HZ + 3 + k * 1.2 + k * k * 0.3
      if y < 63 then
        local amy = (0.6 + 4 * lo + 3 * bf) * (0.4 + k * 0.12)
        local pre
        for x = 0, 128, 4 do
          local yy = y + math.sin(x * 0.06 + T * (0.8 + k * 0.1) + k * 0.4) * amy
          if pre then line(1 + (k % 3) * 0.4 + 0.3 * k * 0.2 + hi * 1.5, x - 4, pre, x, yy) end
          pre = yy
        end
      end
    end
    -- the beam's glitter on the sea
    if dirx < 0 then
      for k = 1, 5 do
        K.dashes(bl * 0.6 * reach, HZ + 2 + k * 3, 2, 7, T * 8 + k * 5, clamp(LX - 20 - 80 * reach, 0, 128), 82)
      end
    end
    -- the bass: a long swell crest rolling in
    if bf > 0.05 then
      local u = 1 - bf
      line(5.5 * bf, bass_x - 10, 48 + u * 12, bass_x + 22, 48 + u * 12)
      line(3 * bf, bass_x - 18, 49 + u * 12, bass_x + 30, 49 + u * 12)
    end
    -- hats glint on the wave tops
    local hf = fade(hat_t, 0.2)
    if hf > 0.05 then
      for q = 0, 5 do
        put(6 * hf, hat_x + q * 11 % 60, HZ + 4 + q * 3, 3, 1)
        put(4 * hf, hat_x + q * 7 % 50 + 4, HZ + 5 + q * 3, 2, 1)
      end
    end

    -- the hats' glitter lingers in rows across the wave tops
    if ah > 0.03 then
      for k = 0, 4 do K.dashes(3 * ah, HZ + 6 + k * 4, 2, 7, T * (3 + k) + k * 9, 2, 76) end
    end
    -- the pad: slow swells at its notes' columns
    if pdz > 0.03 then
      for i = 1, #pad_notes do
        local x = K.px(pad_notes[i]) * 0.6
        for r = 0, 4 do
          local w = 8 + r * 5 + math.floor(math.sin(T * 0.5 + i + r) * 3)
          put(pdz * (3.2 - r * 0.5), x - w / 2, 46 + r * 3, w, 1)
        end
      end
    end

    -- buoys out on the water: a lamp, a mast and a reflection
    for i = 1, #buoys do
      local b = buoys[i]
      local f = fade(b.t, 0.5)
      local by = HZ + 5 + b.lane * 3 + math.floor(b.n * 3)
      if f > 0 then
        put(1.2 + 6 * f, b.x, by, 2, 2)
        line(2 * f, b.x + 1, by + 2, b.x + 1, by + 1 + 4)
        if f > 0.05 then put(2.5 * f, b.x - 3, by + 4, 8, 1); put(1.5 * f, b.x - 5, by + 6, 12, 1) end
      end
    end

    -- the haze over the water, lifted by the mids
    K.haze(0, HZ - 14, 80, HZ + 2, 0.1 + mid * 0.9 + 0.3 * ap, 1 + mid * 2, T * 2)
    if aa > 0.03 then
      for k = 0, 5 do K.dashes(2.5 * aa, 14 + k * 4, 2, 8, T * 2 + k * 11, 0, 74) end
    end
    K.grain(function(u, v) return u * 76, HZ + 3 + v * 24 end, hi * 40, 7)
  end

  M.init()
  return M
end
