-- substation: a fenced yard of transformers and insulators at night. three
-- transformer tanks with radiator fins and ribbed bushings stand under a
-- gantry of hanging insulator strings; a small control room sits at the
-- right, and a chain-link fence with barbed top runs across the front. the
-- low band hums as heat shimmer over the transformers, the pump sways the
-- gantry wires, the kick brightens the tank outlines. clap arcs between two
-- bushing tops and perc arcs down from the gantry to a bushing (brief, thin,
-- dim). stabs light the control-room windows (note = window), the pad is
-- the sodium glow over the fence (a lamp head per note), bass warms the
-- tank cores, arps light an insulator string disc by disc (lane = string,
-- note = how far), hats glint along the barbed wire, ticks spit a spark
-- off a radiator. mids lift the windows' idle glow, highs glitter on the
-- fence, the level lights the sky
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local GY = 47                          -- ground line
  local TANK = {{8, 26}, {40, 26}, {72, 26}}  -- x, width of each tank
  local TY0 = 33                         -- tank top
  local GANT = 19                        -- the gantry bar
  local STR = {14, 30, 46, 62, 78, 94}   -- insulator string x on the gantry
  local FY0, FY1 = 53, 61                -- fence top / bottom rail

  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / tau)
    return v < 0.03 and 0 or v
  end

  local kick_t, pump_t, bass_t, hat_t = -99, -99, -99, -99
  local hat_x, hat_n = 20, 0
  local win = {}
  for i = 1, 6 do win[i] = -99 end
  local arcs = {}
  for i = 1, 4 do arcs[i] = {t = -99, x0 = 0, y0 = 0, x1 = 0, y1 = 0, s = 1} end
  local ai, arc_n = 0, 0
  local strs = {}
  for i = 1, 6 do strs[i] = {t = -99, n = 5} end
  local sparks = {}
  for i = 1, 4 do sparks[i] = {t = -99, x = 10, y = 40, k = 1} end
  local spi, tick_n = 0, 0
  local pad_notes = {}
  local pdz = 0

  function M.init()
    kick_t, pump_t, bass_t, hat_t = -99, -99, -99, -99
    hat_x, hat_n, arc_n, tick_n = 20, 0, 0, 0
    for i = 1, 6 do win[i] = -99; strs[i].t = -99 end
    for i = 1, 4 do arcs[i].t = -99; sparks[i].t = -99 end
    pad_notes = {}
    pdz = 0
  end
  M.clear = M.init

  -- bushing tops: three per tank
  local function bush(tank, k)
    local t = TANK[tank]
    return t[1] + 4 + (k - 1) * ((t[2] - 8) / 2), TY0 - 8
  end

  local function arc(x0, y0, x1, y1)
    arc_n = arc_n + 1
    ai = ai % #arcs + 1
    local a = arcs[ai]
    a.t, a.x0, a.y0, a.x1, a.y1, a.s = K.NOW, x0, y0, x1, y1, arc_n
  end

  function M.kick() kick_t = K.NOW end
  function M.pump() pump_t = K.NOW end
  function M.bass(note) bass_t = K.NOW end
  function M.hat()
    hat_n = hat_n + 1
    hat_t = K.NOW
    hat_x = 6 + (hat_n * 37) % 112
  end
  function M.clap()
    arc_n = arc_n + 1
    local a = arc_n % 2 + 1
    local x0, y0 = bush(a, 3)
    local x1, y1 = bush(a + 1, 1)
    arc(x0, y0, x1, y1)
  end
  function M.perc(voice, _)
    voice = clamp(math.floor(K.num(voice, 1)), 1, 4)
    local tank = (voice + arc_n) % 3 + 1
    local bx, by = bush(tank, voice % 3 + 1)
    arc(STR[(voice + tank) % 6 + 1], GANT + 5, bx, by)
  end
  function M.tick(kind)
    kind = clamp(math.floor(K.num(kind, 1)), 1, 4)
    tick_n = tick_n + 1
    spi = spi % #sparks + 1
    local s = sparks[spi]
    s.t, s.k = K.NOW, kind
    s.x = TANK[(tick_n + kind) % 3 + 1][1] + 3 + (tick_n * 5 + kind * 3) % 20
    s.y = TY0 + 3 + (tick_n * 3) % 8
  end
  function M.stab(notes)
    if type(notes) ~= "table" then notes = {60} end
    for i = 1, math.min(#notes, 4) do
      local n = math.floor(K.num(notes[i], 60))
      win[n % 6 + 1] = K.NOW
    end
    if #notes == 0 then win[1] = K.NOW end
  end
  function M.arp(lane, note, step)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    note = K.num(note, 72)
    local s = strs[(lane * 2 + math.floor(K.num(step, 1))) % 6 + 1]
    s.t = K.NOW
    s.n = clamp(math.floor((note - 48) / 12) + 2, 1, 5)
  end
  function M.pad(notes)
    pad_notes = {}
    if type(notes) == "table" then
      for i = 1, math.min(#notes, 6) do pad_notes[i] = K.num(notes[i], 50) end
    end
  end
  function M.bar() end

  -- a jagged arc from (x0,y0) to (x1,y1), steady between draws
  local function bolt(l, a, f)
    local px, py = a.x0, a.y0
    for i = 1, 4 do
      local u = i / 4
      local nx = a.x0 + (a.x1 - a.x0) * u
      local ny = a.y0 + (a.y1 - a.y0) * u - math.sin(u * math.pi) * 5
      if i < 4 then
        nx = nx + (K.hash(a.s, i) - 0.5) * 5
        ny = ny + (K.hash(a.s, i + 7) - 0.5) * 4
      end
      line(l, px, py, nx, ny)
      px, py = nx, ny
    end
    put(l * 0.6, a.x0 - 1, a.y0 - 1, 3, 1)
    put(l * 0.6, a.x1 - 1, a.y1 - 1, 3, 1)
    put(l * 0.35 * f, math.min(a.x0, a.x1), math.min(a.y0, a.y1) - 3, math.abs(a.x1 - a.x0) + 1, 1)
  end

  function M.draw(S)
    local T, DT = K.T, K.DT
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local kk, pf, bt = fade(kick_t, 0.25), fade(pump_t, 0.3), fade(bass_t, 0.3)
    local hf = fade(hat_t, 0.12)

    -- the sky: faint sodium haze low over the yard, thicker with the pad
    for y = 6, GY - 6, 6 do
      local v = 0.3 + (y / GY) * (0.6 + 1.2 * amp)
      if v > 0.9 then K.dashes(math.min(2, v), y, 3, 10, y * 3 + T * 5, 0, 128) end
    end
    K.haze(0, 26, 128, GY, 0.12 + pdz * 0.4, 1.2 + 1.2 * pdz, T * 3)
    for i = 1, #pad_notes do
      local x = K.px(pad_notes[i])
      put(3 + 3 * pdz, x - 1, 40, 3, 1)
      put(2.5 * pdz, x - 5, 41, 11, 1)
    end

    -- ground and the gravel line
    line(1.5, 0, GY, 127, GY)

    -- the gantry bar, wires swaying with the pump, strings hanging off it
    local sag = 1 + 5 * pf
    line(2 + mid * 1.5 + 4 * pf, 2, GANT, 108, GANT)
    if pf > 0.05 then line(3 * pf, 2, GANT - 2, 108, GANT - 2); line(2.5 * pf, 2, GANT + 1, 108, GANT + 1) end
    line(1.4, 4, GANT, 4, GY); line(1.4, 106, GANT, 106, GY)
    for i = 1, #STR do
      local x = STR[i]
      local s = strs[i]
      local f = fade(s.t, 0.4)
      for d = 1, 5 do
        local lit = f > 0 and d <= s.n
        put(lit and (3.5 + 3.5 * f) or 2.5, x - 1, GANT + 1 + d * 2, 3, 1)
      end
      line(1.5, x, GANT, x, GANT + 1)
      if f > 0 then
        put(4 * f, x - 3, GANT + 3 + s.n * 2, 7, 1)
        put(2.5 * f, x - 6, GANT + 4 + s.n * 2, 13, 1)
        put(2.5 * f, x, GANT + 1, 1, 11)
      end
    end
    -- conductors from the string feet down to the bushing tops (sagging)
    for t = 1, 3 do
      for k = 1, 3 do
        local bx, by = bush(t, k)
        local sx = STR[((t - 1) * 2 + k) % 6 + 1]
        local mx, my = (bx + sx) / 2, (GANT + 13 + by) / 2 + sag
        line(1.4, sx, GANT + 12, mx, my)
        line(1.4, mx, my, bx, by)
      end
    end

    -- the transformers: tank outline, radiator fins, bushings, warm core
    for t = 1, 3 do
      local x0, w = TANK[t][1], TANK[t][2]
      line(2 + 3 * kk + bt, x0, TY0, x0 + w, TY0)
      line(2 + 3 * kk + bt, x0, TY0, x0, GY)
      line(2 + 3 * kk + bt, x0 + w, TY0, x0 + w, GY)
      line(1.5, x0 - 2, TY0 + 4, x0 + w + 2, TY0 + 4)
      for fx = x0 + 3, x0 + w - 2, 5 do line(1, fx, TY0 + 5, fx, GY - 1) end
      if bt > 0.04 then
        for y = TY0 + 6, GY - 2, 3 do put(6 * bt, x0 + 1, y, w - 1, 1) end
        put(4 * bt, x0 - 3, GY - 1, w + 7, 1); put(3 * bt, x0 - 5, GY, w + 11, 1)
      end
      for k = 1, 3 do
        local bx, by = bush(t, k)
        line(2.2, bx, by, bx, TY0)
        for y = by + 1, TY0 - 1, 2 do put(3, bx - 1, y, 3, 1) end
        put(3 + 2 * kk, bx - 1, by - 1, 3, 1)
      end
      -- the hum: heat shimmer over the tank
      local hum = 0.12 + lo
      if hum > 0.05 then
        for r = 0, 1 do
          local yy = TY0 - 11 + r * 3
          local wob = math.sin(T * 5 + r * 1.3 + t * 2) * (2 + 3 * hum)
          K.dashes(0.5 + 3.4 * hum, yy, 3, 6, wob * 3 + r * 5 + t * 7, x0 - 2, x0 + w + 2)
        end
      end
    end

    -- the control room, right: a block with six windows
    local cx, cy = 108, 36
    line(2, cx, cy, cx + 18, cy); line(1.6, cx, cy, cx, GY); line(1.6, cx + 18, cy, cx + 18, GY)
    line(1.4, cx - 1, cy - 2, cx + 19, cy - 2)
    for i = 1, 6 do
      local wx = cx + 2 + ((i - 1) % 3) * 6
      local wy = cy + 3 + ((i - 1) // 3) * 6
      local f = fade(win[i], 0.5)
      local l = 1.2 + mid * 1.8 + 7 * f
      put(l, wx, wy, 4, 3)
      if f > 0 then
        put(3 * f, wx - 1, wy + 3, 6, 1)
        put(2 * f, wx - 2, wy - 1, 8, 1)
      end
    end

    -- the fence: rails, posts, mesh, barbed top
    line(1.8, 0, FY0, 127, FY0); line(1.4, 0, FY1, 127, FY1)
    for x = 2, 127, 16 do line(1.8, x, FY0 - 2, x, FY1) end
    for x = 0, 127, 10 do line(0.7, x, FY0 + 1, x + 8, FY1 - 1) end
    K.dashes(1.4, FY0 - 2, 1, 3, T * 2, 0, 128)
    -- floodlight heads on the posts glow with the pad
    if pdz > 0.05 then
      for x = 14, 127, 24 do
        put(2 + 4 * pdz, x - 1, FY0 - 4, 3, 1)
        put(1.6 * pdz, x - 4, FY0 - 3, 9, 1)
      end
    end
    if hf > 0 then
      put(7 * hf, hat_x - 1, FY0 - 3, 3, 1)
      put(4 * hf, hat_x - 6, FY0 - 2, 13, 1)
      put(2.5 * hf, hat_x - 10, FY0 - 1, 21, 1)
    end
    K.grain(function(u, v) return u * 127, FY0 + v * 8 end, hi * 90, 7)
    if hi > 0.04 then
      K.dashes(hi * 4, FY0 + 2, 1, 9, T * 9, 0, 128); K.dashes(hi * 3, FY1 + 1, 2, 11, T * 5, 0, 128)
    end
    if pf > 0.05 then
      for y = FY0 + 1, FY1, 2 do put(2.4 * pf, 0, y, 128, 1) end
    end

    -- sparks off the radiators
    for i = 1, #sparks do
      local s = sparks[i]
      local f = fade(s.t, 0.25)
      if f > 0 then
        put(8 * f, s.x, s.y, 1, 1)
        put(6 * f, s.x - 3, s.y, 7, 1)
        put(6 * f, s.x, s.y - 3, 1, 7)
        put(3 * f, s.x - 6, s.y, 13, 1)
        put(3 * f, s.x - 2, s.y + 3, 5, 1)
        put(2.5 * f, s.x - 1, GY - 2, 3, 2)
        put(2 * f, s.x - 8, s.y - 1, 17, 1); put(2 * f, s.x - 8, s.y + 1, 17, 1)
        put(3 * f, s.x, TY0 + 5, 1, GY - TY0 - 6)
        put(2 * f, s.x - 12, s.y - 3, 25, 1)
        if s.k > 2 then put(3 * f, s.x - 3, s.y - 3, 1, 1); put(3 * f, s.x + 3, s.y + 3, 1, 1) end
      end
    end

    -- arcs between insulators
    for i = 1, #arcs do
      local a = arcs[i]
      local f = fade(a.t, 0.16)
      if f > 0 then
        bolt(2.5 + 2.5 * f, a, f)
        local mx, my = (a.x0 + a.x1) / 2, math.min(a.y0, a.y1)
        put(3 * f, mx - 12, my - 2, 25, 1)
        put(2.4 * f, mx - 18, my, 37, 1)
        put(2 * f, mx - 10, my + 3, 21, 1)
        put(2 * f, a.x0 - 4, a.y0 + 2, 9, 1); put(2 * f, a.x1 - 4, a.y1 + 2, 9, 1)
      end
    end
    -- the kick's thin pulse along the ground
    if kk > 0.04 then
      put(3 * kk, 0, GY + 1, 128, 1)
      put(2 * kk, 20, GY - 1, 88, 1)
    end
  end

  M.init()
  return M
end
