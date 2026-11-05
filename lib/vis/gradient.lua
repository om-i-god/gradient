-- gradient: the chord as soft bands of light at each voice's pitch, seen
-- through a haze over a floor. each band breathes with the pump and swells
-- when its voice is stabbed; calm sections widen and soften them, the peak
-- tightens them. the bass is a glow along the floor and its reflection; the
-- highs are a fine grain in the light; in kickless stretches the bands
-- drift apart and the haze thickens
return function(K)
  local M = {}
  local put, A, clamp = K.put, K.A, K.clamp

  local FLOOR = 56
  local ys = {40, 30, 22, 14}             -- each band's eased row
  local vk = {0, 0, 0, 0}                 -- each voice's stab, eased in
  local bs = 0                            -- the bass glow, eased in

  function M.init() ys = {40, 30, 22, 14}; vk = {0, 0, 0, 0}; bs = 0 end

  function M.draw(S)
    local T, e, c = K.T, K.energy, K.chord
    local breathe = 1 - K.duck * (0.18 + 0.1 * (1 - K.kickless))
    local width = 1.2 + (1 - e) * 1.6 + K.kickless * 0.4
    local loose = 1.5 + (1 - e) * 3 + K.kickless * 3
    -- the chord spread over the sky around its own centre, so voice leading
    -- moves the bands wherever the chord sits
    for i = 1, 4 do
      ys[i] = K.follow(ys[i], K.clamp(27 - (c[i] - (c[1] + c[2] + c[3] + c[4]) / 4) * 2.6, 3, FLOOR - 5), 0.35, K.DT)
      vk[i] = K.follow(vk[i], K.voice_kick[i], 0.05, K.DT)
    end
    -- the highs lift the upper voices
    local hi = A[K.HI]
    -- the bands, in 4-px columns of 2-px cells, equal neighbours merged
    local lv = {}
    for row = 0, FLOOR // 2 - 1 do
      local y = row * 2
      for col = 0, 31 do
        local wob = math.sin(T * 0.6 + col * 0.22) * loose
        local v = 0
        for i = 1, 4 do
          local d = (y - ys[i] - wob * (i % 2 == 0 and 1 or -1)) / width
          v = v + math.exp(-d * d) * (2.2 + i * 0.5) * (1 + vk[i] * 0.45 + (i >= 3 and hi * 0.5 or 0))
        end
        v = v * breathe * (0.75 + 0.35 * A[K.MID])
        -- soft knee: close voices merge into a glow, not a flat slab; the
        -- tails thin to a dither so the black stays black
        local l = 12 * (1 - math.exp(-v * v * 0.045))
        if l >= 1.6 then l = K.B > 0.05 and math.floor(l * K.B + 0.5) / K.B or 0
        elseif l >= 0.8 and (row + col) % 2 == 0 then l = -1
        else l = 0 end
        lv[col] = l
      end
      local run, rl = 0, lv[0]
      for col = 1, 32 do
        local l = lv[col]
        if l ~= rl then
          if rl > 0 then put(rl, run * 4, y, (col - run) * 4, 2)
          elseif rl < 0 then put(1, run * 4, y, (col - run) * 4, 1) end
          run, rl = col, l
        end
      end
    end
    -- the floor: a horizon line, the bass glowing along it and reflected
    bs = K.follow(bs, math.max(K.env.bass, A[K.LO] * 0.8) * (K.gain(S, "bass") > 0 and 1 or 0.4), 0.06, K.DT)
    local bass = bs
    put(2 + bass * 4 + K.bar_pulse * 2, 0, FLOOR, 128, 1)
    K.gradient(FLOOR + 1, 63, function(y)
      local d = y - FLOOR
      return (0.5 + bass * 3.5) * math.exp(-d / (1.5 + bass * 3))
    end)
    -- the bands come back in the floor, broken by the pump
    for i = 1, 4 do
      local l = 1.5 + K.voice_kick[i] * 3
      local off = T * (6 + i * 3) + i * 17
      K.dashes(l * breathe, FLOOR + 2 + i, 3 + i, 10 + i * 2, off)
    end
    -- haze: a light bank low down, heavier with dub and kickless
    K.haze(0, 36, 128, FLOOR, 0.12 + 0.2 * K.dub * K.throw + 0.18 * K.kickless, 1, T * 4)
    -- grain in the light, as much as the highs ask for
    K.grain(function(u, v)
      local i = 1 + math.floor(u * 4) % 4
      return v * 127, ys[i] + (K.rnd() - 0.5) * width * 2
    end, hi * 90, 9)
  end

  M.init()
  return M
end
