-- headless sim: stubs the norns APIs gradient touches, then drives the step
-- clock through several bars and prints the conductor's arc.
-- run from repo root:  lua test/sim.lua [bars] [play_mode] [minutes] [listen] [mode]

local BARS    = tonumber(arg[1]) or 300
local PMODE   = tonumber(arg[2]) or 2
local MINUTES = tonumber(arg[3]) or 4
local LISTEN  = arg[4] == "listen"
local MODE    = tonumber(arg[5])

calls = {}
-- engine stub: every command's arg count is checked against the format
-- string in lib/Engine_Gradient.sc
local FMT = {}
do
  local f = assert(io.open("lib/Engine_Gradient.sc"))
  local src = f:read("a")
  f:close()
  for name, fmt in src:gmatch('addCommand%(\\([%w_]+), "(%w*)"') do FMT[name] = fmt end
  -- tweak keys the engine knows: `st` defaults and fxMap entries (\\key -> ...)
  TWEAKS = {}
  for k in src:gmatch('\\([%w_]+) %->') do TWEAKS[k] = true end
end
engine = setmetatable({}, {__index = function(_, k)
  if k == "name" then return nil end
  return function(...)
    local fmt = FMT[k]
    if not fmt then error("engine has no command '" .. k .. "'", 2) end
    local n = select("#", ...)
    if n ~= #fmt then error(string.format("engine.%s: %d args, engine wants %d (%s)", k, n, #fmt, fmt), 2) end
    for i = 1, n do
      local v, t = select(i, ...), fmt:sub(i, i)
      if (t == "f" or t == "i") and type(v) ~= "number" then error("engine." .. k .. " arg " .. i .. " not a number", 2) end
      if t == "s" and type(v) ~= "string" then error("engine." .. k .. " arg " .. i .. " not a string", 2) end
    end
    if k == "tweak" and not TWEAKS[(...)] then error("engine.tweak: unknown key '" .. (...) .. "'", 2) end
    calls[k] = (calls[k] or 0) + 1
  end
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
function params:add_file(id, _, d) add(id, {v = d}) end
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
function params:lookup_param(id) return {name = id} end
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
          cc = function(_, num, val, ch)
            assert(num >= 0 and num <= 127 and val >= 0 and val <= 127 and ch >= 1 and ch <= 16)
            calls.midi_cc = (calls.midi_cc or 0) + 1
          end,
          start = function() calls.midi_start = (calls.midi_start or 0) + 1 end,
          stop = function() calls.midi_stop = (calls.midi_stop or 0) + 1 end}
end}
-- crow: four outputs that record what they're asked to do
local function crow_out(n)
  local store = {}
  return setmetatable({}, {
    __index = store,
    __newindex = function(_, k, v)
      if k == "volts" then
        assert(type(v) == "number" and v > -5.1 and v < 10.1, "crow volts out of range: " .. tostring(v))
        calls["crow" .. n .. "_v"] = (calls["crow" .. n .. "_v"] or 0) + 1
      end
      store[k] = v
    end,
    __call = function() calls["crow" .. n .. "_fire"] = (calls["crow" .. n .. "_fire"] or 0) + 1 end,
  })
end
crow = {connected = function() return true end,
        output = {crow_out(1), crow_out(2), crow_out(3), crow_out(4)}}
grid_dev = {cols = 16, rows = 8, leds = 0}
function grid_dev:all() end
function grid_dev:led() self.leds = self.leds + 1 end
function grid_dev:refresh() calls.grid_refresh = (calls.grid_refresh or 0) + 1 end
grid = {connect = function() return grid_dev end}
polls = {}
poll = {set = function(name, fn) polls[name] = fn; return {start = function() end} end}
screen = setmetatable({text_extents = function() return 20, 6 end},
  {__index = function() return function() end end})
_path = {audio = "/home/we/dust/audio/"}
VT = 0   -- virtual seconds, advanced one 16th per drive tick
util = {time = function() return VT end}
_menu = {mode = false}

dofile("gradient.lua")
init()
params:set("play_mode", PMODE)
params:set("track_minutes", MINUTES)
params:set("bass_out", 3)
params:set("bass_dev", 2)
params:set("bed_file", "/home/we/dust/audio/hermit_leaves.wav")
params:set("verb_type", 2)
params:set("lane2_voice", 3)
if os.getenv("OUTS") then
  params:set("transport_dev", 2)
  params:set("cc_dev", 2); params:set("cc_energy", 20); params:set("cc_phrase", 21)
  params:set("cc_dub", 22)
  -- crow: bass pitch, lead gate, energy, then pump env / kick trig
  params:set("crow_1", 2); params:set("crow_2", 5); params:set("crow_3", 7)
  params:set("crow_4", tonumber(os.getenv("OUTS")) == 2 and 8 or 9)
end
if os.getenv("ARP") then
  params:set("arp_out", 2); params:set("arp_dev", 2); params:set("arp_lanes", tonumber(os.getenv("ARP")))
end
if os.getenv("HARM") then params:set("harmony", tonumber(os.getenv("HARM"))) end
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
-- harmony trace: semitones the stab voices move per bar, labels heard
local HTRACE = os.getenv("HTRACE")
local prev_chord, moves, changes, max_leap, labels = nil, 0, 0, 0, {}
local function trace_harmony(S)
  local c = S.chord
  for i = 1, 4 do assert(c[i] >= 40 and c[i] <= 88, "stab voice out of range: " .. c[i]) end
  for i = 2, 4 do assert(c[i] > c[i - 1], "doubled stab note at bar " .. S.track_bar) end
  assert(S.bass_pc >= 0 and S.bass_pc < 12, "bass_pc out of range")
  if prev_chord then
    local d = 0
    for i = 1, 4 do d = d + math.abs(c[i] - prev_chord[i]) end
    if d > 0 then changes = changes + 1; moves = moves + d; max_leap = math.max(max_leap, d) end
  end
  prev_chord = {c[1], c[2], c[3], c[4]}
  labels[S.chord_label] = (labels[S.chord_label] or 0) + 1
  if HTRACE then
    print(string.format("  bar %3d %-9s e=%.2f %-8s [%d %d %d %d] bass+%d%s", S.track_bar, S.section,
      S.energy, S.chord_label, c[1], c[2], c[3], c[4], S.bass_pc, S.bass_free and "" or " (inv)"))
  end
end
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
    trace_harmony(S)
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
-- encoder pages
for pg = 1, 4 do
  key(1, 1); enc(2, 1); key(1, 0)
  enc(1, 2); enc(2, -1); enc(3, 1)
end
-- grid: every action, a mute, a step toggle, an energy pull, a new lane
for _, x in ipairs({1, 2, 3, 4, 6, 7, 14}) do grid_dev.key(x, 8, 1); grid_dev.key(x, 8, 0) end
grid_dev.key(1, 3, 1); grid_dev.key(6, 3, 1); grid_dev.key(2, 4, 1)
grid_dev.key(12, 2, 1); grid_dev.key(16, 5, 1); grid_dev.key(15, 6, 1)
-- perform params
for _, id in ipairs({"p_throw", "p_lead_throw", "p_build", "p_break", "p_mutate", "p_drop"}) do
  P.defs[id].action()
end
for i = 1, 16 * 8 do tick_all() end
print("grid leds lit (cumulative):", grid_dev.leds)
local ls = {}
for k, n in pairs(labels) do ls[#ls + 1] = k .. "=" .. n end
table.sort(ls)
print(string.format("harmony: %d bars changed, avg %.1f semitones moved, max %d;  %s",
  changes, changes > 0 and moves / changes or 0, max_leap, table.concat(ls, " ")))

local keys = {}
for k in pairs(calls) do keys[#keys+1] = k end
table.sort(keys)
for _, k in ipairs(keys) do print(string.format("  %-12s %d", k, calls[k])) end
print("OK")
