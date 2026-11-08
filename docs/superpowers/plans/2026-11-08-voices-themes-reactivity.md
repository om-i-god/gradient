# More voices, eight themes, full audioreactivity: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 16 new voice choices across five parts, add eight new visual
themes, and make every theme react to every part and every audio band,
without changing anything that exists.

**Architecture:**
- **Engine.** New SynthDefs, picked through the existing `st` keys
  (`tweak`), the same way as `kick_type`. The persistent pad is swapped by a
  new `pad_type` command that crossfades between pad synths, the way
  `verb_type` swaps the reverb.
- **auto.** A new `lib/timbre.lua` makes the auto picks with its own dice,
  per track and per phrase.
- **Visuals.** The kit gains a `pad` event and a test-only `VIS.strict`
  flag, so a reactivity test can prove each theme answers each part
  itself. Every theme gets the missing reactions, and the eight new themes
  are new files in `lib/vis/`.

**Tech stack:**
- Lua 5.3 (norns matron); the tests also run on Lua 5.4.
- SuperCollider 3.13-dev on the norns (ARM), and 3.14 locally.

**Spec:** `docs/superpowers/specs/2026-11-08-voices-themes-reactivity-design.md`

## Global constraints

- Add, never replace:
  - Existing voices, themes, param IDs and option orders and indices stay
    as they are.
  - New options are appended to the end of their lists.
  - Existing themes keep their compositions; tasks only add reactions.
- Visual bounds, unchanged (`test/unit_visuals.lua`): lit ≤ 0.40, a live
  scene lit > 0.04 and silence lit > 0.01, `DIFF_MAX` 0.7, level-15 pixels
  ≤ 12, draw calls ≤ 1200 per frame, no NaN or inf.
- sclang has no operator precedence, so parenthesise every compound
  expression.
- Never give a `t_foo` argument and a `foo` argument the same name.
- Clamp `sqrt` input with `.max(<positive literal>)`. `test/unit_engine.lua`
  enforces this, because the norns' ARM `sqrt` is NaN at 0. Keep `log`,
  `pow` and division away from 0 too.
- Load the script's own lib files with `include("lib/<name>")`, never
  `require`.
- Never write device names, LAN IPs or SSH key paths into the repo.
- New voice levels: each new type's peak is within ±4 dB of the part's
  first fixed type.
- CPU on a norns at a peak with the heaviest choices: under about 45%.
- READMEs describe behaviour, steering and setup. No "what it won't do"
  sections.

## Review focus

These are five inputs no task's main tests exercise. Each has a pinned test
in the task named:

1. **Old PSETs.** A saved pset with `laneN_voice` = 5 ("soft") must still
   mean soft after the lists grow. Pinned in Task 8 (sim: option index 5
   is still "soft").
2. **Changing `pad_type` rapidly** (encoder spun through the list): no
   stacked pads, no click, and the engine ends on the last choice with one
   pad running. Pinned in Task 7 (`pad_swap.scd`: 10 swaps in 1 s, then
   exactly one pad node).
3. **A type change during a held note.** A bass or chord already sounding
   keeps its voice; only new notes use the new type. That follows from the
   pick being made at spawn time. Pinned in Task 7 (`levels.scd` swaps the
   type mid-note).
4. **The `pad` event with a short or garbage chord** (`{}`, `{60}`, or NaN
   in it): no theme throws. Pinned in Task 1 (the garbage-events test is
   extended to `pad`).
5. **auto never flickers.** A part's auto pick changes at most once per
   phrase. Pinned in Task 8 (sim: count the changes per phrase).

---

### Task 1: Reactivity harness (the kit's `pad` event, `VIS.strict`, the failing test)

**Files:**
- Modify: `lib/visuals.lua`:
  - `env` and `ENV_TAU`: add `pad`, with tau 0.6.
  - `VIS.event`: route `pad`; honour `VIS.strict`.
  - The header: document the `pad` event and the `pad = fn(notes)` handler.
- Modify: `test/unit_visuals.lua`: add the reactivity test, add the
  `out_mid` and `out_amp` band checks, and extend the garbage-events test to
  `pad`.

**Interfaces:**
- Produces:
  - `VIS.event("pad", notes)`: sets `env.pad = 1`, then calls the theme's
    `pad(notes)` if it has one. `notes` is any table; the kit copies up to
    four finite numbers.
  - `K.env.pad`.
  - `VIS.strict` (boolean, default `false`): when `true`, clap, perc and
    tick no longer fall back to the theme's `hat`.
  - The theme module contract gains an optional `pad = fn(notes)`.

- [ ] **Step 1: Write the failing test.** Add `test("visuals <name> reacts to every part", ...)`
  to `test/unit_visuals.lua`, inside the per-theme loop. For each event in
  `{"kick","pump","hat","clap","perc","tick","stab","bass","arp","pad"}`:
  - run `run(th, "mid", {frames = 120, keep = true, at = probe})` twice.
  - The `probe` sets `VIS.strict = true` at frame 1. At frame 60, in the A
    copy only, it fires the event with fixed args:
    - `stab`, `pad`: `{50, 57, 60, 65}`
    - `bass`: `38`
    - `arp`: `2, 67, 3`
    - `perc`: `2, 62`
    - `tick`: `3`
  - Then **both** copies call `math.randomseed(60)`. That keeps the groove's
    random stream identical after the probe, even if a theme handler used
    `math.random`.
  - Assert `mean(bufdiff(A.frames[i], B.frames[i]) for i = 60..72) > 0.003`.
    The failure message names the theme and the event.
- [ ] **Step 2: Extend the band test.** Add `out_mid` 0 vs 1 and `out_amp`
  0 vs 1 to the existing "reacts to out_hi and out_lo" test, each asserted
  `> 0.01`, and rename it "reacts to every band".
- [ ] **Step 3: Extend the garbage-events test.** In "new drum events and
  garbage never throw", also fire `pad` with `{}`, `{60}`, `{0/0, 50}`,
  `"x"` and `nil`.
- [ ] **Step 4: Run the tests and confirm they fail.**
  - Run `lua test/unit.lua test/unit_visuals.lua 2>&1 | grep -c "reacts to every part"`.
  - Expected: FAIL lines for most themes. Clap, perc and tick should fail
    on all 16, which proves the test measures something. Save the FAIL
    list into the commit message.
- [ ] **Step 5: Implement the kit changes.**
  - `env.pad` and `ENV_TAU.pad = 0.6`.
  - `VIS.event("pad", notes)`: set `env.pad = 1`, then call
    `call(cur, "pad", sanitized_copy)`.
  - In the clap/perc/tick fallback branch, skip the `hat` fallback when
    `VIS.strict` is set.
  - `VIS.init()` resets `VIS.strict = false`.
- [ ] **Step 6: Run the tests.** Run
  `lua test/unit.lua test/unit_visuals.lua | grep -E "FAIL|tests" | grep -v "reacts to every part"`.
  Expected: no other FAIL lines (only the new test fails). The
  garbage-events test passes.
- [ ] **Step 7: Commit.**
  `git commit -m "visuals: pad event, strict mode, reactivity test (fails: themes to follow)"`

### Task 2: The script sends `pad`

**Files:**
- Modify: `gradient.lua`. Wherever `engine.wash_chord(...)` is called, also
  call `VIS.event("pad", notes)` with the same four notes as MIDI numbers.
  If the call site has Hz, keep the MIDI values it was built from.
- Test: `test/sim.lua`.

**Interfaces:**
- Consumes: `VIS.event("pad", notes)` from Task 1.

- [ ] **Step 1: Write the failing test.** In `test/sim.lua`, count the
  `VIS.event` calls by kind (wrap the stub). Assert that `pad` fires at
  least once per 8 bars while the wash is up, and exactly as often as
  `engine.wash_chord`.
- [ ] **Step 2: Run the test to verify it fails.** Run `lua test/sim.lua`.
  Expected: the assertion fails with 0 pad events.
- [ ] **Step 3: Implement the change** in `gradient.lua`.
- [ ] **Step 4: Run the test to verify it passes.** Run `lua test/sim.lua`.
  Expected: `OK`.
- [ ] **Step 5: Commit.** `git commit -m "script: tell the visuals about pad chords"`

### Tasks 3–6: Full reactivity for the existing 16 themes

There are four tasks, one per group of four theme files. Each task touches
only its own four files, so the tasks can run in parallel.

| task | themes |
|---|---|
| 3 | gradient, voices, lanes, phase |
| 4 | echo, fall, pump, arc |
| 5 | motorway, tape, stack, blocks |
| 6 | beams, window, pylons, dubplate |

**Files:** `lib/vis/<theme>.lua` for each of the four themes.

**Interfaces:**
- Consumes:
  - Task 1's `pad = fn(notes)` handler and `K.env.pad`.
  - The existing handlers `kick()`, `pump()`, `hat()`, `clap()`,
    `perc(voice, note)`, `tick(kind)`, `stab(notes)`, `bass(note)` and
    `arp(lane, note, step)`.
  - `K.env.<part>` and `K.A[K.AMP|LO|MID|HI]`.

For each theme:

- [ ] **Step 1: Find the gaps.** Run
  `VISONLY=<theme> lua test/unit.lua test/unit_visuals.lua | grep FAIL`
  and note which parts and bands fail.
- [ ] **Step 2: Add a reaction for each missing part.** Each reaction must
  belong to the scene, either as a handler or by reading `K.env.<part>`.
  Keep the existing drawing, and add a new element only where the scene
  has nothing that could answer that part. A generic overlay flash doesn't
  count. Suggested roles:
  - clap: a short swell on a mid-bright element
  - perc: something small and placed, tied to its voice and note
  - tick: a single dim pixel-scale glint
  - pad: a slow change to the haze or the sky
  - MID: texture or haze density
  - AMP: overall presence
- [ ] **Step 3: Run the tests and confirm the theme passes every one.** Run
  `VISONLY=<theme> lua test/unit.lua test/unit_visuals.lua | grep -E "FAIL|tests"`.
  Expected: `N tests, 0 failed`. The reactivity, band, bounds, pulse,
  silence, glitch and budget tests all pass.
- [ ] **Step 4: Check by eye.** Run
  `lua test/contact.lua /private/tmp/<theme>.pgm`, convert it to PNG
  (`sips -s format png`), and read it. The theme should look like itself,
  with no new clutter.
- [ ] **Step 5: Commit.** Commit once per task:
  `git commit -m "visuals: <themes> answer every part and band"`

### Task 7: Engine voices

**Files:**
- Modify: `lib/Engine_Gradient.sc`:
  - New SynthDefs: `grad_bass_reese`, `grad_bass_rubber`,
    `grad_chord_felt`, `grad_chord_organ`, `grad_chord_glass`,
    `grad_chord_rhodes`, `grad_hat_metal`, `grad_hat_dust`,
    `grad_arp_glass`, `grad_arp_reed`, `grad_arp_kalimba`,
    `grad_arp_marimba`, `grad_pad_choir`, `grad_pad_strings`,
    `grad_pad_drone`.
  - Each new SynthDef takes the same args as the def it sits beside.
  - The `bass`, `bass_glide`, `chord` and `hat` commands pick their def
    through `st`, and `arp` gets a longer list.
  - New `pad_type` command.
  - `st` defaults: `bass_type 1`, `chord_type 1`, `hat_type 1`.
- Modify: `test/sc/sound.scd` to play every new def once.
- Create: `test/sc/levels.scd` (the level check) and `test/sc/pad_swap.scd`
  (rapid pad swaps).

**Interfaces:**
- Produces, for Task 8:
  - `engine.tweak("bass_type", n)`, n = 1 sub, 2 reese, 3 rubber.
  - `engine.tweak("chord_type", n)`, n = 1 dub, 2 felt, 3 organ,
    4 glass, 5 rhodes.
  - `engine.tweak("hat_type", n)`, n = 1 noise, 2 metal, 3 dust.
  - `engine.arp(..., voice)`, voice = 1 classic, 2 bell, 3 pluck,
    4 soft, 5 glass, 6 reed, 7 kalimba, 8 marimba.
  - `engine.pad_type(n)` (format `"f"`), n = 1 wash, 2 choir, 3 strings,
    4 drone.
  - The type lists are 1-based and use `clipAt(n - 1)`, like `kick_type`.

- [ ] **Step 1: Write the failing tests.**
  - `test/sc/levels.scd` spawns each part's types with identical args
    (`bass`: 55 Hz, amp 0.8, dur 0.5; `chord`: a fixed 4-note chord;
    `hat`; `arp` voices 1–8). For each type it measures the peak with
    `~seg`, then prints `LEVEL <part> <type> <dB vs type 1>` and
    `LEVEL FAIL` when outside ±4 dB.
  - For the pad, it switches `pad_type` to each value, waits 8 s, and
    measures the peak over 2 s.
  - It also swaps `bass_type` while a 2-s bass note is held. The held
    note's peak must be unchanged, within 1 dB.
  - `test/sc/pad_swap.scd` sends `pad_type` 10 times in 1 s, waits 9 s,
    then counts `grad_wash` and `grad_pad_*` nodes with
    `s.queryAllNodes`-style introspection (`Group.queryTree` or tracking
    in `~eng`). It prints `PADS <n>`, and `PAD FAIL` unless n == 1.
- [ ] **Step 2: Run the tests and confirm they fail.** Run
  `sh test/sc/run.sh test/sc/levels.scd`.
  Expected: errors for the undefined `pad_type` command and the defs.
- [ ] **Step 3: Write the SynthDefs and plumbing.**
  - The four arp defs share the arp arg list.
  - The pad defs share `grad_wash`'s args and its `Lag.kr(amp, 6)`.
  - `pad_type` follows `verb_type`:
    - new node `Synth(def, args ++ remembered fxVals[\wash] with amp=0)`
      added after the old one in `voiceGroup`;
    - then set it to the remembered amp, so it lags in;
    - set the old node's amp to 0 and free it after 7 s;
    - update `fx[\wash]` and `washSynth`.
  - If a swap arrives while one is fading, free the oldest fading node
    straight away, so at most two pad nodes ever coexist.
  - `wash_chord` keeps addressing `washSynth`. The new node is
    created with the last chord, so remember the last `f1..f4`.
  - The crossfade takes about 6 s, which matches the wash's existing amp
    lag. That's my call; the spec said about 2 s.
- [ ] **Step 4: Run the tests and confirm they pass.**
  - `sh test/sc/run.sh test/sc/levels.scd`: no `LEVEL FAIL` and no
    `ERROR`.
  - `sh test/sc/run.sh test/sc/pad_swap.scd`: `PADS 1`.
  - `sh test/sc/run.sh test/sc/sound.scd` and `sh test/sc/run.sh`: no
    `ERROR`.
  - `lua test/unit.lua test/unit_engine.lua`: `0 failed`.
- [ ] **Step 5: Commit.**
  `git commit -m "engine: reese/rubber bass, felt/organ/glass/rhodes stabs, metal/dust hats, four arp voices, choir/strings/drone pads"`

### Task 8: Params and auto (`lib/timbre.lua`)

**Files:**
- Create: `lib/timbre.lua`.
- Modify:
  - `gradient.lua`: `include` timbre, append to `VOICE_NAMES`, add the
    SOUND params, resolve the types in `apply_bar`, send `pad_type` on
    change, resolve the lane voice at `gradient.lua:499-501`.
  - `lib/conductor.lua`: call `TB.roll(S)` in `regen_material` and
    `TB.phrase(S)` at each phrase decision.
- Test: `test/sim.lua`.

**Interfaces:**
- Consumes: the engine interface from Task 7.
- Produces:
  - `TB.roll(S)`: sets `S.timbre = {bass=1..3, chord=1..5, hat=1..3, pad=1..4, lane={[i]=nil|5..8}}`.
  - `TB.phrase(S)`: re-picks at most one of bass, chord or hat, with
    probability 0.3. It reads `S.section`, `S.energy` and `S.kickless`.
  - `TB.resolve(S, part, param_value)`: returns the engine type. A
    `param_value` of 1 means auto and returns `S.timbre[part]`; otherwise
    it returns `param_value - 1`.
  - The dice are an LCG local to `timbre.lua`, seeded from `S.seed` (or
    the track seed) XOR `0x5eed`. Never call `math.random` in it.
  - Weights:
    - peak or energy > 0.7: bass `{1,2,2}`, hat `{2,2,1}`.
    - breakdown or kickless: chord felt ×3, hat dust ×3, pad drone or
      choir ×2.
    - otherwise: today's type at about 40% and the rest even.
  - Lane: each lane has a 0.35 chance to take a new voice, from 5..8.
    Otherwise it stays `nil`, which keeps the material's `l.voice`.

- [ ] **Step 1: Write the failing tests** in `test/sim.lua`:
  - The params `bass_type`, `chord_type`, `hat_type` and `pad_type` exist
    with these option lists:
    - `{"auto","sub","reese","rubber"}`
    - `{"auto","dub","felt","organ","glass","rhodes"}`
    - `{"auto","noise","metal","dust"}`
    - `{"auto","wash","choir","strings","drone"}`
    - Each defaults to 1.
  - `VOICE_NAMES[5] == "soft"` and `#VOICE_NAMES == 9`. That proves old
    psets still map.
  - Over a 256-bar set-mode run with everything on auto:
    - `engine.tweak("bass_type", v)` is sent with v in 1..3, and at least
      2 distinct values.
    - `engine.pad_type` is sent only when its value changes.
    - Each part changes at most once per phrase.
    - At least one `engine.arp` call has voice ≥ 5.
  - Fixed params win: with `bass_type` = 3 (reese), every bass tweak
    sends 2.
  - The same seed gives the same drum patterns as before. Compare
    `S.pat.kick` and `S.pat.clap` for seed 4218 with timbre on and with
    `TB.roll` stubbed out: they must be identical.
- [ ] **Step 2: Run the tests and confirm they fail.** Run
  `lua test/sim.lua`. Expected: a missing param, or `lib/timbre` not
  found.
- [ ] **Step 3: Implement.**
  - The tweaks in `apply_bar` are sent only when the resolved value
    changes. Keep a local cache, and reset it in `init` so the first bar
    always sends.
  - Hats send `hat_type` the same way.
  - Add `params:set_action` for each new param: it clears that part's
    cache, so a change takes effect on the next bar.
- [ ] **Step 4: Run the tests and confirm they pass.** Run `lua test/sim.lua`
  and `lua test/sim.lua 64 2`. Expected: `OK` from both.
- [ ] **Step 5: Run all tests on Lua 5.3.** Run
  `<lua5.3> test/sim.lua` and
  `<lua5.3> test/unit.lua test/unit_engine.lua test/unit_visuals.lua`.
  Build Lua 5.3 from the lua.org 5.3.6 tarball with `make macosx` if it
  isn't present. Expected: the same results as 5.4. The visual
  reactivity test may still fail for the themes in tasks not yet done.
- [ ] **Step 6: Commit.** `git commit -m "voices: SOUND params and auto picks"`

### Tasks 9–12: Eight new themes, two per task

| task | themes (in `VIS.names` order) |
|---|---|
| 9 | radar, subway |
| 10 | harbour, sodium |
| 11 | lighthouse, tramlines |
| 12 | substation, cooling |

**Files:**
- Create: `lib/vis/<name>.lua` for each theme.
- Modify:
  - `lib/visuals.lua`: append to `VIS.names`.
  - `test/unit_visuals.lua`: append to `NAMES` and update the "v1 order
    first" test to expect the appended names.
- Tasks 9–12 each append in order. Run them one after another, or have
  each append only its own names after rebasing.

**Interfaces:**
- Consumes: the kit (`K.put`, `K.line`, `K.follow`, `K.clamp`, `K.env`,
  `K.A`, `K.duck`, `K.energy`, `K.kickless`, `K.chord`, `K.T`, `K.DT`,
  `K.B`, and the rest as in `lib/visuals.lua`) and every handler in the
  contract, including `pad`.
- Produces: one module per theme with the standard shape (see the
  `lib/visuals.lua` header), defining **every** handler: kick, pump, hat,
  clap, perc, tick, stab, bass, arp, pad.

For each theme:

- [ ] **Step 1: Register the theme name.** Append it to `NAMES` in the test
  and to `VIS.names`, and create a stub file with an empty `draw`. Run
  `VISONLY=<name> lua test/unit.lua test/unit_visuals.lua`. Expected: FAIL
  (near blank, no pulse, no reactions).
- [ ] **Step 2: Draw the scene** the spec describes in its section 2 for
  this theme. The composition is yours.
- [ ] **Step 3: Run the theme's tests.** Run
  `VISONLY=<name> lua test/unit.lua test/unit_visuals.lua | grep -E "FAIL|tests"`.
  Expected: `0 failed`.
- [ ] **Step 4: Check the theme by eye.** Look at the contact sheet: it
  should read at a glance as the place it's named after, at low
  brightness.
- [ ] **Step 5: Commit.** `git commit -m "visuals: <a> and <b>"`

### Task 13: Docs, full gate, device test, ship

**Files:**
- Modify:
  - `README.md`: the new SOUND params, the eight themes, "twenty-four",
    the `pad` event in the theme notes, and the dev commands for
    `levels.scd` and `pad_swap.scd`.
  - `lib/visuals.lua` header: "sixteen" becomes "twenty-four".
  - `docs/drums-glitch-followups.md`: rename it to
    `docs/device-checks.md` and add the new voice and theme checks.

- [ ] **Step 1: Run the full local gate.** Run all of these:
  - `lua test/unit.lua test/unit_engine.lua test/unit_visuals.lua`
  - `lua test/sim.lua`
  - `lua test/sim.lua 64 2`
  - the 5.3 runs of both
  - `sh test/sc/run.sh`
  - `sh test/sc/run.sh test/sc/sound.scd`
  - `sh test/sc/run.sh test/sc/levels.scd`
  - `sh test/sc/run.sh test/sc/pad_swap.scd`
  - `sh test/sc/run.sh test/sc/glitch_after.scd`
  - `luac -p` on every Lua file

  Expected: `0 failed`, `OK`, no `ERROR`, no `LEVEL FAIL`, and `PADS 1`.
- [ ] **Step 2: Review the contact sheet.** Make the sheet of all 24 themes
  and read it.
- [ ] **Step 3: Request a whole-branch review** with
  superpowers:requesting-code-review. Fix the confirmed findings.
- [ ] **Step 4: Test on a device.** Deploy to one reachable norns:
  - rsync with `--exclude .git --exclude test --exclude .DS_Store`;
  - check linger;
  - `sudo -n reboot`.

  Then, over the websocket REPL (ports 5555 and 5556), check each of these:
  - The engine has 22 commands, including `pad_type`.
  - Step through every `bass_type`, `chord_type`, `hat_type` and
    `pad_type` and lane voice while it plays. There must be no sclang
    errors, and the level bus (`Bus(\control, 10, 4)`) must stay live.
  - Step through all 24 themes with `params:set("theme", i)`. There must
    be no "theme fell back" log.
  - Read CPU at a forced peak with the heaviest choices (reese, organ,
    metal, strings): it must be under 45%.
  - Fire every glitch mode: the level bus must stay live.
  - Finally, clear the script.
- [ ] **Step 5: Ship.**
  - Commit, merge to main, `git push origin main`.
  - rsync to every norns that's on the network, with an md5 check.
  - `sudo -n reboot` each one (linger is on).
- [ ] **Step 6: Update memory.** Update the gradient project memory: the
  new commit, which norns got it, and the device results.
