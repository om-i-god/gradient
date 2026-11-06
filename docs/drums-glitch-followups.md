# drums + glitch: device checks

The engine changed (new SynthDefs and the glitch insert), so do **SYSTEM > RESTART** before loading.

- **CPU.** The glitch insert is a 4-channel delay that runs all the time, and peaks now stack clap, perc, ride, ticks and ghost kicks on top of the old kit. Watch the CPU readout at energy near 1 with glitch = heavy.
- **RT memory.** The glitch delay takes about 2 MB, and the two echoes take about 2 MB more. If engine load shows `alloc failed` or `/fail`, this is the first suspect: shorten `DelayC.ar(sig, 2.05, ...)` in `grad_glitch`. Reverse is capped at 1 s to match.
- **Levels.** Check clap, perc and ticks against the kick and hats by ear. The LEVELS params scale them, and their amps in `play_step` set where they sit by default.
- **Glitch feel.** "normal" gives a small glitch on roughly 1 bar in 5 near the top. If it's too busy, "subtle" halves that. Glitch depth sets how wet it is.
- **Visual glitch.** A band freezes on stutter and chop, slides out and back on reverse, and the picture dims through a tape stop. Check it reads at low brightness.
