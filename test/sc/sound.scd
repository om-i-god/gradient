// group 2 sound features: kick types, lead voices, reverb swaps, bed load
var e = ~eng, t = 60 / 128 / 4;
~seg.("start");
[1, 2].do { |k|
  e.cmd(\tweak, \kick_type, k);
  4.do { e.cmd(\kick, 0.9, 33, 0.45, 0.3); (t * 4).wait };
  ~seg.("kick" ++ k);
};
1.5.wait; ~seg.("tail");
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
