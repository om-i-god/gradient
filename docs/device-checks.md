# drums + glitch: device checks

The engine changed (new SynthDefs and the glitch insert), so do **SYSTEM > RESTART** before loading.

- **CPU.** The glitch insert is a 4-channel delay that runs all the time, and peaks now stack clap, perc, ride, ticks and ghost kicks on top of the old kit. Watch the CPU readout at energy near 1 with glitch = heavy.
- **RT memory.** The glitch delay takes about 2 MB, and the two echoes take about 2 MB more. If engine load shows `alloc failed` or `/fail`, this is the first suspect: shorten `DelayC.ar(sig, 2.05, ...)` in `grad_glitch`. Reverse is capped at 1 s to match.
- **Levels.** Check clap, perc and ticks against the kick and hats by ear. The LEVELS params scale them, and their amps in `play_step` set where they sit by default.
- **Glitch feel.** "normal" gives a small glitch on roughly 1 bar in 5 near the top. If it's too busy, "subtle" halves that. Glitch depth sets how wet it is.
- **Visual glitch.** A band freezes on stutter and chop, slides out and back on reverse, and the picture dims through a tape stop. Check it reads at low brightness.

# voices, themes and time signatures: device checks

The engine gained commands (`bass_type`, `chord_type`, `hat_type`, `pad_type`, four more arp voices), so do **SYSTEM > RESTART** before loading.

- **New voices: level and CPU.** At energy near 1, set the heaviest choices together (bass reese, chords organ or glass, hats metal, pad choir or strings, arp lanes on the new voices, glitch = heavy) and watch the CPU readout and the levels against the kick. Then walk each choice on its own. Anything much louder or quieter than the rest wants its amp trimmed in the engine.
- **Auto picks.** On auto, let a set run several phrases. Voices should change at phrase edges and the pad only around section changes.
- **Pad swaps.** Change the pad type by hand while the pad is loud, and several times in quick succession. The change should crossfade (0.25 to 2 s to arrive) with no click, no gap and no CPU spike from stacked pads.
- **Themes.** Step through all 24 with hold K1 + E1, including radar, subway, harbour, sodium, lighthouse, tramlines, substation and cooling. For each: every part visibly answers (kick, pump, hats, clap, perc, ticks, stabs, bass, arps, pad), it reads at low brightness, nothing strobes, and the frame rate holds at peak.
- **5/4 in each feel.** Set the time signature to 5/4 and try even, `3+2` and `2+3`. A change made mid-phrase should land on the phrase edge, not before. Check that the bar counts five beats, the ghost beats sit on the non-group beats in the uneven feels, and the visuals pulse on the beat (sweeps and rings complete once per bar).
- **7/4 even.** Same checks with 7/4 and the even feel, then try `4+3` and `3+4`. Go back to 4/4 and confirm the pattern returns to normal.
- **Meter and sync.** With an external clock or MIDI sync out connected, a meter change should keep the clock and start/stop lined up.
