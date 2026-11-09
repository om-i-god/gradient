# gradient

generative dub / kickless techno for norns. press play and let it ride.

gradient makes whole tracks by itself: phasing arpeggios, dub chord stabs into a tape echo, a sub bass, a kick you can drop out while its sidechain pump keeps breathing, hats, rims, claps, tuned hand / wood / metal percussion, a ride, glitch ticks, a glitch processor on the whole mix, a pad wash and a hiss/crackle bed. a conductor above the notes decides, bar by bar, what plays, how hard, and when things change. you can steer it, but you don't have to.

the bass, chords and arps can also go out over USB MIDI, per part: **internal**, **midi**, or **both**.

---

## how it rides

**energy.** everything hangs off one slow value, 0 to 1. parts enter as it rises (arp lane 1 first, then the chords, a second lane, rim, hats, bass, kick, more lanes) and leave as it falls. each part fades over about four bars, and the entry thresholds jitter every phrase so the order isn't identical each time.

**phrase length.** a phrase (8, 16, **32** or 64 bars; default 32) is how long the arrangement holds before material mutates and the dice are re-rolled. track sections snap to whole phrases, and the set-mode swell lasts 8–16 phrases. the conductor still checks every 4 bars so parts follow the energy arc, and the dub throws, drop and input-key moves stay on an 8-bar grid.

**two modes.**
- **set (endless):** energy swells and drains over 8–16 phrases (about 4–16 min, depending on phrase length) with a random walk on top. the troughs are kickless "drift" stretches. at some troughs the key moves by a 4th or 5th.
- **track:** a fixed arc over the track length (default 8 min): intro → build → peak → breakdown (kickless) → return → outro. at the end it either stops or rolls straight into a new track with a new seed and a neighbouring key.

**kickless.** the pump (ghost sidechain on every quarter) keeps running when the kick drops out, so pads, arps, echo and reverb tails still breathe on the beat. that happens in breakdowns, when you press drop, and sometimes on its own at mid energy (kick: auto). set **kick → never** for a fully kickless set. **bass** works the same way: auto sits it out in some kickless stretches, always keeps it in whenever the energy is high enough, never turns it off everywhere (engine, midi and crow), for when you bring your own low end. **hats** too: auto sometimes clears them for a drop, always keeps them in once the energy is there, never mutes them for good. the hats setting (and the hats mute) covers the shaker and toms as well.

**drums.** each track picks a hat groove: **straight** (offbeats plus loose 16th ghosts), **rolling** (every 16th, leaning on the offbeat), **skip** (offbeats plus a euclidean ghost pattern) or **sparse** (just the offbeats). some grooves shuffle, sitting the off-16ths a little late, on top of the global swing. marked offbeats open up while the energy is building or near the top. on some phrases a **shaker** joins at higher energy, and **dub toms** tuned to the chord drop one or two hits a bar into the echo.

**more drums.** each track also picks:

- **clap:** a clap, snare or snap on the backbeat (2 and 4), a lone 4, or a backbeat with a ghost; on some tracks it sits a little behind the grid. it comes in high on the energy, sits out drops and most kickless stretches, and goes into the dub echo (harder on a throw).
- **perc:** a percussion lane with its own odd length (6, 7, 9, 10, 12, 14 or 16 steps), so like the arps it phases against the bar. the kit is **hand** (bent-sine congas), **wood** (claves / logs) or **metal** (cowbell / agogo), tuned to the chord's low, middle and high voices. it comes in early in the build, and on some kickless stretches it stays in or comes in low down: congas in the breakdown. it rotates or regrows on phrase edges.
- **ride:** quarters, offbeats or 8ths near the top of the energy on some phrases, riding with the hats.
- **ghost kicks:** quiet extra kicks before a beat, near the top, on some phrases. the pump stays on the quarters.
- **kick types:** sub, dusty, **boom** (a long 808-ish sub) or **knock** (short and tight).

**glitch.** two layers, set together by **glitch** (off / subtle / **normal** / heavy):

- **ticks:** clicks, blips, crushed noise and zaps tuned to the chord, on a euclidean scatter, some ratcheted 2–3 times inside a 16th, into the dub echo. they come in mid-build and float on through kickless stretches.
- **the glitch insert:** a processor on the whole mix after the echoes and reverb, before the master (so the pump still ducks the live pulse). **stutter** repeats a slice, **tape stop** winds the mix down, **reverse** plays the last moments backwards, **chop** gates the mix in 32nds, **crush** coarsens it. each bar may hold a small one somewhere (more near the top and in kickless stretches), and the stutter, tape stop and reverse also turn up as fills. **glitch depth** (LEVELS) sets how wet it is.

**fills.** the bar before a phrase edge almost always gets a fill, and some 8-bar edges get a small one:

- **swell:** a noise riser over the last three beats, cut dead at the downbeat
- **dip:** a filter dip on everything but the kick and hats, opening again on the downbeat
- **toms:** a tom run down the chord on the last beat
- **gap:** kick, hats and bass drop out for the last beat (sometimes the last half bar) while the pump keeps going
- **throw:** an extra stab on the last offbeat with the echo thrown
- **open:** open hats and rim ghosts
- **stutter:** the last beat repeats, the slices halving into a roll (glitch on)
- **tape stop:** the mix winds down over the last beat, the downbeat lands live (glitch on)
- **reverse:** the last beat plays backwards (glitch on)

risers and gaps come up more when the energy is heading up; dips and throws when it's settling. **fills** (GRADIENT) sets normal / busy / off. there are no fills while something's soloed.

**bass lines.** each track keeps three bass lines and plays the one that fits the energy: a calm one (sparse roots, or a slide line of long notes gliding into each other), a middle one (octave bounces or slides) and a high one (rolling syncopated 16ths with fifths and b7s, or octaves). every 4th bar the last beat can move: if the chord is about to change, the bass walks in from a semitone or tone away; if not, it turns around (octave up, then a slide back down). over a pedal it sticks to roots and octaves.

**voices.** bass, chords, hats, pad and the arp lanes each have a choice of sound, set in SOUND. on **auto** (the default) gradient picks for you, from the seed and the energy, and re-picks at phrase edges, so a long set doesn't keep one timbre. fix any of them to stop that part moving.

- **bass:** **sub** (a round sine), **reese** (detuned saws beating slowly) or **rubber** (a round FM bass that bounces in on a pitch blip)
- **chords:** **dub** (the classic filtered stab), **felt** (soft, muted), **organ**, **glass** or **rhodes**
- **hats:** **noise**, **metal** (ringing, inharmonic) or **dust** (soft and breathy, with a longer tail)
- **pad:** **wash**, **choir**, **strings** or **drone**. on auto the pad can change when the section changes. a pad change lands a moment after you stop turning, then crossfades over a few seconds.
- **arp lanes:** **classic** (triangle/pulse), **bell** (two-operator FM), **pluck** (karplus string), **soft** (sine), **glass**, **reed**, **kalimba** or **marimba**. on auto the seed picks, mostly classic.

**time signatures.** **time signature** (GRADIENT) is 4/4, 3/4, 5/4 or 7/4. **feel** sets how the beats group: **even**, or one of the two uneven groupings of that meter (shown as the groups themselves, e.g. `3+2` or `2+3` in 5/4, `4+3` or `3+4` in 7/4). the patterns, fills and bass lines are built for the bar length, and in A / B feels soft ghost beats sit on the beats that aren't the start of a group. a change lands at the next phrase, not mid-bar, and while stopped it applies at once. the screen shows the meter in front of the section label, and the visuals follow the bar: their pulse, rings and sweeps count the real beats.

**phasing arps.** four lanes, each with its own odd length (3, 5, 7, 9, 11, 13 steps...), its own rate (16th, 8th, dotted 8th), register, pan, decay and slow filter LFO. lanes keep stepping even while silent, so when one fades back in it lands in a new phase against the others. lanes are written as chord-tone indices, so when the harmony moves, the arps move with it.

**mutation.** on every phrase, each lane might rotate, swap a note, or grow or shrink by a step, which shifts its phase. stab, hat, shaker, tom, bass and rim patterns regenerate occasionally (the bass one band at a time). very rarely a lane is replaced or a new progression arrives (it lands on the next 8-bar edge).

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
| parts | energy nudge | pick a part | that part's level |

the page name shows under the key when you're off the play page.

**parts page.** a strip of every part (`K H R B C 1 2 3 4 S P G`: S clap, P perc, G glitch ticks and the small glitches) with the picked one underlined. here **K2** mutes / unmutes the picked part and **K3** solos it (soloed parts are boxed, and more than one can be soloed; a solo silences everything else, beds included). K2 + K3 still plays / stops. the lanes share the arp level. mutes and solos, from here or the grid, land at once instead of fading.

**actions.** besides drop and mutate:
- **throw:** the main dub echo's feedback and stab send jump for the rest of this bar and the next.
- **lead throw:** the same for the lead delay (feedback near runaway, send up).
- **stutter / tape stop / reverse / chop:** the glitch insert on the next beat, by hand.
- **build:** pushes energy up and cancels a drop.
- **break:** pulls energy down and drops the kick, hats and bass for the rest of this 8 bars and the next.

build and break relax back over about 16 bars, like the E1 nudge. every action is also a trigger in **PARAMS > PERFORM**, so you can map them to a MIDI controller (PARAMS > MAP).

## grid

| row | |
|---|---|
| 1 | phrase position (dim marks every 8 bars) |
| 2 | energy: lit to the current level; press anywhere to pull energy there |
| 3 | parts `K H R B C 1 2 3 4 . wash noise bed clap perc ticks`: brightness = how loud; press to mute / unmute |
| 4–7 | arp lanes 1–4: the lane's steps with its playhead. press a step to switch it on / off. col 15 mutes the lane, col 16 replaces it with a new one |
| 8 | 1 drop · 2 mutate · 3 throw · 4 lead throw · 6 break · 7 build · 9 stutter · 10 tape stop · 11 reverse · 14 new track · 16 play / stop |

mutes win over the conductor until you unmute; the pump keeps breathing when the kick is muted. lanes are at most 14 steps so they fit beside the lane buttons.

screen: key and mode top left, section top right (with `~` when kickless), energy bar bottom left, part lights bottom right (K H R B C 1 2 3 4 S P G; K is dim when only the ghost pump is running).

---

## params

- **GRADIENT:** time signature (4/4, 3/4, 5/4, 7/4), feel (even or the two groupings), play mode, phrase length, track length (4–32 min), track end (stop / next track), kick (auto / always / never), bass (auto / always / never), hats (auto / always / never), fills (normal / busy / off), perc (auto / always / never), clap (auto / always / never), glitch (off / subtle / normal / heavy), freeze material (stop mutations, arc still runs), seed, rebuild from seed, new random track
- **LISTEN:** follow input key, input gate (dB), hold before move (s)
- **KEY:** root, mode, harmony (simple / rich / drifting), chord voicing (m7, m9, quartal, add9, sus2, sus4, m11, cluster, 6/9, or auto by energy), bass octave
- **MIX:** dub, tone, echo time (1/8, 3/16, 1/4, 3/8), swing, pump depth, level, drive, reverb size, reverb type (hall / plate / spring), echo wow
- **LEAD DELAY:** a second tape echo fed only by the arps, apart from the dub echo and untouched by the dub knob and throws: send, time (1/16, 1/8T, 1/8, 3/16, 1/4T, 1/4, 3/8, 1/2; tempo-synced), feedback, tone, low cut, ping-pong, wow, saturation, to reverb, and whether the arps also feed the dub echo
- **BED:** a sound file from `dust/audio` looping under everything as a field-recording layer: file, level, tone, speed, to reverb. it drifts slowly in speed, filter and pan, rises in the kickless stretches, and fades with the arc like the wash
- **LEVELS:** kick, hat (also shaker, toms, ride), rim, bass, chord, arp, clap, perc, tick, glitch depth, wash, noise, crackle
- **SOUND:** kick tune (shown as note + Hz), kick type (**sub**: clean sine / **dusty**: 909-ish thud, crushed and band-limited / **boom**: long 808-ish sub / **knock**: short and tight / **deep**: a low slow-falling sub with a felt thump / **tight**: a fast drop and a tiny tick), kick decay, stab cutoff / resonance / detune, bass cutoff, clap voice (auto / clap / snare / snap), perc kit (auto / hand / wood / metal), bass type (auto / sub / reese / rubber / fm sub / tape), stab type (auto / dub / felt / organ / glass / rhodes / choir / strings), hat type (auto / noise / metal / dust / tape), pad type (auto / wash / choir / strings / drone / glass / tape loop), lane 1–4 voice (auto / classic / bell / pluck / soft / glass / reed / kalimba / marimba / steel / bowed). auto picks from every choice and changes now and then as the track moves. **echo type** swaps the dub echo, crossfading: **dub** (as before) / **tape** (one darker, wobblier head whose repeats widen) / **ping-pong** (clean and bright, crossing sides) / **space** (three heads on one tape loop with a spring-like smear). **character** colours the whole mix: **clean** (exactly as before) / **warm** (a soft saturating knee and a gentle top roll-off) / **dusty** (narrower, crunchier, a little wow)
- **BASS OUT / CHORD OUT / ARP OUT:** output (internal / midi / both), midi device, channel (default bass ch 1, chords ch 2, arps ch 3)
- **ARP OUT > lanes to midi:** all four lanes on one channel, a single lane (for a mono synth: the other lanes keep playing on norns), or each lane on its own channel starting at the arp channel (ch, ch+1, ch+2, ch+3). velocity follows the lane's fade and accent; note length follows its decay
- **SYNC OUT:** a midi device to send start / stop to. gradient sends start on the bar it begins playing and stop when it stops, so a drum machine or sequencer lines up with bar one. the clock itself comes from norns: **PARAMS > CLOCK > midi out**, per port
- **CROW:** four outputs, each assignable: bass pitch, bass gate, lead pitch, lead gate, chord root, energy (0–5V, slewed), kick trig, pump env (5V ar per beat, follows the ghost sidechain even when the kick is out). pitches are 1V/oct with C3 at 0V, gates 8V. **lead lane** picks which arp lane is the lead; **pitch slew** adds glide; **pitch octave** shifts every pitch output. crow follows the parts as they play, whatever their internal / midi routing
- **CC OUT:** a midi device and channel (default 16) for the arc as CCs: energy, dub, tone (0 = off), a phrase pulse (127 on the first bar of each phrase, 0 on every other bar: it goes out every bar, so a listener can tell gradient is still there) kickless (127 while the kick is out), and the key: key root and chord root (0–11, C = 0) and mode (its number in KEY > mode). all sent every bar. **breakage**, the drummer script, follows these on its own norns, tuning its drums to the key: set energy 20, dub 21, tone 22, phrase pulse 23, kickless 24, key root 25, mode 26, chord root 27 on channel 16 to match its defaults
- **VISUALS:**
  - **theme:** twenty-eight places at night, each drawn from what the music is doing. every theme answers every part (kick, pump, hats, clap, perc, ticks, chord stabs, bass, arp lanes and the pad) and every band of what the engine hears of its own output (overall level, lows, mids, highs), plus the dub echo and its throws. the pulse shows in every theme, kickless stretches loosen the picture, and nothing strobes:
    - **gradient:** the chord as soft bands of light weaving across the sky at each voice's place in the chord, over a floor where the bass glows and the bands come back as broken reflections. the pump breathes the bands, stabs swell their voice, the highs are grain in the light, and kickless stretches loosen them into haze
    - **voices:** the four chord voices as ribbons scrolling right to left over a dim staff, written at a playhead on the right, so voice leading and morphs are drawn as they happen. stabs swell the ribbons with a stem and echo back as fainter repeats at the echo time; a heavy bass ribbon runs along the bottom
    - **lanes:** a machine of four nested step rings round a hub, one per arp lane, each with a tick per step. playheads ease round with fading trails, notes light the tick they land on, and a line joins the heads: tight when the lanes line up, a zigzag as they phase apart. the hub pumps and lights on the kick
    - **phase:** two chain-link fences under a floodlight on waste ground. the gap between arp lanes 1 and 2 turns the far fence against the near one, so the moiré bands of light swim as the lanes drift apart; the pump squeezes the far fence on every beat
    - **echo:** a railway viaduct seen side-on over a canal. each stab lights the first arch with four bars of light, one per chord voice; every echo time a copy appears in the next arch, fainter by the feedback and swaying on a tape wobble. arp notes are train windows along the deck, the bass glows on the water
    - **fall:** under a brick arch looking through to a lit street. arp notes drip from the arch at their pitch and splash on the wet floor, stabs fall heavier, the bass glows in a puddle the kick ripples, and the pump flickers the street lamp. throws repeat the splashes at the echo time
    - **pump:** a city across a flat drawn in ruled lines. each pump squeezes every line toward the horizon, near field first, and they spring back; the horizon flares with the kick. in kickless stretches the ground turns to water and the skyline reflects in it
    - **arc:** the last ~60 bars as a ridge at night: each bar's land as high as its energy, hollow where the kick was out, a small light where the chord changed, a road under pedal bass. the live edge is a lamp pulsing with the kick; the moon crosses the sky with the track, and track mode adds a progress line
    - **motorway:** a night motorway from a bridge, under sodium lamps and a gantry of signs. the four arp lanes are four traffic lanes: each note sends a car, higher notes faster. the bass sends a lorry up the slow lane, stabs light the signs, the pump is the sodium flicker, throws streak the lights into long exposures
    - **tape:** a reel-to-reel tape echo face on. each stab is written at the record head and the tape carries it to the playback heads in exactly one echo time, where it is written again, fainter by the feedback, until it dies. the VU needle kicks with the pump; throws spin the reels and smear the marks
    - **stack:** a sound system in a yard: bass bins, mids, horns, an amp rack and a crowd in silhouette. the bin cones push out on the kick and the lows (softer on the ghost pump when kickless), each chord voice lights its mid cone, each arp lane its own tweeter, the horns shimmer with the highs
    - **blocks:** tower blocks at night over a viaduct. each arp lane has a tower, and a note lights a window on the floor of its pitch, coming back fainter at the echo time. the chord decides which floors are lived in, the pump dims the stairwells, a train crosses on each bar
    - **beams:** moving heads and a mirror ball throwing slow beams through haze onto a dancefloor. each head is an arp lane leaning toward its notes, stabs swell every beam, the kick lands as a low floor glow, throws leave ghost beams at the echo time. every change is eased
    - **window:** the city out of focus through a rain-streaked window. the chord is four bokeh discs at its voices' pitches, the bass a big streetlamp blur, arp notes far windows switching on. drops slide down in jolts on each pump and merge; throws ghost the discs in the double glazing
    - **pylons:** lattice pylons striding across a foggy field. four wires, one per arp lane: each note runs along its wire as a spark. the wires sag with the bass and dip on every pump, stabs make the insulators glow, the highs crackle round them
    - **dubplate:** a record turning under a lamp, once a bar, so the label's mark passes the stylus on every downbeat while the tonearm creeps in over the phrase. stabs leave glints on the groove at each voice's radius, arp notes drop dust that crackles past the stylus, the strobe dots flicker with the pump
    - **radar:** a round scope at night, a sweep arm turning once a bar and leaving a phosphor wake. every hit leaves a blip that glows again each time the arm passes: the bass on the inner ring (its note the bearing), arps on the next, stabs and perc in the middle, hats and ticks on the rim. the kick pings a ring out from the centre, the pump swells the range rings, a clap flares a sector, and the pad is weather drifting over the scope
    - **subway:** a train passing in a tunnel, seen side-on, lamps and pillars going by in parallax. the speed follows the energy, surges with each pump and slows to a crawl when kickless. stabs fill four windows, arps draw a lane's line in the glass, perc lights a rider, hats a window's top, ticks a spark, claps two windows at once; the kick thumps the carriage and the bass fires the wheels
    - **harbour:** a container berth: two quay cranes over a moored ship on dark water, every light with a long rippled reflection that sways with the bass and lows. hats blink the crane lights one crane after another, the pad lies on the water as slow bands, the kick thumps the waterline, the pump lifts the dock's glow, a clap throws a searchlight pool, ticks are welding sparks, stabs fill the bridge windows
    - **sodium:** a street at night looking down it under a hazy sodium sky, lamps drifting towards you as if on a walk (faster with the energy). hats flicker a lamp, ticks make one buzz with sparks and moths, the pump makes the tarmac breathe, a stab flares the four nearest lamps, the kick thumps the glow at the vanishing point, a clap sends headlights down the road
    - **lighthouse:** a headland seen from the sea, a lighthouse beam turning in the haze (its speed follows the energy). the kick pulses the beam, the pump lifts the lantern's glow, waves catch the bass and lows, stabs light the keeper's window bands, arps are buoys blinking on the water (one lane each), hats glint on the wave tops, ticks are gulls' sparks, a clap flashes a thin signal line
    - **tramlines:** looking up a tram street at night, overhead wires running toward a vanishing point and a mast at the left. a pantograph rides a contact wire and slides with the arps. each pump sags the whole web and lets it shiver back, the bass hums as a standing wave in the long spans, hats and ticks spark blue-white at the joints
    - **substation:** a fenced yard of transformers and insulators under a gantry, with a small control room. the lows hum as heat shimmer over the transformers, the pump sways the gantry wires, the kick brightens the tank outlines, a clap arcs between two bushing tops, perc arcs down from the gantry, stabs light the control-room windows (one note per window), the pad is the sodium glow over the fence
    - **cooling:** two cooling towers on the horizon with steam plumes rising from the rims. the pad and the energy thicken the plumes, the pump squeezes them in, the kick sends a ring up the plume, hats are the aircraft warning lights on the rims (one tower each, alternating), the bass lights the towers' bases and the ground, a clap bursts a fan of vapour off a rim
    - **carpark:** a multi-storey car park side-on: concrete decks under strip lights, parked cars, a ramp, a stairwell and an exit barrier. the kick catches every strip light, the bass hums in the lowest deck, hats flicker a failing tube, ticks blink the barrier, stabs send a car up the ramp with its headlights sweeping, arps are brake lights, a clap swings the stairwell door, perc echoes off a landing, the pad is fog at the open sides
    - **laundrette:** a late-night laundrette through the shop window: a row of front-loaders with their drums turning (faster with the energy and the pump), a bench, a change machine. the kick drops the loads, the bass shakes the machines, hats glint in the suds, ticks are the timer LEDs, stabs flood a porthole, arps light the panels, a clap is a dryer's tumble knock, perc drops a coin through the change machine, the pad steams the glass
    - **signalbox:** a railway junction from beside the line: a raised signal box with its lever frame lit, track fanning into points, signals on posts and wires beyond. the kick runs a pulse along the rails, the bass rings them, hats twinkle on the signal lamps, ticks are the block-bell lights, stabs pull a lever and move its signal arm, arps change the colour-light aspects, a clap is a train's windows passing far off, perc throws the points over with sparks, the pad is mist over the junction, the pump breathes the box window
    - **rooftop:** a city rooftop: water towers on stilts, aerials, a dish, an air-con unit, a parapet and the skyline beyond. the kick shakes the towers' hoops, the bass turns the air-con fan, hats are the aviation lights on a far mast, ticks blink skyline windows, stabs light a window in the near tower block, arps flash the aerial tips and run light down the masts, a clap swings a searchlight, perc glints off the dish, the pad is low cloud lit from below, the pump breathes the parapet lamp
  - **drums and glitch on screen:** claps, perc and ticks land on every theme, each with its own touch. while the glitch insert runs, the picture glitches with it, whatever the theme: a band of rows freezes on each stutter or chop slice while the rest moves on, slides out and home on a reverse, drifts out while the picture dims through a tape stop, and coarsens on a crush. it stays inside the no-strobe limits.
  - **robust:** a theme that fails to load or errors mid-draw is swapped for a plain horizon scene and logged once to the REPL; the script and the other themes keep going, and the theme gets another go next time you switch to it. every frame has a draw budget, and bad values never reach the screen.
  - **theme cycle:** off / every 8 bars / every phrase / each track; jumps to a random other theme
  - **overlay:** full / minimal (key and chord only) / off (just the picture, plus held-key hints and messages)
  - **speed, brightness**
  - **trails, detail, reactivity:** trails (0-100, 50 as designed) scales how long marks and afterimages linger; detail is classic (exactly the look before round 3; trails only shorten, to 0.95x, there) / fine (the default) / dense (fine plus extra fine texture: more lit windows, finer staff lines, extra hairlines, subtle on some scenes); reactivity (0-100, 50 as designed) scales how hard each scene answers the parts and bands at fine and dense (classic is the look before round 3 and does not react to it)

**seeds.** a seed fixes a track's material: patterns, lanes, progression, harmonic rhythm. the moment-to-moment dice (which notes skip, when mutations land) run live, so a rebuilt seed is the same track played a different night.

**clock.** gradient follows the norns clock, so Link / MIDI clock sync works from the system CLOCK menu, and transport start/stop is honoured.

---

## install

copy the folder to `~/dust/code/gradient/` on norns. it ships its own engine (`lib/Engine_Gradient.sc`), so after the first install, and after any update that changes the engine (the visuals' output polls did), run **SYSTEM > RESTART** before loading the script.

## dev

`lua test/sim.lua [bars] [mode 1=set 2=track] [minutes]` runs the script headless against stubbed norns APIs and prints the conductor's arc every 8 bars. `HARM=1|2|3` picks the harmony mode; `SNAP=dir` renders each visual theme to a PGM in `dir` through a small rasterizer (`test/raster.lua`); `lua test/unit.lua test/unit_meter.lua` checks the meters, feels and bar lengths; `lua test/unit.lua test/unit_engine.lua` checks the engine source for maths that only goes wrong on the norns (an unclamped `sqrt` is NaN at zero there); `lua test/unit.lua test/unit_visuals.lua` runs every theme headless through silence / mid / peak / kickless and checks lit area, frame-to-frame change, the pulse, audio reactivity, bad input and the draw-call budget (`VISONLY=a,b` for some themes, `VISREPORT=1` for the numbers; `lua test/switch_probe.lua` lists the frames of the theme-switch run that jump most); `lua test/contact.lua out.pgm` draws a contact sheet of every theme; `test/sc/run.sh [test/sc/sound.scd | test/sc/glitch.scd]` compiles the engine against a stub and plays every voice (`glitch.scd` checks each glitch mode against a lone kick, `glitch_after.scd` that the mix comes back after each one, `levels.scd` that every voice choice sits in a sane level range, `pad_swap.scd` that a pad change mid-fade never leaves more than two pads running, `fx_swap.scd` that rapid echo type and character changes keep at most two echoes and the output alive, `character_null.scd` that character clean is sample-identical to the master before it existed); the tests also pass on Lua 5.3; the checks to make on a real norns are in `docs/device-checks.md`; `HTRACE=1` prints every bar's chord, notes and bass, and the run ends with how far the voices moved per change. it fails on doubled or out-of-range stab notes.

## license

MIT
