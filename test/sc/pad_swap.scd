// rapid pad swaps. two bursts of ten pad_type sends (0.1 s apart), 2.5 s
// apart: each burst coalesces into one swap, and the second swap lands
// while the first swap's old pad is still fading, so the "free the oldest
// fading pad at once" path runs. the live pad-node count is sampled every
// 0.25 s throughout and must never exceed 2 (PAD FAIL); after the fades
// exactly one pad must be left (PADS 1)
var e = ~eng;
var count = nil, maxSeen = 0, samples = 0, resp, sampler;
var countPads = { |msg|
  msg.count { |x|
    var str = x.asString;
    (str == "grad_wash") or: { str.beginsWith("grad_pad_") }
  }
};
if(e.commands[\pad_type].isNil, { "ERROR: no pad_type command".postln });
resp = OSCFunc({ |msg|
  count = countPads.(msg);
  maxSeen = maxSeen.max(count);
  samples = samples + 1;
}, '/g_queryTree.reply', s.addr);
sampler = fork { loop { s.sendMsg("/g_queryTree", 0, 0); 0.25.wait } };
e.cmd(\wash_chord, 110, 130.8, 164.8, 196);
e.cmd(\tweak, \wash_amp, 0.3);
// burst 1 ends on type 2; burst 2 ends on type 4
10.do { |i| e.cmd(\pad_type, (i % 4) + 1); 0.1.wait };
2.5.wait;
10.do { |i| e.cmd(\pad_type, ((i + 2) % 4) + 1); 0.1.wait };
// the second swap lands ~0.25 s after burst 2; its old pad goes 7 s later
9.wait;
sampler.stop;
0.3.wait;
resp.free;
s.sendMsg("/g_queryTree", 0, 0);
OSCFunc({ |msg| count = countPads.(msg) }, '/g_queryTree.reply', s.addr).oneShot;
0.5.wait;
("PADS max " ++ maxSeen ++ " over " ++ samples ++ " samples").postln;
if(maxSeen > 2, { ("PAD FAIL: " ++ maxSeen ++ " pad nodes at once").postln });
if(maxSeen < 2, { "PAD FAIL: never saw a crossfade (no swap?)".postln });
("PADS " ++ count).postln;
if(count != 1, { "PAD FAIL".postln });
