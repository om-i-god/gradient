-- tramlines: looking up a tram street at night, the overhead wires crossing
-- the sky. three pairs of wires (a taut contact wire and a messenger wire
-- above it that sags between its stations, joined by droppers) run as long
-- near-parallel diagonals across the whole frame toward a vanishing point
-- below and off the right edge; a mast stands at the left with brackets, and
-- sagging cross-spans of varied height and length hang between the pairs.
-- a pantograph rides a contact wire and slides with the arps. each pump
-- sags the whole web and lets it shiver back, the bass hums as a standing
-- wave in the long spans, hats and ticks spark blue-white at the joints,
-- kick lights the insulator beads, clap snaps a cross-span, perc flashes a
-- wire's droppers, stabs hang lamps from the spans (notes as lengths), the
-- pad lies as slow bands. mids lift the haze, highs glint on the wires, lows
-- deepen the sag, the level lights the contact wires
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local VPX, VPY = 175, 64               -- the vanishing point, off frame
  local YL = {-4, 18, 42}                 -- each contact wire's y at x = 0
  local NW = 3
  local NST = 8                          -- stations along each wire
  local NSP = 7                          -- cross-spans

  local function ywire(w, x) return VPY + (YL[w] - VPY) * (VPX - x) / VPX end

  -- station x for wire w, jittered so there is no rhythm
  local stx = {}
  for w = 1, NW do
    stx[w] = {}
    for n = 1, NST do
      local base = VPX - 181 * 0.84 ^ (n - 1)
      local gap = 181 * 0.84 ^ (n - 1) * 0.16
      stx[w][n] = base + (K.hash(n * 7 + w, 3) - 0.5) * gap * 0.7
    end
  end
  -- droppers: two per segment at jittered fractions
  local hu = {}
  for w = 1, NW do
    hu[w] = {}
    for n = 1, NST - 1 do
      hu[w][n] = {0.2 + K.hash(n, w * 5) * 0.2, 0.55 + K.hash(n, w * 9 + 1) * 0.3}
    end
  end
  -- cross-spans: {x0, wire a, x1, wire b, lift}
  local sp = {}
  for i = 1, NSP do
    local x0 = VPX - 175 * 0.8 ^ (i - 1) + (K.hash(i, 21) - 0.5) * 10
    local wa = 1 + (i % 2)
    local wb = wa + 1 + (i % 3 == 0 and 1 or 0)
    if wb > NW then wb = NW; wa = 1 end
    sp[i] = {x0 = x0, wa = wa, x1 = x0 + 6 + K.hash(i, 22) * 16, wb = wb,
      lift = 2 + K.hash(i, 23) * 6, sag = 3 + K.hash(i, 24) * 4}
  end

  local kick_t, clap_t, stab_t, pump_t = -99, -99, -99, -99
  local clap_i = 1
  local bass_t = -99
  local stab_h = {0.3, 0.3, 0.3, 0.3}
  local sparks = {}
  for i = 1, 8 do sparks[i] = {t = -99, k = 1, i = 1, e = 0} end
  local si = 0
  local drop = {}
  for i = 1, 4 do drop[i] = {t = -99, w = 1} end
  local di = 0
  local panto_x, panto_t, panto_lane = 0.5, -99, 1
  local panto_s = 0.5
  local pad_notes = {}
  local pdz = 0
  local sway = 0

  -- the fades follow the trails setting (fine: nearly at full strength, about 0.5x at 0 to 1.9x at 100)
  local function TR() return K.detail ~= "classic" and math.min(1.9, math.max(0.48, K.trail ^ 0.8)) or K.trail end

  -- fine: the street's buildings rise into the lower corners, dark against the haze: {x0, x1, roof}
  local BLD = {{0, 17, 31}, {17, 38, 39}, {92, 109, 43}, {109, 128, 35}}
  local bwin = {}                         -- the windows on a grid: x, y, lit (warm) or dark
  for b = 1, #BLD do
    local B = BLD[b]
    for x = B[1] + 2, B[2] - 4, 5 do
      for y = B[3] + 4, 60, 6 do
        local h = K.hash(x * 7 + y, 51)
        bwin[#bwin + 1] = {x = x, y = y, lit = h < 0.3, warm = h < 0.12}
      end
    end
  end
  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    return v < 0.03 and 0 or v
  end

  -- a bar w wide whose left edge sits at a fractional x: the end pixels share the level
  local function sbar(l, x, y, w)
    local ix = math.floor(x)
    local fx = x - ix
    if fx == 0 then put(l, ix, y, w, 1); return end
    if w > 1 then put(l, ix + 1, y, w - 1, 1) end
    put(l * (1 - fx), ix, y, 1, 1)
    put(l * fx, ix + w, y, 1, 1)
  end

  function M.init()
    kick_t, clap_t, stab_t, pump_t, bass_t = -99, -99, -99, -99, -99
    for i = 1, 8 do sparks[i].t = -99 end
    for i = 1, 4 do drop[i].t = -99 end
    panto_t = -99
    pad_notes = {}
    pdz = 0
    sway = 0
  end
  M.clear = M.init

  local function spark(kind)
    si = si % #sparks + 1
    local s = sparks[si]
    s.t, s.k = K.NOW, kind
    s.i = (si * 3) % NSP + 1
    s.e = si % 2
  end

  function M.kick() kick_t = K.NOW end
  function M.pump() pump_t = K.NOW end
  function M.hat() spark(1) end
  function M.clap()
    clap_t = K.NOW
    clap_i = clap_i % NSP + 1
  end
  function M.perc(voice, note)
    di = di % #drop + 1
    drop[di].t = K.NOW
    drop[di].w = (clamp(math.floor(K.num(voice, 1)), 1, 4) + di) % NW + 1
  end
  function M.tick(kind)
    spark(clamp(math.floor(K.num(kind, 1)), 1, 4) + 1)
  end
  function M.stab(notes)
    stab_t = K.NOW
    for i = 1, 4 do stab_h[i] = clamp((K.num(K.chord[i], 55) - 40) / 36, 0.25, 1) end
  end
  function M.bass(note) bass_t = K.NOW end
  function M.arp(lane, note, step)
    panto_lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    panto_x = clamp((K.num(note, 72) - 48) / 48, 0, 1)
    panto_t = K.NOW
  end
  function M.pad(notes)
    pad_notes = {}
    if type(notes) == "table" then
      for i = 1, #notes do pad_notes[i] = K.num(notes[i], 50) end
    end
  end
  function M.bar() end

  -- a sagging span (x0,y0)-(x1,y1): the catenary as short lines; `hum` is a
  -- standing wave (nodes at both ends), `sw` a lateral sway
  local function span(l, x0, y0, x1, y1, sag, hum, sw, n)
    local px, py
    for i = 0, n do
      local u = i / n
      local x = x0 + (x1 - x0) * u + sw * math.sin(u * math.pi)
      local y = y0 + (y1 - y0) * u + sag * 4 * u * (1 - u) + hum * math.sin(u * math.pi * 3)
      if px then line(l, px, py, x, y) end
      px, py = x, y
    end
  end

  function M.draw(S)
    local T, DT, NOW = K.T, K.DT, K.NOW
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    local fine, dense, RT = K.detail ~= "classic", K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.2 end      -- barely above 1: the frame-change bound is tight here
    local fp = fine and K.playing                   -- time-driven fine detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RT, 13) or l end
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    sway = K.follow(sway, K.env.pump + 0.6 * K.duck, 0.12, DT)
    local kk, cf, sf = fade(kick_t, 0.3), fade(clap_t, 0.3), fade(stab_t, 0.4)
    local pf = fade(pump_t, 0.4)
    local bf = fade(bass_t, 0.7)
    local hum = (0.5 + 2.5 * lo + 5 * bf) * math.sin(T * 5.5)
    local shiver = pf * math.sin(T * 14)
    local swv = sway * 2 * math.sin(T * 3.1) + 2 * shiver
    local sagk = 1 + 2 * lo + 3 * pf

    -- the night sky: haze lifted by the mids, a few stars
    -- (fine keeps the haze to the upper sky and thins it at the top end, so the marks drawn after it are never cut by the draw budget)
    if fine then
      -- fine: the haze is the far layer, kept dim, and stops at the rooftops so the buildings stand dark against it
      local hd, hl = math.min(0.1 + mid * 0.5 + pdz * 0.3, 0.55), 1 + 0.9 * mid + 0.6 * pdz
      K.haze(0, 0, 128, 30, hd, hl, T * 1.5)
      K.haze(17, 30, 92, 38, hd, hl, T * 1.5)
      K.haze(38, 38, 92, 46, hd, hl, T * 1.5)
      K.haze(109, 30, 128, 34, hd, hl, T * 1.5)
      K.haze(92, 30, 109, 42, hd, hl, T * 1.5)
      -- the buildings: a dim cornice on each roof and a few windows, lit ones warmed by the mids
      for i = 1, #BLD do
        local b = BLD[i]
        put(1.6, b[1], b[3], b[2] - b[1], 1)
        if b[1] > 0 then put(1, b[1], b[3] + 1, 1, 63 - b[3]) end
        if b[2] < 128 then put(1, b[2] - 1, b[3] + 1, 1, 63 - b[3]) end
        if dense then put(0.8, b[1], b[3] + 2, b[2] - b[1], 1) end      -- dense: a second string course
      end
      for i = 1, #bwin do
        local w = bwin[i]
        if w.warm then put(2.6 + 2.2 * mid + 1.5 * pdz, w.x, w.y, 3, 3)
        elseif w.lit then put(1.4 + 1.2 * mid, w.x, w.y, 3, 3)
        elseif dense then put(0.7, w.x, w.y, 3, 1) end      -- dense: the dark windows' sills
      end
    else
      K.haze(0, 0, 128, 64, 0.1 + mid * 0.6 + pdz * 0.3, 1 + mid, T * 1.5)
    end
    for i = 1, 10 do
      put(1 + math.sin(T * 0.5 + i * 1.9) ^ 2, K.hash(i, 3) * 126, K.hash(i, 4) * 60, 1, 1)
    end
    -- fine: a dimmer second rank of stars
    if fine then
      for i = 11, dense and 22 or 16 do
        put(0.7 + (fp and 0.9 * math.sin(T * 0.37 + i * 2.3) ^ 2 or 0.45), K.hash(i, 3) * 126, K.hash(i, 4) * 60, 1, 1)
      end
    end

    -- the mast at the left, with a bracket out to each wire
    line(2 + (fine and 2.4 * kk or 0), 4, 0, 4, 63)
    line(1.5, 1, 0, 8, 0)
    if dense then
      for y = 6, 60, 6 do put(0.8, 3, y, 1, 3); put(0.8, 5, y + 3, 1, 3) end      -- the mast's lattice
    end
    for w = 1, NW do
      local y = ywire(w, 4)
      line(1.6 + (fine and 3.8 or 3) * pf, 4, y, 12, y - 0.5)
      if fine and kk > 0.05 then put(E(3.2 * kk), 2, y - 1, 5, 3) end
    end

    -- cross-spans: sagging arcs of varied height and length between the pairs
    for i = 1, NSP do
      local c = sp[i]
      local ya = ywire(c.wa, c.x0) - c.lift
      local yb = ywire(c.wb, c.x1) - c.lift
      local cs = (i == clap_i) and cf or 0
      local len = math.abs(c.x1 - c.x0) + math.abs(yb - ya)
      if ya < 66 or yb < 66 then
        span(1.4 + (fine and 6.4 or 5) * cs, c.x0, ya, c.x1, yb, c.sag * sagk * 0.6, hum * len * 0.03, swv * 0.5, 8)
        if fine and cs > 0.05 then span(E(2.6 * cs), c.x0, ya - 1, c.x1, yb - 1, c.sag * sagk * 0.6, hum * len * 0.03, swv * 0.5, 8) end
      end
    end

    -- the wires: contact (taut) and messenger (sagging between stations)
    local cl = 2.3 + (fine and 2.3 or 2) * amp + 1.5 * kk
    for w = 1, NW do
      for n = 1, NST - 1 do
        -- fine: the far end of the street is dimmer
        local dep = fine and 1.1 - 0.4 * (n - 1) / (NST - 2) or 1
        local xa, xb = stx[w][n], stx[w][n + 1]
        local ya, yb = ywire(w, xa), ywire(w, xb)
        if ya < 66 or yb < 66 then
          local len = xb - xa
          local h = hum * len * 0.03
          span(fine and cl - (2.3 * (1 - dep)) or cl, xa, ya, xb, yb, 0.2, h * 0.3, swv * 0.3, 4)
          span(fine and (1.1 * dep + hi * 1.2) or (1.5 * dep + hi * 1.5), xa, ya - 6, xb, yb - 6, 2.5 * sagk, h, swv, 6)
          -- droppers: jittered, from the messenger down to the contact wire
          for q = 1, 2 do
            local u = hu[w][n][q]
            local x = xa + len * u
            local yc = ya + (yb - ya) * u
            local ym = ya - 6 + (yb - ya) * u + 2.5 * sagk * 4 * u * (1 - u)
              + h * math.sin(u * math.pi * 3) + swv * math.sin(u * math.pi)
            line(1.1, x + swv * math.sin(u * math.pi), ym, x, yc)
          end
        end
      end
    end
    -- insulator beads: small isolated points on the contact wires
    for w = 1, NW do
      for n = 1, NST do
        local x = stx[w][n]
        local y = ywire(w, x)
        if y < 64 then
          put(1.5 + (fine and 6.5 or 5) * kk, x - 1, y - 1, 2, 2)
          if fine and kk > 0.05 then put(E(3 * kk), x - 1, y - 2, 3, 3) end
        end
      end
    end

    -- droppers flashed by perc: every hanger of one wire pair
    for i = 1, #drop do
      local d = drop[i]
      local f = fade(d.t, 0.35)
      if f > 0.03 then
        for n = 1, NST - 1 do
          local xa, xb = stx[d.w][n], stx[d.w][n + 1]
          for q = 1, 2 do
            local u = hu[d.w][n][q]
            local x = xa + (xb - xa) * u
            local y = ywire(d.w, x)
            if y < 62 then
              line((fine and 7.5 or 6) * f, x, y - 6, x, y)
              put((fine and 4.5 or 3.5) * f, x - 1, y - 7, 3, 1)
            end
          end
        end
      end
    end

    -- lamps hung from the cross-spans by the stabs: notes as lengths
    if sf > 0.05 then
      for i = 1, 4 do
        local c = sp[i + 1]
        local x = (c.x0 + c.x1) / 2
        local y = (ywire(c.wa, c.x0) + ywire(c.wb, c.x1)) / 2 - c.lift + c.sag * sagk * 0.6
        local h = math.max(2, math.floor(stab_h[i] * 12 + 3))
        line(E(4.5 * sf), x, y, x, y + h); line(E(3 * sf), x - 4, y, x - 4, y + h - 2); line(E(3 * sf), x + 4, y, x + 4, y + h - 2)
        put(E(6 * sf), x - 1, y + h, 3, 2)
        put(E(2.5 * sf), x - 5, y + h + 2, 11, 1)
        if fine then put(E(2 * sf), x - 8, y + h + 4, 17, 1); put(E(1.6 * sf), x - 6, y + h + 6, 13, 1) end
      end
    end

    -- sparks at the joints: blue-white where a cross-span meets a wire
    for i = 1, #sparks do
      local s = sparks[i]
      local a = NOW - s.t
      if a < 0.35 then
        local c = sp[s.i]
        local x = s.e == 0 and c.x0 or c.x1
        local y = ywire(s.e == 0 and c.wa or c.wb, x) - c.lift
        local l = (s.k == 1 and 6 or 7) * (1 - a / 0.35)
        if fine then
          l = E(l * 1.15)
          put(l * 0.4, x - 2, y - 2, 5, 5)       -- the flash's glow
        end
        put(l, x - 1, y - 1, 3, 3)
        line(l * 0.8, x - 6 - a * 14, y, x + 6 + a * 14, y)
        line(l * 0.7, x, y - 7 - a * 12, x, y + 7 + a * 12)
        line(l * 0.5, x - 5 - a * 10, y - 5 - a * 10, x + 5 + a * 10, y + 5 + a * 10)
      end
    end

    -- the pantograph: a small collector on a contact wire, sliding with the arps
    do
      local f = fade(panto_t, 0.8)
      panto_s = K.follow(panto_s, panto_x, 0.35, DT)
      local w = 1 + (panto_lane - 1) % NW
      local x = 10 + 60 * (1 - panto_s)
      local y = ywire(w, x)
      local l = 3 + 4 * f
      if fine then
        -- fine: the pantograph is the scene's live point: brighter, with a hot contact on the wire
        l = math.min(12, 3.5 + E(6 * f) + (K.playing and 2 + 3 * K.energy or 0))
        -- the collector glides on the sub-pixel along the wire as the arps move it
        local iy = math.floor(y + 0.5)
        sbar(l, x - 3, iy - 1, 7)
        K.line_sub(l * 0.8, x - 4, iy + 4, x, iy - 1); K.line_sub(l * 0.8, x + 4, iy + 4, x, iy - 1)
        sbar(l * 0.6, x - 4, iy + 4, 9)
        -- the stretch of wire it draws on carries the current, brighter the harder the music runs
        if K.playing then
          local cw = 1.5 + 7.5 * K.energy * K.energy
          line(cw, x - 16, ywire(w, x - 16), x - 4, ywire(w, x - 4))
          line(cw, x + 4, ywire(w, x + 4), x + 16, ywire(w, x + 16))
        end
        if f > 0.05 then
          sbar(E(5.2 * f), x - 7, iy - 3, 15)
          line(E(5 * f), x, iy - 2, x, iy - 11)
          sbar(E(3 * f), x - 5, iy - 11, 11)
          line(E(4.4 * f), x - 12, ywire(w, x - 12) - 1, x + 12, ywire(w, x + 12) - 1)
          sbar(E(6 * f), x - 1, iy - 2, 3)
          put(E(5 + 8 * f), math.floor(x + 0.5), iy - 1, 1, 1)
          put(E(2.2 * f), x - 3, iy - 5, 7, 2)
        end
      else
        put(l, x - 3, y - 1, 7, 1)
        line(l * 0.8, x - 4, y + 4, x, y - 1); line(l * 0.8, x + 4, y + 4, x, y - 1)
        line(l * 0.6, x - 4, y + 4, x + 4, y + 4)
        if f > 0.05 then put(3 * f, x - 7, y - 3, 15, 1); line(3 * f, x, y - 2, x, y - 8) end
      end
    end

    -- the pad: slow bands at the notes' columns
    if pdz > 0.03 then
      for i = 1, #pad_notes do
        local x = K.px(pad_notes[i])
        for r = 0, 4 do
          local w = 8 + r * 6 + math.floor(math.sin(T * 0.5 + i + r) * 4)
          put(pdz * (3.2 - r * 0.5), x - w / 2, 8 + r * 5, w, 1)
        end
      end
    end

    -- fine, kickless: with no kick the current shows as glints running down the contact wires
    if fp and K.kickless > 0.05 then
      local kl = K.kickless
      for w = 1, NW do
        local x = (T * (9 + 14 * K.duck) + w * 47) % 150 - 10
        for q = 0, 2 do
          local xq = x - q * 3 * TR()
          local yq = ywire(w, xq)
          if yq < 63 then K.put_sub((2.5 + 6 * kl) * (1 - q * 0.33), xq, yq - 0.5, 2, 1) end
        end
      end
    end

    -- dense: a far tram's headlamps creep along the street under the wires
    if dense and fp then
      local fx = 126 - (T * 3.5) % 70
      local fy = ywire(2, fx) + 7
      K.put_sub(3, fx, math.floor(fy + 0.5), 1, 1); K.put_sub(3, fx + 4, math.floor(fy + 0.5), 1, 1)
      K.put_sub(1.6, fx + 2, math.floor(fy + 0.5) - 1, 1, 1)
    end

    K.grain(function(u, v) return u * 124 + 2, 4 + v * 56 end, hi * 40, 7)
    end

  M.init()
  return M
end
