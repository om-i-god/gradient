-- gradient / gen
-- pattern generators: drums, stab rhythms, bass lines, phasing arp lanes.
-- 16-step tables are indexed 1..16; drum/stab entries are velocities (0 = rest).

local MT = include("lib/meter")

local G = {}

local function pick(t) return t[math.random(#t)] end
G.pick = pick

-- every bar-length generator takes a bar descriptor (lib/meter) and
-- defaults to 4/4 even. each makes exactly the draws it always did, in the
-- same order, and only then shapes the result for the bar, so 4/4 even
-- gives the same patterns per seed as before the meters existed.
local BAR44 = MT.bar(4, "even")

-- a 16-entry template (with any extra named fields) -> bar.n entries
local function lay(tpl, bar)
  local out = MT.map16(tpl, bar)
  for i = 1, #out do
    if type(out[i]) == "table" then
      local c = {}
      for k, v in pairs(out[i]) do c[k] = v end
      out[i] = c
    end
  end
  for k, v in pairs(tpl) do
    if type(k) ~= "number" then out[k] = v end
  end
  return out
end

-- a list of 16-step positions -> the same hits laid into the bar
local function lay_steps(list, bar)
  local flags = {}
  for i = 1, 16 do flags[i] = 0 end
  for _, s in ipairs(list) do flags[s] = 1 end
  local out = {}
  for i, v in ipairs(MT.map16(flags, bar)) do
    if v == 1 then out[#out + 1] = i end
  end
  return out
end

function G.euclid(k, n, rot)
  local out = {}
  for i = 0, n - 1 do
    local j = (i + (rot or 0)) % n
    out[j + 1] = ((i * k) % n) < k
  end
  return out
end

-- four on the floor; `ghost` = quiet extra kicks a track may add near the
-- top of the energy (the pump stays on the quarters)
local GHOSTS = {{}, {}, {}, {16}, {16}, {11}, {8, 16}, {15}}
function G.kick(bar)
  bar = bar or BAR44
  local p = {ghost = {}}
  -- on every beat in even feel, on the group starts otherwise
  for i = 1, bar.n do p[i] = ((i - 1) % 4 == 0 and bar.starts[(i - 1) // 4 + 1]) and 1 or 0 end
  local g16 = {}
  for _, s in ipairs(pick(GHOSTS)) do g16[s] = 0.35 + math.random() * 0.2 end
  local flat = {}
  for i = 1, 16 do flat[i] = g16[i] or 0 end
  for i, v in ipairs(MT.map16(flat, bar)) do
    if v > 0 then p.ghost[i] = v end
  end
  return p
end

-- clap / snare / snap: a backbeat, a lone 4, or a backbeat with a ghost.
-- `kind` 1 clap 2 snare 3 snap; `late` nudges the hits behind the grid
local CLAPS = {{5, 13}, {5, 13}, {13}, {5, 13, 16}, {5, 13, 15}, {13, 14}, {5, 12}}
function G.clap(bar)
  bar = bar or BAR44
  local t = {kind = pick({1, 1, 1, 2, 3, 3}), late = pick({0, 0, 0.08, 0.15})}
  for i = 1, 16 do t[i] = 0 end
  for j, s in ipairs(pick(CLAPS)) do
    local main = s == 5 or s == 13
    t[s] = main and (0.85 + math.random() * 0.15) or (0.35 + math.random() * 0.2)
  end
  local p = lay(t, bar)
  -- even feel: today's patterns, mapped (3/4 takes beat 2 alone). a grouped
  -- feel claps on the last beat of each group longer than one beat.
  local beats
  if bar.feel ~= "even" then
    beats = {}
    local b = 1
    for _, len in ipairs(bar.groups) do
      if len > 1 then beats[#beats + 1] = b + len - 1 end
      b = b + len
    end
  elseif bar.beats == 3 then
    beats = {2}
  end
  if beats then
    for i = 1, bar.n do if p[i] >= 0.85 then p[i] = 0 end end   -- keep the soft ghosts
    for _, b in ipairs(beats) do p[(b - 1) * 4 + 1] = 0.85 + math.random() * 0.15 end
  end
  return p
end

-- percussion: a lane of its own odd length, so it phases against the bar
-- like the arps. entries are {vel, voice} (voice 1 low .. 3 high, tuned to
-- the chord); `kit` 1 hand 2 wood 3 metal
local PERC_LENS = {16, 12, 12, 10, 9, 7, 6, 14}
function G.perc()
  local len  = pick(PERC_LENS)
  local hits = G.euclid(math.max(2, math.floor(len * (0.3 + math.random() * 0.25))), len,
    math.random(0, len - 1))
  local p = {kit = pick({1, 1, 1, 2, 2, 3}), len = len, pos = 0, decay = 0.15 + math.random() * 0.2}
  for i = 1, len do
    if hits[i] then
      p[i] = {(i == 1) and 0.9 or (0.45 + math.random() * 0.4), pick({1, 2, 2, 3})}
    else
      p[i] = {0, 1}
    end
  end
  return p
end

-- ride: quarters, offbeats or 8ths with the offbeat leaning
local RIDES = {
  {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0},
  {0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0},
  {0.6, 0, 1, 0, 0.6, 0, 1, 0, 0.6, 0, 1, 0, 0.6, 0, 1, 0},
  {1, 0, 0.5, 0.4, 1, 0, 0.5, 0, 1, 0, 0.5, 0.4, 1, 0, 0.5, 0},
}
function G.ride(bar)
  bar = bar or BAR44
  local r = MT.map16(pick(RIDES), bar)
  local p = {}
  for i = 1, bar.n do p[i] = r[i] * (0.8 + math.random() * 0.2) end
  return p
end

-- glitch ticks: tiny digital hits on a euclidean scatter. entries are
-- {vel, kind (1 click 2 blip 3 crush 4 zap), ratchet (1-3 hits inside the 16th)}
function G.ticks(bar)
  bar = bar or BAR44
  local hits = G.euclid(pick({3, 4, 5, 5, 7}), bar.n, math.random(0, bar.n - 1))
  local kinds = pick({{1, 1, 2}, {1, 2, 2}, {1, 3}, {2, 4}, {1, 2, 3, 4}})
  local p = {}
  for i = 1, bar.n do
    if hits[i] then
      p[i] = {0.4 + math.random() * 0.5, pick(kinds), pick({1, 1, 1, 2, 3})}
    else
      p[i] = {0, 1, 1}
    end
  end
  return p
end

-- hat grooves. the offbeat spine is in all of them; what fills around it
-- changes. `open` = offbeats that open up when the energy builds,
-- `shuffle` = how late the off-16ths sit (fraction of a 16th)
G.HAT_KINDS = {"straight", "rolling", "skip", "sparse"}
local ROLL = {0.35, 0.2, 0.9, 0.28}   -- 16th contour inside a beat
function G.hats(bar)
  bar = bar or BAR44
  local kind = pick({1, 1, 2, 2, 3, 4})
  local p = {kind = kind, shuffle = pick({0, 0, 0.12, 0.2, 0.3})}
  p.open = lay_steps(pick({{}, {15}, {15}, {7, 15}, {3, 11}}), bar)
  local ghosts = kind == 3 and G.euclid(pick({3, 5}), bar.n, math.random(0, bar.n - 1))
  for i = 1, bar.n do
    local b = (i - 1) % 4 + 1
    if b == 3 then
      p[i] = 0.9
    elseif kind == 1 then
      p[i] = (math.random() < 0.5) and (0.25 + math.random() * 0.3) or 0
    elseif kind == 2 then
      p[i] = ROLL[b] * (0.85 + math.random() * 0.3)
    elseif kind == 3 then
      p[i] = ghosts[i] and (0.3 + math.random() * 0.25) or 0
    else
      p[i] = (i == bar.n and math.random() < 0.5) and 0.3 or 0
    end
  end
  return p
end

-- shaker: soft 16ths leaning on the offbeats; toms: one or two dub tom
-- ghosts a bar, left for the echo to answer. tom entries are {vel, voice}
-- (which chord voice it's tuned to, 1 low .. 4 high)
function G.shaker(bar)
  bar = bar or BAR44
  local p = {}
  local acc = pick({{0.25, 0.5, 0.8, 0.45}, {0.3, 0.3, 0.75, 0.3}, {0.5, 0.25, 0.7, 0.25}})
  for i = 1, bar.n do p[i] = acc[(i - 1) % 4 + 1] * (0.8 + math.random() * 0.4) end
  return p
end

local TOMS = {{8}, {14}, {7, 15}, {6, 14}, {11}, {4, 12}, {16}}
function G.toms(bar)
  bar = bar or BAR44
  local t = {}
  for i = 1, 16 do t[i] = {0, 1} end
  for _, s in ipairs(pick(TOMS)) do t[s] = {0.5 + math.random() * 0.4, math.random(1, 3)} end
  return lay(t, bar)
end

function G.rim(bar)
  bar = bar or BAR44
  local hits = G.euclid(pick({3, 3, 5, 7}), bar.n, math.random(0, bar.n - 1))
  local p = {}
  for i = 1, bar.n do p[i] = hits[i] and (0.5 + math.random() * 0.4) or 0 end
  return p
end

-- dub stab rhythms: sparse, off the beat, long gaps for the echo to fill
local STABS = {
  {3},          -- the classic single offbeat stab
  {3, 11},
  {4, 11},
  {3, 8, 14},
  {2, 7, 12},   -- euclid-ish 3 over 16
  {3, 6, 11, 14},
  {7},
  {3, 10},
}
function G.stabs(bar)
  bar = bar or BAR44
  local p = {}
  for i = 1, 16 do p[i] = 0 end
  for _, s in ipairs(pick(STABS)) do p[s] = 0.7 + math.random() * 0.3 end
  return lay(p, bar)
end

-- bass lines: 16 steps of {vel, semitone offset from the chord's bass,
-- glide in from the last note (bool)}. a track keeps one line per energy
-- band (calm / mid / high) and plays whichever the energy is in.
--   root    sparse offbeat roots, the odd fifth or octave
--   octave  offbeat 8ths bouncing root <-> octave
--   rolling syncopated 16ths with fifths and b7s
--   slide   few, long notes that glide into each other
G.BASS_KINDS = {"root", "octave", "rolling", "slide"}
local BASS_RHY = {
  {3, 7, 11, 15},          -- offbeat
  {1, 4, 7, 11, 14},
  {3, 6, 11, 14},
  {1, 7, 11},
  {3, 8, 11, 16},
}
local ROLL_RHY = {
  {3, 4, 7, 8, 11, 12, 15},
  {1, 3, 4, 6, 8, 11, 12, 14},
  {3, 4, 6, 7, 11, 12, 14, 15},
  {2, 3, 7, 10, 11, 15, 16},
}
local SLIDE_RHY = {{1, 7, 11}, {3, 11}, {1, 6, 11, 15}, {3, 9, 14}}
local function vel() return 0.7 + math.random() * 0.3 end
function G.bass(kind, bar)
  bar = bar or BAR44
  kind = kind or pick(G.BASS_KINDS)
  local p = {kind = kind}
  for i = 1, 16 do p[i] = {0, 0} end
  if kind == "octave" then
    local up = false
    for s = 3, 15, 4 do
      p[s] = {vel(), up and 12 or 0}
      if math.random() < 0.35 then p[s + 1] = {vel() * 0.7, up and 0 or 12} end
      up = not up
    end
    if math.random() < 0.5 then p[1] = {vel(), 0} end
  elseif kind == "rolling" then
    for _, s in ipairs(pick(ROLL_RHY)) do
      p[s] = {vel() * (s % 4 == 3 and 1 or 0.8), pick({0, 0, 0, 0, 7, 12, 10, 0})}
    end
  elseif kind == "slide" then
    local last
    for _, s in ipairs(pick(SLIDE_RHY)) do
      local iv = last and pick({0, 7, 10, 12, 5}) or 0
      p[s] = {vel(), iv, last ~= nil and iv ~= last and math.random() < 0.7}
      last = iv
    end
  else
    for _, s in ipairs(pick(BASS_RHY)) do
      local r = math.random()
      local iv = (r < 0.72) and 0 or (r < 0.84) and 7 or (r < 0.94) and 12 or 10
      p[s] = {vel(), iv}
    end
  end
  return lay(p, bar)
end

-- calm / mid / high lines for a track
function G.bass_lines(bar)
  return {G.bass(pick({"root", "root", "slide"}), bar),
          G.bass(pick({"octave", "slide", "root"}), bar),
          G.bass(pick({"rolling", "octave", "rolling"}), bar)}
end

------------------------------------------------------------------------
-- arp lanes: odd lengths so lanes phase against each other and the bar
------------------------------------------------------------------------

local LENS  = {3, 5, 5, 6, 7, 7, 9, 10, 11, 12, 13, 14}   -- <= 14: grid cols 15-16 are lane buttons
local DIVS  = {1, 1, 1, 2, 2, 3}       -- in 16ths (3 = dotted 8th)
local SHAPES = {"up", "down", "updown", "random", "pendulum"}

local function make_seq(len, shape)
  local seq = {}
  local span = math.random(4, 8)        -- chord-tone indices across 1-2 octaves
  for i = 1, len do
    local v
    if shape == "up" then
      v = ((i - 1) % span) + 1
    elseif shape == "down" then
      v = span - ((i - 1) % span)
    elseif shape == "updown" then
      local per = math.max(1, (span - 1) * 2)
      local k = (i - 1) % per
      v = (k < span) and (k + 1) or (per - k + 1)
    elseif shape == "pendulum" then
      v = (i % 2 == 1) and 1 or (((i // 2 - 1) % (span - 1)) + 2)
    else
      v = math.random(1, span)
    end
    seq[i] = v
  end
  -- a few rests keep it breathing
  for i = 2, len do
    if math.random() < 0.12 then seq[i] = 0 end
  end
  return seq
end

function G.lane(i)
  local len   = pick(LENS)
  local shape = pick(SHAPES)
  return {
    len    = len,
    div    = (i == 1) and 1 or pick(DIVS),
    shape  = shape,
    seq    = make_seq(len, shape),
    oct    = pick({0, 12, 12, 24}),
    pan    = ((i % 2 == 0) and 1 or -1) * (0.15 + math.random() * 0.6),
    decay  = 0.12 + math.random() * 0.35,
    cutoff = 900 + math.random() * 2600,
    shapeX = math.random(),
    lfo_bars  = pick({4, 8, 12, 16, 24}),
    lfo_phase = math.random() * math.pi * 2,
    prob   = 0.8 + math.random() * 0.2,
    voice  = pick({1, 1, 1, 2, 3, 4}),     -- classic, bell, pluck, soft
    pos    = 0,
    tick   = 0,
  }
end

-- small, audible-over-time changes; never a full regen
function G.mutate_lane(l)
  local r = math.random()
  if r < 0.3 then
    -- rotate
    local first = table.remove(l.seq, 1)
    table.insert(l.seq, first)
  elseif r < 0.55 then
    -- swap one note
    l.seq[math.random(l.len)] = math.random(0, 8)
  elseif r < 0.75 then
    -- grow / shrink by one step: shifts the phase relationship
    if l.len < 14 and (math.random() < 0.5 or l.len <= 3) then
      l.len = l.len + 1
      table.insert(l.seq, math.random(1, 6))
    else
      l.len = l.len - 1
      table.remove(l.seq)
    end
  elseif r < 0.9 then
    l.decay = math.max(0.08, math.min(0.6, l.decay * (0.7 + math.random() * 0.6)))
  else
    l.shape = pick(SHAPES)
    l.seq   = make_seq(l.len, l.shape)
  end
  if l.pos > l.len then l.pos = 0 end
end

-- chord-tone index -> midi, given current 4-note chord
function G.lane_note(l, chord, idx)
  local c = chord[((idx - 1) % 4) + 1]
  local n = c + 12 * ((idx - 1) // 4) + l.oct
  while n > 96 do n = n - 12 end
  return n
end

return G
