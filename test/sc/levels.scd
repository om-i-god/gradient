// level check for the voice types: every part's types play with identical
// args, one at a time and dry (sends off, master drive off), and each new
// type's peak must sit within +-4 dB of the part's first type. the types
// that were there before (arp 2-4, kick 2-4) are printed but not judged.
// round 3 adds: bass 4-5, chord 6-7, hat 4, pad 5-6, arp 9-10, kick 5-6,
// the echo types (judged on their echo return alone) and the master
// character modes (judged against character 1, clean)
//   LEVEL <part> <type> <dB vs type 1>      (LEVEL FAIL when outside)
// also: swapping bass_type under a held bass note leaves that note alone
var e = ~eng;
var pk = { s.sync; ~mbus.getSynchronous };
var reset = { s.sync; ~meter.set(\t_reset, 1); 0.05.wait };
var report = { |part, peaks, firstNew = 2, tol = 4|
  peaks.do { |p, i|
    var db = (p.max(0.000001) / peaks[0].max(0.000001)).ampdb;
    ("LEVEL " ++ part ++ " " ++ (i + 1) ++ " " ++ db.round(0.1) ++ " dB"
      ++ "  (peak " ++ p.round(0.001) ++ ")").postln;
    if(((i + 1) >= firstNew) and: { db.abs > tol }, { ("LEVEL FAIL " ++ part ++ " " ++ (i + 1) ++ " " ++ db.round(0.1)).postln });
  };
};
var measure = { |part, n, setup, play, wait, firstNew = 2|
  var peaks = n.collect { |i|
    setup.(i + 1);
    reset.();
    play.(i + 1);
    wait.wait;
    pk.()
  };
  report.(part, peaks, firstNew);
};
if(e.commands[\pad_type].isNil, { "ERROR: no pad_type command".postln });
[\hat_echo, \hat_verb, \chord_echo, \chord_verb, \arp_echo, \arp_verb, \arp_lead,
 \wash_echo, \wash_verb].do { |k| e.cmd(\tweak, k, 0) };
e.cmd(\tweak, \drive, 0);
1.wait;

measure.(\kick, 6, { |k| e.cmd(\tweak, \kick_type, k) },
  { e.cmd(\kick, 0.4, 33, 0.45, 0.3) }, 1.0, 5);
e.cmd(\tweak, \kick_type, 1);
measure.(\bass, 5, { |k| e.cmd(\tweak, \bass_type, k) },
  { e.cmd(\bass, 55, 0.8, 0.5) }, 1.0);
measure.(\chord, 7, { |k| e.cmd(\tweak, \chord_type, k) },
  { e.cmd(\chord, 220, 261.6, 329.6, 392, 0.3, 0.2) }, 2.5);
measure.(\hat, 4, { |k| e.cmd(\tweak, \hat_type, k) },
  // six hits, the loudest kept: one noise hit's peak varies by a dB or two
  { fork { 6.do { e.cmd(\hat, 0.3, 0.05, 8000, 0); 0.15.wait } } }, 1.2);
e.cmd(\tweak, \bass_type, 1);
e.cmd(\tweak, \chord_type, 1);
e.cmd(\tweak, \hat_type, 1);
measure.(\arp, 10, { },
  { |v| e.cmd(\arp, 440, 0.15, 0.25, 3000, 0, 0.5, v) }, 1.6, 5);

// pads: wash first, then swap to each type, settle 8 s, measure 2 s
e.cmd(\wash_chord, 110, 130.8, 164.8, 196);
e.cmd(\tweak, \wash_amp, 0.3);
measure.(\pad, 6, { |k|
  if(k > 1, { e.cmd(\pad_type, k) });
  8.wait;
  ("CPU pad " ++ k ++ " avg " ++ s.avgCPU.round(0.1) ++ " peak " ++ s.peakCPU.round(0.1)).postln;
}, { }, 2.0);
e.cmd(\pad_type, 1);
e.cmd(\tweak, \wash_amp, 0);
8.wait;

// a held bass note must not change when bass_type changes under it
e.cmd(\tweak, \bass_type, 1);
reset.();
e.cmd(\bass, 55, 0.8, 2.0);
0.8.wait;
~held1 = pk.();
reset.();
e.cmd(\tweak, \bass_type, 2);
0.8.wait;
~held2 = pk.();
e.cmd(\tweak, \bass_type, 1);
report.(\bass_held, [~held1, ~held2], 2, 1);
1.wait;

// echo types: a rim into the echo only (no dry, no reverb), the peak taken
// over the repeats after the dry hit has gone. each swap gets 3.5 s to land
// and for the old echo to fade
if(e.commands[\echo_type].isNil, { "ERROR: no echo_type command".postln });
e.cmd(\tweak, \echo_verb, 0);
e.cmd(\tweak, \echo_time, 0.375);
e.cmd(\tweak, \echo_fb, 0.55);
e.cmd(\tweak, \rim_echo, 1);
e.cmd(\tweak, \rim_verb, 0);
~echoPeaks = 4.collect { |i|
  e.cmd(\echo_type, i + 1);
  3.5.wait;
  e.cmd(\rim, 0.5, 1700, 0);
  0.2.wait;
  reset.();
  1.6.wait;
  pk.()
};
report.(\echo, ~echoPeaks);
e.cmd(\echo_type, 1);
e.cmd(\tweak, \rim_echo, 0.45);
e.cmd(\tweak, \rim_verb, 0.25);
3.5.wait;

// character: the pad and a bass line through each master mode
e.cmd(\tweak, \wash_amp, 0.3);
e.cmd(\tweak, \drive, 0.2);
6.wait;
~charPeaks = 3.collect { |i|
  e.cmd(\tweak, \character, i + 1);
  1.5.wait;
  reset.();
  4.do { e.cmd(\bass, 55, 0.6, 0.3); 0.5.wait };
  ("CPU character " ++ (i + 1) ++ " avg " ++ s.avgCPU.round(0.1) ++ " peak " ++ s.peakCPU.round(0.1)).postln;
  pk.()
};
report.(\character, ~charPeaks);
e.cmd(\tweak, \character, 1);
e.cmd(\tweak, \wash_amp, 0);
