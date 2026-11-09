-- gradient / meter
-- time signatures: a bar is beats * 4 sixteenths. a feel groups the beats
-- (even = every beat leads; short-long / long-short = two groups) and says
-- where the kick and pump lean.

local MT = {}

MT.METERS = {4, 3, 5, 7}                          -- beats, in the param's option order
MT.FEELS  = {"even", "short-long", "long-short"}

local GROUPS = {
  [3] = {{2, 1}, {1, 2}},
  [4] = {{2, 2}, {3, 1}},
  [5] = {{3, 2}, {2, 3}},
  [7] = {{4, 3}, {3, 4}},
}

local function feel_index(feel)
  for i, f in ipairs(MT.FEELS) do if f == feel then return i end end
  return 1
end

-- group lengths in beats
function MT.groups(beats, feel)
  local fi = feel_index(feel)
  local g = {}
  if fi == 1 or not GROUPS[beats] then
    for i = 1, beats do g[i] = 1 end
  else
    for i, v in ipairs(GROUPS[beats][fi - 1]) do g[i] = v end
  end
  return g
end

-- "5/4 3+2", or "5/4" in even feel
function MT.label(beats, feel)
  local s = beats .. "/4"
  if feel_index(feel) == 1 then return s end
  return s .. " " .. table.concat(MT.groups(beats, feel), "+")
end

-- the live bar descriptor
function MT.bar(beats, feel)
  local groups = MT.groups(beats, feel)
  local starts, b = {}, 1
  for _, len in ipairs(groups) do starts[b] = true; b = b + len end
  local n = beats * 4
  return {beats = beats, feel = feel or "even", n = n, groups = groups, starts = starts, last = n}
end

-- a 16-entry template -> bar.n entries, beat by beat: the first beat is the
-- template's beat 1, the last is its beat 4, the middle ones cycle 2, 3
function MT.map16(tpl, bar)
  local out = {}
  for b = 1, bar.beats do
    local tb
    if b == 1 then tb = 1
    elseif b == bar.beats then tb = 4
    else tb = 2 + ((b - 2) % 2) end
    for k = 1, 4 do out[(b - 1) * 4 + k] = tpl[(tb - 1) * 4 + k] end
  end
  return out
end

-- switch S to a meter now: bar descriptor, and the bar restarts
function MT.apply(S, beats, feel)
  S.bar = MT.bar(beats, feel)
  S.bar_step = 1
  S.meter_pending = nil
end

-- the conductor calls this on the bar before a phrase starts
function MT.apply_pending(S)
  local p = S.meter_pending
  if not p then return false end
  S.meter_pending = nil
  if S.bar and p.beats == S.bar.beats and p.feel == S.bar.feel then return false end
  S.bar = MT.bar(p.beats, p.feel)
  return true
end

return MT
