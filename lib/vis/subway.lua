-- subway: a train passing in a tunnel at night, seen side-on. a row of
-- lit carriage windows slides across, doors and gangway joints between
-- them, riders in some seats, wheels and sleepers below and the tunnel's
-- lamps and pillars going by faster above (parallax). the speed follows
-- the energy, surges with each pump and slows to a crawl in kickless
-- stretches. each part lights windows as they pass: stabs fill four of
-- them (the notes as bars), arps draw a lane's line and note, percs light a
-- rider, hats a window's top, ticks a spark, claps two windows at once.
-- the kick thumps the carriage's outline, the bass fires the wheels and
-- throws sparks off the rail, the pump flares the tunnel's cornice, the
-- pad glows in the tunnel roof. mids lift every window, highs the glass,
-- lows the wheels, the level the tunnel lamps
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local PITCH = 16                       -- a slot; six to a car
  local WY, WH = 17, 14                  -- window top, height
  local dist, cnt = 0, 0                 -- how far along the car we are, cars passed
  local pdist = 0                        -- the tunnel's own travel (parallax)
  local vel = 14                         -- px/s, eased

  local wl, wi = {}, 0                   -- lit windows: slot, start, level, kind, extra
  for i = 1, 28 do wl[i] = {on = false, n = 0, t = 0, lv = 0, kind = "", x = 0, y = 0} end
  local kick_t, pump_t, bass_t, clap_t = -99, -99, -99, -99
  local sparks = {}                      -- bass sparks: start, x
  local hats_n, tick_n, perc_n, arp_n, bass_n, pdz = 0, 0, 0, 0, 0, 0
  local pad_notes = {}

  local function slot_at(x) return math.floor((x + dist) / PITCH) + 6 * cnt end
  local function kind_of(n) return n % 6 end
  local function window_slot(n)
    while kind_of(n) == 2 or kind_of(n) == 5 do n = n + 1 end
    return n
  end
  local function light(x, kind, lv, a, b)
    local n = window_slot(slot_at(x))
    wi = wi % #wl + 1
    local w = wl[wi]
    w.on, w.n, w.t, w.lv, w.kind, w.x, w.y = true, n, K.NOW, lv, kind, a or 0, b or 0
    return n
  end

  -- the fades follow the trails setting; at fine it acts at half strength and never moves them by more than 15% or 10%
  local function TR() return K.detail ~= "classic" and math.min(1.1, math.max(0.85, K.trail ^ 0.5)) or K.trail end
  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    return v < 0.03 and 0 or v
  end

  function M.init()
    dist, cnt, pdist, vel = 0, 0, 0, 14
    for _, w in ipairs(wl) do w.on = false end
    wi = 0
    kick_t, pump_t, bass_t, clap_t = -99, -99, -99, -99
    sparks = {}
    hats_n, tick_n, perc_n, arp_n, bass_n, pdz = 0, 0, 0, 0, 0, 0
    pad_notes = {}
  end
  M.clear = M.init

  function M.kick() kick_t = K.NOW end
  function M.pump() pump_t = K.NOW end
  function M.hat()
    hats_n = hats_n + 1
    light(8 + (hats_n * 37) % 112, "hat", 6)
  end
  function M.clap()
    clap_t = K.NOW
    local x = 20 + (math.floor(K.NOW * 9) % 5) * 20
    local n = light(x, "full", 4.5)
    light(x + PITCH, "full", 4.5)
  end
  function M.perc(voice, note)
    perc_n = perc_n + 1
    voice = clamp(math.floor(K.num(voice, 1)), 1, 4)
    light(10 + ((voice * 29 + perc_n * 17) % 112), "rider", 7)
  end
  function M.tick(kind)
    kind = clamp(math.floor(K.num(kind, 1)), 1, 4)
    tick_n = tick_n + 1
    light(6 + (kind * 31 + tick_n * 23) % 116, "spark", 7, tick_n % 9, 0)
  end
  function M.stab(notes)
    for i = 1, 4 do
      light(10 + (i - 1) * 30, "bar", 4.5, K.clamp((K.num(K.chord[i], 55) - 40) / 36, 0, 1), 0)
    end
  end
  function M.bass(note)
    bass_t = K.NOW
    bass_n = bass_n + 1
    sparks[#sparks + 1] = {t = K.NOW, x = 6 + ((K.num(note, 36) % 12) * 9 + bass_n * 31) % 116}
    if #sparks > 8 then table.remove(sparks, 1) end
  end
  function M.arp(lane, note, step)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    arp_n = arp_n + 1
    light(6 + ((lane * 29 + arp_n * 23) % 116), "arp", 6.5, lane, clamp((K.num(note, 72) - 48) / 48, 0, 1))
  end
  function M.pad(notes)
    pad_notes = {}
    if type(notes) == "table" then
      for i = 1, #notes do pad_notes[i] = K.num(notes[i], 50) end
    end
  end
  function M.bar() end

  -- one window, its riders as dark shapes cut into the glow
  local function glass(lv, x, rider)
    if rider then
      put(lv, x, WY, 12, 6)
      put(lv, x, WY + 6, 4, 4); put(lv, x + 8, WY + 6, 4, 4)
      put(lv, x, WY + 10, 2, 4); put(lv, x + 10, WY + 10, 2, 4)
    else
      put(lv, x, WY, 12, WH)
    end
  end

  function M.draw(S)
    local T, DT, e, NOW = K.T, K.DT, K.energy, K.NOW
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    local kl = K.kickless
    local fine, dense, RT = K.detail ~= "classic", K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.3 end      -- eased above 1: the frame change is tight here
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RT, 13) or l end
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)

    -- the speed: energy and the pulse; kickless stretches crawl
    local to = (9 + 22 * e) * (1 - 0.7 * kl) * (1 + 0.5 * K.duck)
    vel = K.follow(vel, to, 0.4, DT)
    local step = vel * K.DTS
    dist = dist + step
    if dist >= 96 then dist = dist - 96; cnt = cnt + 1 end
    pdist = (pdist + step * 1.5) % 4096

    local kk, pf, bt = fade(kick_t, 0.3), fade(pump_t, 0.3), fade(bass_t, 0.3)

    -- the tunnel: a cornice, pillars and lamps going by faster than the train
    put(1, 0, 11, 128, 1)
    for c = 0, 2 do
      local x = (c * 64 - pdist) % 192 - 32
      if fine then
        K.line_sub(1.2, x, 0, x, 10)
        K.line_sub(0.8, x + 2, 0, x + 2, 10)
      else
        line(1.2, x, 0, x, 10)
        line(0.8, x + 2, 0, x + 2, 10)
      end
    end
    local lamp = 1.5 + (fine and 3.6 or 2.5) * amp + 3 * pf
    for c = 0, 3 do
      local x = (c * 56 - pdist * 1.25) % 224 - 24
      if fine then
        K.put_sub(lamp, x, 4, 8, 1)
        if lamp > 2.2 then K.put_sub(lamp * 0.4, x + 1, 5, 6, 1) end
      else
        put(lamp, x, 4, 8, 1)
        if lamp > 2.2 then put(lamp * 0.4, x + 1, 5, 6, 1) end
      end
    end
    if pf > 0.03 then put(3.5 * pf, 0, 10, 128, 1) end
    -- dense: the cable runs along the tunnel wall
    if dense then put(0.8, 0, 7, 128, 1); put(0.6, 0, 9, 128, 1) end
    -- the pad glows in the roof, its notes as soft lights
    if pdz > 0.03 then
      put(1.5 * pdz, 0, 0, 128, 2)
      for i = 1, #pad_notes do
        local x = K.px(pad_notes[i])
        put(4.5 * pdz, x - 2, 1, 5, 3)
      end
    end

    -- the carriage: roof, belt and skirt lines, thumped by the kick
    local bl = 1.2 + 3.5 * kk
    put(bl, 0, 13, 128, 1)
    put(bl, 0, 47, 128, 1)
    put(1 + 3 * kk, 0, 36, 128, 1)
    if kk > 0.03 then put(2 * kk, 0, 48, 128, 1); put(2 * kk, 0, 12, 128, 1) end

    -- the slots, window by window
    local base = 1.8 + 1.0 * mid + 0.4 * amp
    for j = -1, 8 do
      local sx = j * PITCH - math.floor(dist)
      local n = j + 6 * cnt
      local k = n % 6
      if k == 5 then
        -- the gangway: bellows ribs
        for r = 0, 4 do line(1.2, sx + 2 + r * 3, 14, sx + 2 + r * 3, 46) end
        put(1.5, sx + 1, 16, 14, 1)
      elseif k == 2 then
        -- doors: two leaves with a lit pane each
        line(1.3, sx + 1, 15, sx + 1, 46); line(1.3, sx + 15, 15, sx + 15, 46)
        line(1.3, sx + 8, 15, sx + 8, 46)
        put(base * 0.8, sx + 3, 19, 3, 11); put(base * 0.8, sx + 10, 19, 3, 11)
      else
        local dark = K.hash(n, 11) < 0.08
        local rider = K.hash(n, 12) < 0.4
        if not dark then
          glass(base, sx + 2, rider)
          if fine then put(base * 0.4, sx + 2, WY + WH, 12, 1) end      -- the sill
        end
        if hi > 0.03 then put(hi * 4, sx + 2, WY - 1, 12, 1) end
      end
      -- the wheels: a bogie under the end slots of each car
      if k == 0 or k == 4 then
        local wl2 = 1.2 + 4.5 * lo + 4 * bt
        put(wl2, sx + 3, 49, 4, 3); put(wl2, sx + 9, 49, 4, 3)
      end
    end

    -- lit windows: each part's mark rides along with its window
    for _, w in ipairs(wl) do
      if w.on then
        local age = NOW - w.t
        local f = math.exp(-age / (0.32 * TR()))
        if fine then f = f * math.min(1, 0.3 + age / 0.07) end      -- a short rise
        local sx = (w.n - 6 * cnt) * PITCH - math.floor(dist)
        if f < 0.03 or sx < -PITCH or sx > 128 then w.on = false
        else
          local l, kd, x = w.lv * f, w.kind, sx + 2
          if kd == "full" then
            glass(l, x, false)
            line(l, x - 1, WY - 1, x + 12, WY - 1)
          elseif kd == "bar" then
            local h = math.max(2, math.floor(w.x * WH + 0.5))
            put(l, x, WY + WH - h, 12, h)
            put(l * 0.4, x, WY, 12, WH - h)
          elseif kd == "arp" then
            local yy = WY + 1 + (w.x - 1) * 3
            put(l, x, yy, 12, 2)
            put(l, x + math.floor(w.y * 9), WY + WH - 4, 3, 3)
          elseif kd == "rider" then
            put(l, x + 4, WY + 5, 4, 4)
            put(l, x + 1, WY + 9, 10, 5)
          elseif kd == "hat" then
            put(l, x, WY, 12, 3)
          elseif kd == "spark" then
            put(l * 0.6, x + 4 + w.x % 3, WY, 2, WH)
            put(l, x + 3 + w.x % 3, WY + 4 + w.x % 4, 4, 4)
            if fine then
              -- the pane flashes, a lit pole runs up to the roof and the cornice answers
              put(E(l * 0.35), x - 1, WY - 1, 14, WH + 2)
              line(E(l * 0.45), x + 5 + w.x % 3, 12, x + 5 + w.x % 3, 47)
              put(E(l * 0.6), x + 2, 48, 8, 1)
            end
          end
        end
      end
    end

    -- the rail below: sleepers going by, the rail itself, sparks from the bass
    put(1.5 + lo * 2, 0, 54, 128, 1)
    K.dashes(1, 57, 8, 24, -pdist * 0.6, 0, 128)
    K.dashes(1, 61, 4, 13, -pdist * 0.9, 0, 128)
    for i = #sparks, 1, -1 do
      local sp = sparks[i]
      local a = NOW - sp.t
      if a > 0.4 then table.remove(sparks, i)
      else
        local l = 7 * (1 - a / 0.4)
        local x = sp.x - a * 30
        put(l, x, 52 - a * 12, 2, 2); put(l * 0.7, x - 4, 51 - a * 8, 2, 2); put(l * 0.7, x + 4, 52 - a * 6, 2, 2)
        put(l, sp.x - 4, 53, 9, 1); put(l * 0.6, sp.x - 6, 50, 13, 3)
      end
    end

    -- the highs glitter on the glass
    K.grain(function(u, v) return u * 124 + 2, WY + v * WH end, hi * 24, 6)
  end

  M.init()
  return M
end
