-- tape: a reel-to-reel tape echo on a desk at night, seen face on. two
-- reels turn over a panel; the tape runs from the left reel, along the
-- head block (erase, record, three playback heads) past the capstan and up
-- to the right reel. each stab is written at the record head as a bright
-- mark and travels with the tape: the distance to the first playback head
-- is the real echo time, and when the mark passes it the head lights and
-- the echo is written again at the record head, fainter by the real echo
-- feedback, until it dies. arp notes leave small marks on their lane of
-- the tape. the VU needle kicks with the pump and the tape's tension
-- slackens on each duck; the knobs below show the echo's intensity and
-- rate, the dub and the bass; throws spin the reels and smear the tape;
-- the highs are hiss on the heads. kickless stretches let the tape sway
-- and the haze in
return function(K)
  local M = {}
  local put, line, A, clamp = K.put, K.line, K.A, K.clamp
  local TAU = K.TAU

  local LX, RX, RY, FL = 28, 100, 19, 17  -- reel centres and flange radius
  local TY = 45                           -- the tape's top row (3 rows)
  local G1, G2 = 7, 121                   -- the guides at either end
  local HE, HR = 21, 35                   -- erase and record heads (x)
  local HP = {58, 72, 86}                 -- playback heads
  local CAP = 106                         -- capstan
  local MAXM = 40

  local marks, hg
  local angL, angR, tpos, vu, bs, slack, sway, wob, rec

  -- the other parts leave a mark (K.NOW of the hit) that fades on its own
  local hit, percs, pdz = {}, {}, 0
  local kn, bn, an, hn = 0, 0, 0, 0              -- kicks, bass notes and arp notes so far: they take turns
  local HS = {"hat0", "hat1"}
  local KS, BS, AH = {"kick0", "kick1"}, {"bass0", "bass1"}, {"ah1", "ah2", "ah3", "ah4", "ah5"}
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
  function M.clap() mark("clap") end
  function M.bass() bn = bn + 1; mark(BS[bn % 2 + 1]) end
  function M.tick(kind) mark("tick"); hit.tk = clamp(math.floor(K.num(kind, 1)), 0, 99) % 2 end
  -- a perc splices the tape: a patch across it, placed by the note, as wide as its voice
  function M.perc(voice, note)
    percs[#percs + 1] = {t = K.NOW, w = 2 + clamp(math.floor(K.num(voice, 1)), 1, 4),
      x = G1 + 6 + (math.floor(K.num(note, 60)) % 12) / 12 * (G2 - G1 - 18)}
    while #percs > 4 do table.remove(percs, 1) end
  end

  function M.init()
    marks, hg = {}, {0, 0, 0, 0}
    hit, percs, pdz, kn, bn, an, hn = {}, {}, 0, 0, 0, 0, 0
    angL, angR, tpos, vu, bs, slack, sway, wob, rec = 0, 0.7, 0, 0, 0, 0, 0, 0, 0
  end
  M.clear = M.init

  local function write(lv, kind, lane)
    if #marks >= MAXM then table.remove(marks, 1) end
    marks[#marks + 1] = {x = HR + 3, lv = lv, kind = kind, lane = lane or 1, fed = false}
  end

  function M.stab()
    write(12, "stab")
    rec = 1
  end

  function M.arp(lane, note)
    -- each note lights the next head along the block, its lane shifting where it starts
    an = an + 1
    mark(AH[(an + clamp(math.floor(K.num(lane, 1)), 1, 4)) % 5 + 1])
    write(4 + (K.num(note, 72) % 12) / 6, "arp", lane)
  end

  -- a reel: the wound pack (alternate rows), its rim, three spokes, the hub
  local function reel(cx, cy, rp, ang, light)
    for dy = -rp, rp do
      local hw = math.floor(math.sqrt(rp * rp - dy * dy) + 0.5)
      if hw > 0 then
        -- the pack's sheen: a lighter band across the upper left
        local sh = math.max(0, 1 - math.abs(dy + rp * 0.35) / (rp * 0.5))
        put(1.2 + light * 0.6 + sh * 1.3, cx - hw, cy + dy, 2 * hw, 1)
      end
    end
    put(3, cx - 1, cy - rp, 3, 1); put(3, cx - 1, cy + rp, 3, 1)
    local n = 14
    for k = 0, n - 1 do
      local a0, a1 = k / n * TAU, (k + 1) / n * TAU
      line(2 + light, cx + math.cos(a0) * FL, cy + math.sin(a0) * FL, cx + math.cos(a1) * FL, cy + math.sin(a1) * FL)
    end
    for k = 0, 2 do
      local a = ang + k * TAU / 3
      local c, s = math.cos(a), math.sin(a)
      line(4 + light * 2, cx + c * 3, cy + s * 3, cx + c * (FL - 1), cy + s * (FL - 1))
      line(2.5 + light, cx + c * 3 + s, cy + s * 3 - c, cx + c * (FL - 2) + s, cy + s * (FL - 2) - c)
    end
    put(6 + light * 3, cx - 1, cy - 1, 3, 3)
  end

  -- a small knob with its pointer at u (0..1)
  local function knob(x, y, u, l)
    put(2, x - 2, y - 3, 5, 1); put(2, x - 2, y + 3, 5, 1)
    put(2, x - 3, y - 2, 1, 5); put(2, x + 3, y - 2, 1, 5)
    local a = math.pi * (0.75 + 1.5 * clamp(u, 0, 1))
    line(l, x, y, x + math.cos(a) * 3, y + math.sin(a) * 3)
  end

  function M.draw(S)
    local T, DT, DTS = K.T, K.DT, K.DTS
    local fine, dense, RT = K.detail ~= "classic", K.detail == "dense", K.react
    if RT > 1 then RT = 1 + (RT - 1) * 0.15 end     -- eased above 1: the lit / frame-change bounds are tight here
    local fp = fine and K.playing          -- time-driven fine detail waits for the music
    -- an event's level: scaled by the reactivity, never a white point (fine only)
    local function E(l) return fine and math.min(l * RT, 13) or l end
    local kl, th = K.kickless, K.throw
    local et, fb = K.echo_t, K.echo_fb
    -- the tape's speed: record to first playback head in one echo time
    local v = (HP[1] - HR) / et
    bs = K.follow(bs, math.max(K.env.bass * 0.8, A[K.LO]) * (K.gain(S, "bass") > 0 and 1 or 0.5), 0.07, DT)
    vu = K.follow(vu, clamp(0.25 + 0.45 * A[K.AMP] + 0.35 * (1 - K.duck) * (K.playing and 1 or 0.3) + 0.25 * K.env.kick, 0, 1),
      0.07, DT)
    slack = K.follow(slack, K.duck * (1 - kl * 0.5), 0.08, DT)
    sway = K.follow(sway, kl, 1.5, DT)
    wob = K.follow(wob, A[K.LO], 0.15, DT)
    rec = rec * math.exp(-DT / 0.2)

    -- the marks travel with the tape (real time: the echo lands on time)
    for i = #marks, 1, -1 do
      local m = marks[i]
      local x0 = m.x
      m.x = m.x + v * DT
      if m.kind == "stab" then
        for h = 1, 3 do
          if x0 < HP[h] + 3 and m.x >= HP[h] + 3 then
            hg[h + 1] = math.max(hg[h + 1], m.lv / 12 * (h == 1 and 1 or 0.55))
            if h == 1 and not m.fed then
              m.fed = true
              if m.lv * fb >= 0.8 then
                if #marks < MAXM then marks[#marks + 1] = {x = HR + 3 + (m.x - HP[1] - 3), lv = m.lv * fb, kind = "stab", lane = 1, fed = false} end
                hg[1] = math.max(hg[1], m.lv * fb / 12)
              end
            end
          end
        end
      end
      if m.x > G2 then table.remove(marks, i) end
    end
    hg[1] = math.max(hg[1], rec)
    for h = 1, 4 do hg[h] = hg[h] * math.exp(-DT / 0.15) end

    -- the reels: the pack moves from left to right over a long slow cycle
    local u = 0.5 + 0.38 * math.sin(T * 0.013)
    local rpL, rpR = math.floor(6 + 10 * u + 0.5), math.floor(6 + 10 * (1 - u) + 0.5)
    local spin = v * (1 + 1.6 * th) * (DTS / math.max(DT, 1e-6))
    if DT <= 0 then spin = 0 end
    angL = (angL + spin * DT / rpL * 0.6) % TAU
    angR = (angR + spin * DT / rpR * 0.6) % TAU
    tpos = tpos + spin * DT
    local light = (0.5 + 0.5 * A[K.MID]) * (1 - 0.7 * slack)
    pdz = K.follow(pdz, K.env.pad, 0.25, DT)
    local kk0, kk1, hh, cl, tkk = fade(KS[1], 0.3), fade(KS[2], 0.3), fade(HS[1], 0.25), fade("clap", 0.3), fade("tick", 0.4)
    local hh1 = fade(HS[2], 0.25)
    local bh0, bh1, pd = fade(BS[1], 0.4), fade(BS[2], 0.4), pdz

    -- the desk: a dim wall above, the deck's panel edge, the brushed lower
    -- panel and the bass glowing under it
    local am = fp and A[K.AMP] or 0        -- the level brightens the deck's edges
    line(2 + am * 1.2, 0, 40, 127, 40)
    line(1.5 + am * 1.2, 0, 55, 127, 55)
    K.gradient(61, 63, function(y) return 0.3 + bs * 2 * (y - 60) / 3 end)
    K.haze(0, 0, 128, 40, (0.2 * kl + 0.1 * th) * (fp and 0.4 or 1), 1, T * 2)

    -- the pad breathes a haze over the wall; the bass, in turns, glows a half of the panel
    if pd > 0.03 then K.haze(0, 0, 128, 40, pd * 0.4, 1, T * 2) end
    if bh0 > 0.03 then K.gradient(58, 62, function(y) return bh0 * 3 * (y - 57) / 5 end, nil, 0, 64) end
    if bh1 > 0.03 then K.gradient(58, 62, function(y) return bh1 * 3 * (y - 57) / 5 end, nil, 64, 128) end

    reel(LX, RY, rpL, -angL, light)
    reel(RX, RY, rpR, -angR, light)
    -- a kick catches a reel's flange, the two in turns; a clap swells both
    for r = 1, 2 do
      local kv = math.max(r == 1 and kk0 or kk1, cl)
      kv = fine and math.min(1.4, kv * (RT > 1 and RT or 1)) or kv
      if kv > 0.03 then
        local cx = r == 1 and LX or RX
        local n = 14
        for k = 0, n - 1 do
          local a0, a1 = k / n * TAU, (k + 1) / n * TAU
          line(math.min(fine and 8 * kv or 6 * kv, 13), cx + math.cos(a0) * FL, RY + math.sin(a0) * FL, cx + math.cos(a1) * FL, RY + math.sin(a1) * FL)
        end
      end
    end

    -- the VU meter between the reels: its scale, its needle with the pump
    put(1.5, 52, 2, 25, 1); put(1.5, 52, 17, 25, 1)
    put(1.5, 52, 3, 1, 14); put(1.5, 76, 3, 1, 14)
    for k = 0, 6 do
      local a = -2.4 + k * 0.27
      put((k >= 5 and 4 or 2) + am * 1.5, 64 + math.cos(a) * 10, 15 + math.sin(a) * 10, 1, 1)
    end
    local na = -2.4 + 1.65 * vu
    line(8 + 3 * K.env.kick + am, 64, 15, 64 + math.cos(na) * 11, 15 + math.sin(na) * 11)
    put(1.5 + rec * 9, 56, 19, 2, 2)                 -- the record lamp
    if fine and rec > 0.03 then                      -- the record head flares as the stab is written
      put(E(rec * 8), HR - 1, TY + 2, 8, 1); put(E(rec * 6), HR - 2, TY + 8, 10, 1); put(E(rec * 5), HR - 1, TY - 2, 8, 1)
    end
    if cl > 0.03 then                                -- the meter's window swells with a clap
      put(E(5 * cl), 52, 2, 25, 1); put(E(5 * cl), 52, 17, 25, 1)
      put(E(5 * cl), 52, 3, 1, 14); put(E(5 * cl), 76, 3, 1, 14)
      if fine then put(E(3 * cl), 53, 3, 23, 1); put(E(3 * cl), 53, 16, 23, 1) end
    end

    -- the tape path: off the left pack to the guide, along the heads, past
    -- the capstan, up to the right pack. the spans slacken on the duck and
    -- sway in kickless stretches
    local sl = slack * 3.5 + sway * 2 * math.sin(T * 0.9)
    local ax, ay = LX - rpL, RY + 2
    local bx, by = RX + rpR, RY + 2
    line(2.5, ax, ay, (ax + G1) / 2 - sl, (ay + TY) / 2)
    line(2.5, (ax + G1) / 2 - sl, (ay + TY) / 2, G1, TY)
    line(2.5, G2, TY, (bx + G2) / 2 + sl, (by + TY) / 2)
    line(2.5, (bx + G2) / 2 + sl, (by + TY) / 2, bx, by)
    put(4, G1 - 2, TY - 1, 3, 4); put(4, G2, TY - 1, 3, 4)
    local fy = math.floor(math.sin(T * 7) * wob * 0.9 + 0.5)
    put(2, G1, TY + fy, G2 - G1, 3)
    K.dashes(3 + A[K.HI] * (fine and 5 or 3), TY + 1 + fy, 2, 7, tpos, G1, G2)

    -- hats crackle along the tape; ticks light a rail of the head block
    if hh > 0.03 then K.dashes(E(5 * hh), TY - 4, 1, 3, T * 40, G1, G2) end
    if hh1 > 0.03 then K.dashes(E(5 * hh1), TY - 2, 1, 3, T * 40 + 7, G1, G2) end
    if fine and (hh > 0.03 or hh1 > 0.03) then K.dashes(E(3.5 * math.max(hh, hh1)), TY - 6, 1, 4, -T * 30, G1, G2) end
    if tkk > 0.03 then
      put(E(6 * tkk), HE - 4, (hit.tk or 0) == 0 and TY + 4 or TY + 9, CAP - HE + 4, 1)
      if fine then put(E(5 * tkk), HE - 4, (hit.tk or 0) == 0 and TY + 5 or TY + 10, CAP - HE + 4, 1); put(E(3 * tkk), HE - 4, (hit.tk or 0) == 0 and TY + 6 or TY + 11, CAP - HE + 4, 1) end
    end
    -- a perc patches the tape where its note says
    for i = #percs, 1, -1 do
      local p = percs[i]
      local f = math.exp(-(K.NOW - p.t) / (0.5 * TR()))
      if f < 0.03 then table.remove(percs, i)
      else
        put(E(8 * f), p.x, TY - 2 + fy, p.w, 7)
        if fine then                      -- the splice's tape: a frayed edge above and below
          put(E(4 * f), p.x - 1, TY - 4 + fy, p.w + 2, 1); put(E(4 * f), p.x - 1, TY + 6 + fy, p.w + 2, 1)
          put(E(3 * f), p.x - 2, TY - 2 + fy, 1, 7); put(E(3 * f), p.x + p.w + 1, TY - 2 + fy, 1, 7)
        end
      end
    end

    -- the head block
    put(1.5, HE - 4, TY + 4, CAP - HE + 4, 1)
    local heads = {HE, HR, HP[1], HP[2], HP[3]}
    for k, x in ipairs(heads) do
      local g = k == 1 and 0 or hg[k - 1]
      put(2.5 + g * 7, x, TY + 3, 6, 5)
      put(4 + g * 8 + A[K.HI] * 3, x + 2, TY + 3, 2, 1)
    end
    for k = 1, 5 do                                  -- the arp walks along the heads
      local a = fade(AH[k], 0.3)
      if a > 0.03 then
        put(E(6 * a), heads[k], TY + 3, 6, 5); put(E(5 * a), heads[k] + 1, TY - 1, 4, 3)
        if fine then put(E(7 * a), heads[k] + 2, TY + 9, 2, 1); put(E(4 * a), heads[k] - 1, TY + 2, 8, 1) end
      end
    end
    -- capstan and pinch roller, the roller turning with the tape
    put(3 + bs * 4, CAP, TY + 3, 4, 4)
    put(3, CAP - 1, TY - 5, 6, 5)
    if fp then
      K.put_sub(6, CAP + 2.5 + math.cos(tpos * 0.3) * 2, TY - 3.5 + math.sin(tpos * 0.3) * 1.5, 1, 1)
    else
      put(6, CAP + 2 + math.floor(math.cos(tpos * 0.3) * 2 + 0.5), TY - 4 + math.floor(math.sin(tpos * 0.3) * 1.5 + 1.5), 1, 1)
    end

    -- the marks on the tape, smeared on a throw
    for _, m in ipairs(marks) do
      if m.x >= G1 then
        if m.kind == "stab" then
          if fine then K.put_sub(math.min(E(m.lv), 13), m.x, TY + fy, 2, 3) else put(m.lv, m.x, TY + fy, 2, 3) end
          if fine and m.lv >= 9 then put(E(m.lv * 0.35), m.x - 1, TY + fy - 1, 4, 1); put(E(m.lv * 0.35), m.x - 1, TY + fy + 3, 4, 1) end
          if th > 0.05 then
            local w = math.min(14, v * 0.12 * th)
            put(m.lv * 0.3 * th, m.x - w, TY + fy, w, 3)
          end
        else
          local al = m.lv * (0.5 + 0.5 * K.lane_kick[m.lane])
          if fine then
            K.put_sub(E(al * 1.3), m.x, TY + fy + (m.lane - 1) % 3, 1, 1)
            put(E(al * 0.4), m.x, TY + fy + (m.lane - 1) % 3 - 1, 1, 1)
          else put(al, m.x, TY + fy + (m.lane - 1) % 3, 1, 1) end
        end
      end
    end

    -- the knobs: intensity (feedback), rate (echo time), the dub, the bass
    knob(22, 58, fb / 0.93, 6)
    knob(46, 58, (et - 0.05) / 1.2, 6)
    knob(82, 58, K.dub, 6)
    knob(106, 58, bs, 6 + bs * 4)

    -- hiss: the highs on the heads and the tape
    K.grain(function(uu, vv) return HR + uu * (CAP - HR), TY - 2 + vv * 9 end, A[K.HI] * 80, 7)
    if fp then K.grain(function(uu, vv) return G1 + uu * (G2 - G1), TY - 1 + vv * 6 end, A[K.HI] * 40, 5) end
    -- dense: the winding of each pack, a ring or two turning with the reel
    if dense and fp then
      for r = 1, 2 do
        local cx, rp, rot = r == 1 and LX or RX, r == 1 and rpL or rpR, r == 1 and -angL or -angR
        for ring = 1, 2 do
          local rr = rp - 2 - ring * 3
          if rr > 5 then
            for k = 0, 5 do
              local a0 = rot * 0.5 + k / 6 * TAU
              line(2.2 + ring * 0.3, cx + math.cos(a0) * rr, RY + math.sin(a0) * rr, cx + math.cos(a0 + 0.8) * rr, RY + math.sin(a0 + 0.8) * rr)
            end
          end
        end
      end
    end
  end

  M.init()
  return M
end
