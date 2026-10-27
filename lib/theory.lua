-- gradient / theory
-- modes, degree math, dub chord voicings, progression pairs

local T = {}

T.NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}

T.MODES = {
  {name = "aeolian",  steps = {0, 2, 3, 5, 7, 8, 10}},
  {name = "dorian",   steps = {0, 2, 3, 5, 7, 9, 10}},
  {name = "phrygian", steps = {0, 1, 3, 5, 7, 8, 10}},
}
T.MODE_NAMES = {}
for i, m in ipairs(T.MODES) do T.MODE_NAMES[i] = m.name end

-- stacked scale-degree offsets from the chord's own degree
T.VOICINGS = {
  {name = "m7",     degs = {0, 2, 4, 6}},   -- classic dub stab
  {name = "m9",     degs = {2, 4, 6, 8}},   -- rootless, floaty
  {name = "quartal", degs = {0, 3, 6, 9}},  -- open, Barker-ish shimmer
  {name = "add9",   degs = {0, 2, 4, 8}},
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

function T.name(pc, mode)
  return T.NOTE_NAMES[(pc % 12) + 1] .. " " .. T.MODES[mode].name
end

return T
