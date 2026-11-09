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
