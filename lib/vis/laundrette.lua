-- laundrette: a late-night laundrette seen through its shop window. under
-- the fascia sign and the fluorescent tubes, two dryers stand stacked on
-- the left, then a row of four front-loading washers with round doors and
-- their drums turning, the change machine on the right, a bench in front,
-- and the street reflected in the glass. the drums turn with the energy
-- and the pump; the kick thumps the loads, the bass shakes the machines
-- on their feet, hats glint in the suds, ticks are the timer LEDs, stabs
-- light a door's porthole (note = which), arps are the panel lights over
-- the doors (note = which machine). the clap is a dryer's tumble knock and
-- perc a smaller one (voice = which dryer). the pad steams the window, the
-- pump breathes the light. mids lift the machines, highs glint on the
-- glass, lows hum along the floor, the level lights the sign
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp

  local TOP, SILL = 6, 55                -- the window head and sill
  local FLOOR = 50                       -- the laundrette's floor, through the glass
  -- the machines: x, top, width, height, door centre y, door radius; dryers first
  local MACH = {
    {6, 13, 20, 18, 22, 6}, {6, 31, 20, 19, 41, 6},
    {29, 27, 17, 23, 40, 6}, {47, 27, 17, 23, 40, 6}, {65, 27, 17, 23, 40, 6}, {83, 27, 17, 23, 40, 6},
  }
  local TUBES = {{12, 36}, {46, 72}, {82, 108}}
  local CX0, CX1 = 105, 118              -- the change machine
  local NSEG = 10                        -- segments in a door ring

  -- the fades follow the trails setting at half strength, held within 15% / 10%
  local function TR() return math.min(1.1, math.max(0.85, K.trail ^ 0.5)) end
  local function fade(t, tau)
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    return v < 0.03 and 0 or v
  end
  -- a hit eases in over a frame or so: big areas never jump
  local function rise(t) return math.min(1, 0.4 + (K.NOW - t) / 0.08) end

  local pump_t, clap_t = -99, -99
  local rot = 0                          -- the drums' turn, radians
  local doors = {}                       -- per machine: the stab's porthole light
  local panels = {}                      -- per machine: the arp's panel light
  for i = 1, #MACH do doors[i], panels[i] = -99, 0 end
  local knocks = {}
  for i = 1, 3 do knocks[i] = {t = -99, m = 1} end
  local kni = 0
  local tick_k = 1
  local pdz = 0
  -- hits pile up and drain: each one adds, so it shows whenever it lands
  local acc = {kick = 0, bass = 0, hat = 0, tick = 0, pump = 0}
  local function add(k, v) acc[k] = math.min(1.6, acc[k] + v) end

  function M.init()
    pump_t, clap_t = -99, -99
    rot, tick_k, pdz = 0, 1, 0
    for i = 1, #MACH do doors[i], panels[i] = -99, 0 end
    for i = 1, 3 do knocks[i].t = -99 end
    for k in pairs(acc) do acc[k] = 0 end
  end
  M.clear = M.init

  function M.kick() add("kick", 0.5) end
  function M.pump() pump_t = K.NOW; add("pump", 0.4) end
  function M.bass() add("bass", 0.45) end
  function M.hat() add("hat", 0.6) end
  function M.clap() clap_t = K.NOW end
  function M.perc(voice)
    voice = clamp(math.floor(K.num(voice, 1)), 1, 3)
    kni = kni % #knocks + 1
    knocks[kni].t, knocks[kni].m = K.NOW, voice % 2 + 1
  end
  function M.tick(kind)
    tick_k = clamp(math.floor(K.num(kind, 1)), 1, 4)
    add("tick", 0.8)
  end
  function M.stab(notes)
    if type(notes) ~= "table" then notes = {60} end
    for i = 1, math.min(#notes, 2) do
      doors[math.floor(K.num(notes[i], 60)) % #MACH + 1] = K.NOW
    end
    if #notes == 0 then doors[3] = K.NOW end
  end
  function M.arp(lane, note)
    local i = (math.floor(K.num(note, 72)) + clamp(math.floor(K.num(lane, 1)), 1, 4) * 2) % #MACH + 1
    panels[i] = math.min(2.5, panels[i] + 0.7)
  end
  function M.bar() end

  -- a door: a ring of NSEG segments, r across
  local function ring(l, cx, cy, r)
    local px, py = cx + r, cy
    for i = 1, NSEG do
      local a = i / NSEG * K.TAU
      local nx, ny = cx + math.cos(a) * r, cy + math.sin(a) * r
      line(l, px, py, nx, ny)
      px, py = nx, ny
    end
  end
  -- a filled disc of rows, r across
  local function disc(l, cx, cy, r)
    for dy = -r + 1, r - 1 do
      local w = math.floor(math.sqrt(r * r - dy * dy) + 0.5)
      put(l, cx - w, cy + dy, w * 2 + 1, 1)
    end
  end

  function M.draw()
    local T, DT, DTS, e = K.T, K.DT, K.DTS, K.energy
    local lo, mid, hi, amp = A[K.LO], A[K.MID], A[K.HI], A[K.AMP]
    local dense, RT = K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.4 end      -- eased above 1: the lit bound
    local fp = K.playing                            -- time-driven detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point
    local function E(l) return math.min(l * RT, 13) end
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local pf = fade(pump_t, 0.3) * rise(pump_t)
    local dk = math.exp(-DT / (0.3 * TR()))
    for k, v in pairs(acc) do acc[k] = v < 0.01 and 0 or v * dk end
    local pk = math.exp(-DT / (0.5 * TR()))
    for i = 1, #MACH do panels[i] = panels[i] < 0.01 and 0 or panels[i] * pk end
    local kk, bt, ap, hf, tf = acc.kick, acc.bass, acc.pump, acc.hat, acc.tick
    -- the drums: slow at rest, faster with the energy, a surge on the pump
    rot = (rot + DTS * (0.7 + 2.6 * e + 2.4 * pf)) % K.TAU

    -- the sign over the window: lettering that the level lights
    line(1.6 + 2 * amp, 2, 0, 125, 0)
    K.dashes(1.2 + 3.2 * amp, 2, 3, 5, 0, 24, 104)
    -- the ceiling: three tubes and their glow, breathing with the pump
    for i = 1, #TUBES do
      local a, b = TUBES[i][1], TUBES[i][2]
      put(math.min(13, 4.2 + 1.2 * mid + E(2.4 * pf + 2 * ap)), a, 9, b - a, 1)
      put(1 + E(1.6 * pf + 1.6 * ap), a - 4, 11, b - a + 8, 1)
    end

    -- the back wall and the floor, through the glass
    line(1.2 + 1.8 * lo + E(2.5 * bt), 2, FLOOR, 125, FLOOR)
    if lo + bt > 0.05 then K.dashes(0.6 + 2.6 * lo + E(2.6 * bt), FLOOR + 1, 2, 5, T * 4, 4, 100) end

    -- the machines: bodies, panels, doors, the drums turning inside
    for i = 1, #MACH do
      local m = MACH[i]
      local x, y, w, h, dy, r = m[1], m[2], m[3], m[4], m[5], m[6]
      local cx = x + w / 2
      local ol = 1.6 + 1.2 * mid + E(2.4 * bt)
      line(ol, x, y, x + w, y); line(ol, x, y, x, y + h - 1); line(ol, x + w, y, x + w, y + h - 1)
      line(1.2, x, y + 4, x + w, y + 4)
      -- the feet buzz with the bass
      if bt > 0.05 then put(E(4 * bt), x + 1, y + h, 3, 1); put(E(4 * bt), x + w - 3, y + h, 3, 1) end
      -- the panel: a timer LED and the panel light the arps set going
      local tl = math.min(13, 2 + E(5 * tf) + ((i + tick_k) % 3 == 0 and E(3 * tf) or 0))
      put(tl, x + w - 6, y + 2, 3, 1)
      if tf > 0 then
        put(E(3.4 * tf), x + w - 7, y + 1, 5, 1); put(E(3.4 * tf), x + w - 7, y + 3, 5, 1)
        put(E(2.6 * tf), x + w - 9, y + 2, 2, 1)
      end
      local pl = panels[i]
      put(math.min(13, 1.4 + E(8 * pl)), x + 2, y + 2, 4, 1)
      if pl > 0 then
        put(E(3.6 * pl), x + 1, y + 1, w - 9, 1)
        put(E(3 * pl), x + 1, y + 3, w - 9, 1)
        put(E(3 * pl), x + 3, y + 5, w - 5, 1)
        put(E(2.4 * pl), x + 1, y - 1, w - 1, 1)
      end
      -- the porthole: a stab floods it with light
      local df = fade(doors[i], 0.4)
      if df > 0 then
        disc(E(5 * df), cx, dy, r - 1)
        put(E(3 * df), cx - r - 2, dy, 2, 1); put(E(3 * df), cx + r + 1, dy, 2, 1)
      end
      ring(2.2 + 0.8 * mid + E(4.5 * df), cx, dy, r)
      ring(1.2 + E(2.6 * hf), cx, dy, r - 2)
      -- the load: three lumps of washing going round, thumped by the kick
      local dir = i <= 2 and -1 or 1
      for k = 0, 2 do
        local a = rot * dir + k * K.TAU / 3 + i
        local rr = (r - 3) * (1 - 0.35 * kk)
        K.put_sub(2.4 + E(5 * kk), cx + math.cos(a) * rr - 0.5, dy + math.sin(a) * rr + kk * 1.5 - 0.5, 2, 1)
      end
      if kk > 0.04 then
        -- the load slumps into the bottom of the drum
        put(E(3.4 * kk), cx - r + 2, dy + r - 3, r * 2 - 3, 1)
        put(E(2.6 * kk), cx - r + 3, dy + r - 4, r * 2 - 5, 1)
      end
      -- suds catching the light: the hats
      if hf > 0.02 then
        for k = 1, 2 do
          local a = rot * dir * 0.5 + k * 2.4 + i * 1.3
          local gx, gy = cx + math.cos(a) * (r - 3), dy + math.sin(a) * (r - 3)
          put(E(7 * hf), gx, gy, 1, 1)
          put(E(3.2 * hf), gx - 2, gy, 5, 1); put(E(3.2 * hf), gx, gy - 2, 1, 5)
        end
      end
    end

    -- the clap: a dryer's tumble knock, the stacked pair shaking
    local cf = fade(clap_t, 0.3)
    for q = 1, #knocks + 1 do
      local f, m
      if q <= #knocks then f, m = fade(knocks[q].t, 0.45), MACH[knocks[q].m]
      else f, m = cf * 1.4, MACH[(math.floor(clap_t * 4) % 2) + 1] end
      if f > 0 then
        local x, y, w, h = m[1], m[2], m[3], m[4]
        line(E(5 * f), x, y, x + w, y); line(E(4 * f), x, y, x, y + h - 1); line(E(4 * f), x + w, y, x + w, y + h - 1)
        for k = 0, 2 do
          local ky = y + 4 + k * 5
          line(E(4.5 * f), x - 2, ky, x - 4, ky - 1)
          line(E(4.5 * f), x + w + 2, ky, x + w + 4, ky - 1)
        end
        put(E(3 * f), x + 1, y + h - 1, w - 1, 1)
        ring(E(5.5 * f), x + w / 2, m[5], m[6])
      end
    end

    -- the change machine: a lit display and the coin tray
    line(1.8 + mid, CX0, 20, CX1, 20); line(1.6 + mid, CX0, 20, CX0, FLOOR - 1); line(1.6 + mid, CX1, 20, CX1, FLOOR - 1)
    put(3.4 + E(1.6 * ap), CX0 + 3, 23, 8, 3)
    put(1.6, CX0 + 4, 30, 6, 1)
    put(2, CX0 + 5, 40, 4, 2)

    -- the bench in front of the machines
    line(2, 34, 52, 92, 52); line(1.4, 34, 53, 92, 53)
    line(1.4, 37, 53, 37, 54); line(1.4, 89, 53, 89, 54)

    -- the window: head, jambs, mullion, sill, and the street in the glass
    line(2.4 + 1.6 * amp, 1, TOP, 126, TOP)
    line(2, 1, TOP, 1, SILL); line(2, 126, TOP, 126, SILL)
    line(1.8, 101, TOP, 101, SILL)
    line(2.6, 0, SILL, 127, SILL)
    -- the street's reflection: a lamp and two slow glares drifting over the glass
    put(1.6, 114, 12, 2, 2)
    for k = 0, 1 do
      local gx = (T * 2.2 + k * 64) % 150 - 20
      K.line_sub(1.2, gx, TOP + 2, gx - 12, SILL - 2)
      K.line_sub(1, gx + 3, TOP + 2, gx - 9, SILL - 2)
    end
    K.grain(function(u, v) return 3 + u * 121, TOP + 2 + v * (SILL - TOP - 4) end, hi * 90, 7)
    if hi > 0.04 then
      K.dashes(hi * 3.6, TOP + 1, 1, 6, T * 5, 2, 126)
      K.dashes(hi * 3.2, SILL - 1, 2, 7, -T * 4, 2, 126)
    end

    -- the pad: steam on the window, rising from the sill
    K.haze(2, 30, 126, SILL, 0.03 + 0.45 * pdz, 1.1 + 1.8 * pdz, T * 1.5)
    if pdz > 0.05 then
      K.dashes(E(2.6 * pdz), SILL - 3, 4, 6, T, 2, 126)
      K.dashes(E(2 * pdz), SILL - 6, 3, 7, -T, 2, 126)
    end

    -- the pavement: the shop's light spilling out, breathing with the pump
    K.dashes(1.2 + E(2.4 * pf + 1.6 * ap), 59, 6, 10, 3, 4, 124)

    -- dense: a sock turning in the nearest drum, a fly round a tube
    if dense and fp then
      local m = MACH[3]
      local a = -rot * 1.3
      K.put_sub(2, m[1] + m[3] / 2 + math.cos(a) * 2, m[5] + math.sin(a) * 2, 1, 1)
      local ph = T * 2.2
      K.put_sub(1.8, 59 + math.cos(ph) * 6, 12 + math.sin(ph * 1.4) * 2, 1, 1)
    end
    -- late in the night the energy lights the "open" sign
    if e > 0.05 then put(1 + 3 * e, 110, 16, 6, 1) end
  end

  M.init()
  return M
end
