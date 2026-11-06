// group 2 sound features: kick types, lead voices, reverb swaps, bed load
var e = ~eng, t = 60 / 128 / 4;
~seg.("start");
[1, 2, 3, 4].do { |k|
  e.cmd(\tweak, \kick_type, k);
  4.do { e.cmd(\kick, 0.9, 33, 0.45, 0.3); (t * 4).wait };
  ~seg.("kick" ++ k);
};
1.5.wait; ~seg.("tail");
// percussion voices one at a time, then each glitch mode on a steady loop
[1, 2, 3].do { |k| 4.do { e.cmd(\clap, 0.4, k, 1200, 0); (t * 4).wait }; ~seg.("clap " ++ k) };
[1, 2, 3].do { |k| 6.do { |i| e.cmd(\perc, 0.4, 220 * [1, 1.5].wrapAt(i), 0.25, 0, k); (t * 2).wait }; ~seg.("perc " ++ k) };
4.do { e.cmd(\ride, 0.3, 0.6, 7000, 0); (t * 4).wait }; ~seg.("ride");
[1, 2, 3, 4].do { |k| 8.do { e.cmd(\tick, 0.3, k, 3000, 0); t.wait }; ~seg.("tick " ++ k) };
1.wait; ~seg.("quiet before glitch");
[1, 2, 3, 4, 5].do { |m|
  16.do { |i|
    if(i % 4 == 0, { e.cmd(\kick, 0.9, 33, 0.3, 0.3) });
    if(i % 2 == 1, { e.cmd(\hat, 0.3, 0.05, 8000, 0) });
    if(i == 8, { e.cmd(\glitch, m, t, t * 4, 1) });
    t.wait;
  };
  ~seg.("glitch mode " ++ m);
};
1.wait; ~seg.("after glitch");
[1, 2, 3, 4].do { |v|
  8.do { |i| e.cmd(\arp, 440 * [1, 1.5, 2].wrapAt(i), 0.15, 0.25, 3000, 0, 0.5, v); t.wait };
  ~seg.("arp voice " ++ v);
  1.wait; ~seg.("tail");
};
e.cmd(\tweak, \verb_size, 0.7);
e.cmd(\tweak, \chord_echo, 0);
[2, 3, 1, 3].do { |v|
  e.cmd(\verb_type, v);
  0.1.wait;
  e.cmd(\chord, 220, 261, 329, 392, 0.3, 0.2); 0.3.wait;
  ~seg.("dry stab, verb " ++ v);
  2.wait;
  ~seg.("verb tail " ++ v);
};
3.wait; ~seg.("quiet");
e.cmd(\tweak, \bed_amp, 0.4);
e.cmd(\tweak, \bed_lpf, 3000);
e.cmd(\bed, "/System/Library/Sounds/Submarine.aiff");
1.5.wait; ~seg.("bed 1");
e.cmd(\bed, "/nope/missing.wav");
e.cmd(\bed, "/System/Library/Sounds/Glass.aiff");
1.5.wait; ~seg.("bed 2");
("CHECK nodes " ++ s.numSynths).postln;
