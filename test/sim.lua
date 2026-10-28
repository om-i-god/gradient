-- headless sim: stubs the norns APIs gradient touches, then drives the step
-- clock through several bars and prints the conductor's arc.
-- run from repo root:  lua test/sim.lua [bars] [play_mode] [minutes] [listen] [mode]

local BARS    = tonumber(arg[1]) or 300
local PMODE   = tonumber(arg[2]) or 2
local MINUTES = tonumber(arg[3]) or 4
local LISTEN  = arg[4] == "listen"
local MODE    = tonumber(arg[5])

calls = {}
engine = setmetatable({}, {__index = function(_, k)
  return function(...) calls[k] = (calls[k] or 0) + 1 end
end})

function include(p) return dofile(p .. ".lua") end

-- params ---------------------------------------------------------------
local P = {order = {}, defs = {}}
params = {}
local function add(id, def) def.id = id; P.defs[id] = def; table.insert(P.order, id) end
function params:add_separator() end
function params:add_option(id, _, opts, d) add(id, {v = d, lo = 1, hi = #opts, opts = opts}) end
function params:add_number(id, _, lo, hi, d) add(id, {v = d, lo = lo, hi = hi}) end
function params:add_control(id, _, spec) add(id, {v = spec.default, lo = spec.min, hi = spec.max, f = true}) end
function params:add_trigger(id) add(id, {v = 0, trig = true}) end
function params:set_action(id, fn) P.defs[id].action = fn end
function params:get(id)
  if id == "clock_tempo" then return 128 end
  return P.defs[id].v
end
function params:string(id) local d = P.defs[id]; return d.opts and d.opts[d.v] or tostring(d.v) end
function params:set(id, v, silent)
  if id == "clock_tempo" then return end
  local d = P.defs[id]; d.v = v
  if not silent and d.action then d.action(v) end
end
function params:delta(id, n)
  if id == "clock_tempo" then return end
  local d = P.defs[id]
  if d.trig then return end
  params:set(id, math.max(d.lo, math.min(d.hi, d.v + n * (d.f and 0.01 or 1))))
end
function params:bang()
  for _, id in ipairs(P.order) do
    local d = P.defs[id]
    if d.action and not d.trig then d.action(d.v) end
  end
end
controlspec = {new = function(min, max, _, _, default) return {min = min, max = max, default = default} end}

-- clock ------------------------------------------------------------------
local threads, nid = {}, 0
clock = {transport = {}}
function clock.run(f) nid = nid + 1; threads[nid] = coroutine.create(f); return nid end
function clock.cancel(id) threads[id] = nil end
function clock.sync() coroutine.yield() end
function clock.sleep() coroutine.yield("sleep") end
function clock.get_beat_sec() return 60 / 128 end
function clock.get_tempo() return 128 end

-- misc -------------------------------------------------------------------
midi = {vports = {{name = "fake synth"}}, connect = function()
  return {note_on = function(_, n, v, ch)
            calls.midi_on = (calls.midi_on or 0) + 1
            local k = "ch" .. ch; calls[k] = (calls[k] or 0) + 1
          end,
          note_off = function() calls.midi_off = (calls.midi_off or 0) + 1 end,
          cc = function() calls.midi_cc = (calls.midi_cc or 0) + 1 end}
end}
polls = {}
poll = {set = function(name, fn) polls[name] = fn; return {start = function() end} end}
screen = setmetatable({text_extents = function() return 20, 6 end},
  {__index = function() return function() end end})
VT = 0   -- virtual seconds, advanced one 16th per drive tick
util = {time = function() return VT end}
_menu = {mode = false}

dofile("gradient.lua")
init()
params:set("play_mode", PMODE)
params:set("track_minutes", MINUTES)
params:set("bass_out", 3)
params:set("bass_dev", 2)
if os.getenv("ARP") then
  params:set("arp_out", 2); params:set("arp_dev", 2); params:set("arp_lanes", tonumber(os.getenv("ARP")))
end
if LISTEN then params:set("listen_on", 2) end
if MODE then params:set("mode", MODE) end

-- fake KeyTrack feed by bar: E minor (16), G major (7 -> rel. E minor),
-- silence, then D minor (14)
local function feed(bar)
  if bar < 24 then return 16, 0.1
  elseif bar < 48 then return 7, 0.1
  elseif bar < 60 then return 0, 0.0001
  else return 14, 0.1 end
end
local last_root

-- K2+K3 = play
key(2, 1); key(3, 1); key(3, 0); key(2, 0)

-- drive: resume every live thread until the step clock has run BARS bars.
-- step clock is thread 2 (draw loop is 1); note-off threads come and go.
local last_bar, steps = -1, 0
local function tick_all()
  VT = VT + 60 / 128 / 4
  for id, co in pairs(threads) do
    if coroutine.status(co) == "dead" then threads[id] = nil
    else
      local ok, err = coroutine.resume(co)
      if not ok then error("thread " .. id .. ": " .. tostring(err)) end
    end
  end
end

local log_every = 8
local bars_seen = 0
for i = 1, BARS * 16 * 3 do
  tick_all()
  if bars_seen >= BARS then break end
  -- peek at conductor state via the debug upvalue of key()
  local S
  for j = 1, 60 do
    local name, val = debug.getupvalue(key, j)
    if not name then break end
    if name == "S" then S = val end
  end
  if LISTEN and S then
    local k, a = feed(S.track_bar)
    if math.random() < 0.15 then k = math.random(0, 23) end   -- tracker noise
    polls.in_key(k); polls.in_amp(a)
    if S.root_pc ~= last_root then
      print(string.format("  >> root now %d at bar %d (bar-in-phrase %d)  pending=%s",
        S.root_pc, S.track_bar, S.track_bar % 8, tostring(S.pending_root)))
      last_root = S.root_pc
    end
  end
  if S and S.track_bar ~= last_bar then
    last_bar = S.track_bar
    bars_seen = bars_seen + 1
    if S.track_bar % log_every == 0 then
      local parts = {}
      for _, k in ipairs({"lane1","lane2","lane3","lane4","chords","rim","hats","bass"}) do
        parts[#parts+1] = string.format("%s=%.2f", k:sub(1,2) .. k:sub(-1), S.gain[k] or 0)
      end
      print(string.format("bar %4d  %-9s e=%.2f kick=%-5s pump=%-5s kl=%-5s %s  chord=%d seed=%s play=%s",
        S.track_bar, S.section, S.energy, tostring(S.on_kick), tostring(S.on_pump),
        tostring(S.kickless), table.concat(parts, " "), S.chord_degree, tostring(S.seed),
        tostring(S.playing)))
    end
    if not S.playing then print("stopped at bar", S.track_bar) break end
  end
end

-- poke the performance controls mid-run
enc(1, 10); enc(2, 5); enc(3, -5)
key(2, 1); key(2, 0)  -- drop
key(3, 1); key(3, 0)  -- mutate
enc(1, 1)
key(2, 1); enc(2, 3); enc(3, 1); key(2, 0)   -- key change while held (no drop)
key(3, 1); enc(2, 2); enc(3, 1); key(3, 0)   -- bpm / mode while held
key(1, 1); enc(1, 1); key(1, 0)
for i = 1, 16 * 8 do tick_all() end

local keys = {}
for k in pairs(calls) do keys[#keys+1] = k end
table.sort(keys)
for _, k in ipairs(keys) do print(string.format("  %-12s %d", k, calls[k])) end
print("OK")
