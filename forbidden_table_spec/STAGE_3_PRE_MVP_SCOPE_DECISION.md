# Stage 3 Pre-MVP Scope Decision

**Date:** 2026-09-26

**Status:** Scope in force; Stage 3 Alpha Exit passed and Stage 4 authorized 2026-09-26

## Decision

The project maintainer has prioritized getting playable content onto the table.
Continue Stage 3 and MVP work without native PC or Steam Deck simulation,
frame-time capture, or command-feedback latency testing. Native-device evidence
is waived for the initial MVP scope; do not collect it or treat it as a release
prerequisite unless the maintainer reopens that scope.

Do not conduct participant playtesting before the first actual MVP release.
The invited-player study may be considered after release, with maintainer
participation, as a post-release activity. It is not a prerequisite for the
initial MVP release, Stage 3 Alpha Exit, or entry into Stage 4.

Keep seeded headless simulation, deterministic replay checks, content
validation, save/replay regressions, and other code-level correctness checks
in the implementation workflow, including the approved 1,000-run full-roster
Scale corpus. A coarse fixed headless benchmark may be recorded as process
timing context, but its five-run precision and 20% comparison are not pre-MVP
acceptance blockers. Existing WSL2 process timings do not count as
native-device results.

## Gate interpretation

This is an explicit maintainer-approved exception to the original native-device
Hardening requirement and invited-study Alpha Exit requirement for the initial
MVP. The device criterion is waived, not passed or measured. Human study results
do not exist before release and are not required to pass Alpha Exit or enter
Stage 4. Do not describe either absent result as a pass.

Stage 3 Alpha Exit still requires the approved content totals, two-Act loop,
automated correctness/replay and compatibility evidence, no unresolved P0/P1,
and an explicit maintainer decision. The missing device and pre-release human
evidence do not block that review. The maintainer may schedule the invited study
after the first actual MVP release.

## Gate disposition — 2026-09-26

- Issue [#57](https://github.com/sunnyday9/Forbidden-Table/issues/57#issuecomment-5843868297)
  records Readiness and Hardening **PASS under this scope waiver**, based on the
  accepted automated simulation/replay, benchmark, compatibility/migration,
  and Act 2 reward-pool evidence. Native PC/Steam Deck measurements remain
  waived, unperformed, and not passed.
- Issue [#69](https://github.com/sunnyday9/Forbidden-Table/issues/69#issuecomment-5843875181)
  records Stage 3 Alpha Exit **PASS** and authorizes Stage 4 to begin. This is
  a gate decision; no MVP release or publication occurred as part of it.
- Issue #68 remains open for an optional post-release invited study. No human
  playtest has been conducted, and no human result is represented as passed.
