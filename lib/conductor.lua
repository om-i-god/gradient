-- gradient / conductor
-- runs once per bar. owns the energy arc (set or track), decides which
-- parts sound, fades them in/out over bars, mutates material on phrase
-- boundaries, moves harmony, and throws the dub echo.

local T = include("lib/theory")
local G = include("lib/gen")

local C = {}

local PHRASE = 8

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
  noise = -1, wash = -1,
  lane1 = 0.08, lane2 = 0.28, lane3 = 0.50, lane4 = 0.70,
  chords = 0.22, rim = 0.35, hats = 0.42, bass = 0.45, kick = 0.50, pump = 0.25,
}
C.FADED = {"noise", "wash", "lane1", "lane2", "lane3", "lane4", "chords", "rim", "hats", "bass"}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

------------------------------------------------------------------------
-- material
------------------------------------------------------------------------

function C.regen_material(S)
  S.pat.kick   = G.kick()
  S.pat.hats   = G.hats()
  S.pat.rim    = G.rim()
  S.pat.stabs  = G.stabs()
  S.pat.bass   = G.bass()
  for i = 1, 4 do S.lanes[i] = G.lane(i) end
  S.pair       = G.pick(T.PAIRS)
  S.harm_bars  = G.pick({2, 4, 4, 8})
  S.pair_i     = 1
end

-- new track: seed drives the material; key moves to a neighbour if asked
function C.new_track(S, seed, move_key)
  math.randomseed(seed)
  S.seed = seed
  if move_key and not S.follow then
    S.root_pc = (S.root_pc + G.pick({0, 5, 7, -5, 3})) % 12
    S.mode    = G.pick({1, 1, 2, 3})
  end
  C.regen_material(S)
  S.track_bar = 0
  S.nudge     = 0
  S.cycle_bars = G.pick({64, 96, 128})
  for _, k in ipairs(C.FADED) do S.gain[k] = 0 end
  S.jitter = {}
  S.drop_phrases = 0
  C.update_chord(S)
end

function C.update_chord(S)
  local degree = S.pair[S.pair_i]
  S.chord_degree = degree
  S.chord = T.chord(48 + S.root_pc, S.mode, degree, S.voicing)
  S.chord_changed = true
end

------------------------------------------------------------------------
-- energy
------------------------------------------------------------------------

local function track_total(S)
  -- minutes -> bars at current tempo, rounded to phrases
  local bars = S.track_minutes * clock.get_tempo() / 4
  return math.max(PHRASE * 6, math.floor(bars / PHRASE + 0.5) * PHRASE)
end

local function track_section(S)
  local total = track_total(S)
  local start = 0
  for i, sec in ipairs(C.SECTIONS) do
    local len = math.floor(sec.len * total / PHRASE + 0.5) * PHRASE
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
-- per-bar tick
------------------------------------------------------------------------

-- returns "stop" when a track finishes with end action = stop
function C.bar(S)
  local bar_in_phrase = (S.track_bar % PHRASE) + 1

  -- user nudge relaxes back to zero over ~16 bars
  S.nudge = S.nudge * 0.9
  if math.abs(S.nudge) < 0.01 then S.nudge = 0 end

  S.energy = clamp(base_energy(S) + S.nudge, 0, 1)
  local e = S.energy

  -- phrase boundary: who plays, what mutates
  if bar_in_phrase == 1 then
    C.phrase(S)
  elseif bar_in_phrase == 5 or S.section == "outro" then
    C.decide(S)
  end

  -- harmony
  if S.track_bar > 0 and S.track_bar % S.harm_bars == 0 and e > 0.2 then
    S.pair_i = (S.pair_i % 2) + 1
    C.update_chord(S)
  end

  -- fades: each faded part moves 1/4 of the way per bar -> ~4-bar fades
  for _, k in ipairs(C.FADED) do
    local target = S.want[k] and 1 or 0
    local g = S.gain[k] or 0
    if target > g then g = math.min(1, g + 0.25) else g = math.max(0, g - 0.25) end
    S.gain[k] = g
  end

  -- dub throw on the last bar of some phrases
  S.throw = (bar_in_phrase == PHRASE) and (math.random() < 0.2 + S.dub * 0.35)

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
    S.cycle_bars = G.pick({64, 96, 128})
    S.key_moved = true
    C.update_chord(S)
  end
end

-- phrase boundary: roll the dice once, then decide + mutate
function C.phrase(S)
  -- a followed input key lands on the phrase edge
  if S.pending_root then
    S.root_pc, S.mode = S.pending_root, 1
    S.pending_root = nil
    S.key_moved = true
    C.update_chord(S)
  end
  -- fresh jitter so parts don't enter in lockstep every time
  for k, _ in pairs(TH) do
    S.jitter[k] = (math.random() - 0.5) * 0.16
  end
  if S.drop_phrases > 0 then S.drop_phrases = S.drop_phrases - 1 end
  S.roll_kickless = math.random() < 0.25   -- Utility-style stretch
  S.roll_hats     = math.random() < 0.6
  S.roll_bass     = math.random() < 0.6
  C.decide(S)
  if not S.freeze then C.mutate(S) end
end

-- who plays; cheap and deterministic given this phrase's rolls, so it can
-- be re-run mid-phrase (half-phrase, every outro bar, drop key)
function C.decide(S)
  local e = S.energy
  local function over(k) return e > TH[k] + (S.jitter[k] or 0) end

  local drop = S.drop_phrases > 0

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
  S.want.lane1  = over("lane1")
  S.want.lane2  = over("lane2")
  S.want.lane3  = over("lane3")
  S.want.lane4  = over("lane4")
  S.want.chords = over("chords")
  S.want.rim    = over("rim")
  S.want.hats   = over("hats") and not (drop and S.roll_hats)
  S.want.bass   = over("bass") and not (kickless and S.roll_bass)
  S.on_kick     = over("kick") and not kickless
  S.on_pump     = over("pump")
end

function C.mutate(S)
  -- mutations: small and frequent for arps, rare for the rest
  local m = S.force_mutate and 1.6 or 1.0
  S.force_mutate = false
  for i = 1, 4 do
    if math.random() < 0.35 * m then G.mutate_lane(S.lanes[i]) end
  end
  if math.random() < 0.20 * m then S.pat.hats  = G.hats() end
  if math.random() < 0.15 * m then S.pat.stabs = G.stabs() end
  if math.random() < 0.12 * m then S.pat.bass  = G.bass() end
  if math.random() < 0.10 * m then S.pat.rim   = G.rim() end
  if math.random() < 0.06 * m then
    local j = math.random(4)
    S.lanes[j] = G.lane(j)
  end
  if math.random() < 0.08 * m then
    S.pair = G.pick(T.PAIRS)
    S.harm_bars = G.pick({2, 4, 4, 8})
  end
end

return C
