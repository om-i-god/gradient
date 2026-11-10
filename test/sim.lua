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
    if k == "tweak" then
      TWV[(...)] = select(2, ...)
      if TLOG then TLOG[#TLOG + 1] = {(...), select(2, ...), LOGKEY()} end
    elseif k == "pad_type" and TLOG then TLOG[#TLOG + 1] = {"pad_type", (...), LOGKEY()}
    elseif k == "arp" and TLOG then
      local v = select(7, ...)
      TLOG.arp_max = math.max(TLOG.arp_max or 0, v)
    end
  end
end})
LOGKEY = function() return "?" end
TWV = {}   -- last value sent per tweak key

-- VIS.event calls are counted by kind (evcalls) so the sim can pair them with engine calls
evcalls = {}
function include(p)
  local m = dofile(p .. ".lua")
  if p == "lib/visuals" and m.event then
    local ev = m.event
    m.event = function(kind, ...)
      evcalls[kind] = (evcalls[kind] or 0) + 1
      return ev(kind, ...)
    end
  end
  return m
end

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
local LP = {}
function params:lookup_param(id) LP[id] = LP[id] or {name = id}; return LP[id] end
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
-- SNAP=dir: draw into a real raster and save a frame per theme
local SNAP = os.getenv("SNAP")
local RAST
if SNAP then RAST = dofile("test/raster.lua"); screen = RAST.screen end
_path = {audio = "/home/we/dust/audio/"}
VT = 0   -- virtual seconds, advanced one 16th per drive tick
util = {time = function() return VT end}
_menu = {mode = false}

dofile("gradient.lua")
init()
-- shipped defaults: drums and bass off, glitch subtle
for _, id in ipairs({"kick_style", "bass_style", "hat_style", "perc_style", "clap_style"}) do
  assert(params:get(id) == 3, id .. " should default to never")
end
assert(params:get("glitch_amt") == 2, "glitch should default to subtle")
-- the checks below exercise the full arrangement: put every part on auto
for _, id in ipairs({"kick_style", "bass_style", "hat_style", "perc_style", "clap_style"}) do params:set(id, 1) end
params:set("glitch_amt", 3)
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

local function getS()
  for j = 1, 60 do
    local name, val = debug.getupvalue(key, j)
    if not name then break end
    if name == "S" then return val end
  end
end
-- fills, drums and bass lines over the run so far
do
  local S = getS()
  print(string.format("drums+fills: tom %d shaker %d swell %d glide %d; hats %s bass %s/%s/%s",
    calls.tom or 0, calls.shaker or 0, calls.swell or 0, calls.bass_glide or 0,
    include("lib/gen").HAT_KINDS[S.pat.hats.kind], S.pat.bass_lines[1].kind, S.pat.bass_lines[2].kind,
    S.pat.bass_lines[3].kind))
  -- a filter dip always opens back up on the next bar
  local seen_dip = false
  for i = 1, 16 * 200 do
    tick_all()
    if S.fill == "dip" then seen_dip = true end
    if seen_dip and S.fill ~= "dip" and (S.step % 16) == 1 then
      assert(TWV.pump_lpf == 20000, "filter dip stuck at " .. tostring(TWV.pump_lpf))
      break
    end
  end
  print("dip seen and released:", seen_dip)
  -- fills off: no fills at all
  params:set("fills", 3)
  for i = 1, 16 * 2 do tick_all() end           -- let a fill already rolled finish
  for i = 1, 16 * 64 do tick_all(); assert(not S.fill, "fill with fills = off") end
  params:set("fills", 2)
  local n = 0
  for i = 1, 16 * 64 do tick_all(); if S.fill and S.step % 16 == 1 then n = n + 1 end end
  assert(n > 0, "busy fills never fired")
  params:set("fills", 1)
  print("fills off/busy ok, busy fills in 64 bars:", n)
end


-- timbre: SOUND params, auto picks, fixed wins, seeds keep their drums
do
  local S = getS()
  local TB = include("lib/timbre")
  local CC = include("lib/conductor")
  local want = {
    bass_type  = {"auto", "sub", "reese", "rubber", "fm sub", "tape"},
    chord_type = {"auto", "dub", "felt", "organ", "glass", "rhodes", "choir", "strings"},
    hat_type   = {"auto", "noise", "metal", "dust", "tape"},
    pad_type   = {"auto", "wash", "choir", "strings", "drone", "glass", "tape loop"},
  }
  for id, opts in pairs(want) do
    local d = P.defs[id]
    assert(d and d.v == 1, id .. " missing or not default auto")
    assert(table.concat(d.opts, ",") == table.concat(opts, ","), id .. " options")
  end
  -- VOICE_NAMES: old psets map (soft stays 5), four new voices appended
  local lo = P.defs.lane1_voice.opts
  assert(#lo == 11 and lo[5] == "soft" and lo[9] == "marimba"
    and lo[10] == "steel" and lo[11] == "bowed", "VOICE_NAMES")
  -- round 3: new types appended, old indices unchanged
  local r3 = {
    kick_type  = {"sub", "dusty", "boom", "knock", "deep", "tight"},
    bass_type  = {"auto", "sub", "reese", "rubber", "fm sub", "tape"},
    chord_type = {"auto", "dub", "felt", "organ", "glass", "rhodes", "choir", "strings"},
    hat_type   = {"auto", "noise", "metal", "dust", "tape"},
    pad_type   = {"auto", "wash", "choir", "strings", "drone", "glass", "tape loop"},
    echo_type  = {"dub", "tape", "ping-pong", "space"},
    character  = {"clean", "warm", "dusty"},
  }
  for id, opts in pairs(r3) do
    local d = P.defs[id]
    assert(d, id .. " missing")
    assert(table.concat(d.opts, ",") == table.concat(opts, ","), id .. " options: " .. table.concat(d.opts, ","))
  end
  assert(P.defs.echo_type.v == 1 and P.defs.character.v == 1, "echo_type / character default")
  do
    params:set("echo_type", 3); assert(calls.echo_type and calls.echo_type >= 1, "echo_type sends")
    local n = calls.echo_type
    params:set("echo_type", 1); assert(calls.echo_type == n + 1, "echo_type sends on change")
    params:set("character", 3); assert(TWV.character == 3, "character sends")
    params:set("character", 1); assert(TWV.character == 1, "character sends on change")
    -- a PSET from before round 3 has neither param: a bang sends the defaults
    P.defs.echo_type.v = 1; P.defs.character.v = 1; TWV.character = nil
    local ne = calls.echo_type
    params:bang()
    assert(calls.echo_type == ne + 1 and TWV.character == 1, "defaults not sent on load")
    params:set("kick_type", 6); assert(TWV.kick_type == 6, "kick tight sends"); params:set("kick_type", 1)
  end

  local dump
  dump = function(t)
    if type(t) ~= "table" then return tostring(t) end
    local ks, out = {}, {}
    for k in pairs(t) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(ks) do out[#out + 1] = tostring(k) .. "=" .. dump(t[k]) end
    return "{" .. table.concat(out, ";") .. "}"
  end
  local function drums()
    CC.new_track(S, 4218)
    return dump(S.pat.kick) .. dump(S.pat.clap)
  end
  local real = drums()
  -- the first roll's old-type draws, snapshotted before round 3
  do
    S.seed = 4218; TB.roll(S)
    local o = S.timbre.old
    assert(o and o.bass == 1 and o.chord == 4 and o.hat == 1 and o.pad == 1
      and o.lane[3] == 5 and not o.lane[1] and not o.lane[2] and not o.lane[4]
      and S.timbre.st.x == 1560200712, "old-type draw sequence for seed 4218 changed")
    S.seed = 1; TB.roll(S); o = S.timbre.old
    assert(o.bass == 3 and o.chord == 5 and o.hat == 3 and o.pad == 3 and S.timbre.st.x == 1150234608, "seed 1 old draws")
  end
  local roll = TB.roll
  TB.roll = function() end
  local stubbed = drums()
  TB.roll = roll
  assert(real == stubbed, "timbre changed the drum patterns of seed 4218")
  -- and timbre itself draws nothing from math.random / math.randomseed
  do
    local r, rs, n = math.random, math.randomseed, 0
    math.random = function(...) n = n + 1; return r(...) end
    math.randomseed = function(...) n = n + 1; return rs(...) end
    S.seed = 4218
    TB.roll(S)
    for _ = 1, 50 do TB.phrase(S) end
    math.random, math.randomseed = r, rs
    assert(n == 0, "timbre called math.random " .. n .. " times")
  end
  print("seed 4218: drums identical, timbre drew 0 from math.random")

  -- 512 bars, everything on auto
  CC.new_track(S, 4218)
  for id in pairs(want) do params:set(id, 1) end   -- clears the send caches: first value is logged
  TLOG = {}
  LOGKEY = function() return tostring(S.seed) .. ":" .. ((S.track_bar - 1) // S.phrase_len) end
  local lanes_seen, lanevar = {}, 0
  for i = 1, 16 * 512 do
    tick_all()
    local t = S.timbre
    if t then
      for l = 1, 4 do
        local v = t.lane[l] or 0
        if not lanes_seen[v] then lanes_seen[v] = true; lanevar = lanevar + 1 end
      end
    end
  end
  local log = TLOG; TLOG = nil
  local vals, last, perphrase = {}, {}, {}
  for _, e in ipairs(log) do
    local k, v, key = e[1], e[2], e[3]
    local part = k:match("^(%w+)_type$")
    if part then
      vals[part] = vals[part] or {}
      vals[part][v] = (vals[part][v] or 0) + 1
      assert(v >= 1 and v <= (k == "chord_type" and 7 or k == "pad_type" and 6 or k == "bass_type" and 5 or k == "hat_type" and 4 or 3), k .. " out of range")
      assert(k ~= "pad_type" or v ~= last[k], "pad_type resent unchanged")
      if last[k] ~= nil and last[k] ~= v then
        perphrase[k .. key] = (perphrase[k .. key] or 0) + 1
        assert(perphrase[k .. key] <= 1, k .. " changed twice in a phrase (" .. key .. ")")
      end
      last[k] = v
    end
  end
  local function nd(p) local n = 0; for _ in pairs(vals[p] or {}) do n = n + 1 end; return n end
  local padchg = 0
  for k, n in pairs(perphrase) do if k:find("^pad_type") then padchg = padchg + n end end
  local nchg = 0; for _ in pairs(perphrase) do nchg = nchg + 1 end
  print(string.format("auto picks over 512 bars: distinct bass %d chord %d hat %d pad %d; changes %d; distinct lane voices %d; pad changes %d; max arp voice %d",
    nd("bass"), nd("chord"), nd("hat"), nd("pad"), nchg, lanevar, padchg, log.arp_max or 0))
  assert(nd("bass") >= 2 and nd("chord") >= 2 and nd("hat") >= 2, "auto never varied")
  do
    local lim = {bass = 5, chord = 7, hat = 4, pad = 6}
    local old = {bass = 3, chord = 5, hat = 3, pad = 4}
    local hit = {}
    for part, vs in pairs(vals) do
      for v in pairs(vs) do
        assert(v <= lim[part], part .. " auto picked " .. v)
        if v > old[part] then hit[#hit + 1] = part .. v end
      end
    end
    assert(#hit >= 1, "auto never picked a round 3 type in 512 bars")
    print("round 3 auto picks seen: " .. table.concat(hit, " "))
  end
  assert(lanevar >= 2, "lane voices never varied")
  assert((log.arp_max or 0) >= 5, "no arp voice >= 5 in 512 bars")

  -- a fixed type wins
  TLOG = {}
  LOGKEY = function() return "fixed" end
  params:set("bass_type", 3)
  for i = 1, 16 * 40 do tick_all() end
  local nb = 0
  for _, e in ipairs(TLOG) do
    if e[1] == "bass_type" then nb = nb + 1; assert(e[2] == 2, "fixed bass_type 3 sent " .. e[2]) end
  end
  assert(nb >= 1 and TWV.bass_type == 2, "fixed bass type never sent")
  params:set("bass_type", 1)
  TLOG = nil
  print("timbre ok")
end

-- meter: every meter x feel runs 64 bars; a bar is beats*4 steps; a change
-- lands once, on the phrase boundary; stopped changes land at once
do
  local S = getS()
  local MTm = include("lib/meter")
  local function playing() return S.playing end
  local function stop_play() if S.playing then key(2, 1); key(3, 1); key(3, 0); key(2, 0) end end
  local function start_play() if not S.playing then key(2, 1); key(3, 1); key(3, 0); key(2, 0) end end
  -- run until n bars have started; returns the list of {track_bar, beats, steps in the previous bar}
  local function run_bars(n)
    local out, lastb, lasts = {}, S.track_bar, S.step
    local guard = 0
    while #out < n do
      tick_all(); guard = guard + 1
      assert(guard < n * 28 * 4 + 400, "meter sim stalled")
      if S.track_bar ~= lastb then
        out[#out + 1] = {bar = S.track_bar, beats = S.bar.beats, prev = S.step - lasts, sstep = S.bar_step}
        for _, k in ipairs({"kick", "clap", "hats", "shaker", "rim", "toms", "ride", "ticks", "stabs"}) do
          assert(#S.pat[k] == S.bar.n, string.format("bar %d: %s has %d steps in %d/4", S.track_bar, k, #S.pat[k], S.bar.beats))
        end
        for _, l in ipairs(S.pat.bass_lines) do assert(#l == S.bar.n, "bass line not bar-length") end
        lastb, lasts = S.track_bar, S.step
      end
    end
    return out
  end
  params:set("play_mode", 1)
  params:set("phrase_len", 1)               -- 8 bars
  stop_play()
  assert(not S.playing)
  for mi = 1, #MTm.METERS do
    for fi = 1, #MTm.FEELS do
      params:set("meter", mi); params:set("feel", fi)
      local beats = MTm.METERS[mi]
      assert(S.bar.beats == beats and S.bar.n == beats * 4, "stopped meter change not immediate")
      start_play()
      local bars = run_bars(64)
      for i = 2, #bars do
        assert(bars[i].prev == beats * 4,
          string.format("%d/4 %s: bar %d was %d steps", beats, MTm.FEELS[fi], bars[i].bar, bars[i].prev))
        assert(bars[i].beats == beats, "bar descriptor drifted")
      end
      stop_play()
    end
  end
  print("meters x feels: 64 bars each, bar = beats*4 steps")

  -- three sets mid-phrase: one change, at the next boundary, to the last value
  params:set("meter", 1); params:set("feel", 1)
  start_play()
  run_bars(3)
  while (S.track_bar % 8) ~= 3 do run_bars(1) end
  params:set("meter", 2); params:set("meter", 4); params:set("meter", 3)
  assert(S.bar.beats == 4 and S.meter_pending and S.meter_pending.beats == 5, "pending not held")
  local bars = run_bars(14)
  local changes, prev = 0, 4
  for i, b in ipairs(bars) do
    if b.beats ~= prev then
      changes = changes + 1
      assert(b.beats == 5, "went to " .. b.beats)
      assert(b.bar % 8 == 1, "meter changed mid-phrase at bar " .. b.bar)
      prev = b.beats
    end
    if i > 1 then assert(bars[i].prev == bars[i - 1].beats * 4, "bar cut or doubled at " .. b.bar) end
  end
  assert(changes == 1, "meter changed " .. changes .. " times")
  stop_play()
  params:set("meter", 1); params:set("feel", 1)
  params:set("phrase_len", 3)
  params:set("play_mode", PMODE)
  start_play()
  print("meter change: pending until the phrase boundary, one change")
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
for pg = 1, 5 do
  key(1, 1); enc(2, 1); key(1, 0)
  enc(1, 2); enc(2, -1); enc(3, 1)
end
-- parts page: pick, level, mute, solo; solo silences the rest at once
do
  local S = getS()
  key(1, 1); enc(2, 10); key(1, 0)            -- last page = parts
  enc(2, -10); enc(2, 3)                        -- part 4 = bass
  local lvl = params:get("bass_lvl")
  enc(3, -5)
  assert(params:get("bass_lvl") == lvl - 5, "parts E3 didn't move bass level")
  key(2, 1); key(2, 0)
  assert(S.mute.bass and (S.gain.bass or 0) == 0, "parts K2 didn't mute bass")
  key(2, 1); key(2, 0)
  assert(not S.mute.bass, "parts K2 didn't unmute bass")
  enc(2, 1)                                     -- chords
  key(3, 1); key(3, 0)
  assert(S.solo.chords, "parts K3 didn't solo")
  for _, k in ipairs({"bass", "hats", "lane1", "wash"}) do
    assert((S.gain[k] or 0) == 0, k .. " still sounding under a chords solo")
  end
  assert(not S.on_kick, "kick still on under a chords solo")
  key(2, 1); key(2, 0)                          -- mute chords too, to see both marks
  for i = 1, 16 * 4 do tick_all() end
  if RAST then RAST.snap(SNAP .. "/parts.pgm") end
  key(2, 1); key(2, 0)
  assert((S.gain.hats or 0) == 0, "hats came back under solo")
  key(3, 1); key(3, 0)
  assert(not next(S.solo), "parts K3 didn't unsolo")
  key(2, 1); key(3, 1); key(3, 0); key(2, 0)   -- K2+K3 still play/stop on this page
  assert(not S.playing, "K2+K3 on parts page didn't stop")
  key(2, 1); key(3, 1); key(3, 0); key(2, 0)
  key(1, 1); enc(2, -10); key(1, 0)
  print("parts page ok")
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

-- visuals: every theme drawn under each overlay with the level moving,
-- long enough for echoes, drops and the arc's history to build up
local VISM = include("lib/visuals")
for th = 1, #VISM.names do
  params:set("theme", th)
  for h = 1, 3 do
    params:set("hud", h)
    polls.amp_out_l(h / 3 * 0.3)
    for i = 1, 16 * 4 do tick_all() end
    if RAST and h == 3 then RAST.snap(string.format("%s/%d_%s.pgm", SNAP, th, VISM.names[th])) end
  end
end
print("themes drawn:", #VISM.names)
-- theme cycle actually moves
params:set("hud", 1)
for c = 2, 3 do
  params:set("vis_cycle", c)
  local t0, moved = params:get("theme"), false
  for i = 1, 16 * 40 do tick_all(); if params:get("theme") ~= t0 then moved = true end end
  assert(moved, "theme cycle " .. c .. " never moved")
end
params:set("vis_cycle", 1)
-- bass never: no bass anywhere (engine, midi, crow) once it has faded out
params:set("bass_style", 3)
for i = 1, 16 * 8 do tick_all() end
local function bass_calls() return (calls.bass or 0) + (calls.bass_glide or 0) end
local b0 = bass_calls()
for i = 1, 16 * 64 do tick_all() end
assert(bass_calls() == b0, "bass still playing with bass = never")
print("bass never: silent for 64 bars")
params:set("bass_style", 2)
-- always still waits for the energy; hold it up from the grid's energy row
for bar = 1, 32 do
  grid_dev.key(16, 2, 1)
  for i = 1, 16 do tick_all() end
end
assert(bass_calls() > b0, "bass = always never played")
-- hats never: silent once faded; always: back with the energy held up
params:set("hat_style", 3)
for i = 1, 16 * 8 do tick_all() end
local function hat_calls() return (calls.hat or 0) + (calls.shaker or 0) + (calls.tom or 0) end
local h0 = hat_calls()
for i = 1, 16 * 64 do tick_all() end
assert(hat_calls() == h0, "hats still playing with hats = never")
params:set("hat_style", 2)
for bar = 1, 32 do
  grid_dev.key(16, 2, 1)
  for i = 1, 16 do tick_all() end
end
assert(hat_calls() > h0, "hats = always never played")
print("hats never/always ok")
params:set("hat_style", 1)
-- perc / clap never: silent once faded; glitch off: no ticks, no glitches
for _, c in ipairs({{"perc_style", "perc"}, {"clap_style", "clap"}, {"glitch_amt", "tick", "glitch"}}) do
  params:set(c[1], c[1] == "glitch_amt" and 1 or 3)
  -- the arc re-decides every 4 bars, then a part fades over 4: wait 12+
  for i = 1, 16 * 14 do tick_all() end
  local n0 = (calls[c[2]] or 0) + (calls[c[3] or ""] or 0)
  for bar = 1, 64 do
    grid_dev.key(16, 2, 1)
    for i = 1, 16 do tick_all() end
  end
  assert((calls[c[2]] or 0) + (calls[c[3] or ""] or 0) == n0, c[1] .. " off but still playing")
  params:set(c[1], c[1] == "glitch_amt" and 3 or 1)
end
for _, id in ipairs({"p_stutter", "p_tapestop", "p_reverse", "p_chop"}) do P.defs[id].action() end
for _, x in ipairs({9, 10, 11}) do grid_dev.key(x, 8, 1) end
for _, k in ipairs({"clap", "perc", "tick", "glitch", "ride"}) do
  assert((calls[k] or 0) > 0, k .. " never played")
end
print("perc/clap never, glitch off ok")
local ls = {}
for k, n in pairs(labels) do ls[#ls + 1] = k .. "=" .. n end
table.sort(ls)
print(string.format("harmony: %d bars changed, avg %.1f semitones moved, max %d;  %s",
  changes, changes > 0 and moves / changes or 0, max_leap, table.concat(ls, " ")))

-- 5/4 A: beat ghosts and bar-relative glitch fills
do
  local S = getS()
  S.mute, S.solo = {}, {}
  params:set("fills", 2)
  params:set("glitch_amt", 3)
  params:set("meter", 3); params:set("feel", 2)
  for i = 1, 20 * 64 * 2 do
    if S.bar.beats == 5 and S.bar_step == 1 then break end
    tick_all()
  end
  assert(S.bar.beats == 5 and S.bar.feel == "short-long", "5/4 A never took effect")
  local n = S.bar.n
  local kicks, gls = {}, {}
  local ek, eg = engine.kick, engine.glitch
  engine.kick = function(...)
    kicks[#kicks + 1] = {S.bar_step, (...), S.on_kick, S.kickless}
    return ek(...)
  end
  engine.glitch = function(...)
    gls[#gls + 1] = {S.bar_step, S.fill}
    return eg(...)
  end
  local kl_bars = 0
  key(2, 1); key(2, 0)   -- K2 tap: drop the kick for a stretch
  for i = 1, 20 * 128 do
    S.roll_ghost = false; S.on_ghost = false   -- isolate the beat ghosts
    tick_all()
    if S.bar_step == 2 and S.kickless then kl_bars = kl_bars + 1 end
  end
  engine.kick, engine.glitch = ek, eg
  local full, soft = 0, 0
  for _, k in ipairs(kicks) do
    assert(k[3] and not k[4], "kick or ghost in a kickless/off bar")
    if S.bar.starts[(k[1] - 1) // 4 + 1] then
      assert(math.abs(k[2] - 0.9) < 1e-9, "group start not full velocity: " .. k[2])
      full = full + 1
    else
      assert(math.abs(k[2] - 0.9 * 0.35) < 1e-9, "beat ghost velocity: " .. k[2] .. " at step " .. k[1] .. " n=" .. n)
      assert((k[1] - 1) % 4 == 0, "beat ghost off the beat at step " .. k[1])
      soft = soft + 1
    end
  end
  assert(kl_bars > 0, "no kickless bars to check")
  assert(full > 0 and soft > 0, "no kicks / beat ghosts in 5/4 A")
  local fillg = 0
  for _, g in ipairs(gls) do
    if g[2] == "stutter" or g[2] == "tapestop" or g[2] == "reverse" then
      assert(g[1] >= n - 3, "glitch fill early at step " .. g[1])
      fillg = fillg + 1
    end
  end
  assert(fillg > 0, "no glitch fills in 128 bars of 5/4")
  print(string.format("5/4 A: %d full kicks, %d beat ghosts, %d glitch-fill hits, %d kickless bars",
    full, soft, fillg, kl_bars))
  params:set("fills", 1)
  params:set("meter", 1); params:set("feel", 1)
end

-- 7/4: the swell fires at step n-11 and the dip reaches full at step n-4
do
  local S = getS()
  S.mute, S.solo = {}, {}
  params:set("fills", 2)
  params:set("meter", 4); params:set("feel", 1)
  for i = 1, 28 * 64 * 2 do
    if S.bar.beats == 7 and S.bar_step == 1 then break end
    tick_all()
  end
  assert(S.bar.beats == 7, "7/4 never took effect")
  local n = S.bar.n
  local swells, dips = {}, {}
  local es, et = engine.swell, engine.tweak
  engine.swell = function(...) swells[#swells + 1] = S.bar_step; return es(...) end
  engine.tweak = function(k, v)
    if k == "pump_lpf" and S.fill == "dip" then dips[S.bar_step] = v end
    return et(k, v)
  end
  for i = 1, 28 * 2048 do
    tick_all()
    if #swells > 0 and dips[n - 4] and dips[n - 5] then break end
  end
  engine.swell, engine.tweak = es, et
  assert(#swells > 0, "no swell fills in 2048 bars of 7/4")
  for _, st in ipairs(swells) do assert(st == n - 11, "swell at step " .. st .. ", want " .. (n - 11)) end
  assert(dips[n - 4] and math.abs(dips[n - 4] - 20000 * 0.025) < 1e-6, "dip not full at step n-4")
  assert(dips[n - 5] and dips[n - 5] > dips[n - 4], "dip already full before step n-4")
  print(string.format("7/4: %d swells all at step %d; dip full at step %d", #swells, n - 11, n - 4))
  params:set("fills", 1)
  params:set("meter", 1); params:set("feel", 1)
end

assert((calls.wash_chord or 0) > 0, "no wash chords")
assert((evcalls.pad or 0) == calls.wash_chord,
  string.format("pad events (%d) must match engine.wash_chord calls (%d)", evcalls.pad or 0, calls.wash_chord))
print(string.format("pad events %d == wash_chord calls %d", evcalls.pad, calls.wash_chord))
assert((calls.bass_glide or 0) > 0, "no bass glides")
assert((calls.tom or 0) > 0, "no toms")
local keys = {}
for k in pairs(calls) do keys[#keys+1] = k end
table.sort(keys)
for _, k in ipairs(keys) do print(string.format("  %-12s %d", k, calls[k])) end
print("OK")
