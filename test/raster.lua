-- a 128x64, 16-level stand-in for the norns screen, enough to see the
-- visuals: rect/fill, move/line/stroke, pixel, level. snap(path) writes a
-- 4x-scaled PGM. R.ops counts draw calls (rect, pixel, circle, line
-- segment) since the last R.reset_ops(); R.bad counts NaN / inf coordinates
-- or levels handed to it.
local R = {buf = {}, lv = 15, path = {}, rects = {}, pts = {}, ops = 0, bad = 0}

local function finite(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return false end
  end
  return true
end
local function check(...) if not finite(...) then R.bad = R.bad + 1 end end
function R.reset_ops() R.ops, R.bad = 0, 0 end

local function plot(x, y, l)
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  if x >= 0 and x < 128 and y >= 0 and y < 64 then R.buf[y * 128 + x] = l end
end

local function seg(x0, y0, x1, y1, l)
  local n = math.max(math.abs(x1 - x0), math.abs(y1 - y0), 1)
  -- a stroke centred on a pixel (x + 0.5, as the kit sends) lights that
  -- pixel, as cairo does with aa off: so floor, not round
  for i = 0, n do plot(x0 + (x1 - x0) * i / n - 0.5, y0 + (y1 - y0) * i / n - 0.5, l) end
end

local S = {}
function S.clear() R.buf = {} end
function S.level(l) check(l); R.lv = l end
function S.aa() end
function S.update() end
function S.line_width() end
function S.font_face() end
function S.font_size() end
function S.text() end
function S.text_right() end
function S.text_extents() return 20, 6 end
function S.rect(x, y, w, h) check(x, y, w or 0, h or 0); R.ops = R.ops + 1; R.rects[#R.rects + 1] = {x, y, w, h} end
function S.pixel(x, y) check(x, y); R.ops = R.ops + 1; R.pts[#R.pts + 1] = {x, y} end
function S.circle(x, y, r) check(x, y, r); R.ops = R.ops + 1; R.rects[#R.rects + 1] = {x - r, y - r, 2 * r, 2 * r} end
function S.move(x, y) check(x, y); R.path[#R.path + 1] = {{x, y}} end
function S.line(x, y)
  check(x, y); R.ops = R.ops + 1
  local p = R.path[#R.path]
  if not p then p = {{x, y}}; R.path[1] = p end
  p[#p + 1] = {x, y}
end
function S.fill()
  for _, r in ipairs(R.rects) do
    for yy = math.floor(r[2]), math.floor(r[2] + r[4]) - 1 do
      for xx = math.floor(r[1]), math.floor(r[1] + r[3]) - 1 do plot(xx, yy, R.lv) end
    end
  end
  for _, p in ipairs(R.pts) do plot(p[1], p[2], R.lv) end
  R.rects, R.pts, R.path = {}, {}, {}
end
function S.stroke()
  for _, p in ipairs(R.path) do
    for i = 2, #p do seg(p[i - 1][1], p[i - 1][2], p[i][1], p[i][2], R.lv) end
  end
  R.path = {}
end

function R.snap(file)
  local f = assert(io.open(file, "wb"))
  f:write("P5\n512 256\n255\n")
  local row = {}
  for y = 0, 63 do
    for x = 0, 127 do
      local v = string.char(math.floor((R.buf[y * 128 + x] or 0) / 15 * 255))
      for k = 1, 4 do row[x * 4 + k] = v end
    end
    local line = table.concat(row)
    for k = 1, 4 do f:write(line) end
  end
  f:close()
end

R.screen = S
return R
