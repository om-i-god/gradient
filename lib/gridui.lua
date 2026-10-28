-- gradient / grid
-- a 16x8 performance surface. reads conductor state, writes through the
-- action table the main script hands in (A).
--
-- row 1    phrase: where we are in the phrase (8-bar blocks marked)
-- row 2    energy: lit to the current level; press to pull energy there
-- row 3    parts: K H R B C 1 2 3 4 . wash noise bed   (press = mute)
-- row 4-7  arp lanes 1-4: the lane's steps, playhead bright
--          press a step to toggle it; col 15 = mute, col 16 = new lane
-- row 8    actions: 1 drop  2 mutate  3 throw  4 lead throw
--                   6 break  7 build    14 new track  16 play/stop

local GU = {}

GU.PARTS = {"kick", "hats", "rim", "bass", "chords", "lane1", "lane2", "lane3", "lane4",
            false, "wash", "noise", "bed"}

local g, A
local flash = {}          -- "x,y" -> time of last press, for a press blink

function GU.init(actions)
  A = actions
  g = grid.connect()
  g.key = function(x, y, z) GU.key(x, y, z) end
end

local function cols() return (g and g.cols and g.cols > 0) and g.cols or 16 end

function GU.key(x, y, z)
  if z == 0 then return end
  local S = A.S
  flash[x .. "," .. y] = util.time()
  if y == 2 then
    A.set_energy((x - 1) / (cols() - 1))
  elseif y == 3 then
    local k = GU.PARTS[x]
    if k then A.toggle_mute(k) end
  elseif y >= 4 and y <= 7 then
    local i = y - 3
    local l = S.lanes[i]
    if x == 16 then A.new_lane(i)
    elseif x == 15 then A.toggle_mute("lane" .. i)
    elseif l and x <= l.len then A.toggle_step(i, x) end
  elseif y == 8 then
    local act = ({[1] = "drop", [2] = "mutate", [3] = "throw", [4] = "lead_throw",
                  [6] = "brk", [7] = "build", [14] = "fresh", [16] = "play"})[x]
    if act then A[act]() end
  end
end

function GU.redraw()
  if not g then return end
  local S = A.S
  local now = util.time()
  local w = cols()
  g:all(0)

  -- row 1: phrase position
  local P = S.phrase_len or 32
  local bar_in = S.track_bar % P
  local cells = math.min(w, P)
  local per = P / cells
  local cur = math.floor(bar_in / per) + 1
  for x = 1, cells do
    local edge = (((x - 1) * per) % 8) == 0
    g:led(x, 1, x == cur and (S.playing and 15 or 6) or (x < cur and 4 or (edge and 3 or 1)))
  end

  -- row 2: energy
  local lit = math.floor(S.energy * (w - 1) + 0.5) + 1
  for x = 1, w do
    g:led(x, 2, x <= lit and (x == lit and 12 or 5) or 1)
  end

  -- row 3: parts
  local m = S.mute or {}
  for x, k in ipairs(GU.PARTS) do
    if k then
      local on
      if k == "kick" then on = S.on_kick and 1 or 0
      else on = S.gain[k] or 0 end
      g:led(x, 3, m[k] and 2 or (4 + math.floor(on * 11)))
    end
  end

  -- rows 4-7: lanes
  for i = 1, 4 do
    local l = S.lanes[i]
    if l then
      local y = 3 + i
      for x = 1, l.len do
        local idx = l.seq[x] or 0
        local lvl = idx > 0 and 3 + math.min(idx, 6) or 0
        if x == l.pos and S.playing then lvl = (idx > 0) and 15 or 4 end
        g:led(x, y, lvl)
      end
      g:led(15, y, m["lane" .. i] and 2 or 6 + math.floor((S.gain["lane" .. i] or 0) * 6))
      g:led(16, y, 3)
    end
  end

  -- row 8: actions (blink on press, held states lit)
  local lv = {
    [1] = (S.drop_bars or 0) > 0 and 15 or 5,
    [2] = 5, [3] = (S.hand_throw or 0) > 0 and 15 or 5,
    [4] = (S.lead_throw or 0) > 0 and 15 or 5,
    [6] = 4, [7] = 4, [14] = 3,
    [16] = S.playing and 12 or 4,
  }
  for x, v in pairs(lv) do
    if x <= w then g:led(x, 8, v) end
  end

  -- press blink
  for key, t in pairs(flash) do
    if now - t < 0.12 then
      local x, y = key:match("(%d+),(%d+)")
      g:led(tonumber(x), tonumber(y), 15)
    else
      flash[key] = nil
    end
  end

  g:refresh()
end

return GU
