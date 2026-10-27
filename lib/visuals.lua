-- gradient / visuals
-- four themes ported from causeway (field, tunnel, terrain, lattice).
-- drawing code is causeway's, verbatim apart from state living on this
-- module and audio_level read from VIS.audio_level.

local VIS = {}

VIS.audio_level = 0
VIS.names = {"terrain", "tunnel", "field", "lattice"}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local V = { columns = {}, tunnel_z = 0, tunnel_rot = 0 }
local terrain = { rows = {}, N = 10, S = 12 }
local lattice = { verts = {}, edges = {}, rx = 0, ry = 0, kick = 0, flash = 0 }

------------------------------------------------------------------------
-- field
------------------------------------------------------------------------

local function init_field()
  V.columns = {}
  local count = math.max(params:get("num_particles"), 16)
  local cw    = math.floor(128 / count)
  for i = 1, count do
    V.columns[i] = {
      x     = (i - 1) * cw,
      cw    = cw,
      h     = math.random(2, 18),
      phase = math.random() * math.pi * 2,
      speed = math.random() * 0.04 + 0.01,
      peak  = 2,
    }
  end
end

local function draw_field()
  local audio_level = VIS.audio_level
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.015
  for _, c in ipairs(V.columns) do
    c.phase = c.phase + c.speed + vis_spd
    local h = math.floor((c.h + math.sin(c.phase) * c.h * 0.6) * (1 + audio_level * 3.5))
    h = clamp(h, 1, 30)
    if h > c.peak then c.peak = h
    else c.peak = math.max(1, c.peak - 0.12) end
    local cw1 = math.max(1, c.cw - 1)
    local bri = clamp(math.floor((4 + audio_level * 10) * bri_scale), 0, 15)
    if bri > 0 then
      screen.level(bri)
      screen.rect(c.x, 32 - h, cw1, h)
      screen.fill()
      screen.rect(c.x, 32, cw1, h)
      screen.fill()
    end
    local pk_bri = clamp(math.floor((3 + audio_level * 6) * bri_scale), 0, 15)
    if pk_bri > 0 then
      local ph = math.floor(c.peak)
      screen.level(pk_bri)
      screen.rect(c.x, 32 - ph - 1, cw1, 1)
      screen.fill()
      screen.rect(c.x, 32 + ph, cw1, 1)
      screen.fill()
    end
  end
end

------------------------------------------------------------------------
-- tunnel
------------------------------------------------------------------------

local function init_tunnel()
  V.tunnel_z   = 0
  V.tunnel_rot = 0
end

local function tunnel_trigger()
  local audio_level = VIS.audio_level
  V.tunnel_z = V.tunnel_z + 0.18 + audio_level * 0.12
  if V.tunnel_z >= 1 then V.tunnel_z = V.tunnel_z - 1 end
end

local function draw_tunnel()
  local audio_level = VIS.audio_level
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.012
  V.tunnel_z   = V.tunnel_z   + vis_spd + audio_level * 0.035
  if V.tunnel_z >= 1 then V.tunnel_z = V.tunnel_z - 1 end
  V.tunnel_rot = V.tunnel_rot + vis_spd * 0.25 + audio_level * 0.007

  -- audio shifts vanishing point slightly
  local ox = 64 + math.sin(V.tunnel_rot * 0.7) * audio_level * 9
  local oy = 32 + math.cos(V.tunnel_rot * 0.5) * audio_level * 4

  local num_rings = 10
  for i = 1, num_rings do
    local t   = ((i / num_rings) + V.tunnel_z) % 1.0
    local s   = t * t
    local hw  = s * 63
    local hh  = s * 31
    local rot = V.tunnel_rot * (1 - s) * 0.5
    local cr  = math.cos(rot)
    local sr  = math.sin(rot)
    local bri = clamp(math.floor((s * 11 + audio_level * 7) * bri_scale), 0, 15)
    if bri > 0 and hw > 0 and hh > 0 then
      screen.level(bri)
      local corners = {{-hw,-hh},{hw,-hh},{hw,hh},{-hw,hh}}
      local fx = math.floor(ox + corners[1][1]*cr - corners[1][2]*sr)
      local fy = math.floor(oy + corners[1][1]*sr + corners[1][2]*cr)
      screen.move(fx, fy)
      for _, c in ipairs(corners) do
        screen.line(math.floor(ox + c[1]*cr - c[2]*sr), math.floor(oy + c[1]*sr + c[2]*cr))
      end
      screen.line(fx, fy)
      screen.stroke()
    end
  end

  local dot_bri = clamp(math.floor((3 + audio_level * 8) * bri_scale), 0, 15)
  if dot_bri > 0 then
    screen.level(dot_bri); screen.pixel(math.floor(ox), math.floor(oy)); screen.fill()
  end
end

------------------------------------------------------------------------
-- terrain
------------------------------------------------------------------------

function terrain.fresh_heights()
  local h = {}
  for i = 1, terrain.S do
    h[i] = math.random()
  end
  return h
end

function terrain.init()
  terrain.rows = {}
  for i = 1, terrain.N do
    terrain.rows[i] = {
      z       = (i - 1) / terrain.N,   -- evenly spaced 0 (horizon) .. 1 (foreground)
      heights = terrain.fresh_heights(),
    }
  end
end

function terrain.trigger()
  local audio_level = VIS.audio_level
  -- find horizon-most row (smallest z) and stamp a raised peak that rolls forward
  local lo, idx = 2, 1
  for i, r in ipairs(terrain.rows) do
    if r.z < lo then lo = r.z; idx = i end
  end
  local r = terrain.rows[idx]
  local center = math.random(2, terrain.S - 1)
  for i = 1, terrain.S do
    local d = i - center
    r.heights[i] = math.min(1, r.heights[i] + (1.0 + audio_level) * math.exp(-d * d * 0.5))
  end
end

function terrain.draw()
  local audio_level = VIS.audio_level
  local bri_scale = params:get("vis_brightness") / 15.0
  local spd       = params:get("vis_speed") * 0.012
  local y_h, y_f  = 20, 60          -- horizon and foreground screen rows

  for _, r in ipairs(terrain.rows) do
    r.z = r.z + spd
    if r.z >= 1 then
      r.z       = r.z - 1
      r.heights = terrain.fresh_heights()
    end
  end
  -- draw far-to-near so nearer (brighter) ridges overdraw distant ones
  table.sort(terrain.rows, function(a, b) return a.z < b.z end)

  for _, r in ipairs(terrain.rows) do
    local z      = r.z
    local persp  = z * z                       -- compress rows toward the horizon
    local row_y  = y_h + (y_f - y_h) * persp
    local half_w = 18 + 46 * z
    local amp    = (2 + audio_level * 14) * (0.25 + 0.75 * z)
    local bri    = clamp(math.floor((2 + 10 * z) * bri_scale), 0, 15)
    if bri > 0 then
      screen.level(bri)
      for i = 1, terrain.S do
        local t = (i - 1) / (terrain.S - 1)
        local x = 64 - half_w + t * half_w * 2
        local y = row_y - r.heights[i] * amp
        if i == 1 then screen.move(x, y) else screen.line(x, y) end
      end
      screen.stroke()
    end
  end
end

------------------------------------------------------------------------
-- lattice
------------------------------------------------------------------------

function lattice.init()
  local phi = (1 + math.sqrt(5)) / 2
  lattice.verts = {
    {0,  1,  phi}, {0,  1, -phi}, {0, -1,  phi}, {0, -1, -phi},
    {1,  phi, 0}, {1, -phi, 0}, {-1,  phi, 0}, {-1, -phi, 0},
    {phi, 0,  1}, {phi, 0, -1}, {-phi, 0,  1}, {-phi, 0, -1},
  }
  -- icosahedron edges = vertex pairs at the minimum (edge-length) distance, d^2 = 4
  lattice.edges = {}
  for i = 1, #lattice.verts do
    for j = i + 1, #lattice.verts do
      local a, b = lattice.verts[i], lattice.verts[j]
      local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
      if math.abs(dx * dx + dy * dy + dz * dz - 4) < 0.1 then
        table.insert(lattice.edges, {i, j})
      end
    end
  end
  lattice.rx, lattice.ry = 0, 0
  lattice.kick, lattice.flash = 0, 0
end

function lattice.trigger()
  local audio_level = VIS.audio_level
  lattice.kick  = math.min(0.5, lattice.kick + 0.15 + audio_level * 0.2)
  lattice.flash = math.min(8, lattice.flash + 4 + audio_level * 4)
end

function lattice.draw()
  local audio_level = VIS.audio_level
  local bri_scale = params:get("vis_brightness") / 15.0
  local spd       = params:get("vis_speed") * 0.04
  lattice.kick    = lattice.kick * 0.9
  lattice.flash   = lattice.flash * 0.85
  lattice.rx      = lattice.rx + spd + lattice.kick
  lattice.ry      = lattice.ry + spd * 0.6 + lattice.kick * 0.7

  local scale = (14 + audio_level * 9) * (1 + lattice.kick * 0.3)
  local cx, cy = 64, 32
  local cosx, sinx = math.cos(lattice.rx), math.sin(lattice.rx)
  local cosy, siny = math.cos(lattice.ry), math.sin(lattice.ry)

  local proj = {}
  for i, v in ipairs(lattice.verts) do
    local x, y, z = v[1], v[2], v[3]
    -- rotate about X then Y
    local y1 = y * cosx - z * sinx
    local z1 = y * sinx + z * cosx
    local x2 = x * cosy + z1 * siny
    local z2 = -x * siny + z1 * cosy
    local persp = 4 / (4 - z2)          -- viewer at +z; nearer vertices project larger
    proj[i] = {
      x = cx + x2 * scale * persp,
      y = cy + y1 * scale * persp,
      z = z2,
    }
  end

  for _, e in ipairs(lattice.edges) do
    local a, b  = proj[e[1]], proj[e[2]]
    local depth = (a.z + b.z) * 0.5
    local norm  = clamp((depth + 1.9) / 3.8, 0, 1)   -- nearer edges brighter
    local bri   = clamp(math.floor((3 + norm * 9 + lattice.flash) * bri_scale), 0, 15)
    if bri > 0 then
      screen.level(bri)
      screen.move(a.x, a.y)
      screen.line(b.x, b.y)
      screen.stroke()
    end
  end
end

------------------------------------------------------------------------
-- dispatch
------------------------------------------------------------------------

function VIS.init()
  terrain.init()
  init_tunnel()
  init_field()
  lattice.init()
end

function VIS.trigger(i)
  if     i == 1 then terrain.trigger()
  elseif i == 2 then tunnel_trigger()
  elseif i == 4 then lattice.trigger()
  end
end

function VIS.draw(i)
  if     i == 1 then terrain.draw()
  elseif i == 2 then draw_tunnel()
  elseif i == 3 then draw_field()
  elseif i == 4 then lattice.draw()
  end
end

return VIS
