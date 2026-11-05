-- contact sheet: every theme (rows) x silence / mid / peak / kickless
-- (columns), the last frame of a 6 s run each, 2x scale with a gap, as one
-- PGM. the OLED's levels are mapped with a slight lift so dim atmosphere
-- shows on a laptop screen as it does on the panel.
--   lua test/contact.lua out.pgm [theme,theme]   (from the repo root)
--   ffmpeg -y -i out.pgm out.png
function include(p) return dofile(p .. ".lua") end
dofile("test/unit_visuals.lua")
local H = VIS_HARNESS
local out = arg[1] or "contact.pgm"
local only = {}
if arg[2] then for n in arg[2]:gmatch("[^,]+") do only[n] = true end end
local themes = {}
for i, n in ipairs(H.NAMES) do if not arg[2] or only[n] then themes[#themes + 1] = i end end
local SC = {"silence", "mid", "peak", "kickless"}
local SCALE, GAP = 2, 4
local cw, ch = 128 * SCALE + GAP, 64 * SCALE + GAP
local W, Hh = #SC * cw + GAP, #themes * ch + GAP
local img = {}
for i = 0, W * Hh - 1 do img[i] = 40 end
for r, th in ipairs(themes) do
  for c, sc in ipairs(SC) do
    local st = H.run(th, sc, {frames = 120, keep = true})
    local fr = st.frames[#st.frames]
    for y = 0, 63 do for x = 0, 127 do
      local v = fr[y * 128 + x]
      local g = v > 0 and math.floor(30 + v / 15 * 225) or 0
      for dy = 0, SCALE - 1 do for dx = 0, SCALE - 1 do
        img[(GAP + (r - 1) * ch + y * SCALE + dy) * W + GAP + (c - 1) * cw + x * SCALE + dx] = g
      end end
    end end
  end
  io.stderr:write(H.NAMES[th], " ")
end
local f = assert(io.open(out, "wb"))
f:write(string.format("P5\n%d %d\n255\n", W, Hh))
local row = {}
for y = 0, Hh - 1 do
  for x = 0, W - 1 do row[x + 1] = string.char(img[y * W + x]) end
  f:write(table.concat(row))
end
f:close()
io.stderr:write("\n")
