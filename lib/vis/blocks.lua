-- blocks: tower blocks at night over a railway viaduct. each arp lane has a
-- tower of its own: a note lights a window on the floor of its pitch, which
-- glows warm and slowly goes dark again, and comes back fainter at the echo
-- time while the dub feeds it. the chord decides which floors are lived in
-- across every block, and a stab turns those lights up. the stairwell
-- lights dim on each pump; red lights pulse on the roofs; the bass glows
-- in the arches of the viaduct (out_lo), the highs flicker as tellies in
-- the windows. a train crosses the viaduct on the bar, one way then the
-- other. kickless stretches let a low mist roll between the blocks
return function(K)
  local M = {}
  local put, A, clamp, follow = K.put, K.A, K.clamp, K.follow

  local BOT = 50                          -- the towers' feet (behind the viaduct)
  local DECK = 53                         -- the viaduct's deck
  -- the four lane towers: x, width, top
  local TOW = {{4, 23, 9}, {35, 20, 16}, {66, 26, 5}, {101, 22, 13}}
  -- far blocks behind them, only their floors catch the light
  local FAR = {{28, 7, 21}, {56, 10, 27}, {93, 8, 19}, {124, 4, 24}}
  local FLH = 3                           -- a floor's height, px
  local SKYP = K.profile(function(x)
    for _, t in ipairs(TOW) do
      if x >= t[1] - 1 and x < t[1] + t[2] + 1 then return t[3] - 1 end
    end
    for _, t in ipairs(FAR) do
      if x >= t[1] and x < t[1] + t[2] then return t[3] - 1 end
    end
    return 99
  end)

  local lit = {{}, {}, {}, {}}            -- per tower: {f, c, t0, pk}
  local echoes = {}                       -- {at, tower, f, c, v}
  local trains = {}
  local dir = 1
  local vk = {0, 0, 0, 0}
  local fl = {}                           -- eased glow per floor key
  local stair, arch, idle = 0, 0, 0

  local function nfl(t) return math.floor((BOT - t[3]) / FLH) end
  local function ncol(t) return math.floor((t[2] - 3) / 3) end
  local function wy(f) return BOT - FLH * (f + 1) + 1 end
  local function wx(t, c) return t[1] + 2 + c * 3 end

  -- a note's floor in a tower: C3..C7 from the ground to the roof
  local function floor_of(t, note)
    return clamp(math.floor((K.num(note, 72) - 48) / 48 * nfl(t)), 0, nfl(t) - 1)
  end

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own.
  -- kick, hat, bass and arp notes take turns (odd / even towers, tellies, piers, sides)
  local hit, percs, pdz = {}, {}, 0
  local kn, hn, bn, an = 0, 0, 0, 0
  local KS, HS, BS = {"kick0", "kick1"}, {"hat0", "hat1"}, {"bass0", "bass1"}
  local AK = {{"a10", "a11"}, {"a20", "a21"}, {"a30", "a31"}, {"a40", "a41"}}
  local aflr = {{0, 0}, {0, 0}, {0, 0}, {0, 0}}
  -- the fades follow the trails setting; at fine it acts at half strength and never moves them by more than 15% or 10%
  local function TR() return K.detail ~= "classic" and math.min(1.1, math.max(0.85, K.trail ^ 0.5)) or K.trail end
  local function mark(k) hit[k] = K.NOW end
  local function fade(k, tau)
    local t = hit[k]
    if not t then return 0 end
    local v = math.exp(-(K.NOW - t) / (tau * TR()))
    if v < 0.02 then hit[k] = nil; return 0 end
    return v
  end
  function M.kick() kn = kn + 1; mark(KS[kn % 2 + 1]) end
  function M.hat() hn = hn + 1; mark(HS[hn % 2 + 1]) end
  function M.bass() bn = bn + 1; mark(BS[bn % 2 + 1]) end
  function M.clap() mark("clap") end
  function M.tick(kind) mark("tick"); hit.tk = clamp(math.floor(K.num(kind, 1)), 0, 99) % 2 end
  -- a perc lights a whole floor in the tower of its voice, the floor its note's
  function M.perc(voice, note)
    local ti = clamp(math.floor(K.num(voice, 1)), 1, 4)
    percs[#percs + 1] = {t = K.NOW, ti = ti, f = floor_of(TOW[ti], note)}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    hit, percs, pdz, kn, hn, bn, an = {}, {}, 0, 0, 0, 0, 0
    aflr = {{0, 0}, {0, 0}, {0, 0}, {0, 0}}
    lit = {{}, {}, {}, {}}
    echoes, trains, dir = {}, {}, 1
    vk = {0, 0, 0, 0}
    fl = {}
    stair, arch, idle = 0, 0, 5
  end

  local function light(ti, f, c, pk)
    local L = lit[ti]
    for _, w in ipairs(L) do
      if w.f == f and w.c == c then w.t0, w.pk = K.NOW, math.max(pk, w.pk * 0.5); return end
    end
    if #L >= 30 then table.remove(L, 1) end
    L[#L + 1] = {f = f, c = c, t0 = K.NOW, pk = pk}
  end

  function M.arp(lane, note, step)
    local ti = clamp(math.floor(K.num(lane, 1)), 1, 4)
    local t = TOW[ti]
    local f = floor_of(t, note)
    an = an + 1                                  -- the notes take turns at the two halves of the tower
    mark(AK[ti][an % 2 + 1])
    aflr[ti][an % 2 + 1] = f
    local c = math.floor(K.num(step, 1)) % ncol(t)
    light(ti, f, c, 1)
    -- the dub brings it back at the echo time, fainter by the feedback
    local v = K.echo_fb * (0.4 + 0.6 * K.dub)
    if v > 0.15 and #echoes < 40 then
      echoes[#echoes + 1] = {at = K.NOW + K.echo_t, ti = ti, f = f, c = c, v = v}
    end
  end

  local function send_train()
    if #trains >= 3 then return end
    trains[#trains + 1] = {x = dir > 0 and -70 or 198, dir = dir, cars = 3 + math.floor(K.rnd() * 2)}
    dir = -dir
  end

  function M.bar() send_train() end

  function M.draw(S)
    local T, DT, DTS, NOW = K.T, K.DT, K.DTS, K.NOW
    local fine, dense, RT = K.detail ~= "classic", K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.15 end     -- eased above 1: the lit / frame-change bounds are tight here
    local fp = fine and K.playing          -- time-driven fine detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RT, 13) or l end
    local c = K.chord
    for i = 1, 4 do vk[i] = follow(vk[i], K.voice_kick[i], 0.12, DT) end
    stair = follow(stair, K.duck, 0.04, DT)
    arch = follow(arch, math.max(K.env.bass * (K.gain(S, "bass") > 0 and 1 or 0.5), A[K.LO] * 0.8), 0.08, DT)
    local breathe = 1 - stair * 0.35
    local hi = A[K.HI]
    pdz = follow(pdz, K.env.pad, 0.25, DT)
    local pd, mid, cl, tkk = pdz, A[K.MID], fade("clap", 0.3), fade("tick", 0.4)
    local kf0, kf1, hf0, hf1 = fade(KS[1], 0.3), fade(KS[2], 0.3), fade(HS[1], 0.25), fade(HS[2], 0.25)

    -- the sky: the city's glow low down, a few clouds catching it
    K.gradient(32, BOT - 1, function(y) return (y - 32) / 18 * (0.45 + A[K.LO] * 0.5) end, SKYP)
    K.haze(0, 2, 128, 22, 0.08 + 0.1 * K.dub, 1, T * 2)

    -- the far blocks: floor lines only, a few windows on
    for k, t in ipairs(FAR) do
      for y = t[3], BOT - 1, FLH do put(1, t[1], y, t[2], 1) end
      for f = 0, 6 do
        local h = K.hash(f * 13 + k, 31)
        if h < 0.35 then
          local y = t[3] + 1 + f * FLH * 2
          if y < BOT - 1 then
            put(1.5 + h * 2 + hi * (fine and 4 or 3) * h, t[1] + 1 + math.floor(K.hash(f, k) * (t[2] - 3)), y, 2, 1)
          end
        end
      end
    end

    -- the chord: which floors are lived in tonight, eased as it moves
    local want, slab = {}, {}
    for ti, t in ipairs(TOW) do
      local n = nfl(t)
      for i = 1, 4 do
        local f = floor_of(t, c[i] + 12)
        local key = ti * 100 + f
        want[key] = math.max(want[key] or 0, 0.6 + vk[i] * 0.8)
        if fine then slab[key] = math.max(slab[key] or 0, vk[i]) end
        if f + 1 < n then
          local k2 = key + 1
          want[k2] = math.max(want[k2] or 0, 0.25 + vk[i] * 0.3)
        end
      end
    end
    for key in pairs(want) do if not fl[key] then fl[key] = 0 end end
    for key, v in pairs(fl) do
      local nv = follow(v, want[key] or 0, 0.6, DT)
      if nv < 0.02 and not want[key] then fl[key] = nil else fl[key] = nv end
    end

    -- the lane towers
    for ti, t in ipairs(TOW) do
      local x0, w, top = t[1], t[2], t[3]
      local n, nc = nfl(t), ncol(t)
      local g = K.gain(S, "lane" .. ti)
      -- the edges and the floor slabs
      put(2, x0, top, 1, BOT - top)
      put(1.5, x0 + w - 1, top, 1, BOT - top)
      put(2, x0, top - 1, w, 1)
      for f = 0, n - 1 do put(1, x0 + 2, BOT - FLH * (f + 1), w - 4, 1) end
      -- lived-in floors: some of their windows on, merged into runs
      for f = 0, n - 1 do                                    -- a stab lights the slab of each lived-in floor
        local sv = slab[ti * 100 + f]
        if sv and sv > 0.03 then put(E(4.5 * sv), x0 + 2, BOT - FLH * (f + 1), w - 4, 1) end
      end
      for f = 0, n - 1 do
        local v = fl[ti * 100 + f]
        if v and v > 0.05 then
          local y = wy(f)
          for cc = 0, nc - 1 do
            if K.hash(ti * 997 + f * 31 + cc, 7) < 0.5 then
              put((1.3 + v * 3) * breathe * (1 + 0.5 * mid + (fp and 0.6 * pd or 0)), wx(t, cc), y, 2, 2)
            end
          end
        end
      end
      -- the stairwell: a column of landing lights, dimmed by the pump
      local sx = x0 + w - 3
      for f = 0, n - 1, 1 do put((2.6 + K.energy) * (1 - stair * (fp and 0.85 or 0.7)) * (1 + (fine and 0.7 or 0.5) * A[K.AMP]), sx, wy(f), 1, 2) end
      -- the arp's windows: warm, slowly going dark
      local L = lit[ti]
      for k = #L, 1, -1 do
        local wi = L[k]
        local u = (NOW - wi.t0) / ((1.4 + K.dub * 1.2) * TR())
        if u > 3.5 or u < 0 then table.remove(L, k)
        else
          local l = (3 + 7 * wi.pk * (0.6 + 0.4 * g)) * math.exp(-u) * breathe
          put(math.min(fine and l * RT or l, 13), wx(t, wi.c), wy(wi.f), 2, 2)
        end
      end
      -- two tellies on: their light flickers with the highs
      for k = 1, 2 do
        local f = math.floor(K.hash(ti * 7 + k, 41) * n)
        local cc = math.floor(K.hash(ti * 7 + k, 42) * nc)
        local fx = 0.5 + 0.5 * math.sin(T * (5 + k * 2.3) + ti)
        put(1 + hi * (fine and 2.6 + 5 * fx or 2 + 4 * fx), wx(t, cc), wy(f), 2, 2)
      end
      -- dense: an aerial on each roof, its tip blinking
      if dense and fp then
        put(1.6, x0 + w - 5, top - 4, 1, 3)
        put(1 + 4 * (0.5 + 0.5 * math.sin(T * 2.1 + ti * 1.3)) ^ 3, x0 + w - 5, top - 5, 1, 1)
      end
      -- a red light on the roof, pulsing slowly
      local r = 0.5 + 0.5 * math.sin(T * 1.3 + ti * 1.9)
      put(1 + r * 4, x0 + math.floor(w / 2), top - 2, 1, 1)
      -- a kick catches the towers' edges, odd and even in turn; a tick flares the roof lamp
      if (ti % 2 == 1 and kf0 or kf1) > 0.03 then
        local kv = ti % 2 == 1 and kf0 or kf1
        put(E(5 * kv), x0, top, 1, BOT - top)
        put(E(5 * kv), x0 + w - 1, top, 1, BOT - top)
      end
      if tkk > 0.03 then
        put(E(((ti + (hit.tk or 0)) % 2 == 0 and (fine and 9 or 8) or 5) * tkk), x0 + math.floor(w / 2) - 1, top - 4, 3, 3)
      end
      -- a clap swells the roof edges
      if fine and cl > 0.03 then put(E(5 * cl), x0, top - 1, w, 1) end
      -- the hats flicker one of each tower's two tellies, in turn
      local hv = hf0
      for k = 1, 2 do
        if hv > 0.03 then
          local f = math.floor(K.hash(ti * 7 + k, 41) * n)
          local cc = math.floor(K.hash(ti * 7 + k, 42) * nc)
          put(E(fine and 5.5 * hv or 4 * hv), wx(t, cc) - 1, wy(f) - 1, 4, 4)
        end
        hv = hf1
      end
      -- the arp notes light half a floor each, odd and even in turn
      for sd = 1, 2 do
        local av = fade(AK[ti][sd], 0.3)
        if av > 0.03 then
          local hw = math.floor((w - 4) / 2)
          put(E((fine and 7.5 or 6) * av), x0 + 2 + (sd - 1) * hw, BOT - FLH * (aflr[ti][sd] + 1), hw, 1)
        end
      end
    end
    -- a perc lights a whole floor of the tower of its voice
    for i = #percs, 1, -1 do
      local p = percs[i]
      local f = math.exp(-(K.NOW - p.t) / (0.5 * TR()))
      if f < 0.03 then table.remove(percs, i)
      else
        local t = TOW[p.ti]
        put(E(7 * f), t[1] + 2, wy(p.f), t[2] - 4, 2)
        put(E(fine and 8 * f or 5 * f), t[1] + 2, BOT - FLH * (p.f + 1), t[2] - 4, 1)
        if fine then put(E(4 * f), t[1] + 1, wy(p.f), 1, 2); put(E(4 * f), t[1] + t[2] - 2, wy(p.f), 1, 2) end
      end
    end
    -- echoes coming due
    for k = #echoes, 1, -1 do
      local e = echoes[k]
      if NOW >= e.at then
        light(e.ti, e.f, e.c, e.v)
        local v = e.v * K.echo_fb
        if v > 0.15 then e.at, e.v = e.at + K.echo_t, v else table.remove(echoes, k) end
      elseif e.at - NOW > 5 then table.remove(echoes, k) end
    end
    -- tellies: the highs flicker blue in a few windows
    K.grain(function(u, v)
      local t = TOW[1 + math.floor(u * 4) % 4]
      return wx(t, math.floor(v * ncol(t))), wy(math.floor(K.rnd() * nfl(t)))
    end, hi * 110, 7)

    -- the pad lifts a haze over the sky
    if pd > 0.03 then K.haze(0, 0, 128, 30, pd * (fine and 0.5 or 0.4), 1, T * 2) end
    -- mist between the blocks: kickless, the dub
    K.haze(0, 30, 128, BOT, (0.06 + 0.32 * K.kickless + 0.12 * K.dub * K.throw) * (fp and 0.5 or 1), 1, T * 4)

    -- the viaduct: the deck, piers, and the arches between them glowing
    -- from the street underneath with the bass
    put(3, 0, DECK, 128, 1)
    if dense and fp then for k = 0, 15 do put(1.6 + 1.2 * math.sin(T * 0.5 + k * 1.9) ^ 2, k * 8 + 3, DECK - 1, 1, 1) end end   -- platform lamps
    if cl > 0.03 then                                            -- a clap swells the deck
      put(E(fine and 8 * cl or 6 * cl), 0, DECK, 128, 1)
    end
    local glow = (0.7 + arch * (fine and 4.8 or 4)) * (1 + (fine and 0.55 or 0.4) * A[K.AMP])
    for k = 0, 7 do
      local ax = k * 16
      put(1.5, ax, DECK + 1, 2, 11)            -- the pier
      local bv = fade(BS[k % 2 + 1], 0.4)         -- the bass shakes the piers, odd and even in turn
      if bv > 0.03 then put(E(fine and 6.5 * bv or 5 * bv), ax, DECK + 1, 2, 11) end
      -- the arch: its curve, and the light pooled under it
      for j = 0, 13, 1 do
        local u = (j - 6.5) / 7
        local y = DECK + 1 + math.floor(3.5 * u * u + 0.5)
        put(1.5, ax + 2 + j, y, 1, 1)
      end
      for r = 0, 2 do
        put(glow * (0.4 + r * 0.3), ax + 5 + (2 - r) * 2, 61 + r, 10 - 4 * (2 - r), 1)
      end
    end

    -- the trains: one each bar, alternate ways; a slow one now and then
    -- when nothing is playing
    if not K.playing then
      idle = idle + DTS
      if idle > 5.5 then idle = 0; send_train() end
    end
    local v = 128 / (K.beat_sec * 7)
    if not K.playing then v = 30 end
    for k = #trains, 1, -1 do
      local tr = trains[k]
      tr.x = tr.x + tr.dir * v * DTS
      local len = tr.cars * 17
      if (tr.dir > 0 and tr.x > 128 + len) or (tr.dir < 0 and tr.x < -len) then
        table.remove(trains, k)
      else
        local yb = DECK - 5
        local psub = fp and K.put_sub or put        -- the train glides between pixels
        for car = 0, tr.cars - 1 do
          local cx = tr.x - tr.dir * car * 17 - (tr.dir > 0 and 16 or 0)
          psub(2.5, cx, yb, 16, 1)               -- the roof
          psub(1.5, cx, yb + 4, 16, 1)           -- the floor
          put(2, cx, yb + 1, 1, 3)
          put(2, cx + 15, yb + 1, 1, 3)
          K.dashes(5 * breathe, yb + 2, 2, 3, 1, cx + 2, cx + 14)
        end
        local hx = tr.dir > 0 and tr.x or tr.x - 1
        put(9, hx, yb + 2, 1, 2)                 -- the headlight
      end
    end
  end

  M.init()
  return M
end
