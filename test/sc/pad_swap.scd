// rapid pad swaps: ten pad_type sends inside a second, then after the
// crossfade has finished there must be exactly one pad node left
var e = ~eng;
var count = nil, resp;
if(e.commands[\pad_type].isNil, { "ERROR: no pad_type command".postln });
e.cmd(\wash_chord, 110, 130.8, 164.8, 196);
e.cmd(\tweak, \wash_amp, 0.3);
10.do { |i| e.cmd(\pad_type, (i % 4) + 1); 0.1.wait };
9.wait;
resp = OSCFunc({ |msg|
  count = msg.count { |x|
    var str = x.asString;
    (str == "grad_wash") or: { str.beginsWith("grad_pad_") }
  };
}, '/g_queryTree.reply', s.addr).oneShot;
s.sendMsg("/g_queryTree", 0, 0);
1.wait;
("PADS " ++ count).postln;
if(count != 1, { "PAD FAIL".postln });
