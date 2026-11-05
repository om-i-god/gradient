# visuals v2: checks only the device can answer

- **SYSTEM > RESTART first.** The engine gained the `out_amp / out_lo / out_mid / out_hi` polls. Until a restart the visuals run on the old amp poll and the event envelopes; they still draw, just with less in the highs and lows.
- **CPU.** On a laptop the heaviest themes (gradient, phase, voices, blocks) cost ~0.4–0.7 ms of Lua per frame and 600–900 screen calls. On the norns, check that the step clock stays tight with each of them on screen at peak energy (listen for late 16ths, watch `top` for matron).
- **Poll ranges.** `grad_master` maps out_amp / out_lo from −54 / −56 dB up to −3 dB. If loud passages pin them at 1 (the pulse flattens in stack, gradient's floor, pylons' hum), move the top ends toward 0 dB in `lib/Engine_Gradient.sc`.
- **Low brightness.** At brightness 3–5 the dim atmosphere (levels 1–2) may vanish on the OLED; check that each theme still reads as its place.
- **Pulse feel.** The pump's visual breath has a 60 ms attack. At 120–130 bpm check it reads as the groove, not a flicker, especially in pump, motorway and beams.
- **Theme cycle.** With theme cycle on, check the 0.25 s fade-out / 0.5 s fade-in at the bar edge feels right.
