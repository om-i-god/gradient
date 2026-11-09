# Time signatures: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 3/4, 5/4 and 7/4 alongside 4/4, with a user-chosen feel (even,
or one of two groupings), without changing anything in 4/4.

**Architecture:**
- A new pure module, `lib/meter.lua`, owns the maths: groups, bar length,
  kick beats, and template mapping.
- `S.meter` holds the live meter. Pending changes apply at the phrase
  boundary.
- The generators in `lib/gen.lua` take a bar descriptor.
- `play_step` and the visuals read the bar length from `S` instead of 16.

**Tech stack:** Lua 5.3 (norns). Tests run on Lua 5.4 and 5.3.

**Spec:** `docs/superpowers/specs/2026-11-08-time-signatures-design.md`

## Global constraints

- Add, never replace:
  - 4/4 with even feel is identical to today: sound, patterns for each seed,
    visuals and timing.
  - In 4/4 even, no extra `math.random` calls.
- Existing param IDs and option indices don't change. `meter` and `feel` are
  new params.
- The beat stays a beat: tempo, `clock.sync(1/4)`, MIDI clock and crow clock
  are unchanged.
- A meter or feel change takes effect at the next phrase boundary while
  playing (immediately when stopped). It never drops or doubles a bar.
- Load the script's own lib files with `include("lib/<name>")`.
- Never put device names or IPs in the repo.
- The visual bounds in `test/unit_visuals.lua` hold in every meter.

## Review focus

1. **A meter change pressed several times within one phrase.** Only the last
   value applies, once, at the boundary. Pinned in M1.
2. **A feel change while the meter is 4/4 even, then back.** No pattern
   change occurs in 4/4 even. Pinned in M2 (snapshot).
3. **Stopping, changing the meter, then starting.** The new meter applies
   immediately, and the first bar is complete. Pinned in M1.
4. **Kickless sections in A/B feel.** No beat ghosts sound. Pinned in M3.
5. **Visual bar phase in 7/4.** It reaches about 1 at step 28, not 16, and
   never exceeds 1. Pinned in M4.

---

### Task M1: `lib/meter.lua`, the params, and the bar step

**Files:**
- Create: `lib/meter.lua`.
- Modify: `gradient.lua`:
  - the params next to `phrase_len`;
  - `play_step`: `s = (S.step % 16) + 1` becomes the bar step;
  - `S` init.
- Modify: `lib/conductor.lua`: apply a pending meter at the phrase boundary.
- Test: `test/sim.lua`, and a new `test/unit_meter.lua`.

**Interfaces (produces):**
- `MT.METERS = {4, 3, 5, 7}`: beats, in the param's option order.
- `MT.FEELS = {"even", "short-long", "long-short"}`.
- `MT.groups(beats, feel)` returns the group lengths in beats:
  - even: `{1, 1, ...}` (one group per beat);
  - 4/4 A: `{2,2}`; 4/4 B: `{3,1}`;
  - 3/4 A: `{2,1}`; 3/4 B: `{1,2}`;
  - 5/4 A: `{3,2}`; 5/4 B: `{2,3}`;
  - 7/4 A: `{4,3}`; 7/4 B: `{3,4}`.
- `MT.label(beats, feel)` returns e.g. `"5/4 3+2"`, or `"5/4"` for even.
- `MT.bar(beats, feel)` returns
  `{beats=, n=beats*4, groups=, starts={[beat]=true}, last=n}`.
  `starts` holds the group-start beats; in even feel every beat is a start.
- `MT.map16(tpl, bar)` maps a 16-entry table to `bar.n` entries, beat by beat:
  - the first beat comes from template beat 1;
  - the last beat comes from template beat 4;
  - the middle beats cycle through template beats 2 and 3.

  For 4/4 it returns an equal copy.
- `S.bar` is the live descriptor, and `S.bar_step` runs 1..`S.bar.n`.
- `S.meter_pending = {beats, feel} | nil`.

**Params** (the `formatter` shows the grouping):
- `params:add_option("meter", "time signature", {"4/4","3/4","5/4","7/4"}, 1)`
- `params:add_option("feel", "feel", MT.FEELS, 1)`, with a formatter that
  shows `MT.label`'s grouping.

**Steps:**

- [ ] **Step 1: Write the failing unit tests.** In `test/unit_meter.lua`:
  - `groups` for all 4 × 3 cases match the table above.
  - `bar(5,"even").n == 20`.
  - `bar(7,"short-long").starts` is `{1,5}`.
  - `map16` of a 16-entry 1..16 table, for 5 beats, gives
    `{1,2,3,4, 5,6,7,8, 9,10,11,12, 5,6,7,8, 13,14,15,16}`.
  - `map16` for 3 beats gives `{1..8, 13..16}`.
  - `map16` for 4 beats is identity.
  - `label(5,"long-short") == "5/4 2+3"` and `label(4,"even") == "4/4"`.
- [ ] **Step 2: Write the failing sim tests.** In `test/sim.lua`:
  - For each meter × feel, run 64 bars with no error. Each bar has exactly
    `beats*4` calls to `play_step`, counted by bar boundaries.
  - Set the meter 3 times mid-phrase. It changes exactly once, at the next
    phrase boundary, to the last value.
  - Stopped: set the meter, then start. The first bar has the new length.
- [ ] **Step 3: Run the tests and confirm they fail.** Run
  `lua test/unit.lua test/unit_meter.lua` and `lua test/sim.lua`.
- [ ] **Step 4: Implement.**
  - `play_step` derives `s` from `S.bar_step`, which wraps at `S.bar.n`.
  - The bar-start logic runs when `s == 1`.
  - `S.step` keeps counting 16ths, because the visuals and other code use it
    as a clock.
- [ ] **Step 5: Run the tests and confirm they pass.** Run
  `lua test/unit.lua test/unit_meter.lua`, `lua test/sim.lua` and
  `lua test/sim.lua 64 2`.
- [ ] **Step 6: Commit.** `git commit -m "meter: params, bar descriptor, bar step"`

### Task M2: Generators at the bar length

**Files:**
- Modify: `lib/gen.lua`. Every generator that loops `1, 16` or uses fixed
  16-step tables takes `bar`, with a default of the 4/4 even bar.
- Modify: `lib/conductor.lua`:
  - `regen_material` passes `S.bar`;
  - new `C.remeter(S)` regenerates only the bar-length patterns from a
    sub-stream.
- Test: `test/sim.lua`, `test/unit_meter.lua`.

**Interfaces:**
- Consumes: M1's `MT.bar` and `MT.map16`.
- Produces:
  - `C.remeter(S)`. It reseeds `math.randomseed(S.seed * 31 + S.bar.beats * 7 + feel_index)`.
  - It then regenerates kick, ghosts, clap, hats, shaker, rim, toms, ride,
    ticks, bass and stabs (whichever `S.pat` keys exist), and leaves lanes,
    perc, harmony and the rest alone.
  - It is called by the phrase-boundary meter apply.

**Rules for the generators:**
- **Euclid patterns** are built directly at `bar.n`.
- **Fixed templates** (claps, toms, bass lines, ghosts) go through
  `MT.map16`.
- **Kick:** on every beat for even, and on group starts otherwise.
- **Clap:**
  - in even feel, today's patterns, mapped;
  - in A/B, on the last beat of each group longer than 1 beat;
  - in 3/4 even, on beat 2.
- **Zero extra `math.random` calls when the bar is 4/4 even.** Branch on the
  bar *after* the draws that exist today, or skip the new draws entirely.

**Steps:**

- [ ] **Step 1: Snapshot today's patterns.** Before touching `gen.lua`, add a
  test that runs `C.new_track` for seeds 4218, 7 and 99 and serialises
  `S.pat` (kick, ghost, clap, hats, shaker, rim, toms, ride, ticks, bass,
  perc). Write the strings into `test/fixtures/patterns_44.lua`, generated
  once from the current code and committed. The test asserts equality.
  Run it; it passes, which proves the snapshot was taken correctly.
- [ ] **Step 2: Write the failing tests.**
  - For 5/4 and 7/4 in each feel, every `S.pat` step table has `bar.n`
    entries.
  - The kick has hits exactly on the beats the feel says.
  - `C.remeter` leaves `S.pat` lanes and perc identical.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests.** Expected:
  - the snapshot test still passes;
  - the new tests pass;
  - `lua test/sim.lua` prints OK;
  - the Lua 5.3 run matches.
- [ ] **Step 5: Commit.** `git commit -m "meter: generators build for the bar length; 4/4 unchanged"`

### Task M3: Bar-relative logic in `play_step`, beat ghosts, the HUD

**Files:**
- Modify: `gradient.lua`:
  - the fill and glitch-fill positions (`s == 13/14/15/16`);
  - `bar_f`;
  - the bass turnaround;
  - the drop-bar counts that use 16 as a bar count stay in bars;
  - beat ghosts;
  - the HUD.
- Test: `test/sim.lua`.

**Interfaces:**
- Consumes: `S.bar` (M1) and `S.pat.*` at `bar.n` (M2).

**Rules:**
- **Fill and glitch positions** convert from "steps before the end": step
  13 of 16 becomes `bar.n - 3`, and 16 becomes `bar.n`. Bar 1 logic is
  unchanged.
- **Beat ghosts:** in A/B feel, every beat that doesn't start a group plays
  the kick at about 0.35 × the kick velocity, with half decay.
  - They are gated by `on_kick`, `not kickless`, mute and solo, the same as
    the main kick.
  - They ignore `on_ghost`.
- **`bar_f`** = `S.track_bar + (s - 1) / bar.n`.
- **HUD:** shows `MT.label` next to the section when the meter isn't 4/4 even.

**Steps:**

- [ ] **Step 1: Write the failing sim tests.** For 5/4 A over 64 bars:
  - The kick command fires at group starts at full velocity, and at
    non-starts at about 0.35 × velocity, whenever the kick is on.
  - In kickless bars, no kick or ghost fires.
  - Glitch fills fire on step `bar.n - 3` or later.
- [ ] **Step 2: Run the tests and confirm they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests.** Expected: `lua test/sim.lua` and
  `lua test/sim.lua 64 2` print OK, and the 4/4 snapshot test still passes.
- [ ] **Step 5: Commit.** `git commit -m "meter: fills, ghosts and HUD follow the bar"`

### Task M4: Visuals follow the meter

**Files:**
- Modify: `lib/visuals.lua` (`physics`): `beat_ph` and `bar_ph` use
  `S.bar.n`, falling back to 16 when `S.bar` is absent. Add `K.beats`
  (default 4).
- Modify: the themes that hard-code 4 beats in a bar (grep for `/ 4`,
  `% 4` and `4 beats` against `bar_ph`). Those use `K.beats`.
- Test: `test/unit_visuals.lua`.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - Add a `meter5` scenario: the mid scenario with `S.bar = {beats=5, n=20, ...}`
    and a groove of 20 steps per bar. Every theme must pass the existing
    bounds in it.
  - A kit test: in 7/4, `bar_ph` stays in [0,1) and reaches ≥ 0.95 at step 27.
- [ ] **Step 2: Run the tests and confirm they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests.** Run the full
  `lua test/unit.lua test/unit_visuals.lua test/unit_meter.lua`.
  Expected: 0 failed.
- [ ] **Step 5: Commit.** `git commit -m "meter: visuals follow the bar"`

### Device checks

The voices plan's Task 13 covers the device checks. Add these to its
on-device list:
- play 5/4 in each feel, and 7/4 even;
- change the meter while playing, and confirm it switches on the phrase;
- check that the visuals pulse on the beat;
- add `meter` and `feel` to the README.
