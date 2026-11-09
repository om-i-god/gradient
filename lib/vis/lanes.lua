-- lanes: the four arp lanes as a machine of nested step rings round a hub.
-- each ring carries a tick per step (the sequence's live steps longer and
-- brighter) and turns slowly on its own; its playhead runs round it
-- leaving a fading trail, and a note lights the tick it lands on. arms
-- reach from the hub to the four playheads and a line joins them: tight
-- when the lanes line up, a long zigzag when they phase apart. the hub
-- pumps with the ghost sidechain, the kick lights it, the bass rings round
-- it (out_lo); stabs light the rings (a voice each), the highs glint on the
-- outer ring, throws drag the trails out. kickless stretches tilt the rings
-- and let the machine drift in a haze
return function(K)
  local M = {}
  local put, line, A, clamp, follow = K.put, K.line, K.A, K.clamp, K.follow
  local TAU = K.TAU

  local CX, CY = 64, 32
  local ang = {0, 0, 0, 0}                -- each playhead's eased angle (turns)
  local flash = {{}, {}, {}, {}}          -- per lane, per step: K.NOW of its note
  local vk = {0, 0, 0, 0}
  local hub, bs, lo = 0, 0, 0
  local seen = {false, false, false, false}

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own
  local hit, hn, percs = {}, 0, {}
  local pdz = 0                           -- the pad, eased in
  local function mark(k) hit[k] = K.NOW end
  local function fade(k, tau)
    local t = hit[k]
    if not t then return 0 end
    local v = math.exp(-(K.NOW - t) / (tau * K.trail))
    if v < 0.02 then hit[k] = nil; return 0 end
    return v
  end
  function M.kick() mark("kick") end
  function M.hat() mark("hat"); hn = hn + 1 end
  function M.clap() mark("clap") end
  function M.bass() mark("bass") end
  function M.tick(kind) mark("tick"); hit.tk = (math.floor(K.num(kind, 1)) % 8) / 8 + 1 / 16 end
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, ring = clamp(math.floor(K.num(voice, 1)), 1, 4),
      a = (math.floor(K.num(note, 60)) % 12) / 12}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    hit, hn, percs, pdz = {}, 0, {}, 0
    ang = {0, 0, 0, 0}
    flash = {{}, {}, {}, {}}
    vk = {0, 0, 0, 0}
    hub, bs, lo = 0, 0, 0
    seen = {false, false, false, false}
  end

  function M.arp(lane, note, step)
    lane = clamp(math.floor(K.num(lane, 1)), 1, 4)
    step = math.floor(K.num(step, 1))
    if step >= 1 and step <= 64 then flash[lane][step] = K.NOW end
  end

  local function len_of(l) return clamp(math.floor(K.num(l.len, 8)), 1, 64) end

  -- ring i's shape this frame: radii and the turn of its ticks
  local function ring(i)
    local sq = 1 - K.duck * 0.018
    local tilt = 1 + K.kickless * 0.22 * math.sin(K.T * 0.31 + i * 1.3)
    local rx = (17 + i * 11) * sq
    local ry = (6 + i * 6.2) * sq * tilt
    local rot = K.T * 0.012 * (i % 2 == 0 and -1 or 1) * (1 + i * 0.3)
    return rx, ry, rot
  end

  local function pt(rx, ry, a, cx, cy)
    local th = a * TAU - math.pi / 2
    return cx + math.cos(th) * rx, cy + math.sin(th) * ry
  end

  function M.draw(S)
    local T, DT, NOW = K.T, K.DT, K.NOW
    local fine, dense, R = K.detail ~= "classic", K.detail == "dense", K.react
    if R > 1 then R = 1 + (R - 1) * 0.55 end        -- the top of the range is eased: peak bars are full already
    local sub = fine and K.playing                  -- sub-pixel glide while it plays
    local function ev(l) return math.min(l * R, 13) end
    local tz = K.trail > 1 and K.trail ^ -0.4 or 1   -- long trails keep the extra marks, a little fainter
    local calm = 1.7 - 1.4 * K.energy               -- a lone note reads bigger in a sparse bar
    local put_s = sub and K.put_sub or put
    -- a tick glides across its pixel along whichever axis it is moving on:
    -- two lines, not four
    local function tick_s(l, x0, y0, x1, y1, a, rx, ry)
      if not sub then return line(l, x0, y0, x1, y1) end
      local th = a * TAU - math.pi / 2                     -- as pt(): the ring's tangent is (-sin, cos)
      if math.abs(math.sin(th)) * rx >= math.abs(math.cos(th)) * ry then   -- the ring runs sideways here
        local fx = x0 - math.floor(x0)
        local dy = math.floor(y0 + 0.5) - y0
        if fx == 0 then return line(l, x0, y0 + dy, x1, y1 + dy) end
        line(l * (1 - fx), x0 - fx, y0 + dy, x1 - fx, y1 + dy)
        line(l * fx, x0 - fx + 1, y0 + dy, x1 - fx + 1, y1 + dy)
      else
        local fy = y0 - math.floor(y0)
        local dx = math.floor(x0 + 0.5) - x0
        if fy == 0 then return line(l, x0 + dx, y0, x1 + dx, y1) end
        line(l * (1 - fy), x0 + dx, y0 - fy, x1 + dx, y1 - fy)
        line(l * fy, x0 + dx, y0 - fy + 1, x1 + dx, y1 - fy + 1)
      end
    end
    local cx = CX + K.kickless * 3 * math.sin(T * 0.23)
    local cy = CY + K.kickless * 1.5 * math.sin(T * 0.17 + 1)
    for i = 1, 4 do vk[i] = follow(vk[i], K.voice_kick[i], 0.06, DT) end
    hub = follow(hub, math.max(K.duck, K.env.kick), 0.03, DT)
    bs = follow(bs, math.max(K.env.bass * (K.gain(S, "bass") > 0 and 1 or 0.5), A[K.LO] * 0.7), 0.06, DT)
    lo = follow(lo, A[K.LO], 0.1, DT)
    local trail = (0.6 + K.throw * 2 + K.dub * 0.6) * K.trail ^ 0.5       -- in steps
    local hi = A[K.HI]
    pdz = follow(pdz, K.env.pad, 0.25, DT)
    local kk, cl, hh, pd = fade("kick", 0.25), fade("clap", 0.3), fade("hat", 0.25), pdz
    local bh = fade("bass", 0.35)
    local mid = A[K.MID]

    -- the housing: corner brackets and a faint bench of haze under it
    local fr = 1.5 + K.bar_pulse * 1.5
    if fine then fr = fr + A[K.MID] * 1.6 + A[K.AMP] * 1.6 end
    for _, c in ipairs({{1, 1, 1, 1}, {126, 1, -1, 1}, {1, 62, 1, -1}, {126, 62, -1, -1}}) do
      put(fr, math.min(c[1], c[1] + c[3] * 5), c[2], 6, 1)
      put(fr, c[1], math.min(c[2], c[2] + c[4] * 4), 1, 5)
    end
    K.haze(0, 44, 128, 64, 0.1 + 0.25 * K.kickless + 0.12 * K.dub * K.throw + 0.12 * mid, 1, T * 3)
    -- the pad and the mids fill the air above the machine
    if mid + pd + A[K.AMP] > 0.05 then K.haze(0, 4, 128, 44, 0.1 * mid + 0.15 * pd + 0.15 * A[K.AMP], 1, -T * 2) end

    local heads = {}
    for i = 1, 4 do
      local l = K.lane(S, i)
      local rx, ry, rot = ring(i)
      local g = K.gain(S, "lane" .. i)
      local lit = 1 + g * 1.5 + vk[i] * 4
      -- the ring itself: a line where the lane plays, dots where it rests
      local n = 20 + i * 8
      if g > 0 then
        local px, py = pt(rx, ry, 0, cx, cy)
        for k = 1, n do
          local qx, qy = pt(rx, ry, k / n, cx, cy)
          line(lit * 0.7, px, py, qx, qy)
          px, py = qx, qy
        end
      else
        for k = 0, 2 * n - 1 do
          local x, y = pt(rx, ry, k / (2 * n) + rot, cx, cy)
          put(lit * 0.8, x, y, 1, 1)
        end
      end
      if l then
        local len = len_of(l)
        local pos = clamp(math.floor(K.num(l.pos, 1)), 0, len)
        local seq = type(l.seq) == "table" and l.seq or nil
        local fl = flash[i]
        -- ticks: one per step, pointing out from the ring
        for s = 1, len do
          local a = (s - 1) / len + rot
          local live = not seq or K.num(seq[s], 1) > 0
          local f = fl[s] and math.exp(-(NOW - fl[s]) / (0.35 * K.trail)) or 0
          if f < 0.02 then fl[s] = nil; f = 0 end
          local x0, y0 = pt(rx - 1, ry - 1, a, cx, cy)
          local out = live and 3 or 1.5
          local x1, y1 = pt(rx + out, ry + out * 0.6, a, cx, cy)
          if dense and sub and live then      -- dense: a hairline dot between this tick and the next
            local mx, my = pt(rx, ry, a + 0.5 / len, cx, cy)
            put(1 + g, mx, my, 1, 1)
          end
          local lv = (live and 2 + g * 2 or 1) + f * (fine and ev(8.5) or 8)
          lv = lv + hi * (1 + i * 0.5) * (fine and 1.6 or 1) * math.max(0, math.sin(T * 4 + s * 1.7 + i))
          tick_s(lv, x0, y0, x1, y1, a, rx, ry)
          -- a landed note blooms round its tick
          if f > 0.1 then
            local bx, by = math.floor(x1 + 0.5), math.floor(y1 + 0.5)
            if fine then
              -- a short arc of the ring lights either side of the tick
              local lw = ev(3.6 * (f ^ 0.45) * calm * tz)
              local px_, py_ = pt(rx + 1.6, ry + 1.2, a - 9 * 0.012, cx, cy)   -- the arc runs -9..+9 steps of 0.012 turn about the tick
              for q = 1, 4 do
                local qx, qy = pt(rx + 1.6, ry + 1.2, a + (q * 4.5 - 9) * 0.012, cx, cy)
                line(lw * ((q == 1 or q == 4) and 0.5 or 1), px_, py_, qx, qy)
                px_, py_ = qx, qy
              end
              local ix, iy = pt(rx - 1.6, ry - 1.2, a - 6 * 0.012, cx, cy)
              local jx, jy = pt(rx - 1.6, ry - 1.2, a + 6 * 0.012, cx, cy)
              line(lw * 0.7, ix, iy, jx, jy)
              put(ev(6 * (f ^ 0.45) * calm), bx - 1, by - 1, 3, 3)
              put(ev(4 * (f ^ 0.45) * calm), bx - 2, by, 5, 1); put(ev(4 * (f ^ 0.45) * calm), bx, by - 2, 1, 5)
              put(ev(8 * (f ^ 0.45)), bx, by, 1, 1)
            else
            put(4.5 * f, bx - 1, by - 1, 3, 3)
            put(2.5 * f, bx - 2, by, 5, 1); put(2.5 * f, bx, by - 2, 1, 5)
            end
          end
        end
        -- the playhead, eased round the ring the short way
        local target = ((math.max(pos, 1) - 1) / len) % 1
        if not seen[i] then ang[i], seen[i] = target, true end
        local d = (target - ang[i] + 0.5) % 1 - 0.5
        ang[i] = (ang[i] + d * (1 - math.exp(-DT / 0.09))) % 1
        local a = ang[i] + rot
        -- its trail: fading points behind it along the ring
        local span = trail / len
        local m = math.floor(4 + span * 40)
        for k = m, 1, -1 do
          local u = k / m
          local x, y = pt(rx, ry, a - span * u, cx, cy)
          put((2 + g * 4 + K.lane_kick[i] * 3) * (1 - u) ^ 1.3, x, y, 1, 1)
        end
        local hx, hy = pt(rx, ry, a, cx, cy)
        put_s(5 + g * 4 + K.lane_kick[i] * 4, hx - 0.5, hy - 0.5, 2, 2)
        if fine and K.lane_kick[i] > 0.05 then
          -- a note kicks a halo round its lane's playhead
          local lk = K.lane_kick[i] * calm
          local hxi, hyi = math.floor(hx + 0.5), math.floor(hy + 0.5)
          put(ev(5 * lk), hxi - 2, hyi - 1, 5, 3)
          put(ev(3.5 * lk), hxi - 3, hyi, 7, 1); put(ev(3.5 * lk), hxi, hyi - 2, 1, 5)
        end
        heads[#heads + 1] = {hx, hy}
      end
    end

    -- the arms from the hub, and the line joining the heads
    local rh = 3 + hub * 2.5 + lo * 2 
    for k = 1, #heads do
      local h = heads[k]
      local dx, dy = h[1] - cx, h[2] - cy
      local d = math.sqrt(dx * dx + dy * dy)
      if d > rh + 2 then line(1, cx + dx / d * (rh + 2), cy + dy / d * (rh + 2), h[1], h[2]) end
    end
    local jl = 1.5 + K.env.arp * 2 + K.throw * 0.6
    for k = 2, #heads do line(jl, heads[k - 1][1], heads[k - 1][2], heads[k][1], heads[k][2]) end

    -- the hub: a disc that pumps, lit by the kick, the bass ringing round it
    local hl = 3 + hub * 5 + K.env.kick * 3
    for dy = -math.floor(rh), math.floor(rh) do
      local w = math.floor(math.sqrt(math.max(0, rh * rh - dy * dy)) + 0.5)
      if w > 0 then
        local inner = math.floor(math.sqrt(math.max(0, (rh - 1.5) ^ 2 - dy * dy)) + 0.5)
        if inner > 0 and math.abs(dy) < rh - 1 then
          put(hl, cx - w, cy + dy, w - inner, 1)
          put(hl, cx + inner, cy + dy, w - inner, 1)
          put(hl * 0.35, cx - inner, cy + dy, 2 * inner, 1)
        else
          put(hl, cx - w, cy + dy, 2 * w, 1)
        end
      end
    end
    put(hl + 2, cx - 1, cy - 1, 2, 2)
    -- a hand inside the hub, round once a bar
    local hx, hy = pt(rh - 1, (rh - 1) * 0.9, K.bar_ph, cx, cy)
    line(hl + 1, cx, cy, hx, hy)
    -- the highs: glints running round the outer ring
    local grx, gry, grot = ring(4)
    K.grain(function(u)
      return pt(grx, gry, u + grot, cx, cy)
    end, hi * (fine and 100 or 90), 9)
    -- a clap swells a halo round the hub
    if cl > 0.03 then
      local rr = rh + 2 + cl * 5
      for k = 0, 23 do
        local th = k / 24 * TAU
        put(ev(6 * cl), cx + math.cos(th) * rr * 1.5, cy + math.sin(th) * rr * 0.8, 1, 1)
        if fine and k % 2 == 0 then
          put(ev(3.5 * cl), cx + math.cos(th) * (rr - 2.5) * 1.5, cy + math.sin(th) * (rr - 2.5) * 0.8, 1, 1)
        end
      end
    end
    -- the kick sends a ring of dots out from the hub
    if kk > 0.03 then
      local r = 1 + (1 - kk) * 26
      for k = 0, 27 do
        local th = k / 28 * TAU
        if fine then
          put(ev(tz * 5.5 * kk), cx + math.cos(th) * r * 1.5, cy + math.sin(th) * r * 0.75, 1, 1)
          if k % 2 == 0 then   -- and a fainter echo of the ring just inside it
            put(ev(tz * 2.5 * kk), cx + math.cos(th) * (r - 2.5) * 1.5, cy + math.sin(th) * (r - 2.5) * 0.75, 1, 1)
          end
        else
        put(4.5 * kk, cx + math.cos(th) * r * 1.5, cy + math.sin(th) * r * 0.75, 1, 1)
        end
      end
    end
    -- hats glint round the outer ring
    if hh > 0.02 then
      for k = 1, (fine and 16 or 14) do
        local x, y = pt(grx, gry, K.hash(k, hn) + grot, cx, cy)
        if fine then
          put(ev(7.5 * hh), x, y, 1, 1)
        else
        put(5 * hh, x, y, 1, 1)
        end
      end
    end
    -- a tick: a dim spoke from the hub out to the outer ring
    local tf = fade("tick", 0.35)
    if tf > 0 then
      local x1, y1 = pt(grx + 3, gry + 2, hit.tk + grot, cx, cy)
      line(3.5 * tf, cx, cy, x1, y1)
    end
    -- a perc: a small bead set on its voice's ring, turned by its note
    for j = #percs, 1, -1 do
      local p = percs[j]
      local f = math.exp(-(NOW - p.t) / (0.6 * K.trail))
      if f < 0.03 then table.remove(percs, j)
      else
        local rx, ry, rot = ring(p.ring)
        local x, y = pt(rx, ry, p.a + rot, cx, cy)
        x, y = math.floor(x + 0.5), math.floor(y + 0.5)
        if fine then
          put(ev(9 * f), x - 1, y - 1, 3, 3)
          put(ev(5 * f), x - 3, y, 7, 1); put(ev(5 * f), x, y - 3, 1, 7)
          local o = ev(4 * (f ^ 0.5))
          put(o, x - 4, y - 4, 1, 1); put(o, x + 4, y - 4, 1, 1); put(o, x - 4, y + 4, 1, 1); put(o, x + 4, y + 4, 1, 1)
          put(o, x - 4, y, 1, 1); put(o, x + 4, y, 1, 1); put(o, x, y - 4, 1, 1); put(o, x, y + 4, 1, 1)
        else
        put(8 * f, x - 1, y - 1, 3, 3)
        put(4 * f, x - 3, y, 7, 1); put(4 * f, x, y - 3, 1, 7)
        end
      end
    end
    local rb = rh + 3 + bs * 3 + bh * 3
    if bh > 0.05 then
      for k = 0, 23 do
        local th = k / 24 * TAU - T * 0.3
        if fine then
          put(ev(tz * 7 * bh), cx + math.cos(th) * (rb + 4) * 1.4, cy + math.sin(th) * (rb + 4) * 0.8, 1, 1)
          if k % 2 == 0 then put(ev(tz * 4 * bh), cx + math.cos(th) * (rb + 6.5) * 1.4, cy + math.sin(th) * (rb + 6.5) * 0.8, 1, 1) end
        else
        put(4 * bh, cx + math.cos(th) * (rb + 4) * 1.4, cy + math.sin(th) * (rb + 4) * 0.8, 1, 1)
        end
      end
    end
    local nb = 16
    for k = 0, nb - 1 do
      local th = k / nb * TAU + T * 0.4
      put(1 + bs * 6 + bh * 3, cx + math.cos(th) * rb * 1.4, cy + math.sin(th) * rb * 0.8, 1, 1)
    end
  end

  M.init()
  return M
end
