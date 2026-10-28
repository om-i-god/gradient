-- gradient / theory
-- modes, degree math, dub chord voicings, progression pairs

local T = {}

T.NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}

-- all seven-note, so degree math works for every one. `short` is for the
-- screen. `rel` = semitones from the relative natural minor's root to this
-- mode's root: following an input heard as A minor puts dorian on D,
-- lydian on F, phrygian dominant on E... the same notes either way (or,
-- for the harmonic/melodic colours, as close as a seven-note set gets).
-- new modes go on the end so saved psets keep their index.
T.MODES = {
  {name = "aeolian",           short = "aeol",   rel = 0,  steps = {0, 2, 3, 5, 7, 8, 10}},
  {name = "dorian",            short = "dor",    rel = 5,  steps = {0, 2, 3, 5, 7, 9, 10}},
  {name = "phrygian",          short = "phr",    rel = 7,  steps = {0, 1, 3, 5, 7, 8, 10}},
  {name = "locrian",           short = "loc",    rel = 2,  steps = {0, 1, 3, 5, 6, 8, 10}},
  {name = "mixolydian",        short = "mix",    rel = 10, steps = {0, 2, 4, 5, 7, 9, 10}},
  {name = "ionian",            short = "ion",    rel = 3,  steps = {0, 2, 4, 5, 7, 9, 11}},
  {name = "lydian",            short = "lyd",    rel = 8,  steps = {0, 2, 4, 6, 7, 9, 11}},
  {name = "harmonic minor",    short = "hmin",   rel = 0,  steps = {0, 2, 3, 5, 7, 8, 11}},
  {name = "melodic minor",     short = "mmin",   rel = 0,  steps = {0, 2, 3, 5, 7, 9, 11}},
  {name = "phrygian dominant", short = "phrdom", rel = 7,  steps = {0, 1, 4, 5, 7, 8, 10}},
  {name = "dorian #4",         short = "dor#4",  rel = 5,  steps = {0, 2, 3, 6, 7, 9, 10}},
  {name = "hungarian minor",   short = "hung",   rel = 0,  steps = {0, 2, 3, 6, 7, 8, 11}},
}
T.MODE_NAMES = {}
for i, m in ipairs(T.MODES) do T.MODE_NAMES[i] = m.name end

-- the moods a new track or set modulation drifts between: weighted to the
-- dark dub minors, with the brighter / stranger colours as rare visits
T.MODE_POOL = {1, 1, 1, 2, 2, 3, 3, 8, 9, 10, 5, 11}

-- root for `mode` that shares the notes of the natural minor on `minor_pc`
function T.root_for(minor_pc, mode)
  return (minor_pc + T.MODES[mode].rel) % 12
end

-- the natural-minor root whose notes `mode` on `pc` borrows
function T.minor_of(pc, mode)
  return (pc - T.MODES[mode].rel) % 12
end

-- stacked scale-degree offsets from the chord's own degree
T.VOICINGS = {
  {name = "m7",     degs = {0, 2, 4, 6}},   -- classic dub stab
  {name = "m9",     degs = {2, 4, 6, 8}},   -- rootless, floaty
  {name = "quartal", degs = {0, 3, 6, 9}},  -- open, Barker-ish shimmer
  {name = "add9",   degs = {0, 2, 4, 8}},
  -- colours the harmony picks from by energy (new ones go on the end)
  {name = "sus2",    degs = {0, 1, 4, 7}},
  {name = "sus4",    degs = {0, 3, 4, 7}},
  {name = "m11",     degs = {0, 2, 6, 10}},
  {name = "cluster", degs = {0, 1, 2, 4}},
  {name = "6/9",     degs = {0, 4, 5, 8}},
}
T.VOICING_NAMES = {}
for i, v in ipairs(T.VOICINGS) do T.VOICING_NAMES[i] = v.name end

-- two-chord worlds (scale degrees); {1,1} = static, the purest dub
T.PAIRS = {
  {1, 1}, {1, 6}, {1, 4}, {1, 7}, {1, 5}, {1, 3},
}

-- midi note for scale degree d (1-based; may run past 7 or below 1)
function T.degree(base, mode, d)
  local steps = T.MODES[mode].steps
  local i     = d - 1
  local oct   = math.floor(i / 7)
  return base + steps[(i % 7) + 1] + 12 * oct
end

-- four notes for chord on `degree`, voiced from `base` (midi of key root)
function T.chord(base, mode, degree, voicing)
  local out = {}
  for i, off in ipairs(T.VOICINGS[voicing].degs) do
    out[i] = T.degree(base, mode, degree + off)
  end
  -- keep the stab in a narrow band: fold anything a 10th+ above base down
  for i = 1, 4 do
    while out[i] - base > 19 do out[i] = out[i] - 12 end
  end
  table.sort(out)
  return out
end

function T.name(pc, mode, short)
  local m = T.MODES[mode]
  return T.NOTE_NAMES[(pc % 12) + 1] .. " " .. (short and m.short or m.name)
end

return T
