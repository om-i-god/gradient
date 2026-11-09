-- visuals: every theme x {silence, mid, peak, kickless} drawn headless into
-- the raster stand-in (test/raster.lua) at 20 fps of virtual time. each run
-- checks the lit-pixel ratio, that silence is never blank, the frame-to-
-- frame change, NaN / inf reaching the screen, level-15 area and the
-- draw-call budget. then: ramping out_hi / out_lo changes every theme, the
-- pulse shows, a theme switch eases, bad input draws cleanly, out-of-range
-- audio draws exactly as the clamped value would, a jittery frame rate tells
-- the same story as a steady one, and brightness / speed scale.
--
--   lua test/unit.lua test/unit_visuals.lua
--   VISONLY=tape,stack   only those themes
--   VISREPORT=1          print the numbers per theme x scenario
local RAST = dofile("test/raster.lua")
local REPORT = os.getenv("VISREPORT")
local ONLY = os.getenv("VISONLY")
local FPS = 20
local PV = {}

local function env()
  screen = RAST.screen
  PV = {vis_brightness = 10, vis_speed = 3, echo_div = 2}
  params = {get = function(_, id) return PV[id] end}
  clock = {get_tempo = function() return 124 end, get_beat_sec = function() return 60 / 124 end}
  util = nil
end

local function mklanes()
  local L = {}
  for i, len in ipairs({5, 7, 11, 13}) do L[i] = {len = len, pos = 1, div = 1 + (i == 4 and 1 or 0), tick = 0} end
  return L
end

local function mkS()
  return {
    playing = true, step = 0, tempo = 124, energy = 0, section = "drift",
    chord = {50, 57, 60, 65}, chord_label = "i", track_bar = 1, phrase_len = 32,
    gain = {kick = 0, bass = 0, chords = 0, lane1 = 0, lane2 = 0, lane3 = 0, lane4 = 0, hats = 0, rim = 0},
    kickless = false, on_kick = true, on_pump = true, dub = 0.5, hand_throw = 0, lead_throw = 0,
    lanes = mklanes(), bass_pc = 2, mode_play = 1,
  }
end

-- the eight v1 themes first, in their old order (saved psets keep pointing
-- at the same theme), then the eight new ones
local NAMES = {"gradient", "voices", "lanes", "phase", "echo", "fall", "pump", "arc",
  "motorway", "tape", "stack", "blocks", "beams", "window", "pylons", "dubplate",
  "radar", "subway"}

local CHORDS = {{50, 57, 60, 65}, {46, 53, 58, 62}, {48, 55, 58, 63}, {45, 52, 57, 60}}
local LABELS = {"i", "VI", "VII", "v/i"}

-- one 16th of the groove: kick + pump on beats, hats offbeat, stabs on the
-- dub offbeats, bass on most 8ths, arp lanes ticking at their lengths
local function groove(S, VIS, k, o)
  local s = k % 16 + 1
  if s == 1 then
    S.track_bar = S.track_bar + 1
    S.energy = o.energy or S.energy
    if S.track_bar % 2 == 0 then
      local ci = (S.track_bar // 2) % 4 + 1
      S.chord, S.chord_label = CHORDS[ci], LABELS[ci]
    end
    VIS.event("bar", S)
  end
  if (s - 1) % 4 == 0 then
    if S.on_pump then VIS.event("pump") end
    if S.on_kick and not S.kickless then VIS.event("kick") end
  end
  if o.hats and (s - 1) % 4 == 2 then VIS.event("hat") end
  if o.stabs and (s == 4 or s == 11 or (o.dense and s == 7)) then VIS.event("stab", S.chord) end
  -- the newer drums: claps on the backbeat, a perc lane, glitch ticks, and
  -- now and then a glitch on the whole mix (each mode in turn)
  if o.drums then
    if s == 5 or s == 13 then VIS.event("clap") end
    if s % 3 == 1 then VIS.event("perc", s % 3 + 1, 57 + s) end
    if s % 5 == 2 then VIS.event("tick", s % 4 + 1) end
    if k % 48 == 12 then VIS.event("glitch", (k // 48) % 5 + 1, 0.25 + (k // 48) % 3 * 0.2) end
  end
  if o.bass and (s % 2 == 1) and math.random() < 0.8 then VIS.event("bass", 36 + S.bass_pc + (s == 9 and 7 or 0)) end
  for i = 1, o.lanes or 0 do
    local l = S.lanes[i]
    l.tick = l.tick + 1
    if (l.tick - 1) % l.div == 0 then
      l.pos = l.pos % l.len + 1
      if math.random() < 0.7 then VIS.event("arp", i, 60 + ({0, 3, 7, 10, 12, 15, 19})[(l.pos + i) % 7 + 1] + (i - 1) * 5, l.pos) end
    end
  end
end

-- what each scenario does: setup(S), on_step(S, VIS, k), audio(t) -> table
local SCEN = {}
SCEN.silence = {
  setup = function(S) S.playing = false end,
  on_step = function() end,
  audio = nil,                                  -- no poll ever arrives
}
SCEN.mid = {
  setup = function(S)
    S.energy = 0.5; S.section = "rise"
    S.gain.kick, S.gain.bass, S.gain.chords, S.gain.lane1, S.gain.lane2, S.gain.hats = 0.8, 0.8, 0.7, 0.6, 0.5, 0.5
  end,
  on_step = function(S, VIS, k) groove(S, VIS, k, {stabs = true, bass = true, hats = true, lanes = 2}) end,
  audio = function(t)
    local b = (t * 124 / 60) % 1
    local p = math.exp(-b * 6)
    return {out_amp = 0.45 + 0.2 * p, out_lo = 0.35 + 0.45 * p, out_mid = 0.4, out_hi = 0.3 + 0.2 * ((b * 2) % 1 < 0.2 and 1 or 0)}
  end,
}
SCEN.peak = {
  setup = function(S)
    S.energy = 1; S.section = "peak"; S.dub = 0.9; S.hand_throw = 2
    for _, p in ipairs({"kick", "bass", "chords", "lane1", "lane2", "lane3", "lane4", "hats", "rim"}) do S.gain[p] = 1 end
  end,
  on_step = function(S, VIS, k)
    groove(S, VIS, k, {stabs = true, dense = true, bass = true, hats = true, lanes = 4, energy = 1, drums = true})
    if k % 64 == 0 then S.hand_throw = 2 end
  end,
  audio = function() return {out_amp = 1, out_lo = 1, out_mid = 1, out_hi = 1} end,
}
-- a kickless stretch: the pump goes on, stabs and lanes, no kick, dub up
SCEN.kickless = {
  setup = function(S)
    S.energy = 0.3; S.section = "drift"; S.kickless = true; S.on_kick = false; S.dub = 0.8
    S.gain.chords, S.gain.lane1, S.gain.lane3, S.gain.bass = 0.7, 0.5, 0.5, 0.5
  end,
  on_step = function(S, VIS, k) groove(S, VIS, k, {stabs = true, bass = true, lanes = 3, drums = true}) end,
  audio = function(t)
    local b = (t * 124 / 60) % 1
    return {out_amp = 0.3, out_lo = 0.2 + 0.1 * math.exp(-b * 4), out_mid = 0.35, out_hi = 0.15}
  end,
}

local function lit_stats()
  local lit, l15, sum = 0, 0, 0
  local buf = RAST.buf
  for i = 0, 128 * 64 - 1 do
    local v = buf[i] or 0
    if v > 0 then lit = lit + 1; sum = sum + v end
    if v >= 15 then l15 = l15 + 1 end
  end
  return lit / 8192, l15, sum
end

local function copybuf()
  local c = {}
  for i = 0, 128 * 64 - 1 do c[i] = RAST.buf[i] or 0 end
  return c
end

local function bufdiff(a, b)
  local d = 0
  for i = 0, 128 * 64 - 1 do d = d + math.abs(a[i] - b[i]) end
  return d / 8192
end

-- run one theme through one scenario; opts: frames, seed, audio override
-- (function t -> table), switch_every, tempo_jitter, dt(f), at(f, VIS, S), keep
local function run(theme, scen, opts)
  opts = opts or {}
  env()
  local VIS = include("lib/visuals")
  VIS.init()
  math.randomseed(opts.seed or 11)
  local SC = SCEN[scen]
  local S = mkS()
  SC.setup(S, VIS)
  local audio = opts.audio or SC.audio
  local st = {ops_max = 0, ops_sum = 0, lit_min = 1, lit_max = 0, lit_sum = 0,
    diff_max = 0, diff_sum = 0, l15_max = 0, bad = 0, n = 0, frames = {}}
  local prev
  local next_step, k = 0, 0
  local th = theme
  local t = 0
  for f = 1, opts.frames or 300 do
    local dt = opts.dt and opts.dt(f) or 1 / FPS
    t = t + dt
    while t >= next_step do
      if S.playing then
        SC.on_step(S, VIS, k)
        S.step = S.step + 1
      end
      k = k + 1
      next_step = next_step + 60 / S.tempo / 4
    end
    if opts.tempo_jitter then S.tempo = (f % 2 == 0) and 40 or 200 end
    if audio then
      for name, v in pairs(audio(t)) do VIS.audio(name, v) end
    end
    if opts.switch_every and f % opts.switch_every == 0 then th = th % #NAMES + 1 end
    if opts.at then opts.at(f, VIS, S) end
    screen.clear()
    RAST.reset_ops()
    VIS.draw(th, S, dt)
    local lit, l15, sum = lit_stats()
    local cur = copybuf()
    st.bad = st.bad + RAST.bad
    if t > 1 then                               -- past the first second
      st.ops_max = math.max(st.ops_max, RAST.ops)
      st.ops_sum = st.ops_sum + RAST.ops
      st.lit_min = math.min(st.lit_min, lit)
      st.lit_max = math.max(st.lit_max, lit)
      st.lit_sum = st.lit_sum + lit
      st.l15_max = math.max(st.l15_max, l15)
      st.n = st.n + 1
      if prev then
        local d = bufdiff(prev, cur)
        st.diff_max = math.max(st.diff_max, d)
        st.diff_sum = st.diff_sum + d
      end
    end
    if opts.keep then st.frames[#st.frames + 1] = cur end
    if opts.snap and f == opts.frames then RAST.snap(opts.snap) end
    prev = cur
  end
  st.t = t
  st.ops_mean = st.ops_sum / math.max(1, st.n)
  st.lit_mean = st.lit_sum / math.max(1, st.n)
  st.diff_mean = st.diff_sum / math.max(1, st.n - 1)
  return st, VIS
end

-- for ad-hoc scripts (contact sheets, per-frame diffs)
VIS_HARNESS = {run = run, bufdiff = bufdiff, NAMES = NAMES, RAST = RAST}
if not test then return end

local SCENS = {"silence", "mid", "peak", "kickless"}

-- bounds
local OPS_BUDGET = 1200       -- draw calls per frame, any theme, any scenario
local LIT_MAX = 0.40          -- never more than ~40% of the screen lit
local LIT_MIN_SILENT = 0.01   -- silence is never blank (~80 pixels)
local LIT_MIN_LIVE = 0.04     -- with music, a scene, not a near-empty screen
local DIFF_MAX = 0.7          -- mean |level change| per pixel, frame to frame (a
                              -- strobe of the lit 40% at level 5 would be 2.0)
local L15_MAX = 12            -- level-15 pixels: points at most, never an area

local function wanted(name)
  if not ONLY then return true end
  for n in ONLY:gmatch("[^,]+") do if n == name then return true end end
  return false
end

if REPORT then
  print(string.format("%-9s %-8s %7s %7s %7s %7s %7s %7s %5s %4s",
    "theme", "scen", "opsMax", "opsMean", "litMin", "litMean", "litMax", "diffMax", "l15", "bad"))
end

for th, name in ipairs(NAMES) do
  if wanted(name) then
    for _, sc in ipairs(SCENS) do
      test(string.format("visuals %s %s", name, sc), function()
        local st = run(th, sc)
        if REPORT then
          print(string.format("%-9s %-8s %7d %7.1f %7.3f %7.3f %7.3f %7.3f %5d %4d",
            name, sc, st.ops_max, st.ops_mean, st.lit_min, st.lit_mean, st.lit_max, st.diff_max, st.l15_max, st.bad))
        end
        assert(st.bad == 0, st.bad .. " NaN / inf coordinates or levels")
        assert(st.ops_max <= OPS_BUDGET, "draw calls " .. st.ops_max .. " > " .. OPS_BUDGET)
        assert(st.lit_max <= LIT_MAX, string.format("lit %.3f > %.2f", st.lit_max, LIT_MAX))
        assert(st.lit_min > (sc == "silence" and LIT_MIN_SILENT or LIT_MIN_LIVE),
          string.format("near blank: lit %.4f", st.lit_min))
        assert(st.diff_max <= DIFF_MAX, string.format("frame jump %.3f > %.2f", st.diff_max, DIFF_MAX))
        assert(st.l15_max <= L15_MAX, st.l15_max .. " pixels at level 15")
      end)
    end

    -- silence still moves: most frames differ from the one before
    test("visuals " .. name .. " moves at silence", function()
      local st = run(th, "silence", {frames = 120, keep = true})
      local moved = 0
      for i = 22, 120 do if bufdiff(st.frames[i - 1], st.frames[i]) > 0 then moved = moved + 1 end end
      if REPORT then print(string.format("still %-9s moved %d/99 meanDiff %.4f", name, moved, st.diff_mean)) end
      assert(moved >= 80, "frozen at silence: " .. moved .. " of 99 frames moved")
    end)

    -- the pulse shows: with the groove running, the picture changes more on
    -- the beat (first 16th) than off it
    test("visuals " .. name .. " shows the pulse", function()
      local st = run(th, "mid", {frames = 240, keep = true})
      local on, off, non, noff = 0, 0, 0, 0
      local spb = 60 / 124
      for i = 41, 240 do
        local tt = i / FPS
        local b = (tt / spb) % 1
        local d = bufdiff(st.frames[i - 1], st.frames[i])
        if b < 0.2 then on, non = on + d, non + 1 elseif b > 0.45 and b < 0.95 then off, noff = off + d, noff + 1 end
      end
      on, off = on / math.max(1, non), off / math.max(1, noff)
      if REPORT then print(string.format("pulse %-9s on %.4f off %.4f", name, on, off)) end
      assert(on > off * 1.15, string.format("no visible pulse: on-beat %.4f vs off-beat %.4f", on, off))
    end)

    -- audio reactivity: identical runs are identical, and ramping out_hi or
    -- out_lo (everything else held) changes the picture
    test("visuals " .. name .. " reacts to every band", function()
      local function with(over)
        return function(t)
          local v = SCEN.mid.audio(t)
          for kk, x in pairs(over) do v[kk] = x end
          return v
        end
      end
      local function paired(a, b)
        local Ar = run(th, "mid", {frames = 160, audio = a, keep = true})
        local Br = run(th, "mid", {frames = 160, audio = b, keep = true})
        local d = 0
        for i = 21, 160 do d = d + bufdiff(Ar.frames[i], Br.frames[i]) end
        return d / 140
      end
      local same = paired(with({}), with({}))
      assert(same == 0, "two identical runs differ: " .. same)
      local dhi = paired(with({out_hi = 0}), with({out_hi = 1}))
      local dlo = paired(with({out_lo = 0}), with({out_lo = 1}))
      local dmid = paired(with({out_mid = 0}), with({out_mid = 1}))
      local damp = paired(with({out_amp = 0}), with({out_amp = 1}))
      if REPORT then print(string.format("react %-9s hi %.3f lo %.3f mid %.3f amp %.3f", name, dhi, dlo, dmid, damp)) end
      assert(dhi > 0.01, string.format("out_hi barely changes it: %.4f", dhi))
      assert(dlo > 0.02, string.format("out_lo barely changes it: %.4f", dlo))
      assert(dmid > 0.01, string.format("out_mid barely changes it: %.4f", dmid))
      assert(damp > 0.01, string.format("out_amp barely changes it: %.4f", damp))
    end)

    -- every part of the music moves every theme: fire one event at frame 60
    -- (strict: no hat fallback) and compare frames 60..72 against a control
    -- that never fires it. both reseed right after, so the groove's random
    -- stream matches whatever a handler did. the control runs once.
    test("visuals " .. name .. " reacts to every part", function()
      local EVENTS = {
        {"kick"}, {"pump"}, {"hat"}, {"clap"}, {"perc", 2, 62}, {"tick", 3},
        {"stab", {50, 57, 60, 65}}, {"bass", 38}, {"arp", 2, 67, 3}, {"pad", {50, 57, 60, 65}}}
      local function probe(ev)
        return function(f, VIS)
          if f == 1 then VIS.strict = true end
          if f == 60 then
            if ev then VIS.event(ev[1], ev[2], ev[3], ev[4]) end
            math.randomseed(60)
          end
        end
      end
      local ctl = run(th, "mid", {frames = 90, keep = true, at = probe(nil)})
      local dead = {}
      for _, ev in ipairs(EVENTS) do
        local A = run(th, "mid", {frames = 90, keep = true, at = probe(ev)})
        local d = 0
        for i = 60, 72 do d = d + bufdiff(A.frames[i], ctl.frames[i]) end
        d = d / 13
        if REPORT then print(string.format("part %-9s %-5s %.4f", name, ev[1], d)) end
        if not (d > 0.003) then dead[#dead + 1] = string.format("%s (%.4f)", ev[1], d) end
      end
      assert(#dead == 0, name .. " does not react to: " .. table.concat(dead, ", "))
    end)

    -- bad input: garbage audio, short / empty chords, no lanes, tempo flapping
    test("visuals " .. name .. " bad input", function()
      local junk = {nil, 0 / 0, -1, 5, math.huge, -math.huge, 0.5}
      local st, VIS = run(th, "peak", {frames = 60, tempo_jitter = true, audio = function(t)
        local v = junk[math.floor(t * FPS) % 7 + 1]
        return {out_amp = v, out_lo = v, out_mid = v, out_hi = v}
      end})
      assert(st.bad == 0, st.bad .. " bad draw values")
      VIS.audio("out_amp", nil); VIS.audio("nope", 1); VIS.audio("out_hi", "x")
      for _, ch in ipairs({{}, {60}, {48, 55}, {48, 55, 62}, {0 / 0, 50}}) do
        local S = mkS()
        S.chord = ch; S.lanes = nil
        for f = 1, 10 do
          VIS.event("stab", ch); VIS.event("bass", 0 / 0); VIS.event("arp", 9, nil, nil)
          VIS.event("arp", (f % 4) + 1, 200, -3); VIS.event("bar", S)
          RAST.reset_ops(); screen.clear()
          VIS.draw(th, S, 1 / FPS)
          assert(RAST.bad == 0, "bad draw with chord of " .. #ch)
        end
        S.gain = nil; S.tempo = nil; S.step = nil; S.energy = 0 / 0; S.dub = "x"
        VIS.draw(th, S, 1 / FPS)
        VIS.draw(th, S, 0)
        VIS.draw(th, S, 5)
        assert(RAST.bad == 0, "bad draw with junk state")
      end
    end)

    -- out-of-range audio draws exactly what the clamped value draws
    test("visuals " .. name .. " out-of-range audio == clamped", function()
      local over = run(th, "mid", {frames = 60, keep = true, audio = function(t)
        local w = math.sin(t * 3)
        return {out_amp = 5, out_lo = -3, out_mid = w * 4, out_hi = 1.5}
      end})
      local clamped = run(th, "mid", {frames = 60, keep = true, audio = function(t)
        local w = math.sin(t * 3)
        return {out_amp = 1, out_lo = 0, out_mid = math.max(0, math.min(1, w * 4)), out_hi = 1}
      end})
      for i = 1, 60 do
        assert(bufdiff(over.frames[i], clamped.frames[i]) == 0, "frame " .. i .. " differs")
      end
    end)

    -- frame-rate independence (coarse)
    test("visuals " .. name .. " variable dt", function()
      local steady = run(th, "mid", {frames = 200})
      local jit = run(th, "mid", {frames = 200, dt = function(f)
        return ({0.025, 0.06, 0.04, 0.03, 0.055, 0.045})[f % 6 + 1]
      end})
      assert(jit.bad == 0, "bad draw values with a jittery dt")
      local r = jit.lit_mean / steady.lit_mean
      assert(r > 0.7 and r < 1.4, string.format("lit %.3f at jittery dt vs %.3f steady", jit.lit_mean, steady.lit_mean))
      assert(jit.diff_max <= DIFF_MAX * 1.3, string.format("jump %.3f at jittery dt", jit.diff_max))
    end)

    -- brightness and speed params scale everything
    test("visuals " .. name .. " brightness and speed", function()
      local function total(b)
        env(); PV.vis_brightness = b
        local VIS = include("lib/visuals"); VIS.init()
        local S = mkS(); SCEN.mid.setup(S)
        local s = 0
        for f = 1, 40 do
          for n, v in pairs(SCEN.mid.audio(f / FPS)) do VIS.audio(n, v) end
          screen.clear(); VIS.draw(th, S, 1 / FPS)
          local _, _, sum = lit_stats(); s = s + sum
        end
        return s
      end
      local a, b = total(3), total(15)
      assert(b > a * 1.5, string.format("brightness 15 vs 3 = %d vs %d", b, a))
      local function moved(sp)
        env(); PV.vis_speed = sp
        local VIS = include("lib/visuals"); VIS.init()
        local S = mkS(); SCEN.silence.setup(S)
        local prev, d = nil, 0
        for f = 1, 100 do
          screen.clear(); VIS.draw(th, S, 1 / FPS)
          local c = copybuf()
          if prev and f > 40 then d = d + bufdiff(prev, c) end
          prev = c
        end
        return d
      end
      local slow, fast = moved(1), moved(9)
      if REPORT then print(string.format("speed %-9s 1: %.3f  9: %.3f", name, slow, fast)) end
      assert(fast > slow * 1.5, string.format("speed 9 moves %.3f vs speed 1 %.3f", fast, slow))
    end)
  end
end

-- a theme switch eases through black rather than cutting
if not ONLY then
  test("visuals theme switch eases", function()
    local st = run(1, "mid", {frames = 400, switch_every = 25})
    if REPORT then print(string.format("switch diffMax %.3f", st.diff_max)) end
    assert(st.diff_max <= DIFF_MAX * 0.8, string.format("theme switch jump %.3f", st.diff_max))
    assert(st.bad == 0)
  end)
  test("visuals names: v1 order first, then the new themes", function()
    env()
    local VIS = include("lib/visuals")
    assert(#VIS.names == #NAMES, #VIS.names .. " themes")
    for i, n in ipairs(NAMES) do assert(VIS.names[i] == n, i .. ": " .. tostring(VIS.names[i])) end
  end)
end

-- the glitch tear: every mode, on every theme, stays inside the bounds and
-- lets go of the picture when it ends
if not ONLY then
  test("visuals glitch: every mode bounded, every theme, and released", function()
    for th = 1, #NAMES do
      for mode = 1, 5 do
        local base = run(th, "mid", {frames = 60, seed = 3})
        local st = run(th, "mid", {frames = 60, seed = 3, at = function(f, VIS)
          if f == 30 then VIS.event("glitch", mode, 0.6) end
        end, keep = true})
        assert(st.bad == 0, NAMES[th] .. " glitch " .. mode .. ": bad draw values")
        assert(st.lit_max <= LIT_MAX, NAMES[th] .. " glitch " .. mode .. string.format(" lit %.3f", st.lit_max))
        assert(st.l15_max <= L15_MAX, NAMES[th] .. " glitch " .. mode .. " l15 " .. st.l15_max)
        assert(st.diff_max <= DIFF_MAX, NAMES[th] .. " glitch " .. mode .. string.format(" jump %.3f", st.diff_max))
        assert(st.ops_max <= OPS_BUDGET, NAMES[th] .. " glitch ops " .. st.ops_max)
      end
    end
  end)

  test("visuals glitch changes the picture while it runs", function()
    local a = run(9, "mid", {frames = 40, seed = 5, keep = true})
    local b = run(9, "mid", {frames = 40, seed = 5, keep = true, at = function(f, VIS)
      if f == 30 then VIS.event("glitch", 1, 0.5) end
    end})
    assert(bufdiff(a.frames[34], b.frames[34]) > 0.01, "stutter tore nothing")
    local c = run(9, "mid", {frames = 40, seed = 5, keep = true, at = function(f, VIS)
      if f == 10 then VIS.event("glitch", 1, 0.3) end
    end})
    -- released: the shift is gone a second after (themes keep their own state)
    assert(bufdiff(a.frames[40], c.frames[40]) < 0.4, "glitch never let go")
  end)

  test("visuals new drum events and garbage never throw", function()
    env()
    local VIS = include("lib/visuals"); VIS.init()
    local S = mkS()
    for th = 1, #NAMES do
      for _, ev in ipairs({{"clap"}, {"perc", 2, 60}, {"perc", "x", nil}, {"tick", 9},
                           {"glitch", 0 / 0, 1e9}, {"glitch", -3, -1}, {"glitch"}, {42}, {nil},
                           {"nonsense", {}, {}}, {"perc", math.huge, -math.huge},
                           {"pad", {}}, {"pad", {60}}, {"pad", {0 / 0, 50}}, {"pad", "x"}, {"pad", nil}}) do
        VIS.event(ev[1], ev[2], ev[3])
      end
      screen.clear(); RAST.reset_ops()
      VIS.draw(th, S, 1 / FPS)
      assert(RAST.bad == 0, NAMES[th] .. " bad draw after garbage events")
    end
    -- odd theme indices and state draw something rather than nothing
    for _, i in ipairs({0, -5, 99, 0 / 0, "3", nil}) do
      screen.clear(); RAST.reset_ops()
      VIS.draw(i, S, 1 / FPS)
      assert(RAST.bad == 0)
    end
    screen.clear(); VIS.draw(1, nil, 1 / FPS)
    screen.clear(); VIS.draw(1, {energy = "loud", chord = "Am", gain = 3, lanes = 7, step = {}}, 1 / FPS)
  end)

  test("visuals a broken theme falls back instead of failing", function()
    env()
    local VIS = include("lib/visuals"); VIS.init()
    local S = mkS(); SCEN.mid.setup(S)
    -- break theme 2's draw and its stab handler from the outside
    local saved_print = print
    local logs = 0
    print = function() logs = logs + 1 end
    local ok = pcall(function()
      local reached
      for j = 1, 60 do
        local name, val = debug.getupvalue(VIS.draw, j)
        if not name then break end
        if name == "THEMES" then reached = val end
      end
      assert(reached, "THEMES not reachable")
      local th = reached[2]
      local d, st = th.draw, th.stab
      th.draw = function() error("boom") end
      th.stab = function() error("stab boom") end
      for f = 1, 40 do
        VIS.event("stab", {50, 57, 60, 65})
        screen.clear(); RAST.reset_ops()
        VIS.draw(2, S, 1 / FPS)
      end
      local lit = lit_stats()
      assert(lit > 0.01, string.format("fallback scene lit only %.3f", lit))
      th.draw, th.stab = d, st
    end)
    print = saved_print
    assert(ok, "a broken theme threw out of VIS")
    assert(logs == 1, "broken theme logged " .. logs .. " times, wanted once")
  end)

  test("visuals per-frame draw budget holds against a runaway theme", function()
    env()
    local VIS = include("lib/visuals"); VIS.init()
    local THEMES
    for j = 1, 60 do
      local name, val = debug.getupvalue(VIS.draw, j)
      if not name then break end
      if name == "THEMES" then THEMES = val end
    end
    local d = THEMES[1].draw
    local KK
    for j = 1, 60 do
      local name, val = debug.getupvalue(d, j)
      if not name then break end
      if name == "K" then KK = val end
    end
    THEMES[1].draw = function() for n = 1, 50000 do KK.put(3, n % 128, n % 64, 1, 1) end end
    screen.clear(); RAST.reset_ops()
    VIS.draw(1, mkS(), 1 / FPS)
    THEMES[1].draw = d
    assert(RAST.ops <= OPS_BUDGET + 40, "runaway theme made " .. RAST.ops .. " draw calls")
  end)
end
