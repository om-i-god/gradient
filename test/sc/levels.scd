// level check for the voice types: every part's types play with identical
// args, one at a time and dry (sends off, master drive off), and each new
// type's peak must sit within +-4 dB of the part's first type. the types
// that were there before (arp 2-4) are printed but not judged.
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

measure.(\bass, 3, { |k| e.cmd(\tweak, \bass_type, k) },
  { e.cmd(\bass, 55, 0.8, 0.5) }, 1.0);
measure.(\chord, 5, { |k| e.cmd(\tweak, \chord_type, k) },
  { e.cmd(\chord, 220, 261.6, 329.6, 392, 0.3, 0.2) }, 2.5);
measure.(\hat, 3, { |k| e.cmd(\tweak, \hat_type, k) },
  { e.cmd(\hat, 0.3, 0.05, 8000, 0) }, 0.6);
measure.(\arp, 8, { },
  { |v| e.cmd(\arp, 440, 0.15, 0.25, 3000, 0, 0.5, v) }, 1.6, 5);

// pads: wash first, then swap to each type, settle 8 s, measure 2 s
e.cmd(\wash_chord, 110, 130.8, 164.8, 196);
e.cmd(\tweak, \wash_amp, 0.3);
measure.(\pad, 4, { |k|
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
