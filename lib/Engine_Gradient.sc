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
//   chord f1 f2 f3 f4 amp dur
//   arp   hz amp decay cutoff pan shape
//   pump  (dummy f)
//   wash_chord f1 f2 f3 f4
//   tweak key val   -- see `st` defaults / fxMap below
//   listen on       -- 1 runs the input key tracker, 0 pauses it
//
// polls
//   in_key  KeyTrack estimate of the audio input: 0-11 C..B major, 12-23 C..B minor
//   in_amp  input amplitude

Engine_Gradient : CroneEngine {
  var voiceGroup, fxGroup;
  var dryBus, pumpBus, echoBus, verbBus, leadBus;
  var washSynth, noiseSynth, echoSynth, leadSynth, verbSynth, masterSynth;
  var listenSynth, keyBus, inAmpBus;
  var st, fxMap;

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

    voiceGroup = Group.head(context.xg);
    fxGroup    = Group.after(voiceGroup);

    // per-voice settings read at spawn time (set via `tweak`)
    st = IdentityDictionary[
      \kick_lvl -> 1.0,
      \hat_lvl -> 1.0,   \hat_echo -> 0.05, \hat_verb -> 0.10,
      \rim_lvl -> 1.0,   \rim_echo -> 0.45, \rim_verb -> 0.25,
      \bass_lvl -> 1.0,  \bass_cutoff -> 260, \bass_drive -> 0.3,
      \chord_lvl -> 1.0, \chord_echo -> 0.55, \chord_verb -> 0.35,
      \chord_cutoff -> 1400, \chord_res -> 0.35, \chord_env -> 1.6, \chord_detune -> 0.18,
      \arp_lvl -> 1.0,   \arp_echo -> 0.22, \arp_verb -> 0.40, \arp_lead -> 0.3
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

    SynthDef(\grad_hat, {
      arg out, echoOut, verbOut, amp=0.3, decay=0.05, tone=8000, pan=0, echo=0, verb=0.1;
      var env = EnvGen.ar(Env.perc(0.001, decay, 1, -6), doneAction: 2);
      var sig = RHPF.ar(WhiteNoise.ar, tone.clip(1000, 16000), 0.4) * env * amp;
      sig = Pan2.ar(sig, pan);
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
      arg out, freq=55, amp=0.5, dur=0.3, cutoff=260, drive=0.3;
      var env = EnvGen.ar(Env.linen(0.004, dur, 0.08, 1, -3), doneAction: 2);
      var sig = SinOsc.ar(freq) + (LFTri.ar(freq * 2) * 0.12) + (Saw.ar(freq) * 0.08);
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

    SynthDef(\grad_master, {
      arg dryIn, pumpIn, out, t_pump=0, pumpDepth=0.6, pumpRel=0.25, level=0.8, drive=0.2;
      var d   = In.ar(dryIn, 2);
      var p   = In.ar(pumpIn, 2);
      var env = EnvGen.kr(Env.perc(0.005, pumpRel, 1, -3), t_pump);
      var sig = d + (p * (1 - (env * pumpDepth)));
      sig = HPF.ar(sig, 28);
      sig = (sig * (1 + (drive * 2))).tanh / (1 + (drive * 0.6));
      sig = Limiter.ar(sig * level, 0.95, 0.01);
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
      \dryIn, dryBus.index, \pumpIn, pumpBus.index, \out, context.out_b.index
    ], fxGroup, \addToTail);

    // tweak keys that route straight to a persistent synth arg
    fxMap = IdentityDictionary[
      \echo_time -> [echoSynth, \time],   \echo_fb -> [echoSynth, \fb],
      \echo_lpf -> [echoSynth, \lpf],     \echo_hpf -> [echoSynth, \hpf],
      \echo_wow -> [echoSynth, \wow],     \echo_sat -> [echoSynth, \sat],
      \echo_pp -> [echoSynth, \pp],       \echo_verb -> [echoSynth, \verb],
      \lead_time -> [leadSynth, \time],   \lead_fb -> [leadSynth, \fb],
      \lead_lpf -> [leadSynth, \lpf],     \lead_hpf -> [leadSynth, \hpf],
      \lead_wow -> [leadSynth, \wow],     \lead_sat -> [leadSynth, \sat],
      \lead_pp -> [leadSynth, \pp],       \lead_verb -> [leadSynth, \verb],
      \verb_size -> [verbSynth, \size],   \verb_damp -> [verbSynth, \damp],
      \verb_level -> [verbSynth, \level],
      \pump_depth -> [masterSynth, \pumpDepth], \pump_rel -> [masterSynth, \pumpRel],
      \level -> [masterSynth, \level],    \drive -> [masterSynth, \drive],
      \wash_amp -> [washSynth, \amp],     \wash_cutoff -> [washSynth, \cutoff],
      \wash_echo -> [washSynth, \echo],   \wash_verb -> [washSynth, \verb],
      \noise_amp -> [noiseSynth, \amp],   \noise_tone -> [noiseSynth, \tone],
      \noise_crackle -> [noiseSynth, \crackle]
    ];

    // ------------------------------------------------------------- commands

    this.addCommand(\kick, "ffff", { |msg|
      Synth(\grad_kick, [
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

    this.addCommand(\arp, "ffffff", { |msg|
      Synth(\grad_arp, [
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

    this.addCommand(\listen, "f", { |msg|
      listenSynth.run(msg[1] > 0);
    });

    this.addPoll(\in_key, { keyBus.getSynchronous });
    this.addPoll(\in_amp, { inAmpBus.getSynchronous });

    this.addCommand(\tweak, "sf", { |msg|
      var key = msg[1].asSymbol;
      var val = msg[2];
      var dest = fxMap[key];
      if(dest.notNil, {
        dest[0].set(dest[1], val);
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
  }
}
