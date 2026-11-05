// compile + smoke-test Engine_Gradient: boot, alloc, fire every command,
// record a few seconds, report peak/rms. run via test/sc/run.sh
var out = thisProcess.argv[0] ? "/tmp/gradient_test.wav";
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;
s.waitForBoot {
  var xg = Group.new(s), inb = [Bus.audio(s, 1), Bus.audio(s, 1)];
  var ctx = (server: s, xg: xg, in_b: inb, out_b: Bus.new(\audio, 0, 2, s));
  var cond = Condition.new, eng, rec;
  eng = Engine_Gradient.new(ctx, { cond.test = true; cond.signal });
  cond.wait;
  s.sync;
  "ENGINE ALLOCATED".postln;
  ~eng = eng;
  ~script = thisProcess.argv[1];
  // ~seg.("name") prints the peak of the output since the last call
  ~mbus = Bus.control(s, 1);
  ~meter = { arg t_reset = 0;
    Out.kr(~mbus.index, Peak.ar(Mix(In.ar(0, 2)).abs, Delay1.kr(t_reset)));
  }.play(s, addAction: \addToTail);
  ~seg = { |name|
    s.sync;
    ("SEG " ++ name ++ " peak " ++ ~mbus.getSynchronous.round(0.001)).postln;
    ~meter.set(\t_reset, 1);
  };
  s.sync;
  s.recHeaderFormat = "wav"; s.recSampleFormat = "float";
  s.record(out, numChannels: 2);
  0.3.wait;
  // any error in the test body still reaches the report and quits the
  // server, so a failure can't leave scsynth holding the pipe open
  try { if(~script.notNil, { ~script.load }, {
    var t = 60 / 128 / 4;
    eng.cmd(\tweak, \wash_amp, 0.3);
    eng.cmd(\tweak, \noise_amp, 0.05);
    eng.cmd(\wash_chord, 220, 261, 329, 392);
    eng.cmd(\listen, 1);
    32.do { |i|
      if(i % 4 == 0, { eng.cmd(\kick, 0.9, 33, 0.45, 0.3); eng.cmd(\pump, 1) });
      if(i % 4 == 2, { eng.cmd(\hat, 0.3, 0.05, 8000, 0.2) });
      if(i % 8 == 4, { eng.cmd(\rim, 0.3, 1700, -0.3) });
      if(i % 8 == 3, { eng.cmd(\chord, 220, 261, 329, 392, 0.3, 0.2) });
      if(i % 2 == 0, { eng.cmd(\bass, 55, 0.5, 0.2) });
      if(i % 4 == 1, { eng.cmd(\bass_glide, 82, 0.5, 0.2, 55, 0.06) });
      if(i % 8 == 6, { eng.cmd(\tom, 0.4, 110, 0.3, 0.2) });
      eng.cmd(\shaker, 0.2, 0.07, -0.2);
      if(i == 16, { eng.cmd(\swell, 0.2, 1.5); eng.cmd(\tweak, \pump_lpf, 600) });
      if(i == 28, { eng.cmd(\tweak, \pump_lpf, 20000) });
      if(i == 24, { eng.polls.keysValuesDo { |k, f| ("poll mid " ++ k ++ " = " ++ f.value.round(0.001)).postln } });
      eng.cmd(\arp, 440 * (1 + (i % 3)), 0.15, 0.25, 3000, 0.3, 0.5, (i % 4) + 1);
      t.wait;
    };
  }) } { |err| ("ERROR in test body: " ++ err.errorString).postln };
  2.wait;
  ~eng.polls.keysValuesDo { |k, f| ("poll " ++ k ++ " = " ++ f.value).postln };
  s.stopRecording;
  1.wait;
  // level report
  SoundFile.use(out, { |f|
    var data = FloatArray.newClear(f.numFrames * f.numChannels), peak, rms;
    f.readData(data);
    peak = data.abs.maxItem;
    rms = (data.squared.sum / data.size.max(1)).sqrt;
    ("LEVELS peak " ++ peak.round(0.001) ++ "  rms " ++ rms.round(0.0001)
      ++ "  secs " ++ (f.numFrames / f.sampleRate).round(0.1)).postln;
  });
  "SMOKE DONE".postln;
  s.quit;
  0.5.wait;
  0.exit;
};
