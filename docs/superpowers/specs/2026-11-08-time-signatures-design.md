# gradient: time signatures (3/4, 5/4, 7/4) and a feel choice

## Intent

The user asked for a time-signature feature with 5/4 as an option. Asked
whether the kick in 5/4 should be a steady pulse or a lopsided grouping, they
said **"let the user choose."** The description below was approved in chat on
2026-11-08 ("go ahead").

## Add, never replace

The user's standing rule for gradient (2026-11-08): "I don't want to replace
anything though, just add more variation."

- **4/4 stays the default**, and in 4/4 gradient sounds and draws exactly as
  it does today, with the same patterns for the same seed.
- Existing param IDs, option orders and indices don't change, so saved
  PSETs load the same as before.

## What gets built

**Params** (in the GRADIENT group, next to `phrase_len`):

| id | name | options | default |
|---|---|---|---|
| `meter` | time signature | 4/4, 3/4, 5/4, 7/4 | 4/4 |
| `feel` | feel | even, A, B | even |

`feel` labels depend on the meter. A and B are the two groupings:

| meter | A | B |
|---|---|---|
| 3/4 | 2+1 | 1+2 |
| 4/4 | 2+2 (half-time: kick on 1 and 3) | 3+1 |
| 5/4 | 3+2 | 2+3 |
| 7/4 | 4+3 | 3+4 |

The param's options are fixed strings (`"even", "short-long", "long-short"`)
so a PSET keeps working, and the HUD and the param's displayed value show the
actual grouping, e.g. `3+2`. *My call:* norns option params can't relabel per
meter, so the string is formatted by the param's `formatter` instead.

**Meaning.** A bar is `beats × 4` sixteenths (12, 16, 20 or 28). The beat stays a
beat: tempo, clock, MIDI clock and crow clock are unchanged. The groups say where
the bar leans:
- **even:** the kick and the pump fall on every beat (today's four-on-the-floor,
  stretched or shortened).
- **A/B:** the kick and the pump fall on the first beat of each group; the
  other beats get ghost kicks (the existing ghost mechanism), never silence.

**What follows the meter.** Every place that assumes 16 steps or 4 beats per bar
follows the current bar length instead:
- the step counter: `gradient.lua` `play_step` takes `s = (S.step % 16) + 1`
  today. It becomes a bar step that wraps at the bar length.
- the pattern generators in `lib/gen.lua`: kick, ghosts, hats, shaker, rim,
  toms, clap, ride, ticks and the perc lane are built for the bar length.
  - In 4/4 they must produce exactly today's patterns for the same seed.
  - In other meters, offbeat hats stay on each beat's "and".
  - The clap takes the backbeat of each group: in even feel the clap falls on
    beats 2 and 4 of 4/4, and in odd meters on the last beat of each group of
    two or more beats.
  - Fills end on the bar's last steps.
- bar-length logic in `gradient.lua`:
  - fill and glitch positions (`s == 13`, `s == 16`, …) become relative to the
    bar's end;
  - `bar_f`;
  - the bass, chord and stab placements.
- the conductor counts real bars, so `phrase_len` stays in bars.
- the visuals: `beat_ph` and `bar_ph` (lib/visuals.lua `physics`) use the bar
  length, and the bar sweep, pulse and hist follow it. Themes that draw "4 beats"
  (tick marks, segments) draw the meter's beats.
- the HUD shows the meter when it isn't 4/4 (e.g. `5/4`, or `5/4 3+2`).
- the grid, outs (crow and MIDI) and the arp lanes: lane lengths are
  independent of the bar and keep drifting against it. Anything sent once per
  bar goes per real bar.

**Change timing.** A new `meter` or `feel` takes effect at the next phrase
boundary while playing (immediately when stopped), so a change never cuts a bar.
The patterns regenerate for the new length at that moment, with the material
seed kept, so it's the same track in a new meter.

## Calls I made after the builder check

1. **4/4 A is "2+2".** It's a half-time feel: kick and pump on beats 1
   and 3. That's a new option and is not the same as even.
2. **Beat ghosts.**
   - In A/B feel, every beat that doesn't start a group gets a soft kick
     ghost (velocity about 0.35 of the bar's kick, at half decay, like
     today's ghosts).
   - These beat ghosts are always on while the kick is on: they follow
     `on_kick`, kickless sections and mute, and they ignore `on_ghost`.
   - The existing random `GHOSTS` positions keep working as today, mapped
     into the bar like any other pattern.
3. **Regeneration.**
   - A meter or feel change regenerates only the bar-length patterns:
     kick, ghosts, clap, hats, shaker, rim, toms, ride, ticks, bass and
     stabs.
   - It draws from a sub-stream seeded from the track seed and the meter
     (e.g. `seed * 31 + beats * 7 + feel`). Lanes, perc length, harmony
     and the rest of the material stay as they are.
   - A track that starts in 4/4 draws exactly as today. Coming back to 4/4
     after a change gives a fresh 4/4 set from the sub-stream, which is
     fine.
4. **Mapping a 16-step template to N beats.** This applies to the bass, the
   stabs and any fixed template.
   - Map beat by beat. The bar's first beat uses the template's beat 1, and
     the bar's last beat uses the template's beat 4, so turnarounds and fills
     still land at the end.
   - The middle beats cycle through the template's beats 2 and 3.
   - Euclid patterns are built directly at the bar length.
   - Chord changes stay on bar 1, step 1. Stabs map like the bass.
5. **Bar counters stay in bars.** That covers `BLOCK`, harm bars,
   `cycle_bars`, the 4th-bar turnaround, throws and fill landings.
   `phrase_len` stays in bars.
6. **The grid** has no step view, so nothing changes there beyond what reads
   `S.step`.
7. **No extra random draws in 4/4 even.** The generators make no extra
   `math.random` calls there, so the patterns for each seed stay identical.
   A/B feels may draw differently.

## Anti-goals

- 4/4 changes in any way: sound, patterns per seed, visuals, timing.
- A meter change lands mid-bar, or drops or doubles a bar.
- Odd meters sound like 4/4 with a hole or an extra stub. Every pattern
  must be built for the real bar length.
- The clock or tempo is reinterpreted; the beat stays a beat.

## Verification

- `test/sim.lua` covers:
  - each meter × feel runs 64 bars with no error;
  - bar length in steps = beats × 4;
  - the kick lands where the feel says, every bar;
  - a meter change made mid-phrase takes effect on the phrase boundary;
  - in 4/4, the patterns for seed 4218 are identical to before (snapshot the
    current patterns into the test first).
- `test/unit_visuals.lua`: every theme runs a 5/4 scenario within the existing
  bounds, and the bar phase reaches 1 at the bar's end.
- On a norns: play 5/4 in each feel and 7/4 even, and check that the visuals
  pulse on the beat.

## Left to the builder

- How the generators are parameterised (bar length, groups).
- How 3/4 claps and ticks are placed.
- How each theme maps its beat marks.
