// every glitch mode must hand the mix back: play a pad + kicks, fire each
// mode, then the output after the glitch must be alive (not stuck at zero
// or NaN, which an echo/limiter/delay line would otherwise hold forever)
var e = ~eng, t = 60 / 128 / 4;
var bar = { 4.do { e.cmd(\kick, 0.9, 33, 0.45, 0.3); e.cmd(\pump, 1); (t * 4).wait } };
e.cmd(\tweak, \wash_amp, 0.3);
e.cmd(\wash_chord, 220, 261, 329, 392);
bar.value; ~seg.("warm");
[1, 2, 3, 4, 5, 5, 1].do { |m|
  e.cmd(\glitch, m, 0.12, 0.9, 1);
  bar.value;
  ~seg.("AFTER mode " ++ m);
};
