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
// the glitch insert sits after the echoes and reverb and before the master:
// it reads dry and pump and writes them back (stutter, tape stop, reverse,
// chop, crush), so the master's pump still ducks the live pulse
//
// NOTE: sclang binary operators have no precedence (strict left-to-right),
// so every compound expression below is fully parenthesized.
//
// commands
//   kick  amp tune decay click       (kick_type 1 sub 2 dusty 3 boom 4 knock 5 deep 6 tight)
//   hat   amp decay tone pan         (hat_type 1 noise 2 metal 3 dust 4 tape)
//   rim   amp freq pan
//   bass  hz amp dur                 (bass_type 1 sub 2 reese 3 rubber 4 fm sub 5 tape)
//   bass_glide hz amp dur from glide   (slides in from `from` Hz over `glide` s)
//   tom   amp hz decay pan
//   shaker amp decay pan
//   swell amp dur   -- reversed-noise riser into the next downbeat
//   clap  amp kind tone pan          (kind 1 clap 2 snare 3 snap)
//   perc  amp hz decay pan kind      (kind 1 hand 2 wood 3 metal)
//   ride  amp decay tone pan
//   tick  amp kind hz pan            (kind 1 click 2 blip 3 crush 4 zap)
//   glitch mode slice dur mix        -- the glitch insert on the whole mix (dur <= 1.5 s):
//         mode 1 stutter (repeat `slice` s) 2 tape stop 3 reverse
//              4 chop (gate at `slice`) 5 crush; for `dur` s, wet `mix`
//   chord f1 f2 f3 f4 amp dur        (chord_type 1 dub 2 felt 3 organ 4 glass 5 rhodes
//                                     6 choir 7 strings)
//   arp   hz amp decay cutoff pan shape voice   (voice 1 classic 2 bell 3 pluck 4 soft
//         5 glass 6 reed 7 kalimba 8 marimba 9 steel 10 bowed)
//   pump  (dummy f)
//   wash_chord f1 f2 f3 f4
//   tweak key val   -- see `st` defaults / fxMap below
//                      (character 1 clean 2 warm 3 dusty: the master's colour)
//   listen on       -- 1 runs the input key tracker, 0 pauses it
//   verb_type n     -- 1 hall 2 plate 3 spring (swaps the reverb synth in place)
//   echo_type n     -- 1 dub 2 tape 3 ping-pong 4 space (crossfades the dub echo over
//                      about 2.5 s; the lead echo stays as it is)
//   pad_type n      -- 1 wash 2 choir 3 strings 4 drone 5 glass 6 tape loop (crossfades the pad: mostly done in about 2 s, settled in about 6 s)
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
  var listenSynth, keyBus, inAmpBus, outBus, glitchSynth;
  var bedBuf;
  var st, fx, fxMap, fxVals;
  var washChord, padFading, padDef, padPending, padDue, padLastSwap, padTimer;
  var echoFading, echoDef, echoPending, echoDue, echoLastSwap, echoTimer;

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
      \clap_lvl -> 1.0,  \clap_echo -> 0.3, \clap_verb -> 0.35,
      \perc_lvl -> 1.0,  \perc_echo -> 0.35, \perc_verb -> 0.2,
      \tick_lvl -> 1.0,  \tick_echo -> 0.3, \tick_verb -> 0.1,
      \ride_verb -> 0.12,
      \kick_type -> 1,
      \bass_type -> 1, \chord_type -> 1, \hat_type -> 1
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

    // boom: a long 808-ish sub, slow pitch fall, a little drive
    SynthDef(\grad_kick_boom, {
      arg out, amp=0.8, tune=33, decay=0.45, click=0.3;
      var base = tune.midicps;
      var penv = EnvGen.ar(Env([base * 2.5, base * 1.05, base], [0.03, 0.25], [-3, -1]));
      var aenv = EnvGen.ar(Env.perc(0.003, decay * 1.9, 1, -3), doneAction: 2);
      var body = SinOsc.ar(penv, 0.5pi) * aenv;
      var clk  = LPF.ar(Impulse.ar(0), 4000) * click * 2;
      var sig  = ((body * 1.6) + clk).tanh * amp;
      Out.ar(out, sig ! 2);
    }).add;

    // knock: short and tight, a woody second partial on top
    SynthDef(\grad_kick_knock, {
      arg out, amp=0.8, tune=33, decay=0.45, click=0.3;
      var base = (tune + 5).midicps;
      var penv = EnvGen.ar(Env([base * 5, base], [0.02], [-6]));
      var aenv = EnvGen.ar(Env.perc(0.001, decay * 0.45, 1, -6), doneAction: 2);
      var body = (SinOsc.ar(penv, 0.5pi) + (SinOsc.ar(penv * 2.71) * 0.25 * EnvGen.ar(Env.perc(0.001, 0.04))));
      var clk  = BPF.ar(WhiteNoise.ar, 3200, 0.5) * EnvGen.ar(Env.perc(0.0005, 0.01)) * (click * 2.5);
      var sig  = (((body * aenv) + clk) * 1.8).tanh * amp;
      Out.ar(out, sig ! 2);
    }).add;

    // deep: a long, low sub that settles a tone under the tune, a slow soft
    // pitch fall and a felt beater instead of a click
    SynthDef(\grad_kick_deep, {
      arg out, amp=0.8, tune=33, decay=0.45, click=0.3;
      var base = (tune - 2).midicps;
      var penv = EnvGen.ar(Env([base * 3, base * 1.15, base], [0.02, 0.18], [-4, -2]));
      var aenv = EnvGen.ar(Env.perc(0.004, decay * 1.6, 1, -4), doneAction: 2);
      var body = (SinOsc.ar(penv, 0.5pi) + (SinOsc.ar(penv * 2) * 0.08)) * aenv;
      var felt = LPF.ar(WhiteNoise.ar, 900) * EnvGen.ar(Env.perc(0.001, 0.015)) * click;
      var sig  = LPF.ar(((body * 1.5) + felt).tanh, 2500) * amp;
      Out.ar(out, sig ! 2);
    }).add;

    // tight: short and punchy; a fast pitch drop, a quickly closed body and
    // a small high tick
    SynthDef(\grad_kick_tight, {
      arg out, amp=0.8, tune=33, decay=0.45, click=0.3;
      var base = (tune + 3).midicps;
      var penv = EnvGen.ar(Env([base * 7, base * 1.3, base], [0.006, 0.035], [-6, -3]));
      var aenv = EnvGen.ar(Env.perc(0.001, decay * 0.55, 1, -7), doneAction: 2);
      var body = SinOsc.ar(penv, 0.5pi) * aenv;
      var tick = HPF.ar(BPF.ar(WhiteNoise.ar, 4500, 0.7), 2000) * EnvGen.ar(Env.perc(0.0003, 0.004)) * (click * 2);
      var sig  = ((body * 1.7) + tick).tanh * amp;
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

    // metal: the 808 hat, six detuned squares through a band-pass and a
    // high-pass, with a short bright tick on top
    SynthDef(\grad_hat_metal, {
      arg out, echoOut, verbOut, amp=0.3, decay=0.05, tone=8000, pan=0, echo=0, verb=0.1;
      var env = EnvGen.ar(Env.perc(0.0008, decay * 1.3, 1, -5), doneAction: 2);
      var sq  = Mix([205.3, 304.4, 369.6, 522.7, 540, 800].collect { |f| Pulse.ar(f * 2.1) }) * 0.2;
      var sig = BPF.ar(sq, tone.clip(3000, 14000), 0.35);
      sig = HPF.ar(sig + (HPF.ar(sq, 7000) * 0.5), 6000) * 16;
      sig = Pan2.ar(sig * env * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // dust: soft filtered noise, a slow breath in and a longer tail, with a
    // few crackle grains in it; quieter than the noise hat
    SynthDef(\grad_hat_dust, {
      arg out, echoOut, verbOut, amp=0.3, decay=0.05, tone=8000, pan=0, echo=0, verb=0.1;
      var len = (decay * 3) + 0.06;
      var env = EnvGen.ar(Env([0, 1, 0], [0.006, len], [2, -5]), doneAction: 2);
      var f   = (tone * 0.7).clip(1500, 11000);
      var hs  = BPF.ar(PinkNoise.ar, f, 0.9) * 2.4;
      var crk = Decay2.ar(Dust.ar(90), 0.0003, 0.002) * BPF.ar(WhiteNoise.ar, f * 1.3, 0.5) * 3;
      var sig = LPF.ar(hs + crk, (f * 1.6).clip(2000, 15000));
      sig = Pan2.ar(sig * env * amp * 4, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // tape: the noise hat bounced to a worn cassette; a softer transient,
    // saturated and band-limited, a little flutter on the tone
    SynthDef(\grad_hat_tape, {
      arg out, echoOut, verbOut, amp=0.3, decay=0.05, tone=8000, pan=0, echo=0, verb=0.1;
      var env = EnvGen.ar(Env([0, 1, 0], [0.002, (decay * 1.4) + 0.01], [1, -5]), doneAction: 2);
      var f   = (tone * 0.8 * (1 + (LFNoise2.kr(7) * 0.04))).clip(1000, 12000);
      var sig = RHPF.ar(WhiteNoise.ar, f, 0.5);
      sig = LPF.ar((sig * 2).tanh, 9000);
      sig = HPF.ar(sig, 1500);
      sig = Pan2.ar(sig * env * amp * 1.6, pan);
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

    // ----------------------------------------------------------- percussion

    // clap: four bursts of band-passed noise, then a short room tail
    SynthDef(\grad_clap, {
      arg out, echoOut, verbOut, amp=0.3, tone=1200, pan=0, echo=0.3, verb=0.35;
      var bursts = EnvGen.ar(Env([0, 1, 0.2, 1, 0.2, 1, 0.2, 1, 0],
        [0.001, 0.009, 0.001, 0.009, 0.001, 0.011, 0.001, 0.16], [0, -4, 0, -4, 0, -4, 0, -5]),
        doneAction: 2);
      var sig = BPF.ar(WhiteNoise.ar, tone.clip(500, 4000), 0.55) * 2.2;
      sig = (sig + (HPF.ar(WhiteNoise.ar, 5000) * 0.25)) * bursts * amp;
      sig = Pan2.ar(sig, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // snare: a tuned body under a noise skin
    SynthDef(\grad_snare, {
      arg out, echoOut, verbOut, amp=0.3, tone=1200, pan=0, echo=0.3, verb=0.35;
      var f    = tone.linlin(500, 4000, 160, 260);
      var body = SinOsc.ar(EnvGen.ar(Env([f * 1.6, f], [0.02], -4)))
                 * EnvGen.ar(Env.perc(0.001, 0.08, 1, -6)) * 0.8;
      var skin = BPF.ar(WhiteNoise.ar, tone * 3, 0.9) * EnvGen.ar(Env.perc(0.001, 0.17, 1, -5), doneAction: 2);
      var sig  = ((body + (skin * 1.4)) * 1.2).tanh * amp;
      sig = Pan2.ar(sig, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // snap: a finger-snap crack, mostly there for the spring
    SynthDef(\grad_snap, {
      arg out, echoOut, verbOut, amp=0.3, tone=1200, pan=0, echo=0.3, verb=0.35;
      var env = EnvGen.ar(Env.perc(0.0005, 0.045, 1, -8), doneAction: 2);
      var sig = (BPF.ar(WhiteNoise.ar, tone * 2.2, 0.3) * 3) + (SinOsc.ar(tone * 1.1) * EnvGen.ar(Env.perc(0.0005, 0.008)));
      sig = Pan2.ar(sig * env * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // hand drum: a bent sine body and a slap, tuned to the chord
    SynthDef(\grad_perc_hand, {
      arg out, echoOut, verbOut, amp=0.3, freq=220, decay=0.25, pan=0, echo=0.35, verb=0.2;
      var env  = EnvGen.ar(Env.perc(0.001, decay, 1, -5), doneAction: 2);
      var body = SinOsc.ar(EnvGen.ar(Env([freq * 1.25, freq], [0.03], -3)));
      var slap = Resonz.ar(WhiteNoise.ar, freq * 3.1, 0.3) * EnvGen.ar(Env.perc(0.0005, 0.015)) * 2;
      var sig  = (((body * env) + slap) * 1.2).tanh * amp;
      sig = Pan2.ar(sig, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // wood: a clave / log, a ringing resonator on a click
    SynthDef(\grad_perc_wood, {
      arg out, echoOut, verbOut, amp=0.3, freq=900, decay=0.25, pan=0, echo=0.35, verb=0.2;
      var exc = Impulse.ar(0) + (WhiteNoise.ar * EnvGen.ar(Env.perc(0.0002, 0.002)) * 0.3);
      var sig = Ringz.ar(exc, [freq, freq * 2.57], [decay * 0.35, decay * 0.12]);
      sig = Mix(sig * [1, 0.35]) * 0.6;
      DetectSilence.ar(sig, 0.0005, 0.05, doneAction: 2);
      sig = Pan2.ar(sig.tanh * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // metal: a cowbell / agogo from two squares through a band-pass
    SynthDef(\grad_perc_metal, {
      arg out, echoOut, verbOut, amp=0.3, freq=560, decay=0.25, pan=0, echo=0.35, verb=0.2;
      var env = EnvGen.ar(Env([0, 1, 0.3, 0], [0.001, 0.03, decay], [0, -3, -4]), doneAction: 2);
      var sig = (Pulse.ar(freq) + Pulse.ar(freq * 1.48)) * 0.5;
      sig = BPF.ar(sig, freq * 1.5, 0.6) * 2;
      sig = Pan2.ar(sig * env * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // ride: six detuned squares, the 808 way, high-passed
    SynthDef(\grad_ride, {
      arg out, verbOut, amp=0.2, decay=0.6, tone=7000, pan=0, verb=0.12;
      var env = EnvGen.ar(Env.perc(0.002, decay, 1, -4), doneAction: 2);
      var sig = Mix([205.3, 304.4, 369.6, 522.7, 540, 800].collect { |f| Pulse.ar(f * 1.7) }) * 0.18;
      sig = BPF.ar(sig, tone.clip(3000, 12000), 0.5) + (HPF.ar(sig, 9000) * 0.4);
      sig = Pan2.ar(sig * env * amp, pan);
      Out.ar(out, sig);
      Out.ar(verbOut, sig * verb);
    }).add;

    // glitch ticks: tiny digital sounds, clicks-and-cuts style
    SynthDef(\grad_tick_click, {
      arg out, echoOut, verbOut, amp=0.2, freq=3000, pan=0, echo=0.3, verb=0.1;
      var sig = RHPF.ar(Impulse.ar(0) * 4, freq.clip(800, 12000), 0.05);
      DetectSilence.ar(sig, 0.0005, 0.02, doneAction: 2);
      sig = Pan2.ar(sig.clip2(1) * amp, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    SynthDef(\grad_tick_blip, {
      arg out, echoOut, verbOut, amp=0.2, freq=3000, pan=0, echo=0.3, verb=0.1;
      var env = EnvGen.ar(Env.linen(0.0005, 0.012, 0.004), doneAction: 2);
      var sig = Pan2.ar(SinOsc.ar(freq.clip(200, 12000)) * env * amp * 0.7, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    SynthDef(\grad_tick_crush, {
      arg out, echoOut, verbOut, amp=0.2, freq=3000, pan=0, echo=0.3, verb=0.1;
      var env = EnvGen.ar(Env.linen(0.0005, 0.025, 0.005), doneAction: 2);
      var sig = Latch.ar(WhiteNoise.ar, Impulse.ar(freq.clip(400, 8000)));
      sig = (sig * 4).round(0.5) * 0.25;
      sig = Pan2.ar(sig * env * amp * 0.6, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    SynthDef(\grad_tick_zap, {
      arg out, echoOut, verbOut, amp=0.2, freq=3000, pan=0, echo=0.3, verb=0.1;
      var env = EnvGen.ar(Env.perc(0.0005, 0.05, 1, -4), doneAction: 2);
      var f   = EnvGen.ar(Env([freq.clip(400, 12000), 60], [0.05], \exp));
      var sig = Pan2.ar(Pulse.ar(f, 0.3) * env * amp * 0.4, pan);
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

    // reese: three detuned saws beating slowly over a sine sub, low-passed
    // with a slow filter drift
    SynthDef(\grad_bass_reese, {
      arg out, freq=55, amp=0.5, dur=0.3, cutoff=260, drive=0.3, from=0, glide=0.05;
      var env = EnvGen.ar(Env.linen(0.006, dur, 0.1, 1, -3), doneAction: 2);
      var f   = Select.kr(from > 0, [freq,
        EnvGen.kr(Env([from.max(20), freq], [glide.max(0.001)], \exp))]);
      var saws = Saw.ar(f * [0.9946, 1, 1.0057], [0.4, 0.3, 0.4]);
      var cut  = (cutoff * 1.8 * (1 + (SinOsc.kr(0.23) * 0.25))).clip(60, 5000);
      var sig;
      saws = RLPF.ar(saws, cut, 0.55);
      sig = (SinOsc.ar(f) * 0.75) + [saws[0] + (saws[1] * 0.5), saws[2] + (saws[1] * 0.5)];
      sig = (sig * (1 + (drive * 3))).tanh * env * amp * 0.95;
      Out.ar(out, sig);
    }).add;

    // rubber: a round FM bass, the index falling away fast and a pitch blip
    // up at the start so each note bounces in
    SynthDef(\grad_bass_rubber, {
      arg out, freq=55, amp=0.5, dur=0.3, cutoff=260, drive=0.3, from=0, glide=0.05;
      var env  = EnvGen.ar(Env.linen(0.003, dur, 0.07, 1, -3), doneAction: 2);
      var f    = Select.kr(from > 0, [freq,
        EnvGen.kr(Env([from.max(20), freq], [glide.max(0.001)], \exp))]);
      var blip = EnvGen.ar(Env([1.9, 1, 0.985, 1], [0.035, 0.06, 0.12], [-4, 2, 0]));
      var ienv = EnvGen.ar(Env([2.4, 0.7, 0.35], [0.06, dur.max(0.05)], [-4, -2]));
      var mod  = SinOsc.ar(f * blip) * f * ienv;
      var sig  = SinOsc.ar((f * blip) + mod);
      sig = LPF.ar(sig, (cutoff * 4).clip(120, 6000));
      sig = (sig * (1 + (drive * 2.5))).tanh * env * amp * 1.0;
      Out.ar(out, sig ! 2);
    }).add;

    // fm sub: a sine sub with a 2:1 FM overtone that blooms and settles on
    // each note, so it speaks on small speakers and keeps its weight
    SynthDef(\grad_bass_fmsub, {
      arg out, freq=55, amp=0.5, dur=0.3, cutoff=260, drive=0.3, from=0, glide=0.05;
      var env  = EnvGen.ar(Env.linen(0.004, dur, 0.08, 1, -3), doneAction: 2);
      var f    = Select.kr(from > 0, [freq,
        EnvGen.kr(Env([from.max(20), freq], [glide.max(0.001)], \exp))]);
      var ienv = EnvGen.ar(Env([0, 1, 0.3], [0.01, dur.max(0.05)], [2, -3]));
      var mod  = SinOsc.ar(f * 2) * f * (0.2 + (ienv * 0.9)) * (0.5 + drive);
      var sig  = (SinOsc.ar(f + mod) * 0.6) + (SinOsc.ar(f) * 0.6);
      sig = LPF.ar(sig, (cutoff * 3).clip(80, 3000));
      sig = (sig * (1 + (drive * 2))).tanh * env * amp;
      Out.ar(out, sig ! 2);
    }).add;

    // tape: the sub bass through a tape machine; slow wow on the pitch, a
    // soft saturated knee, a head bump and the top rolled off
    SynthDef(\grad_bass_tape, {
      arg out, freq=55, amp=0.5, dur=0.3, cutoff=260, drive=0.3, from=0, glide=0.05;
      var env = EnvGen.ar(Env.linen(0.006, dur, 0.09, 1, -3), doneAction: 2);
      var f   = Select.kr(from > 0, [freq,
        EnvGen.kr(Env([from.max(20), freq], [glide.max(0.001)], \exp))]);
      var wow = 1 + (LFNoise2.kr(0.7) * 0.0025) + (SinOsc.kr(0.5) * 0.0015);
      var fw  = f * wow;
      var sig = SinOsc.ar(fw) + (LFTri.ar(fw * 2) * 0.18) + (Saw.ar(fw) * 0.1);
      sig = RLPF.ar(sig, (cutoff * 1.2).clip(40, 4000), 0.8);
      sig = (sig * (1.4 + (drive * 3))).tanh;
      sig = sig + (BPF.ar(sig, 90, 1) * 0.3);
      sig = LPF.ar(sig, 2200) * env * amp * 0.85;
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

    // the other chord stabs share grad_chord's args and sends

    // felt: soft, muted, dark; triangles with a slow attack under a closed
    // low-pass, like a damped piano through a blanket
    SynthDef(\grad_chord_felt, {
      arg out, echoOut, verbOut, f1=220, f2=261, f3=329, f4=392,
          amp=0.3, dur=0.2, cutoff=1400, res=0.35, envAmt=1.6, detune=0.18,
          echo=0.55, verb=0.35;
      var d    = detune * 0.006;
      var env  = EnvGen.ar(Env([0, 1, 0], [0.018, (dur * 1.6) + 0.12], [2, -4]), doneAction: 2);
      var fenv = EnvGen.ar(Env.perc(0.01, dur, 1, -4));
      var sig  = Mix([f1, f2, f3, f4].collect { |f| LFTri.ar(f * [1 - d, 1 + d]) + (SinOsc.ar(f * 0.5) * 0.3) }) * 0.135;
      sig = LPF.ar(sig, (cutoff * 0.45 * (1 + (fenv * envAmt * 0.4))).clip(150, 3000));
      sig = sig * env * amp;
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // organ: four drawbars per note (16', 8', 4', 2 2/3') and a key click,
    // the notes spread a little across the stereo field
    SynthDef(\grad_chord_organ, {
      arg out, echoOut, verbOut, f1=220, f2=261, f3=329, f4=392,
          amp=0.3, dur=0.2, cutoff=1400, res=0.35, envAmt=1.6, detune=0.18,
          echo=0.55, verb=0.35;
      var env   = EnvGen.ar(Env.linen(0.004, dur * 0.8, (dur * 0.5) + 0.04, 1, -2), doneAction: 2);
      var click = BPF.ar(WhiteNoise.ar, 2400, 0.8) * EnvGen.ar(Env.perc(0.0005, 0.006)) * 0.6;
      var bars  = [f1, f2, f3, f4].collect { |f, i|
        Pan2.ar(Klang.ar(`[[0.5, 1, 2, 3], [0.55, 1, 0.45, 0.3], nil], f), (i - 1.5) * 0.25)
      };
      var sig = (Mix(bars) * 0.09) + (click ! 2);
      sig = LPF.ar(sig, (cutoff * 3).clip(800, 9000));
      sig = sig * env * amp;
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // glass: an FM bell per note with an inharmonic modulator, its index
    // dying away and a long, slightly detuned shimmer left behind
    SynthDef(\grad_chord_glass, {
      arg out, echoOut, verbOut, f1=220, f2=261, f3=329, f4=392,
          amp=0.3, dur=0.2, cutoff=1400, res=0.35, envAmt=1.6, detune=0.18,
          echo=0.55, verb=0.35;
      var len  = (dur * 4) + 0.9;
      var env  = EnvGen.ar(Env.perc(0.002, len, 1, -5), doneAction: 2);
      var ienv = EnvGen.ar(Env.perc(0.001, len * 0.3, 1, -4));
      var d    = (detune * 0.004) + 0.0005;
      var sig  = Mix([f1, f2, f3, f4].collect { |f|
        var mod = SinOsc.ar(f * 3.51) * f * (0.4 + (ienv * 2.2));
        SinOsc.ar((f * [1 - d, 1 + d]) + mod)
      }) * 0.104;
      sig = LPF.ar(sig, (cutoff * 5).clip(1500, 14000));
      sig = sig * env * amp;
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // rhodes: an electric-piano tine; a 1:1 FM bark on the attack, a short
    // bell partial, and a stereo tremolo across the decay
    SynthDef(\grad_chord_rhodes, {
      arg out, echoOut, verbOut, f1=220, f2=261, f3=329, f4=392,
          amp=0.3, dur=0.2, cutoff=1400, res=0.35, envAmt=1.6, detune=0.18,
          echo=0.55, verb=0.35;
      var len  = (dur * 3) + 0.5;
      var env  = EnvGen.ar(Env.perc(0.003, len, 1, -4), doneAction: 2);
      var ienv = EnvGen.ar(Env.perc(0.001, 0.25, 1, -4));
      var benv = EnvGen.ar(Env.perc(0.0005, 0.08, 1, -6));
      var trem = 1 - ((SinOsc.kr(4.6, [0, pi]) + 1) * 0.15);
      var sig  = Mix([f1, f2, f3, f4].collect { |f|
        var mod = SinOsc.ar(f) * f * (0.15 + (ienv * 1.4));
        SinOsc.ar(f + mod) + (SinOsc.ar(f * 7.03) * benv * 0.25)
      }) * 0.14;
      sig = LPF.ar(sig, (cutoff * 3).clip(800, 10000));
      sig = (sig ! 2) * trem * env * amp;
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // choir: a detuned saw pair per note, each with its own vibrato, sung
    // through formants that close from ah towards oo as the stab falls
    SynthDef(\grad_chord_choir, {
      arg out, echoOut, verbOut, f1=220, f2=261, f3=329, f4=392,
          amp=0.3, dur=0.2, cutoff=1400, res=0.35, envAmt=1.6, detune=0.18,
          echo=0.55, verb=0.35;
      var len = (dur * 2.5) + 0.4;
      var env = EnvGen.ar(Env([0, 1, 0], [0.06, len], [2, -4]), doneAction: 2);
      var v   = EnvGen.kr(Env([0, 1], [len], [-2]));
      var d   = (detune * 0.008) + 0.001;
      var src = Mix([f1, f2, f3, f4].collect { |f, i|
        var vib = 1 + (SinOsc.kr(4.7 + (i * 0.4), i) * 0.0025);
        LFSaw.ar(f * vib * [1 - d, 1 + d])
      }) * 0.25;
      var sig = (BPF.ar(src, v.linlin(0, 1, 750, 350), 0.14) * 1.0)
                + (BPF.ar(src, v.linlin(0, 1, 1150, 700), 0.12) * 0.6)
                + (BPF.ar(src, 2600, 0.1) * 0.2);
      sig = LPF.ar(sig, (cutoff * 3).clip(800, 9000));
      sig = sig * env * amp * 2.6;
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // strings: a short bowed-section stab; saw pairs swell in under a
    // gentle low-pass and a two-tap chorus spreads them left and right
    SynthDef(\grad_chord_strings, {
      arg out, echoOut, verbOut, f1=220, f2=261, f3=329, f4=392,
          amp=0.3, dur=0.2, cutoff=1400, res=0.35, envAmt=1.6, detune=0.18,
          echo=0.55, verb=0.35;
      var len  = (dur * 2) + 0.3;
      var env  = EnvGen.ar(Env([0, 1, 0.7, 0], [0.03, dur * 0.6, len], [2, -1, -4]), doneAction: 2);
      var fenv = EnvGen.ar(Env.perc(0.03, dur, 1, -3));
      var d    = (detune * 0.008) + 0.001;
      var src  = Mix([f1, f2, f3, f4].collect { |f| Saw.ar(f * [1 - d, 1 + d]) }) * 0.15;
      var mono, sig;
      src  = LPF.ar(src, (cutoff * 1.2 * (1 + (fenv * envAmt * 0.3))).clip(200, 8000));
      mono = HPF.ar(src[0] + src[1], 100);
      sig  = [DelayC.ar(mono, 0.03, 0.011 + (SinOsc.kr(0.7) * 0.003)),
              DelayC.ar(mono, 0.03, 0.014 + (SinOsc.kr(0.53, 1) * 0.003))];
      sig  = (sig + (mono * 0.5)) * 0.85 * env * amp;
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

    // glass: a pure tone and its octave beating slowly against each other,
    // with a quick inharmonic glint on the attack
    SynthDef(\grad_arp_glass, {
      arg out, echoOut, verbOut, leadOut, freq=440, amp=0.2, decay=0.25, cutoff=3000,
          shape=0.5, pan=0, echo=0.2, verb=0.4, lead=0.3;
      var len  = (decay * 2.2) + 0.15;
      var env  = EnvGen.ar(Env.perc(0.003, len, 1, -5), doneAction: 2);
      var genv = EnvGen.ar(Env.perc(0.0005, 0.05, 1, -6));
      var sig  = SinOsc.ar(freq) + (SinOsc.ar(freq * 2.003) * shape.linlin(0, 1, 0.15, 0.6))
                 + (SinOsc.ar(freq * 5.43) * genv * 0.5);
      sig = LPF.ar(sig, (cutoff * 3).clip(400, 16000));
      sig = Pan2.ar(sig * env * amp * 1.1, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
      Out.ar(leadOut, sig * lead);
    }).add;

    // reed: a melodica / harmonium, two narrow pulses through a nasal
    // formant, a breathy attack and a little vibrato
    SynthDef(\grad_arp_reed, {
      arg out, echoOut, verbOut, leadOut, freq=440, amp=0.2, decay=0.25, cutoff=3000,
          shape=0.5, pan=0, echo=0.2, verb=0.4, lead=0.3;
      var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.025, decay * 0.6, (decay * 0.8) + 0.06], [2, -1, -4]), doneAction: 2);
      var vib = 1 + (SinOsc.kr(5.2) * 0.003 * EnvGen.kr(Env([0, 0, 1], [0.08, 0.2])));
      var w   = shape.linlin(0, 1, 0.12, 0.38);
      var sig = (Pulse.ar(freq * vib, w) + Pulse.ar(freq * vib * 1.004, w)) * 0.5;
      sig = sig + (BPF.ar(WhiteNoise.ar, freq * 3, 0.5) * EnvGen.ar(Env.perc(0.005, 0.05)) * 0.3);
      sig = BPF.ar(sig, 1250, 1.2) + (RLPF.ar(sig, cutoff.clip(300, 9000), 0.7) * 0.6);
      sig = Pan2.ar(sig * env * amp * 1.2, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
      Out.ar(leadOut, sig * lead);
    }).add;

    // kalimba: a struck tine; the fundamental rings, its high inharmonic
    // partial dies fast, and a woody knock sits under the attack
    SynthDef(\grad_arp_kalimba, {
      arg out, echoOut, verbOut, leadOut, freq=440, amp=0.2, decay=0.25, cutoff=3000,
          shape=0.5, pan=0, echo=0.2, verb=0.4, lead=0.3;
      var len  = (decay * 3) + 0.3;
      var env  = EnvGen.ar(Env.linen(0, len, 0.05), doneAction: 2);
      var exc  = Impulse.ar(0) + (LPF.ar(WhiteNoise.ar, 3000) * EnvGen.ar(Env.perc(0.0002, 0.004)) * 0.5);
      var ring = Ringz.ar(exc, [freq, freq * 5.93, freq * 0.5], [len * 0.55, 0.05, 0.03]);
      var sig  = Mix(ring * [1, shape.linlin(0, 1, 0.15, 0.5), 0.6]) * 0.32;
      sig = LPF.ar(sig, (cutoff * 2.5).clip(400, 16000)).tanh;
      sig = Pan2.ar(sig * env * amp * 1.8, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
      Out.ar(leadOut, sig * lead);
    }).add;

    // marimba: a soft mallet into a bar resonator, tuned 1 : 4 : 10 like a
    // real bar, the upper modes damped quickly
    SynthDef(\grad_arp_marimba, {
      arg out, echoOut, verbOut, leadOut, freq=440, amp=0.2, decay=0.25, cutoff=3000,
          shape=0.5, pan=0, echo=0.2, verb=0.4, lead=0.3;
      var len  = (decay * 2) + 0.25;
      var env  = EnvGen.ar(Env.linen(0, len, 0.05), doneAction: 2);
      var mal  = LPF.ar(WhiteNoise.ar, shape.linlin(0, 1, 900, 3000)) * EnvGen.ar(Env.perc(0.001, 0.004, 1, -2));
      var ring = Ringz.ar(mal, [freq, freq * 3.99, freq * 9.85], [len * 0.4, len * 0.12, 0.03]);
      var sig  = Mix(ring * [1, 0.25, 0.08]) * 1.1;
      sig = LPF.ar(sig, (cutoff * 2.5).clip(400, 16000)).tanh;
      sig = Pan2.ar(sig * env * amp * 1.5, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
      Out.ar(leadOut, sig * lead);
    }).add;

    // steel: a steel-pan note; three tuned modes (the octave and twelfth a
    // little stretched), the upper ones dying first, a brief ping on top
    SynthDef(\grad_arp_steel, {
      arg out, echoOut, verbOut, leadOut, freq=440, amp=0.2, decay=0.25, cutoff=3000,
          shape=0.5, pan=0, echo=0.2, verb=0.4, lead=0.3;
      var len  = (decay * 2.5) + 0.2;
      var env  = EnvGen.ar(Env.linen(0, len, 0.05), doneAction: 2);
      var amps = [1, shape.linlin(0, 1, 0.3, 0.7), 0.25];
      var decs = [len * 0.5, len * 0.25, len * 0.1];
      var sig  = Mix([1, 2.01, 2.99].collect { |r, i|
        SinOsc.ar(freq * r) * EnvGen.ar(Env.perc(0.002, decs[i], 1, -5)) * amps[i]
      });
      sig = sig + (SinOsc.ar(freq * 4.02) * EnvGen.ar(Env.perc(0.0005, 0.02)) * 0.15);
      sig = LPF.ar(sig, (cutoff * 3).clip(400, 16000));
      sig = Pan2.ar(sig * env * amp * 1.0, pan);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
      Out.ar(leadOut, sig * lead);
    }).add;

    // bowed: a bowed string; a saw with a slow bow-in, delayed vibrato, a
    // little bow noise and two body resonances
    SynthDef(\grad_arp_bowed, {
      arg out, echoOut, verbOut, leadOut, freq=440, amp=0.2, decay=0.25, cutoff=3000,
          shape=0.5, pan=0, echo=0.2, verb=0.4, lead=0.3;
      var len = (decay * 2) + 0.25;
      var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.06, decay, len], [2, -1, -4]), doneAction: 2);
      var vib = 1 + (SinOsc.kr(5.4) * 0.004 * EnvGen.kr(Env([0, 0, 1], [0.1, 0.25])));
      var sig = Saw.ar(freq * vib) + (BPF.ar(WhiteNoise.ar, freq * 2, 0.3) * 0.15 * shape);
      sig = LPF.ar(sig, (cutoff * 0.9).clip(300, 8000));
      sig = (sig * 0.6) + (BPF.ar(sig, 450, 0.8) * 0.5) + (BPF.ar(sig, 1600, 1) * 0.3);
      sig = Pan2.ar(sig * env * amp * 3.0, pan);
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

    // the other pads share grad_wash's args and its slow amp lag; pad_type
    // crossfades between them

    // choir: soft pulse voices on the chord, a little vibrato each, through
    // three vowel formants that wander slowly between ah, oh and oo
    SynthDef(\grad_pad_choir, {
      arg out, echoOut, verbOut, f1=110, f2=130, f3=165, f4=196,
          amp=0, cutoff=700, echo=0.1, verb=0.5;
      var freqs = [f1, f2, f3, f4].collect { |f| Lag.kr(f, 3) };
      var src = Mix(freqs.collect { |f, i|
        var vib = 1 + (LFNoise2.kr(4 + i) * 0.003);
        LFSaw.ar(f * vib * [0.998, 1.002])
      }) * 0.25;
      var x = LFNoise2.kr(0.06).range(0, 1);
      var y = LFNoise2.kr(0.045).range(0, 1);
      var form = [x.linlin(0, 1, 330, 750), (x * y).linlin(0, 1, 750, 1150), y.linlin(0, 1, 2450, 2850)];
      var sig = (BPF.ar(src, form[0], 0.12) * 1.0) + (BPF.ar(src, form[1], 0.1) * 0.6)
                + (BPF.ar(src, form[2], 0.08) * 0.25);
      sig = LPF.ar(sig * 0.82, (Lag.kr(cutoff, 4) * 4).clip(300, 9000));
      sig = sig * Lag.kr(amp, 6);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // strings: slow bowed saws, each note swelling on its own, through a
    // three-tap ensemble chorus spread left and right
    SynthDef(\grad_pad_strings, {
      arg out, echoOut, verbOut, f1=110, f2=130, f3=165, f4=196,
          amp=0, cutoff=700, echo=0.1, verb=0.5;
      var freqs = [f1, f2, f3, f4].collect { |f| Lag.kr(f, 3) };
      var src = Mix(freqs.collect { |f, i|
        var bow = 0.7 + (LFNoise2.kr(0.13 + (i * 0.04)) * 0.3);
        Saw.ar(f * [0.9985, 1.0015]) * bow
      }) * 0.12;
      var mono, taps, sig;
      src = LPF.ar(src, (Lag.kr(cutoff, 4) * 2 * (1 + (LFNoise2.kr(0.05) * 0.2))).clip(150, 8000));
      mono = HPF.ar(src[0] + src[1], 90);
      taps = [0.0, 0.33, 0.67].collect { |ph|
        DelayC.ar(mono, 0.03, 0.012 + (SinOsc.kr(0.6, ph * 2pi) * 0.004) + (SinOsc.kr(5.7, ph * 2pi) * 0.0005))
      };
      sig = [taps[0] + (taps[1] * 0.6) + (mono * 0.4), taps[2] + (taps[1] * 0.6) + (mono * 0.4)] * 0.62;
      sig = sig * Lag.kr(amp, 6);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // drone: one deep tone on the chord root (an octave down) and its
    // fifth, the pairs beating slowly, with tape wow, warmth and a little hiss
    SynthDef(\grad_pad_drone, {
      arg out, echoOut, verbOut, f1=110, f2=130, f3=165, f4=196,
          amp=0, cutoff=700, echo=0.1, verb=0.5;
      var root = Lag.kr(f1, 3) * 0.5;
      var wow  = 1 + (LFNoise2.kr(0.4) * 0.0015) + (SinOsc.kr(0.11) * 0.001);
      var r    = root * wow;
      var low  = SinOsc.ar(r * [1, 1.0021]) + (LFTri.ar(r * [2.002, 1.998]) * 0.3);
      var fifth = Saw.ar(r * 1.5 * [0.9993, 1.0009]) * 0.35;
      var sig;
      fifth = LPF.ar(fifth, (Lag.kr(cutoff, 4) * 1.2).clip(120, 5000));
      sig = ((low * 0.5) + fifth) * (1 + (LFNoise2.kr(0.08) * 0.15));
      sig = (sig * 1.4).tanh * 0.7;
      sig = sig + (HPF.ar({ PinkNoise.ar } ! 2, 3000) * 0.012);
      sig = LPF.ar(sig, 7000) * 0.22;
      sig = sig * Lag.kr(amp, 6);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // glass: sine partials on each note, the octave and twelfth shimmering
    // in and out on slow independent drifts, like wine glasses held ringing
    SynthDef(\grad_pad_glass, {
      arg out, echoOut, verbOut, f1=110, f2=130, f3=165, f4=196,
          amp=0, cutoff=700, echo=0.1, verb=0.5;
      var freqs = [f1, f2, f3, f4].collect { |f| Lag.kr(f, 3) };
      var sig = Mix(freqs.collect { |f, i|
        var sh  = LFNoise2.kr(0.11 + (i * 0.027)).range(0, 1);
        var sh2 = LFNoise2.kr(0.07 + (i * 0.031)).range(0, 1);
        var p   = SinOsc.ar(f) + (SinOsc.ar(f * 2.003) * sh * 0.5) + (SinOsc.ar(f * 3.004) * sh2 * 0.18);
        Pan2.ar(p, (i - 1.5) * 0.4)
      }) * 0.05;
      sig = LPF.ar(sig, (Lag.kr(cutoff, 4) * 6).clip(400, 9000));
      sig = sig * Lag.kr(amp, 6);
      Out.ar(out, sig);
      Out.ar(echoOut, sig * echo);
      Out.ar(verbOut, sig * verb);
    }).add;

    // tape loop: the chord as a worn loop; saws under a dark low-pass with
    // shared wow and flutter on the pitch, a soft dip each time the splice
    // comes round (every eight seconds) and a breath of hiss
    SynthDef(\grad_pad_tapeloop, {
      arg out, echoOut, verbOut, f1=110, f2=130, f3=165, f4=196,
          amp=0, cutoff=700, echo=0.1, verb=0.5;
      var freqs = [f1, f2, f3, f4].collect { |f| Lag.kr(f, 3) };
      var wow = 1 + (LFNoise2.kr(0.3) * 0.003) + (SinOsc.kr(0.13) * 0.002) + (LFNoise1.kr(9) * 0.0006);
      var dip = 1 - (Lag.kr(LFPulse.kr(0.125, 0, 0.04), 0.1) * 0.35);
      var sig = Mix(freqs.collect { |f, i|
        Saw.ar(f * wow * [0.998 + (i * 0.0004), 1.002 - (i * 0.0004)])
      }) * 0.1;
      sig = LPF.ar(sig, (Lag.kr(cutoff, 4) * 0.9).clip(80, 5000));
      sig = (sig * 1.5).tanh * 0.7 * dip;
      sig = sig + (HPF.ar({ PinkNoise.ar } ! 2, 4000) * 0.008);
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
    // on the delay line, lagged time so tempo changes slide like tape.
    // xin / xout are echo_type's crossfade (input and output gains, both 1
    // unless a swap is fading this echo in or out); every echo type has them
    SynthDef(\grad_echo, {
      arg in, out, verbOut, time=0.375, fb=0.55, lpf=2500, hpf=300,
          wow=0.3, sat=0.4, pp=0.7, verb=0.3, xin=1, xout=1;
      var input = In.ar(in, 2) * Lag.kr(xin, 0.1);
      var xo    = Lag.kr(xout, 2.5);
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
      Out.ar(out, del * xo);
      Out.ar(verbOut, (del * verb) * xo);
    }).add;

    // the other echoes share grad_echo's args; echo_type crossfades them

    // tape: a single-head tape echo; both sides share the repeat, the right
    // head a hair later so the repeats widen as they go, with deeper wow and
    // flutter, more saturation and a darker top
    SynthDef(\grad_echo_tape, {
      arg in, out, verbOut, time=0.375, fb=0.55, lpf=2500, hpf=300,
          wow=0.3, sat=0.4, pp=0.7, verb=0.3, xin=1, xout=1;
      var input = In.ar(in, 2) * Lag.kr(xin, 0.1);
      var xo    = Lag.kr(xout, 2.5);
      var t     = Lag.kr(time, 1.2);
      var w     = wow + 0.2;
      var mod   = (LFNoise2.kr(0.6) * 0.004 * w) + (SinOsc.kr(0.23) * 0.003 * w) + (LFNoise1.kr(11) * 0.0003);
      var fbk   = LocalIn.ar(2);
      var m     = Mix(input) * 0.6;
      var sig, del;
      sig = [m, m] + (fbk * Lag.kr(fb, 0.2).clip(0, 1.02));
      sig = LPF.ar(sig, (Lag.kr(lpf, 0.3) * 0.75).clip(200, 12000));
      sig = HPF.ar(sig, Lag.kr(hpf, 0.3).clip(20, 4000));
      sig = (sig * (1.5 + (sat * 2.5))).tanh / (1.2 + sat);
      del = DelayC.ar(sig, 2.5, ((t + mod) * [1, 1.012]).clip(0.01, 2.4));
      LocalOut.ar(del);
      del = del * 1.6;
      Out.ar(out, del * xo);
      Out.ar(verbOut, (del * verb) * xo);
    }).add;

    // ping-pong: a clean, bright digital ping-pong; the input enters on the
    // left and every repeat crosses over, with barely any wow or grit
    SynthDef(\grad_echo_pingpong, {
      arg in, out, verbOut, time=0.375, fb=0.55, lpf=2500, hpf=300,
          wow=0.3, sat=0.4, pp=0.7, verb=0.3, xin=1, xout=1;
      var input = In.ar(in, 2) * Lag.kr(xin, 0.1);
      var xo    = Lag.kr(xout, 2.5);
      var t     = Lag.kr(time, 0.8);
      var mod   = SinOsc.kr(0.17) * 0.0003 * wow;
      var fbk   = LocalIn.ar(2);
      var sig, del;
      sig = [Mix(input), DC.ar(0)] + (fbk * Lag.kr(fb, 0.2).clip(0, 1.0));
      sig = LPF.ar(sig, (Lag.kr(lpf, 0.3) * 1.6).clip(400, 16000));
      sig = HPF.ar(sig, (Lag.kr(hpf, 0.3) * 0.7).clip(20, 4000));
      sig = (sig * (1 + (sat * 0.6))).tanh / (1 + (sat * 0.3));
      del = DelayC.ar(sig, 2.5, (t + mod).clip(0.01, 2.4));
      LocalOut.ar([del[1], del[0]]);
      del = del * 1.35;
      Out.ar(out, del * xo);
      Out.ar(verbOut, (del * verb) * xo);
    }).add;

    // space: a three-head tape echo (heads at a third, two thirds and the
    // full time, one tape loop read three ways) with a little spring-like
    // diffusion in the loop, so the repeats smear into a wash as they go
    SynthDef(\grad_echo_space, {
      arg in, out, verbOut, time=0.375, fb=0.55, lpf=2500, hpf=300,
          wow=0.3, sat=0.4, pp=0.7, verb=0.3, xin=1, xout=1;
      var frames = 131072;
      var input = In.ar(in, 2) * Lag.kr(xin, 0.1);
      var xo    = Lag.kr(xout, 2.5);
      var t     = Lag.kr(time, 1.0);
      var mod   = (LFNoise2.kr(0.5) * 0.003 * wow) + (SinOsc.kr(0.19) * 0.002 * wow);
      var fbk   = LocalIn.ar(2);
      var buf   = LocalBuf(frames, 2).clear;
      var wp    = Phasor.ar(0, 1, 0, frames);
      var inj   = XFade2.ar(input, [Mix(input), DC.ar(0)], (pp * 2) - 1);
      var tap   = { |k| BufRd.ar(2, buf, (wp - (((t * k) + mod).clip(0.01, 2.4) * SampleRate.ir)).wrap(0, frames), 1, 4) };
      var sig, h1, h2, h3, diff;
      diff = AllpassN.ar(fbk, 0.03, [0.0123, 0.0171], 0.3);
      diff = AllpassN.ar(diff, 0.03, [0.0089, 0.0067], 0.2);
      sig = inj + (diff * Lag.kr(fb, 0.2).clip(0, 1.0));
      sig = LPF.ar(sig, (Lag.kr(lpf, 0.3) * 0.9).clip(200, 12000));
      sig = HPF.ar(sig, Lag.kr(hpf, 0.3).clip(20, 4000));
      sig = (sig * (1 + (sat * 2))).tanh / (1 + (sat * 0.8));
      BufWr.ar(sig, buf, wp);
      h1 = tap.(1 / 3);
      h2 = tap.(2 / 3);
      h3 = tap.(1);
      LocalOut.ar((h3 * 0.7) + (h2 * 0.3));
      sig = ((h1 * 0.35) + (h2 * 0.5) + (h3 * 0.75)) * 1.3;
      Out.ar(out, sig * xo);
      Out.ar(verbOut, (sig * verb) * xo);
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

    // the glitch insert: one 4-channel delay line over dry + pump, its time
    // driven per mode from the moment of the trigger (el = seconds since)
    //   1 stutter  time steps up a slice at a time: the first slice plays
    //              live, then repeats; a tiny window at each slice edge
    //   2 tape stop time grows by (1 - rate) as the rate falls to zero
    //   3 reverse  time grows at 2x: reads backwards from the trigger
    //   4 chop     live, gated on and off every half slice
    //   5 crush    live, sample-and-hold + bit reduction
    // wet fades in and out over a few ms, so it never clicks on or off
    SynthDef(\grad_glitch, {
      arg dryBus, pumpBus, t_go=0, mode=1, slice=0.1, dur=0, mix=1;
      var sig  = In.ar(dryBus, 2) ++ In.ar(pumpBus, 2);
      var el   = Sweep.ar(t_go, 1);
      var sl   = slice.clip(0.01, 1);
      var d    = dur.clip(0, 1.5);
      var gate = EnvGen.ar(Env([0, 1, 1, 0], [0.004, (d - 0.012).max(0.001), 0.008]), t_go);
      var rate = EnvGen.ar(Env([1, 1, 0.0], [0, d.max(0.01)], [0, -2]), t_go);
      var ph   = (el / sl).frac;
      var win  = Select.ar(mode < 1.5, [DC.ar(1), (ph * sl / 0.003).min(1) * ((1 - ph) * sl / 0.003).min(1)]);
      var time = Select.ar((mode - 1).clip(0, 2), [
        (el / sl).floor * sl, Sweep.ar(t_go, 1 - rate), el * 2
      ]).clip(0.0001, 2);
      var wet  = Select.ar(mode > 3.5, [DelayC.ar(sig, 2.05, time) * win, sig]);
      wet = Select.ar((mode - 3).clip(0, 2), [
        wet,
        wet * Lag.ar(LFPulse.ar(sl.reciprocal, 0, 0.5), 0.002),
        // companded: 8 steps on the square root, so quiet pads survive.
        // the max() matters: norns' ARM sqrt returns NaN for 0 and for
        // denormals (fine on a Mac), and one NaN froze the master's levels
        { |h| h.sign * ((h.abs.max(0.000001).sqrt * 8).round(1) / 8).squared }.value(Latch.ar(wet, Impulse.ar(3000)))
      ]);
      ReplaceOut.ar(dryBus,  (sig[0..1] * (1 - (gate * mix))) + (wet[0..1] * gate * mix));
      ReplaceOut.ar(pumpBus, (sig[2..3] * (1 - (gate * mix))) + (wet[2..3] * gate * mix));
    }).add;

    SynthDef(\grad_master, {
      arg dryIn, pumpIn, out, ampOut, t_pump=0, pumpDepth=0.6, pumpRel=0.25, level=0.8, drive=0.2,
          pumpLpf=20000, character=1;
      // Sanitize: a NaN or inf from any voice becomes 0 here, so it can't
      // stick in the limiter or the Amplitude followers (they never recover)
      var d   = Sanitize.ar(In.ar(dryIn, 2));
      var mono, toVis, ch, warm, dusty, blend;
      // pumpLpf: the fill's filter dip, on everything but kick and hats
      var p   = LPF.ar(Sanitize.ar(In.ar(pumpIn, 2)), Lag.kr(pumpLpf, 0.12).clip(80, 20000));
      var env = EnvGen.kr(Env.perc(0.005, pumpRel, 1, -3), t_pump);
      var sig = d + (p * (1 - (env * pumpDepth)));
      sig = HPF.ar(sig, 28);
      sig = (sig * (1 + (drive * 2))).tanh / (1 + (drive * 0.6));
      // character: 1 clean, 2 warm, 3 dusty, crossfaded over about half a
      // second. clean is the master exactly as it was: the Select passes
      // the untouched signal whenever the lagged mode sits at 1
      //   warm   a low shelf up, the top shelved down, a soft tape knee
      //   dusty  band-limited, a slow wow and a little flutter, a mid
      //          bump and a harder knee, like an old cassette dub
      ch    = Lag.kr(character.clip(1, 3), 0.6);
      warm  = BHiShelf.ar(BLowShelf.ar(sig, 120, 1, 2.5), 6000, 1, -3);
      warm  = (warm * 1.3).tanh / 1.15;
      dusty = DelayC.ar(HPF.ar(sig, 35), 0.02,
        0.004 + (LFNoise2.kr(0.5) * 0.0012) + (SinOsc.kr(6.3) * 0.00012));
      dusty = BPeakEQ.ar(LPF.ar(dusty, 5000), 1200, 1, 2);
      dusty = (dusty * 1.6).tanh / 1.25;
      blend = (sig * (2 - ch).max(0)) + (warm * (1 - (ch - 2).abs).max(0)) + (dusty * (ch - 2).max(0));
      sig = Select.ar(ch > 1.0005, [sig, blend]);
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

    washChord = [110, 130, 165, 196];
    padFading = List.new;
    padDef = \grad_wash;
    padLastSwap = -100;
    padTimer = false;
    echoFading = List.new;
    echoDef = \grad_echo;
    echoLastSwap = -100;
    echoTimer = false;
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
    // after the echoes and reverb (which write to pump), before the master
    glitchSynth = Synth.before(masterSynth, \grad_glitch, [
      \dryBus, dryBus.index, \pumpBus, pumpBus.index
    ]);

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
      \character -> [\master, \character],
      \wash_amp -> [\wash, \amp],     \wash_cutoff -> [\wash, \cutoff],
      \wash_echo -> [\wash, \echo],   \wash_verb -> [\wash, \verb],
      \noise_amp -> [\noise, \amp],   \noise_tone -> [\noise, \tone],
      \noise_crackle -> [\noise, \crackle],
      \bed_amp -> [\bed, \amp],       \bed_lpf -> [\bed, \lpf],
      \bed_rate -> [\bed, \rate],     \bed_verb -> [\bed, \verb]
    ];

    // ------------------------------------------------------------- commands

    this.addCommand(\kick, "ffff", { |msg|
      Synth([\grad_kick, \grad_kick_dusty, \grad_kick_boom, \grad_kick_knock,
        \grad_kick_deep, \grad_kick_tight].clipAt(st[\kick_type].asInteger - 1), [
        \out, dryBus.index, \amp, msg[1] * st[\kick_lvl],
        \tune, msg[2], \decay, msg[3], \click, msg[4]
      ], voiceGroup);
    });

    this.addCommand(\hat, "ffff", { |msg|
      Synth([\grad_hat, \grad_hat_metal, \grad_hat_dust, \grad_hat_tape].clipAt(st[\hat_type].asInteger - 1), [
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
      Synth([\grad_bass, \grad_bass_reese, \grad_bass_rubber,
        \grad_bass_fmsub, \grad_bass_tape].clipAt(st[\bass_type].asInteger - 1), [
        \out, pumpBus.index, \freq, msg[1], \amp, msg[2] * st[\bass_lvl], \dur, msg[3],
        \cutoff, st[\bass_cutoff], \drive, st[\bass_drive]
      ], voiceGroup);
    });

    this.addCommand(\bass_glide, "fffff", { |msg|
      Synth([\grad_bass, \grad_bass_reese, \grad_bass_rubber,
        \grad_bass_fmsub, \grad_bass_tape].clipAt(st[\bass_type].asInteger - 1), [
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

    this.addCommand(\clap, "ffff", { |msg|
      Synth([\grad_clap, \grad_snare, \grad_snap].clipAt(msg[2].asInteger - 1), [
        \out, dryBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \amp, msg[1] * st[\clap_lvl], \tone, msg[3], \pan, msg[4],
        \echo, st[\clap_echo], \verb, st[\clap_verb]
      ], voiceGroup);
    });

    this.addCommand(\perc, "fffff", { |msg|
      Synth([\grad_perc_hand, \grad_perc_wood, \grad_perc_metal].clipAt(msg[5].asInteger - 1), [
        \out, pumpBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \amp, msg[1] * st[\perc_lvl], \freq, msg[2], \decay, msg[3], \pan, msg[4],
        \echo, st[\perc_echo], \verb, st[\perc_verb]
      ], voiceGroup);
    });

    this.addCommand(\ride, "ffff", { |msg|
      Synth(\grad_ride, [
        \out, dryBus.index, \verbOut, verbBus.index,
        \amp, msg[1] * st[\hat_lvl], \decay, msg[2], \tone, msg[3], \pan, msg[4],
        \verb, st[\ride_verb]
      ], voiceGroup);
    });

    this.addCommand(\tick, "ffff", { |msg|
      Synth([\grad_tick_click, \grad_tick_blip, \grad_tick_crush, \grad_tick_zap].clipAt(msg[2].asInteger - 1), [
        \out, dryBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \amp, msg[1] * st[\tick_lvl], \freq, msg[3], \pan, msg[4],
        \echo, st[\tick_echo], \verb, st[\tick_verb]
      ], voiceGroup);
    });

    this.addCommand(\glitch, "ffff", { |msg|
      glitchSynth.set(\mode, msg[1], \slice, msg[2], \dur, msg[3], \mix, msg[4], \t_go, 1);
    });

    this.addCommand(\chord, "ffffff", { |msg|
      Synth([\grad_chord, \grad_chord_felt, \grad_chord_organ, \grad_chord_glass,
        \grad_chord_rhodes, \grad_chord_choir, \grad_chord_strings].clipAt(st[\chord_type].asInteger - 1), [
        \out, pumpBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
        \f1, msg[1], \f2, msg[2], \f3, msg[3], \f4, msg[4],
        \amp, msg[5] * st[\chord_lvl], \dur, msg[6],
        \cutoff, st[\chord_cutoff], \res, st[\chord_res],
        \envAmt, st[\chord_env], \detune, st[\chord_detune],
        \echo, st[\chord_echo], \verb, st[\chord_verb]
      ], voiceGroup);
    });

    this.addCommand(\arp, "fffffff", { |msg|
      var def = [\grad_arp, \grad_arp_bell, \grad_arp_pluck, \grad_arp_soft,
        \grad_arp_glass, \grad_arp_reed, \grad_arp_kalimba, \grad_arp_marimba,
        \grad_arp_steel, \grad_arp_bowed].clipAt(msg[7].asInteger - 1);
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
      washChord = msg[1..4];
      washSynth.set(\f1, msg[1], \f2, msg[2], \f3, msg[3], \f4, msg[4]);
    });

    // swap the pad (1 wash 2 choir 3 strings 4 drone); see swapPad below.
    // requests are coalesced: the swap lands 0.25 s after the last request,
    // and never sooner than 2 s after the previous swap, so scrolling
    // through the types makes one or two swaps, and the node a swap frees
    // early has already faded by 20 dB or more (no click)
    this.addCommand(\pad_type, "f", { |msg|
      var now = SystemClock.seconds;
      padPending = [\grad_wash, \grad_pad_choir, \grad_pad_strings, \grad_pad_drone,
        \grad_pad_glass, \grad_pad_tapeloop].clipAt(msg[1].asInteger - 1);
      padDue = (now + 0.25).max(padLastSwap + 2);
      if(padTimer.not, {
        padTimer = true;
        SystemClock.sched(padDue - now, {
          var wait = padDue - SystemClock.seconds;
          if(wait > 0.001, { wait }, {
            padTimer = false;
            if(padPending.notNil and: { padPending != padDef }, { this.swapPad(padPending) });
            padPending = nil;
            nil
          })
        });
      });
    });

    // swap the reverb in place, then re-send its remembered settings
    this.addCommand(\verb_type, "f", { |msg|
      var def = [\grad_verb, \grad_verb_plate, \grad_verb_spring].clipAt(msg[1].asInteger - 1);
      var vals = fxVals[\verb] ? IdentityDictionary.new;
      var args = [\in, verbBus.index, \out, pumpBus.index];
      vals.keysValuesDo { |k, v| args = args ++ [k, v] };
      fx[\verb] = Synth.replace(fx[\verb], def, args);
    });

    // swap the dub echo (1 dub 2 tape 3 ping-pong 4 space); see swapEcho
    // below. coalesced like pad_type: the swap lands 0.25 s after the last
    // request and never sooner than 2 s after the previous one. the lead
    // echo is never swapped
    this.addCommand(\echo_type, "f", { |msg|
      var now = SystemClock.seconds;
      echoPending = [\grad_echo, \grad_echo_tape, \grad_echo_pingpong,
        \grad_echo_space].clipAt(msg[1].asInteger - 1);
      echoDue = (now + 0.25).max(echoLastSwap + 2);
      if(echoTimer.not, {
        echoTimer = true;
        SystemClock.sched(echoDue - now, {
          var wait = echoDue - SystemClock.seconds;
          if(wait > 0.001, { wait }, {
            echoTimer = false;
            if(echoPending.notNil and: { echoPending != echoDef }, { this.swapEcho(echoPending) });
            echoPending = nil;
            nil
          })
        });
      });
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

  // the pad crossfade, the way verb_type swaps the reverb: the new pad
  // starts silent after the old one with the remembered settings and the
  // last chord, then lags up to the remembered amp (Lag.kr 6: mostly done in about 2 s, settled in about 6 s) while the old one
  // lags down and is freed after 7 s. a swap that lands while one is still
  // fading frees that one at once, so at most two pads ever coexist
  swapPad { arg def;
    var vals = fxVals[\wash] ? IdentityDictionary.new;
    var amp = vals[\amp] ? 0;
    var old = washSynth, nu;
    var args = [\out, pumpBus.index, \echoOut, echoBus.index, \verbOut, verbBus.index,
      \f1, washChord[0], \f2, washChord[1], \f3, washChord[2], \f4, washChord[3]];
    if(old.isNil, { ^this });
    vals.keysValuesDo { |k, v| if(k != \amp, { args = args ++ [k, v] }) };
    args = args ++ [\amp, 0];
    padFading.do { |n| n.free };
    padFading = List[old];
    nu = Synth.after(old, def, args);
    nu.set(\amp, amp);
    old.set(\amp, 0);
    washSynth = nu;
    fx[\wash] = nu;
    padDef = def;
    padLastSwap = SystemClock.seconds;
    SystemClock.sched(7, {
      if(padFading.includes(old), { old.free; padFading.remove(old) });
      nil
    });
  }

  // the echo crossfade: the new echo starts after the old one with the
  // remembered settings and its input faded in over about 0.1 s; the old
  // one stops taking input at once (its repeats carry on) and its output
  // lags down (Lag.kr 2.5: 60 dB in 2.5 s), and it is freed after 3 s. a
  // swap that lands while one is still fading frees that one at once, so
  // at most two dub echoes ever coexist
  swapEcho { arg def;
    var vals = fxVals[\echo] ? IdentityDictionary.new;
    var old = echoSynth, nu;
    var args = [\in, echoBus.index, \out, pumpBus.index, \verbOut, verbBus.index];
    if(old.isNil, { ^this });
    vals.keysValuesDo { |k, v| args = args ++ [k, v] };
    args = args ++ [\xin, 0];
    echoFading.do { |n| n.free };
    echoFading = List[old];
    nu = Synth.after(old, def, args);
    nu.set(\xin, 1);
    old.set(\xin, 0, \xout, 0);
    echoSynth = nu;
    fx[\echo] = nu;
    echoDef = def;
    echoLastSwap = SystemClock.seconds;
    SystemClock.sched(3, {
      if(echoFading.includes(old), { old.free; echoFading.remove(old) });
      nil
    });
  }

  free {
    // disarm any pending swap or crossfade free: the group takes the nodes
    padFading = List.new;
    padPending = nil;
    echoFading = List.new;
    echoPending = nil;
    echoSynth = nil;
    washSynth = nil;
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
