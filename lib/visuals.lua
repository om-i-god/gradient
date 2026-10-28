-- gradient / visuals
-- all twenty causeway themes. the drawing code (state, helpers, themes) is
-- causeway's, verbatim (causeway.lua, v1.4); this file only adds the module
-- wrapper, `audio_level` / `time_val` as module state fed by the script,
-- and the dispatch. gradient's first four themes keep their slots so saved
-- psets still point at the same picture; the rest follow in causeway's order.

local VIS = {}

VIS.audio_level = 0

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local audio_level = 0      -- copied from VIS.audio_level before each draw / trigger
local time_val    = 0      -- advances 0.05 a frame, as in causeway's draw loop

-- V: single namespace for all per-theme animation state. Holds the state that
-- used to be ~30 separate top-level locals — collapsing them here keeps the main
-- chunk well under Lua's 200-local-per-chunk limit so new themes can be added.
local V = {}

V.rings      = {}
V.bands      = {}
V.columns    = {}
V.hex_nodes  = {}
local stars      = {}
V.rain_drops = {}
V.bounce_balls  = {}
V.grid_nodes    = {}
V.spiral_points = {}
V.wave_phase    = 0
V.wave_phase2   = 0
V.wave_shock    = 0
V.spiral_angle  = 0
V.liss_phase    = 0
V.liss_ratio_i  = 1
V.tunnel_z      = 0
V.grid_wave_t   = 0
V.nova_rings      = {}
V.splash_particles = {}
V.liss_history    = {}
V.spiral_dust     = {}
V.shatter_flashes = {}
V.code_highlight  = 1
V.code_boost      = 0
V.tunnel_rot      = 0
V.grid_wave2_t    = 0
V.grid_src2_x     = 20
V.grid_src2_y     = 10
V.morph_vphase    = {}

-- 3D-ish themes: each table holds the theme's state + its init/draw/trigger funcs.
local terrain = { rows = {}, N = 10, S = 12 }
local lattice = { verts = {}, edges = {}, rx = 0, ry = 0, kick = 0, flash = 0 }
local kaleido = { parts = {}, shards = {} }

V.LISS_RATIOS = {{1,2},{2,3},{3,4},{3,5},{4,5},{1,3},{2,5}}

------------------------------------------------------------------------
-- visual helpers
------------------------------------------------------------------------

local function draw_polygon(cx, cy, sides, radius, angle, bri)
  bri = clamp(bri, 0, 15)
  screen.level(bri)
  for i = 0, sides - 1 do
    local a1 = angle + (i / sides) * math.pi * 2
    local a2 = angle + ((i + 1) / sides) * math.pi * 2
    screen.move(cx + math.cos(a1) * radius, cy + math.sin(a1) * radius)
    screen.line(cx + math.cos(a2) * radius, cy + math.sin(a2) * radius)
    screen.stroke()
  end
end

------------------------------------------------------------------------
-- pulse theme
------------------------------------------------------------------------

local function init_pulse()
  V.rings = {}
end

local function pulse_trigger()
  -- burst of staggered rings from center
  local n = math.random(3, 6)
  for i = 1, n do
    if #V.rings < 40 then
      table.insert(V.rings, {cx = 64, cy = 32, radius = i * 2.5, bri = 12 + audio_level * 3, ry = 0.55})
    end
  end
  -- off-center echo rings
  for i = 1, math.random(1, 2) do
    if #V.rings < 40 then
      local ang = math.random() * math.pi * 2
      local d   = 10 + math.random(0, 28)
      table.insert(V.rings, {
        cx     = clamp(64 + math.cos(ang) * d, 8, 120),
        cy     = clamp(32 + math.sin(ang) * d * 0.5, 6, 58),
        radius = 3 + audio_level * 4,
        bri    = 7 + audio_level * 6,
        ry     = 0.4 + math.random() * 0.5,
      })
    end
  end
end

local function draw_pulse()
  local bri_scale = params:get("vis_brightness") / 15.0
  local spd = params:get("vis_speed") * 0.35
  for i = #V.rings, 1, -1 do
    local r = V.rings[i]
    r.radius = r.radius + spd
    r.bri    = r.bri - 0.2
    if r.bri <= 0 or r.radius > 90 then
      table.remove(V.rings, i)
    else
      local b = clamp(math.floor(r.bri * bri_scale), 0, 15)
      if b > 0 then
        screen.level(b)
        local steps = 28
        screen.move(r.cx + r.radius, r.cy)
        for j = 1, steps do
          local a = j / steps * math.pi * 2
          screen.line(r.cx + math.cos(a) * r.radius, r.cy + math.sin(a) * r.radius * r.ry)
        end
        screen.stroke()
      end
    end
  end
  local pb = clamp(math.floor((4 + audio_level * 11) * bri_scale), 0, 15)
  if pb > 0 then
    screen.level(pb)
    screen.circle(64, 32, 1 + audio_level * 8)
    screen.fill()
  end
  if audio_level > 0.25 then
    local ob = clamp(math.floor((1 + audio_level * 5) * bri_scale), 0, 15)
    if ob > 0 then
      screen.level(ob)
      screen.circle(64, 32, 4 + audio_level * 20)
      screen.stroke()
    end
  end
end

------------------------------------------------------------------------
-- drift theme
------------------------------------------------------------------------

local function init_drift()
  V.bands = {}
  local count = params:get("num_particles")
  for i = 1, count do
    V.bands[i] = {
      y     = math.random(0, 63),
      w     = math.random(12, 64),
      h     = math.random(1, 2),
      spd   = (math.random() * 0.3 + 0.05) * (math.random() < 0.5 and 1 or -1),
      bri   = math.random(2, 8),
      phase = math.random() * math.pi * 2,
    }
  end
end

local function draw_drift()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.005
  for _, b in ipairs(V.bands) do
    b.phase = b.phase + vis_spd + audio_level * 0.025
    -- gentle pull toward centre at high audio
    local pull = audio_level * 0.25
    if b.y < 32 then b.y = b.y + pull else b.y = b.y - pull end
    b.y = b.y + b.spd * (vis_spd * 8 + audio_level * 0.3)
    if b.y < -4 then b.y = 68 end
    if b.y >  68 then b.y = -4 end
    local brightness = b.bri + math.sin(b.phase) * 3 + audio_level * 10
    local bri = clamp(math.floor(brightness * bri_scale), 0, 15)
    local w   = math.floor(b.w * (1 + audio_level * 0.7))
    local h   = clamp(math.floor(b.h + audio_level * 4), 1, 6)
    local x   = math.floor((128 - w) / 2)
    local iy  = math.floor(b.y)
    if bri > 0 then
      screen.level(bri)
      screen.rect(x, iy - math.floor(h / 2), w, h)
      screen.fill()
      -- sparkle at brightness peak
      if brightness > 10 and math.random() < 0.2 then
        screen.level(clamp(bri + 3, 0, 15))
        screen.pixel(x + math.random(0, w - 1), iy)
        screen.fill()
      end
    end
  end
end

------------------------------------------------------------------------
-- field theme
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
-- hex theme
------------------------------------------------------------------------

local function init_hex()
  V.hex_nodes = {}
  local r = 11
  for row = 0, 5 do
    for col = 0, 8 do
      local x = col * r * 1.732 + (row % 2) * r * 0.866 - 16
      local y = row * r * 1.5 - 8
      if x >= -r and x <= 128 + r and y >= -r and y <= 64 + r then
        table.insert(V.hex_nodes, {
          x = x, y = y, r = r,
          bri   = math.random(1, 3),
          phase = math.random() * math.pi * 2,
          pulse = 0,
        })
      end
    end
  end
end

local function hex_trigger()
  local seeds = {}
  for i = 1, math.random(1, 3) do
    local ni = math.random(1, #V.hex_nodes)
    V.hex_nodes[ni].pulse = 13 + audio_level * 2
    table.insert(seeds, V.hex_nodes[ni])
  end
  -- propagate to hex neighbors
  for _, seed in ipairs(seeds) do
    for _, node in ipairs(V.hex_nodes) do
      local d = math.sqrt((node.x - seed.x)^2 + (node.y - seed.y)^2)
      if d > 2 and d < 26 then
        node.pulse = math.max(node.pulse, 7 + audio_level * 5)
      end
    end
  end
end

local function draw_hex()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.008
  -- connections between bright adjacent nodes
  if audio_level > 0.15 then
    for i = 1, #V.hex_nodes do
      local a  = V.hex_nodes[i]
      local ab = a.bri + math.sin(a.phase) * 1.5 + a.pulse + audio_level * 6
      if ab > 7 then
        for j = i + 1, #V.hex_nodes do
          local b = V.hex_nodes[j]
          local d2 = (a.x - b.x)^2 + (a.y - b.y)^2
          if d2 < 576 then  -- ~24px
            local bb = b.bri + math.sin(b.phase) * 1.5 + b.pulse + audio_level * 6
            if bb > 7 then
              local lb = clamp(math.floor(math.min(ab, bb) * 0.28 * bri_scale), 0, 15)
              if lb > 0 then
                screen.level(lb)
                screen.move(math.floor(a.x), math.floor(a.y))
                screen.line(math.floor(b.x), math.floor(b.y))
                screen.stroke()
              end
            end
          end
        end
      end
    end
  end
  for _, node in ipairs(V.hex_nodes) do
    node.phase = node.phase + vis_spd
    node.pulse = node.pulse * 0.88
    local bri = clamp(math.floor(
      (node.bri + math.sin(node.phase) * 1.5 + node.pulse + audio_level * 6) * bri_scale
    ), 0, 15)
    if bri > 0 then
      draw_polygon(node.x, node.y, 6, node.r * 0.82, node.phase, bri)
    end
  end
end

------------------------------------------------------------------------
-- stars theme  (warp-speed starfield with streak trails)
------------------------------------------------------------------------

local function init_stars()
  stars      = {}
  V.nova_rings = {}
  local count = params:get("num_particles")
  for i = 1, count do
    local angle = math.random() * math.pi * 2
    local speed = math.random() * 0.35 + 0.1
    local dist  = math.random(2, 55)
    local px    = 64 + math.cos(angle) * dist
    local py    = 32 + math.sin(angle) * dist * 0.5
    table.insert(stars, {
      x = px, y = py, px = px, py = py,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed * 0.5,
      bri = math.random(2, 8),
    })
  end
end

local function stars_trigger()
  for i = 1, math.random(4, 12) do
    local angle = math.random() * math.pi * 2
    local speed = 0.5 + audio_level * 2.0
    table.insert(stars, {
      x = 64, y = 32, px = 64, py = 32,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed * 0.5,
      bri = 11 + audio_level * 4,
    })
  end
  while #stars > 120 do table.remove(stars, 1) end
  if audio_level > 0.3 and math.random() < 0.45 and #stars > 0 then
    local s = stars[math.random(#stars)]
    table.insert(V.nova_rings, {x = s.x, y = s.y, r = 1.5, bri = 14})
    while #V.nova_rings > 8 do table.remove(V.nova_rings, 1) end
  end
end

local function draw_stars()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.3
  local warp      = 1.0 + audio_level * 3.5
  for _, s in ipairs(stars) do
    s.px = s.x; s.py = s.y
    local spd = vis_spd * warp
    s.x = s.x + s.vx * spd
    s.y = s.y + s.vy * spd
    if s.x < -4 or s.x > 132 or s.y < -4 or s.y > 68 then
      local angle = math.random() * math.pi * 2
      local speed = math.random() * 0.35 + 0.1
      s.x = 64; s.y = 32; s.px = 64; s.py = 32
      s.vx = math.cos(angle) * speed
      s.vy = math.sin(angle) * speed * 0.5
      s.bri = math.random(2, 8)
    end
    local dist = math.sqrt((s.x - 64)^2 + (s.y - 32)^2 * 4)
    local fade = math.min(1.0, dist / 18)
    local vel  = math.sqrt(s.vx^2 + s.vy^2) * warp
    local bri  = clamp(math.floor((s.bri * fade + vel * 2.0 + audio_level * 4) * bri_scale), 0, 15)
    if bri > 0 then
      screen.level(bri)
      local sx, sy = math.floor(s.x), math.floor(s.y)
      local ex, ey = math.floor(s.px), math.floor(s.py)
      if sx == ex and sy == ey then
        screen.pixel(sx, sy); screen.fill()
      else
        screen.move(ex, ey); screen.line(sx, sy); screen.stroke()
      end
    end
  end
  for i = #V.nova_rings, 1, -1 do
    local n = V.nova_rings[i]
    n.r   = n.r + vis_spd * warp * 1.8
    n.bri = n.bri - 0.55
    if n.bri <= 0 or n.r > 48 then
      table.remove(V.nova_rings, i)
    else
      local nb = clamp(math.floor(n.bri * bri_scale), 0, 15)
      if nb > 0 then
        screen.level(nb)
        screen.circle(math.floor(n.x), math.floor(n.y), math.floor(n.r))
        screen.stroke()
      end
    end
  end
end

------------------------------------------------------------------------
-- wave theme  (three interfering sine waves + note-triggered shock)
------------------------------------------------------------------------

local function init_wave()
  V.wave_phase  = 0
  V.wave_phase2 = math.pi * 0.7
  V.wave_shock  = 0
end

local function wave_trigger()
  V.wave_shock = math.min(1.0, V.wave_shock + 0.6 + audio_level * 0.8)
end

local function draw_wave()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.022
  V.wave_phase  = V.wave_phase  + vis_spd + audio_level * 0.055
  V.wave_phase2 = V.wave_phase2 + vis_spd * 1.37 + audio_level * 0.03
  V.wave_shock  = V.wave_shock  * 0.88

  local shock_amp = V.wave_shock * 14
  local amp   = 8 + audio_level * 18 + shock_amp
  local amp2  = (amp * 0.52) + shock_amp * 0.4
  local amp3  = amp * 0.28
  local freq  = 0.042 + audio_level * 0.028
  local freq2 = 0.071 + audio_level * 0.018
  local freq3 = 0.118

  -- fill envelope under primary wave
  local fill_bri = clamp(math.floor((1 + audio_level * 5 + V.wave_shock * 4) * bri_scale), 0, 15)
  if fill_bri > 0 then
    screen.level(fill_bri)
    for x = 0, 127, 2 do
      local wy = math.floor(32 + amp * math.sin(x * freq + V.wave_phase))
      local y1 = clamp(math.min(wy, 32), 0, 63)
      local y2 = clamp(math.max(wy, 32), 0, 63)
      if y2 > y1 then
        screen.move(x, y1); screen.line(x, y2); screen.stroke()
      end
    end
  end

  -- tertiary wave (faintest, fastest)
  local bri3 = clamp(math.floor((2 + audio_level * 4 + V.wave_shock * 5) * bri_scale), 0, 15)
  if bri3 > 0 then
    screen.level(bri3)
    screen.move(0, clamp(math.floor(32 + amp3 * math.sin(V.wave_phase * 1.6)), 0, 63))
    for x = 1, 127 do
      local y = math.floor(32 + amp3 * math.sin(x * freq3 + V.wave_phase * 1.6))
      screen.line(x, clamp(y, 0, 63))
    end
    screen.stroke()
  end

  -- secondary wave
  local bri2 = clamp(math.floor((4 + audio_level * 6 + V.wave_shock * 6) * bri_scale), 0, 15)
  if bri2 > 0 then
    screen.level(bri2)
    screen.move(0, clamp(math.floor(32 + amp2 * math.sin(V.wave_phase2)), 0, 63))
    for x = 1, 127 do
      local y = math.floor(32 + amp2 * math.sin(x * freq2 - V.wave_phase2))
      screen.line(x, clamp(y, 0, 63))
    end
    screen.stroke()
  end

  -- primary wave (brightest)
  local bri1 = clamp(math.floor((7 + audio_level * 8 + V.wave_shock * 8) * bri_scale), 0, 15)
  if bri1 > 0 then
    screen.level(bri1)
    screen.move(0, clamp(math.floor(32 + amp * math.sin(V.wave_phase)), 0, 63))
    for x = 1, 127 do
      local y = math.floor(32 + amp * math.sin(x * freq + V.wave_phase))
      screen.line(x, clamp(y, 0, 63))
    end
    screen.stroke()
  end
end

------------------------------------------------------------------------
-- rain theme  (streaking drops with wind drift + splashes)
------------------------------------------------------------------------

local function init_rain()
  V.rain_drops        = {}
  V.splash_particles  = {}
  local count = params:get("num_particles")
  for i = 1, count do
    local spd = math.random() * 1.2 + 0.4
    table.insert(V.rain_drops, {
      x   = math.random(0, 127),
      y   = math.random(0, 63),
      spd = spd,
      dx  = (math.random() - 0.5) * 0.4,
      len = math.random(2, 7),
      bri = math.random(3, 8),
    })
  end
end

local function rain_trigger()
  for i = 1, math.random(5, 14) do
    if #V.rain_drops < 110 then
      local spd = math.random() * 1.8 + 1.2 + audio_level * 2.5
      table.insert(V.rain_drops, {
        x   = math.random(0, 127),
        y   = -math.random(0, 12),
        spd = spd,
        dx  = (math.random() - 0.5) * 0.6,
        len = math.random(5, 18),
        bri = 9 + audio_level * 6,
      })
    end
  end
end

local function draw_rain()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.35
  local wind      = math.sin(time_val * 0.3) * audio_level * 0.8
  -- splash particles
  for i = #V.splash_particles, 1, -1 do
    local sp = V.splash_particles[i]
    sp.x   = sp.x + sp.vx
    sp.y   = sp.y + sp.vy
    sp.vy  = sp.vy + 0.15
    sp.bri = sp.bri - 0.55
    if sp.bri <= 0 or sp.y > 65 then
      table.remove(V.splash_particles, i)
    else
      local sb = clamp(math.floor(sp.bri * bri_scale), 0, 15)
      if sb > 0 then
        screen.level(sb)
        screen.pixel(math.floor(sp.x), clamp(math.floor(sp.y), 0, 63))
        screen.fill()
      end
    end
  end
  for i = #V.rain_drops, 1, -1 do
    local d = V.rain_drops[i]
    local fall = d.spd * (vis_spd + 0.5 + audio_level * 2.2)
    d.y = d.y + fall
    d.x = d.x + d.dx + wind
    if d.x < 0 then d.x = d.x + 128 end
    if d.x > 127 then d.x = d.x - 128 end
    if d.y > 64 + d.len then
      if #V.splash_particles < 60 then
        local nx = math.floor(d.x)
        for s = 1, math.random(2, 4) do
          local sang = math.pi + (math.random() - 0.5) * math.pi * 0.9
          local sv   = 0.6 + math.random() * 0.9 + audio_level * 0.8
          table.insert(V.splash_particles, {
            x = nx, y = 61,
            vx = math.cos(sang) * sv,
            vy = math.sin(sang) * sv - 0.4,
            bri = d.bri * 0.8,
          })
        end
      end
      d.x   = math.random(0, 127)
      d.y   = -d.len
      d.spd = math.random() * 1.2 + 0.4
      d.dx  = (math.random() - 0.5) * 0.4
      d.len = math.random(2, 7)
      d.bri = math.random(3, 8)
    else
      local bri = clamp(math.floor((d.bri + d.spd * 0.8 + audio_level * 5) * bri_scale), 0, 15)
      if bri > 0 then
        screen.level(bri)
        local ix  = math.floor(d.x)
        local iy  = clamp(math.floor(d.y), 0, 63)
        local iy2 = clamp(math.floor(d.y - d.len), 0, 63)
        screen.move(ix, iy2); screen.line(ix, iy); screen.stroke()
      end
    end
  end
end

------------------------------------------------------------------------
-- spiral theme  (galaxy arms drawn as connected line segments)
------------------------------------------------------------------------

local function init_spiral()
  V.spiral_angle  = 0
  V.spiral_points = {}
  V.spiral_dust   = {}
  local arms  = 4
  local count = math.max(params:get("num_particles"), 40)
  for arm_i = 1, arms do
    local arm_offset = (arm_i - 1) * math.pi * 2 / arms
    for j = 1, math.floor(count / arms) do
      local t = j / math.floor(count / arms) * math.pi * 3.5
      table.insert(V.spiral_points, {t = t, arm = arm_offset, arm_i = arm_i, bri = math.random(2, 6)})
    end
  end
  for i = 1, 22 do
    local t   = math.random() * math.pi * 3.5
    local ang = math.random() * math.pi * 2
    local r   = t * 5.0 + (math.random() - 0.5) * 7
    table.insert(V.spiral_dust, {r = r, ang = ang, drift = (math.random() - 0.5) * 0.002, bri = math.random(1, 3)})
  end
end

local function spiral_trigger()
  for _, p in ipairs(V.spiral_points) do
    p.bri = math.min(13, p.bri + audio_level * 10)
  end
end

local function draw_spiral()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.016
  V.spiral_angle = V.spiral_angle + vis_spd + audio_level * 0.04
  local scale  = 1 + audio_level * 0.55
  local arms   = 4

  -- dust particles
  for _, d in ipairs(V.spiral_dust) do
    d.ang = d.ang + vis_spd * 0.5 + d.drift
    local x = math.floor(64 + math.cos(d.ang) * d.r * scale)
    local y = math.floor(32 + math.sin(d.ang) * d.r * scale * 0.5)
    if x >= 0 and x <= 127 and y >= 0 and y <= 63 then
      local db = clamp(math.floor((d.bri + audio_level * 4) * bri_scale), 0, 15)
      if db > 0 then screen.level(db); screen.pixel(x, y); screen.fill() end
    end
  end

  for arm_i = 1, arms do
    local prev_x, prev_y, prev_bri
    for _, p in ipairs(V.spiral_points) do
      if p.arm_i == arm_i then
        p.bri = p.bri * 0.975 + math.random(1, 4) * 0.025
        local r     = p.t * 5.0 * scale
        local angle = p.t + p.arm + V.spiral_angle
        local x = math.floor(64 + math.cos(angle) * r)
        local y = math.floor(32 + math.sin(angle) * r * 0.5)
        local bri = clamp(math.floor((p.bri + audio_level * 7) * bri_scale), 0, 15)
        if prev_x and bri > 0 and prev_bri > 0
            and x >= 0 and x <= 127 and y >= 0 and y <= 63 then
          screen.level(math.max(bri, prev_bri))
          screen.move(prev_x, prev_y); screen.line(x, y); screen.stroke()
        end
        prev_x = x; prev_y = y; prev_bri = bri
      end
    end
  end

  local cglow = clamp(math.floor((3 + audio_level * 10) * bri_scale), 0, 15)
  if cglow > 0 then
    screen.level(cglow); screen.circle(64, 32, 1 + audio_level * 3); screen.fill()
  end
end

------------------------------------------------------------------------
-- lissajous theme  (harmonic oscilloscope curves, phase-morphing)
------------------------------------------------------------------------

local function init_lissajous()
  V.liss_phase   = 0
  V.liss_ratio_i = 1
  V.liss_history = {}
end

local function liss_trigger()
  V.liss_ratio_i = (V.liss_ratio_i % #V.LISS_RATIOS) + 1
end

local function draw_lissajous()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.007
  V.liss_phase = V.liss_phase + vis_spd + audio_level * 0.012

  local ratio = V.LISS_RATIOS[V.liss_ratio_i]
  local a, b  = ratio[1], ratio[2]
  local amp_x = 56 + audio_level * 8
  local amp_y = 26 + audio_level * 5
  local steps = 120

  -- build current curve
  local cur = {}
  for i = 0, steps do
    local t = i / steps * math.pi * 2
    cur[i + 1] = {
      x = math.floor(64 + amp_x * math.sin(a * t + V.liss_phase)),
      y = math.floor(32 + amp_y * math.sin(b * t)),
    }
  end

  -- ghost history traces
  for hi = 1, #V.liss_history do
    local fade    = 1.0 - hi / (#V.liss_history + 1)
    local ghost_b = clamp(math.floor((3 + audio_level * 3) * fade * bri_scale), 0, 15)
    if ghost_b > 0 then
      local pts = V.liss_history[hi]
      screen.level(ghost_b)
      screen.move(pts[1].x, pts[1].y)
      for j = 2, #pts do screen.line(pts[j].x, pts[j].y) end
      screen.stroke()
    end
  end

  -- echo offset by audio
  local bri2 = clamp(math.floor((2 + audio_level * 6) * bri_scale), 0, 15)
  if bri2 > 0 and audio_level > 0.08 then
    local ph2 = V.liss_phase + audio_level * 0.35
    screen.level(bri2)
    screen.move(math.floor(64 + amp_x * 0.65 * math.sin(a * 0 + ph2)),
                math.floor(32 + amp_y * 0.65 * math.sin(b * 0)))
    for i = 1, steps do
      local t = i / steps * math.pi * 2
      screen.line(math.floor(64 + amp_x * 0.65 * math.sin(a * t + ph2)),
                  math.floor(32 + amp_y * 0.65 * math.sin(b * t)))
    end
    screen.stroke()
  end

  -- primary trace
  local bri1 = clamp(math.floor((7 + audio_level * 8) * bri_scale), 0, 15)
  if bri1 > 0 then
    screen.level(bri1)
    screen.move(cur[1].x, cur[1].y)
    for j = 2, #cur do screen.line(cur[j].x, cur[j].y) end
    screen.stroke()
  end

  -- snapshot for history
  if math.floor(V.liss_phase * 6) % 4 == 0 then
    table.insert(V.liss_history, 1, cur)
    while #V.liss_history > 2 do table.remove(V.liss_history) end
  end
end

------------------------------------------------------------------------
-- tunnel theme  (zooming concentric rectangles, warp on note)
------------------------------------------------------------------------

local function init_tunnel()
  V.tunnel_z   = 0
  V.tunnel_rot = 0
end

local function tunnel_trigger()
  V.tunnel_z = V.tunnel_z + 0.18 + audio_level * 0.12
  if V.tunnel_z >= 1 then V.tunnel_z = V.tunnel_z - 1 end
end

local function draw_tunnel()
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
-- bounce theme  (physics balls with trails, audio boosts velocity)
------------------------------------------------------------------------

local function init_bounce()
  V.bounce_balls = {}
  local count = clamp(math.floor(params:get("num_particles") / 6), 2, 8)
  for i = 1, count do
    local angle = math.random() * math.pi * 2
    local speed = math.random() * 1.2 + 0.6
    table.insert(V.bounce_balls, {
      x     = math.random(6, 122),
      y     = math.random(6, 58),
      vx    = math.cos(angle) * speed,
      vy    = math.sin(angle) * speed * 0.7,
      r     = math.random(2, 4),
      bri   = math.random(6, 12),
      trail = {},
    })
  end
end

local function bounce_trigger()
  for _, b in ipairs(V.bounce_balls) do
    local boost = 1.5 + audio_level * 3.0
    b.vx = b.vx * boost
    b.vy = b.vy * boost
    local spd = math.sqrt(b.vx^2 + b.vy^2)
    if spd > 6 then b.vx = b.vx/spd*6; b.vy = b.vy/spd*6 end
    b.bri = math.min(15, b.bri + audio_level * 7)
  end
end

local function draw_bounce()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.28

  -- weak inter-ball attraction
  for i = 1, #V.bounce_balls do
    for j = i + 1, #V.bounce_balls do
      local bi, bj = V.bounce_balls[i], V.bounce_balls[j]
      local dx = bj.x - bi.x
      local dy = bj.y - bi.y
      local d2 = dx * dx + dy * dy
      if d2 > 4 and d2 < 3600 then
        local f = 0.00035
        bi.vx = bi.vx + dx * f; bi.vy = bi.vy + dy * f * 0.7
        bj.vx = bj.vx - dx * f; bj.vy = bj.vy - dy * f * 0.7
      end
    end
  end

  for _, b in ipairs(V.bounce_balls) do
    table.insert(b.trail, {x = b.x, y = b.y})
    while #b.trail > 10 do table.remove(b.trail, 1) end

    local sm = vis_spd + 0.35 + audio_level * 1.8
    b.x = b.x + b.vx * sm
    b.y = b.y + b.vy * sm

    if b.x - b.r < 0   then b.x = b.r;       b.vx =  math.abs(b.vx) end
    if b.x + b.r > 127  then b.x = 127 - b.r; b.vx = -math.abs(b.vx) end
    if b.y - b.r < 0   then b.y = b.r;       b.vy =  math.abs(b.vy) end
    if b.y + b.r > 63   then b.y = 63  - b.r; b.vy = -math.abs(b.vy) end

    b.vx = b.vx * 0.997; b.vy = b.vy * 0.997
    b.bri = b.bri * 0.97 + math.random(4, 8) * 0.03

    local spd_now = math.sqrt(b.vx^2 + b.vy^2)
    for j, t in ipairs(b.trail) do
      local fade = j / #b.trail
      local tbri = clamp(math.floor(b.bri * fade * (0.35 + spd_now * 0.05) * bri_scale), 0, 15)
      if tbri > 0 then
        screen.level(tbri); screen.pixel(math.floor(t.x), math.floor(t.y)); screen.fill()
      end
    end

    local r_vis = b.r + audio_level * 2 + spd_now * 0.12
    local bri   = clamp(math.floor((b.bri + audio_level * 5) * bri_scale), 0, 15)
    if bri > 0 then
      screen.level(bri); screen.circle(math.floor(b.x), math.floor(b.y), r_vis); screen.fill()
    end
  end
end

------------------------------------------------------------------------
-- grid theme  (ripple waves on dot grid, radiating from centre)
------------------------------------------------------------------------

local function init_grid()
  V.grid_nodes   = {}
  V.grid_wave_t  = 0
  V.grid_wave2_t = 0
  V.grid_src2_x  = 20
  V.grid_src2_y  = 10
  local cols, rows = 16, 8
  for row = 0, rows - 1 do
    for col = 0, cols - 1 do
      table.insert(V.grid_nodes, {
        x   = col * 8 + 4,
        y   = row * 8 + 4,
        bri = math.random(1, 3),
        col = col,
        row = row,
      })
    end
  end
end

local function grid_trigger()
  V.grid_wave_t  = V.grid_wave_t  + math.pi * 0.6 + audio_level * math.pi * 1.2
  V.grid_wave2_t = V.grid_wave2_t + math.pi * 0.4 + audio_level * math.pi * 0.9
end

local function draw_grid()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.035
  V.grid_wave_t  = V.grid_wave_t  + vis_spd + audio_level * 0.07
  V.grid_wave2_t = V.grid_wave2_t + vis_spd * 0.71 + audio_level * 0.05
  V.grid_src2_x  = 64 + math.sin(time_val * 0.4) * 44
  V.grid_src2_y  = 32 + math.cos(time_val * 0.3) * 22

  local brights = {}
  for idx, node in ipairs(V.grid_nodes) do
    local dx1  = (node.x - 64) / 58.0
    local dy1  = (node.y - 32) / 30.0
    local d1   = math.sqrt(dx1*dx1 + dy1*dy1) * 3.5
    local dx2  = (node.x - V.grid_src2_x) / 58.0
    local dy2  = (node.y - V.grid_src2_y) / 30.0
    local d2   = math.sqrt(dx2*dx2 + dy2*dy2) * 3.5
    local wave = math.sin(V.grid_wave_t  - d1) * 0.65
              + math.sin(V.grid_wave2_t - d2) * 0.35
    local raw  = node.bri + wave * 6 + audio_level * 9
    local bri  = clamp(math.floor(raw * bri_scale), 0, 15)
    brights[idx] = bri
    if bri > 0 then
      screen.level(bri)
      if wave > 0.4 or audio_level > 0.4 then
        screen.rect(node.x - 1, node.y - 1, 3, 3)
      else
        screen.rect(node.x, node.y, 2, 2)
      end
      screen.fill()
    end
  end

  -- connections between bright horizontal neighbors
  if audio_level > 0.15 then
    for idx, node in ipairs(V.grid_nodes) do
      if brights[idx] and brights[idx] > 5 and node.col < 15 then
        local ridx = idx + 1
        if brights[ridx] and brights[ridx] > 5 then
          local cb = clamp(math.floor(math.min(brights[idx], brights[ridx]) * 0.38), 0, 15)
          if cb > 0 then
            screen.level(cb)
            screen.move(node.x + 2, node.y + 1)
            screen.line(V.grid_nodes[ridx].x, V.grid_nodes[ridx].y + 1)
            screen.stroke()
          end
        end
      end
    end
  end
end

------------------------------------------------------------------------
-- flow theme  (curl-noise vector field particles)
------------------------------------------------------------------------

V.flow_particles = {}

local function init_flow()
  V.flow_particles = {}
  local count = params:get("num_particles")
  for i = 1, count do
    table.insert(V.flow_particles, {
      x     = math.random(0, 127),
      y     = math.random(0, 63),
      bri   = math.random(3, 9),
      age   = math.random(0, 80),
      trail = {},
    })
  end
end

local function flow_trigger()
  for i = 1, math.random(6, 14) do
    if #V.flow_particles < 120 then
      table.insert(V.flow_particles, {
        x     = math.random(0, 127),
        y     = math.random(0, 63),
        bri   = 11 + audio_level * 4,
        age   = 0,
        trail = {},
      })
    end
  end
end

local function draw_flow()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.18
  local t         = time_val
  local ax1 = math.sin(t * 0.31) * math.pi
  local ax2 = math.cos(t * 0.19) * math.pi
  for _, p in ipairs(V.flow_particles) do
    table.insert(p.trail, {x = p.x, y = p.y})
    while #p.trail > 5 do table.remove(p.trail, 1) end
    local nx  = p.x / 38.0
    local ny  = p.y / 19.0
    local ang = math.sin(nx + t * 0.7 + ax1) * math.cos(ny * 1.3 - t * 0.5) * math.pi * 2
             + math.sin(nx * 0.6 - ny + t * 0.4 + ax2) * math.pi
             + math.cos(nx * 1.1 + ny * 0.8 - t * 0.3) * 0.5
    local spd = vis_spd + audio_level * 1.6
    p.x   = p.x + math.cos(ang) * spd
    p.y   = p.y + math.sin(ang) * spd * 0.6
    p.age = p.age + 1
    if p.x < 0 or p.x > 127 or p.y < 0 or p.y > 63 or p.age > 110 then
      p.x   = math.random(0, 127)
      p.y   = math.random(0, 63)
      p.bri = math.random(3, 9)
      p.age = 0
      p.trail = {}
    else
      local fade = 1.0 - p.age / 110.0
      for j = 2, #p.trail do
        local tf  = (j - 1) / #p.trail
        local bri = clamp(math.floor((p.bri * fade * tf * 0.65 + audio_level * 4) * bri_scale), 0, 15)
        if bri > 0 then
          screen.level(bri)
          screen.move(math.floor(p.trail[j-1].x), math.floor(p.trail[j-1].y))
          screen.line(math.floor(p.trail[j].x),   math.floor(p.trail[j].y))
          screen.stroke()
        end
      end
      if #p.trail > 0 then
        local hbri = clamp(math.floor((p.bri * fade + audio_level * 7) * bri_scale), 0, 15)
        if hbri > 0 then
          local last = p.trail[#p.trail]
          screen.level(hbri)
          screen.move(math.floor(last.x), math.floor(last.y))
          screen.line(math.floor(p.x), math.floor(p.y))
          screen.stroke()
        end
      end
    end
  end
end

------------------------------------------------------------------------
-- morph theme  (polygon morphing between shapes)
------------------------------------------------------------------------

local morph_t      = 0
local morph_sides  = {3, 4, 5, 6, 8, 12}
local morph_from_i = 1
local morph_to_i   = 2
local morph_phase  = 0

local function init_morph()
  morph_phase  = 0
  morph_t      = 0
  morph_from_i = 1
  morph_to_i   = 2
  V.morph_vphase = {}
  for i = 1, 16 do V.morph_vphase[i] = math.random() * math.pi * 2 end
end

local function morph_trigger()
  morph_from_i = morph_to_i
  morph_to_i   = (morph_to_i % #morph_sides) + 1
  morph_t      = 0
  for i = 1, 16 do
    V.morph_vphase[i] = V.morph_vphase[i] + (math.random() - 0.5) * math.pi * 1.5
  end
end

local function draw_morph()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.007
  morph_phase = morph_phase + vis_spd + audio_level * 0.012
  morph_t     = math.min(1.0, morph_t + vis_spd * 0.4 + audio_level * 0.006)
  if morph_t >= 1.0 then
    morph_from_i = morph_to_i
    morph_to_i   = (morph_to_i % #morph_sides) + 1
    morph_t      = 0
  end
  if V.morph_vphase then
    for i = 1, 16 do
      V.morph_vphase[i] = V.morph_vphase[i] + vis_spd * 0.4 + audio_level * 0.005
    end
  end

  local t3 = morph_t * morph_t * (3 - 2 * morph_t)
  local sa = morph_sides[morph_from_i]
  local sb = morph_sides[morph_to_i]
  local cx, cy = 64, 32

  for layer = 1, 4 do
    local base_r  = 7 + layer * 6
    local noise_a = (1 + audio_level * 5) * (layer * 0.5 + 0.4)
    local rot_dir = (layer % 2 == 0) and 1 or -1
    local bri = clamp(math.floor((1 + (5 - layer) * 2.5 + audio_level * 9) * bri_scale), 0, 15)
    if bri > 0 then
      screen.level(bri)
      local steps = 48
      local first_x, first_y
      for i = 0, steps do
        local frac   = i / steps
        local snap_a = math.floor(sa * frac + 0.5) / sa * math.pi * 2
        local snap_b = math.floor(sb * frac + 0.5) / sb * math.pi * 2
        local ang    = snap_a + (snap_b - snap_a) * t3 + morph_phase * rot_dir
        local vi1    = math.floor(frac * 7) + 1
        local vi2    = (vi1 % 8) + 1
        local noise  = 0
        if V.morph_vphase then
          noise = math.sin(V.morph_vphase[vi1] + frac * math.pi * 4) * noise_a
                + math.sin(V.morph_vphase[vi2] - frac * math.pi * 3) * noise_a * 0.45
        end
        local r = base_r + noise
        local x = math.floor(cx + math.cos(ang) * r)
        local y = math.floor(cy + math.sin(ang) * r * 0.68)
        if i == 0 then
          screen.move(x, y); first_x, first_y = x, y
        else
          screen.line(x, y)
        end
      end
      screen.stroke()
    end
  end
end

------------------------------------------------------------------------
-- shatter theme  (crack lines that spawn on notes and slowly heal)
------------------------------------------------------------------------

V.shatter_cracks = {}

local function init_shatter()
  V.shatter_cracks  = {}
  V.shatter_flashes = {}
end

local function shatter_trigger()
  local ox  = math.random(20, 108)
  local oy  = math.random(10, 54)
  table.insert(V.shatter_flashes, {x = ox, y = oy, r = 2 + audio_level * 3, bri = 15})
  local num = math.random(5, 9) + math.floor(audio_level * 6)
  for i = 1, num do
    local ang  = math.random() * math.pi * 2
    local len  = math.random(10, 34) * (1 + audio_level)
    local segs = math.random(2, 5)
    local points = {{x = ox, y = oy}}
    local cx, cy = ox, oy
    for s = 1, segs do
      ang = ang + (math.random() - 0.5) * 0.7
      local dl = len / segs
      cx = cx + math.cos(ang) * dl
      cy = cy + math.sin(ang) * dl * 0.6
      table.insert(points, {x = clamp(cx, 0, 127), y = clamp(cy, 0, 63)})
    end
    table.insert(V.shatter_cracks, {points = points, bri = 12 + audio_level * 3})
    -- branch crack
    if math.random() < 0.45 and #V.shatter_cracks < 65 and #points >= 2 then
      local bi   = math.random(2, #points)
      local bang = ang + (math.random() < 0.5 and 1 or -1) * (0.4 + math.random() * 0.5)
      local blen = len * (0.3 + math.random() * 0.4)
      local bpts = {{x = points[bi].x, y = points[bi].y}}
      local bx, by = points[bi].x, points[bi].y
      for s = 1, math.random(1, 3) do
        bang = bang + (math.random() - 0.5) * 0.4
        local dl = blen / 2
        bx = bx + math.cos(bang) * dl; by = by + math.sin(bang) * dl * 0.6
        table.insert(bpts, {x = clamp(bx,0,127), y = clamp(by,0,63)})
      end
      table.insert(V.shatter_cracks, {points = bpts, bri = 9 + audio_level * 3})
    end
  end
  while #V.shatter_cracks > 70 do table.remove(V.shatter_cracks, 1) end
end

local function draw_shatter()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.004
  for i = #V.shatter_flashes, 1, -1 do
    local f = V.shatter_flashes[i]
    f.bri = f.bri - 1.4; f.r = f.r + 0.9
    if f.bri <= 0 then
      table.remove(V.shatter_flashes, i)
    else
      local fb = clamp(math.floor(f.bri * bri_scale), 0, 15)
      if fb > 0 then
        screen.level(fb); screen.circle(math.floor(f.x), math.floor(f.y), math.floor(f.r)); screen.fill()
      end
    end
  end
  for i = #V.shatter_cracks, 1, -1 do
    local c = V.shatter_cracks[i]
    c.bri = c.bri - 0.05 - vis_spd * 2
    if c.bri <= 0 then
      table.remove(V.shatter_cracks, i)
    else
      local bri = clamp(math.floor((c.bri + audio_level * 4) * bri_scale), 0, 15)
      if bri > 0 and #c.points >= 2 then
        screen.level(bri)
        screen.move(math.floor(c.points[1].x), math.floor(c.points[1].y))
        for j = 2, #c.points do
          screen.line(math.floor(c.points[j].x), math.floor(c.points[j].y))
        end
        screen.stroke()
      end
    end
  end
end

------------------------------------------------------------------------
-- code theme  (matrix-style falling character columns)
------------------------------------------------------------------------

V.code_cols  = {}
local CODE_CHARS = {"|","/","\\","-","_",":",".","#","*","+","=","~"}

local function init_code()
  V.code_cols      = {}
  V.code_highlight = 1
  V.code_boost     = 0
  local n = 21
  for i = 0, n - 1 do
    table.insert(V.code_cols, {
      x    = i * 6 + 2,
      y    = math.random(-64, 0),
      spd  = math.random() * 0.8 + 0.4,
      len  = math.random(4, 14),
      bri  = math.random(4, 9),
      char = CODE_CHARS[math.random(#CODE_CHARS)],
      tick = 0,
    })
  end
end

local function code_trigger()
  V.code_boost     = 3.0 + audio_level * 4.0
  V.code_highlight = (V.code_highlight % #V.code_cols) + 1
  V.code_cols[V.code_highlight].bri = 14 + audio_level
end

local function draw_code()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.4
  V.code_boost      = V.code_boost * 0.88
  for ci, c in ipairs(V.code_cols) do
    local is_hot = (ci == V.code_highlight)
    c.tick = c.tick + 1
    local fall = c.spd * (vis_spd + 0.5 + audio_level * 2.0 + V.code_boost)
    c.y = c.y + fall
    local char_rate = math.max(1, math.floor((is_hot and 2 or 7) - audio_level * 4))
    if c.tick % char_rate == 0 then c.char = CODE_CHARS[math.random(#CODE_CHARS)] end
    if c.y > 64 + c.len * 6 then
      c.y   = -c.len * 6 - math.random(0, 40)
      c.spd = math.random() * 0.8 + 0.4
      c.len = math.random(4, 14)
      c.bri = is_hot and (10 + math.random(4)) or math.random(4, 9)
    end
    for j = 0, c.len do
      local ty = math.floor(c.y - j * 6)
      if ty >= 0 and ty <= 63 then
        local b
        if j == 0 then
          local hb = is_hot and (c.bri + 5 + audio_level * 4) or (c.bri + audio_level * 6)
          b = clamp(math.floor(hb * bri_scale), 0, 15)
        else
          local fade = 1.0 - j / c.len
          b = clamp(math.floor(c.bri * fade * (is_hot and 0.75 or 0.55) * bri_scale), 0, 15)
        end
        if b > 0 then
          screen.level(b)
          screen.move(c.x, ty)
          screen.text(j == 0 and c.char or CODE_CHARS[math.random(#CODE_CHARS)])
        end
      end
    end
    c.bri = c.bri * 0.985 + math.random(4, 8) * 0.015
  end
end

------------------------------------------------------------------------
-- orbit theme  (planets orbiting a star, audio perturbs orbits)
------------------------------------------------------------------------

local orbit_bodies  = {}
local orbit_perturb = 0

local function init_orbit()
  orbit_bodies  = {}
  orbit_perturb = 0
  local radii = {10, 18, 27, 38, 50}
  local sizes = {3, 2, 3, 2, 2}
  for i, rad in ipairs(radii) do
    local angle = math.random() * math.pi * 2
    local spd   = (0.018 + math.random() * 0.012) * (i % 2 == 0 and -1 or 1)
    table.insert(orbit_bodies, {
      angle  = angle,
      radius = rad,
      base_r = rad,
      spd    = spd,
      size   = sizes[i],
      bri    = math.random(6, 12),
      trail  = {},
    })
  end
end

local function orbit_trigger()
  orbit_perturb = math.min(1.2, orbit_perturb + 0.6 + audio_level * 0.8)
  for _, b in ipairs(orbit_bodies) do
    b.bri = math.min(15, b.bri + audio_level * 7)
  end
end

local function draw_orbit()
  local bri_scale = params:get("vis_brightness") / 15.0
  local vis_spd   = params:get("vis_speed") * 0.5
  orbit_perturb   = orbit_perturb * 0.93

  -- faint orbital path ellipses
  local path_bri = clamp(math.floor((1 + audio_level * 2) * bri_scale), 0, 15)
  if path_bri > 0 then
    for _, b in ipairs(orbit_bodies) do
      screen.level(path_bri)
      screen.move(64 + b.base_r, 32)
      for j = 1, 32 do
        local a = j / 32 * math.pi * 2
        screen.line(64 + math.cos(a) * b.base_r, 32 + math.sin(a) * b.base_r * 0.55)
      end
      screen.stroke()
    end
  end

  -- star + corona
  local star_bri = clamp(math.floor((6 + audio_level * 9) * bri_scale), 0, 15)
  if star_bri > 0 then
    screen.level(star_bri); screen.circle(64, 32, 2 + audio_level * 2); screen.fill()
    local corona = clamp(math.floor((2 + audio_level * 5) * bri_scale), 0, 15)
    if corona > 0 then screen.level(corona); screen.circle(64, 32, 4 + audio_level * 4); screen.stroke() end
  end

  for _, b in ipairs(orbit_bodies) do
    b.angle  = b.angle + b.spd * (vis_spd + 1.0 + audio_level * 2.0)
    b.radius = b.base_r + orbit_perturb * math.sin(b.angle * 3) * 7 + audio_level * 5

    local x = 64 + math.cos(b.angle) * b.radius
    local y = 32 + math.sin(b.angle) * b.radius * 0.55

    table.insert(b.trail, {x = x, y = y})
    while #b.trail > 20 do table.remove(b.trail, 1) end

    for j, pt in ipairs(b.trail) do
      local fade = j / #b.trail
      local tbri = clamp(math.floor(b.bri * fade * 0.45 * bri_scale), 0, 15)
      if tbri > 0 then
        screen.level(tbri); screen.pixel(math.floor(pt.x), math.floor(pt.y)); screen.fill()
      end
    end

    b.bri = b.bri * 0.97 + math.random(5, 10) * 0.03
    local pb = clamp(math.floor((b.bri + audio_level * 6) * bri_scale), 0, 15)
    if pb > 0 then
      screen.level(pb); screen.circle(math.floor(x), math.floor(y), b.size); screen.fill()
    end
  end
end

------------------------------------------------------------------------
-- terrain theme
------------------------------------------------------------------------

-- new themes attach their functions as table fields (not top-level locals) to
-- stay under Lua's 200-local-per-chunk limit.

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
-- lattice theme
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
  lattice.kick  = math.min(0.5, lattice.kick + 0.15 + audio_level * 0.2)
  lattice.flash = math.min(8, lattice.flash + 4 + audio_level * 4)
end

function lattice.draw()
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
-- kaleido theme
------------------------------------------------------------------------

function kaleido.init()
  kaleido.parts  = {}
  kaleido.shards = {}
  local count = params:get("num_particles")
  for i = 1, count do
    kaleido.parts[i] = {
      r   = math.random() * 30,
      a   = math.random() * (math.pi / 3),   -- angle within one 60-degree wedge
      dr  = 0.15 + math.random() * 0.4,
      da  = (math.random() - 0.5) * 0.04,
      bri = math.random(4, 11),
    }
  end
end

function kaleido.trigger()
  table.insert(kaleido.shards, {
    r   = 0,
    a   = math.random() * (math.pi / 3),
    spd = 1.2 + audio_level * 1.5,
    bri = 13 + audio_level * 2,
  })
  if #kaleido.shards > 12 then table.remove(kaleido.shards, 1) end
end

function kaleido.draw()
  local bri_scale = params:get("vis_brightness") / 15.0
  local spd       = params:get("vis_speed") * 0.5
  local cx, cy    = 64, 32
  local bloom     = 1 + audio_level * 0.8
  local max_r     = 40

  -- plot one wedge point into all six rotations plus their mirrors (6-fold mandala)
  local function plot(r, a, bri)
    if bri <= 0 then return end
    local rr = r * bloom
    screen.level(bri)
    for k = 0, 5 do
      local base = k * (math.pi / 3)
      local a1   = base + a
      local a2   = base - a
      screen.pixel(math.floor(cx + math.cos(a1) * rr), math.floor(cy + math.sin(a1) * rr * 0.62))
      screen.pixel(math.floor(cx + math.cos(a2) * rr), math.floor(cy + math.sin(a2) * rr * 0.62))
    end
    screen.fill()
  end

  for _, p in ipairs(kaleido.parts) do
    p.r = p.r + p.dr * (spd + audio_level * 1.5)
    p.a = p.a + p.da
    if p.a < 0          then p.a = p.a + math.pi / 3 end
    if p.a > math.pi / 3 then p.a = p.a - math.pi / 3 end
    if p.r > max_r then
      p.r   = math.random() * 4
      p.bri = math.random(4, 11)
    end
    plot(p.r, p.a, clamp(math.floor((p.bri + audio_level * 5) * bri_scale), 0, 15))
  end

  for i = #kaleido.shards, 1, -1 do
    local s = kaleido.shards[i]
    s.r   = s.r + s.spd * (spd + 1)
    s.bri = s.bri - 0.4
    if s.bri <= 0 or s.r > max_r then
      table.remove(kaleido.shards, i)
    else
      plot(s.r, s.a, clamp(math.floor(s.bri * bri_scale), 0, 15))
    end
  end

  -- centre glow
  local gb = clamp(math.floor((3 + audio_level * 8) * bri_scale), 0, 15)
  if gb > 0 then
    screen.level(gb)
    screen.circle(cx, cy, 1 + audio_level * 2)
    screen.fill()
  end
end

------------------------------------------------------------------------
-- dispatch
------------------------------------------------------------------------

-- {name, init, trigger (nil = reacts to level only), draw}
local THEMES = {
  {"terrain",  terrain.init,    terrain.trigger, terrain.draw},
  {"tunnel",   init_tunnel,     tunnel_trigger,  draw_tunnel},
  {"field",    init_field,      nil,             draw_field},
  {"lattice",  lattice.init,    lattice.trigger, lattice.draw},
  {"pulse",    init_pulse,      pulse_trigger,   draw_pulse},
  {"drift",    init_drift,      nil,             draw_drift},
  {"hex",      init_hex,        hex_trigger,     draw_hex},
  {"stars",    init_stars,      stars_trigger,   draw_stars},
  {"wave",     init_wave,       wave_trigger,    draw_wave},
  {"rain",     init_rain,       rain_trigger,    draw_rain},
  {"spiral",   init_spiral,     spiral_trigger,  draw_spiral},
  {"liss",     init_lissajous,  liss_trigger,    draw_lissajous},
  {"bounce",   init_bounce,     bounce_trigger,  draw_bounce},
  {"grid",     init_grid,       grid_trigger,    draw_grid},
  {"flow",     init_flow,       flow_trigger,    draw_flow},
  {"morph",    init_morph,      morph_trigger,   draw_morph},
  {"shatter",  init_shatter,    shatter_trigger, draw_shatter},
  {"code",     init_code,       code_trigger,    draw_code},
  {"orbit",    init_orbit,      orbit_trigger,   draw_orbit},
  {"kaleido",  kaleido.init,    kaleido.trigger, kaleido.draw},
}

VIS.names = {}
for i, t in ipairs(THEMES) do VIS.names[i] = t[1] end

-- (re)start theme i's animation state
function VIS.init(i)
  local t = THEMES[i or 1]
  if t then
    audio_level = VIS.audio_level
    t[2]()
  end
end

function VIS.trigger(i)
  local t = THEMES[i]
  if t and t[3] then
    audio_level = VIS.audio_level
    t[3]()
  end
end

function VIS.draw(i)
  local t = THEMES[i]
  if t then
    audio_level = VIS.audio_level
    time_val = time_val + 0.05
    t[4]()
  end
end

return VIS
