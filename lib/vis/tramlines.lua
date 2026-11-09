-- tramlines: looking straight up at a tram street's overhead wires at night.
-- two pairs of wires (a taut contact wire and a sagging messenger above it,
-- joined by droppers) run away overhead to a vanishing point, and long
-- cross-spans zig-zag from pole to pole over the street, sagging between
-- the edges. a pantograph rides the nearest contact wire and slides with
-- the arps. the pump sways the wires, the bass hums as a standing wave in
-- the long spans, hats and ticks spark blue-white at the joints, kick
-- lights the insulators, clap snaps a cross-span, perc flashes a station's
-- droppers, stabs hang lamps from the spans (notes as lengths), the pad
-- lies as slow haze. mids lift the haze, highs glint on the wires, lows
-- deepen the sag, the level lights the contact wires
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local VX, VY = 64, 3                   -- the vanishing point
  local NS = 7                           -- stations along the street
  local BOT = 61                         -- the near end of the wires
  -- the wires: x at the bottom edge for each of the four, and the pair id
  local WX = {-6, 14, 50, 70, 108, 128}

  -- station n (1 near .. NS far) -> fraction of the way from the vanishing
  -- point to the near edge
  local function frac(n) return ((NS + 1 - n) / NS) ^ 1.7 end
  local function wx(w, f) return VX + (WX[w] - VX) * f end
  local function wy(f) return VY + (BOT - VY) * f end

  local kick_t, clap_t, stab_t = -99, -99, -99
  local clap_i = 1
  local bass_t = -99
  local stab_h = {0.3, 0.3, 0.3, 0.3}
  local sparks = {}
  for i = 1, 8 do sparks[i] = {t = -99, k = 1, w = 1, n = 1} end
  local si = 0
  local drop = {}
  for i = 1, 4 do drop[i] = {t = -99, n = 1} end
  local di = 0
  local panto_x, panto_t, panto_lane = 0.5, -99, 1
  local panto_s = 0.5
  local pad_notes = {}
  local pdz = 0
  local sway = 0

  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / tau)
    return v < 0.03 and 0 or v
  end

  function M.init()
    kick_t, clap_t, stab_t, bass_t = -99, -99, -99, -99
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
    s.w = (si * 3) % 6 + 1
    s.n = (si * 5) % (NS - 1) + 1
  end

  function M.kick() kick_t = K.NOW end
  function M.pump() end
  function M.hat() spark(1) end
  function M.clap()
    clap_t = K.NOW
    clap_i = clap_i % (NS - 1) + 1
  end
  function M.perc(voice, note)
    di = di % #drop + 1
    drop[di].t = K.NOW
    drop[di].n = (clamp(math.floor(K.num(voice, 1)), 1, 4) * 2 + di) % (NS - 1) + 1
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
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    sway = K.follow(sway, K.env.pump + 0.6 * K.duck, 0.12, DT)
    local kk, cf, sf = fade(kick_t, 0.3), fade(clap_t, 0.3), fade(stab_t, 0.4)
    local bf = fade(bass_t, 0.7)
    local sgn = math.sin(T * 5.5)
    local hum = (0.5 + 2.5 * lo + 5 * bf) * sgn
    local swv = sway * 3 * math.sin(T * 3.1)
    local sagk = 1.2 + 2 * lo

    -- the night sky between the wires: haze lifted by the mids, a few stars
    K.haze(0, 0, 128, 40, 0.1 + mid * 0.6 + pdz * 0.3, 1 + mid, T * 1.5)
    for i = 1, 10 do
      put(1 + math.sin(T * 0.5 + i * 1.9) ^ 2, K.hash(i, 3) * 126, 4 + K.hash(i, 4) * 40, 1, 1)
    end

    -- the cross-spans: zig-zag from the left pole of one station to the right
    -- pole of the next, and back; they cross over the street as a web
    for n = 1, NS - 1 do
      local f0, f1 = frac(n), frac(n + 1)
      local y0, y1 = wy(f0), wy(f1)
      local cs = (n == clap_i) and cf or 0
      local nl = 0.7 + 1.1 * f0
      local sg = (1 + 5 * f0) * sagk * 0.6
      local h = hum * (0.3 + f0) * 0.5
      local sw = swv * (0.3 + f0)
      span(1.3 + nl * 0.6 + 5 * cs, 0, y0, 127, y1, sg, h, sw, 12)
      if n % 2 == 1 then span(1.2 + nl * 0.5 + 5 * cs, 127, y0, 0, y1, sg, -h, -sw, 12) end
    end

    -- the wires: contact (taut) and messenger (sagging, with droppers)
    local cl = 2.4 + 2 * amp
    for w = 1, 6 do
      for n = 1, NS - 1 do
        local f0, f1 = frac(n), frac(n + 1)
        local xa, xb = wx(w, f0), wx(w, f1)
        local ya, yb = wy(f0), wy(f1)
        local pair = (w % 2 == 1)
        if pair then
          -- the contact wire: straight, lit by the level, hums a little
          span(cl, xa, ya, xb, yb, 0.3 * f0, hum * 0.3 * f0, swv * 0.5 * f0, 4)
        else
          -- the messenger: sags above between droppers, hums in the long spans
          local mx0, mx1 = wx(w, f0), wx(w, f1)
          span(1.6 + hi * 1.5, mx0, ya - 3 * f0 - 1, mx1, yb - 3 * f1 - 1, -sagk * 2 * f0 - 0.5, hum * f0, swv * f0, 6)
          -- droppers down to the neighbouring contact wire
          local cx0, cx1 = wx(w - 1, f0), wx(w - 1, f1)
          for q = 1, 2 do
            local u = q / 3
            local mx = mx0 + (mx1 - mx0) * u
            local my = ya + (yb - ya) * u - 3 * (f0 + (f1 - f0) * u) - 1
            local cx = cx0 + (cx1 - cx0) * u
            local cy = ya + (yb - ya) * u
            line(1.1, mx + swv * f0 * math.sin(u * math.pi), my, cx, cy)
          end
        end
        -- the insulator at each station: lit by the kick
        local l = 1.2 + 5.5 * kk
        put(l, xa - 1, ya - 1, 3, 1)
        if kk > 0.05 then line(4 * kk, xa, ya - 5 * f0, xa, ya + 4 * f0) end
      end
    end
    if kk > 0.05 then
      -- the kick rings the whole bundle: bright contact wires at the near end
      for w = 1, 6, 2 do line(2.5 * kk, wx(w, 0.15), wy(0.15), wx(w, 1), BOT) end
    end

    -- droppers flashed by perc: a station's hangers across the street
    for i = 1, #drop do
      local d = drop[i]
      local f = fade(d.t, 0.35)
      if f > 0.03 then
        local fr = frac(d.n)
        local y = wy(fr)
        for w = 1, 6 do
          local x = wx(w, fr)
          line(6 * f, x, y - 6 * fr, x, y + 5 * fr)
          put(4 * f, x - 2, y + 5 * fr, 5, 1)
        end
        line(3 * f, wx(1, fr), y, wx(6, fr), y); put(2 * f, 0, y, 128, 1)
      end
    end

    -- lamps hung from the spans by the stabs: notes as lengths
    if sf > 0.05 then
      for i = 1, 4 do
        local fr = frac(i * 2 - 1)
        local x = wx(i + (i > 2 and 2 or 0), fr) + (i % 2 == 0 and 8 or -8) * fr
        local y = wy(fr)
        local h = math.max(2, math.floor(stab_h[i] * 10 * fr + 3))
        line(4.5 * sf, x, y, x, y + h)
        put(6 * sf, x - 2, y + h, 5, 2)
        put(2.5 * sf, x - 6, y + h + 2, 13, 1)
      end
    end

    -- sparks at the joints: blue-white where wires meet the stations
    for i = 1, #sparks do
      local sp = sparks[i]
      local a = NOW - sp.t
      if a < 0.35 then
        local fr = frac(sp.n)
        local x, y = wx(sp.w, fr), wy(fr)
        local l = (sp.k == 1 and 6 or 7) * (1 - a / 0.35)
        put(l, x - 1, y - 1, 3, 3)
        line(l * 0.8, x - 6 - a * 14, y, x + 6 + a * 14, y)
        line(l * 0.7, x, y - 7 - a * 12, x, y + 7 + a * 12)
        line(l * 0.5, x - 5 - a * 10, y - 5 - a * 10, x + 5 + a * 10, y + 5 + a * 10)
      end
    end

    -- the pantograph: a small collector on a contact wire, sliding with the arps
    do
      local pf = fade(panto_t, 0.8)
      panto_s = K.follow(panto_s, panto_x, 0.35, DT)
      local f = 0.25 + 0.75 * (1 - panto_s)
      local w = 1 + 2 * ((panto_lane - 1) % 3)
      local x, y = wx(w, f), wy(f)
      local l = 3 + 4 * pf
      put(l, x - 3, y, 7, 1)
      line(l * 0.8, x - 4, y + 5, x, y); line(l * 0.8, x + 4, y + 5, x, y)
      line(l * 0.6, x - 4, y + 5, x + 4, y + 5)
      if pf > 0.05 then put(3 * pf, x - 7, y - 2, 15, 1); line(3 * pf, x, y - 1, x, y - 7) end
    end

    -- the pad: slow bands low in the frame at the notes' columns
    if pdz > 0.03 then
      for i = 1, #pad_notes do
        local x = K.px(pad_notes[i])
        for r = 0, 4 do
          local w = 8 + r * 6 + math.floor(math.sin(T * 0.5 + i + r) * 4)
          put(pdz * (3.2 - r * 0.5), x - w / 2, 22 + r * 4, w, 1)
        end
      end
    end

    K.grain(function(u, v) return u * 124 + 2, 4 + v * 56 end, hi * 40, 7)
  end

  M.init()
  return M
end
