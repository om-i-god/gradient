-- timbre: which voice each part sounds in, when the SOUND params say "auto".
-- rolled with the track's material (S.timbre) and nudged now and then at a
-- phrase boundary. the dice are an LCG of our own, never math.random, so the
-- drum patterns and every other draw of a seed stay exactly where they were.

local TB = {}

-- COUNT: every type the engine has. OLD: the types before round 3; a fresh
-- roll still draws over these, so a seed's first picks never moved
local COUNT = {bass = 5, chord = 7, hat = 4, pad = 6}
local OLD   = {bass = 3, chord = 5, hat = 3, pad = 4}

-- a small LCG (glibc constants); state lives in S.timbre so each track
-- carries its own stream
local function next_u(st)
  st.x = (st.x * 1103515245 + 12345) & 0x7fffffff
  return st.x / 2147483648
end

local function pick_w(st, w)
  local sum = 0
  for i = 1, #w do sum = sum + w[i] end
  local r = next_u(st) * sum
  for i = 1, #w do
    r = r - w[i]
    if r < 0 then return i end
  end
  return #w
end

-- today's type (1) about 40%, the rest even
local function base(n)
  local w = {0.4}
  for i = 2, n do w[i] = 0.6 / (n - 1) end
  return w
end

-- neutral = today's type at 40% (a fresh roll, which knows nothing of the
-- section); otherwise the section / energy shape an even spread
local function weights(S, part, neutral)
  local n = COUNT[part]
  if neutral then return base(OLD[part]) end
  local w = {}
  for i = 1, n do w[i] = 1 end
  local loud = S.section == "peak" or (S.energy or 0) > 0.7
  local soft = S.section == "breakdown" or S.kickless
  if loud then
    if part == "bass" then w = {1, 2, 2}
    elseif part == "hat" then w = {2, 2, 1} end
  elseif soft then
    if part == "chord" then w[2] = 3
    elseif part == "hat" then w[3] = 3
    elseif part == "pad" then w[2] = 2; w[4] = 2 end
  end
  for i = #w + 1, n do w[i] = 1 end   -- the round 3 types: an even share
  return w
end

local function seed_of(S)
  local s = math.tointeger(S.seed) or math.floor(tonumber(S.seed) or 1)
  return (s ~ 0x5eed) & 0x7fffffff
end

-- new material: every part and lane gets a pick. neutral weights, so a seed
-- always starts the same
function TB.roll(S)
  local st = {x = seed_of(S)}
  for _ = 1, 4 do next_u(st) end
  local t = {st = st, lane = {}}
  S.timbre = t
  for _, part in ipairs({"bass", "chord", "hat", "pad"}) do
    t[part] = pick_w(st, weights(S, part, true))
  end
  for i = 1, 4 do
    if next_u(st) < 0.35 then t.lane[i] = 5 + math.floor(next_u(st) * 4) end
  end
  -- the old picks, kept as the record of what the draws above gave
  t.old = {lane = {}}
  for _, part in ipairs({"bass", "chord", "hat", "pad"}) do t.old[part] = t[part] end
  for i = 1, 4 do t.old.lane[i] = t.lane[i] end
  -- appended draw, on a stream of its own so `st` (and every later draw)
  -- is exactly where it was: each part, p = 0.3, swaps to a round 3 type
  local s2 = {x = (seed_of(S) ~ 0x2c9d3a7) & 0x7fffffff}
  for _ = 1, 4 do next_u(s2) end
  for _, part in ipairs({"bass", "chord", "hat", "pad"}) do
    local swap = next_u(s2) < 0.3
    local pick = OLD[part] + 1 + math.floor(next_u(s2) * (COUNT[part] - OLD[part]))
    if swap then t[part] = pick end
  end
end

-- phrase boundary: one of bass, chord, hat moves (55%); the pad may follow a
-- new section (50%); a lane may change voice (15%)
function TB.phrase(S)
  if not S.timbre then TB.roll(S) end
  local t = S.timbre
  local st = t.st
  if next_u(st) < 0.55 then
    -- a shuffled bag, so the three parts take turns instead of one hogging
    if not t.bag or #t.bag == 0 then
      t.bag = {"bass", "chord", "hat"}
      for i = 3, 2, -1 do
        local j = 1 + math.floor(next_u(st) * i)
        t.bag[i], t.bag[j] = t.bag[j], t.bag[i]
      end
    end
    local part = table.remove(t.bag)
    local w = weights(S, part)
    w[t[part]] = 0   -- a pick that actually moves
    t[part] = pick_w(st, w)
  end
  if S.section ~= t.pad_sec and next_u(st) < 0.5 then
    local w = weights(S, "pad")
    w[t.pad] = 0
    t.pad = pick_w(st, w)
    t.pad_sec = S.section
  end
  if next_u(st) < 0.15 then
    local i = 1 + math.floor(next_u(st) * 4)
    local opts = {false, 5, 6, 7, 8, 9, 10}   -- false = the material's own voice
    local cur = t.lane[i] or false
    local w = {1, 1, 1, 1, 1, 1, 1}
    for k, o in ipairs(opts) do if o == cur then w[k] = 0 end end
    local o = opts[pick_w(st, w)]
    t.lane[i] = o or nil
  end
end

-- the engine's type for a part: param 1 = auto
function TB.resolve(S, part, value)
  if value > 1 then return value - 1 end
  return S.timbre and S.timbre[part] or 1
end

return TB
