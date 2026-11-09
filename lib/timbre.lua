-- timbre: which voice each part sounds in, when the SOUND params say "auto".
-- rolled with the track's material (S.timbre) and nudged now and then at a
-- phrase boundary. the dice are an LCG of our own, never math.random, so the
-- drum patterns and every other draw of a seed stay exactly where they were.

local TB = {}

local COUNT = {bass = 3, chord = 5, hat = 3, pad = 4}

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

local function weights(S, part)
  local n = COUNT[part]
  local w = base(n)
  local loud = S.section == "peak" or (S.energy or 0) > 0.7
  local soft = S.section == "breakdown" or S.kickless
  if loud then
    if part == "bass" then w = {1, 2, 2}
    elseif part == "hat" then w = {2, 2, 1} end
  elseif soft then
    if part == "chord" then w[2] = w[2] * 3
    elseif part == "hat" then w[3] = w[3] * 3
    elseif part == "pad" then w[2] = w[2] * 2; w[4] = w[4] * 2 end
  end
  return w
end

local function seed_of(S)
  local s = math.tointeger(S.seed) or math.floor(tonumber(S.seed) or 1)
  return (s ~ 0x5eed) & 0x7fffffff
end

-- new material: every part and lane gets a pick
function TB.roll(S)
  local st = {x = seed_of(S)}
  for _ = 1, 4 do next_u(st) end
  local t = {st = st, lane = {}}
  S.timbre = t
  for _, part in ipairs({"bass", "chord", "hat", "pad"}) do
    t[part] = pick_w(st, weights(S, part))
  end
  for i = 1, 4 do
    if next_u(st) < 0.35 then t.lane[i] = 5 + math.floor(next_u(st) * 4) end
  end
end

-- phrase boundary: at most one of bass, chord, hat moves, 30% of the time
function TB.phrase(S)
  if not S.timbre then TB.roll(S) end
  local t = S.timbre
  local st = t.st
  if next_u(st) >= 0.3 then return end
  local parts = {"bass", "chord", "hat"}
  local part = parts[1 + math.floor(next_u(st) * 3)]
  local w = weights(S, part)
  w[t[part]] = 0   -- a pick that actually moves
  t[part] = pick_w(st, w)
end

-- the engine's type for a part: param 1 = auto
function TB.resolve(S, part, value)
  if value > 1 then return value - 1 end
  return S.timbre and S.timbre[part] or 1
end

return TB
