# Stage 3 — Alpha Implementation Plan

Status: Dependency-ordered plan published by [issue #50](https://github.com/sunnyday9/Forbidden-Table/issues/50).
Parent map: [issue #40](https://github.com/sunnyday9/Forbidden-Table/issues/40).
Specification: [STAGE_3_ALPHA_SPEC.md](STAGE_3_ALPHA_SPEC.md).

This plan is additive to the established specification hierarchy. Production
work follows the stated blockers and gates, with the dated pre-MVP scope
decision authorizing the ordered Scale content work after the recorded
Hardening simulation subgate and fixed benchmark. That exception does not mark
the full Hardening gate passed. Each implementation/review ticket is a GitHub
sub-issue of #40. The native GitHub `blocked_by` edges are canonical; the
bodies repeat them for readability.

## 1. Graph and execution order

```text
#49 + #53 → #54 → #55 → #56 ───────────────┐
                       └──────────→ #71 ────┤
#47 + #48 → #70 ────────────────→ #71 ─────┴→ #57 [Hardening gate evidence/decision]
                                                   └ pre-MVP authorization → #58 → #59 → #60 → #61 → #62 → #63 → #64 → #65 ─┐
#54 + #55 + #60 + #61 ─────────────────────────────────────────────────→ #66 ────────────────────────────────────────────────┴→ #67 ─→ #68 [post-release]
#54 + #57 + #66 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────→ #69
```

The graph’s direct dependencies are:

| Issue | Work item | Native blocked-by edges |
|---:|---|---|
| #54 | Verify Phase 2 v1 and every distributed Alpha save/replay format | #49, #53 |
| #55 | Continuous two-Act Run and Act 2 map | #49, #53, #54 |
| #56 | Seeded simulation and fixed benchmark harness | #55 |
| #70 | Resolve full-roster simulation coverage versus gate order | none; resolved by maintainer |
| #71 | Enable the Act 2 Boss reward path for pre-Hardening coverage | #49, #53, #54, #55, #70 |
| #57 | Readiness and Hardening evidence/sign-off | #49, #53, #54, #55, #56, #70, #71 |
| #58 | Scale the Act 2 encounter package under the pre-MVP scope decision | #49, #53 |
| #59 | Six Act 2 Event identities | #49, #53, #58 |
| #60 | Third Character and matching Core Technique | #49, #53, #59 |
| #61 | Contracts 4–6 | #49, #53, #60 |
| #62 | Eight Yaku additions | #49, #53, #61 |
| #63 | Eighteen Normal Relic additions | #49, #53, #62 |
| #64 | Six Run Technique additions | #49, #53, #63 |
| #65 | Three Tile Modifier additions | #49, #53, #64 |
| #66 | Minimum horizontal unlock path | #54, #55, #60, #61 |
| #67 | Full-roster interaction regression and Scale evidence | #58, #59, #60, #61, #62, #63, #64, #65, #66 |
| #68 | Private invited Alpha study and evidence report | #67 |
| #69 | Alpha Exit evidence review and maintainer decision | #54, #57, #66 |

Every content-scaling ticket (#58–#65) retains explicit native `blocked_by`
edges to Phase 2 reward prerequisites #49 and #53 and to the immediately
preceding batch. Under the 2026-09-26 pre-MVP scope decision, these content
tickets no longer depend on native-device evidence; the scope decision waives
that evidence for the initial MVP and permits #67's automated Scale
verification after #58–#66 finish. Participant testing is scheduled only after
the first MVP release and is not an Alpha Exit or Stage 4 prerequisite. Neither
waiver nor deferral is reported as a test pass. #53 remains blocked by #49 and
#52. Issue #70 records the approved gate-by-gate coverage. The narrow #71
reward-pool slice remains the only content implementation scheduled before the
Hardening simulation subgate; the Act 2 Boss identity and remaining Scale
batches follow that subgate.

## 2. Shared acceptance contract for Scale batches (#58–#65)

Every Scale issue has its own exact category delta, IDs, catalog/pool
eligibility, and targeted test cases. In addition, each issue requires:

1. Catalog/content validation reaches the exact cumulative count in the Alpha
   spec; IDs remain stable and unique.
2. The No-Core-Code Content Test adds/validates representative content through
   current definitions, registries, pools, and resolvers without changing core
   rule code solely to make the batch work.
3. Targeted interaction regressions exercise new content against the existing
   reward/run systems and at least one relevant cross-category interaction;
   rejected/illegal content must remain rejected without authoritative state or
   RNG mutation.
4. Extend the declared Partial, Complete, and Hybrid simulation/replay corpus;
   execute the approved 1,000-run workload and require matching hashes, RNG,
   events, and outcomes with zero crash, invalid-state, soft-lock, or unexplained
   replay failures. Defeat is valid; there is no win-rate quota.
5. Keep the unchanged fixed benchmark and record coarse process-level timing
   context. A five-repetition comparison and 20% regression cap are not
   pre-MVP batch acceptance blockers. Native PC/Deck frame and feedback
   measurements are waived for the initial MVP scope; WSL2 timings must not be
   described as native-device results.
6. If a build containing the batch is distributed, freeze its save/replay
   fixtures before a subsequent compatibility change. Verify applicable
   sequential migrations, stable boundaries, exact future RNG, and replay
   content-version pinning; never overwrite an earlier fixture.

If an acceptance check fails, the issue remains open and the batch does not
advance. Do not call process timing a gameplay frame-time measurement.

## 3. Ticket contracts

### #54 — Verify Phase 2 v1 and distributed Alpha save/replay compatibility

- Preserve `game.phase2.v1` / `content.slice.v1` as immutable fixture input and
  verify its explicit migration under #45; schema migration alone never changes
  `content_version`.
- Keep the archived-baseline regression for the originally supplied static
  fixture: `INVALID_RNG_STATE`, `INVALID_RUN_SEED`, `INVALID_CURRENCY` (`gold`
  and `refinement_tokens`), and `STATE_HASH_MISMATCH`. Replace that candidate
  only with an immutable, genuinely serializable fixture generated from a valid
  v1 stable checkpoint. The archived baseline must accept it with validators
  unchanged.
- Preserve a second real archived-v1 fixture for a stable `BOSS_REWARD`
  checkpoint with no `reward_draft`; archived `SaveCoordinator` maps this phase
  to stable boundary `REWARD`. Because the v2 validator requires a Boss draft,
  the explicit v1→v2 content migration must synthesize the approved three-choice
  Boss Rule Breaker draft from the saved Reward RNG, increment
  `reward_draft_sequence`, and recalculate the migrated checkpoint hash and
  persisted RNG state. Verify exact choices/IDs and future RNG, and prove the
  source fixture is unchanged. Keep this content migration distinct from
  sequential schema migration.
- Make wide RNG integers lossless across the JSON wire representation and
  migration. Tests must verify integer type/value round-trip, load acceptance,
  restored stream states, and exact future RNG outputs; do not weaken
  validators or hash checks to make the fixture pass.
- Maintain a version matrix for each player-distributed Alpha suspend/meta
  snapshot and replay. Add immutable pre-migration fixtures before format
  changes and verify sequential migration, stable-boundary validity, hashes,
  and exact future RNG for every stream.
- Old replays retain their original content/rules version; verify against that
  exact bundle or report reproduction unavailable without altering the record.
- Reject unsupported saves without overwriting the input. Verify game/engine
  version validation and the single-continuation-save contract.
- Tests cover successful migration, unsupported versions, replay pinning, and
  no-mutation rejection. Do not change the existing Phase 2 normative spec.

### #55 — Implement the continuous two-Act Run and Act 2 map

- Extend existing Run/map state and Commands; after the Act 1 Boss reward is
  selected and applied, create a fresh deterministic Act 2 map in the same Run.
- Carry the state enumerated in Stage 3 spec §3; dispose of battle/Act-scoped
  state and do not cross a pending reward or node interaction.
- Use the 10-node planning shape and Phase 2 reachability/branch/encounter
  invariants. Act 2 Boss reward is applied before the Normal Ending/Summary.
- Tests cover exact boundary state, pending reward, both Boss outcomes,
  deterministic map/replay, stable save/resume at the boundary, and no optional
  Act 3. No new Act-wide mechanic or parallel Run system.

### #56 — Add deterministic Alpha simulation and fixed-run benchmark harness

- Provide reproducible seed/policy manifests, complete two-Act attempt records,
  checkpoint/hash/RNG/event/outcome capture, strategy classification, and
  repeated seed/policy replay comparison.
- Parameterize the runner by gate: Readiness/Hardening use the then-implemented
  2-Character/3-Contract baseline; Scale and Exit use the complete 3-Character/
  6-Contract Alpha roster. Cover both Acts/Boss boundaries and every available
  reward path; after #71, the Act 2 three-choice Boss pool is available at the
  first two gates. Report any other not-yet-introduced content explicitly.
- Add the unchanged headless complete-Run benchmark with seed, accepted-command
  count, checkpoints, outcome, and process timing/RSS context. Five repetitions
  and a 20% comparison are deferred as pre-MVP acceptance criteria.
- Native PC and Steam Deck-class frame/feedback measurements are waived for
  the initial MVP scope. WSL2 timings remain process-only context; no device
  result is claimed. Do not collect this evidence unless the maintainer reopens
  the scope.
- Tests cover deterministic manifest/output, failure classification, valid
  Defeat outcomes, and reproducible benchmark metadata; this ticket creates no
  Alpha content.

### #57 — Record Readiness and Hardening gate evidence

- Verify both #49 and #53 are closed with their required Phase 2 regression,
  save/replay, and #39 exit evidence before Readiness passes.
- Verify #71 is complete and its Act 2-specific Boss pool produces exactly
  three unique legal choices after an Act 1 Rule Breaker has been acquired.
- Readiness exit: candidate full two-Act loop, required core capabilities,
  valid content IDs/pools, No-Core-Code check, and Phase 2 regression.
- Hardening simulation subgate: fixed workloads/fixtures; 1,000 runs across
  the then-available 2-Character/3-Contract roster and implemented Act/Boss/
  reward paths; replay invariants; and migration evidence. Do not call this
  full-roster coverage. Report crashes, invalid state, soft-locks, replay
  divergence, and process timing separately.
- Native PC/Deck measurements are waived for the initial MVP scope and are not
  required for the Stage 3 Hardening decision. Record this criterion as waived,
  not passed or measured. The simulation subgate and fixed benchmark are
  recorded; the maintainer makes the explicit gate decision.
- Scale/Exit simulation coverage still requires the full Alpha roster after
  the content batches complete. The full-roster 1,000-run correctness evidence
  is not deferred or waived.

### #58 — Scale the Act 2 encounter package under the pre-MVP scope decision

- Add four Act 2 Normal enemies, one Act 2 Elite, and one Act 2 multi-phase
  Boss, reaching cumulative totals of 8 Normal enemies, 2 Elites, and 2 Bosses.
- Reuse the Act 2-specific three-choice Rule Breaker pool implemented by #71;
  do not add or move its definitions in this Scale ticket. Each Boss presents
  its own three required choices, and the selected Act 1 reward/build continues
  through the transition.
- Tests cover encounter factory/catalog validation, intent/phase behavior,
  eligible reward choices and selection, and interactions with existing
  Character/Contract/Relic/Technique systems through current extension points.
- Apply the shared Scale acceptance contract in §2. The dated pre-MVP scope
  decision authorizes this batch after the recorded Hardening simulation
  subgate and fixed benchmark; native-device measurements are waived for the
  initial MVP scope.

### #71 — Enable the Act 2 Boss reward path for pre-Hardening coverage

- Add exactly three stable, distinct Act 2 Boss Rule Breaker definitions and
  their Act 2-specific reward pool through the existing typed content and
  reward-selection seams. The three definitions count toward the Alpha total
  of six; the Phase 2 Act 1 pool and contract remain unchanged.
- After an Act 1 Rule Breaker has been selected, the Act 2 Boss draft still
  contains exactly three unique eligible Act 2 choices. Tests cover pool/ID
  validation, deterministic draft creation, selection/application, and
  stable-boundary save/replay through existing Phase 2 behavior.
- Do not add a new Act-wide mechanic, Act 2 Boss identity/encounter package,
  Normal enemies, Elite, or unrelated Scale content. This is the sole
  pre-Hardening content-order exception required by #57.

### #59 — Add six Act 2 Event identities

- Add one identity from each of the six existing Event families, reaching 12
  total Events and six per Act; do not create a new Event family/system.
- Tests cover deterministic payload selection, each option’s typed state change,
  invalid/stale choice no-mutation behavior, save/replay at stable Event
  boundaries, and interaction with the two-Act map/economy.
- Apply the shared Scale acceptance contract in §2.

### #60 — Add Character 3 and Core Technique 3

- Add exactly one Character and its matching Character-bound Core Technique;
  reach 3 Characters and 3 Core Techniques. Equality with those 1.0 budgets is
  the approved #46 exception, not an expansion to other categories.
- A Character's signature passive must be a typed, encounter-resolved effect,
  not an ID-only catalog entry. Harbor Read triggers on that Character's first
  Complete Hand in each encounter and grants 1 TP; the encounter checkpoint
  records its once-per-encounter use.
- Tests verify stable IDs, registry/selection eligibility, ownership/binding,
  authoritative profile-backed unlock enforcement, passive effect and
  once-per-encounter behavior, deterministic replay, and interactions with the
  current Run/reward path.
- Apply the shared Scale acceptance contract in §2.

### Stage 3 review follow-up — Run startup, summary, and evidence scope

- Run-start commands are validated against the injected trusted meta-profile
  unlock state. The Run Scene filters its choices for presentation and submits
  commands; it does not reconstruct the RunDomain or starting Tile Pool.
- A rejected or unsupported meta-profile is preserved byte-for-byte and
  progression writes stay disabled until the player explicitly resets that
  profile. The Run Scene shows the recovery state and reset action.
- The terminal Run Summary renders the tracked Build Story fields in
  `PROJECT_SPEC.md` §21. Duration is shown only when the Run has a tracked start
  time; older saves without one say that duration is not tracked.
- Device-evidence capture controls are absent from the pre-MVP Run Scene. The
  waived native-device and pre-release human evidence remains unmeasured and is
  not a Stage 4 prerequisite; see `../STAGE3_DEVICE_EVIDENCE.md`.

### #61 — Expand Contracts to 6

- Add Contracts 4–6 (three definitions) to reach six cumulative Contracts;
  keep Contracts selected at Run start and preserve the accepted Alpha roster
  unlock path.
- Tests cover IDs, registry/selectability, each contract’s defining constraint
  and reward/economy interactions, and invalid selection without state/RNG
  mutation.
- Each authored risk/reward field for Contracts 4–6 must resolve to an
  observable gameplay outcome or player-facing gameplay signal. Non-empty
  metadata and build bias alone do not satisfy this acceptance check; preserve
  the accepted Phase 2 three-Contract behavior.
- Define and test the exact effects recorded in §2 of
  `STAGE_3_ALPHA_SPEC.md`: Quiet Current changes battle-start Pressure/TP and
  pays a Refinement Token on Elite Skip; Open Ledger narrows normal tile
  rewards to Characters and signals Sequence; Brittle Compass adjusts Elite
  Skip/Workshop costs, grants its starting token, and adds a distinct Modified
  Tile reward choice when the candidate pool permits it.
- Show the three new Contracts' names, risk/reward summaries, build bias, and
  Yaku signal in Contract choice details. Scope the new fields to the Alpha
  definitions so Phase 2 contract behavior and default costs remain unchanged.
- Apply the shared Scale acceptance contract in §2.

### #62 — Expand Yaku to 18

- Add eight stable Yaku definitions to the ten Phase 2 Yaku; keep the pool
  shared across both Acts and preserve existing scoring/Complete Hand laws.
- Tests cover each new activation/progress/payoff contract and interactions
  with Partial, Complete, and Hybrid paths without bespoke resolver logic.
- Apply the shared Scale acceptance contract in §2.

### #63 — Expand Normal Relics to 36

- Add 18 stable Normal Relic definitions to the existing 18; introduce the new
  set in Act 2 while keeping acquired Relics for the rest of the Run.
- Tests cover pool legality, effect validation/lifetimes, representative
  interactions with Yaku/Techniques/Modifiers/rewards, and run carryover.
- Apply the shared Scale acceptance contract in §2.

### #64 — Expand Run Techniques to 14

- Add six stable Run Techniques to the existing eight and reach 14 total in a
  shared run-wide pool; retain existing slot, typed Command, and TP rules.
- Tests cover legality/usage type, costs and effects, deterministic outcomes,
  and representative interactions with new/old Relics, Yaku, and encounters.
- Apply the shared Scale acceptance contract in §2.

### #65 — Expand Tile Modifiers to 8

- Add three stable Tile Modifier definitions to the existing five and reach
  eight total through the current Workshop/content model.
- Tests cover application, persistence, target validation, removal/transform
  interactions, and representative interactions with Patterns/Yaku and Run
  rewards.
- Apply the shared Scale acceptance contract in §2.

### #66 — Implement the minimum horizontal unlock path

- Use the existing `MetaProgressSnapshot` seam and separate discovered,
  unlocked, and progress state; no new currency, stat inflation, or full
  progression economy.
- Default profile starts with 2 Characters/3 Contracts. The first Act 2 Normal
  Ending unlocks Character 3 and Contracts 4–6 for later Runs only.
- Test exact milestone, restart persistence, schema migration, all-unlocked
  test profile, unchanged completed Run, and no other Alpha meta locks.
- Depends on the two-Act Run/save compatibility and the third Character and
  Contracts batches; it is before Exit but is not a Readiness/Hardening/Scale
  prerequisite.

### #67 — Verify full Alpha interactions and Scale evidence

- Run the complete catalog/pool validator and the No-Core-Code test against
  representative examples from every expanded category.
- Run targeted cross-category interaction coverage across both Acts, both Boss
  rewards, Events, Shop/Workshop, migrations, and all three Run strategies.
- Execute the approved full-roster 1,000-run seed/replay corpus and require the
  zero-failure correctness criteria. Record coarse headless process timing as
  context without a pre-MVP five-run/20% gate. Native PC/Deck/feedback evidence
  is waived for the initial MVP scope. Human evidence is post-release follow-up;
  report neither as completed or passed.
- Verify fixture coverage for every distributed version and the minimum unlock
  flow. Required automated evidence must be complete; record the device
  criterion as waived and the invited study as post-release follow-up. Neither
  is a prerequisite or a passed test.
- No new content or production core system in this integration ticket.
- This ticket has direct native `blocked_by` edges to #58–#66. The device waiver
  and post-release study decision do not change the automated Scale evidence.

### #68 — Run the private invited Alpha study and publish evidence

- Do not recruit participants or run this study before the first actual MVP
  release. After release, the maintainer may choose to run this private study
  with 12 invited participants (8 Mahjong-new/minimal, 4 familiar). The study
  is a post-release follow-up and is not a release, Alpha Exit, or Stage 4 gate.
- Follow the no-coaching two-Act session protocol and required observation
  points in Stage 3 spec §7, including a stable-boundary Suspend/Resume.
- Publish anonymized evidence, threshold results, P0/P1/P2 triage and
  dispositions. Do not claim a miss as a pass or generalize the cohort.
- This is human work; no playtest is run by publishing this issue.

### #69 — Review and record the Stage 3 Alpha Exit decision

- Confirm all approved cumulative counts and both Acts are present; all 1.0
  core-system capabilities exist; Readiness/Hardening/Scale evidence passes;
  compatibility fixtures and migration/replay contracts pass.
- Verify no unresolved P0/P1 and the exact minimum unlock behavior. Record the
  native-device criterion as waived for the initial MVP scope and #68 as a
  post-release follow-up; neither blocks Alpha Exit. Do not claim either absent
  result as passed.
- The maintainer records explicit pass/fail, evidence links, and follow-up
  issues. A failed criterion remains visible and does not advance the milestone.
- Human maintainer sign-off is required; no release/publication action is
  included.

### #70 — Resolved #47/#48 simulation-coverage and gate-order decision

- Keep the Readiness → Hardening → Scale → Exit order and 1,000 complete
  two-Act runs at each gate.
- Readiness and Hardening cover the current baseline roster (2 Characters,
  3 Contracts), both available Act/Boss boundaries, and every implemented
  reward path. Scale and Exit cover all Alpha content, 3 Characters, 6
  Contracts, both Acts/Bosses, and every applicable reward path.
- This maintainer-approved gate-specific coverage explicitly revises #47’s
  full-roster-at-every-gate wording, preserves #48, and does not change Phase 2.
  Issue #70 records the decision and unblocks #57; no implementation is part
  of #70.

The subsequent maintainer-approved sequencing refinement in #71 moves only
the Act 2-specific three-choice Boss reward pool ahead of #57 so the already
required Act 2 Boss boundary is coverable before the Hardening simulation
subgate. The pre-MVP scope decision separately authorizes the ordered Scale
batches after that subgate and the fixed benchmark. Native-device evidence is
waived for the initial MVP scope; the maintainer records the gate decision
without claiming a device measurement.

## Pre-MVP Scale verification update — 2026-09-26

The ordered Scale content batches and minimum unlock path have been implemented
and validated with the full Godot suite. The seeded Scale subgate completed
1,000/1,000 manifest attempts and 1,000/1,000 deterministic repeats with no
attempt failures, replay divergences, or coverage gaps. The exact manifest
roster, report hash, command, aggregate, and validation limits are recorded in
[`STAGE_3_SCALE_EVIDENCE_2026-09-26.md`](STAGE_3_SCALE_EVIDENCE_2026-09-26.md).

This update completes the pre-MVP implementation and automated Scale evidence
work represented by #58–#67. The separate gate decisions are recorded below.

## Gate disposition — 2026-09-26

- **#57 Readiness/Hardening: PASS under the initial-MVP scope waiver.** The
  accepted baseline simulation/replay, fixed two-Act process benchmark,
  compatibility/migration evidence, and Act 2 reward-pool prerequisite are
  recorded in the issue. Native-device measurements were waived, not performed
  or passed.
- **#69 Stage 3 Alpha Exit: PASS. Stage 4 may begin.** The full-roster Scale
  corpus, compatibility evidence, minimum unlock path, and absence of a
  separate unresolved P0/P1 issue were accepted. This is a gate decision only;
  it does not release or publish the MVP.
- **#68 remains open as a post-release follow-up.** No participant playtest was
  run. Human evidence is neither claimed nor required for this Alpha Exit.

The Scale report remains evidence for the Scale subgate only; the maintainer's
Hardening and Alpha Exit decisions are recorded separately in [#57](https://github.com/sunnyday9/Forbidden-Table/issues/57#issuecomment-5843868297)
and [#69](https://github.com/sunnyday9/Forbidden-Table/issues/69#issuecomment-5843875181).
