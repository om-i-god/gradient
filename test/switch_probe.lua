-- which frames of the theme-switch run jump most: lua test/switch_probe.lua (from the repo root)
function include(p) return dofile(p .. ".lua") end
function test() end
dofile("test/unit_visuals.lua")
local H = VIS_HARNESS
local N = #H.NAMES
local st = H.run(1, "mid", {frames = 25 * (N + 1) + 25, switch_every = 25, keep = true})
local rows = {}
for f = 2, #st.frames do
  if f > 20 then
    local d = H.bufdiff(st.frames[f-1], st.frames[f])
    local th = (math.floor(f / 25)) % N + 1
    rows[#rows+1] = {f = f, d = d, th = H.NAMES[th], prevth = H.NAMES[(math.floor((f-1)/25)) % N + 1]}
  end
end
table.sort(rows, function(a, b) return a.d > b.d end)
for i = 1, 12 do local r = rows[i]; print(string.format("f%4d  %.3f  %s%s", r.f, r.d, r.th, r.th ~= r.prevth and (" (from " .. r.prevth .. ")") or "")) end
print("max", st.diff_max)
