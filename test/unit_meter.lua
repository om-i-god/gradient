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

if os.getenv("GEN_FIXTURE") then
  local f = assert(io.open("test/fixtures/patterns_44.lua", "w"))
  f:write("-- generated from the pre-meter generators (4/4 even); do not regenerate\nreturn {\n")
  for _, seed in ipairs(SNAP_SEEDS) do f:write(string.format("  [%d] = %q,\n", seed, snapshot(seed))) end
  f:write("}\n")
  f:close()
end

test("gen: 4/4 even patterns are identical to the pre-meter snapshot", function()
  local want = dofile("test/fixtures/patterns_44.lua")
  for _, seed in ipairs(SNAP_SEEDS) do
    assert(snapshot(seed) == want[seed], "seed " .. seed .. " drifted from the snapshot")
  end
end)
