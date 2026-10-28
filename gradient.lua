-- gradient
-- generative dub / kickless techno
-- press play and let it ride
--
-- E1-E3: the current page
--   play: energy nudge / dub / tone
--   lead: send / feedback / time
--   sound: kick tune / stab cutoff / pump
--   space: reverb / echo wow / swing
-- K2 tap: drop (kickless)
-- K3 tap: mutate now
-- K2+K3: play / stop
-- hold K2: E2 key  E3 mode
-- hold K3: E2 bpm  E3 set/track
-- hold K1: E1 visual theme  E2 page
-- grid: see lib/gridui.lua
--
-- params > LISTEN > follow input key:
-- tracks the key of the audio input
-- and moves with it on phrase edges
--
-- v0.1

engine.name = "Gradient"

local T   = include("lib/theory")
local G   = include("lib/gen")
local C   = include("lib/conductor")
local H   = include("lib/harmony")
local VIS = include("lib/visuals")
local L   = include("lib/listen")
local GU  = include("lib/gridui")
local O   = include("lib/outs")

local ECHO_DIVS      = {0.5, 0.75, 1, 1.5}          -- in beats
local ECHO_DIV_NAMES = {"1/8", "3/16", "1/4", "3/8"}
local LEAD_DIVS      = {0.25, 1/3, 0.5, 0.75, 2/3, 1, 1.5, 2}
local LEAD_DIV_NAMES = {"1/16", "1/8T", "1/8", "3/16", "1/4T", "1/4", "3/8", "1/2"}
local OUT_NAMES      = {"internal", "midi", "both"}
local VOICE_NAMES    = {"auto", "classic", "bell", "pluck", "soft"}

------------------------------------------------------------------------
-- state
------------------------------------------------------------------------

local S = {
  playing = false, step = 0, track_bar = 0,
  energy = 0, nudge = 0, dub = 0.5,
  section = "-", progress = 0, total_bars = nil,
  root_pc = 9, mode = 1, voicing = 1, harmony = 3,
  mode_play = 1, track_minutes = 8, end_action = 2, kick_style = 1, bass_style = 1,
  pat = {}, lanes = {}, gain = {}, want = {}, jitter = {},
  chord = {57, 60, 64, 67}, chord_degree = 1, pair = {1, 1}, harm_bars = 4,
  bass_pc = 0, bass_free = true, chord_root_pc = 0, chord_label = "i",
  on_kick = false, on_pump = false, kickless = false,
  drop_bars = 0, phrase_len = 32, force_mutate = false, freeze = false, throw = false,
  cycle_bars = 96,
  follow = false, pending_root = nil,
  mute = {}, hand_throw = 0, lead_throw = 0,
}

local main_clock, draw_clock, listen_clock
local in_key, in_amp = nil, 0
local loop_gen = 0        -- bumps on each start; stale step loops exit
local k1, k2, k3 = false, false, false
local k2_used, k3_used = false, false
local theme = 1
local page  = 1
local msg, msg_t = nil, 0
local audio_level_smooth = 0

local midi_dev = {}        -- part -> midi device
local hanging  = {}        -- "part:ch:note" -> {dev, ch, note, id}
local note_id  = 0

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function mtof(n) return 440 * 2 ^ ((n - 69) / 12) end

-- what makes the visuals jump (VISUALS > react to)
local VIS_REACT = {"kick + stabs", "kick", "stabs", "arps", "bass", "everything"}
local REACT_TO = {
  {kick = true, stab = true}, {kick = true}, {stab = true}, {arp = true}, {bass = true},
  {kick = true, stab = true, arp = true, bass = true},
}
local function vis_hit(src)
  local r = params:get("vis_react")
  if not REACT_TO[r][src] then return end
  -- terrain rolls on the kick; on the default setting stabs only push it
  -- when the kick is out
  if r == 1 and src == "stab" and theme == 1 and S.on_kick then return end
  VIS.trigger(theme)
end

-- VISUALS > theme cycle: a new random theme on a bar edge / phrase / track
local function cycle_theme(edge)
  if params:get("vis_cycle") ~= edge or #VIS.names < 2 then return end
  local n = theme
  while n == theme do n = math.random(#VIS.names) end
  params:set("theme", n)
end

local function flash(text)
  msg, msg_t = text, util.time()
end

------------------------------------------------------------------------
-- engine helpers
------------------------------------------------------------------------

local tweak_cache = {}
local function tweak(k, v)
  if tweak_cache[k] ~= v then
    tweak_cache[k] = v
    engine.tweak(k, v)
  end
end

------------------------------------------------------------------------
-- midi out
------------------------------------------------------------------------

local function midi_note(part, note, vel, dur, ch)
  local dev = midi_dev[part]
  if not dev then return end
  ch = ch or params:get(part .. "_ch")
  local v   = clamp(math.floor(vel * 127), 1, 127)
  local key = part .. ":" .. ch .. ":" .. note
  note_id = note_id + 1
  local id = note_id
  dev:note_on(note, v, ch)
  hanging[key] = {dev, ch, note, id}
  clock.run(function()
    clock.sleep(dur)
    if hanging[key] and hanging[key][4] == id then
      dev:note_off(note, 0, ch)
      hanging[key] = nil
    end
  end)
end

local function all_notes_off()
  for k, h in pairs(hanging) do
    h[1]:note_off(h[3], 0, h[2])
    hanging[k] = nil
  end
  for _, part in ipairs({"bass", "chord", "arp"}) do
    local dev = midi_dev[part]
    if dev then
      local ch = params:get(part .. "_ch")
      -- arp "own ch each" spans ch..ch+3
      local n = (part == "arp" and params:get("arp_lanes") == 6) and 3 or 0
      for c = ch, math.min(16, ch + n) do dev:cc(123, 0, c) end
    end
  end
end

local function routes(part)
  local o = params:get(part .. "_out")
  return (o == 1 or o == 3), (o == 2 or o == 3)
end

------------------------------------------------------------------------
-- bar-rate macros: energy + user knobs -> engine
------------------------------------------------------------------------

local function apply_bar()
  local e    = S.energy
  local dub  = params:get("dub") / 100
  local tone = params:get("tone") / 100
  S.dub = dub
  local beat = clock.get_beat_sec()

  local throwing = S.throw or S.hand_throw > 0
  tweak("echo_time", ECHO_DIVS[params:get("echo_div")] * beat)
  local fb = 0.32 + dub * 0.45
  if throwing then fb = math.min(0.93, fb + 0.28) end
  tweak("echo_fb", fb)

  -- lead delay: only the hand throw touches it
  local lthrow = S.lead_throw > 0
  tweak("lead_time", LEAD_DIVS[params:get("lead_div")] * beat)
  tweak("lead_fb", lthrow and 0.92 or params:get("lead_fb") / 100)
  tweak("arp_lead", math.min(1, params:get("lead_send") / 100 + (lthrow and 0.45 or 0)))
  tweak("echo_lpf", 1100 + tone * 2600 + e * 1200)
  tweak("echo_hpf", 250 + (1 - dub) * 300)
  tweak("chord_echo", 0.28 + dub * 0.5 + (throwing and 0.35 or 0))
  tweak("rim_echo",   0.15 + dub * 0.55)
  tweak("arp_echo",   params:get("lead_dub") == 2 and (0.08 + dub * 0.25) or 0)
  tweak("hat_echo",   dub * 0.12)

  tweak("chord_cutoff", params:get("chord_cutoff") * (0.5 + tone) * (0.55 + e * 0.6))
  tweak("bass_cutoff",  params:get("bass_cutoff") * (0.8 + e * 0.4))
  tweak("pump_depth", params:get("pump_depth") / 100 * (0.5 + e * 0.5))
  tweak("pump_rel", beat * 0.55)

  local wash = params:get("wash_lvl") / 100 * (S.gain.wash or 0)
  tweak("wash_amp", wash * (0.18 + (S.kickless and 0.3 or 0) + (1 - e) * 0.18))
  tweak("wash_cutoff", 350 + tone * 900 + e * 600)
  local noise = params:get("noise_lvl") / 100 * (S.gain.noise or 0)
  tweak("noise_amp", noise * (0.05 + (1 - e) * 0.06))
  local bed = params:get("bed_lvl") / 100 * (S.gain.bed or 0)
  tweak("bed_amp", bed * (0.3 + (1 - e) * 0.3 + (S.kickless and 0.2 or 0)))

  if S.chord_changed then
    S.chord_changed = false
    local c = S.chord
    engine.wash_chord(mtof(c[1] - 12), mtof(c[2] - 12), mtof(c[3]), mtof(c[4]))
  end
end

------------------------------------------------------------------------
-- one 16th step
------------------------------------------------------------------------

local start, stop

local function play_step()
  local s = (S.step % 16) + 1

  if s == 1 then
    if S.hand_throw > 0 then S.hand_throw = S.hand_throw - 1 end
    if S.lead_throw > 0 then S.lead_throw = S.lead_throw - 1 end
    local r = C.bar(S)
    if r == "next" or S.key_moved then
      S.key_moved = false
      params:set("root", S.root_pc + 1, true)
      params:set("mode", S.mode, true)
      params:set("seed", S.seed or params:get("seed"), true)
      local label = T.name(S.root_pc, S.mode)
      if r == "next" then label = "new track " .. S.seed
      elseif S.follow then label = "in key " .. label end
      flash(label)
    end
    apply_bar()
    O.bar(S, (S.track_bar - 1) % S.phrase_len == 0)
    if (S.track_bar - 1) % 8 == 0 then cycle_theme(2) end
    if (S.track_bar - 1) % S.phrase_len == 0 then cycle_theme(3) end
    if r == "next" then cycle_theme(4) end
    if r == "stop" then
      stop(true)
      flash("track end")
      return
    end
  end

  local e    = S.energy
  local beat = clock.get_beat_sec()

  -- kick + ghost pump
  if S.pat.kick[s] > 0 then
    if S.on_pump then
      engine.pump(1)
      O.pump(beat)
    end
    if S.on_kick then
      engine.kick(0.9, params:get("kick_tune"), params:get("kick_decay") / 100, 0.15 + e * 0.2)
      O.kick()
      vis_hit("kick")
    end
  end

  -- hats: offbeat spine always (when on); 16th ghosts thin with energy
  local hg, hv = S.gain.hats or 0, S.pat.hats[s]
  if hg > 0 and hv > 0 then
    local spine = (s - 1) % 4 == 2
    if spine or math.random() < 0.2 + e * 0.7 then
      engine.hat(hv * hg * 0.3, spine and (0.05 + e * 0.09) or 0.03,
        6500 + e * 4500, (math.random() - 0.5) * 0.5)
    end
  end

  -- rim
  local rg, rv = S.gain.rim or 0, S.pat.rim[s]
  if rg > 0 and rv > 0 then
    engine.rim(rv * rg * 0.25, 1500 + math.random(0, 500), (math.random() - 0.5) * 0.8)
  end

  -- chord stabs
  local cg, cv = S.gain.chords or 0, S.pat.stabs[s]
  if cg > 0 and cv > 0 then
    local amp = cv * cg * 0.32
    local dur = 0.1 + (1 - e) * 0.25
    local internal, ext = routes("chord")
    local c = S.chord
    if internal then
      engine.chord(mtof(c[1]), mtof(c[2]), mtof(c[3]), mtof(c[4]), amp, dur)
    end
    if ext then
      for i = 1, 4 do midi_note("chord", c[i], cv * cg, beat * 0.5) end
    end
    vis_hit("stab")
    O.note("chord", 48 + S.root_pc + S.chord_root_pc, dur)
  end

  -- bass: chord root, its 3rd / 5th, or a tonic pedal (lib/harmony)
  local bg, bv = S.gain.bass or 0, S.pat.bass[s]
  if bg > 0 and bv[1] > 0 then
    local base = 12 * (params:get("bass_oct") + 1) + S.root_pc
    local iv = bv[2]
    if not S.bass_free and (iv == 7 or iv == 10) then iv = 12 end
    local note = base + S.bass_pc + iv
    local dur  = beat * 0.25 * (1.2 + (1 - e) * 1.2)
    local internal, ext = routes("bass")
    if internal then engine.bass(mtof(note), bv[1] * bg * 0.55, dur) end
    if ext then midi_note("bass", note, bv[1] * bg, dur) end
    O.note("bass", note, dur)
    vis_hit("bass")
  end

  -- phasing arp lanes: always tick so phase relationships persist in silence
  local tone = params:get("tone") / 100
  local bar_f = S.track_bar + (s - 1) / 16
  local arp_int, arp_ext = routes("arp")
  local arp_sel = params:get("arp_lanes")   -- 1 all, 2-5 one lane, 6 own ch each
  for i = 1, 4 do
    local l = S.lanes[i]
    l.tick = l.tick + 1
    if (l.tick - 1) % l.div == 0 then
      l.pos = (l.pos % l.len) + 1
      local g   = S.gain["lane" .. i] or 0
      local idx = l.seq[l.pos] or 0
      if g > 0 and idx > 0 and math.random() < l.prob then
        local note = G.lane_note(l, S.chord, idx)
        local lfo  = math.sin(bar_f / l.lfo_bars * 2 * math.pi + l.lfo_phase)
        local cut  = l.cutoff * (0.4 + tone * 1.2) * (0.65 + 0.35 * lfo) * (0.6 + e * 0.6)
        local vel = g * (0.7 + math.random() * 0.3)
        local dur = l.decay * (0.6 + e * 0.6)
        O.note("lead", note, dur, i)
        vis_hit("arp")
        local ext = arp_ext and (arp_sel == 1 or arp_sel == 6 or arp_sel == i + 1)
        if ext then
          local ch = (arp_sel == 6) and math.min(16, params:get("arp_ch") + i - 1) or nil
          midi_note("arp", note, vel, dur, ch)
        end
        -- lanes not picked for midi keep sounding on norns
        if arp_int or not ext then
          local v = params:get("lane" .. i .. "_voice")
          engine.arp(mtof(note), 0.13 * vel, dur, clamp(cut, 150, 12000), l.pan, l.shapeX,
            v == 1 and (l.voice or 1) or v - 1)
        end
      end
    end
  end

  S.step = S.step + 1
end

------------------------------------------------------------------------
-- input key follow
------------------------------------------------------------------------

local function listen_loop()
  while true do
    clock.sleep(0.25)
    if S.follow then
      local now  = util.time()
      local gate = 10 ^ (params:get("listen_gate") / 20)
      L.tick(in_key, in_amp, gate, now)
      -- the vote is in minor roots; keep the chosen mode and move its root
      -- onto the heard notes
      local m  = L.proposal(T.minor_of(S.root_pc, S.mode), params:get("listen_hold"), now)
      local pc = m and T.root_for(m, S.mode)
      if pc and pc ~= S.pending_root then
        if S.playing then
          S.pending_root = pc           -- conductor lands it on the next 8-bar edge
        else
          S.root_pc = pc
          C.update_chord(S)
          params:set("root", pc + 1, true)
          flash("in key " .. T.name(pc, S.mode))
        end
      end
    end
  end
end

------------------------------------------------------------------------
-- transport
------------------------------------------------------------------------

local function loop(my)
  clock.sync(4)
  if S.playing and my == loop_gen then O.start() end
  S.step = 0
  while true do
    clock.sync(1 / 4)
    local swing = params:get("swing") / 100
    if S.step % 2 == 1 and swing > 0 then
      clock.sleep(clock.get_beat_sec() * 0.25 * swing)
    end
    if not S.playing or my ~= loop_gen then return end
    play_step()
  end
end

start = function()
  if S.playing then return end
  S.playing = true
  loop_gen = loop_gen + 1
  local my = loop_gen
  main_clock = clock.run(function() loop(my) end)
  flash("play")
end

-- from_loop: called inside the step clock, which exits on its own once
-- S.playing is false (don't cancel the running coroutine from within)
stop = function(from_loop)
  S.playing = false
  if main_clock and not from_loop then clock.cancel(main_clock) end
  main_clock = nil
  all_notes_off()
  O.stop()
  tweak("wash_amp", 0)
  tweak("noise_amp", 0)
  tweak("bed_amp", 0)
  flash("stop")
end

local function new_track(seed, move_key)
  C.new_track(S, seed, move_key)
  params:set("seed", seed, true)
  params:set("root", S.root_pc + 1, true)
  params:set("mode", S.mode, true)
  S.energy = 0
  apply_bar()
end

------------------------------------------------------------------------
-- controls
------------------------------------------------------------------------

local function drop()
  if S.drop_bars > 0 then
    S.drop_bars = 0
    flash("return")
  else
    S.drop_bars = 16 - (S.track_bar % 8)   -- rest of this 8 and the next
    flash("drop")
  end
  C.decide(S)
end

local function mutate()
  S.force_mutate = true
  C.mutate(S)
  flash("mutate")
end

-- dub throw by hand: rest of this bar and the next, on the main echo
local function throw()
  S.hand_throw = 2
  apply_bar()
  flash("throw")
end

local function lead_throw()
  S.lead_throw = 2
  apply_bar()
  flash("lead throw")
end

-- push the arc; both relax back with the nudge (~16 bars)
local function build()
  S.drop_bars = 0
  S.nudge = clamp(S.nudge + 0.25, -1, 1)
  C.decide(S)
  flash("build")
end

local function brk()
  S.nudge = clamp(S.nudge - 0.35, -1, 1)
  S.drop_bars = 16 - (S.track_bar % 8)
  C.decide(S)
  flash("break")
end

local function toggle_play()
  if S.playing then stop() else start() end
end

local function set_energy(target)
  local base = S.energy - S.nudge
  S.nudge = clamp(target - base, -1, 1)
  S.energy = clamp(base + S.nudge, 0, 1)
  C.decide(S)
end

local function toggle_mute(k)
  S.mute[k] = not S.mute[k] or nil
  C.decide(S)
  flash((S.mute[k] and "mute " or "unmute ") .. k)
end

local function fresh()
  new_track(math.random(1, 9999), true)
  flash("new track " .. S.seed)
end

local function toggle_step(i, x)
  local l = S.lanes[i]
  if (l.seq[x] or 0) > 0 then l.seq[x] = 0 else l.seq[x] = math.random(1, 6) end
end

local function new_lane(i)
  local old = S.lanes[i]
  S.lanes[i] = G.lane(i)
  S.lanes[i].tick = old.tick
  flash("new lane " .. i)
end

-- encoder pages: {param id, step multiplier}; "_energy" is the nudge
local PAGES = {
  {name = "play",  {"_energy", 1}, {"dub", 1},          {"tone", 1}},
  {name = "lead",  {"lead_send", 1}, {"lead_fb", 1},    {"lead_div", 1}},
  {name = "sound", {"kick_tune", 1}, {"chord_cutoff", 25}, {"pump_depth", 1}},
  {name = "space", {"verb_size", 1}, {"echo_wow", 1},   {"swing", 1}},
}

function key(n, z)
  if n == 1 then
    k1 = z == 1
  elseif n == 2 then
    if z == 1 then
      k2, k2_used = true, false
      if k3 then
        if S.playing then stop() else start() end
        k2_used, k3_used = true, true
      end
    else
      k2 = false
      if not k2_used then drop() end
    end
  elseif n == 3 then
    if z == 1 then
      k3, k3_used = true, false
      if k2 then
        if S.playing then stop() else start() end
        k2_used, k3_used = true, true
      end
    else
      k3 = false
      if not k3_used then mutate() end
    end
  end
end

function enc(n, d)
  if k1 and n == 1 then
    params:delta("theme", d)
  elseif k1 and n == 2 then
    page = clamp(page + d, 1, #PAGES)
    flash("page " .. PAGES[page].name)
  elseif k1 then
    return
  elseif k2 then
    k2_used = true
    if n == 2 then params:delta("root", d)
    elseif n == 3 then params:delta("mode", d) end
    flash(T.name(S.root_pc, S.mode))
  elseif k3 then
    k3_used = true
    if n == 2 then
      params:delta("clock_tempo", d)
      flash(math.floor(clock.get_tempo() + 0.5) .. " bpm")
    elseif n == 3 then
      params:delta("play_mode", d)
      flash(params:string("play_mode"))
    end
  else
    local id, mult = PAGES[page][n][1], PAGES[page][n][2]
    if id == "_energy" then
      S.nudge = clamp(S.nudge + d * 0.03, -0.6, 0.6)
      flash(string.format("energy %+d", math.floor(S.nudge * 100 + 0.5)))
    else
      params:delta(id, d * mult)
      flash(params:lookup_param(id).name .. " " .. params:string(id))
    end
  end
end

------------------------------------------------------------------------
-- screen
------------------------------------------------------------------------

local PART_KEYS  = {"kick", "hats", "rim", "bass", "chords", "lane1", "lane2", "lane3", "lane4"}
local PART_GLYPH = {"K", "H", "R", "B", "C", "1", "2", "3", "4"}

local function text_box(x, y, s, lvl, right)
  local w = screen.text_extents(s)
  local x0 = right and (x - w) or x
  screen.level(0)
  screen.rect(x0 - 1, y - 6, w + 2, 8)
  screen.fill()
  screen.level(lvl)
  screen.move(x0, y)
  screen.text(s)
end

local function draw_hud()
  -- overlay: 1 full, 2 minimal (key + chord), 3 off (hints and messages only)
  local hud = params:get("hud")

  -- top: key / section
  local top = T.name(S.root_pc, S.mode, true)
  if k1 then top = VIS.names[theme] .. " " .. theme .. "/" .. #VIS.names end
  if hud < 3 or k1 then text_box(1, 7, top, S.playing and 12 or 4) end
  -- second line: the chord (roman, "/i" = over a tonic pedal), then the page
  if not k1 and (hud < 3 or page ~= 1) then
    local sub = S.chord_label
    if page ~= 1 then sub = sub .. "  " .. PAGES[page].name end
    text_box(1, 15, sub, page ~= 1 and 6 or 5)
  end

  if hud == 1 then
    local sec = S.section or "-"
    if S.mode_play == 2 and S.total_bars then
      sec = sec .. " " .. math.floor(S.progress * 100) .. "%"
    end
    if S.kickless and S.playing then sec = sec .. " ~" end
    text_box(127, 7, sec, S.playing and 8 or 3, true)

    -- listening: what the input sounds like, and where we're headed
    if S.follow then
      local s
      if not L.heard then
        s = "listening"
      elseif L.leader then
        s = "in " .. T.NOTE_NAMES[L.leader + 1] .. "m " .. math.floor(L.share * 100) .. "%"
      else
        s = "in ?"
      end
      if S.pending_root then s = s .. " >" .. T.NOTE_NAMES[S.pending_root + 1] end
      text_box(127, 15, s, L.heard and 7 or 3, true)
    end

    -- bottom: energy bar + parts
    screen.level(0)
    screen.rect(0, 55, 128, 9)
    screen.fill()
    screen.level(2)
    screen.rect(1, 59, 40, 3)
    screen.fill()
    local ew = math.floor(S.energy * 40 + 0.5)
    if ew > 0 then
      screen.level(S.nudge ~= 0 and 15 or 10)
      screen.rect(1, 59, ew, 3)
      screen.fill()
    end

    for i, k in ipairs(PART_KEYS) do
      local on
      if k == "kick" then
        on = S.on_kick and 1 or (S.on_pump and 0.3 or 0)
      else
        on = S.gain[k] or 0
      end
      screen.level(math.floor(1 + on * 13))
      screen.move(46 + (i - 1) * 9, 63)
      screen.text(PART_GLYPH[i])
    end
  end

  -- held-key hints, then transient messages
  local hint
  if k1 then hint = "E1 theme  E2 page: " .. PAGES[page].name
  elseif k2 and not k3 then hint = "E2 key  E3 mode"
  elseif k3 and not k2 then hint = "E2 bpm  E3 " .. params:string("play_mode") end
  if hint then
    text_box(64 - screen.text_extents(hint) / 2, 34, hint, 15)
  elseif msg and util.time() - msg_t < 1.5 then
    text_box(64 - screen.text_extents(msg) / 2, 34, msg, 15)
  end

  if not S.playing then
    text_box(127, 52, "K2+K3 play", 4, true)
  end
end

local function draw_loop()
  local n = 0
  while true do
    clock.sleep(1 / 20)
    n = n + 1
    if n % 4 ~= 0 then GU.redraw() end
    if not _menu.mode then
      screen.clear()
      screen.aa(0)
      VIS.draw(theme)
      draw_hud()
      screen.update()
    end
  end
end

------------------------------------------------------------------------
-- params
------------------------------------------------------------------------

local function setup_params()
  local vport_names = {"none"}
  local vport_ids   = {0}
  for i = 1, #midi.vports do
    local n = midi.vports[i].name
    if n ~= nil and n ~= "none" and n ~= "" then
      table.insert(vport_names, i .. ":" .. n)
      table.insert(vport_ids, i)
    end
  end

  params:add_separator("GRADIENT")
  params:add_option("play_mode", "play mode", {"set (endless)", "track"}, 1)
  params:set_action("play_mode", function(v)
    S.mode_play = v
    if v == 2 then S.track_bar = 0 end
  end)
  params:add_option("phrase_len", "phrase length (bars)", {"8", "16", "32", "64"}, 3)
  params:set_action("phrase_len", function(v)
    local old = S.phrase_len
    S.phrase_len = ({8, 16, 32, 64})[v]
    S.cycle_bars = math.floor(S.cycle_bars * S.phrase_len / old)
  end)
  params:add_number("track_minutes", "track length (min)", 4, 32, 8)
  params:set_action("track_minutes", function(v) S.track_minutes = v end)
  params:add_option("end_action", "track end", {"stop", "next track"}, 2)
  params:set_action("end_action", function(v) S.end_action = v end)
  params:add_option("kick_style", "kick", {"auto", "always", "never"}, 1)
  params:set_action("kick_style", function(v) S.kick_style = v end)
  params:add_option("bass_style", "bass", {"auto", "always", "never"}, 1)
  params:set_action("bass_style", function(v) S.bass_style = v end)
  params:add_option("freeze", "freeze material", {"off", "on"}, 1)
  params:set_action("freeze", function(v) S.freeze = v == 2 end)
  params:add_number("seed", "seed", 1, 9999, 1)
  params:add_trigger("regen", "> rebuild from seed")
  params:set_action("regen", function()
    new_track(params:get("seed"), false)
    flash("seed " .. params:get("seed"))
  end)
  params:add_trigger("fresh", "> new random track")
  params:set_action("fresh", fresh)

  params:add_separator("PERFORM")
  for _, a in ipairs({{"p_play", "> play / stop", toggle_play}, {"p_drop", "> drop", drop},
                      {"p_mutate", "> mutate", mutate}, {"p_throw", "> throw", throw},
                      {"p_lead_throw", "> lead throw", lead_throw},
                      {"p_build", "> build", build}, {"p_break", "> break", brk}}) do
    params:add_trigger(a[1], a[2])
    params:set_action(a[1], a[3])
  end

  params:add_separator("KEY")
  params:add_option("root", "root", T.NOTE_NAMES, 10)
  params:set_action("root", function(v) S.root_pc = v - 1; C.update_chord(S) end)
  params:add_option("mode", "mode", T.MODE_NAMES, 1)
  params:set_action("mode", function(v) S.mode = v; C.update_chord(S) end)
  params:add_option("harmony", "harmony", H.NAMES, 3)
  params:set_action("harmony", function(v) S.harmony = v; C.reharm(S) end)
  local vnames = {table.unpack(T.VOICING_NAMES)}
  vnames[H.AUTO] = "auto (energy)"
  params:add_option("voicing", "chord voicing", vnames, H.AUTO)
  params:set_action("voicing", function(v) S.voicing = v; C.reharm(S) end)
  params:add_number("bass_oct", "bass octave", 0, 2, 1)

  params:add_separator("LISTEN")
  params:add_option("listen_on", "follow input key", {"off", "on"}, 1)
  params:set_action("listen_on", function(v)
    S.follow = v == 2
    S.pending_root = nil
    L.reset()
    engine.listen(S.follow and 1 or 0)
  end)
  params:add_number("listen_gate", "input gate (dB)", -70, -10, -45)
  params:add_number("listen_hold", "hold before move (s)", 2, 60, 10)

  params:add_separator("MIX")
  params:add_number("dub", "dub", 0, 100, 50)
  params:add_number("tone", "tone", 0, 100, 50)
  params:add_option("echo_div", "echo time", ECHO_DIV_NAMES, 2)
  params:add_number("swing", "swing %", 0, 50, 6)
  params:add_number("pump_depth", "pump depth", 0, 100, 55)
  params:add_control("level", "level", controlspec.new(0, 1, "lin", 0.01, 0.8))
  params:set_action("level", function(v) engine.tweak("level", v) end)
  params:add_control("drive", "drive", controlspec.new(0, 1, "lin", 0.01, 0.2))
  params:set_action("drive", function(v) engine.tweak("drive", v) end)
  params:add_control("verb_size", "reverb size", controlspec.new(0, 1, "lin", 0.01, 0.88))
  params:set_action("verb_size", function(v) engine.tweak("verb_size", v) end)
  params:add_option("verb_type", "reverb type", {"hall", "plate", "spring"}, 1)
  params:set_action("verb_type", function(v) engine.verb_type(v) end)
  params:add_control("echo_wow", "echo wow", controlspec.new(0, 1, "lin", 0.01, 0.3))
  params:set_action("echo_wow", function(v) engine.tweak("echo_wow", v) end)

  params:add_separator("LEAD DELAY")
  params:add_number("lead_send", "send", 0, 100, 30)
  params:set_action("lead_send", function() apply_bar() end)
  params:add_option("lead_div", "time", LEAD_DIV_NAMES, 4)
  params:add_number("lead_fb", "feedback", 0, 95, 45)
  params:set_action("lead_fb", function() apply_bar() end)
  params:add_control("lead_lpf", "tone", controlspec.new(500, 12000, "exp", 0, 4500, "Hz"))
  params:set_action("lead_lpf", function(v) engine.tweak("lead_lpf", v) end)
  params:add_control("lead_hpf", "low cut", controlspec.new(40, 2000, "exp", 0, 350, "Hz"))
  params:set_action("lead_hpf", function(v) engine.tweak("lead_hpf", v) end)
  params:add_control("lead_pp", "ping-pong", controlspec.new(0, 1, "lin", 0.01, 0.85))
  params:set_action("lead_pp", function(v) engine.tweak("lead_pp", v) end)
  params:add_control("lead_wow", "wow", controlspec.new(0, 1, "lin", 0.01, 0.1))
  params:set_action("lead_wow", function(v) engine.tweak("lead_wow", v) end)
  params:add_control("lead_sat", "saturation", controlspec.new(0, 1, "lin", 0.01, 0.2))
  params:set_action("lead_sat", function(v) engine.tweak("lead_sat", v) end)
  params:add_control("lead_verb", "to reverb", controlspec.new(0, 1, "lin", 0.01, 0.25))
  params:set_action("lead_verb", function(v) engine.tweak("lead_verb", v) end)
  params:add_option("lead_dub", "arps also to dub echo", {"off", "on"}, 2)

  params:add_separator("BED")
  params:add_file("bed_file", "file", _path.audio)
  params:set_action("bed_file", function(path)
    if path and path ~= "" and path ~= "-" and path:sub(-1) ~= "/" then engine.bed(path) end
  end)
  params:add_number("bed_lvl", "level", 0, 150, 60)
  params:add_control("bed_tone", "tone", controlspec.new(300, 12000, "exp", 0, 4000, "Hz"))
  params:set_action("bed_tone", function(v) engine.tweak("bed_lpf", v) end)
  params:add_control("bed_speed", "speed", controlspec.new(0.25, 2, "exp", 0, 1, "x"))
  params:set_action("bed_speed", function(v) engine.tweak("bed_rate", v) end)
  params:add_control("bed_verb", "to reverb", controlspec.new(0, 1, "lin", 0.01, 0.35))
  params:set_action("bed_verb", function(v) engine.tweak("bed_verb", v) end)

  params:add_separator("LEVELS")
  for _, p in ipairs({{"kick", 100}, {"hat", 100}, {"rim", 100}, {"bass", 100},
                      {"chord", 100}, {"arp", 100}}) do
    params:add_number(p[1] .. "_lvl", p[1] .. " level", 0, 150, p[2])
    params:set_action(p[1] .. "_lvl", function(v) engine.tweak(p[1] .. "_lvl", v / 100) end)
  end
  params:add_number("wash_lvl", "wash level", 0, 150, 100)
  params:add_number("noise_lvl", "noise level", 0, 150, 100)
  params:add_control("crackle", "crackle", controlspec.new(0, 1, "lin", 0.01, 0.3))
  params:set_action("crackle", function(v) engine.tweak("noise_crackle", v) end)

  params:add_separator("SOUND")
  params:add_number("kick_tune", "kick tune", 24, 45, 33, function(p)
    local n = p:get()
    return string.format("%s%d  %.1f Hz", T.NOTE_NAMES[n % 12 + 1], n // 12 - 1,
      440 * 2 ^ ((n - 69) / 12))
  end)
  params:add_option("kick_type", "kick type", {"sub", "dusty"}, 1)
  params:set_action("kick_type", function(v) engine.tweak("kick_type", v) end)
  params:add_number("kick_decay", "kick decay", 15, 120, 45)
  params:add_number("chord_cutoff", "stab cutoff", 300, 5000, 1400)
  params:add_control("chord_res", "stab resonance", controlspec.new(0, 1, "lin", 0.01, 0.35))
  params:set_action("chord_res", function(v) engine.tweak("chord_res", v) end)
  params:add_control("chord_detune", "stab detune", controlspec.new(0, 1, "lin", 0.01, 0.18))
  params:set_action("chord_detune", function(v) engine.tweak("chord_detune", v) end)
  params:add_number("bass_cutoff", "bass cutoff", 80, 1200, 260)
  for i = 1, 4 do
    params:add_option("lane" .. i .. "_voice", "lane " .. i .. " voice", VOICE_NAMES, 1)
  end

  for _, part in ipairs({"bass", "chord", "arp"}) do
    params:add_separator(string.upper(part) .. " OUT")
    params:add_option(part .. "_out", "output", OUT_NAMES, 1)
    params:set_action(part .. "_out", function() all_notes_off() end)
    params:add_option(part .. "_dev", "midi device", vport_names, 1)
    params:set_action(part .. "_dev", function(v)
      all_notes_off()
      local id = vport_ids[v]
      midi_dev[part] = (id and id > 0) and midi.connect(id) or nil
    end)
    params:add_number(part .. "_ch", "midi channel", 1, 16, ({bass = 1, chord = 2, arp = 3})[part])
  end
  params:add_option("arp_lanes", "lanes to midi",
    {"all (one ch)", "lane 1", "lane 2", "lane 3", "lane 4", "own ch each"}, 1)
  params:set_action("arp_lanes", function() all_notes_off() end)

  O.setup_params(vport_names, vport_ids)

  params:add_separator("VISUALS")
  params:add_option("theme", "theme", VIS.names, 1)
  params:set_action("theme", function(v) theme = v; VIS.init(v) end)
  params:add_option("vis_cycle", "theme cycle", {"off", "every 8 bars", "every phrase", "each track"}, 1)
  params:add_option("vis_react", "react to", VIS_REACT, 1)
  params:add_option("hud", "overlay", {"full", "minimal", "off"}, 1)
  params:add_number("vis_speed",      "speed",      1, 10,  3)
  params:add_number("vis_brightness", "brightness", 1, 15, 10)
  params:add_number("num_particles",  "particles",  5, 40, 20)
  params:set_action("num_particles",  function() VIS.init(theme) end)
end

------------------------------------------------------------------------
-- lifecycle
------------------------------------------------------------------------

function init()
  setup_params()
  params:bang()

  math.randomseed(os.time())
  new_track(math.random(1, 9999), false)
  VIS.init(theme)

  local amp_poll = poll.set("amp_out_l", function(val)
    if val > audio_level_smooth then
      audio_level_smooth = audio_level_smooth * 0.2 + val * 0.8
    else
      audio_level_smooth = audio_level_smooth * 0.92 + val * 0.08
    end
    VIS.audio_level = math.min(1.0, audio_level_smooth * 5)
  end)
  amp_poll.time = 1 / 30
  amp_poll:start()

  local key_poll = poll.set("in_key", function(v) in_key = v end)
  key_poll.time = 1 / 4
  key_poll:start()
  local in_amp_poll = poll.set("in_amp", function(v) in_amp = v end)
  in_amp_poll.time = 1 / 4
  in_amp_poll:start()
  listen_clock = clock.run(listen_loop)

  clock.transport.start = function() start() end
  clock.transport.stop  = function() stop() end

  GU.init({
    S = S, drop = drop, mutate = mutate, throw = throw, lead_throw = lead_throw,
    build = build, brk = brk, play = toggle_play,
    fresh = fresh,
    set_energy = set_energy, toggle_mute = toggle_mute,
    toggle_step = toggle_step, new_lane = new_lane,
  })

  draw_clock = clock.run(draw_loop)
end

function cleanup()
  stop()
  if draw_clock then clock.cancel(draw_clock) end
  if listen_clock then clock.cancel(listen_clock) end
end
