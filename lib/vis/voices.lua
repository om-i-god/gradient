-- voices: the four chord voices as ribbons scrolling right to left over a
-- dim staff, written at a playhead on the right edge. voice leading bends
-- the ribbons as the chord moves; a stab brightens all four with a stem
-- joining them, and its echoes follow as fainter ticks under each ribbon at
-- the echo time, fading by the feedback (a throw drags them out). beat and
-- bar lines scroll past with the music, the pump breathes the ribbons and
-- the playhead, the bass runs its own heavy ribbon along the bottom over a
-- low glow (out_lo), and the highs sparkle at the playhead. kickless
-- stretches set the ribbons wavering in a haze
return function(K)
  local M = {}
  local put, A, clamp, follow = K.put, K.A, K.clamp, K.follow

  local RATE = 20                         -- scroll, px per second of motion time
  local STEP = 2 / RATE                   -- one 2-px column per STEP
  local NCOL = 66
  local HEAD = 124                        -- the playhead's column
  local BASS_TOP, BASS_BOT = 53, 62
  local STAFF = {48, 55, 62, 69, 76}   -- staff lines at these pitches

  local cols, next_t                      -- newest first
  local ys = {40, 33, 29, 22}             -- each voice's eased row
  local by = 57                           -- the bass ribbon's eased row
  local echoes = {}                       -- pending echo ticks: {at, v}
  local stab_hit, beat_seen, bar_seen = 0, 0, 0
  local vk = {0, 0, 0, 0}
  local bs, glow = 0, 0

  local function vrow(n) return clamp(50 - (K.num(n, 60) - 46) * 1.5, 4, 49) end
  local function brow(n)
    n = K.num(n, 36)
    while n > 48 do n = n - 12 end
    while n < 24 do n = n + 12 end
    return clamp(62 - (n - 24) * 0.4, BASS_TOP + 1, BASS_BOT - 1)
  end

  function M.init()
    cols, next_t, echoes = {}, nil, {}
    ys, by = {40, 33, 29, 22}, 57
    stab_hit, beat_seen, bar_seen, bs, glow = 0, 0, 0, 0, 0
    vk = {0, 0, 0, 0}
  end

  function M.stab()
    stab_hit = 1
    -- the echoes: the same stab again at the echo time, fainter by the feedback
    local t, fb = K.echo_t, K.echo_fb
    local v = 1
    for k = 1, 8 do
      v = v * fb
      if v < 0.08 then break end
      echoes[#echoes + 1] = {at = K.NOW + t * k, v = v}
    end
    while #echoes > 24 do table.remove(echoes, 1) end
  end

  function M.kick() beat_seen = 2 end
  function M.pump() if beat_seen < 1 then beat_seen = 1 end end
  function M.bar() bar_seen = 1 end

  -- one new column at the playhead
  local function push(t, S)
    local c = {t = t, y = {}, s = {}}
    local wob = K.kickless * 2.2 + K.throw * 0.8
    for i = 1, 4 do
      c.y[i] = math.floor(ys[i] + math.sin(t * 1.7 + i * 1.9) * wob + 0.5)
      c.s[i] = vk[i]
    end
    c.stem = stab_hit > 0.5 and stab_hit or nil
    stab_hit = 0
    c.beat, c.bar = beat_seen, bar_seen
    beat_seen, bar_seen = 0, 0
    c.by, c.bl = math.floor(by + 0.5), bs
    -- an echo landing now
    local e = 0
    for i = #echoes, 1, -1 do
      if K.NOW >= echoes[i].at then
        e = math.max(e, echoes[i].v); table.remove(echoes, i)
      end
    end
    c.echo = e > 0 and e or nil
    table.insert(cols, 1, c)
    if #cols > NCOL then cols[#cols] = nil end
  end

  -- merged runs of 2-px cells, one per track: a cell joins the run when it
  -- sits right next to it at the same row and level; run(r) flushes
  local runs = {}
  local function run(r, lv, x, y)
    local q = runs[r]
    local l = lv and math.floor(lv + 0.5)
    if q and q.x and lv and l == q.l and y == q.y and x + 2 == q.x then
      q.w, q.x = q.w + 2, x
      return
    end
    if q and q.x and q.l > 0 then put(q.l, q.x, q.y, q.w, 1) end
    if not q then q = {}; runs[r] = q end
    if lv then q.x, q.y, q.l, q.w = x, y, l, 2 else q.x = nil end
  end

  function M.draw(S)
    local T, DT = K.T, K.DT
    local c = K.chord
    local playing = K.playing
    for i = 1, 4 do
      ys[i] = follow(ys[i], vrow(c[i]), 0.25, DT)
      vk[i] = follow(vk[i], K.voice_kick[i], 0.04, DT)
    end
    local bg = K.gain(S, "bass")
    by = follow(by, brow(K.bass_note or 36), 0.15, DT)
    bs = follow(bs, math.max(K.env.bass * (bg > 0 and 1 or 0.5), A[K.LO] * 0.6), 0.05, DT)
    glow = follow(glow, A[K.LO], 0.12, DT)

    -- scroll: columns on an exact time ladder, so neighbours sit 2 px apart
    if not next_t or next_t > T + 1 then next_t = T end
    local n = 0
    while T >= next_t and n < 40 do push(next_t, S); next_t = next_t + STEP; n = n + 1 end
    if T >= next_t then next_t = T + STEP end
    -- the newest column's x; the rest sit exactly 2 px apart
    local x0 = cols[1] and math.floor(HEAD - (T - cols[1].t) * RATE + 0.5) or HEAD
    local function cx(k) return x0 - 2 * (k - 1) end

    local breathe = 1 - K.duck * (0.35 + 0.1 * (1 - K.kickless))
    local base = (playing and (2.2 + K.energy * 1.8) or 2.2) * (0.8 + 0.4 * A[K.MID])

    -- the staff: dotted lines drifting with the scroll
    for _, n2 in ipairs(STAFF) do
      K.dashes(1 + A[K.HI] * 1.6, math.floor(vrow(n2)), 1, 6, -T * RATE, 0, HEAD)
    end
    -- the playhead: the pump breathes it, the kick lights it
    put(1.5 + (1 - breathe) * 6 + K.env.kick * 4, HEAD + 2, 3, 1, BASS_BOT - 3)

    -- beat / bar lines and stems first, so the ribbons sit on top
    for k = 1, #cols do
      local col = cols[k]
      local x = cx(k)
      if x < -1 then break end
      local fade = 1 - k / (NCOL + 8)
      -- the ruler: a tick top and bottom on each beat, a dotted line on the bar
      if col.beat > 0 or col.bar > 0 then
        local l = (col.beat > 1 and 2.5 or 1.5) * fade
        put(l, x, 1, 1, col.bar > 0 and 3 or 2)
        put(l, x, BASS_TOP - 3, 1, 2)
        if col.bar > 0 then
          for y = 6, BASS_TOP - 6, 4 do put(fade, x, y, 1, 1) end
        end
      end
      if col.stem then
        local top, bot = math.min(col.y[4], col.y[1]), math.max(col.y[4], col.y[1])
        for y = top + 2, bot - 2, 3 do put((1 + col.stem) * fade, x + 1, y, 1, 1) end
      end
    end

    -- the ribbons, equal neighbours merged into one rect
    for i = 1, 4 do
      local prev_y
      for k = 1, #cols do
        local col = cols[k]
        local x = cx(k)
        if x < -1 then break end
        local fade = 1 - (k / (NCOL + 6)) ^ 1.5
        local hit = math.max(col.s[i], (col.echo or 0) * 0.7)
        local lv = (base + hit * (7 + i * 0.6)) * fade * breathe
        if k > 6 and lv > 3 then lv = math.floor(lv / 2 + 0.5) * 2 end   -- older: coarser, longer runs
        local y = col.y[i]
        run(1, lv, x, y)
        -- voice leading: join a step between neighbours
        if prev_y and prev_y ~= y then
          local a, b = math.min(prev_y, y), math.max(prev_y, y)
          put(lv * 0.8, x + 2, a, 1, b - a + 1)
        end
        prev_y = y
        -- a stab swells the ribbon upward; its echoes leave a shadow under it
        if hit > 0.35 then run(2, lv * 0.45, x, y - 1) end
        if col.echo and col.echo > 0.2 then
          run(3, (1 + col.echo * 2.5) * fade, x, y + 2)
          if K.throw > 0.3 then run(4, (0.6 + col.echo * 2) * fade * K.throw, x, y + 3) end
        end
      end
      for r = 1, 4 do run(r) end
    end

    -- the bass ribbon: heavy, low, with a glow under it
    K.gradient(BASS_BOT - 1, 63, function(y)
      return (0.2 + glow * 2.4) * (y - BASS_BOT + 2) / 3
    end)
    local run_x, run_y, run_l, run_w
    for k = 1, #cols do
      local col = cols[k]
      local x = cx(k)
      if x < -1 then break end
      local fade = 1 - (k / (NCOL + 6)) ^ 1.3
      local l = math.floor(((playing and 2 or 1) + col.bl * 8) * fade * breathe + 0.5)
      if run_x and col.by == run_y and l == run_l then
        run_x, run_w = x, run_w + (run_x - x)
      else
        if run_x and run_l > 0 then put(run_l, run_x, run_y, run_w, 2) end
        run_x, run_y, run_l, run_w = x, col.by, l, 2
      end
    end
    if run_x and run_l > 0 then put(run_l, run_x, run_y, run_w, 2) end

    -- the heads at the playhead: bright points where each voice is written
    for i = 1, 4 do
      put(4 + vk[i] * 6 + K.env.kick * 2, HEAD, math.floor(ys[i] + 0.5), 2, 1)
    end

    -- haze: kickless and dub loosen the picture
    K.haze(0, 4, 128, BASS_TOP, 0.05 + 0.25 * K.kickless + 0.15 * K.dub * K.throw, 1, T * 5)
    -- the highs: sparkle just behind the playhead, along the ribbons
    K.grain(function(u, v)
      local i = 1 + math.floor(u * 4) % 4
      return HEAD - 2 - v * 30, ys[i] + (K.rnd() < 0.5 and -1 or 1)
    end, A[K.HI] * 70, 8)
  end

  M.init()
  return M
end
