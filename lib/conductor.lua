-- gradient / conductor
-- runs once per bar. owns the energy arc (set or track), decides which
-- parts sound, fades them in/out over bars, mutates material on phrase
-- boundaries, moves harmony, and throws the dub echo.

local T = include("lib/theory")
local G = include("lib/gen")
local H = include("lib/harmony")
local TB = include("lib/timbre")
local MT = include("lib/meter")

local C = {}

local BLOCK = 8   -- dub throws, half-checks, drop and key landings run on 8 bars

-- phrase = how long the arrangement holds before parts move and material
-- mutates (param, 8..64 bars)
local function plen(S) return S.phrase_len or 32 end

-- track mode arc: fractions of total length; energy ramps e0 -> e1
C.SECTIONS = {
  {name = "intro",     len = 0.12, e0 = 0.08, e1 = 0.30},
  {name = "build",     len = 0.16, e0 = 0.30, e1 = 0.65},
  {name = "peak",      len = 0.20, e0 = 0.70, e1 = 0.88},
  {name = "breakdown", len = 0.14, e0 = 0.38, e1 = 0.25, kickless = true},
  {name = "return",    len = 0.22, e0 = 0.72, e1 = 1.00},
  {name = "outro",     len = 0.16, e0 = 0.80, e1 = 0.00},
}

-- part -> energy threshold to enter
local TH = {
  noise = -1, wash = -1, bed = -1,
  lane1 = 0.08, lane2 = 0.28, lane3 = 0.50, lane4 = 0.70,
  chords = 0.22, rim = 0.35, hats = 0.42, bass = 0.45, kick = 0.50, pump = 0.25,
  perc = 0.30, ticks = 0.38, clap = 0.58, ride = 0.80, ghost = 0.72,
}
C.FADED = {"noise", "wash", "bed", "lane1", "lane2", "lane3", "lane4", "chords", "rim", "hats", "bass",
           "perc", "clap", "ticks"}

-- glitch amount (param): 1 off, 2 subtle, 3 normal, 4 heavy -> chance per bar
-- of a small glitch somewhere in it
local GLITCH_P = {0, 0.1, 0.22, 0.45}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

------------------------------------------------------------------------
-- material
------------------------------------------------------------------------

function C.regen_material(S)
  S.pat.kick   = G.kick(S.bar)
  S.pat.hats   = G.hats(S.bar)
  S.pat.rim    = G.rim(S.bar)
  S.pat.stabs  = G.stabs(S.bar)
  S.pat.shaker = G.shaker(S.bar)
  S.pat.toms   = G.toms(S.bar)
  S.pat.clap   = G.clap(S.bar)
  S.pat.perc   = G.perc()
  S.pat.ride   = G.ride(S.bar)
  S.pat.ticks  = G.ticks(S.bar)
  S.pat.bass_lines = G.bass_lines(S.bar)
  S.pat.bass   = S.pat.bass_lines[1]
  for i = 1, 4 do S.lanes[i] = G.lane(i) end
  S.pair       = G.pick(T.PAIRS)
  S.harm_bars  = G.pick({2, 4, 4, 8})
  H.new_prog(S)
  TB.roll(S)
end

-- a meter or feel changed: rebuild only the patterns that follow the bar
-- (kick + ghosts, clap, hats, shaker, rim, toms, ride, ticks, stabs, bass)
-- from a sub-stream of the track seed and the meter. lanes, perc, harmony
-- and the rest of the material stay as they are.
function C.remeter(S)
  local bar = S.bar
  local fi = 1
  for i, f in ipairs(MT.FEELS) do if f == bar.feel then fi = i end end
  local resume = math.random(1 << 30)    -- later material carries on from here
  math.randomseed((S.seed or 0) * 31 + bar.beats * 7 + fi)
  local P = S.pat
  if P.kick   then P.kick   = G.kick(bar) end
  if P.clap   then P.clap   = G.clap(bar) end
  if P.hats   then P.hats   = G.hats(bar) end
  if P.shaker then P.shaker = G.shaker(bar) end
  if P.rim    then P.rim    = G.rim(bar) end
  if P.toms   then P.toms   = G.toms(bar) end
  if P.ride   then P.ride   = G.ride(bar) end
  if P.ticks  then P.ticks  = G.ticks(bar) end
  if P.stabs  then P.stabs  = G.stabs(bar) end
  if P.bass_lines then
    local cur = 1
    for i, l in ipairs(P.bass_lines) do if l == P.bass then cur = i end end
    P.bass_lines = G.bass_lines(bar)
    P.bass = P.bass_lines[cur]
  end
  math.randomseed(resume)
end

-- new track: seed drives the material; key moves to a neighbour if asked
function C.new_track(S, seed, move_key)
  math.randomseed(seed)
  S.seed = seed
  if move_key and not S.follow then
    S.root_pc = (S.root_pc + G.pick({0, 5, 7, -5, 3})) % 12
    S.mode    = G.pick(T.MODE_POOL)
  end
  C.regen_material(S)
  S.track_bar = 0
  S.nudge     = 0
  S.cycle_bars = G.pick({8, 12, 16}) * plen(S)
  for _, k in ipairs(C.FADED) do S.gain[k] = 0 end
  S.jitter = {}
  S.drop_bars = 0
  S.h.voices = nil
  C.update_chord(S, true)
end

-- re-sound the current chord after a key / mode / voicing change; in
-- drifting it morphs there unless `instant`
function C.update_chord(S, instant)
  H.retarget(S, instant)
end

-- harmony mode or voicing changed: rebuild the loop from step 1
function C.reharm(S)
  if not S.h then return end
  H.new_prog(S)
  H.retarget(S)
end

------------------------------------------------------------------------
-- energy
------------------------------------------------------------------------

local function track_total(S)
  -- minutes -> bars at current tempo, rounded to phrases
  local bars = S.track_minutes * clock.get_tempo() / 4
  local P = plen(S)
  return math.max(P * 6, math.floor(bars / P + 0.5) * P)
end

local function track_section(S)
  local total = track_total(S)
  local start = 0
  for i, sec in ipairs(C.SECTIONS) do
    local P = plen(S)
    local len = math.max(P, math.floor(sec.len * total / P + 0.5) * P)
    if i == #C.SECTIONS then len = total - start end
    if S.track_bar < start + len then
      return sec, (S.track_bar - start) / math.max(1, len), total
    end
    start = start + len
  end
  return C.SECTIONS[#C.SECTIONS], 1, total
end

local function base_energy(S)
  if S.mode_play == 2 then
    local sec, prog, total = track_section(S)
    S.section  = sec.name
    S.kickless_section = sec.kickless or false
    S.progress = S.track_bar / total
    S.total_bars = total
    return sec.e0 + (sec.e1 - sec.e0) * prog
  else
    -- set mode: slow cosine swell + random walk; trough = breakdown
    local ph = (S.track_bar % S.cycle_bars) / S.cycle_bars
    S.walk = clamp((S.walk or 0) + (math.random() - 0.5) * 0.04, -0.15, 0.15)
    local e = 0.52 - 0.40 * math.cos(ph * 2 * math.pi) + S.walk
    S.progress = ph
    S.kickless_section = e < 0.32 and S.track_bar > 16
    S.section = (e < 0.32) and "drift" or (e < 0.6) and "rise" or "peak"
    return e
  end
end

------------------------------------------------------------------------
-- fills: the bar before a phrase edge, sometimes an 8-bar edge
--   swell  noise riser into the downbeat      dip   filter dip on the pads
--   toms   a tom run down the chord           gap   drums out for the last beat(s)
--   throw  an extra stab, echo thrown         open  open hats + rim ghosts
-- with glitch on, also (the glitch insert on the whole mix):
--   stutter the last beat repeats, the slices halving   tapestop  the mix winds down
--   reverse the last beat plays backwards
------------------------------------------------------------------------

local function pick_fill(S, big)
  local e = S.energy
  local t = {"open", "throw", "toms"}
  if big then
    t = {"swell", "dip", "toms", "gap", "throw", "open"}
    -- heading up: risers and gaps; settling: dips and throws
    if (S.trend or 0) > 0.002 or S.nudge > 0.05 then
      t[#t + 1] = "swell"; t[#t + 1] = "gap"; t[#t + 1] = "swell"
    elseif e < 0.45 then
      t[#t + 1] = "dip"; t[#t + 1] = "throw"
    end
  end
  -- glitch fills, more of them the more glitch there is
  local gl = S.glitch_amt or 3
  for _ = 1, gl - 1 do
    t[#t + 1] = G.pick(big and {"stutter", "tapestop", "reverse"} or {"stutter", "reverse"})
  end
  local f = G.pick(t)
  -- toms and gaps need something to play / something to stop
  -- toms belong to the hats (style, mute)
  if f == "toms" and (e < 0.25 or S.hat_style == 3 or S.mute.hats) then f = "throw" end
  if f == "gap" and not S.on_kick and (S.gain.hats or 0) == 0 then f = "dip" end
  return f
end

-- small glitches inside a bar: {step, mode, slices (16ths), length (16ths)}.
-- more near the top of the energy and in kickless stretches; never on a
-- bar with a fill, never under a solo
local function roll_glitch(S)
  S.glitches = nil
  local p = GLITCH_P[S.glitch_amt or 3] or 0
  if p == 0 or S.fill or next(S.solo or {}) or S.mute.ticks then return end
  p = p * (0.4 + S.energy * 0.8 + (S.kickless and 0.3 or 0))
  local n = 0
  while math.random() < p and n < 3 do
    n = n + 1
    S.glitches = S.glitches or {}
    local step = G.pick({4, 6, 8, 10, 12, 14, 15, 16, 7, 11})
    local r = math.random()
    local g
    if r < 0.45 then g = {step, 1, G.pick({0.5, 0.5, 1}), G.pick({1, 2, 2})}   -- stutter
    elseif r < 0.65 then g = {step, 4, 0.5, 2}                                -- chop
    elseif r < 0.82 then g = {step, 5, 1, G.pick({2, 4})}                     -- crush
    else g = {step, 3, 1, 2} end                                              -- reverse
    S.glitches[step] = g
    p = p * 0.5
  end
end

local function roll_fill(S, bar_in_phrase, bar_in_block)
  S.fill = nil
  local amt = S.fills or 1               -- 1 normal, 2 busy, 3 off
  -- no fills while something's soloed: you're listening to that part
  if amt == 3 or S.track_bar == 0 or next(S.solo or {}) then return end
  local busy = amt == 2
  if bar_in_phrase == plen(S) then
    if math.random() < (busy and 1 or 0.85) then S.fill = pick_fill(S, true) end
  elseif bar_in_block == BLOCK then
    if math.random() < (busy and 0.6 or 0.3) then S.fill = pick_fill(S, false) end
  elseif busy and bar_in_block == 4 and math.random() < 0.25 then
    S.fill = pick_fill(S, false)
  end
  S.fill_from = (S.fill == "gap" and math.random() < 0.4) and 9 or 13
  if S.fill == "throw" then S.throw = true end
end

------------------------------------------------------------------------
-- per-bar tick
------------------------------------------------------------------------

-- returns "stop" when a track finishes with end action = stop
function C.bar(S)
  local P = plen(S)
  local bar_in_phrase = (S.track_bar % P) + 1
  local bar_in_block  = (S.track_bar % BLOCK) + 1

  -- user nudge relaxes back to zero over ~16 bars
  S.nudge = S.nudge * 0.9
  if math.abs(S.nudge) < 0.01 then S.nudge = 0 end

  local prev_e = S.energy
  S.energy = clamp(base_energy(S) + S.nudge, 0, 1)
  local e = S.energy
  -- which way the energy is heading, smoothed (fills + open hats read it)
  S.trend = (S.trend or 0) * 0.85 + (e - prev_e) * 0.15

  if S.drop_bars > 0 then S.drop_bars = S.drop_bars - 1 end

  -- a followed input key lands on the next 8-bar edge
  if bar_in_block == 1 and S.pending_root then
    S.root_pc = S.pending_root
    S.pending_root = nil
    S.key_moved = true
    C.update_chord(S)
  end

  -- a meter or feel picked mid-phrase lands here, on the phrase's first bar
  if bar_in_phrase == 1 and MT.apply_pending(S) then C.remeter(S) end

  -- phrase boundary: who plays, what mutates; re-check every 4 bars
  -- (and every outro bar) so long phrases still follow the energy arc
  if bar_in_phrase == 1 then
    C.phrase(S)
  elseif bar_in_phrase % 4 == 1 or S.section == "outro" then
    C.decide(S)
  end

  -- harmony: progression, voice leading, morphs, pedal (lib/harmony)
  if bar_in_phrase == 1 and S.track_bar > 0 then H.phrase(S) end
  H.bar(S, bar_in_block)

  -- bass: the line for this energy band; every 4th bar can turn around,
  -- walking into the next chord if there is one
  local lines = S.pat.bass_lines
  if lines then S.pat.bass = lines[e < 0.5 and 1 or (e < 0.75 and 2 or 3)] end
  S.bass_turn = bar_in_block % 4 == 0 and math.random() < 0.55
  S.bass_appr = G.pick({-1, -1, 1, -2})
  S.bass_next = S.bass_turn and H.next_bass(S, bar_in_phrase == plen(S), bar_in_block == BLOCK) or nil

  -- fades: each faded part moves 1/4 of the way per bar -> ~4-bar fades
  for _, k in ipairs(C.FADED) do
    local target = S.want[k] and 1 or 0
    local g = S.gain[k] or 0
    if target > g then g = math.min(1, g + 0.25) else g = math.max(0, g - 0.25) end
    S.gain[k] = g
  end

  -- dub throw on the last bar of some phrases
  S.throw = (bar_in_block == BLOCK) and (math.random() < 0.2 + S.dub * 0.35)
  roll_fill(S, bar_in_phrase, bar_in_block)
  roll_glitch(S)

  S.track_bar = S.track_bar + 1

  -- track end
  if S.mode_play == 2 and S.track_bar >= (S.total_bars or math.huge) then
    if S.end_action == 1 then
      return "stop"
    else
      C.new_track(S, math.random(1, 9999), true)
      return "next"
    end
  end
  -- set mode: modulate at a cycle trough now and then
  if S.mode_play == 1 and not S.follow
     and S.track_bar % S.cycle_bars == 0 and math.random() < 0.5 then
    S.root_pc = (S.root_pc + G.pick({5, 7, -5, 3})) % 12
    S.pair = G.pick(T.PAIRS)
    H.new_prog(S)
    S.cycle_bars = G.pick({8, 12, 16}) * plen(S)
    S.key_moved = true
    C.update_chord(S)
  end
end

-- phrase boundary: roll the dice once, then decide + mutate
function C.phrase(S)
  -- fresh jitter so parts don't enter in lockstep every time
  for k, _ in pairs(TH) do
    S.jitter[k] = (math.random() - 0.5) * 0.16
  end
  S.roll_kickless = math.random() < 0.25   -- Utility-style stretch
  S.roll_hats     = math.random() < 0.6
  S.roll_bass     = math.random() < 0.6
  S.roll_shaker   = math.random() < 0.5
  S.roll_toms     = math.random() < 0.45
  S.roll_ride     = math.random() < 0.5
  S.roll_ghost    = math.random() < 0.5
  S.roll_perc_kl  = math.random() < 0.6    -- perc stays in (or comes in) for a kickless stretch
  S.roll_clap_kl  = math.random() < 0.7    -- clap sits out a kickless stretch
  C.decide(S)
  TB.phrase(S)
  if not S.freeze then C.mutate(S) end
end

-- who plays; cheap and deterministic given this phrase's rolls, so it can
-- be re-run mid-phrase (half-phrase, every outro bar, drop key)
function C.decide(S)
  local e = S.energy
  local function over(k) return e > TH[k] + (S.jitter[k] or 0) end

  local drop = S.drop_bars > 0

  -- kickless: section says so, user dropped it, style forces it, or
  -- an occasional Utility-style stretch at mid energy
  local kickless = S.kickless_section or drop or S.kick_style == 3
  if S.kick_style == 1 and not kickless and e > 0.4 and e < 0.8 then
    kickless = S.roll_kickless
  end
  if S.kick_style == 2 then kickless = false end
  S.kickless = kickless

  S.want.noise  = true
  S.want.wash   = true
  S.want.bed    = true
  S.want.lane1  = over("lane1")
  S.want.lane2  = over("lane2")
  S.want.lane3  = over("lane3")
  S.want.lane4  = over("lane4")
  S.want.chords = over("chords")
  S.want.rim    = over("rim")
  -- hats: auto sometimes clears them for a drop; always stays in; never
  S.want.hats   = over("hats") and S.hat_style ~= 3
                  and (S.hat_style == 2 or not (drop and S.roll_hats))
  -- bass: auto sits out some kickless stretches; always stays in; never
  S.want.bass   = over("bass") and S.bass_style ~= 3
                  and (S.bass_style == 2 or not (kickless and S.roll_bass))
  S.on_kick     = over("kick") and not kickless
  S.on_pump     = over("pump")
  -- percussion: auto brings it in on the energy, and on some kickless
  -- stretches lower down too (congas in the breakdown); always stays in;
  -- never
  S.want.perc   = S.perc_style ~= 3 and (over("perc") or (kickless and S.roll_perc_kl and e > 0.15))
                  and (S.perc_style == 2 or not drop or S.roll_perc_kl)
  -- clap: auto sits out drops and most kickless stretches
  S.want.clap   = over("clap") and S.clap_style ~= 3
                  and (S.clap_style == 2 or not (drop or (kickless and S.roll_clap_kl)))
  -- glitch ticks: off with glitch off; float on in kickless stretches
  S.want.ticks  = (S.glitch_amt or 3) > 1
                  and (over("ticks") or (kickless and e > 0.2 and (S.glitch_amt or 3) > 2))
  -- ride and ghost kicks: near the top, on some phrases (ride rides with the hats)
  S.on_ride     = over("ride") and S.roll_ride
  S.on_ghost    = over("ghost") and S.roll_ghost and S.on_kick

  -- hand mutes (grid) override the arc; the pump keeps breathing
  local m = S.mute or {}
  for k, _ in pairs(S.want) do
    if m[k] then S.want[k] = false end
  end
  if m.kick then S.on_kick = false; S.on_ghost = false end

  -- solo: only the soloed parts (beds included) play
  if next(S.solo or {}) then
    for k, _ in pairs(S.want) do
      if not S.solo[k] then S.want[k] = false end
    end
    if not S.solo.kick then S.on_kick = false; S.on_ghost = false end
  end
end

function C.mutate(S)
  -- mutations: small and frequent for arps, rare for the rest
  local m = S.force_mutate and 1.6 or 1.0
  S.force_mutate = false
  for i = 1, 4 do
    if math.random() < 0.35 * m then G.mutate_lane(S.lanes[i]) end
  end
  if math.random() < 0.20 * m then S.pat.hats  = G.hats(S.bar) end
  if math.random() < 0.10 * m then S.pat.shaker = G.shaker(S.bar) end
  if math.random() < 0.15 * m then S.pat.toms  = G.toms(S.bar) end
  if math.random() < 0.15 * m then S.pat.stabs = G.stabs(S.bar) end
  if math.random() < 0.12 * m and S.pat.bass_lines then
    local j = math.random(3)
    S.pat.bass_lines[j] = G.bass(G.pick(({{"root", "slide"}, {"octave", "slide"},
                                           {"rolling", "octave"}})[j]), S.bar)
  end
  if math.random() < 0.10 * m then S.pat.rim   = G.rim(S.bar) end
  if math.random() < 0.10 * m then S.pat.clap  = G.clap(S.bar) end
  if math.random() < 0.12 * m then S.pat.ride  = G.ride(S.bar) end
  if math.random() < 0.18 * m then S.pat.ticks = G.ticks(S.bar) end
  -- the perc lane rotates or regrows, like an arp lane; it keeps its kit
  if math.random() < 0.30 * m then
    local pc = S.pat.perc
    if math.random() < 0.6 then
      table.insert(pc, 1, table.remove(pc, pc.len))
    else
      local np = G.perc()
      np.kit, np.pos = pc.kit, 0
      S.pat.perc = np
    end
  end
  if math.random() < 0.06 * m then
    local j = math.random(4)
    S.lanes[j] = G.lane(j)
  end
  if math.random() < 0.08 * m then
    S.pair = G.pick(T.PAIRS)
    S.harm_bars = G.pick({2, 4, 4, 8})
    H.next_prog(S)
  end
end

return C
