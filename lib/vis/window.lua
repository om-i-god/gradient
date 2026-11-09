-- window: the city at night through a rain-streaked window. out of focus
-- beyond the glass the chord hangs as four bokeh discs at its voices'
-- pitches, swelling when stabbed; the bass is a big low streetlamp blur;
-- the arp notes are far windows switching on along the skyline, one row
-- per lane. on the glass: beads, and drops that slide down in jerks,
-- every pump shaking them on, joining up as they go. dub throws ghost the
-- discs in the double glazing at the echo time; kickless stretches mist
-- the glass and slow the drops; the highs glint in the beads
return function(K)
  local M = {}
  local put, A, clamp = K.put, K.A, K.clamp

  local MX, MW = 86, 3                  -- the mullion
  local SILL = 58                        -- the sill's top

  -- a row on the glass, split around the mullion and kept above the sill
  local function row(l, x, y, w)
    if y < 0 or y >= SILL or w < 1 then return end
    x = math.floor(x); w = math.floor(w)
    local x1 = x + w
    if x < MX and x1 > MX then
      put(l, x, y, MX - x, 1)
      if x1 > MX + MW then put(l, MX + MW, y, x1 - MX - MW, 1) end
    elseif x >= MX and x < MX + MW then
      if x1 > MX + MW then put(l, MX + MW, y, x1 - MX - MW, 1) end
    else
      put(l, x, y, w, 1)
    end
  end

  -- the far skyline, very soft
  local far = K.profile(function(x)
    local b = x // 7
    return 34 + math.floor(K.hash(b, 41) * 10) - math.floor(math.exp(-((x - 40) / 22) ^ 2) * 8)
  end)

  local disc = {}                        -- the chord's bokeh: {x, y, r, k}
  local lamp = 0                         -- the bass blur, eased
  local lights = {}                      -- far windows switched on by the arps
  local drops = {}                       -- drops sliding on the glass
  local ghost = {}                       -- the discs' echoes in the glazing
  local mist = 0

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own
  local hit, percs = {}, {}
  local pdz = 0                          -- the pad, eased in
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
  function M.hat() mark("hat") end
  function M.bass() mark("bass") end
  function M.clap() mark("clap") end
  function M.tick(kind) mark("tick"); hit.tk = clamp(math.floor(K.num(kind, 1)), 0, 99) % 4 end
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, v = clamp(math.floor(K.num(voice, 1)), 1, 4),
      n = math.floor(K.num(note, 60)) % 12}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    hit, percs, pdz = {}, {}, 0
    disc = {}
    for i = 1, 4 do disc[i] = {x = 14 + (i - 1) * 32, y = 34 - i * 6, r = 6, k = 0} end
    lamp, mist, lights, drops, ghost = 0, 0, {}, {}, {}
  end

  local function new_drop(x)
    if #drops >= 12 then return end
    x = x or 2 + math.floor(K.rnd() * 124)
    if x >= MX - 1 and x <= MX + MW then x = x + MW + 2 end
    drops[#drops + 1] = {x = x, y0 = K.rnd() * 20, y = 0, v = 0, w = K.rnd() < 0.3 and 2 or 1, hold = K.rnd() * 0.6}
    drops[#drops].y = drops[#drops].y0
  end

  function M.arp(lane, note)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    local x = math.floor(K.px(note))
    if x >= MX and x < MX + MW then x = MX + MW end
    local y = 50 - lane * 4 + math.floor(K.hash(x, lane) * 3)
    mark("arp"); hit.ax, hit.ay = x, y
    for i = #lights, 1, -1 do                       -- the same window again: just relight it
      local L = lights[i]
      if L.x == x and L.y == y then L.t0 = K.T; return end
    end
    if #lights >= 40 then table.remove(lights, 1) end
    lights[#lights + 1] = {x = x, y = y, t0 = K.T, life = 2 + 3 * K.hash(x * 3 + y, 9)}
  end

  function M.stab()
    -- the glazing echoes the discs, fading by the feedback
    local fb, et = K.echo_fb, K.echo_t * K.SP
    local a = 0.35 + 0.65 * K.throw
    for k = 1, 3 do
      a = a * fb
      if a < 0.15 or #ghost >= 12 then break end
      ghost[#ghost + 1] = {t0 = K.T + k * et, a = a, k = k}
    end
  end

  function M.pump()
    mark("pump")
    -- the pump shakes the glass: drops jerk on, sometimes a new one starts
    for _, d in ipairs(drops) do d.hold = 0; d.v = d.v + 14 + 10 * K.rnd() end
    if K.rnd() < 0.5 then new_drop() end
  end

  -- a row at a fractional x: the end pixels take the share they cover
  local function srow(l, x, y, w)
    local ix = math.floor(x)
    local f = x - ix
    if f < 0.12 or w < 2 then return row(l, ix, y, w) end
    row(l * (1 - f), ix, y, 1); row(l, ix + 1, y, w - 1); row(l * f, ix + w, y, 1)
  end

  local function draw_disc(l, cx, cy, r, rim, sub)
    if l < 0.4 or r < 1 then return end
    local rw = sub and srow or row
    for dy = -r, r do
      local u = dy / (r + 0.5)
      local hw = math.floor(r * math.sqrt(math.max(0, 1 - u * u)) + 0.5)
      if hw > 0 then
        local y = math.floor(cy + dy)
        if math.abs(dy) >= r - 1 then rw(l + rim, cx - hw, y, 2 * hw)
        elseif dy % 2 == 0 and rim > 0 then
          rw(l, cx - hw + 1, y, 2 * hw - 2)
          rw(l + rim, cx - hw, y, 1); rw(l + rim, cx + hw - 1, y, 1)
        else
          rw(l, cx - hw, y, 2 * hw)
        end
      end
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
    local c = K.chord
    local mean = (c[1] + c[2] + c[3] + c[4]) / 4
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local kk, hh, cl, tk = fade("kick", 0.3), fade("hat", 0.3), fade("clap", 0.3), fade("tick", 0.4)
    local bh = fade("bass", 0.4)
    local pu = fade("pump", 0.3)
    local pd, mid = pdz, A[K.MID]
    local mf = fp and mid or 0             -- the mids lift the lit windows and the glow (fine)
    mist = K.follow(mist, 0.2 * kl + 0.1 * K.dub * K.throw + (fp and 0.23 or 0.2) * pd + 0.05 * mid, 1, DT)
    local soft = 1 + kl * 0.25

    -- the far skyline, a dim blur; the city's ground glow under it
    K.gradient(50, SILL - 1, function(y)
      return 0.15 + 0.35 * (y - 50) / 7 + 0.3 * lamp
    end)
    -- the street far below: smeared lights, shimmering through the water
    for i = 0, 15 do
      local x = math.floor(K.hash(i, 61) * 124)
      local y = 40 + math.floor(K.hash(i, 62) * 14)
      local w = 3 + math.floor(K.hash(i, 63) * 7)
      local sh = 0.5 + 0.5 * math.sin(T * (0.4 + K.hash(i, 64)) + i * 2.7 + 2.5 * mid)
      local l = 1 + K.hash(i, 65) * 1.2 + sh * 0.8 + e * 0.5 + ((x < 90 or x > 122) and 1.6 * mf or 0)
      row(l, x, y, w)
      if w > 4 and not fp then row(l * 0.6, x + 1, y + 1, w - 2) end
    end
    -- buildings: unlit masses cut out of the glow are too sharp through
    -- wet glass, so they show only as the dim rows of their windows
    for c2 = 0, 63, 2 do
      local top = far[c2]
      for y = top + 2, SILL - 6, 3 do
        if K.hash(c2 * 31 + y, 5) > (fp and 0.66 or 0.55) then row(1.8 + ((c2 * 2 < 92 or c2 * 2 > 120) and 2.4 * mf or 0), c2 * 2, y, 2) end
      end
    end

    -- the bass: a big streetlamp blur low on the right, and the kick in it
    local bassg = K.gain(S, "bass") > 0 and 1 or 0.4
    lamp = K.follow(lamp, math.max(K.env.bass * bassg * 0.8, A[K.LO] * 0.75, K.env.kick * (fp and 0.6 or 0.5)), 0.07, DT)
    draw_disc(1 + lamp * (fp and 3.4 or 3), 106, 50, math.floor(8 + lamp * 3 + kl * 2), 0.8)
    -- the kick swells the lamp's blur
    -- a bass note lights a hot core in it
    if bh > 0.03 then
      draw_disc(E(4 * bh), 106, 50, 6, 0)
      if fine then                          -- the blur blooms round the core, and the sill below it takes the light
        local bn = (hit.bassn or 0) % 3        -- each note throws its light to the next place along the sill
        row(E(4.5 * bh), 90 + bn * 4, SILL - 1, 24); row(E(3 * bh), 94 + bn * 4, SILL - 2, 16)
      end
    end
    if kk > 0.03 then draw_disc(E(fine and 4.4 * kk or 3.5 * kk), 106, 50, math.floor(9 + (hit.kickn or 0) % 3 * 2 + lamp * 3 + kl * 2), 0) end

    -- the arp lights: far windows switching on, holding, going out
    for i = #lights, 1, -1 do
      local L = lights[i]
      local age = T - L.t0
      if age > L.life then table.remove(lights, i)
      else
        local on = math.min(1, age / 0.08) * math.min(1, (L.life - age) / 0.8)
        if on > 0.5 then row(1.2 + on, L.x - 1, L.y, 3) end
        put((3 + 5 * on) * (0.8 + 0.2 * e), L.x, L.y, 1, 1)
      end
    end

    -- the chord as bokeh: each voice a soft disc, swelling when stabbed and
    -- breathing with the pump
    local breathe = 1 - K.duck * 0.12
    for i = 1, 4 do
      local d = disc[i]
      local tx = 12 + (i - 1) * 31 + math.sin(T * 0.13 + i * 2.1) * 6
      local ty = clamp(30 - (c[i] - mean) * 1.6, 7, 44)
      d.x = K.follow(d.x, tx, 0.6, DT)
      d.y = K.follow(d.y, ty, 0.4, DT)
      d.k = K.follow(d.k, K.voice_kick[i], 0.06, DT)
      local r = math.floor((5 + (4 - i) * 0.7 + d.k * 2) * soft * breathe + 0.5)
      local l = (1.6 + 1.2 * e + d.k * (fp and 4.6 or 4)) * (1 - kl * 0.25) * (1 + (fp and 0.36 or 0.3) * A[K.AMP])
      draw_disc(l, d.x, d.y, r, 1 + A[K.HI] * 0.5, fp)
    end
    -- the discs' ghosts in the double glazing, at the echo time
    for i = #ghost, 1, -1 do
      local g = ghost[i]
      local u = (T - g.t0) / 0.6
      if u >= 1 then table.remove(ghost, i)
      elseif u >= 0 then
        local a = g.a * math.sin(math.pi * u)
        for v = 1, 4 do
          local d = disc[v]
          draw_disc(a * 3.5, d.x + 4 * g.k, d.y + 3 * g.k, math.floor(4 + (4 - v) * 0.5), 0)
        end
      end
    end

    -- the frame: the mullion's edge and the sill catch the room's light
    put(1, MX, 0, 1, SILL)
    put(2, MX + MW - 1, 0, 1, SILL)
    put(2, 0, SILL, 128, 1)
    -- the newest window flares in the wet air round it
    local af = fade("arp", 0.45)
    if af > 0.03 then
      for dy = -3, 3 do row(E(fine and 6.5 * af or 5 * af), hit.ax - 6, hit.ay + dy, 13) end
      if fine then                          -- a wider bloom of wet air, and the pane's reflection of the window
        for dy = -4, 4, 4 do row(E(4 * af), hit.ax - 10, hit.ay + dy, 21) end
        row(E(5 * af), hit.ax - 1, math.min(SILL - 1, hit.ay + 8), 3)
      end
    end
    -- a clap swells the light along the mullion
    if cl > 0.03 then put(E(5 * cl), MX, 0, MW, SILL) end
    -- a perc: a small far light, its voice the height, its note the place
    for i = #percs, 1, -1 do
      local p = percs[i]
      local v = math.exp(-(K.NOW - p.t) / (0.35 * TR()))
      if v < 0.03 then table.remove(percs, i)
      else draw_disc(E(fine and 5.6 * v or 5 * v), 8 + p.n * 9, 12 + p.v * 8, 3, 0) end
    end
    -- a tick: a glint on a bead of the glass
    if tk > 0.03 then
      local gx, gy = 10 + hit.tk * 24 + (hit.tickn or 0) % 3 * 5, 16 + (hit.tickn or 0) % 4 * 9
      for dy = -1, 1 do row(E(fine and 6.8 * tk or 6 * tk), gx - 5, gy + dy, 11) end
      for dy = -3, 3 do if dy < -1 or dy > 1 then row(E(fine and 6.8 * tk or 6 * tk), gx - 1, gy + dy, 3) end end
    end
    put(1, 0, SILL + 3, 128, 1)

    -- a drop on the glass is a lens: over a disc it carries the disc's light
    local function lens(x, y)
      local best = 0
      for i = 1, 4 do
        local d = disc[i]
        local dx, dy = x - d.x, y - d.y
        if dx * dx + dy * dy < 49 then best = math.max(best, 2 + d.k * 4) end
      end
      local dx, dy = x - 106, y - 50
      if dx * dx + dy * dy < 81 then best = math.max(best, 1.5 + lamp * 3) end
      return best
    end

    -- the glass: mist, beads, sliding drops
    K.haze(0, 14, 128, SILL, mist, 1, T * 1.5)
    local hi = A[K.HI]
    -- a hat glints a handful of beads, a different handful each time
    if hh > 0.03 then
      local hn = hit.hatn or 0
      for j = 1, 8 do
        local gx, gy = math.floor(K.hash(hn * 8 + j, 91) * 126), math.floor(K.hash(hn * 8 + j, 92) * (SILL - 3))
        row(E(fine and 6.8 * hh or 6 * hh), gx, gy, 3); row(E(fine and 6.8 * hh or 6 * hh), gx, gy + 1, 3)
      end
    end
    -- a pump shivers the beads on the glass, a different handful each time (fine)
    if fine and pu > 0.03 then
      local pn = hit.pumpn or 0
      for j = 1, 5 do
        local gx, gy = math.floor(K.hash(pn * 10 + j, 93) * 124), math.floor(K.hash(pn * 10 + j, 94) * (SILL - 3))
        row(E(5.5 * pu), gx, gy, 4); row(E(5.5 * pu), gx, gy + 1, 4)
      end
    end
    for i = 0, 33 do
      local life = 6 + 6 * K.hash(i, 51)
      local ph = T / life + K.hash(i, 52)
      local gen = math.floor(ph)
      local u = ph - gen
      local x = math.floor(K.hash(i * 97 + gen, 53) * 127)
      local y = math.floor(K.hash(i * 89 + gen, 54) * (SILL - 2))
      local a = math.min(1, u * 6, (1 - u) * 6)
      local tw = 0.5 + 0.5 * math.sin(T * 3 + i * 1.7)
      local ln = lens(x, y)
      row((1.5 + ln + hi * 3 * tw) * a, x, y, 1)
      if a > 0.5 then row((2.5 + ln * 1.5 + hi * 4 * tw) * a, x, y - 1, i % 3 == 0 and 2 or 1) end
    end
    -- dense: a second, finer set of beads, condensation on the cold glass
    if dense and fp then
      for i = 34, 45 do
        local life = 9 + 5 * K.hash(i, 51)
        local ph = T / life + K.hash(i, 52)
        local gen = math.floor(ph)
        local u = ph - gen
        local a = math.min(1, u * 5, (1 - u) * 5)
        local x = math.floor(K.hash(i * 97 + gen, 53) * 127)
        local y = math.floor(K.hash(i * 89 + gen, 54) * (SILL - 2))
        row((1.4 + lens(x, y) + hi * 2) * a, x, y, 1)
      end
    end
    if #drops < 5 then new_drop() end
    local g = 26 * (1 - kl * 0.6)
    for i = #drops, 1, -1 do
      local d = drops[i]
      -- stick and slip: a drop holds, then runs and slows as it sheds water
      if d.hold > 0 then d.hold = d.hold - K.DTS
      else
        d.v = d.v + g * K.DTS * K.rnd()
        d.y = d.y + d.v * K.DTS
        d.v = d.v * math.exp(-K.DTS * 2.5)
        if d.v < 2 and K.rnd() < K.DTS * 1.5 then d.hold = 0.3 + K.rnd() * 1.2; d.v = 0 end
        d.x = d.x + (K.hash(math.floor(d.y), d.w) - 0.5) * 6 * K.DTS
      end
      if d.y > SILL + 1 then table.remove(drops, i)
      else
        local x = math.floor(d.x)
        local y = math.floor(d.y)
        -- the wet track it leaves, and its head catching the light
        if y - d.y0 > 1 then put(1, x, d.y0, 1, y - d.y0) end
        local ln = lens(x, y)
        local hl = 5 + ln * 1.5 + hi * 3 + (d.v > 4 and 1.5 or 0)
        if fp and y < SILL - 1 and (d.x < MX - 2 or d.x > MX + MW + 1) then
          -- the head glides: its level split between the rows (and columns) it sits across
          row(2 + ln, x, y - 1, d.w)
          K.put_sub(hl, d.x, d.y, d.w, 1)
          row(2.5 + ln, x, y + 1, d.w)
        else
          row(2 + ln, x, y - 1, d.w)
          row(hl, x, y, d.w)
          row(2.5 + ln, x, y + 1, d.w)
        end
      end
    end
    -- two drops meeting run on as one
    for i = #drops, 2, -1 do
      local a, b = drops[i], drops[i - 1]
      if math.abs(a.x - b.x) < 2 and math.abs(a.y - b.y) < 2 then
        b.w = 2; b.v = math.max(a.v, b.v) + 4; b.hold = 0
        table.remove(drops, i)
      end
    end
  end

  M.init()
  return M
end
