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

  function M.init()
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
    -- the pump shakes the glass: drops jerk on, sometimes a new one starts
    for _, d in ipairs(drops) do d.hold = 0; d.v = d.v + 14 + 10 * K.rnd() end
    if K.rnd() < 0.5 then new_drop() end
  end

  local function draw_disc(l, cx, cy, r, rim)
    if l < 0.4 or r < 1 then return end
    for dy = -r, r do
      local u = dy / (r + 0.5)
      local hw = math.floor(r * math.sqrt(math.max(0, 1 - u * u)) + 0.5)
      if hw > 0 then
        local y = math.floor(cy + dy)
        if math.abs(dy) >= r - 1 then row(l + rim, cx - hw, y, 2 * hw)
        elseif dy % 2 == 0 and rim > 0 then
          row(l, cx - hw + 1, y, 2 * hw - 2)
          row(l + rim, cx - hw, y, 1); row(l + rim, cx + hw - 1, y, 1)
        else
          row(l, cx - hw, y, 2 * hw)
        end
      end
    end
  end

  function M.draw(S)
    local T, DT, e = K.T, K.DT, K.energy
    local kl = K.kickless
    local c = K.chord
    local mean = (c[1] + c[2] + c[3] + c[4]) / 4
    mist = K.follow(mist, 0.2 * kl + 0.1 * K.dub * K.throw, 1, DT)
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
      local sh = 0.5 + 0.5 * math.sin(T * (0.4 + K.hash(i, 64)) + i * 2.7)
      local l = 1 + K.hash(i, 65) * 1.2 + sh * 0.8 + e * 0.5
      row(l, x, y, w)
      if w > 4 then row(l * 0.6, x + 1, y + 1, w - 2) end
    end
    -- buildings: unlit masses cut out of the glow are too sharp through
    -- wet glass, so they show only as the dim rows of their windows
    for c2 = 0, 63, 2 do
      local top = far[c2]
      for y = top + 2, SILL - 6, 3 do
        if K.hash(c2 * 31 + y, 5) > 0.55 then row(1.8, c2 * 2, y, 2) end
      end
    end

    -- the bass: a big streetlamp blur low on the right, and the kick in it
    local bassg = K.gain(S, "bass") > 0 and 1 or 0.4
    lamp = K.follow(lamp, math.max(K.env.bass * bassg * 0.8, A[K.LO] * 0.75, K.env.kick * 0.5), 0.07, DT)
    draw_disc(1 + lamp * 3, 106, 50, math.floor(8 + lamp * 3 + kl * 2), 0.8)

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
      local l = (1.6 + 1.2 * e + d.k * 4) * (1 - kl * 0.25)
      draw_disc(l, d.x, d.y, r, 1 + A[K.HI] * 0.5)
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
        row(2 + ln, x, y - 1, d.w)
        row(5 + ln * 1.5 + hi * 3 + (d.v > 4 and 1.5 or 0), x, y, d.w)
        row(2.5 + ln, x, y + 1, d.w)
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
