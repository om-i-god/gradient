-- gradient / listen
-- turns the engine's KeyTrack poll into a steady key to follow.
-- votes decay over ~10s; a major key counts toward its relative minor
-- (same pitch set, and gradient's harmony is minor-modal), so the tally is
-- per minor root pitch class. a new root is only proposed once it has led
-- for `hold` seconds with a clear share of the vote.

local L = {}

local DECAY = 0.985   -- per 0.25s tick -> ~0.94/s, half-life ~11s

function L.reset()
  L.votes  = {}
  for pc = 0, 11 do L.votes[pc] = 0 end
  L.leader = nil     -- minor root pc currently winning
  L.since  = 0       -- time it took the lead
  L.share  = 0       -- leader's fraction of all votes
  L.total  = 0
  L.heard  = false   -- input above gate on the last tick
  L.raw    = nil     -- last raw KeyTrack value (0..23)
end
L.reset()

-- KeyTrack 0..11 = C..B major, 12..23 = C..B minor -> minor root pc
function L.minor_root(k)
  if k >= 12 then return k - 12 end
  return (k + 9) % 12          -- relative minor sits a major 6th up
end

-- call every 0.25s with the latest poll values
function L.tick(key, amp, gate, now)
  local total = 0
  for pc = 0, 11 do
    L.votes[pc] = L.votes[pc] * DECAY
  end
  L.heard = amp > gate
  if L.heard and key then
    local k = math.floor(key + 0.5)
    if k >= 0 and k <= 23 then
      L.raw = k
      local pc = L.minor_root(k)
      L.votes[pc] = L.votes[pc] + 1
    end
  end
  local best, best_v = nil, 0
  for pc = 0, 11 do
    total = total + L.votes[pc]
    if L.votes[pc] > best_v then best, best_v = pc, L.votes[pc] end
  end
  L.total = total
  L.share = (total > 0) and (best_v / total) or 0
  if best ~= L.leader then
    L.leader = best
    L.since  = now
  end
end

-- returns a minor root pc to move to, or nil
function L.proposal(current_pc, hold, now)
  if L.leader == nil or L.leader == current_pc then return nil end
  if L.total < 6 then return nil end            -- ~a few seconds of signal
  if L.share < 0.4 then return nil end
  if now - L.since < hold then return nil end
  return L.leader
end

return L
