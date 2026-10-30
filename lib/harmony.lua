-- gradient / harmony
-- where the chords go. a progression is a loop of steps ({deg, bars}, or a
-- chord borrowed from outside the mode) that restarts on every phrase.
-- each new chord is voice-led from the last (fewest semitones moved); in
-- "drifting" it then morphs in one voice at a time, so the in-between
-- chords sound too. the bass can hold the tonic under it all (pedal) or
-- sit on the chord's 3rd / 5th. calm stretches hold chords twice as long,
-- peaks move twice as fast; the colour (voicing) opens up or thickens
-- with energy.
--
-- out: S.chord (4 midi notes, low -> high), S.bass_pc (semitones over the
-- key root), S.bass_free (bass may add 5ths / b7s over it), S.chord_root_pc,
-- S.chord_degree, S.chord_label (roman numeral for the screen).
--
-- "simple" is the old behaviour: the seed's two-chord pair, flipped every
-- harm_bars, one voicing, bass on the root.

local T = include("lib/theory")

local H = {}

H.NAMES = {"simple", "rich", "drifting"}
H.AUTO  = #T.VOICINGS + 1      -- the voicing param's last option: colour by energy

local function pick(t) return t[math.random(#t)] end

-- loops of scale degrees; the chord quality follows the mode, so one list
-- serves them all
local PROGS = {
  {1, 6, 3, 7}, {1, 4, 6, 5}, {1, 6, 4, 5}, {1, 7, 6, 7}, {1, 3, 4, 6},
  {1, 4, 1, 7}, {1, 6, 7},    {1, 3, 6},    {1, 4, 7, 3}, {1, 5, 6, 4},
  {6, 7, 1},    {1, 1, 6, 4}, {4, 5, 1},    {1, 7, 4},    {1, 3, 7, 6},
  {1, 6},       {1, 4},
}
-- each mode's signature moves get extra tickets
local FLAVOUR = {
  [2]  = {{1, 4, 1, 4}, {1, 4, 7, 1}, {1, 2, 4, 1}},   -- dorian: the major IV
  [3]  = {{1, 2, 1, 7}, {1, 2, 7, 1}},                -- phrygian: the b2
  [5]  = {{1, 7, 4, 1}, {1, 7, 1, 4}},                -- mixolydian: bVII
  [7]  = {{1, 2, 1, 5}, {1, 2, 7, 1}},                -- lydian: the II
  [10] = {{1, 2, 1, 2}, {1, 2, 7, 6}},                -- phrygian dominant
}
-- bars per chord, by chord count; each loop is 8 or 16 bars
local LENS = {
  [2] = {{4, 4}, {6, 2}, {8, 8}, {12, 4}, {5, 3}},
  [3] = {{3, 3, 2}, {4, 2, 2}, {2, 2, 4}, {6, 6, 4}, {4, 4, 8}},
  [4] = {{2, 2, 2, 2}, {4, 4, 4, 4}, {3, 3, 1, 1}, {4, 2, 4, 6}, {3, 1, 2, 2}, {2, 2, 3, 1}},
}
-- outside chords for the loop's last bar: a degree borrowed from another
-- mode on the same root, or the previous chord's shape slid (planing)
local BORROW = {
  {mode = 3, deg = 2},    -- bII, the neapolitan
  {mode = 1, deg = 6},    -- bVI
  {mode = 1, deg = 7},    -- bVII
  {mode = 2, deg = 4},    -- major IV
  {mode = 8, deg = 5},    -- major V, the harmonic-minor pull home
  {plane = -1}, {plane = 2},
}
-- voicing colours by energy (indices into T.VOICINGS)
local COLOUR = {
  low  = {3, 5, 2, 9},    -- quartal, sus2, m9, 6/9: open
  mid  = {1, 4, 2, 6},    -- m7, add9, m9, sus4
  high = {7, 8, 1, 4},    -- m11, cluster, m7, add9: dense
}
local PEDAL_SECTIONS = {intro = true, build = true, breakdown = true, drift = true, rise = true}
local ROMAN = {[0] = "I", "bII", "II", "bIII", "III", "IV", "#IV", "V", "bVI", "VI", "bVII", "VII"}

------------------------------------------------------------------------
-- building progressions
------------------------------------------------------------------------

local function in_scale(pc, mode)
  for _, s in ipairs(T.MODES[mode].steps) do
    if s == pc then return true end
  end
  return false
end

-- does a step use any note the mode doesn't have?
local function outside(st, mode)
  for _, off in ipairs({0, 2, 4, 6}) do
    local pc = (T.degree(0, st.mode or mode, st.deg + off) + (st.shift or 0)) % 12
    if not in_scale(pc, mode) then return true end
  end
  return false
end

local function build(S)
  local steps = {}
  if S.harmony == 1 then
    for i, d in ipairs(S.pair) do steps[i] = {deg = d, bars = S.harm_bars} end
    return steps
  end
  local pool = {}
  for _, p in ipairs(PROGS) do pool[#pool + 1] = p end
  for _, p in ipairs(FLAVOUR[S.mode] or {}) do
    pool[#pool + 1] = p
    pool[#pool + 1] = p
  end
  local degs = pick(pool)
  local lens = pick(LENS[#degs])
  for i, d in ipairs(degs) do steps[i] = {deg = d, bars = lens[i]} end
  -- now and then the loop's last bar leans outside the mode
  local last = steps[#steps]
  if math.random() < 0.35 and last.bars >= 2 then
    local opts = {}
    for _, b in ipairs(BORROW) do
      local st = b.plane and {deg = last.deg, shift = b.plane} or {deg = b.deg, mode = b.mode}
      if st.mode ~= S.mode and outside(st, S.mode) then opts[#opts + 1] = st end
    end
    if #opts > 0 then
      last.bars = last.bars - 1
      local st = pick(opts)
      st.bars, st.borrowed = 1, true
      steps[#steps + 1] = st
    end
  end
  return steps
end

------------------------------------------------------------------------
-- voicing
------------------------------------------------------------------------

-- voice leading: give each of the previous chord's voices one of the new
-- chord's notes (every assignment, each in the octave just below or above
-- that voice) and keep the one that moves least, stays in the stab's
-- register (A2..A5) and doesn't drift far from around D4. the colour's
-- notes all survive; only their octave placement changes.
local PERMS = {}
do
  local function perm(a, n)
    if n == 1 then PERMS[#PERMS + 1] = {a[1], a[2], a[3], a[4]}; return end
    for i = 1, n do
      a[i], a[n] = a[n], a[i]
      perm(a, n - 1)
      a[i], a[n] = a[n], a[i]
    end
  end
  perm({1, 2, 3, 4}, 4)
end

local function lead(prev, raw)
  local best, best_cost
  local c = {}
  for _, p in ipairs(PERMS) do
    for mask = 0, 15 do
      local cost = 0
      for v = 1, 4 do
        local pc = raw[p[v]] % 12
        local below = prev[v] - ((prev[v] - pc) % 12)       -- nearest at or below
        local up = (mask >> (v - 1)) & 1 == 1
        c[v] = (up and below ~= prev[v]) and below + 12 or below
        cost = cost + math.abs(c[v] - prev[v])
      end
      local s1, s2, s3, s4 = c[1], c[2], c[3], c[4]
      local lo, hi = math.min(s1, s2, s3, s4), math.max(s1, s2, s3, s4)
      if lo >= 45 and hi <= 81 and s1 ~= s2 and s1 ~= s3 and s1 ~= s4
         and s2 ~= s3 and s2 ~= s4 and s3 ~= s4 then
        cost = cost + math.abs((lo + hi) / 2 - 62) * 0.25
        if not best_cost or cost < best_cost then best, best_cost = {s1, s2, s3, s4}, cost end
      end
    end
  end
  return best or raw
end

local function publish(S)
  local v = S.h.voices
  local c = {v[1], v[2], v[3], v[4]}
  table.sort(c)
  S.chord = c
  S.chord_changed = true
end

local function set_bass(S)
  local h = S.h
  if not h.label then return end
  S.bass_pc   = h.pedal and 0 or h.bass_pc
  S.bass_free = h.pedal or h.bass_plain
  local label = h.label
  if h.pedal and h.root_pc ~= 0 then label = label .. "/" .. (h.minor_tonic and "i" or "I") end
  S.chord_label = label
end

-- bars the current step lasts at this energy
local function need(S)
  local st = S.h.prog[S.h.i]
  if S.harmony == 1 then return st.bars end
  local e = S.energy or 0
  local k = e < 0.3 and 2 or (e > 0.8 and 0.5 or 1)
  return math.max(1, math.floor(st.bars * k + 0.5))
end

-- a new step: pick its colour and where the bass sits
local function begin_step(S)
  local h = S.h
  local st = h.prog[h.i]
  local e = S.energy or 0
  if S.voicing == H.AUTO then
    h.colour = S.harmony == 1 and 1
      or pick(e < 0.4 and COLOUR.low or e < 0.75 and COLOUR.mid or COLOUR.high)
  else
    h.colour = S.voicing
  end
  local r = math.random()
  h.inv = (S.harmony == 1 or st.borrowed) and 0 or (r < 0.72 and 0 or r < 0.86 and 2 or 4)
  h.held = 0
end

-- move the next voice(s) of a morph; prefer a move that doesn't land on
-- a note another voice is still holding
local function morph(S)
  local h = S.h
  for _ = 1, h.per_bar do
    if #h.queue == 0 then break end
    local pick_i = 1
    for qi, mv in ipairs(h.queue) do
      local clash = false
      for vi = 1, 4 do
        if vi ~= mv[1] and h.voices[vi] == mv[2] then clash = true end
      end
      if not clash then pick_i = qi; break end
    end
    local mv = table.remove(h.queue, pick_i)
    h.voices[mv[1]] = mv[2]
  end
  publish(S)
end

------------------------------------------------------------------------
-- api
------------------------------------------------------------------------

-- fresh progression from step 1 (new track, harmony mode change)
function H.new_prog(S)
  S.h = S.h or {}
  local h = S.h
  h.prog, h.next = build(S), nil
  h.i, h.queue, h.per_bar = 1, {}, 1
  h.pedal_roll = math.random() < 0.55
  begin_step(S)
end

-- a new progression lands on the next 8-bar edge (mutate)
function H.next_prog(S)
  if S.h then S.h.next = build(S) end
end

-- sound the current step. drifting morphs into it unless `instant`.
function H.retarget(S, instant)
  local h = S.h
  if not h or not h.prog then return end
  local st = h.prog[h.i]
  local m = st.mode or S.mode
  local raw = T.chord(48 + S.root_pc, m, st.deg, h.colour or 1)
  for i = 1, 4 do raw[i] = raw[i] + (st.shift or 0) end
  -- a fold can land one voice on another: lift the double an octave
  table.sort(raw)
  for i = 2, 4 do
    while raw[i] <= raw[i - 1] do raw[i] = raw[i] + 12 end
    table.sort(raw)
  end
  local target = (S.harmony == 1 or not h.voices) and raw or lead(h.voices, raw)

  if S.harmony == 3 and h.voices and not instant then
    -- lead() kept each voice's slot: queue the ones that move
    h.queue = {}
    for vi = 1, 4 do
      if h.voices[vi] ~= target[vi] then h.queue[#h.queue + 1] = {vi, target[vi]} end
    end
    for k = #h.queue, 2, -1 do
      local j = math.random(k)
      h.queue[k], h.queue[j] = h.queue[j], h.queue[k]
    end
    -- spread over the first ~60% of the chord; the first move is now
    local span = math.max(1, math.floor(need(S) * 0.6))
    h.per_bar = math.max(1, math.ceil(#h.queue / span))
    morph(S)
  else
    h.voices = {target[1], target[2], target[3], target[4]}
    h.queue = {}
    publish(S)
  end

  -- root, bass, label
  local shift = st.shift or 0
  h.root_pc = (T.degree(0, m, st.deg) + shift) % 12
  h.bass_pc = (T.degree(0, m, st.deg + h.inv) + shift) % 12
  h.bass_plain = h.inv == 0 and not st.borrowed
  local third = (T.degree(0, m, st.deg + 2) - T.degree(0, m, st.deg)) % 12
  local name = ROMAN[h.root_pc]
  h.label = third == 3 and name:lower() or name
  h.minor_tonic = (T.MODES[S.mode].steps[3] == 3)
  S.chord_root_pc = h.root_pc
  S.chord_degree  = st.deg
  set_bass(S)
end

-- where the bass is going next bar (semitones over the key root), or nil
-- if the chord holds. `phrase_end` / `block_end`: next bar starts a phrase
-- (the loop restarts) / an 8-bar block (a queued progression lands)
function H.next_bass(S, phrase_end, block_end)
  local h = S.h
  if not h or not h.prog then return nil end
  local st
  if h.next and block_end then
    st = h.next[1]
  elseif phrase_end and S.harmony ~= 1 and h.i ~= 1 then
    st = h.prog[1]
  elseif h.held >= need(S) then
    st = h.prog[(h.i % #h.prog) + 1]
  end
  if not st then return nil end
  if h.pedal then return 0 end
  local m = st.mode or S.mode
  return (T.degree(0, m, st.deg) + (st.shift or 0)) % 12
end

-- phrase start: re-roll the pedal and, outside simple, restart the loop
function H.phrase(S)
  local h = S.h
  if not h or not h.prog then return end
  h.pedal_roll = math.random() < 0.55
  if S.harmony ~= 1 and h.i ~= 1 and not h.next then
    h.i = 1
    begin_step(S)
    H.retarget(S)
  end
end

-- once a bar, after the energy is known
function H.bar(S, bar_in_block)
  local h = S.h
  if not h or not h.prog then return end

  -- pedal: the tonic held through the calmer sections, let go when they end
  local pedal = S.harmony ~= 1 and h.pedal_roll and PEDAL_SECTIONS[S.section] or false
  if pedal ~= h.pedal then
    h.pedal = pedal
    set_bass(S)
  end

  if h.next and bar_in_block == 1 then
    h.prog, h.next, h.i = h.next, nil, 1
    begin_step(S)
    H.retarget(S)
  elseif h.held >= need(S) and (S.harmony ~= 1 or S.energy > 0.2) then
    h.i = (h.i % #h.prog) + 1
    begin_step(S)
    H.retarget(S)
  elseif #h.queue > 0 then
    morph(S)
  end
  h.held = h.held + 1
end

return H
