// null test for the master's character stage: at character 1 the master
// must be sample-identical to the master as it was before the stage
// existed. a fixed signal (no noise, no randomness) goes through two
// masters side by side, started in the same bundle on private buses:
//   ref  grad_master_ref, a verbatim copy of the pre-character grad_master
//   dut  the engine's grad_master, at the given character
// a third synth keeps the running peak of |dut - ref| over every sample.
// character 1 must give exactly 0 (CHECK FAIL otherwise); characters 2
// and 3 must differ, which proves the comparison can see a leak
var e = ~eng;
var run;
// the master before round 3, copied verbatim (renamed): do not edit
SynthDef(\grad_master_ref, {
  arg dryIn, pumpIn, out, ampOut, t_pump=0, pumpDepth=0.6, pumpRel=0.25, level=0.8, drive=0.2,
      pumpLpf=20000;
  var d   = Sanitize.ar(In.ar(dryIn, 2));
  var mono, toVis;
  var p   = LPF.ar(Sanitize.ar(In.ar(pumpIn, 2)), Lag.kr(pumpLpf, 0.12).clip(80, 20000));
  var env = EnvGen.kr(Env.perc(0.005, pumpRel, 1, -3), t_pump);
  var sig = d + (p * (1 - (env * pumpDepth)));
  sig = HPF.ar(sig, 28);
  sig = (sig * (1 + (drive * 2))).tanh / (1 + (drive * 0.6));
  sig = Limiter.ar(sig * level, 0.95, 0.01);
  toVis = { arg a, lo, hi; a.max(0.00001).ampdb.linlin(lo, hi, 0, 1) };
  mono = (sig[0] + sig[1]) * 0.5;
  Out.kr(ampOut, [
    toVis.value(Amplitude.kr(mono, 0.02, 0.3), -54, -3),
    toVis.value(Amplitude.kr(LPF.ar(mono, 160), 0.02, 0.3), -56, -3),
    toVis.value(Amplitude.kr(LPF.ar(HPF.ar(mono, 160), 3000), 0.02, 0.3), -60, -14),
    toVis.value(Amplitude.kr(HPF.ar(mono, 3000), 0.02, 0.25), -70, -24)
  ]);
  Out.ar(out, sig);
}).add;
// the fixed signal, written identically to both masters' inputs: a loud
// sub and saws on dry, detuned saws on pump, hot enough to hit the limiter
SynthDef(\cn_src, { arg dryA, pumpA, dryB, pumpB;
  var env = EnvGen.ar(Env([0, 1, 1, 0.3, 0], [0.01, 0.8, 0.4, 0.3]));
  var a = (SinOsc.ar(55) + (Saw.ar(220) * 0.3) + (Pulse.ar(3300, 0.3) * 0.1)) * env;
  var b = [Saw.ar(110.3), Saw.ar(164.9)] * env * 0.5;
  Out.ar(dryA, (a * 0.7) ! 2); Out.ar(dryB, (a * 0.7) ! 2);
  Out.ar(pumpA, b); Out.ar(pumpB, b);
}).add;
SynthDef(\cn_diff, { arg inA, inB, outK;
  var a = In.ar(inA, 2), b = In.ar(inB, 2);
  Out.kr(outK, [
    RunningMax.ar((a - b).abs.reduce(\max)),
    RunningMax.ar(a.abs.reduce(\max))
  ]);
}).add;
s.sync;
run = { |character|
  var bus = { Bus.audio(s, 2) } ! 6, kb = Bus.control(s, 2), ak = Bus.control(s, 8);
  var g = Group.tail(s), res;
  s.makeBundle(0.1, {
    Synth.head(g, \cn_src, [\dryA, bus[0].index, \pumpA, bus[1].index,
      \dryB, bus[2].index, \pumpB, bus[3].index]);
    Synth.tail(g, \grad_master_ref, [\dryIn, bus[0].index, \pumpIn, bus[1].index,
      \out, bus[4].index, \ampOut, ak.index, \drive, 0.35]);
    Synth.tail(g, \grad_master, [\dryIn, bus[2].index, \pumpIn, bus[3].index,
      \out, bus[5].index, \ampOut, ak.index + 4, \character, character, \drive, 0.35]);
    Synth.tail(g, \cn_diff, [\inA, bus[4].index, \inB, bus[5].index, \outK, kb.index]);
  });
  2.2.wait;
  s.sync;
  res = kb.getnSynchronous(2);
  g.free; s.sync;
  bus.do(_.free); kb.free; ak.free;
  res
};
[1, 2, 3].do { |c|
  var r = run.(c), diff = r[0], peak = r[1];
  ("CHECK character null " ++ c ++ " max |diff| " ++ diff ++ " (ref peak " ++ peak.round(0.001) ++ ")").postln;
  if(peak < 0.1, { ("CHECK FAIL character: reference too quiet (" ++ peak ++ ")").postln });
  if(c == 1, {
    if(diff != 0, { ("CHECK FAIL character: character 1 differs from the pre-character master by " ++ diff).postln });
  }, {
    if(diff < 0.001, { ("CHECK FAIL character: character " ++ c ++ " matches clean; the null test can't see a leak").postln });
  });
};
