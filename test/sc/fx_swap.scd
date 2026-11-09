// rapid echo_type and character swaps under a running loop. two bursts of
// ten echo_type sends (0.1 s apart, a character tweak with each), 2.5 s
// apart: each burst coalesces into one echo swap, and the second lands
// while the first one's old echo is still fading. the live dub-echo node
// count (every grad_echo* node minus the lead echo, which is never swapped)
// is sampled every 0.25 s and must never exceed 2; after the fades exactly
// one must be left. the output must stay alive throughout, the lead echo
// must be the same node, and the echo's remembered settings must reach the
// new echo. any problem prints a line with FAIL
var e = ~eng, t = 60 / 128 / 4;
var count = nil, maxSeen = 0, samples = 0, resp, sampler, loop, lead0, dead = 0, peaks = List.new;
var countEchoes = { |msg|
  (msg.count { |x| x.asString.beginsWith("grad_echo") }) - 1
};
if(e.commands[\echo_type].isNil, { "CHECK FAIL: no echo_type command".postln });
lead0 = e.instVarAt(\leadSynth).nodeID;
resp = OSCFunc({ |msg|
  count = countEchoes.(msg);
  maxSeen = maxSeen.max(count);
  samples = samples + 1;
}, '/g_queryTree.reply', s.addr);
sampler = fork { loop { s.sendMsg("/g_queryTree", 0, 0); 0.25.wait } };
e.cmd(\tweak, \echo_time, 0.3);
e.cmd(\tweak, \echo_fb, 0.6);
e.cmd(\wash_chord, 110, 130.8, 164.8, 196);
e.cmd(\tweak, \wash_amp, 0.2);
// the loop: kick, hats, a chord stab and a rim into the echo every bar
loop = fork { inf.do { |i|
  if(i % 4 == 0, { e.cmd(\kick, 0.9, 33, 0.45, 0.3); e.cmd(\pump, 1) });
  if(i % 2 == 1, { e.cmd(\hat, 0.3, 0.05, 8000, 0) });
  if(i % 16 == 3, { e.cmd(\chord, 220, 261, 329, 392, 0.3, 0.2) });
  if(i % 8 == 6, { e.cmd(\rim, 0.3, 1700, -0.3) });
  t.wait;
} };
// per half second: the output peak must never fall silent
~liveMon = fork { loop {
  s.sync;
  ~meter.set(\t_reset, 1);
  0.5.wait;
  s.sync;
  peaks.add(~mbus.getSynchronous);
} };
1.wait;
// burst 1 ends on echo type 2 (tape) and character 1; burst 2 on type 3
// (ping-pong) and character 3
10.do { |i| e.cmd(\echo_type, (i % 4) + 1); e.cmd(\tweak, \character, (i % 3) + 1); 0.1.wait };
2.5.wait;
10.do { |i| e.cmd(\echo_type, ((i + 1) % 4) + 1); e.cmd(\tweak, \character, ((i + 2) % 3) + 1); 0.1.wait };
6.wait;
sampler.stop;
0.3.wait;
resp.free;
s.sendMsg("/g_queryTree", 0, 0);
OSCFunc({ |msg| count = countEchoes.(msg) }, '/g_queryTree.reply', s.addr).oneShot;
0.5.wait;
("CHECK echoes max " ++ maxSeen ++ " over " ++ samples ++ " samples, " ++ count ++ " at the end").postln;
if(maxSeen > 2, { ("CHECK FAIL: " ++ maxSeen ++ " echo nodes at once").postln });
if(maxSeen < 2, { "CHECK FAIL: never saw an echo crossfade (no swap?)".postln });
if(count != 1, { "CHECK FAIL: expected 1 echo node at the end".postln });
if(e.instVarAt(\echoDef) != \grad_echo_pingpong, { ("CHECK FAIL: last echo swap landed on " ++ e.instVarAt(\echoDef)).postln });
// the lead echo is never touched
if(e.instVarAt(\leadSynth).nodeID != lead0, { "CHECK FAIL: lead echo was replaced".postln });
// the remembered echo settings reached the new echo
e.instVarAt(\fx)[\echo].get(\time, { |v| ~gotTime = v });
e.instVarAt(\fx)[\echo].get(\fb, { |v| ~gotFb = v });
0.5.wait;
("CHECK echo time " ++ ~gotTime ++ " fb " ++ ~gotFb).postln;
if(((~gotTime ? 0) - 0.3).abs > 0.001, { "CHECK FAIL: echo_time not re-sent after a swap".postln });
if(((~gotFb ? 0) - 0.6).abs > 0.001, { "CHECK FAIL: echo_fb not re-sent after a swap".postln });
loop.stop;
~liveMon.stop;
("CHECK live peaks min " ++ peaks.minItem.round(0.0001) ++ " max " ++ peaks.maxItem.round(0.001)
  ++ " over " ++ peaks.size).postln;
peaks.do { |p| if(p.isNaN or: { p < 0.01 }, { dead = dead + 1 }) };
if(dead > 0, { ("CHECK FAIL: output dead or NaN in " ++ dead ++ " half-second windows").postln });
// the meter reads the L+R sum, so full scale on both sides is 2
if(peaks.maxItem > 1.95, { "CHECK FAIL: output over full scale".postln });
// settle back to the defaults
e.cmd(\echo_type, 1);
e.cmd(\tweak, \character, 1);
e.cmd(\tweak, \wash_amp, 0);
4.wait;
