# gradient round 3: more sound, more visual options, better themes

## Intent

The user asked for "even more sound and visual options", and to "improve all
the visual options". Asked what to improve first (sharper detail, smoother
motion, stronger reactions, or something else), they said **"all that"**. The
description below was approved in chat on 2026-11-08 ("go"). This round runs
after the voices/themes/meter work has shipped.

## Standing rules

- **Add, never replace** (the user's words, 2026-11-08): "I don't want to
  replace anything though, just add more variation."
  - Existing params, option orders and indices don't change, and new options
    are appended.
  - Existing voices keep their sound.
- **Improve the themes.** The user asked for the visuals to be improved, so
  this pass may refine *how* each theme renders. It must not remove or replace
  *what* a theme shows.
  - Keep: composition, elements, and which part answers where.
  - May change: the rendering quality (grey levels, dithering, outlines,
    sub-pixel motion) and reaction strength.
  - *My call:* the improved rendering is the new default. The new `detail`
    param includes a "classic" setting that draws each theme as before the
    pass, so today's look stays one choice away.
- Visual bounds stay: lit ≤ 0.40; frame-to-frame change ≤ 0.7; ≤ 12 pixels
  at level 15; ≤ 1200 draw calls per frame; no NaN. Nothing strobes.
- Every test passes on Lua 5.3 (the device) and on 5.4.
- CPU on the norns at peak with the heaviest choices stays under about 45%.
  The real-time memory budget is about 8 MB.

## 1. Sound

New choices are appended to the existing params:

| param | new choices |
|---|---|
| `bass_type` | fm sub (a pure FM sub with a slow index sweep), tape (a saturated sine/saw with wow) |
| `chord_type` | choir stab (formant), string stab (a short bowed ensemble) |
| `hat_type` | tape (a soft, saturated noise hat, slightly late-swung by its envelope) |
| `pad_type` | glass (an FM bell pad with a long shimmer), tape loop (a slowly wobbling, filtered loop-like pad) |
| `laneN_voice` | steel (a steel-drum FM ping), bowed (a soft bowed-string pluck) |
| `kick_type` | two more: `deep` (a long round sub thump) and `tight` (a short, high, punchy kick) |

New params, in SOUND:

- `echo_type`: dub (today's echo, the default), tape (more wow/flutter and
  saturation in the feedback), ping-pong (alternating L/R), and space (wide,
  diffused, with a longer tail). It swaps the echo the way `verb_type` swaps
  the reverb, keeping the remembered settings. No clicks.
- `character`: clean (today's master, the default), warm (gentle tape
  saturation plus a soft high shelf), and dusty (a band-limited lo-fi master
  with light crackle). It is a mode of the master synth, selected
  click-free. Default = today.

`auto` (`lib/timbre.lua`) may pick the new voices, the same way it picks
the others. `echo_type` and `character` stay where the user sets them; auto
never changes them.

## 2. Visual options

- **Four more themes**, appended after `cooling`. Names and scenes are the
  builder's choice, within the house style:
  - night, greys on black;
  - a real place a viewer reads at a glance;
  - not a Causeway theme (pulse, drift, field, hex, stars, wave, rain, spiral,
    liss, tunnel, bounce, grid, flow, morph, shatter, code, orbit, terrain,
    lattice, kaleido);
  - not one of the existing 24.

  Each answers every part and band, like the rest.
- **New params**, in the visuals group:
  - `trails` (0–100, default = today's behaviour): how long marks and
    afterimages linger, through a kit-level scale on fade times that every
    theme reads.
  - `detail`: classic, fine (the default), dense. "classic" is the
    pre-pass look, "fine" is the improved rendering, and "dense" adds extra
    texture within the lit bound. Themes read `K.detail`.
  - `reactivity` (0–100, default 50 = the pass's standard strength): scales
    how hard each scene answers the parts and bands, through `K.react`.

## 3. The improvement pass, on all 28 themes

For each theme:

- **Sharper detail.** Use more of the 16 levels for depth. Use finer
  dithering instead of flat fills. Draw cleaner silhouettes and outlines.
  The darkest atmosphere stays dim.
- **Smoother motion.** Anything that moves slowly (under about 1 px per
  frame) moves sub-pixel: draw it at two adjacent positions with the
  brightness split by the fraction, using a kit helper (`K.put_sub` /
  `K.line_sub`), so it glides instead of stepping.
- **Stronger reactions.** Each part's single hit reads clearly. The
  reactivity test's threshold rises from 0.003 to 0.0045 at `reactivity` =
  50. The band threshold rises from 0.01 to 0.015.
- **`detail` = classic** must reproduce the pre-pass frames (test: a frame
  hash matches a stored fixture per theme × scenario, taken before the pass).

## Calls I made after the builder check

1. **The classic baseline** is the branch head as shipped to the norns at
   the end of the previous round (after the Lua 5.3 fix). The frame hashes
   are fixtured from that commit, before any round-3 edit. The four new
   themes have no pre-pass look, so for them classic draws the same as fine,
   and they have no fixture.
2. **classic honours `trails` and `reactivity`.** Their defaults (50 and 50)
   are the exact identity, so classic at defaults reproduces the old frames.
   The raised reaction thresholds (0.0045 and 0.015) apply at `fine`. The
   classic fixtures cover classic.
3. **Bounds.**
   - The full bounds matrix runs at the defaults.
   - The extremes run on the `peak` and `mid` scenarios only, one param at a
     time: `trails` 0 and 100, `reactivity` 0 and 100, and `detail` dense.
   - If a theme can't hold the bounds at an extreme, the kit clamps that
     param's effect (e.g. the trails scale is capped where lit would pass
     0.40). The theme doesn't break the bound.
4. **`echo_type`** swaps the dub echo (`\echo`) only. The arp lead delay
   (`leadSynth`) keeps today's echo.
   - "ping-pong" is a new SynthDef with hard L/R alternation and
     cross-feedback, and it ignores `echo_pp`.
   - "dub" is today's `grad_echo` exactly.
5. **auto keeps existing seeds' first picks.**
   - The roll draws exactly as today, then makes one appended draw: with
     probability 0.3 it swaps the picked part for one of its new voices.
   - That changes how a seed sounds, which is the intent ("more
     variation"), but never which old draws happen. The drum and no-
     `math.random` rules hold.
   - Phrase re-picks choose from every voice.
6. **`trails`:** 50 is 1×, 0 is about 0.4× (shorter), and 100 is about 2.5×
   (longer), on a smooth curve.

## Verification

- All the existing tests pass, plus:
  - the raised reactivity thresholds;
  - the classic-frame fixtures;
  - tests that `trails`, `detail` and `reactivity` change the picture in
    the expected direction;
  - level checks for the new voices (±4 dB);
  - the echo and character swaps don't click and keep one node each.
  - All of this runs on Lua 5.3 and 5.4.
- Contact sheets of all 28 themes, before and after, read by a person or
  agent.
- On a norns: CPU at peak with the heaviest choices; every new voice,
  `echo_type` and `character`; and every theme at each `detail` setting.
- Ship: GitHub, plus every norns that's on the network.

## Left to the builder

- Synthesis details.
- The four new themes' places.
- Each theme's improvement specifics.
- The exact mapping of trails, detail and reactivity inside each theme.
