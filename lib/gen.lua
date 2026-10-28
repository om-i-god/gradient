-- gradient / gen
-- pattern generators: drums, stab rhythms, bass lines, phasing arp lanes.
-- 16-step tables are indexed 1..16; drum/stab entries are velocities (0 = rest).

local G = {}

local function pick(t) return t[math.random(#t)] end
G.pick = pick

function G.euclid(k, n, rot)
  local out = {}
  for i = 0, n - 1 do
    local j = (i + (rot or 0)) % n
    out[j + 1] = ((i * k) % n) < k
  end
  return out
end

function G.kick()
  local p = {}
  for i = 1, 16 do p[i] = ((i - 1) % 4 == 0) and 1 or 0 end
  return p
end

-- offbeat open-ish hats are the spine; 16th ghosts fill in by density
function G.hats()
  local p = {}
  for i = 1, 16 do
    if (i - 1) % 4 == 2 then
      p[i] = 0.9
    else
      p[i] = (math.random() < 0.5) and (0.25 + math.random() * 0.3) or 0
    end
  end
  return p
end

function G.rim()
  local hits = G.euclid(pick({3, 3, 5, 7}), 16, math.random(0, 15))
  local p = {}
  for i = 1, 16 do p[i] = hits[i] and (0.5 + math.random() * 0.4) or 0 end
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
function G.stabs()
  local p = {}
  for i = 1, 16 do p[i] = 0 end
  for _, s in ipairs(pick(STABS)) do p[s] = 0.7 + math.random() * 0.3 end
  return p
end

-- bass: {vel, semitone offset from chord root}
local BASS_RHY = {
  {3, 7, 11, 15},          -- offbeat
  {1, 4, 7, 11, 14},
  {3, 6, 11, 14},
  {1, 7, 11},
  {3, 8, 11, 16},
}
function G.bass()
  local p = {}
  for i = 1, 16 do p[i] = {0, 0} end
  for _, s in ipairs(pick(BASS_RHY)) do
    local r = math.random()
    local iv = (r < 0.72) and 0 or (r < 0.84) and 7 or (r < 0.94) and 12 or 10
    p[s] = {0.7 + math.random() * 0.3, iv}
  end
  return p
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
