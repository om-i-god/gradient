# gradient

generative dub / kickless techno for norns. press play and let it ride.

gradient makes whole tracks by itself: phasing arpeggios, dub chord stabs into a tape echo, a sub bass, a kick you can drop out while its sidechain pump keeps breathing, hats, rims, a pad wash and a hiss/crackle bed. a conductor above the notes decides, bar by bar, what plays, how hard, and when things change. you can steer it, but you don't have to.

the bass and chords can also go out over USB MIDI, per part: **internal**, **midi**, or **both**.

---

## how it rides

**energy.** everything hangs off one slow value, 0 to 1. parts enter as it rises (arp lane 1 first, then the chords, a second lane, rim, hats, bass, kick, more lanes) and leave as it falls. each part fades over about four bars, and the entry thresholds jitter every phrase so the order isn't identical each time.

**phrase length.** a phrase (8, 16, **32** or 64 bars; default 32) is how long the arrangement holds before material mutates and the dice are re-rolled. track sections snap to whole phrases, and the set-mode swell lasts 8–16 phrases. the conductor still checks every 4 bars so parts follow the energy arc, and the dub throws, drop and input-key moves stay on an 8-bar grid.

**two modes.**
- **set (endless):** energy swells and drains over 8–16 phrases (about 4–16 min, depending on phrase length) with a random walk on top. the troughs are kickless "drift" stretches. at some troughs the key moves by a 4th or 5th.
- **track:** a fixed arc over the track length (default 8 min): intro → build → peak → breakdown (kickless) → return → outro. at the end it either stops or rolls straight into a new track with a new seed and a neighbouring key.

**kickless.** the pump (ghost sidechain on every quarter) keeps running when the kick drops out, so pads, arps, echo and reverb tails still breathe on the beat. that happens in breakdowns, when you press drop, and sometimes on its own at mid energy (kick: auto). set **kick → never** for a fully kickless set.

**phasing arps.** four lanes, each with its own odd length (3, 5, 7, 9, 11, 13 steps...), its own rate (16th, 8th, dotted 8th), register, pan, decay and slow filter LFO. lanes keep stepping even while silent, so when one fades back in it lands in a new phase against the others. lanes are written as chord-tone indices, so when the harmony moves, the arps move with it.

**mutation.** on every phrase, each lane might rotate, swap a note, or grow or shrink by a step, which shifts its phase. stab, hat, bass and rim patterns regenerate occasionally. very rarely a lane is replaced or the chord pair changes.

**harmony.** one key and one mode, and a two-chord world: i–VI, i–iv, i–VII and so on, or just i. chords swap every 2–8 bars. voicings: m7 (the classic stab), rootless m9, quartal, add9. the voicing names assume minor; in a major mode the same shape gives maj7, maj9 and so on.

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
| **E1** | energy nudge (relaxes back over ~16 bars) |
| **E2** | dub (echo send / feedback) |
| **E3** | tone (brightness of stabs, arps, echo, wash) |
| **K2 tap** | drop: kickless, hats and bass out, for the rest of this 8 bars and the next 8. tap again to bring it back |
| **K3 tap** | mutate now |
| **K2 + K3** | play / stop (starts on the next bar) |
| **hold K2** + E2 / E3 | key / mode |
| **hold K3** + E2 / E3 | tempo / set ↔ track |
| **hold K1** + E1 | visual theme |

screen: key and mode top left, section top right (with `~` when kickless), energy bar bottom left, part lights bottom right (K H R B C 1 2 3 4; K is dim when only the ghost pump is running).

---

## params

- **GRADIENT:** play mode, phrase length, track length (4–32 min), track end (stop / next track), kick (auto / always / never), freeze material (stop mutations, arc still runs), seed, rebuild from seed, new random track
- **LISTEN:** follow input key, input gate (dB), hold before move (s)
- **KEY:** root, mode, chord voicing, bass octave
- **MIX:** dub, tone, echo time (1/8, 3/16, 1/4, 3/8), swing, pump depth, level, drive, reverb size, echo wow
- **LEVELS:** kick, hat, rim, bass, chord, arp, wash, noise, crackle
- **SOUND:** kick tune / decay, stab cutoff / resonance / detune, bass cutoff
- **BASS OUT / CHORD OUT:** output (internal / midi / both), midi device, channel (default bass ch 1, chords ch 2)
- **VISUALS:** theme (terrain, tunnel, field, lattice: ported from causeway), speed, brightness, particles

**seeds.** a seed fixes a track's material: patterns, lanes, chord pair, harmonic rhythm. the moment-to-moment dice (which notes skip, when mutations land) run live, so a rebuilt seed is the same track played a different night.

**clock.** gradient follows the norns clock, so Link / MIDI clock sync works from the system CLOCK menu, and transport start/stop is honoured.

---

## install

copy the folder to `~/dust/code/gradient/` on norns. it ships its own engine (`lib/Engine_Gradient.sc`), so after the first install run **SYSTEM > RESTART** before loading the script.

## dev

`lua test/sim.lua [bars] [mode 1=set 2=track] [minutes]` runs the script headless against stubbed norns APIs and prints the conductor's arc every 8 bars.

## license

MIT
