-- gradient / visuals
-- twenty-four places on the 128x64 OLED at night, drawn from what the music is
-- doing and from what the engine hears of itself. greys on black; the dim
-- levels carry the atmosphere (haze, far structure, texture) and the bright
-- ones are kept for the music. the pulse shows in every theme, the dub
-- leaves trails, and nothing strobes.
--
-- the visuals params reach the kit through VIS.set_trails(v) / VIS.set_react(v)
-- (0..100, 50 = today) and VIS.set_detail("classic"|"fine"|"dense"). themes
-- read K.trail (x their fade times; 0.4..2.5, held back near the lit bound),
-- K.react (x their reaction strength; 0.4..1.8) and K.detail, and place slow
-- things with K.put_sub / K.line_sub (the level split across two pixels).
--
-- the script feeds events as they happen (VIS.event), the engine's output
-- polls as they arrive (VIS.audio) and the conductor state every frame
-- (VIS.draw(theme, S)). under every theme runs the same machine:
--
--   the ears    out_amp / out_lo / out_mid / out_hi from the engine, eased.
--               until one arrives (an engine not yet restarted) they are
--               made up from the old amp poll and the event envelopes
--   the beat    where we are in the beat and the bar, smooth between 16ths
--   the pump    the ghost sidechain: snaps down on each pump and recovers
--               over the beat; kickless stretches ease in and out
--   the arc     the energy (eased), its trend, the dub and the throws
--
-- motion runs on time, not frames: the speed param scales time, and a
-- dropped frame changes nothing but smoothness.
--
-- each theme lives in lib/vis/<name>.lua. it returns a function that takes
-- the kit (K: the helpers below plus a read-only view of the machine,
-- refreshed every frame) and returns {draw = fn(S), stab = fn(notes),
-- bass = fn(note), arp = fn(lane, note, step), kick = fn(), pump = fn(),
-- hat = fn(), clap = fn(), perc = fn(voice, note), tick = fn(kind),
-- pad = fn(notes), bar = fn(S), init = fn(), clear = fn()}; all but draw
-- are optional (a theme without clap / perc / tick hears them as hats,
-- unless VIS.strict is set, which the tests use to find themes that never
-- answer them; pad has no fallback: K.env.pad rises for every theme). events reach only
-- the theme on screen; the kit keeps shared history (K.hist, the
-- envelopes) for every theme.
--
-- the glitch: VIS.event("glitch", mode, dur) tears the picture for as long
-- as the engine's glitch insert runs, whatever the theme: a band of rows
-- holds still on each stutter / chop slice while the rest moves on, slides
-- out and home on a reverse, drifts out while the picture dims through a
-- tape stop, and coarsens on a crush.
--
-- robust: a theme that fails to load, or errors while drawing or hearing
-- an event, is swapped for a plain fallback scene (logged once) instead of
-- taking the screen or the script down; every frame has a draw budget.

local VIS = {}

VIS.audio_level = 0
VIS.names = {"gradient", "voices", "lanes", "phase", "echo", "fall", "pump", "arc",
  "motorway", "tape", "stack", "blocks", "beams", "window", "pylons", "dubplate",
  "radar", "subway", "harbour", "sodium", "lighthouse", "tramlines", "substation", "cooling",
  "carpark"}

local FPS = 20
local TAU = 2 * math.pi

-- state (declared before any function that uses it)
local B = 1                             -- brightness scale for this frame
local SP = 1                            -- speed scale (1 at the default 3)
local T = 0                             -- motion time, s (scaled by speed)
local NOW = 0                           -- real time since init, s
local DT, DTS = 1 / FPS, 1 / FPS        -- this frame's real / motion step
local last_clock                        -- util.time() at the last frame
local cur, xf = nil, 0                  -- theme on screen, its fade (0..1)
local THEMES = {}                       -- the loaded theme modules, by index

-- the engine's output, as polled: raw targets and eased followers
local AMP, LO, MID, HI = 1, 2, 3, 4
local A_IDX = {out_amp = AMP, out_lo = LO, out_mid = MID, out_hi = HI}
local raw = {0, 0, 0, 0}
local A = {0, 0, 0, 0}
local RISE = {0.03, 0.03, 0.05, 0.03}           -- s: rise fast...
local FALL = {0.35, 0.25, 0.4, 0.2}             -- ...fall a little slower
local heard = -1                                -- NOW when a poll last arrived

-- envelopes: events set them to 1, they decay on time
local env = {kick = 0, pump = 0, stab = 0, bass = 0, arp = 0, hat = 0,
  clap = 0, perc = 0, tick = 0, pad = 0}
local ENV_TAU = {kick = 0.12, pump = 0.2, stab = 0.18, bass = 0.2, arp = 0.12, hat = 0.06,
  clap = 0.1, perc = 0.1, tick = 0.05, pad = 0.6}

-- the glitch tear (see the header): time left, length, mode, band, shift
local gl_t, gl_dur, gl_mode = 0, 0, 0
local gl_y0, gl_y1, gl_dx = 0, 0, 0
local gl_sag = 0                        -- tape stop: px the frame has sunk
local gl_dx_abs = 0
local gl_dim = 1                        -- tape stop: eased brightness factor
local gl_slice = -1                     -- stutter / chop: the slice being held
local gl_cap = false                    -- this frame captures the held band
local hold, hn = {}, 0                  -- the held band: level, kind, 4 numbers

-- robustness: themes that failed, the per-frame draw budget
local broken = {}                       -- theme index -> true once it errored
local logged = {}                       -- theme index -> logged already
local OPS_CAP = 1200
local ops = 0
local voice_kick = {0, 0, 0, 0}         -- per chord voice, on a stab
local lane_kick = {0, 0, 0, 0}          -- per arp lane, on a note
local lane_note = {}                    -- lane -> last midi
local lane_step = {}                    -- lane -> last step
local bass_note                         -- last bass midi
local chord = {48, 55, 62, 65}          -- last chord seen (always 4 numbers)

-- the machine
local energy, trend, dub, throw = 0, 0, 0.5, 0
local kickless = 0
local duck, duck_age = 0, 99            -- the ghost sidechain, its age (s)
local beat_ph, bar_ph = 0, 0
local bar_beats = 4
local beat_sec = 0.5
local step_seen, step_t = -1, 0
local bar_kick, bar_pulse = 0, 0
local hist = {}                         -- per bar: {e, kl, ch, pedal}
local HIST_N = 64
local rseed = 1                         -- the visuals' own dice
local energy_seen = false

-- the round-3 visual params (VIS.set_trails / set_detail / set_react) and the
-- trails clamp: the lit ratio of the last 10 frames, measured as the frame is
-- flushed (only while trails is above 1; at the default nothing is measured)
local trail_raw, react_raw, detail = 50, 50, "fine"
local trail_eff, trail_scale = 1, 1
local lit_hist, lit_i = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, 0
local LIT_TRAIL_MAX = 0.38
local lit_seen, lit_stamp = {}, 0

-- the kit every theme draws with (filled in below, refreshed every frame)
local K = {beats = 4, A = A, AMP = AMP, LO = LO, MID = MID, HI = HI, TAU = TAU,
  env = env, voice_kick = voice_kick, lane_kick = lane_kick,
  lane_note = lane_note, lane_step = lane_step, chord = chord,
  hist = hist, HIST_N = HIST_N,
  trail = 1, react = 1, detail = "fine"}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function num(v, d)
  v = tonumber(v)
  if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
  return v
end

-- smoothstep: 0..1 eased at both ends
local function ease(u)
  u = clamp(u, 0, 1)
  return u * u * (3 - 2 * u)
end

-- a follower step toward `to` with time constant `tau` over dt
local function follow(v, to, tau, dt) return v + (to - v) * (1 - math.exp(-dt / tau)) end

-- own dice so the visuals never disturb (or depend on) math.random
local function rnd()
  rseed = (rseed * 1103515245 + 12345) & 0x7fffffff
  return rseed / 2147483648.0
end

-- a fixed hash 0..1 of an integer (and a salt): for shapes that must not move
local function hash(i, s)
  i = num(i, 0)
  if not (i > -1e9 and i < 1e9) then i = 0 end
  i = math.floor(i) // 1 | 0
  local h = ((i * 374761393 + (s or 0) * 668265263) & 0x7fffffff)
  h = ((h ~ (h >> 13)) * 1274126177) & 0x7fffffff
  return (h ~ (h >> 16)) / 2147483648.0
end

-- note -> screen row: the stabs' usual range (Bb2..E5) fills the height
local function py(n)
  n = num(n, 60)
  return clamp(62 - (n - 46) * 1.8, 1, 62)
end

-- note -> screen column: the arps' range (C3..C7) spans the width
local function px(n)
  n = num(n, 72)
  return clamp(4 + (n - 48) / 48 * 120, 2, 125)
end

local function opt(id, d)
  local ok, v = pcall(function() return params:get(id) end)
  if ok and type(v) == "number" and v == v then return v end
  return d
end

------------------------------------------------------------------------
-- batched drawing: one fill / stroke per brightness level
------------------------------------------------------------------------

local batch, bn = {}, {}
local lbatch, lbn = {}, {}
for l = 1, 15 do batch[l], bn[l], lbatch[l], lbn[l] = {}, 0, {}, 0 end

local function lvl(l)
  l = l * B
  if not (l >= 0.5) then return nil end                  -- also drops NaN
  l = math.floor(l + 0.5)
  if l > 15 then l = 15 end
  return l
end

local function okc(v) return v == v and v > -1e6 and v < 1e6 end

-- the glitch tear, applied as things are drawn: x shifted (or coarsened)
-- inside the torn band, the whole frame sunk through a tape stop
local function tear(x, y, w)
  if gl_t <= 0 then return x, y, w end
  y = y + gl_sag
  if y >= gl_y0 and y < gl_y1 then
    if gl_mode == 5 then
      local x1 = x + w
      x = (x // 3) * 3
      w = math.max(3, ((x1 + 2) // 3) * 3 - x)
    else
      x = x + gl_dx
    end
  end
  return x, y, w
end

-- stutter / chop: inside the band, the frame that started the slice is
-- kept (captured into `hold`) and everything newer is dropped
local function held(y)
  return gl_t > 0 and (gl_mode == 1 or gl_mode == 4) and y >= gl_y0 and y < gl_y1
end
local function keep(l, kind, a, b, c, d)
  if gl_cap and hn < 400 then
    hold[hn + 1], hold[hn + 2], hold[hn + 3], hold[hn + 4], hold[hn + 5], hold[hn + 6] = l, kind, a, b, c, d
    hn = hn + 6
  end
end

local function put(l, x, y, w, h)
  w, h = w or 1, h or 1
  if type(x) ~= "number" or type(y) ~= "number" or type(w) ~= "number" or type(h) ~= "number" then return end
  if not (okc(x) and okc(y)) then return end
  if not (w >= 1 and h >= 1 and w < 1e4 and h < 1e4) then return end
  if ops >= OPS_CAP then return end
  l = lvl(l)
  if not l then return end
  ops = ops + 1
  if held(y) then keep(l, 1, x, y, w, h); return end
  x, y, w = tear(x, y, w)
  local b, n = batch[l], bn[l]
  b[n + 1], b[n + 2], b[n + 3], b[n + 4] = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
  bn[l] = n + 4
end

-- a 1-px line, batched with others of its level into one stroke
local function line(l, x0, y0, x1, y1)
  if type(x0) ~= "number" or type(y0) ~= "number" or type(x1) ~= "number" or type(y1) ~= "number" then return end
  if not (okc(x0) and okc(y0) and okc(x1) and okc(y1)) then return end
  if ops >= OPS_CAP then return end
  l = lvl(l)
  if not l then return end
  ops = ops + 1
  if held(y0) then keep(l, 2, x0, y0, x1, y1); return end
  if gl_t > 0 then
    local dx = 0
    if gl_mode ~= 5 and y0 + gl_sag >= gl_y0 and y0 + gl_sag < gl_y1 then dx = gl_dx end
    x0, x1, y0, y1 = x0 + dx, x1 + dx, y0 + gl_sag, y1 + gl_sag
  end
  local b, n = lbatch[l], lbn[l]
  b[n + 1], b[n + 2], b[n + 3], b[n + 4] = x0 + 0.5, y0 + 0.5, x1 + 0.5, y1 + 0.5
  lbn[l] = n + 4
end

-- drop whatever a failed theme had queued
local function discard()
  for l = 1, 15 do bn[l], lbn[l] = 0, 0 end
end

local function flush()
  ops = 0
  -- the held band goes back in, as it was when its slice began
  if gl_t > 0 and (gl_mode == 1 or gl_mode == 4) then
    for i = 1, hn, 6 do
      local l, kind = hold[i], hold[i + 1]
      if kind == 1 then
        local b, n = batch[l], bn[l]
        b[n + 1], b[n + 2], b[n + 3], b[n + 4] = math.floor(hold[i + 2]), math.floor(hold[i + 3]),
          math.floor(hold[i + 4]), math.floor(hold[i + 5])
        bn[l] = n + 4
      else
        local b, n = lbatch[l], lbn[l]
        b[n + 1], b[n + 2], b[n + 3], b[n + 4] = hold[i + 2] + 0.5, hold[i + 3] + 0.5, hold[i + 4] + 0.5, hold[i + 5] + 0.5
        lbn[l] = n + 4
      end
    end
  end
  gl_cap = false
  if trail_raw > 50 then                   -- the trails clamp needs the lit ratio
    lit_stamp = lit_stamp + 1
    local cnt = 0
    for l = 1, 15 do
      local b = batch[l]
      for i = 1, bn[l], 4 do
        local x0, y0 = math.max(0, b[i]), math.max(0, b[i + 1])
        local x1, y1 = math.min(128, b[i] + b[i + 2]), math.min(64, b[i + 1] + b[i + 3])
        for y = y0, y1 - 1 do
          local row = y * 128
          for x = x0, x1 - 1 do
            if lit_seen[row + x] ~= lit_stamp then lit_seen[row + x] = lit_stamp; cnt = cnt + 1 end
          end
        end
      end
      b = lbatch[l]
      for i = 1, lbn[l], 4 do
        local ax, ay, bx, by = b[i], b[i + 1], b[i + 2], b[i + 3]
        local steps = math.min(200, math.ceil(math.max(math.abs(bx - ax), math.abs(by - ay))))
        for q = 0, steps do
          local u = steps > 0 and q / steps or 0
          local x, y = math.floor(ax + (bx - ax) * u), math.floor(ay + (by - ay) * u)
          if x >= 0 and x < 128 and y >= 0 and y < 64 and lit_seen[y * 128 + x] ~= lit_stamp then
            lit_seen[y * 128 + x] = lit_stamp; cnt = cnt + 1
          end
        end
      end
    end
    lit_i = lit_i % 10 + 1
    lit_hist[lit_i] = cnt / 8192
  end
  for l = 1, 15 do
    local n = bn[l]
    if n > 0 then
      local b = batch[l]
      screen.level(l)
      for i = 1, n, 4 do screen.rect(b[i], b[i + 1], b[i + 2], b[i + 3]) end
      screen.fill()
      bn[l] = 0
    end
  end
  screen.line_width(1)
  for l = 1, 15 do
    local n = lbn[l]
    if n > 0 then
      local b = lbatch[l]
      screen.level(l)
      for i = 1, n, 4 do
        screen.move(b[i], b[i + 1])
        screen.line(b[i + 2], b[i + 3])
      end
      screen.stroke()
      lbn[l] = 0
    end
  end
end

------------------------------------------------------------------------
-- scenery: profiles, silhouettes and dithered gradients from few wide rects
------------------------------------------------------------------------

-- a skyline profile: prof[c] is the top y of the mass at column 2c (c = 0..64)
local function profile(fn)
  local p = {}
  for c = 0, 64 do p[c] = fn(c * 2) end
  return p
end

-- a profile's height at any x
local function at(prof, x)
  local c = math.floor(num(x, 0) / 2)
  if c < 0 then c = 0 elseif c > 64 then c = 64 end
  return prof[c]
end

-- a solid silhouette from a profile down to y_bot, one 2-px column per rect
local function mass(l, prof, y_bot, x0, x1)
  for c = (x0 or 0) // 2, math.min(63, ((x1 or 128) - 1) // 2) do
    local top = math.floor(prof[c] + 0.5)
    if top < y_bot then put(l, c * 2, top, 2, y_bot - top) end
  end
end

-- one row lit where it is above the profile (prof may be nil: all of it),
-- merged into runs so a row costs one rect per gap
local function row_above(l, y, prof, x0, x1)
  x0, x1 = x0 or 0, x1 or 128
  if not prof then put(l, x0, y, x1 - x0, 1); return end
  local run
  for c = x0 // 2, (x1 - 1) // 2 do
    if y < prof[c] then
      run = run or c * 2
    elseif run then
      put(l, run, y, c * 2 - run, 1); run = nil
    end
  end
  if run then put(l, run, y, x1 - run, 1) end
end

-- ordered dither thresholds down the rows: any 8 rows hold each step once
local TH8 = {0, 4, 2, 6, 1, 5, 3, 7}

-- a vertical gradient of whole rows: lv(y) is the light at row y (0..~6,
-- fractional). each row draws at the floor level and the fraction decides
-- by ordered dither whether it steps up; under 1 the rows thin out instead
local function gradient(y0, y1, lv, prof, x0, x1)
  for y = y0, y1 do
    local v = lv(y)
    if v == v and v > 0.05 then
      local th = (TH8[y % 8 + 1] + 0.5) / 8
      local l
      if v < 1 then l = (v > th) and 1 or 0
      else
        l = math.floor(v)
        if v - l > th then l = l + 1 end
      end
      if l > 0 then row_above(l, y, prof, x0, x1) end
    end
  end
end

-- a dashed row: dashes of `w` px every `gap` px, slid by `off`
local function dashes(l, y, w, gap, off, x0, x1)
  x0, x1 = x0 or 0, x1 or 128
  off = num(off, 0)
  local s = x0 + (off % gap) - gap
  for x = s, x1 - 1, gap do
    local a, b = math.max(x0, x), math.min(x1, x + w)
    if b > a then put(l, a, y, b - a, 1) end
  end
end

-- haze: drifting banks of dithered fog over a box. density 0..1 (how much
-- of the box is lit), level l. made of short row runs where two slow waves
-- agree, so it rolls rather than scrolls; every other row at most
local function haze(x0, y0, x1, y1, density, l, drift)
  density = clamp(num(density, 0), 0, 1)
  if density < 0.02 then return end
  drift = num(drift, 0)
  local thr = 1.6 - 3.2 * density
  for y = y0, y1 - 1, 2 do
    local run
    local yo = (y // 2) % 2
    for x = x0 + yo * 2, x1 - 1, 4 do
      local w = math.sin((x + drift) * 0.045 + y * 0.21 + T * 0.13)
        + 0.8 * math.sin((x - drift * 0.6) * 0.083 - y * 0.11 - T * 0.21)
      if w > thr then
        run = run or x
      elseif run then
        dashes(l, y, 2, 4, run - x0 - yo * 2, run, x); run = nil
      end
    end
    if run then dashes(l, y, 2, 4, run - x0 - yo * 2, run, x1) end
  end
end

-- grain: a few short-lived points where `sample(u, v)` says, as many as
-- `rate` per second asks for; each rises and fades on a sine
local grains, grain_acc = {}, 0
local GRAIN_MAX = 18
local function grain(sample, rate, peak)
  grain_acc = grain_acc + num(rate, 0) * DTS
  while grain_acc >= 1 do
    grain_acc = grain_acc - 1
    if #grains < GRAIN_MAX then
      local x, y = sample(rnd(), rnd())
      if x then grains[#grains + 1] = {x = x, y = y, t0 = T, life = 0.15 + 0.25 * rnd(), pk = (peak or 6) * (0.6 + 0.4 * rnd())} end
    end
  end
  for i = #grains, 1, -1 do
    local g = grains[i]
    local u = (T - g.t0) / g.life
    if u >= 1 or u < 0 then table.remove(grains, i)
    else put(g.pk * math.sin(math.pi * u), g.x, g.y, 1, 1) end
  end
end

------------------------------------------------------------------------
-- the machine every theme shares
------------------------------------------------------------------------

local function S_tempo(S)
  local t = num(S.tempo, nil)
  if not t then
    local ok, v = pcall(function() return clock.get_tempo() end)
    t = ok and num(v, 120) or 120
  end
  return clamp(t, 20, 300)
end

-- the chord as four numbers, whatever arrives
local function take_chord(c)
  if type(c) ~= "table" then return end
  local got = {}
  for i = 1, 4 do
    local m = num(c[i], nil)
    if m then got[#got + 1] = m end
  end
  if #got == 0 then return end
  for i = 1, 4 do chord[i] = got[(i - 1) % #got + 1] end
end

-- trails: 2.5^((v-50)/50) is 1 at 50, 0.4 at 0 and 2.5 at 100, smooth through
-- the middle. past 1 it is held back while the last 10 frames run over the lit
-- bound (LIT_TRAIL_MAX): the scale eases down fast and back up slowly
local function trails_clamp()
  local want = 2.5 ^ ((trail_raw - 50) / 50)
  if want > 1 then
    local m = 0
    for i = 1, 10 do m = m + lit_hist[i] end
    m = m / 10
    if m > LIT_TRAIL_MAX then trail_scale = math.max(0, trail_scale - 0.08)
    elseif m < LIT_TRAIL_MAX - 0.04 then trail_scale = math.min(1, trail_scale + 0.01) end
    trail_eff = 1 + (want - 1) * trail_scale
  else
    trail_scale, trail_eff = 1, want
  end
end

local function physics(S)
  trails_clamp()
  -- the ears: polls when the engine has them, else made up from the music
  local live = heard >= 0 and (NOW - heard) < 1.5
  for k = 1, 4 do
    local to = raw[k]
    if live then
      if k == HI then to = math.max(to, env.hat * 0.35, env.tick * 0.3) end   -- hats tick the highs
    else
      local lv = clamp(num(VIS.audio_level, 0), 0, 1)
      if k == AMP then to = lv
      elseif k == LO then to = math.max(env.kick * 0.9, env.bass * 0.7, lv * 0.5)
      elseif k == MID then to = math.max(env.stab * 0.8, env.arp * 0.5, env.perc * 0.5, lv * 0.4)
      else to = math.max(env.hat * 0.7, env.clap * 0.6, env.tick * 0.5, lv * 0.25) end
    end
    A[k] = follow(A[k], to, to > A[k] and RISE[k] or FALL[k], DT)
  end
  local e = clamp(num(S.energy, 0), 0, 1)
  if not energy_seen then energy, energy_seen = e, true end
  local ne = follow(energy, e, 1.5, DT)
  trend = follow(trend, DT > 0 and clamp((ne - energy) / DT * 20, -1, 1) or 0, 3, DT)
  energy = ne
  dub = follow(dub, clamp(num(S.dub, 0.5), 0, 1), 1, DT)
  local throwing = S.throw == true or num(S.hand_throw, 0) > 0 or num(S.lead_throw, 0) > 0
  throw = follow(throw, throwing and 1 or 0, throwing and 0.15 or 1.2, DT)
  local kl = (S.kickless == true or S.on_kick == false) and S.playing ~= false
  kickless = follow(kickless, kl and 1 or 0, 1.5, DT)
  -- the beat: the 16th clock, smoothed between steps
  beat_sec = 60 / S_tempo(S)
  local step = num(S.step, 0)
  if step ~= step_seen then step_seen, step_t = step, NOW end
  local sub = clamp((NOW - step_t) / (beat_sec / 4), 0, 0.999)
  -- the bar: S.bar.n 16ths (5/4 = 20), the position S.bar_step (1..n, the step
  -- about to play, as S.step is). no bar in S: the 4/4 of 16
  local bn, bpos = 16, step % 16
  if type(S.bar) == "table" then
    local n, b = num(S.bar.n, 16), num(S.bar.beats, 4)
    if n >= 4 and n <= 64 and n % 1 == 0 then
      bn, bar_beats = n, clamp(math.floor(b), 1, 16)
      bpos = clamp(num(S.bar_step, 1) - 1, 0, n - 1)
    end
  else
    bar_beats = 4
  end
  local s16 = bpos + sub
  beat_ph = (s16 % 4) / 4
  bar_ph = s16 / bn
  -- the pump: a quick duck, a recovery over most of a beat
  duck_age = duck_age + DT
  local rec = beat_sec * 0.6
  local ATK = 0.06                       -- a breath in, not a hit: the kick is env.kick
  duck = duck_age < ATK and ease(duck_age / ATK) or math.exp(-(duck_age - ATK) / (rec * 0.45))
  for k, v in pairs(env) do env[k] = v * math.exp(-DT / ENV_TAU[k]) end
  for i = 1, 4 do
    voice_kick[i] = voice_kick[i] * math.exp(-DT / 0.25)
    lane_kick[i] = lane_kick[i] * math.exp(-DT / 0.15)
  end
  bar_pulse = follow(bar_pulse, bar_kick, 0.05, DT)
  bar_kick = bar_kick * math.exp(-DT / 0.5)
  -- tape stop dims as it winds down and eases back up after, never a snap
  local dim_to = (gl_t > 0 and gl_mode == 2) and (0.6 + 0.4 * gl_t / math.max(gl_dur, 0.01)) or 1
  gl_dim = follow(gl_dim, dim_to, 0.15, DT)
  if gl_t > 0 then
    gl_t = math.max(0, gl_t - DT)
    local u = 1 - gl_t / math.max(gl_dur, 0.01)
    -- a stutter / chop band jumps out and back each slice; a reverse slides
    -- home; a tape stop drifts out as it winds down. one px a frame at most
    -- outside the stutter, so nothing flashes
    local to
    if gl_mode == 1 or gl_mode == 4 then
      local sl = math.floor(u * gl_dur / math.max(0.05, beat_sec / 4))
      if sl ~= gl_slice then gl_slice, gl_cap, hn = sl, true, 0 end
      gl_dx = 0
    else
      if gl_mode == 3 then to = math.floor(gl_dx_abs * math.sin(u * math.pi) + 0.5)
      elseif gl_mode == 2 then to = math.floor(gl_dx_abs * u + 0.5)
      else to = 0 end
      if to > gl_dx then gl_dx = gl_dx + 1 elseif to < gl_dx then gl_dx = gl_dx - 1 end
    end
    gl_sag = 0
    if gl_t == 0 then gl_dx = 0 end
  end
end

local function echo_params(S)
  local t = num(S.echo_time, nil)
  if not t then t = ({0.5, 0.75, 1, 1.5})[clamp(math.floor(opt("echo_div", 2)), 1, 4)] * beat_sec end
  local fb = num(S.echo_fb, nil) or (0.32 + dub * 0.45 + throw * 0.28)
  return clamp(t, 0.05, 3), clamp(fb, 0, 0.93)
end

-- the read-only view of the machine the themes see this frame
local function sync(S)
  K.T, K.NOW, K.DT, K.DTS, K.SP, K.B = T, NOW, DT, DTS, SP, B
  K.energy, K.trend, K.dub, K.throw, K.kickless = energy, trend, dub, throw, kickless
  K.duck, K.beat_ph, K.bar_ph, K.beat_sec, K.bar_pulse = duck, beat_ph, bar_ph, beat_sec, bar_pulse
  K.bass_note = bass_note
  K.beats = bar_beats
  K.echo_t, K.echo_fb = echo_params(S)
  K.glitch = gl_t > 0 and gl_t / math.max(gl_dur, 0.01) or 0
  K.glitch_mode = gl_t > 0 and gl_mode or 0
  K.playing = S.playing ~= false
  K.trail, K.detail = trail_eff, detail
  K.react = react_raw <= 50 and (0.4 + 0.6 * react_raw / 50) or (1 + 0.8 * (react_raw - 50) / 50)
  K.S = S
end

K.clamp, K.num, K.ease, K.follow, K.rnd, K.hash, K.py, K.px, K.opt =
  clamp, num, ease, follow, rnd, hash, py, px, opt
K.put, K.line, K.profile, K.at, K.mass, K.row_above, K.gradient, K.dashes, K.haze, K.grain =
  put, line, profile, at, mass, row_above, gradient, dashes, haze, grain

-- sub-pixel placement: the level is split between the pixel at floor(x) and the
-- next one by the fractional part, and the same in y. whole numbers draw as put
K.put_sub = function(l, x, y, w, h)
  x, y = num(x, nil), num(y, nil)
  if not (x and y and okc(x) and okc(y)) then return end
  l = num(l, 0)
  local ix, iy = math.floor(x), math.floor(y)
  local fx, fy = x - ix, y - iy
  if fx == 0 and fy == 0 then return put(l, ix, iy, w, h) end
  for oy = 0, 1 do
    local wy = oy == 0 and 1 - fy or fy
    for ox = 0, 1 do
      local wx = ox == 0 and 1 - fx or fx
      if wx * wy > 0 then put(l * wx * wy, ix + ox, iy + oy, w, h) end
    end
  end
end

-- the same for a line: its start's fractional part moves the whole line, which
-- is drawn at the two (four) neighbouring whole-pixel positions
K.line_sub = function(l, x0, y0, x1, y1)
  x0, y0, x1, y1 = num(x0, nil), num(y0, nil), num(x1, nil), num(y1, nil)
  if not (x0 and y0 and x1 and y1 and okc(x0) and okc(y0) and okc(x1) and okc(y1)) then return end
  l = num(l, 0)
  local fx, fy = x0 - math.floor(x0), y0 - math.floor(y0)
  if fx == 0 and fy == 0 then return line(l, x0, y0, x1, y1) end
  for oy = 0, 1 do
    local wy = oy == 0 and 1 - fy or fy
    for ox = 0, 1 do
      local wx = ox == 0 and 1 - fx or fx
      if wx * wy > 0 then
        line(l * wx * wy, x0 - fx + ox, y0 - fy + oy, x1 - fx + ox, y1 - fy + oy)
      end
    end
  end
end

-- a part's gain on the mixer (0 when muted or missing)
K.gain = function(S, part)
  local g = type(S.gain) == "table" and num(S.gain[part], 0) or 0
  return clamp(g, 0, 1)
end

-- an arp lane's state, or nil: {len, pos, div, tick}
K.lane = function(S, i)
  local l = type(S.lanes) == "table" and S.lanes[i]
  if type(l) == "table" and num(l.len, 0) > 0 then return l end
end

sync({})

-- the themes, each in its own file (include, not require: norns resolves it
-- against the script's folder)
-- the fallback scene: a horizon breathing with the pump, haze under it and
-- the chord as four faint lights. drawn when a theme is broken
local FALLBACK = {draw = function()
  local e, d = energy, duck
  local hy = math.floor(40 - e * 6)
  for r = 0, 5 do put(1 + (5 - r) * 0.4, 0, hy + 2 + r * 4, 128, 2) end
  line(5 + e * 5 - d * 3, 0, hy, 127, hy)
  for i = 1, 4 do
    local x = 16 + (i - 1) * 32 + math.sin(T * 0.3 + i) * 4
    put(3 + voice_kick[i] * 9, x, py(chord[i]) * 0.5 + 4, 2, 2)
  end
  put(4 + env.kick * 8, 62, hy - 1, 4, 1)
end}

local function log_once(i, what, err)
  if logged[i] then return end
  logged[i] = true
  print("gradient visuals: theme " .. tostring(VIS.names[i] or i) .. " " .. what .. ": " .. tostring(err))
end

for i, name in ipairs(VIS.names) do
  local ok, th = pcall(function() return include("lib/vis/" .. name)(K) end)
  if ok and type(th) == "table" and type(th.draw) == "function" then
    THEMES[i] = th
  else
    THEMES[i] = FALLBACK
    log_once(i, "did not load", ok and "no draw function" or th)
  end
end

-- call a theme's handler, guarded; a failure retires the theme to the fallback
local function call(i, fname, ...)
  local th = THEMES[i]
  local f = th and not broken[i] and th[fname]
  if type(f) ~= "function" then return false end
  local ok, err = pcall(f, ...)
  if not ok then
    broken[i] = true
    log_once(i, "failed in " .. fname, err)
  end
  return ok
end

------------------------------------------------------------------------
-- dispatch
------------------------------------------------------------------------

VIS.strict = false
VIS.kit = K

-- the visuals params: trails and reactivity 0..100 (50 is today's behaviour),
-- detail "classic" / "fine" / "dense"
function VIS.set_trails(v) trail_raw = clamp(num(v, 50), 0, 100) end
function VIS.set_react(v) react_raw = clamp(num(v, 50), 0, 100) end
function VIS.set_detail(name)
  if name == "classic" or name == "fine" or name == "dense" then detail = name else detail = "fine" end
end

function VIS.init()
  VIS.strict = false
  for i = #grains, 1, -1 do grains[i] = nil end
  for i = #hist, 1, -1 do hist[i] = nil end
  for k in pairs(lane_note) do lane_note[k] = nil end
  for k in pairs(lane_step) do lane_step[k] = nil end
  grain_acc = 0
  for k in pairs(env) do env[k] = 0 end
  for i = 1, 4 do voice_kick[i], lane_kick[i] = 0, 0 end
  bass_note = nil
  chord[1], chord[2], chord[3], chord[4] = 48, 55, 62, 65
  for k = 1, 4 do raw[k], A[k] = 0, 0 end
  heard = -1
  energy, trend, dub, throw, kickless, energy_seen = 0, 0, 0.5, 0, 0, false
  duck, duck_age, beat_ph, bar_ph, beat_sec = 0, 99, 0, 0, 0.5
  bar_beats = 4
  step_seen, step_t, bar_kick, bar_pulse = -1, 0, 0, 0
  T, NOW, last_clock = 0, 0, nil
  cur, xf = nil, 0
  rseed = 1
  gl_t, gl_dur, gl_mode, gl_dx, gl_dx_abs, gl_sag = 0, 0, 0, 0, 0, 0
  gl_slice, gl_cap, hn = -1, false, 0
  gl_dim = 1
  ops = 0
  trail_eff, trail_scale, lit_i = 1, 1, 0
  for i = 1, 10 do lit_hist[i] = 0 end
  discard()
  for i = 1, #THEMES do
    broken[i] = nil
    local th = THEMES[i]
    if th.init then call(i, "init") elseif th.clear then call(i, "clear") end
  end
end

-- a poll value from the engine (out_amp, out_lo, out_mid, out_hi). anything
-- that is not a number in 0..1 is clamped, NaN reads as 0
function VIS.audio(name, v)
  local i = A_IDX[name]
  if not i then return end
  if type(v) ~= "number" or v ~= v then v = 0 end
  raw[i] = clamp(v, 0, 1)
  heard = NOW
end

-- kind: "kick", "pump", "hat", "stab" (notes), "bass" (note),
-- "arp" (lane, note, step), "pad" (notes), "bar" (S)
function VIS.event(kind, a, b, c)
  if type(kind) ~= "string" then return end
  if env[kind] then env[kind] = 1 end
  local i = cur
  if kind == "stab" then
    take_chord(a)
    for v = 1, 4 do voice_kick[v] = 1 end
    if i then call(i, "stab", chord) end
  elseif kind == "bass" then
    bass_note = num(a, bass_note)
    if i then call(i, "bass", bass_note or 36) end
  elseif kind == "arp" then
    local lane = clamp(math.floor(num(a, 1)), 1, 4)
    lane_kick[lane] = 1
    lane_note[lane] = num(b, lane_note[lane] or 72)
    lane_step[lane] = num(c, lane_step[lane] or 1)
    if i then call(i, "arp", lane, lane_note[lane], lane_step[lane]) end
  elseif kind == "pad" then
    -- up to four finite numbers, copied; anything else is an empty list
    local notes = {}
    if type(a) == "table" then
      for k = 1, 4 do
        local m = num(a[k], nil)
        if m then notes[#notes + 1] = m end
      end
    end
    if i then call(i, "pad", notes) end
  elseif kind == "pump" then
    duck_age = 0
    if i then call(i, "pump") end
  elseif kind == "kick" or kind == "hat" then
    if i then call(i, kind) end
  elseif kind == "clap" or kind == "perc" or kind == "tick" then
    -- the new drums: their own handler if the theme has one, else a hat
    if i then
      local th = THEMES[i]
      if th[kind] then
        if kind == "perc" then call(i, "perc", clamp(math.floor(num(a, 1)), 1, 3), num(b, 60))
        elseif kind == "tick" then call(i, "tick", clamp(math.floor(num(a, 1)), 1, 4))
        else call(i, "clap") end
      elseif VIS.strict then
        -- no fallback
      elseif kind ~= "tick" or rnd() < 0.5 then
        call(i, "hat")
      end
    end
  elseif kind == "glitch" then
    local mode = clamp(math.floor(num(a, 1)), 1, 5)
    local dur = clamp(num(b, 0.25), 0.02, 1.5)
    gl_mode, gl_dur, gl_t = mode, dur, dur
    local h = 4 + math.floor(rnd() * 6)
    gl_y0 = math.floor(rnd() * (64 - h))
    gl_y1 = gl_y0 + h
    gl_dx_abs = (2 + math.floor(rnd() * 3)) * (rnd() < 0.5 and -1 or 1)
    gl_dx = 0
    gl_slice, gl_cap, hn = -1, false, 0
    gl_sag = 0
  elseif kind == "bar" then
    local S = type(a) == "table" and a or {}
    bar_kick = 1
    local label = S.chord_label
    hist[#hist + 1] = {e = clamp(num(S.energy, 0), 0, 1), kl = S.kickless == true,
      ch = label, pedal = type(label) == "string" and label:find("/") ~= nil}
    if #hist > HIST_N then table.remove(hist, 1) end
    take_chord(S.chord)
    if i then call(i, "bar", S) end
  end
end

-- this frame's real step: given (tests), or from the clock; a stall or a
-- repeat draw never jumps the picture
local function frame_dt(dt)
  if dt == nil then
    local now = util and util.time and util.time()
    if type(now) == "number" and last_clock then dt = now - last_clock else dt = 1 / FPS end
    last_clock = now
  end
  if type(dt) ~= "number" or dt ~= dt then dt = 1 / FPS end
  return clamp(dt, 0, 0.25)
end

-- draw theme i. dt (s) is optional: on the norns it comes from the clock
function VIS.draw(i, S, dt)
  i = math.floor(num(i, 1))
  if not THEMES[i] then i = clamp(i, 1, #THEMES) end
  if type(S) ~= "table" then S = {} end
  DT = frame_dt(dt)
  SP = clamp(opt("vis_speed", 3) / 3, 0.1, 5)
  DTS = DT * SP
  NOW = NOW + DT
  T = T + DTS
  local ok, err = pcall(physics, S)
  if not ok then log_once(0, "kit physics", err) end
  -- a theme switch: the old picture eases to black, the new one eases up
  if cur == nil then cur = i end
  if i ~= cur then
    xf = xf - DT / 0.25
    if xf <= 0 then
      local old = THEMES[cur]
      if old.clear then call(cur, "clear") elseif old.init then call(cur, "init") end
      for k = #grains, 1, -1 do grains[k] = nil end
      xf, cur = 0, i
      -- a fresh visit gives a broken theme another go
      broken[cur] = nil
      -- the trails clamp starts over: the old theme's lit history is not the new one's
      for k = 1, 10 do lit_hist[k] = 0 end
      lit_i, trail_scale = 0, 1
      trails_clamp()
    end
  else
    xf = math.min(1, xf + DT / 0.5)
  end
  B = opt("vis_brightness", 10) / 10 * ease(xf)
  -- a tape stop dims the picture as it winds down
  B = B * gl_dim
  sync(S)
  ops = 0
  if broken[cur] or not call(cur, "draw", S) then
    discard()
    ops = 0
    FALLBACK.draw()
  end
  flush()
end

return VIS
