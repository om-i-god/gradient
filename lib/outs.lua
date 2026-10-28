-- gradient / outs
-- everything that leaves norns besides notes: midi transport, crow cv,
-- midi cc. the main script calls the hooks; params live here.
--
-- crow outputs are assignable: pitches are 1V/oct with C3 (midi 48) at 0V,
-- gates are 8V, energy is 0-5V, the pump is a 5V ar envelope per beat.

local O = {}

O.CROW_NAMES = {"off", "bass pitch", "bass gate", "lead pitch", "lead gate",
                "chord root", "energy", "kick trig", "pump env"}
local CROW_FOR = {bass = {2, 3}, lead = {4, 5}, chord = {6, nil}}  -- pitch, gate

local devs = {}          -- "transport" / "cc" -> midi device
local gate_id = {0, 0, 0, 0}
local cc_last = {}

local function crow_ok()
  return crow ~= nil and (crow.connected == nil or crow.connected())
end

local function out_mode(n) return params:get("crow_" .. n) end

-- prepare an output for its job when the assignment changes
local function crow_assign(n, m)
  if not crow_ok() then return end
  local o = crow.output[n]
  o.slew  = 0
  o.volts = 0
  if m == 8 then
    o.action = "pulse(0.01, 8)"
  elseif m == 7 then
    o.slew = 0.5
  end
end

function O.setup_params(vport_names, vport_ids)
  local function dev_param(key, id, name)
    params:add_option(id, name, vport_names, 1)
    params:set_action(id, function(v)
      local pid = vport_ids[v]
      devs[key] = (pid and pid > 0) and midi.connect(pid) or nil
    end)
  end

  params:add_separator("SYNC OUT")
  dev_param("transport", "transport_dev", "midi start/stop to")
  -- clock pulses themselves come from PARAMS > CLOCK > midi out

  params:add_separator("CROW")
  for n = 1, 4 do
    params:add_option("crow_" .. n, "out " .. n, O.CROW_NAMES, 1)
    params:set_action("crow_" .. n, function(m) crow_assign(n, m) end)
  end
  params:add_number("crow_lead_lane", "lead lane", 1, 4, 1)
  params:add_control("crow_slew", "pitch slew", controlspec.new(0, 0.5, "lin", 0.005, 0, "s"))
  params:add_number("crow_oct", "pitch octave", -3, 3, 0)

  params:add_separator("CC OUT")
  dev_param("cc", "cc_dev", "midi device")
  params:add_number("cc_ch", "channel", 1, 16, 16)
  -- 0 = off
  params:add_number("cc_energy", "energy cc", 0, 127, 0)
  params:add_number("cc_dub", "dub cc", 0, 127, 0)
  params:add_number("cc_tone", "tone cc", 0, 127, 0)
  params:add_number("cc_phrase", "phrase pulse cc", 0, 127, 0)
end

------------------------------------------------------------------------
-- transport
------------------------------------------------------------------------

function O.start()
  if devs.transport then devs.transport:start() end
end

function O.stop()
  if devs.transport then devs.transport:stop() end
  if crow_ok() then
    for n = 1, 4 do
      local m = out_mode(n)
      if m == 3 or m == 5 then crow.output[n].volts = 0 end
    end
  end
end

------------------------------------------------------------------------
-- crow
------------------------------------------------------------------------

-- kind: "bass" / "lead" / "chord"; lane: which arp lane (lead only)
function O.note(kind, note, dur, lane)
  if not crow_ok() then return end
  if kind == "lead" and lane ~= params:get("crow_lead_lane") then return end
  local pm, gm = CROW_FOR[kind][1], CROW_FOR[kind][2]
  local volts = (note - 48) / 12 + params:get("crow_oct")
  for n = 1, 4 do
    local m = out_mode(n)
    if m == pm then
      crow.output[n].slew  = params:get("crow_slew")
      crow.output[n].volts = volts
    elseif gm and m == gm then
      gate_id[n] = gate_id[n] + 1
      local id = gate_id[n]
      crow.output[n].volts = 8
      clock.run(function()
        clock.sleep(math.max(0.01, dur))
        if gate_id[n] == id then crow.output[n].volts = 0 end
      end)
    end
  end
end

function O.kick()
  if not crow_ok() then return end
  for n = 1, 4 do
    if out_mode(n) == 8 then crow.output[n]() end
  end
end

function O.pump(beat)
  if not crow_ok() then return end
  for n = 1, 4 do
    if out_mode(n) == 9 then
      crow.output[n].action = string.format("ar(0.005, %.3f, 5)", beat * 0.55)
      crow.output[n]()
    end
  end
end

------------------------------------------------------------------------
-- once a bar: energy cv + ccs
------------------------------------------------------------------------

local function cc(num, val)
  if num == 0 or not devs.cc then return end
  val = math.max(0, math.min(127, math.floor(val + 0.5)))
  if cc_last[num] == val then return end
  cc_last[num] = val
  devs.cc:cc(num, val, params:get("cc_ch"))
end

function O.bar(S, phrase_start)
  if crow_ok() then
    for n = 1, 4 do
      if out_mode(n) == 7 then crow.output[n].volts = S.energy * 5 end
    end
  end
  cc(params:get("cc_energy"), S.energy * 127)
  cc(params:get("cc_dub"), params:get("dub") * 1.27)
  cc(params:get("cc_tone"), params:get("tone") * 1.27)
  local pc = params:get("cc_phrase")
  if pc > 0 and devs.cc then
    cc(pc, phrase_start and 127 or 0)
  end
end

return O
