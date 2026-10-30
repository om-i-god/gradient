# gradient

generative dub / kickless techno for norns. press play and let it ride.

gradient makes whole tracks by itself: phasing arpeggios, dub chord stabs into a tape echo, a sub bass, a kick you can drop out while its sidechain pump keeps breathing, hats, rims, a pad wash and a hiss/crackle bed. a conductor above the notes decides, bar by bar, what plays, how hard, and when things change. you can steer it, but you don't have to.

the bass, chords and arps can also go out over USB MIDI, per part: **internal**, **midi**, or **both**.

---

## how it rides

**energy.** everything hangs off one slow value, 0 to 1. parts enter as it rises (arp lane 1 first, then the chords, a second lane, rim, hats, bass, kick, more lanes) and leave as it falls. each part fades over about four bars, and the entry thresholds jitter every phrase so the order isn't identical each time.

**phrase length.** a phrase (8, 16, **32** or 64 bars; default 32) is how long the arrangement holds before material mutates and the dice are re-rolled. track sections snap to whole phrases, and the set-mode swell lasts 8–16 phrases. the conductor still checks every 4 bars so parts follow the energy arc, and the dub throws, drop and input-key moves stay on an 8-bar grid.

**two modes.**
- **set (endless):** energy swells and drains over 8–16 phrases (about 4–16 min, depending on phrase length) with a random walk on top. the troughs are kickless "drift" stretches. at some troughs the key moves by a 4th or 5th.
- **track:** a fixed arc over the track length (default 8 min): intro → build → peak → breakdown (kickless) → return → outro. at the end it either stops or rolls straight into a new track with a new seed and a neighbouring key.

**kickless.** the pump (ghost sidechain on every quarter) keeps running when the kick drops out, so pads, arps, echo and reverb tails still breathe on the beat. that happens in breakdowns, when you press drop, and sometimes on its own at mid energy (kick: auto). set **kick → never** for a fully kickless set. **bass** works the same way: auto sits it out in some kickless stretches, always keeps it in whenever the energy is high enough, never turns it off everywhere (engine, midi and crow), for when you bring your own low end. **hats** too: auto sometimes clears them for a drop, always keeps them in once the energy is there, never mutes them for good.

**lead voices.** each arp lane plays one of four voices: **classic** (triangle/pulse), **bell** (two-operator FM), **pluck** (karplus string) or **soft** (sine). on **auto** (the default) the seed picks, mostly classic. set a lane's voice in SOUND to fix it.

**phasing arps.** four lanes, each with its own odd length (3, 5, 7, 9, 11, 13 steps...), its own rate (16th, 8th, dotted 8th), register, pan, decay and slow filter LFO. lanes keep stepping even while silent, so when one fades back in it lands in a new phase against the others. lanes are written as chord-tone indices, so when the harmony moves, the arps move with it.

**mutation.** on every phrase, each lane might rotate, swap a note, or grow or shrink by a step, which shifts its phase. stab, hat, bass and rim patterns regenerate occasionally. very rarely a lane is replaced or a new progression arrives (it lands on the next 8-bar edge).

**harmony.** one key and one mode, three ways to move through it (PARAMS > KEY > harmony):

- **simple:** the old two-chord world: i–VI, i–iv, i–VII and so on, or just i, swapping every 2–8 bars with one voicing.
- **rich:** 2–5 chord loops (i–VI–III–VII, i–iv–VI–v, dorian's i–IV, phrygian's i–bII...) with uneven bar lengths such as 3+3+2 or 4+2+4+6. the loop restarts every phrase. each new chord is **voice-led**: every voice moves to the nearest note of the next chord, so the stabs and the arps glide instead of jumping. calm stretches hold chords twice as long; peaks change twice as fast.
- **drifting** (default): rich, plus chords **morph** in one voice at a time across their first bars, so the in-between chords sound too. key changes from the input follower drift in the same way.

in rich and drifting:

- **pedal bass:** in the intro, build and breakdown (and set mode's drift and rise), the bass often holds the tonic while the chords move above. the release when it finally follows is the lift into the peak.
- **inversions:** outside a pedal, the bass sometimes sits on the chord's 3rd or 5th.
- **colour by energy:** with chord voicing on **auto**, low energy picks open shapes (quartal, sus2, rootless m9, 6/9), the middle picks m7, add9 and sus4, and the peaks pick dense ones (m11, clusters).
- **outside chords:** about one loop in three ends on a borrowed chord for a bar: bII, bVI, bVII, a major IV or V, or the last chord's shape slid down a semitone or up a tone. then it's home again.

the screen shows the chord as a roman numeral under the key; `bVII/i` means bVII over a tonic pedal. voicing names assume minor; in a major mode the same shape gives maj7, maj9 and so on.

**modes.** twelve, all seven-note:

| | |
|---|---|
| dark dub minors | aeolian, dorian, phrygian, locrian |
| bright | mixolydian, ionian, lydian |
| minor colours | harmonic minor, melodic minor, phrygian dominant, dorian #4, hungarian minor |

new tracks (and next-track key moves) mostly land on aeolian, dorian or phrygian, with harmonic minor, melodic minor, phrygian dominant, mixolydian and dorian #4 as occasional visits. set the mode by hand (hold K2 + E3) to go anywhere. the screen shows a short name (`A dor`, `E phrdom`).

**dub.** the echo is a ping-pong tape delay with filtering, saturation and wow inside the feedback loop. its time is tempo-synced and glides when the tempo changes. at the end of some 8-bar blocks the conductor throws the echo: feedback and stab send jump for one bar, then fall back.

**listening.** with **LISTEN > follow input key** on, gradient tracks the key of whatever is coming into the norns inputs and keeps following it. the engine runs SuperCollider's `KeyTrack` (a pitch-class profile over a 4096 FFT, matched against major and minor templates). the script turns that into a decaying vote: a major key counts for its relative minor, since they share the same notes. gradient keeps whatever mode you're in and moves its root onto the heard notes: hearing A minor puts dorian on D, lydian on F, phrygian on E. the harmonic and melodic colours sit on the heard minor root (or, for phrygian dominant, its 5th). a new key has to lead the vote for **hold** seconds (default 10) with a clear share before gradient moves, and the move lands on the next 8-bar edge. quiet input below the **gate** doesn't vote, so the key holds through silence. while following, gradient stops making its own key moves (set-mode modulation, next-track key shifts). the screen shows `in Em 64%` (what it hears and how sure it is), `>D` when a move is pending, and `listening` when the input is below the gate.

---

## controls

| input | action |
|---|---|
| **E1 / E2 / E3** | the current page (below) |
| **K2 tap** | drop: kickless, hats and bass out, for the rest of this 8 bars and the next 8. tap again to bring it back |
| **K3 tap** | mutate now |
| **K2 + K3** | play / stop (starts on the next bar) |
| **hold K2** + E2 / E3 | key / mode |
| **hold K3** + E2 / E3 | tempo / set ↔ track |
| **hold K1** + E1 | visual theme |
| **hold K1** + E2 | encoder page |

**encoder pages**

| page | E1 | E2 | E3 |
|---|---|---|---|
| play | energy nudge (relaxes back over ~16 bars) | dub (echo send / feedback) | tone (brightness of stabs, arps, echo, wash) |
| lead | lead delay send | lead delay feedback | lead delay time |
| sound | kick tune | stab cutoff | pump depth |
| space | reverb size | echo wow | swing |

the page name shows under the key when you're off the play page.

**actions.** besides drop and mutate:
- **throw:** the main dub echo's feedback and stab send jump for the rest of this bar and the next.
- **lead throw:** the same for the lead delay (feedback near runaway, send up).
- **build:** pushes energy up and cancels a drop.
- **break:** pulls energy down and drops the kick, hats and bass for the rest of this 8 bars and the next.

build and break relax back over about 16 bars, like the E1 nudge. every action is also a trigger in **PARAMS > PERFORM**, so you can map them to a MIDI controller (PARAMS > MAP).

## grid

| row | |
|---|---|
| 1 | phrase position (dim marks every 8 bars) |
| 2 | energy: lit to the current level; press anywhere to pull energy there |
| 3 | parts `K H R B C 1 2 3 4 . wash noise`: brightness = how loud; press to mute / unmute |
| 4–7 | arp lanes 1–4: the lane's steps with its playhead. press a step to switch it on / off. col 15 mutes the lane, col 16 replaces it with a new one |
| 8 | 1 drop · 2 mutate · 3 throw · 4 lead throw · 6 break · 7 build · 14 new track · 16 play / stop |

mutes win over the conductor until you unmute; the pump keeps breathing when the kick is muted. lanes are at most 14 steps so they fit beside the lane buttons.

screen: key and mode top left, section top right (with `~` when kickless), energy bar bottom left, part lights bottom right (K H R B C 1 2 3 4; K is dim when only the ghost pump is running).

---

## params

- **GRADIENT:** play mode, phrase length, track length (4–32 min), track end (stop / next track), kick (auto / always / never), bass (auto / always / never), hats (auto / always / never), freeze material (stop mutations, arc still runs), seed, rebuild from seed, new random track
- **LISTEN:** follow input key, input gate (dB), hold before move (s)
- **KEY:** root, mode, harmony (simple / rich / drifting), chord voicing (m7, m9, quartal, add9, sus2, sus4, m11, cluster, 6/9, or auto by energy), bass octave
- **MIX:** dub, tone, echo time (1/8, 3/16, 1/4, 3/8), swing, pump depth, level, drive, reverb size, reverb type (hall / plate / spring), echo wow
- **LEAD DELAY:** a second tape echo fed only by the arps, apart from the dub echo and untouched by the dub knob and throws: send, time (1/16, 1/8T, 1/8, 3/16, 1/4T, 1/4, 3/8, 1/2; tempo-synced), feedback, tone, low cut, ping-pong, wow, saturation, to reverb, and whether the arps also feed the dub echo
- **BED:** a sound file from `dust/audio` looping under everything as a field-recording layer: file, level, tone, speed, to reverb. it drifts slowly in speed, filter and pan, rises in the kickless stretches, and fades with the arc like the wash
- **LEVELS:** kick, hat, rim, bass, chord, arp, wash, noise, crackle
- **SOUND:** kick tune (shown as note + Hz), kick type (**sub**: clean sine / **dusty**: 909-ish thud, crushed and band-limited), kick decay, stab cutoff / resonance / detune, bass cutoff, lane 1–4 voice
- **BASS OUT / CHORD OUT / ARP OUT:** output (internal / midi / both), midi device, channel (default bass ch 1, chords ch 2, arps ch 3)
- **ARP OUT > lanes to midi:** all four lanes on one channel, a single lane (for a mono synth: the other lanes keep playing on norns), or each lane on its own channel starting at the arp channel (ch, ch+1, ch+2, ch+3). velocity follows the lane's fade and accent; note length follows its decay
- **SYNC OUT:** a midi device to send start / stop to. gradient sends start on the bar it begins playing and stop when it stops, so a drum machine or sequencer lines up with bar one. the clock itself comes from norns: **PARAMS > CLOCK > midi out**, per port
- **CROW:** four outputs, each assignable: bass pitch, bass gate, lead pitch, lead gate, chord root, energy (0–5V, slewed), kick trig, pump env (5V ar per beat, follows the ghost sidechain even when the kick is out). pitches are 1V/oct with C3 at 0V, gates 8V. **lead lane** picks which arp lane is the lead; **pitch slew** adds glide; **pitch octave** shifts every pitch output. crow follows the parts as they play, whatever their internal / midi routing
- **CC OUT:** a midi device and channel (default 16) for the arc as CCs: energy, dub, tone (0 = off), and a phrase pulse (127 on the first bar of each phrase, then 0). sent once a bar, only when the value changes
- **VISUALS:**
  - **theme:** eight, each drawn from what the music is doing rather than just how loud it is:
    - **gradient:** the chord as soft bands of light at each voice's pitch, the bass glowing underneath; calm sections widen and soften the bands
    - **voices:** the four chord voices scrolling right to left, so voice leading and morphs are drawn as they happen; stabs flash as stems
    - **lanes:** each arp lane as a ring of its steps, playheads circling at their own lengths; a line joins the four heads and tightens when the lanes line up
    - **phase:** two line gratings turned by the phase gap between lanes 1 and 2, so the moiré swims as they drift apart
    - **echo:** every stab leaves copies drifting off at the echo time, fading by the feedback, wobbling like tape; throws leave long trails
    - **fall:** arp notes fall from their pitch; stabs fall slower and heavier; the bass glows on the floor
    - **pump:** horizon lines squeezed by the ghost sidechain each beat; in kickless stretches they turn to water
    - **arc:** the energy of the last 60 bars. columns go hollow where the kick was out, dots mark chord changes, a line marks pedal bass; in track mode a progress line runs along the bottom
  - **theme cycle:** off / every 8 bars / every phrase / each track; jumps to a random other theme
  - **overlay:** full / minimal (key and chord only) / off (just the picture, plus held-key hints and messages)
  - **speed, brightness**

**seeds.** a seed fixes a track's material: patterns, lanes, progression, harmonic rhythm. the moment-to-moment dice (which notes skip, when mutations land) run live, so a rebuilt seed is the same track played a different night.

**clock.** gradient follows the norns clock, so Link / MIDI clock sync works from the system CLOCK menu, and transport start/stop is honoured.

---

## install

copy the folder to `~/dust/code/gradient/` on norns. it ships its own engine (`lib/Engine_Gradient.sc`), so after the first install run **SYSTEM > RESTART** before loading the script.

## dev

`lua test/sim.lua [bars] [mode 1=set 2=track] [minutes]` runs the script headless against stubbed norns APIs and prints the conductor's arc every 8 bars. `HARM=1|2|3` picks the harmony mode; `SNAP=dir` renders each visual theme to a PGM in `dir` through a small rasterizer (`test/raster.lua`); `HTRACE=1` prints every bar's chord, notes and bass, and the run ends with how far the voices moved per change. it fails on doubled or out-of-range stab notes.

## license

MIT
