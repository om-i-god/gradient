# gradient visuals v2: design

The brief: "improve the visual themes for gradient and add more unique ones in the same vein as we've done for estuary". Estuary's v3 turned abstract diagrams into small *places*, split each theme into its own file over a shared kit, gave the visuals ears (engine output polls) and a headless test matrix. gradient gets the same treatment, in its own world: dub and kickless techno at night. Concrete, sodium light, haze, tape, sound systems, the city seen from a bridge at 3am. Never causeway's themes, never estuary's water scenes.

## Character
- Night and architecture, greys on black. It may be dark and moody (unlike estuary), but a theme at mid activity should read as a scene, not a near-empty screen: the dim levels (1–4) carry the atmosphere (haze, distant structure, texture), the bright levels are kept for what the music is doing.
- The pulse is visible in every theme: the kick, and in kickless stretches the ghost pump. Kickless stretches loosen the picture (haze, drift, water) rather than going dead.
- Dub is visible: throws leave trails, echoes repeat at the echo time and fade by the feedback.
- Nothing strobes. No theme lights more than ~40% of pixels; level 15 is for points, never areas; the frame-to-frame change is bounded so a 2 Hz pump never flashes the whole screen.
- Motion runs on time, not frames; speed and brightness params scale everything; a theme switch eases through black.

## The kit (lib/visuals.lua)
Public API unchanged for the script: `VIS.names`, `VIS.init`, `VIS.event(kind, ...)`, `VIS.draw(theme, S [, dt])`, `VIS.audio_level`; new `VIS.audio(name, v)` for the engine's output polls.

Shared state every theme reads through `K` (refreshed every frame):
- **ears**: `A[AMP|LO|MID|HI]` eased from the new engine polls `out_amp/out_lo/out_mid/out_hi`. Until a poll arrives (an engine not yet restarted) they fall back to the old `amp_out_l` level and the event envelopes.
- **beat**: `beat_ph`, `bar_ph` (0..1, smooth between 16ths), `beat_sec`, `bar_pulse`.
- **pump**: `duck` (the ghost sidechain shape: snaps on each pump, recovers over the beat), `kick` envelope, `kickless` (eased 0..1).
- **arc**: `energy` (eased), `trend`, `dub`, `throw` (eased 0..1 while a throw is on), `echo_t`, `echo_fb`.
- **music**: the chord, per-voice stab envelopes, bass note + envelope, per-lane arp note / step / envelope, a bar history (energy, kickless, chord change, pedal).
- **helpers**: batched `put` rects and batched `line`s per level; `py`/`px` note→row/column; `profile`, `mass`, `row_above`, `gradient` (ordered-dither rows), `dashes`, `haze` (drifting dithered fog from row runs); `rnd`, `hash`, `ease`, `follow`.

Each theme is `lib/vis/<name>.lua`, loaded with `include` and returning `function(K) return {draw, stab, bass, arp, kick, pump, bar, init, clear} end`; all but `draw` optional. No globals.

## Themes: the eight, better (same names, same order, same ideas)
- **gradient** — the chord as bands of light, now behind a haze with a floor and depth; the pump breathes the bands, the bass a low ground-glow, out_hi a fine grain.
- **voices** — the scrolling voice ribbons get a dim staff/grid, an echo shadow behind each stab and a bass ribbon of its own.
- **lanes** — the four step rings become a machine: rings with tick marks, playhead trails, the join line, a centre that pumps.
- **phase** — the moiré keeps its two gratings but is drawn with dither bands so it reads at a glance; the pump squeezes the spacing.
- **echo** — stab copies drift on a tape-wobble path, fading by the real echo feedback at the real echo time; throws smear.
- **fall** — notes fall through haze onto a floor that splashes; stabs heavier; the bass glows on the floor.
- **pump** — the horizon lines with a skyline/ground and haze; kickless turns them to water.
- **arc** — the 60-bar history as a landscape with dithered fill, chord-change marks and a live edge.

## Eight new themes
- **motorway** — a night motorway seen from a bridge: lamp posts recede, the four arp lanes are four traffic lanes (each note a pair of tail/head lights at its lane), the bass is a lorry, the pump the sodium flicker of the posts, stabs light a gantry sign.
- **tape** — a reel-to-reel dub delay: reels turning, the tape path past record and playback heads; each stab is written at the record head and travels to the playback heads at the echo time, coming back fainter by the feedback; throws spin the reels and smear the tape.
- **stack** — a sound-system stack: bass bins, mids and horns; cones excurse with out_lo / the kick, horns shimmer with out_hi, stabs light the mids, haze from the dancefloor below.
- **blocks** — tower blocks at night: windows light at the floor of each arp note's pitch, the chord sets which floors glow, the pump dims the stairwell lights, a train line at the bottom crosses on the bar.
- **beams** — club lights through haze: a few slow beams from the rig sweep with the lanes, stabs swell them, the kick lands as a low floor glow, haze thickens with dub. Slow, never strobing.
- **window** — the city through a rain-streaked window: bokeh discs at the chord voices' pitches, drops slide down and join with the pump, arp notes as distant lights switching on.
- **pylons** — power lines across a field at night: the wires hum and sag with the bass, arp notes run as sparks along their lane's wire, stabs ring the insulators, fog at the ground.
- **dubplate** — a record turning under a light: grooves as rings, the playhead (tonearm) at the bar phase, stabs catch a glint along the groove, the lanes as dust/crackle points that come round each revolution.

`VIS.names` order: the eight existing themes first (saved psets keep their theme), then the eight new ones.

## Tests
`test/unit_visuals.lua` (new, standalone): every theme × {silence, mid, peak, kickless} headless at 20 fps of virtual time — no NaN, draw-call budget, lit ratio within bounds (≥1% at silence, ≥4% with music, ≤40%), level-15 ≤ 12 px, bounded frame change; moves at silence; reacts to out_lo and out_hi; switch eases; bad input; brightness and speed scale; variable dt. `SNAP=dir` writes still/mid/peak frames per theme, plus a contact sheet. `lua test/sim.lua` and `luac -p` on every file keep passing.

## Deferred to the device
CPU at 20 fps on a norns, visibility at low brightness, and how the pulse feels at tempo. The engine gains polls, so it needs SYSTEM > RESTART.
