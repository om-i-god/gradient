-- lib/meter: groupings, bar descriptor, 16-step template mapping
local MT = include("lib/meter")

local function eq(a, b, msg)
  assert(#a == #b, (msg or "") .. " length " .. #a .. " vs " .. #b)
  for i = 1, #a do assert(a[i] == b[i], (msg or "") .. " [" .. i .. "] " .. tostring(a[i]) .. " vs " .. tostring(b[i])) end
end

test("meter: METERS and FEELS", function()
  eq(MT.METERS, {4, 3, 5, 7})
  eq(MT.FEELS, {"even", "short-long", "long-short"})
end)

test("meter: groups for every meter x feel", function()
  local want = {
    [4] = {{1,1,1,1}, {2,2}, {3,1}},
    [3] = {{1,1,1},   {2,1}, {1,2}},
    [5] = {{1,1,1,1,1}, {3,2}, {2,3}},
    [7] = {{1,1,1,1,1,1,1}, {4,3}, {3,4}},
  }
  for beats, rows in pairs(want) do
    for f, g in ipairs(rows) do
      eq(MT.groups(beats, MT.FEELS[f]), g, beats .. "/" .. MT.FEELS[f])
    end
  end
end)

test("meter: bar descriptor", function()
  local b = MT.bar(5, "even")
  assert(b.n == 20 and b.beats == 5 and b.last == 20)
  for i = 1, 5 do assert(b.starts[i], "even: every beat starts") end
  local b7 = MT.bar(7, "short-long")
  assert(b7.n == 28)
  local ks = {}
  for k in pairs(b7.starts) do ks[#ks + 1] = k end
  table.sort(ks)
  eq(ks, {1, 5})
end)

test("meter: map16", function()
  local tpl = {}
  for i = 1, 16 do tpl[i] = i end
  eq(MT.map16(tpl, MT.bar(5, "even")), {1,2,3,4, 5,6,7,8, 9,10,11,12, 5,6,7,8, 13,14,15,16})
  eq(MT.map16(tpl, MT.bar(3, "even")), {1,2,3,4,5,6,7,8, 13,14,15,16})
  eq(MT.map16(tpl, MT.bar(4, "even")), tpl)
end)

test("meter: label", function()
  assert(MT.label(5, "long-short") == "5/4 2+3")
  assert(MT.label(4, "even") == "4/4")
  assert(MT.label(7, "short-long") == "7/4 4+3")
end)

------------------------------------------------------------------------
-- generators at the bar length
------------------------------------------------------------------------

local C = include("lib/conductor")
local G_ = include("lib/gen")

local function new_S()
  return {pat = {}, lanes = {}, gain = {}, jitter = {}, want = {}, mute = {}, solo = {},
          chord = {57, 60, 64, 67}, root_pc = 9, mode = 1, voicing = 1, harmony = 3,
          phrase_len = 32, bar = MT.bar(4, "even"), bar_step = 1}
end

-- deterministic serialiser (sorted keys, 14 significant digits)
local function ser(v)
  local t = type(v)
  if t == "number" then return string.format("%.14g", v) end
  if t ~= "table" then return tostring(v) end
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
  end)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = "[" .. ser(k) .. "]=" .. ser(v[k]) end
  return "{" .. table.concat(out, ",") .. "}"
end

local SNAP_KEYS = {"kick", "clap", "hats", "shaker", "rim", "toms", "ride", "ticks", "stabs", "perc", "bass_lines"}
local SNAP_SEEDS = {4218, 7, 99}

-- everything the 4/4 even track draws: the patterns, plus what is drawn
-- after them (lanes, pair, harmony length), so any extra draw shows up
local function snapshot(seed)
  local S = new_S()
  C.new_track(S, seed)
  local parts = {}
  for _, k in ipairs(SNAP_KEYS) do parts[#parts + 1] = k .. "=" .. ser(S.pat[k]) end
  parts[#parts + 1] = "lanes=" .. ser(S.lanes)
  parts[#parts + 1] = "pair=" .. ser(S.pair)
  parts[#parts + 1] = "harm_bars=" .. ser(S.harm_bars)
  parts[#parts + 1] = "cycle_bars=" .. ser(S.cycle_bars)
  return table.concat(parts, ";")
end

-- math.random differs between Lua 5.3 (norns) and 5.4, so each has a fixture
local FIXTURE = _VERSION == "Lua 5.3" and "test/fixtures/patterns_44_lua53.lua" or "test/fixtures/patterns_44.lua"

if os.getenv("GEN_FIXTURE") then
  local f = assert(io.open(FIXTURE, "w"))
  f:write("-- generated from the pre-meter generators (4/4 even); do not regenerate\nreturn {\n")
  for _, seed in ipairs(SNAP_SEEDS) do f:write(string.format("  [%d] = %q,\n", seed, snapshot(seed))) end
  f:write("}\n")
  f:close()
end

test("gen: 4/4 even patterns are identical to the pre-meter snapshot", function()
  local want = dofile(FIXTURE)
  for _, seed in ipairs(SNAP_SEEDS) do
    assert(snapshot(seed) == want[seed], "seed " .. seed .. " drifted from the snapshot")
  end
end)

local STEP_KEYS = {"kick", "clap", "hats", "shaker", "rim", "toms", "ride", "ticks", "stabs"}

local function check_lengths(S, label)
  local n = S.bar.n
  for _, k in ipairs(STEP_KEYS) do
    assert(#S.pat[k] == n, label .. " " .. k .. " has " .. #S.pat[k] .. " steps, want " .. n)
  end
  for i, l in ipairs(S.pat.bass_lines) do
    assert(#l == n, label .. " bass line " .. i .. " has " .. #l .. " steps, want " .. n)
  end
  for s in pairs(S.pat.kick.ghost) do assert(s >= 1 and s <= n, label .. " kick ghost off the bar") end
  for _, s in ipairs(S.pat.hats.open) do assert(s >= 1 and s <= n, label .. " hat open off the bar") end
end

local function in_meter(seed, beats, feel)
  local S = new_S()
  S.bar = MT.bar(beats, feel)
  C.new_track(S, seed)
  return S
end

test("gen: every pattern has bar.n steps in every meter and feel", function()
  for _, seed in ipairs({4218, 7, 99}) do
    for _, beats in ipairs(MT.METERS) do
      for _, feel in ipairs(MT.FEELS) do
        check_lengths(in_meter(seed, beats, feel), beats .. "/4 " .. feel)
      end
    end
  end
end)

test("gen: the kick lands on the beats the feel says", function()
  for _, beats in ipairs(MT.METERS) do
    for _, feel in ipairs(MT.FEELS) do
      local S = in_meter(4218, beats, feel)
      local bar = S.bar
      for i = 1, bar.n do
        local want = ((i - 1) % 4 == 0 and bar.starts[(i - 1) // 4 + 1]) and 1 or 0
        assert(S.pat.kick[i] == want, string.format("%d/4 %s kick[%d]", beats, feel, i))
      end
    end
  end
  -- 2+2 leans on beats 1 and 3, 3+2 on 1 and 4
  local k = in_meter(4218, 4, "short-long").pat.kick
  for i = 1, 16 do assert((k[i] == 1) == (i == 1 or i == 9)) end
  k = in_meter(4218, 5, "short-long").pat.kick
  for i = 1, 20 do assert((k[i] == 1) == (i == 1 or i == 13)) end
end)

test("gen: claps follow the groups", function()
  local function hits(S)
    local out = {}
    for i = 1, S.bar.n do if S.pat.clap[i] >= 0.85 then out[#out + 1] = i end end
    return out
  end
  eq(hits(in_meter(4218, 5, "short-long")), {9, 17})    -- 3+2: beats 3 and 5
  eq(hits(in_meter(4218, 5, "long-short")), {5, 17})    -- 2+3: beats 2 and 5
  eq(hits(in_meter(4218, 7, "short-long")), {13, 25})   -- 4+3: beats 4 and 7
  eq(hits(in_meter(4218, 5, "even")), {5, 13})          -- even: beats 2 and 4
  eq(hits(in_meter(4218, 7, "even")), {5, 13, 21})      -- even: beats 2, 4 and 6
  eq(hits(in_meter(7, 5, "even")), {5, 13})
  eq(hits(in_meter(4218, 3, "even")), {5})              -- 3/4 even: beat 2
  eq(hits(in_meter(4218, 3, "short-long")), {5})        -- 2+1: beat 2
  eq(hits(in_meter(4218, 3, "long-short")), {9})        -- 1+2: beat 3
  eq(hits(in_meter(4218, 4, "short-long")), {5, 13})
end)

test("gen: a generator at the default bar equals the 4/4 even bar", function()
  for _, g in ipairs({"kick", "clap", "hats", "shaker", "rim", "toms", "ride", "ticks", "stabs"}) do
    math.randomseed(5); local a = ser(G_[g]())
    math.randomseed(5); local b = ser(G_[g](MT.bar(4, "even")))
    assert(a == b, g)
  end
end)

test("remeter: bar-length patterns change; lanes, perc and harmony stay", function()
  for _, seed in ipairs({4218, 7}) do
    local S = new_S()
    C.new_track(S, seed)
    local lanes, perc, pair, hb = ser(S.lanes), ser(S.pat.perc), ser(S.pair), S.harm_bars
    local before = ser({S.pat.kick, S.pat.hats, S.pat.ride})
    S.bar = MT.bar(7, "short-long")
    C.remeter(S)
    check_lengths(S, "remeter 7/4")
    assert(ser(S.lanes) == lanes and ser(S.pat.perc) == perc and ser(S.pair) == pair and S.harm_bars == hb,
      "remeter touched lanes, perc or harmony")
    assert(ser({S.pat.kick, S.pat.hats, S.pat.ride}) ~= before, "remeter did not change the patterns")
    assert(S.pat.bass == S.pat.bass_lines[1], "bass is one of the lines")
    -- deterministic from the track seed and the meter
    local first = ser(S.pat)
    C.remeter(S)
    assert(ser(S.pat) == first, "remeter is not repeatable")
    -- the global stream resumes deterministically after it
    S.bar = MT.bar(7, "short-long")
    math.randomseed(11); C.remeter(S); local r1 = math.random()
    math.randomseed(11); C.remeter(S); assert(math.random() == r1, "stream after remeter not deterministic")
    -- and it follows the meter
    S.bar = MT.bar(5, "even")
    C.remeter(S)
    check_lengths(S, "remeter 5/4")
    assert(ser(S.lanes) == lanes and ser(S.pat.perc) == perc)
  end
end)
