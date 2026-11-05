// Engine_Gradient
//
// Generative dub / kickless techno voice set. One-shot voices are spawned
// per note into a voice group; two persistent beds (wash, noise) live there
// too. A fixed fx chain (dub echo -> reverb -> master) sits in an fx group
// after it.
//
// buses: dry  (never ducked: kick, hats)
//        pump (ducked by the sidechain envelope: everything else, plus the
//              echo and reverb returns, so the tails breathe with the pulse)
//        echo / verb sends
//        lead  (arp-only send into its own echo, set apart from the dub echo)
//
// NOTE: sclang binary operators have no precedence (strict left-to-right),
// so every compound expression below is fully parenthesized.
//
// commands
//   kick  amp tune decay click
//   hat   amp decay tone pan
//   rim   amp freq pan
//   bass  hz amp dur
//   bass_glide hz amp dur from glide   (slides in from `from` Hz over `glide` s)
//   tom   amp hz decay pan
//   shaker amp decay pan
//   swell amp dur   -- reversed-noise riser into the next downbeat
//   chord f1 f2 f3 f4 amp dur
//   arp   hz amp decay cutoff pan shape voice   (voice 1 classic 2 bell 3 pluck 4 soft)
//   pump  (dummy f)
//   wash_chord f1 f2 f3 f4
//   tweak key val   -- see `st` defaults / fxMap below
//   listen on       -- 1 runs the input key tracker, 0 pauses it
//   verb_type n     -- 1 hall 2 plate 3 spring (swaps the reverb synth in place)
//   bed path        -- load a sound file as the looping field-recording bed
//
// polls
//   in_key  KeyTrack estimate of the audio input: 0-11 C..B major, 12-23 C..B minor
//   in_amp  input amplitude
//   out_amp, out_lo, out_mid, out_hi  what gradient itself sounds like, for
//           the visuals: 0..1 on a dB scale, overall and in three bands

Engine_Gradient : CroneEngine {
  var voiceGroup, fxGroup;
  var dryBus, pumpBus, echoBus, verbBus, leadBus;
  var washSynth, noiseSynth, echoSynth, leadSynth, verbSynth, masterSynth;
  var listenSynth, keyBus, inAmpBus, outBus;
  var bedBuf;
  var st, fx, fxMap, fxVals;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    var s = context.server;

    dryBus  = Bus.audio(s, 2);
    pumpBus = Bus.audio(s, 2);
    echoBus = Bus.audio(s, 2);
    verbBus = Bus.audio(s, 2);
    leadBus = Bus.audio(s, 2);
    keyBus   = Bus.control(s, 1);
    inAmpBus = Bus.control(s, 1);
    outBus   = Bus.control(s, 4);     // out_amp, out_lo, out_mid, out_hi

    voiceGroup = Group.head(context.xg);
    fxGroup    = Group.after(voiceGroup);

    // per-voice settings read at spawn time (set via `tweak`)
    st = IdentityDictionary[
      \kick_lvl -> 1.0,
      \hat_lvl -> 1.0,   \hat_echo -> 0.05, \hat_verb -> 0.10,
      \tom_echo -> 0.45, \tom_verb -> 0.25, \swell_echo -> 0.3,
      \rim_lvl -> 1.0,   \rim_echo -> 0.45, \rim_verb -> 0.25,
      \bass_lvl -> 1.0,  \bass_cutoff -> 260, \bass_drive -> 0.3,
      \chord_lvl -> 1.0, \chord_echo -> 0.55, \chord_verb -> 0.35,
      \chord_cutoff -> 1400, \chord_res -> 0.35, \chord_env -> 1.6, \chord_detune -> 0.18,
      \arp_lvl -> 1.0,   \arp_echo -> 0.22, \arp_verb -> 0.40, \arp_lead -> 0.3,
      \kick_type -> 1
    ];

    // ---------------------------------------------------------------- voices

    SynthDef(\grad_kick, {
      arg out, amp=0.8, tune=33, decay=0.45, click=0.3;
      var base = tune.midicps;
      var penv = EnvGen.ar(Env([base * 4, base * 1.1, base], [0.012, 0.09], [-4, -2]));
      var aenv = EnvGen.ar(Env.perc(0.002, decay, 1, -5), doneAction: 2);
      var body = SinOsc.ar(penv, 0.5pi) * aenv;
      var clk  = HPF.ar(WhiteNoise.ar, 2500) * EnvGen.ar(Env.perc(0.0005, 0.006)) * click;
      var sig  = ((body + clk) * 1.4).tanh * amp;
      Out.ar(out, sig ! 2);
    }).add;

    // dusty: a 909-ish thud, band-limited and sample-rate crushed
    SynthDef(\grad_kick_dusty, {
      arg out, amp=0.8, tune=33, decay=0.45, click=0.3;
      var base = tune.midicps;
      var penv = EnvGen.ar(Env([base * 6, base * 1.4, base], [0.008, 0.06], [-5, -2]));
      var aenv = EnvGen.ar(Env.perc(0.001, decay * 0.85, 1, -4), doneAction: 2);
      var body = SinOsc.ar(penv, 0.5pi) * aenv;
      var nz   = BPF.ar(WhiteNoise.ar, 1800, 0.6) * EnvGen.ar(Env.perc(0.0005, 0.025)) * (click * 2);
      var sig  = ((body * 1.8) + nz).softclip;
      sig = Latch.ar(sig, Impulse.ar(14000));
      sig = LPF.ar(sig, 3800);
      sig = (sig * 1.3).tanh * amp;
      Out.ar(out, sig ! 2);
    }).add;

    SynthDef(\grad_hat, {
      arg out, echoOut, verbOut, amp=0.3, decay=0.05, tone=8000, pan=0, echo=0, verb=0.1;
      var env = EnvGen.ar(Env.perc(0.001, decay, 1, -6), doneAction: 2);
      var sig = RHPF.ar(WhiteNoise.ar, tone.clip(1000, 16000), 0.4) * env * amp;
      sig = Pan2.ar(sig, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    SynthDef(\grad_shaker, {
      arg out, echoOut, verbOut, amp=0.2, decay=0.07, pan=0, echo=0, verb=0.15;
      var env = EnvGen.ar(Env([0, 1, 0], [decay * 0.35, decay * 0.65], [2, -6]), doneAction: 2);
      var sig = BPF.ar(WhiteNoise.ar, 7000, 0.7) + (HPF.ar(WhiteNoise.ar, 11000) * 0.4);
      sig = Pan2.ar(sig * env * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // dub tom: a pitched sine thump with a noise skin, mostly there for the
    // echo to answer
    SynthDef(\grad_tom, {
      arg out, echoOut, verbOut, amp=0.3, freq=110, decay=0.3, pan=0, echo=0.45, verb=0.25;
      var penv = EnvGen.ar(Env([freq * 1.7, freq], [0.035], -3));
      var env  = EnvGen.ar(Env.perc(0.002, decay, 1, -5), doneAction: 2);
      var skin = BPF.ar(WhiteNoise.ar, freq * 4, 0.4) * EnvGen.ar(Env.perc(0.0005, 0.012)) * 0.6;
      var sig  = ((SinOsc.ar(penv) * 1.3).tanh + skin) * env * amp;
      sig = Pan2.ar(sig, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // riser: filtered noise swelling up (a reversed cymbal, more or less)
    // and cut dead at the end, so the downbeat lands in the gap
    SynthDef(\grad_swell, {
      arg out, echoOut, verbOut, amp=0.2, dur=1.8, echo=0.3, verb=0.5;
      var env = EnvGen.ar(Env([0.0001, 1, 0], [dur, 0.01], [5, -4]), doneAction: 2);
      var cut = EnvGen.ar(Env([300, 9000], [dur], [4]));
      var sig = RLPF.ar({ WhiteNoise.ar } ! 2, cut, 0.45) * env * amp;
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    SynthDef(\grad_rim, {
      arg out, echoOut, verbOut, amp=0.3, freq=1700, pan=0, echo=0.4, verb=0.2;
      var env  = EnvGen.ar(Env.perc(0.0005, 0.05, 1, -8), doneAction: 2);
      var body = BPF.ar(WhiteNoise.ar, freq, 0.08) * 6;
      var tick = SinOsc.ar(freq * 0.5) * EnvGen.ar(Env.perc(0.0005, 0.02));
      var sig  = Pan2.ar((body + tick) * env * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    SynthDef(\grad_bass, {
      arg out, freq=55, amp=0.5, dur=0.3, cutoff=260, drive=0.3, from=0, glide=0.05;
      var env = EnvGen.ar(Env.linen(0.004, dur, 0.08, 1, -3), doneAction: 2);
      // from > 0: slide in from that pitch
      var f   = Select.kr(from > 0, [freq,
        EnvGen.kr(Env([from.max(20), freq], [glide.max(0.001)], \exp))]);
      var sig = SinOsc.ar(f) + (LFTri.ar(f * 2) * 0.12) + (Saw.ar(f) * 0.08);
      sig = RLPF.ar(sig, cutoff.clip(40, 4000), 0.7);
      sig = (sig * (1 + (drive * 3))).tanh * env * amp;
      Out.ar(out, sig ! 2);
    }).add;

    // dub chord stab: detuned saw pairs (L/R) through a resonant LPF with a
    // short filter blip; the long life comes from the echo send
    SynthDef(\grad_chord, {
      arg out, echoOut, verbOut, f1=220, f2=261, f3=329, f4=392,
          amp=0.3, dur=0.2, cutoff=1400, res=0.35, envAmt=1.6, detune=0.18,
          echo=0.55, verb=0.35;
      var d    = detune * 0.01;
      var env  = EnvGen.ar(Env.perc(0.004, dur, 1, -4), doneAction: 2);
      var fenv = EnvGen.ar(Env.perc(0.002, dur * 0.6, 1, -6));
      var sig  = Mix([f1, f2, f3, f4].collect { |f| Saw.ar(f * [1 - d, 1 + d]) }) * 0.22;
      sig = RLPF.ar(sig, (cutoff * (1 + (fenv * envAmt))).clip(60, 14000), res.linlin(0, 1, 1, 0.12));
      sig = sig * env * amp;
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    SynthDef(\grad_arp, {
      arg out, echoOut, verbOut, leadOut, freq=440, amp=0.2, decay=0.25, cutoff=3000,
          shape=0.5, pan=0, echo=0.2, verb=0.4, lead=0.3;
      var env  = EnvGen.ar(Env.perc(0.002, decay, 1, -4), doneAction: 2);
      var fenv = EnvGen.ar(Env.perc(0.001, decay * 0.5, 1, -4));
      var sig  = XFade2.ar(LFTri.ar(freq), Pulse.ar(freq, 0.3), (shape * 2) - 1);
      sig = sig + (SinOsc.ar(freq * 2) * 0.2);
      sig = RLPF.ar(sig, (cutoff * (0.5 + (fenv * 1.5))).clip(60, 16000), 0.5);
      sig = Pan2.ar(sig * env * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
      Out.ar(leadOut, sig * lead);
    }).add;

    // the other lead voices share grad_arp's args and sends
    SynthDef(\grad_arp_bell, {
      arg out, echoOut, verbOut, leadOut, freq=440, amp=0.2, decay=0.25, cutoff=3000,
          shape=0.5, pan=0, echo=0.2, verb=0.4, lead=0.3;
      var len  = (decay * 2.5) + 0.1;
      var env  = EnvGen.ar(Env.perc(0.001, len, 1, -6), doneAction: 2);
      var ienv = EnvGen.ar(Env.perc(0.001, len * 0.4, 1, -4));
      var ratio = shape.linlin(0, 1, 1.4, 3.5);
      var mod  = SinOsc.ar(freq * ratio) * freq * (0.5 + (ienv * 3));
      var sig  = SinOsc.ar(freq + mod) * 1.25;
      sig = LPF.ar(sig, (cutoff * 2).clip(200, 16000));
      sig = Pan2.ar(sig * env * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
      Out.ar(leadOut, sig * lead);
    }).add;

    SynthDef(\grad_arp_pluck, {
      arg out, echoOut, verbOut, leadOut, freq=440, amp=0.2, decay=0.25, cutoff=3000,
          shape=0.5, pan=0, echo=0.2, verb=0.4, lead=0.3;
      var len = (decay * 3) + 0.2;
      var env = EnvGen.ar(Env.linen(0, len, 0.05), doneAction: 2);
      var exc = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0005, 0.01));
      var sig = Pluck.ar(exc, Impulse.ar(0), 0.05, freq.reciprocal, len, shape.linlin(0, 1, 0.15, 0.6));
      sig = LPF.ar(sig * 3.4, cutoff.clip(200, 16000));
      sig = Pan2.ar(sig * env * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
      Out.ar(leadOut, sig * lead);
    }).add;

    SynthDef(\grad_arp_soft, {
      arg out, echoOut, verbOut, leadOut, freq=440, amp=0.2, decay=0.25, cutoff=3000,
          shape=0.5, pan=0, echo=0.2, verb=0.4, lead=0.3;
      var env = EnvGen.ar(Env.perc(0.012, (decay * 1.5) + 0.05, 1, -3), doneAction: 2);
      var sig = SinOsc.ar(freq) + (LFTri.ar(freq * 2) * 0.12 * shape);
      sig = LPF.ar(sig, (cutoff * 0.7).clip(200, 8000));
      sig = Pan2.ar(sig * env * amp * 1.1, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
      Out.ar(leadOut, sig * lead);
    }).add;

    // persistent pad under the chords; glides between voicings, swells in
    // the kickless stretches
    SynthDef(\grad_wash, {
      arg out, echoOut, verbOut, f1=110, f2=130, f3=165, f4=196,
          amp=0, cutoff=700, echo=0.1, verb=0.5;
      var freqs = [f1, f2, f3, f4].collect { |f| Lag.kr(f, 3) };
      var sig = Mix(freqs.collect { |f, i|
        var dt = (LFNoise2.kr(0.1 + (i * 0.03)) * 0.004) + 0.003;
        Saw.ar(f * [1 - dt, 1 + dt])
      }) * 0.1;
      sig = LPF.ar(sig, (Lag.kr(cutoff, 4) * (1 + (LFNoise2.kr(0.07) * 0.3))).clip(80, 8000));
      sig = sig * Lag.kr(amp, 6);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // hiss + vinyl crackle bed
    SynthDef(\grad_noise, {
      arg out, verbOut, amp=0, tone=2000, crackle=0.3, verb=0.4;
      var ktone = Lag.kr(tone, 2);
      var hiss  = BPF.ar({ PinkNoise.ar } ! 2,
        (ktone * (1 + (LFNoise2.kr([0.05, 0.06]) * 0.5))).clip(100, 12000), 0.8) * 0.5;
      var crk   = Decay2.ar(Dust.ar(([3, 3.3] * crackle * 4) + 0.01), 0.0005, 0.003)
                  * ({ WhiteNoise.ar } ! 2) * crackle;
      var sig   = (hiss + crk) * Lag.kr(amp, 3);
      Out.ar(out, sig);
      Out.ar(verbOut, sig * verb);
    }).add;

    // field-recording bed: a loaded file looping slowly, drifting in speed,
    // filter and pan. one def per channel count
    [1, 2].do { |nc|
      SynthDef(("grad_bed" ++ nc).asSymbol, {
        arg out, verbOut, buf, amp=0, lpf=4000, rate=1, verb=0.4;
        var drift = 1 + (LFNoise2.kr(0.05) * 0.01);
        var sig = PlayBuf.ar(nc, buf, BufRateScale.kr(buf) * Lag.kr(rate, 2) * drift, loop: 1);
        if(nc == 1, { sig = Pan2.ar(sig, LFNoise2.kr(0.03) * 0.5) });
        sig = LPF.ar(sig, (Lag.kr(lpf, 2) * (1 + (LFNoise2.kr(0.04) * 0.25))).clip(100, 16000));
        sig = HPF.ar(sig, 60) * Lag.kr(amp, 4);
        Out.ar(out, sig);
        Out.ar(verbOut, sig * verb);
      }).add;
    };

    // ------------------------------------------------------------------- fx

    // tape-ish ping-pong dub echo: filters + saturation inside the loop, wow
    // on the delay line, lagged time so tempo changes slide like tape
    SynthDef(\grad_echo, {
      arg in, out, verbOut, time=0.375, fb=0.55, lpf=2500, hpf=300,
          wow=0.3, sat=0.4, pp=0.7, verb=0.3;
      var input = In.ar(in, 2);
      var t     = Lag.kr(time, 0.8);
      var mod   = (LFNoise2.kr(0.4) * 0.002 * wow) + (SinOsc.kr(0.17) * 0.0015 * wow);
      var fbk   = LocalIn.ar(2);
      var inj   = XFade2.ar(input, [Mix(input), DC.ar(0)], (pp * 2) - 1);
      var sig, del;
      sig = inj + (fbk * Lag.kr(fb, 0.2).clip(0, 1.02));
      sig = LPF.ar(sig, Lag.kr(lpf, 0.3).clip(200, 16000));
      sig = HPF.ar(sig, Lag.kr(hpf, 0.3).clip(20, 4000));
      sig = (sig * (1 + (sat * 2))).tanh / (1 + (sat * 0.8));
      del = DelayC.ar(sig, 2.5, (t + mod).clip(0.01, 2.4));
      LocalOut.ar([del[1], del[0]]);
      Out.ar(out, del);
      Out.ar(verbOut, del * verb);
    }).add;

    SynthDef(\grad_verb, {
      arg in, out, size=0.85, damp=0.5, level=0.8;
      var sig = In.ar(in, 2);
      sig = DelayN.ar(sig, 0.1, 0.03);
      [0.013, 0.017, 0.023, 0.031].do { |dt|
        sig = AllpassC.ar(sig, 0.08, (dt * [1, 1.13]) + (LFNoise2.kr([0.1, 0.11]) * 0.0008), 1.5);
      };
      sig = FreeVerb2.ar(sig[0], sig[1], 1, Lag.kr(size, 1).clip(0, 1), damp);
      sig = HPF.ar(sig, 150);
      Out.ar(out, sig * level);
    }).add;

    // plate: short dense diffusion into a cross-fed modulated tank
    SynthDef(\grad_verb_plate, {
      arg in, out, size=0.85, damp=0.5, level=0.8;
      var sig = DelayN.ar(In.ar(in, 2), 0.02, 0.008);
      var dec = Lag.kr(size, 1).linlin(0, 1, 0.45, 0.92);
      var fb  = LocalIn.ar(2);
      var l, r;
      sig = Mix(sig) * 0.5;
      [0.0048, 0.0036, 0.0127, 0.0093].do { |dt| sig = AllpassN.ar(sig, 0.02, dt, 0.08) };
      l = sig + (fb[1] * dec);
      r = sig + (fb[0] * dec);
      l = AllpassC.ar(l, 0.05, 0.0225 + (SinOsc.kr(0.6) * 0.0006), 0.5);
      r = AllpassC.ar(r, 0.05, 0.0305 + (SinOsc.kr(0.71, 1) * 0.0006), 0.5);
      l = LPF.ar(DelayC.ar(l, 0.2, 0.1415), damp.linexp(0, 1, 12000, 2500));
      r = LPF.ar(DelayC.ar(r, 0.2, 0.1061), damp.linexp(0, 1, 12000, 2500));
      LocalOut.ar([l, r]);
      sig = HPF.ar([l, r], 180);
      Out.ar(out, sig * level * 0.9);
    }).add;

    // spring: a chain of tiny allpasses for the chirp, a short wobbling
    // feedback delay for the drip
    SynthDef(\grad_verb_spring, {
      arg in, out, size=0.85, damp=0.5, level=0.8;
      var sig = HPF.ar(In.ar(in, 2), 220);
      var dec = Lag.kr(size, 1).linlin(0, 1, 0.4, 0.86);
      var fb  = LocalIn.ar(2);
      var y   = sig + (fb * dec);
      12.do { |i|
        y = AllpassC.ar(y, 0.01, [0.0011, 0.0013] * (1 + (i * 0.07)), 0.025);
      };
      y = DelayC.ar(y, 0.1, [0.037, 0.043] + (LFNoise2.kr([3.1, 2.7]) * 0.0008));
      y = LPF.ar(y, damp.linexp(0, 1, 6500, 2500));
      y = HPF.ar(y, 300);
      LocalOut.ar(y);
      Out.ar(out, y * level * 1.2);
    }).add;

    SynthDef(\grad_master, {
      arg dryIn, pumpIn, out, ampOut, t_pump=0, pumpDepth=0.6, pumpRel=0.25, level=0.8, drive=0.2,
          pumpLpf=20000;
      var d   = In.ar(dryIn, 2);
      var mono, toVis;
      // pumpLpf: the fill's filter dip, on everything but kick and hats
      var p   = LPF.ar(In.ar(pumpIn, 2), Lag.kr(pumpLpf, 0.12).clip(80, 20000));
      var env = EnvGen.kr(Env.perc(0.005, pumpRel, 1, -3), t_pump);
      var sig = d + (p * (1 - (env * pumpDepth)));
      sig = HPF.ar(sig, 28);
      sig = (sig * (1 + (drive * 2))).tanh / (1 + (drive * 0.6));
      sig = Limiter.ar(sig * level, 0.95, 0.01);
      // the visuals' ears: three cheap filters and four Amplitude followers
      // on the mono sum, mapped from dB to 0..1
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

    // input key tracker: pitch-class profile over a 4096 FFT matched against
    // major/minor templates (KeyTrack has tables for 44.1k and 48k)
    SynthDef(\grad_listen, {
      arg in_l, in_r, keyOut, ampOut, keydecay=4;
      var sig   = (In.ar(in_l) + In.ar(in_r)) * 0.5;
      var chain = FFT(LocalBuf(4096), sig);
      Out.kr(keyOut, KeyTrack.kr(chain, keydecay, 0.5));
      Out.kr(ampOut, Amplitude.kr(sig, 0.05, 0.5));
    }).add;

    s.sync;

    washSynth = Synth(\grad_wash, [
      \out, pumpBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index
    ], voiceGroup);
    noiseSynth = Synth(\grad_noise, [
      \out, pumpBus.index, \verbOut, verbBus.index
    ], voiceGroup);

    echoSynth = Synth(\grad_echo, [
      \in, echoBus.index, \out, pumpBus.index, \verbOut, verbBus.index
    ], fxGroup, \addToTail);
    // the lead delay: a second grad_echo, fed only by the arps; it must sit
    // before the reverb because it writes to the verb send
    leadSynth = Synth.after(echoSynth, \grad_echo, [
      \in, leadBus.index, \out, pumpBus.index, \verbOut, verbBus.index
    ]);
    verbSynth = Synth(\grad_verb, [
      \in, verbBus.index, \out, pumpBus.index
    ], fxGroup, \addToTail);
    listenSynth = Synth(\grad_listen, [
      \in_l, context.in_b[0].index, \in_r, context.in_b[1].index,
      \keyOut, keyBus.index, \ampOut, inAmpBus.index
    ], fxGroup, \addToHead);
    listenSynth.run(false);

    masterSynth = Synth(\grad_master, [
      \dryIn, dryBus.index, \pumpIn, pumpBus.index, \out, context.out_b.index,
      \ampOut, outBus.index
    ], fxGroup, \addToTail);

    // persistent synths by name; the reverb and bed get swapped in place,
    // so tweaks look the synth up at send time and remember their values
    fx = IdentityDictionary[
      \echo -> echoSynth, \lead -> leadSynth, \verb -> verbSynth,
      \master -> masterSynth, \wash -> washSynth, \noise -> noiseSynth
    ];
    fxVals = IdentityDictionary.new;

    // tweak keys that route straight to a persistent synth arg
    fxMap = IdentityDictionary[
      \echo_time -> [\echo, \time],   \echo_fb -> [\echo, \fb],
      \echo_lpf -> [\echo, \lpf],     \echo_hpf -> [\echo, \hpf],
      \echo_wow -> [\echo, \wow],     \echo_sat -> [\echo, \sat],
      \echo_pp -> [\echo, \pp],       \echo_verb -> [\echo, \verb],
      \lead_time -> [\lead, \time],   \lead_fb -> [\lead, \fb],
      \lead_lpf -> [\lead, \lpf],     \lead_hpf -> [\lead, \hpf],
      \lead_wow -> [\lead, \wow],     \lead_sat -> [\lead, \sat],
      \lead_pp -> [\lead, \pp],       \lead_verb -> [\lead, \verb],
      \verb_size -> [\verb, \size],   \verb_damp -> [\verb, \damp],
      \verb_level -> [\verb, \level],
      \pump_depth -> [\master, \pumpDepth], \pump_rel -> [\master, \pumpRel],
      \pump_lpf -> [\master, \pumpLpf],
      \level -> [\master, \level],    \drive -> [\master, \drive],
      \wash_amp -> [\wash, \amp],     \wash_cutoff -> [\wash, \cutoff],
      \wash_echo -> [\wash, \echo],   \wash_verb -> [\wash, \verb],
      \noise_amp -> [\noise, \amp],   \noise_tone -> [\noise, \tone],
      \noise_crackle -> [\noise, \crackle],
      \bed_amp -> [\bed, \amp],       \bed_lpf -> [\bed, \lpf],
      \bed_rate -> [\bed, \rate],     \bed_verb -> [\bed, \verb]
    ];

    // ------------------------------------------------------------- commands

    this.addCommand(\kick, "ffff", { |msg|
      Synth([\grad_kick, \grad_kick_dusty].clipAt(st[\kick_type].asInteger - 1), [
        \out, dryBus.index, \amp, msg[1] * st[\kick_lvl],
        \tune, msg[2], \decay, msg[3], \click, msg[4]
      ], voiceGroup);
    });

    this.addCommand(\hat, "ffff", { |msg|
      Synth(\grad_hat, [
        \out, dryBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \amp, msg[1] * st[\hat_lvl], \decay, msg[2], \tone, msg[3], \pan, msg[4],
        \echo, st[\hat_echo], \verb, st[\hat_verb]
      ], voiceGroup);
    });

    this.addCommand(\rim, "fff", { |msg|
      Synth(\grad_rim, [
        \out, pumpBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \amp, msg[1] * st[\rim_lvl], \freq, msg[2], \pan, msg[3],
        \echo, st[\rim_echo], \verb, st[\rim_verb]
      ], voiceGroup);
    });

    this.addCommand(\bass, "fff", { |msg|
      Synth(\grad_bass, [
        \out, pumpBus.index, \freq, msg[1], \amp, msg[2] * st[\bass_lvl], \dur, msg[3],
        \cutoff, st[\bass_cutoff], \drive, st[\bass_drive]
      ], voiceGroup);
    });

    this.addCommand(\bass_glide, "fffff", { |msg|
      Synth(\grad_bass, [
        \out, pumpBus.index, \freq, msg[1], \amp, msg[2] * st[\bass_lvl], \dur, msg[3],
        \from, msg[4], \glide, msg[5],
        \cutoff, st[\bass_cutoff], \drive, st[\bass_drive]
      ], voiceGroup);
    });

    this.addCommand(\tom, "ffff", { |msg|
      Synth(\grad_tom, [
        \out, pumpBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \amp, msg[1] * st[\hat_lvl], \freq, msg[2], \decay, msg[3], \pan, msg[4],
        \echo, st[\tom_echo], \verb, st[\tom_verb]
      ], voiceGroup);
    });

    this.addCommand(\shaker, "fff", { |msg|
      Synth(\grad_shaker, [
        \out, dryBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \amp, msg[1] * st[\hat_lvl], \decay, msg[2], \pan, msg[3],
        \echo, st[\hat_echo], \verb, st[\hat_verb]
      ], voiceGroup);
    });

    this.addCommand(\swell, "ff", { |msg|
      Synth(\grad_swell, [
        \out, pumpBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \amp, msg[1], \dur, msg[2], \echo, st[\swell_echo]
      ], voiceGroup);
    });

    this.addCommand(\chord, "ffffff", { |msg|
      Synth(\grad_chord, [
        \out, pumpBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \f1, msg[1], \f2, msg[2], \f3, msg[3], \f4, msg[4],
        \amp, msg[5] * st[\chord_lvl], \dur, msg[6],
        \cutoff, st[\chord_cutoff], \res, st[\chord_res],
        \envAmt, st[\chord_env], \detune, st[\chord_detune],
        \echo, st[\chord_echo], \verb, st[\chord_verb]
      ], voiceGroup);
    });

    this.addCommand(\arp, "fffffff", { |msg|
      var def = [\grad_arp, \grad_arp_bell, \grad_arp_pluck, \grad_arp_soft].clipAt(msg[7].asInteger - 1);
      Synth(def, [
        \out, pumpBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \leadOut, leadBus.index,
        \freq, msg[1], \amp, msg[2] * st[\arp_lvl], \decay, msg[3],
        \cutoff, msg[4], \pan, msg[5], \shape, msg[6],
        \echo, st[\arp_echo], \verb, st[\arp_verb], \lead, st[\arp_lead]
      ], voiceGroup);
    });

    this.addCommand(\pump, "f", { |msg|
      masterSynth.set(\t_pump, 1);
    });

    this.addCommand(\wash_chord, "ffff", { |msg|
      washSynth.set(\f1, msg[1], \f2, msg[2], \f3, msg[3], \f4, msg[4]);
    });

    // swap the reverb in place, then re-send its remembered settings
    this.addCommand(\verb_type, "f", { |msg|
      var def = [\grad_verb, \grad_verb_plate, \grad_verb_spring].clipAt(msg[1].asInteger - 1);
      var vals = fxVals[\verb] ? IdentityDictionary.new;
      var args = [\in, verbBus.index, \out, pumpBus.index];
      vals.keysValuesDo { |k, v| args = args ++ [k, v] };
      fx[\verb] = Synth.replace(fx[\verb], def, args);
    });

    // load a sound file as the bed; the bed synth is rebuilt to match its
    // channel count and keeps its remembered settings
    this.addCommand(\bed, "s", { |msg|
      var path = msg[1].asString;
      if(File.exists(path), {
        Buffer.read(context.server, path, action: { |b|
          var nc = b.numChannels.clip(1, 2);
          var vals = fxVals[\bed] ? IdentityDictionary.new;
          var args = [\out, pumpBus.index, \verbOut, verbBus.index, \buf, b.bufnum];
          var old = bedBuf;
          vals.keysValuesDo { |k, v| args = args ++ [k, v] };
          if(fx[\bed].notNil, { fx[\bed].free });
          fx[\bed] = Synth(("grad_bed" ++ nc).asSymbol, args, voiceGroup, \addToTail);
          bedBuf = b;
          if(old.notNil, { old.free });
        });
      }, {
        ("gradient: bed file not found: " ++ path).postln;
      });
    });

    this.addCommand(\listen, "f", { |msg|
      listenSynth.run(msg[1] > 0);
    });

    this.addPoll(\in_key, { keyBus.getSynchronous });
    this.addPoll(\in_amp, { inAmpBus.getSynchronous });
    // the visuals' ears (see grad_master)
    [\out_amp, \out_lo, \out_mid, \out_hi].do { |name, i|
      this.addPoll(name, { outBus.getnSynchronous(4)[i] });
    };

    this.addCommand(\tweak, "sf", { |msg|
      var key = msg[1].asSymbol;
      var val = msg[2];
      var dest = fxMap[key];
      if(dest.notNil, {
        var node = fx[dest[0]];
        if(fxVals[dest[0]].isNil, { fxVals[dest[0]] = IdentityDictionary.new });
        fxVals[dest[0]][dest[1]] = val;
        if(node.notNil, { node.set(dest[1], val) });
      }, {
        st[key] = val;
      });
    });
  }

  free {
    voiceGroup.free;
    fxGroup.free;
    dryBus.free;
    pumpBus.free;
    echoBus.free;
    verbBus.free;
    leadBus.free;
    keyBus.free;
    inAmpBus.free;
    outBus.free;
    if(bedBuf.notNil, { bedBuf.free });
  }
}
