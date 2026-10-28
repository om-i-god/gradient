-- gradient / visuals
-- eight themes drawn from what the music is doing, not just how loud it
-- is: the chord voices, the phasing arp lanes, the dub echo, the pump,
-- the track's energy arc. the script feeds events as they happen
-- (VIS.event) and the conductor state every frame (VIS.draw(theme, S)).
--
--   gradient  the chord as soft bands of light at each voice's pitch;
--             the bass glows underneath, the bands breathe with energy
--   voices    the four chord voices scrolling right to left: morphs and
--             voice leading drawn as they happen, stabs as bright ticks
--   lanes     each arp lane as a ring of its steps, playheads circling
--             at their own lengths; a line joins the four heads
--   phase     two line gratings turned by the phase gap between lanes
--             1 and 2: the moire swims as the lanes drift apart
--   echo      every stab leaves copies drifting off at the echo time,
--             fading by the feedback; throws leave long trails
--   fall      arp notes fall from their pitch; stabs fall heavier
--   pump      horizon lines squeezed by the ghost sidechain each beat;
--             in kickless stretches they turn to water
--   arc       the energy of the last 60 bars; hollow where the kick was
--             out, dots where the chord changed, a bar under pedal bass

local VIS = {}

VIS.audio_level = 0
VIS.names = {"gradient", "voices", "lanes", "phase", "echo", "fall", "pump", "arc"}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- note -> screen row: the stabs' usual range (Bb2..E5) fills the height
local function py(n) return clamp(math.floor(62 - (n - 46) * 1.8), 1, 62) end

local cur = 1          -- theme being drawn; events only build state for it
local last_S           -- conductor state as of the last frame
local frame = 0
local B = 1            -- brightness scale for this frame
local SP = 1           -- speed scale for this frame (1 at the default 3)

-- envelopes every theme can read; events bump them, frames decay them
local env = {kick = 0, pump = 0, stab = 0, bass = 0, arp = 0}

------------------------------------------------------------------------
-- batched rects: one fill per brightness level, not one per rect
------------------------------------------------------------------------

local batch, bn = {}, {}
for l = 1, 15 do batch[l], bn[l] = {}, 0 end

local function put(l, x, y, w, h)
  l = math.floor(l * B + 0.5)
  if l <= 0 then return end
  if l > 15 then l = 15 end
  local b, n = batch[l], bn[l]
  b[n + 1], b[n + 2], b[n + 3], b[n + 4] = x, y, w, h
  bn[l] = n + 4
end

local function flush()
  for l = 1, 15 do
    local n = bn[l]
    if n > 0 then
      local b = batch[l]
      screen.level(l)
      for i = 1, n, 4 do screen.rect(b[i], b[i + 1], b[i + 2], b[i + 3]) end
      screen.fill()
      bn[l] = 0
    end
  end
end

local function stroke_level(l)
  l = math.floor(l * B + 0.5)
  if l <= 0 then return false end
  screen.level(math.min(15, l))
  return true
end

------------------------------------------------------------------------
-- gradient
------------------------------------------------------------------------

local function draw_gradient(S)
  local c, e = S.chord, S.energy
  local t = frame * 0.05 * SP
  local glow = 0.55 + env.stab * 0.7 + VIS.audio_level * 0.5
  local width = 1.6 + (1 - e) * 2.2             -- calm = wider, softer bands
  local bass_lit = 1.5 + env.bass * 7 + env.kick * 3 * ((S.gain.bass or 0) > 0 and 1 or 0.3)
  for col = 0, 15 do
    local x = col * 8
    local wob = math.sin(t * 0.6 + col * 0.45) * (1.5 + (1 - e) * 3.5)
    for row = 0, 31 do
      local y = row * 2
      local v = 0
      for i = 1, 4 do
        local d = (y - py(c[i]) - wob * (i % 2 == 0 and 1 or -1)) / width
        v = v + math.exp(-d * d) * (2.2 + i * 0.6)
      end
      local db = (y - 62) / 5
      v = v * glow
      -- soft knee: close voices merge into a glow, not a flat slab
      put(13 * (1 - math.exp(-v * v * 0.04)) + math.exp(-db * db) * bass_lit, x, y, 8, 2)
    end
  end
end

------------------------------------------------------------------------
-- voices
------------------------------------------------------------------------

local ribbon = {}
local rib_acc, rib_hit, rib_kick = 0, 0, 0

local function draw_voices(S)
  rib_hit  = math.max(rib_hit, env.stab)
  rib_kick = math.max(rib_kick, env.kick)
  rib_acc = rib_acc + SP * 0.3
  while rib_acc >= 1 do
    rib_acc = rib_acc - 1
    local c = S.chord
    table.insert(ribbon, 1, {
      py(c[1]), py(c[2]), py(c[3]), py(c[4]),
      bass = (S.gain.bass or 0) > 0 and (63 - (S.bass_pc or 0)) or nil,
      hit = rib_hit, k = rib_kick, lanes = S.gain.lane1 or 0,
    })
    rib_hit, rib_kick = 0, 0
    if #ribbon > 64 then ribbon[#ribbon] = nil end
  end
  local base = 2 + S.energy * 5
  for i, col in ipairs(ribbon) do
    local x = 128 - i * 2
    local fade = 1 - i / 72
    local lv = (base + col.hit * 9) * fade
    for v = 1, 4 do put(lv, x, col[v], 2, 1) end
    if col.hit > 0.5 then
      -- a stab: a faint stem joining the voices
      put(2 * fade, x, col[4], 1, col[1] - col[4])
    end
    if col.bass then put((2 + col.k * 9) * fade, x, col.bass - 1, 2, 2) end
  end
end

------------------------------------------------------------------------
-- lanes
------------------------------------------------------------------------

local lane_flash = {{}, {}, {}, {}}
local lane_rot = 0

local function draw_lanes(S)
  lane_rot = lane_rot + 0.004 * SP
  local cx, cy = 64, 32
  local heads = {}
  for i = 1, 4 do
    local l = S.lanes[i]
    if l then
      local g = S.gain["lane" .. i] or 0
      local rx, ry = 10 + i * 12, 5 + i * 6.3
      local fl = lane_flash[i]
      local dir = (i % 2 == 0) and -1 or 1
      -- the orbit itself, faint, so short lanes still read as rings
      for k = 0, 47 do
        local a = k / 48 * 2 * math.pi
        put(1 + g, math.floor(cx + math.cos(a) * rx), math.floor(cy + math.sin(a) * ry), 1, 1)
      end
      for s = 1, l.len do
        local a = lane_rot * dir + (s - 1) / l.len * 2 * math.pi - math.pi / 2
        local x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        local on = (l.seq[s] or 0) > 0
        local lv = on and (4 + g * 5) or 2
        if s == l.pos then
          lv = lv + 3 + g * 6
          heads[#heads + 1] = {x, y}
        end
        lv = lv + (fl[s] or 0)
        if fl[s] then fl[s] = fl[s] > 0.3 and fl[s] * 0.8 or nil end
        local sz = on and 2 or 1
        put(lv, math.floor(x - sz / 2), math.floor(y - sz / 2), sz, sz)
      end
    end
  end
  put(2 + env.pump * 9, cx - 1, cy - 1, 3, 3)
  flush()
  -- the four playheads joined: tight when the lanes line up
  if #heads > 1 and stroke_level(1 + env.arp * 5) then
    screen.move(heads[1][1], heads[1][2])
    for k = 2, #heads do screen.line(heads[k][1], heads[k][2]) end
    screen.stroke()
  end
end

------------------------------------------------------------------------
-- phase
------------------------------------------------------------------------

local ph_rot, ph_delta = 0, 0

local function lane_cycle(l)
  if not l then return 0 end
  return (l.tick or 0) / math.max(1, l.len * l.div)
end

local function grating(angle, lv, spacing)
  if not stroke_level(lv) then return end
  local ca, sa = math.cos(angle), math.sin(angle)
  local reach = math.ceil(75 / spacing)
  for k = -reach, reach do
    local ox, oy = 64 - sa * k * spacing, 32 + ca * k * spacing
    screen.move(ox - ca * 80, oy - sa * 80)
    screen.line(ox + ca * 80, oy + sa * 80)
  end
  screen.stroke()
end

local function draw_phase(S)
  local d = (lane_cycle(S.lanes[1]) - lane_cycle(S.lanes[2])) % 1
  local target = math.sin(d * 2 * math.pi) * 0.22
  ph_delta = ph_delta + (target - ph_delta) * 0.08
  ph_rot = ph_rot + 0.0025 * SP
  local e = S.energy
  local spacing = 6 - e * 2
  grating(ph_rot, 3 + e * 4 + env.kick * 5, spacing)
  grating(ph_rot + 0.2 + ph_delta, 3 + (S.gain.lane2 or 0) * 3 + env.arp * 6,
          spacing * (1.12 + ph_delta))
  if (S.gain.lane3 or 0) > 0 then
    grating(-ph_rot * 0.5 + math.pi / 2, 1 + env.stab * 6, spacing * 2)
  end
end

------------------------------------------------------------------------
-- echo
------------------------------------------------------------------------

local copies, emitters = {}, {}

local function echo_spawn(ys, lv)
  if #copies < 90 then copies[#copies + 1] = {x = 4, ys = ys, lv = lv, dy = 0} end
end

local function on_stab_echo(notes)
  local S = last_S
  local ys = {}
  for i = 1, 4 do ys[i] = py(notes[i]) end
  echo_spawn(ys, 13)
  local throwing = S and (S.throw or (S.hand_throw or 0) > 0)
  local fb = throwing and 0.86 or 0.4 + (S and S.dub or 0.5) * 0.35
  local period = clock.get_beat_sec() * 0.75 / 0.05      -- frames
  if #emitters < 12 then
    emitters[#emitters + 1] = {ys = ys, lv = 13 * fb, fb = fb, next = frame + period, period = period}
  end
end

local function draw_echo(S)
  for i = #emitters, 1, -1 do
    local em = emitters[i]
    if frame >= em.next then
      echo_spawn(em.ys, em.lv)
      em.lv, em.next = em.lv * em.fb, em.next + em.period
    end
    if em.lv < 0.8 then table.remove(emitters, i) end
  end
  local v = 1.6 * SP
  for i = #copies, 1, -1 do
    local c = copies[i]
    c.x = c.x + v
    c.dy = c.dy + (math.random() - 0.5) * 0.25          -- tape wow
    c.lv = c.lv * 0.995
    if c.x > 130 or c.lv < 0.6 then
      table.remove(copies, i)
    else
      for k = 1, 4 do put(c.lv, math.floor(c.x), math.floor(c.ys[k] + c.dy), 5, 1) end
    end
  end
  put(1 + env.kick * 8 + env.pump * 2, 0, 63, 128, 1)
end

------------------------------------------------------------------------
-- fall
------------------------------------------------------------------------

local drops = {}

local function nx(n) return clamp(math.floor((n - 36) * 2.2), 1, 125) end

local function draw_fall(S)
  local g = 0.04 * SP
  for i = #drops, 1, -1 do
    local d = drops[i]
    d.vy = d.vy + g * d.mass
    d.y = d.y + d.vy * SP
    d.lv = d.lv * 0.985
    if d.y > 66 or d.lv < 0.6 then
      table.remove(drops, i)
    else
      put(d.lv, d.x, math.floor(d.y), d.w, d.h)
      put(d.lv * 0.35, d.x, math.floor(d.y - d.h - 2), d.w, 2)   -- trail
    end
  end
  -- the bass as a glowing floor under its pitch
  if (S.gain.bass or 0) > 0 then
    local bx = clamp(math.floor((S.bass_pc or 0) * 10), 0, 118)
    put(2 + env.bass * 9, bx, 62, 10, 2)
  end
end

local function on_arp_fall(lane, note)
  if #drops < 140 then
    drops[#drops + 1] = {x = nx(note), y = 0, vy = 0.3 + lane * 0.15 + math.random() * 0.1,
                         mass = 0.6 + lane * 0.2,
                         w = 1, h = 2 + lane, lv = 7 + lane}
  end
end

local function on_stab_fall(notes)
  for i = 1, 4 do
    if #drops < 140 then
      drops[#drops + 1] = {x = nx(notes[i]) - 2 + math.random(-3, 3), y = math.random(0, 6),
                           vy = 0.1 + math.random() * 0.15, mass = 0.3 + math.random() * 0.2,
                           w = 4 + math.random(0, 2), h = 1, lv = 9 + math.random() * 4}
    end
  end
end

------------------------------------------------------------------------
-- pump
------------------------------------------------------------------------

local function draw_pump(S)
  local e = S.energy
  local n = 6 + math.floor(e * 12)
  local squeeze = 1 - env.pump * 0.55
  local t = frame * 0.05 * SP
  local water = S.kickless and 1 or 0
  for j = 1, n do
    local f = j / n
    local d = (f ^ 1.6) * 31 * squeeze + 1
    local near = f
    for side = -1, 1, 2 do
      local y0 = 32 + side * d
      local lv = 1 + near * (3 + e * 5)
      if side > 0 then lv = lv + env.bass * 6 * near else lv = lv + env.stab * 5 * near end
      if stroke_level(lv) then
        if water > 0 then
          screen.move(0, y0)
          for x = 8, 128, 8 do
            screen.line(x, y0 + math.sin(t * 1.3 + x * 0.06 + j) * near * 2.5)
          end
        else
          screen.move(0, y0)
          screen.line(128, y0)
        end
        screen.stroke()
      end
    end
  end
  -- the horizon flashes with the kick
  if stroke_level(2 + env.kick * 12) then
    screen.move(0, 32)
    screen.line(128, 32)
    screen.stroke()
  end
end

------------------------------------------------------------------------
-- arc
------------------------------------------------------------------------

local hist = {}

local function on_bar_arc(S)
  hist[#hist + 1] = {e = S.energy, kl = S.kickless, pedal = (S.chord_label or ""):find("/") ~= nil,
                     ch = S.chord_label}
  if #hist > 61 then table.remove(hist, 1) end
end

local function draw_arc(S)
  local n = #hist
  for i = 1, n do
    local h = hist[i]
    local x = 128 - (n - i + 2) * 2
    local top = 52 - math.floor(h.e * 36)
    local lv = 2 + h.e * 6
    if h.kl then
      put(lv, x, top, 2, 1)                       -- hollow: kick out
    else
      put(lv * 0.6, x, top, 2, 52 - top)
      put(lv + 2, x, top, 2, 1)
    end
    if i > 1 and h.ch ~= hist[i - 1].ch then put(6, x, top - 4, 1, 1) end
    if h.pedal then put(4, x, 55, 2, 1) end
  end
  -- this bar, live
  local top = 52 - math.floor(S.energy * 36)
  put(6 + env.kick * 9, 126, top, 2, 52 - top)
  -- track mode: how far through, with section edges
  if S.mode_play == 2 and S.total_bars then
    put(2, 0, 60, 128, 1)
    put(10, 0, 60, math.floor((S.progress or 0) * 128), 1)
  end
end

------------------------------------------------------------------------
-- dispatch
------------------------------------------------------------------------

local DRAW = {draw_gradient, draw_voices, draw_lanes, draw_phase, draw_echo, draw_fall, draw_pump, draw_arc}

function VIS.init()
  ribbon, copies, emitters, drops = {}, {}, {}, {}
  lane_flash = {{}, {}, {}, {}}
  for k in pairs(env) do env[k] = 0 end
end

-- kind: "kick", "pump", "stab" (notes), "bass" (note), "arp" (lane, note,
-- step), "bar" (S)
function VIS.event(kind, a, b, c)
  if kind == "bar" then
    on_bar_arc(a)     -- the arc keeps its history whatever's on screen
    return
  end
  if env[kind] then env[kind] = 1 end
  if kind == "stab" then
    if cur == 5 then on_stab_echo(a) elseif cur == 6 then on_stab_fall(a) end
  elseif kind == "arp" then
    if cur == 3 and c then lane_flash[a][c] = 7 end
    if cur == 6 then on_arp_fall(a, b) end
  end
end

function VIS.draw(i, S)
  local fn = DRAW[i]
  if not fn or not S then return end
  if i ~= cur then VIS.init(); cur = i end
  last_S = S
  frame = frame + 1
  B  = params:get("vis_brightness") / 10
  SP = params:get("vis_speed") / 3
  fn(S)
  flush()
  -- envelopes fall over a few frames; the pump follows the beat's duck
  env.kick = env.kick * 0.72
  env.pump = env.pump * 0.8
  env.stab = env.stab * 0.8
  env.bass = env.bass * 0.75
  env.arp  = env.arp * 0.7
end

return VIS
