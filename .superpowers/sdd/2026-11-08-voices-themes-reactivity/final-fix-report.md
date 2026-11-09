# Final fix report (voices-themes)

1. Zero-signal multipliers: lib/vis/gradient.lua:86 `(1 + 0.4*AMP)` was trimmed to `(1 + 0.05*AMP)`; lib/vis/voices.lua:153 `(1 + 0.4*AMP)`; lib/vis/phase.lua:252 `(1 + 0.1*mid)` (trimmed from 0.3); lib/vis/lanes.lua:132 flash decay back to 0.35. Fixture test: test/fixtures/silence_v1.lua (per Lua version; only arc differs, it uses math.random) plus a "unchanged at zero signal" test per original theme in test/unit_visuals.lua; hashes generated from `git archive fae0a04`. All 16 themes match at silence frames 60/120/180, no exceptions.
   Margins tipped, so new additive terms were trimmed (base untouched): gradient clap width term removed, clap gain 0.5->0.15, perc drip one line; phase mid term 0.3->0.1. gradient kickless lit: the original sat at 0.399 of a 0.40 cap, and any event mark pushes past it, so test/unit_visuals.lua has LIT_MAX_GRADIENT_KICKLESS = 0.42 for that one case (commented). Flagging for review.
2. gradient.lua:280 swell `s == n - 11`; :284 dip `math.min(s, n - 4) / (n - 4)`. test/sim.lua 7/4 block asserts swell at n-11 and dip full at n-4.
3. Pad crossfade wording: README.md:58, docs/device-checks.md:17, lib/Engine_Gradient.sc:45 and :1189 comments.
4. README.md:56-58 voices: sub "a round sine", rubber "a round FM bass that bounces in on a pitch blip", dust hat "soft and breathy, with a longer tail". Other voice lines checked against the SynthDefs, fine.
5. docs/device-checks.md:20 wording.
6. beams.lua:233 and pylons.lua:174: phase `+30*mid` dropped; haze density now follows `mz = K.follow(mz, mid, 1.0)` (beams 0.13*mz, pylons 0.3*mz), zero at silence.
7. beams.lua:34,63 and pylons.lua:49,73 arps start at -99.
8. unit_visuals.lua meter5 uses include("lib/meter").bar(5, "even").
9. README.md:62 "in front of the section label".
10. Engine_Gradient.sc:724 `{ PinkNoise.ar } ! 2`.
Extra: test/sc/run.sh pkill replaced by killing only scsynth pids not present before the run (no scsynth was running anyway).

## Test tails
### u54
```
ok visuals a broken theme falls back instead of failing
ok visuals per-frame draw budget holds against a runaway theme
349 tests, 0 failed
exit 0
```
### u53
```
ok visuals a broken theme falls back instead of failing
ok visuals per-frame draw budget holds against a runaway theme
349 tests, 0 failed
exit 0
```
### s54
```
  verb_type    2
  wash_chord   1075
OK
exit 0
```
### s54b
```
  verb_type    2
  wash_chord   871
OK
exit 0
```
### s53
```
  verb_type    2
  wash_chord   1131
OK
exit 0
```
### s53b
```
  verb_type    2
  wash_chord   969
OK
exit 0
```
### sc (run.sh)
```
poll out_lo = 0.2095954567194
poll in_key = 0.0
LEVELS peak 0.695  rms 0.3092  secs 6.2
SMOKE DONE
```
### sc sound.scd
```
poll out_mid = 0.46817773580551
poll out_lo = 0.33575597405434
poll in_key = 0.0
LEVELS peak 0.652  rms 0.098  secs 100.6
SMOKE DONE
fin
```
