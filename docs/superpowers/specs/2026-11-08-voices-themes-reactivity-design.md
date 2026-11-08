# gradient: more voices, eight themes, full audioreactivity

## Intent

The user wants **more options**: more choices of sound for each part, and more
visual themes. Every theme should react to every part of the music. Today
some themes ignore whole parts: no existing theme has its own handler for
clap, perc or tick, so those only reach a theme through the hat fallback.
Several themes also ignore the chord stabs, the arps or the mid band.

What the user approved in chat (2026-11-08) is below, in sections 1–3.

## Goals

1. **Voice options** for bass, chord stabs, hats, pads and arp lanes. Each has
   an `auto` choice plus fixed choices. **Every new param defaults to
   `auto`, and `auto` picks from all the voices, old and new** (the user's
   answer, 2026-11-08). So out of the box gradient sounds more varied than
   it does today, which is intended. The first fixed choice is always
   today's sound, so you can pin it.
2. **Eight new themes:** radar, subway, harbour, sodium, lighthouse, tramlines, substation, cooling.
3. **Full audioreactivity.** Every theme, old and new, visibly reacts to
   every part and to every audio band. A test enforces this.

## Non-goals

- No changes to the conductor's arc, the harmony, or the drum patterns.
- The omigod web page's JS theme ports are left as they are.
- No new grid or encoder controls. The new options are params.

## Anti-goals: the work fails if any of these happen

- Anything strobes, or the screen gets bright and busy. The existing
  limits stay as they are: lit area ≤ 40%, frame-to-frame change
  ≤ `DIFF_MAX` 0.7, level 15 ≤ 12% of pixels, ≤ 1200 draw calls per frame.
- A new voice is much louder or quieter than the one it replaces. Each
  type should sit at about the same level as the default.
- CPU climbs. The norns idles at about 16–18% today. A peak with the
  heaviest choices on every part should stay under about 45%.
- NaN or inf from any new voice. The norns' ARM `sqrt` returns NaN at 0,
  and `test/unit_engine.lua` lints for that. Keep `pow`, `log` and division
  away from zero too.

## Constraints

- norns: Lua 5.3, SuperCollider 3.13-dev on ARM, about 8 MB of real-time
  memory, and a 128×64 screen with 16 grey levels at about 20 fps.
- sclang has no operator precedence, so parenthesise every compound
  expression.
- `t_` arguments are triggers. Never use the same name for a `t_foo`
  argument and a `foo` argument.
- Load lib files with `include()`.
- Never put device names, IPs or SSH key paths in the repo.
- READMEs say what things do and how to use them, with no "what it won't
  do" sections.

## 1. Voices

The names come from the user-approved list. The synthesis details are the
builder's call, and these descriptions are only a guide.

| part | param (SOUND) | choices (1st fixed = today) |
|---|---|---|
| bass | `bass_type` | auto, **sub**, reese (2–3 detuned saws, low-passed, a slow beat), rubber (a round, bouncing FM bass with a pitch blip) |
| chord stabs | `chord_type` | auto, **dub** (today's), felt (soft, muted, dark), organ (drawbar sines, a little key click), glass (FM bell, a long shimmer) |
| hats | `hat_type` | auto, **noise** (today's), metal (808-style: six square waves through a band-pass), dust (soft filtered noise, longer and quieter) |
| pads | `pad_type` | auto, **wash** (today's), choir (vowel formants on the chord, slowly morphing), strings (slow bowed saws through an ensemble) |
| arp lanes | `laneN_voice` (existing) | auto, classic, bell, pluck, soft, **+ glass, + reed, + kalimba** (tine pluck, woody), **+ marimba** (bar resonator, soft mallet) |

The user then asked for four more distinctive voices on top of this list.
These are the last four rows of new choices:

- **arp lanes:** kalimba and marimba (in the table above)
- **chord stabs:** + **rhodes** (an electric piano tine with a touch of bell
  and tremolo)
- **pads:** + **drone** (a single deep tone on the chord root and fifth,
  slowly beating, with a hint of tape)

So `chord_type` is auto, dub, felt, organ, glass, rhodes, and `pad_type` is
auto, wash, choir, strings, drone.

- **Plumbing.** Follow the existing patterns. The spawn-time voices (bass,
  chord, hat, arp) pick their SynthDef from an `st` key set through `tweak`,
  the way `kick_type` does. The pad is a persistent synth, so changing
  `pad_type` must **crossfade**: start the new pad synth fading in, release
  the old one over about 2 s, no click. Run only one pad type at a time;
  don't Select across all three.
- **auto.** The lane `auto` pool grows to include glass, reed, kalimba and
  marimba. The conductor picks a type when material regenerates (a new
  track in set mode, or at mutation), the way `clap_kind` / `perc_kit` auto
  do. *My call:* draw the picks from their own dice, not the material seed,
  so the drum patterns for a given seed don't shift. The pick leans on energy and darkness: rubber and reese near the top,
  felt and dust in breakdowns. A pick holds for at least a phrase, so the
  sound never flickers.
- Every new SynthDef gets a line in `test/sc/sound.scd` (or `run.scd`).
  `test/sim.lua` checks that each new param exists and accepts every value.

## 2. Eight new themes

Each one is a file in `lib/vis/<name>.lua` on the shared kit, added to
`VIS.names` after `dubplate`, in this order: radar, subway, harbour, sodium,
lighthouse, tramlines, substation, cooling. That makes 24 themes. The last
four came from the user's follow-up ("four more unique visual themes").
None of them repeats a Causeway theme (pulse, drift, field, hex, stars,
wave, rain, spiral, liss, tunnel, bounce, grid, flow, morph, shatter, code,
orbit, terrain, lattice, kaleido) or an existing gradient theme.
They share the existing style: a night scene, greys on black, the dim levels
for atmosphere and the bright ones kept for the music.

- **radar:** a sweep arm turning about once per bar. Hits leave blips that
  fade on the scope, each part at its own ring or bearing, so the scope
  fills with what is playing. The bass sits on the inner rings and the hats
  and ticks on the outer ones.
- **subway:** lit carriage windows sliding past. The train's speed follows
  the pulse and the energy, and slows in kickless stretches. Each window
  holds a part (stabs, arps, perc) or flickers to it.
- **harbour:** cranes and moored hulls on dark water. The reflections ripple
  with the bass and the low band. Crane lights blink with the hats, and the
  water carries the pad.
- **sodium:** street lamps receding down a road to a vanishing point. They
  flicker with the hats and buzz with the ticks. The road surface breathes
  with the pump, and the stabs flare the near lamps.

- **lighthouse:** a headland seen from the sea. The beam turns slowly and
  fans through the haze. Its speed follows the energy, and the kick pulses
  its brightness. The waves catch the bass. Stabs light the keeper's window
  bands, and arps are buoys blinking out on the water. This differs from
  radar: it's a side-on landscape, not a top-down scope.
- **tramlines:** looking up through a web of overhead catenary wires. The
  wires sway with the pump, and the hats and ticks spark blue-white at the
  joints. A pantograph slides along with the arps. The bass hums as a
  standing wave in the long spans.
- **substation:** a fenced yard of transformers and insulators at night.
  The low band hums as heat shimmer over the transformers. Clap and perc
  arc between the insulators, briefly and dimly, never strobing. Stabs
  light the control-room windows. The pad is the sodium glow over the
  fence.
- **cooling:** two cooling towers on the horizon. Steam plumes rise and
  billow with the pad and the energy. The kick pushes a ring up the plume.
  The hats are aircraft warning lights on the rims. The bass lights the
  base of the towers.

The exact compositions are the builder's call, within the style and the
anti-goals.

## 3. Full audioreactivity

**The contract.** Every theme visibly responds to each of these inputs:

- events: `kick`, `pump`, `hat`, `clap`, `perc`, `tick`, `stab`, `bass`,
  `arp`, `pad` (new)
- bands: `AMP`, `LO`, `MID`, `HI`
- `glitch`, which already reaches every theme through the shared tear

`pad` is a new event. The script fires `VIS.event("pad", notes)` whenever
it sends `wash_chord`. Add `env.pad` with a slow `ENV_TAU` (about 0.6 s).

**The test.** Add it to `test/unit_visuals.lua`. For every theme and every
event, run two copies of the scene with the same seed and the same time,
fire the event in only one of them, then compare the frames over the next
few frames. The mean absolute difference must exceed a small threshold:
the event has to be seen. Do the same for each band, holding it at 0 in
one copy and 0.8 in the other.

*My call: the strict reading.* In the event checks, the hat fallback is
off and the bands are held fixed (they count as live polls), so the
envelopes can't reach a theme through made-up bands. A reaction only counts
when the theme answers that part itself. The band checks drive the bands
directly.

The test must fail today for the gaps listed in Intent. That proves it
measures something. The existing limits must hold through every new
reaction.

**How the work is split.** Each theme reacts in its own way, through a
handler or by reading `K.env.<part>`. A kit-wide generic flash doesn't
count. Keep the existing fallback (clap, perc and tick reach themes as
hats) for themes loaded from elsewhere, but every shipped theme has its own
reaction to each part.

## Verification

- `lua test/unit.lua test/unit_engine.lua test/unit_visuals.lua` and
  `lua test/sim.lua` pass on both Lua 5.4 and Lua 5.3.
- `test/sc/run.sh` and `test/sc/run.sh test/sc/sound.scd` play every new
  voice with no errors. Add a level check: each new type's peak is within
  about ±4 dB of the default type for the same part.
- `lua test/contact.lua out.pgm` gives a contact sheet of all 24 themes. A
  person looks at it before shipping.
- **On a norns,** via the websocket REPL at :5555/:5556: compile, load, play,
  step through every voice type and every theme, read CPU at peak, and
  check the engine's level bus stays live.
- Then ship it: commit, push to GitHub, and deploy to every norns that's on
  the network. Linger is on everywhere, so a reboot is the clean engine
  reload.

## Left to the builder

- The synthesis inside each new voice.
- The compositions of the new themes.
- The exact mapping of each part in each existing theme.
- How `auto` weighs its picks.
- The exact thresholds for the reactivity test.

## README

- Add the new SOUND params and the eight themes.
- Update "sixteen" to "twenty-four" everywhere, including the `lib/visuals.lua`
  header.
- Note the `pad` event in the theme contract.
