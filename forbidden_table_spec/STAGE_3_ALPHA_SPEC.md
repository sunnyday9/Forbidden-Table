# Stage 3 — Alpha Specification

Status: Approved scope and planning decisions; implementation remains gated.
Date: 2026-09-23
Map: [GitHub issue #40](https://github.com/sunnyday9/Forbidden-Table/issues/40)
Publication: [GitHub issue #50](https://github.com/sunnyday9/Forbidden-Table/issues/50)

This is the additive Stage 3 specification. It records the decisions made in
issues #43–48, #51, #52, #70, and #71 and gives the provisional Alpha targets in
`PROJECT_SPEC.md` §28 exact cumulative values. It does not replace or rewrite
`PROJECT_SPEC.md`, `ADR.md`, `CONTEXT.md`, `IMPLEMENTATION_PLAN.md`, or
`PHASE_2_SPEC.md`. The existing spec-pack authority order remains controlling;
Phase 2 requirements remain in force. Where this document resolves an Alpha
detail left open by the general milestone outline, the linked decision issue is
the source of that resolution.

## 1. Purpose, scope, and guardrails

Alpha scales and hardens the proven Vertical Slice into one continuous
two-Act Run. It is a private, invited test milestone, not a public release.
Alpha must leave all 1.0 core systems present and no major system still required
to finish the game.

The Phase 2 Vertical Slice remains the preserved baseline: its single Mini-Act,
Run loop, Commands, reward contracts, persistence, replay, and content
requirements are not redefined here. The Act 1 Boss still presents the Phase 2
three-choice Rule Breaker reward; the Elite reward still follows its separate
Phase 2 contract. Alpha adds a second Act and content through the existing
Run/map/reward/content extension points.

The normal Alpha ordering requires the Readiness and Hardening gates to pass
and the Phase 2 Boss and Elite reward prerequisites (#49 and #53) to be
verified complete before Scale. The dated
[pre-MVP scope decision](STAGE_3_PRE_MVP_SCOPE_DECISION.md) waives native-device
evidence for the initial MVP scope and moves participant testing to after the
first MVP release. Neither absent result blocks Alpha Exit or Stage 4, and
neither may be reported as a pass. Do not introduce an Act-wide mechanic or a
new core system merely to support a content batch. A genuinely missing core
capability requires the evidence bar in decision #44: cite the normative 1.0
requirement and gate, produce a reproducible failing acceptance case or narrow
prototype, show why existing extension paths cannot satisfy it, and review the
smallest proposed boundary and its save/replay/test/presentation costs before
implementation.

The content-order exception in #71 remains the only work scheduled before the
Hardening simulation subgate: add the three Act 2-specific Boss Rule Breakers
and their eligibility pool to the existing Act 2 Boss reward boundary so #57
can verify the required three-choice contract after an Act 1 Rule Breaker has
been acquired. These definitions count toward the approved Alpha total of six.
This narrow slice does not add the Act 2 Boss identity or other Scale content.
After the simulation subgate and fixed benchmark are recorded, the pre-MVP
scope decision authorizes the remaining Scale batches to proceed without
waiting for native-device measurements. This changes implementation
authorization only; it does not pass Hardening or alter Phase 2 rules.

Out of scope: optional Act 3/Final Table, a full progression economy, public
release, a public mod SDK, and any new Act-wide rule absent evidence of a real
systems gap.

## 2. Alpha content budget and Act allocation

Counts are cumulative at Alpha exit. “New in Alpha” is the addition over the
Phase 2 Vertical Slice baseline. Act allocation means where content is
introduced or primarily offered; run-wide content is not made unavailable in
the other Act, and acquired build state carries across the Act boundary.

| Category | Phase 2 baseline | Alpha total | New in Alpha | Act allocation / rule |
|---|---:|---:|---:|---|
| Characters | 2 | 3 | 1 | Run-wide choice at Run start; the third Character is unlocked for later Runs by the minimum Exit progression path. |
| Contracts | 3 | 6 | 3 | Run-wide choice at Run start; Contracts 4–6 follow the same minimum unlock path. |
| Yaku | 10 | 18 | 8 | Shared across both Acts; no Act-exclusive run-wide pool. |
| Normal Relics | 18 | 36 | 18 | Introduce the new set in Act 2; acquired Relics remain in the continuous Run. |
| Boss Rule Breakers | 3 required by the Phase 2 three-choice Boss contract | 6 unique definitions | 3 | Three associated with each Act Boss; each Boss offers its required three choices. The Act 2 trio is the sole pre-Hardening gate-enabling content in #71 and counts toward the six. |
| Run Techniques | 8 | 14 | 6 | Shared run-wide pool. |
| Core Techniques | 2 | 3 | 1 | One per Character; Character-bound, not Act-specific. |
| Tile Modifiers | 5 | 8 | 3 | Shared Workshop/content system. |
| Normal enemies | 4 | 8 | 4 | Four per Act: the existing four in Act 1 and four new in Act 2. |
| Elites | 1 | 2 | 1 | One per Act. |
| Bosses | 1 | 2 | 1 | One per Act. |
| Events | 6 | 12 | 6 | Six per Act; Act 2 adds one identity from each of the six existing event families. |
| Act maps | 1 | 2 | 1 | Preserve the existing Act 1 map and create a fresh Act 2 map. Use the current 10-node shape as the planning baseline, then validate it. |

The third Character, Harbor Reader, binds Core Technique 3 and the Harbor Read
Signature Passive. Harbor Read grants 1 TP after the Character's first Complete
Hand in each encounter. Run-start commands enforce the trusted meta-profile's
Character and Contract unlocks; presentation filtering is not the authority.

The map’s 10-node planning shape retains the Phase 2 topology contract: four
Normal battles (including a mandatory first Normal), one Elite, one Shop, one
Workshop, at least two Event opportunities, and one terminal Boss; meaningful
branch decisions precede the Elite, all selectable routes can reach the Boss,
and at least one route exposes both Shop and Workshop. Map topology and payload
selection stay deterministic.

No optional Act 3 is part of Alpha. The following Alpha totals remain below the
approved 1.0 budgets: Contracts 6/8, Yaku 18/~24, Normal Relics 36/~50, Boss
Rule Breakers 6/~10–12, Run Techniques 14/~21, Tile Modifiers 8/~12–16, Normal
enemies 8/~14, Elites 2/6, Bosses 2/4, and Events 12/~24. Equality is allowed
only for the explicitly required 3 Characters and 3 Core Techniques, which
already equal their 1.0 targets; this exception was approved in #46. Alpha has
two main Acts and excludes the optional final Act.

### Contracts 4–6 effect contract (#61)

Contracts 4–6 use the existing Contract selection, reward draft, encounter
setup, and Workshop paths. A declared `risk` or `reward` field must change a
Run or give the player an explicit signal; metadata presence alone does not
count. These effects are Alpha-only and must leave the Phase 2 three-Contract
behavior and reward defaults unchanged.

| Contract | Risk | Reward | Build bias / signal |
|---|---|---|---|
| Quiet Current | Begin each battle with 2 additional Pressure. | Begin each battle with 1 additional TP; choosing Elite Skip grants 1 Refinement Token. | Prefer East and South Honor tiles in normal battle rewards. |
| Open Ledger | Normal battle rewards offer no `ADD_TILE` choice outside the Characters suit. Modified Tile choices remain available because they modify an owned tile. | Bias normal battle tile rewards toward Characters and show `Sequence` as a Yaku hint at Contract selection. | Prefer Characters 4, 5, and 6. |
| Brittle Compass | Elite Skip pays 2 less Gold; Workshop Refinement Token service costs 1 additional Gold. | Gain 1 Refinement Token on Contract selection and receive one extra, distinct Modified Tile choice in normal battle rewards when another valid target/modifier pair exists. | Prefer Dots 4, 5, and 6. |

The first of Brittle Compass's Modified Tile choices follows the normal reward
draft. Its extra choice is drawn from a distinct tile-instance/modifier pair;
it is omitted only when no second valid pair exists. Contract names, effects,
build bias, and Yaku signals are shown in the Contract choice details. Only the
three `alpha.contract.*` definitions consume these new fields.

## 3. Continuous two-Act Run contract

Acts are chapters of one Run, not separate Runs. Apply the Boss reward before
changing Acts. The Act 1 transition creates a fresh Act 2 map/path in the same
Run. After the Act 2 Boss reward is applied, end at the Normal Ending and Run
Summary; there is no Alpha Act 3.

| State at boundary | Carry or reset |
|---|---|
| Carry unchanged | Run ID, seed, content version, Character, Contract, Tile Pool/build (including acquired Rule Breakers), Gold, Refinement Tokens, tutorial progress, and Run-scoped effects. |
| Recreate | Act index/context, map definition/path/node context, and the next encounter. Act 2 uses a fresh map. |
| Do not carry | Prior battle snapshot/instance, Battle- or Act-scoped effects, or an active Shop, Workshop, Event, or other node interaction. |
| Pending Boss reward | Remain at the reward choice. Do not create/enter the next Act map until the choice is applied. |

The Act 1 sequence is Boss victory → three-choice Boss Rule Breaker reward →
apply selected Rule Breaker → initialize Act 2 map. Act 2 ends with Boss
victory → apply that Boss’s reward → Normal Ending/Run Summary. Act distinctions
come from existing enemies, encounters, events, rewards, and maps, not a new
Act-wide ruleset. Act transitions and outcomes are authoritative Run/replay
events and stable checkpoints.

## 4. Core-system hardening and content extensibility

Existing core systems are hardened, not presumed absent. Preserve Domain-first
authority, serializable Commands, typed data definitions and stable IDs,
deterministic domain-separated RNG, explicit DTO persistence/migration, and
headless rule tests. Every ordinary content batch must pass the No-Core-Code
Content Test using existing definition, registry, pool, and resolver seams.
Do not edit core CombatEngine/DrawResolver/SettlementResolver/EffectQueue to
make ordinary content data work. A new Rule Breaker extension point is allowed
only for a demonstrably new rule dimension and only after the #44 evidence and
spec review.

Each Scale batch needs catalog validation, targeted new-vs-existing interaction
regression, and an update to the full Alpha simulation/replay corpus. Compare
the unchanged fixed benchmark as coarse process-timing context only; timing
thresholds are not initial MVP criteria and native-device measurements are
waived for this scope. For every save format included in a player-distributed
build, freeze an immutable fixture and verify the applicable migration path
before changing that format; never rewrite an earlier fixture in place.

## 5. Save, content-version, and replay compatibility

Preserve the Phase 2 schema-v1 `game.phase2.v1` / `content.slice.v1` suspend
snapshot as an immutable baseline fixture. Through Alpha Exit, support
migration of that fixture and every player-distributed Alpha save schema using
sequential schema migrations. Each distributed format has an immutable
pre-migration fixture; verification covers successful load, stable-boundary
validity, state/checkpoint integrity, and exact future RNG outputs.

Schema migration must not silently change `content_version`. Resume under the
matching frozen content/rules bundle or use an explicit, fixture-tested content
migration. Reject unsupported or unavailable content versions without
overwriting the source save. There remains one automatic continuation save,
not multiple slots or rollback.

Replay migration is added only when needed; a replay retains its original
content version and is verified only against that exact rules/content version.
Never relabel an old replay. If its matching bundle is unavailable, report
reproduction as unavailable while preserving the record. Validate game/engine
version explicitly. Freeze distributed replay fixtures and verify accepted
commands, checkpoints/state hashes, RNG snapshots, events, and terminal outcome.
Compatibility is guaranteed through Alpha Exit; a later release policy is
outside this spec.

Compatibility is an evidence requirement, not a statement about any particular
checkout or implementation status. The archived pre-change Phase 2 validator
rejected the originally supplied static JSON fixture with
`INVALID_RNG_STATE`, `INVALID_RUN_SEED`, `INVALID_CURRENCY` (for `gold` and
`refinement_tokens`), and `STATE_HASH_MISMATCH`; wide RNG integers lost integer
type fidelity during JSON parsing. Preserve this as a regression case: #54
requires a genuinely serializable fixture from a valid archived v1 stable
checkpoint, acceptance by the unchanged archived validator, a lossless
wire-format/migration path where needed, and exact future RNG. Issues #49 and
#53 own the Phase 2 Boss/Elite reward and content-version/save/replay evidence
at those boundaries; #54 owns the full compatibility matrix through Alpha
Exit. Readiness cannot pass until all three tickets' required evidence is
independently verified. Do not weaken validators or change the normative Phase
2 documents to make the fixture pass. No existing Phase 2 document is changed
by this specification.

## 6. Performance and deterministic simulation thresholds

These are approved Alpha planning thresholds, not measurements inferred from
the #42 baseline. The WSL2 Ryzen 7 H 260 / Godot 4.7.2 results are process-level
test references only; they are not gameplay frame-time or full-Run throughput
claims.

### Seeded simulation

- At Readiness, Hardening, Scale, and Exit, run 1,000 complete two-Act seeded
  Run attempts, split across Partial, Complete, and Hybrid strategy policies.
- Coverage grows with the roster instead of requiring content before its Scale
  batch. Readiness and Hardening each cover the then-implemented baseline roster
  (2 Characters and 3 Contracts), both Act/Boss boundaries, and every currently
  implemented reward path. The #71 Act 2 Boss pool must be implemented before
  these gates so the Act 2 three-choice reward is available for coverage. They
  must not be reported as full-Alpha-roster runs.
- The Scale gate, after the ordered content batches complete, and the Exit gate
  each cover the full Alpha roster (3 Characters and 6 Contracts), both Acts,
  both Bosses, every applicable reward path, and the cumulative Alpha content.
  Report exact roster and content coverage at every gate; entries not yet
  introduced are explicitly “not yet available,” never silently omitted.
- Repeat each declared seed/policy and require matching checkpoint hashes, RNG
  states, events, and terminal outcome.
- Require zero crashes, invalid authoritative state, soft-locks/infinite
  resolution, or unexplained replay divergence. Defeat is a valid game outcome.
- Report outcomes and strategy distributions; impose no win-rate quota before
  invited-player evidence establishes one. Correctness and balance evidence
  stay separate.

### Performance

- Keep the fixed headless complete two-Act Run benchmark and its seed,
  accepted-command count, checkpoints, outcome, wall/CPU time, and peak RSS as
  coarse process-level context. Five repetitions and the former 20% median
  regression cap are not pre-MVP Scale acceptance blockers. A changed workload
  needs a newly documented baseline before comparing its process timings.
- Native PC and Steam Deck frame-time and command-to-visible-feedback
  measurements are waived for the initial MVP scope. The earlier planning
  targets (p95 frame time of 16.7 ms on representative PC and 33.3 ms on Steam
  Deck; p95 feedback latency of 100 ms) are not release criteria. Do not
  simulate native performance or treat WSL2 process timings as device evidence.
  No device result is claimed; reopen this evidence only by maintainer decision.

### Gate-specific coverage decision (#70)

The maintainer resolved the conflict between #47 and #48 in
[#70](https://github.com/sunnyday9/Forbidden-Table/issues/70): retain the
Readiness → Hardening → Scale → Exit order and the 1,000-run requirement at each
gate, while advancing roster coverage only as Scale adds content. Readiness and
Hardening use the existing baseline roster; Scale and Exit require the full
Alpha roster. This explicitly revises #47’s former full-roster-at-every-gate
wording and does not change Phase 2 requirements or #48’s order.

## 7. Invited-player protocol and four gates

Do not recruit participants or run the private invited study before the first
actual MVP release. The maintainer may help with the study after release as a
post-release activity; it is not required for the initial MVP release, Alpha
Exit, or Stage 4 entry. Keep the protocol below as an optional follow-up; its
publication does not launch the study or imply that results exist.

- **Cohort:** 12 participants: 8 with no/minimal Mahjong experience and 4
  familiar participants as a comparison group. Record roguelike experience as
  context, not qualification.
- **Session:** normal onboarding and one continuous two-Act Run using in-game
  help only. A second session may finish a run exceeding 90 minutes. Require at
  least one stable-boundary Suspend/Resume. Moderators may clarify controls or
  recover technical failures, but may not teach strategy/rules.
- **Observed path:** Normal encounter, Elite reward, both Boss rewards, Act 1
  transition, route/economy decision, and Run Summary, with approved content and
  version.
- **Evidence:** anonymized notes for build/content/schema versions, platform,
  seed, accepted commands/checkpoints, route/reward choices, suspend/resume,
  outcome/time, invalid inputs, help, confusion, frame/feedback metrics,
  crashes, and participant feedback. Record screen/audio only with informed
  consent.
- **Triage:** P0 = data loss/crash/soft-lock/determinism or invariant failure;
  P1 = core path blocked or repeated cohort confusion; P2 = balance/polish.
  Record findings and disposition them with owner/rationale. Pre-release P0/P1
  findings already known still block Alpha Exit; post-release study findings
  are follow-up issues and do not retroactively gate the initial release.
- **Study observations:** at least 6/8 Mahjong-new participants complete
  onboarding and independently execute the main loop without coaching; at
  least 6/8 reach the Act 2 Normal Ending within at most two sessions; obtain
  one successful Partial, Complete, and Hybrid strategy example across the
  cohort. Report misses accurately; these observations are optional post-release
  feedback, not Alpha Exit criteria or generalizable public claims.

The project maintainer is accountable for each gate decision; Engineering owns
automated/reliability evidence, the facilitator owns consent/protocol and
anonymized observations, and the content owner owns roster/batch evidence.

| Gate | Entry | Exit evidence and decision |
|---|---|---|
| Readiness | Approved scope, two-Act contract, compatibility policy, performance plan, both Phase 2 reward fixes complete, #71 gate-enabling reward pool complete, and a candidate full-loop build. | Required core capabilities present; content IDs/pools validate; No-Core-Code and Phase 2 regressions pass. Maintainer authorizes Hardening. |
| Hardening | Readiness passed; fixed build/workload and save/replay fixtures available. | Required 1,000-run invariant/replay criteria and migration fixtures pass. Native PC/Deck evidence is waived for the initial MVP scope, not passed or measured. The #47/#48 gate-order resolution is recorded in #70; #71 makes the required Act 2 reward path available. |
| Scale | Approved batch and the recorded Hardening simulation subgate/fixed benchmark; #49 and #53 complete. | Each batch reaches its approved counts and passes catalog, No-Core-Code, interaction, seeded-corpus, and save/replay checks. Coarse process timings are informational; native-device evidence is waived for the initial MVP scope. Content owner signs each batch. Full-roster 1,000-run evidence remains required before Alpha Exit. |
| Exit | Both Acts and all approved Alpha totals are present; required automated evidence is complete. | Phase 2/Alpha compatibility fixtures pass; no unresolved P0/P1; full-roster Scale evidence and minimum unlock behavior pass. Native-device evidence is waived for the initial MVP scope. Participant testing is a post-release follow-up, not an Alpha Exit prerequisite. Maintainer records pass/fail and follow-up work. |

## 8. Minimum Alpha-exit unlock path

Implement the thin profile-backed horizontal unlock path on the existing
`MetaProgressSnapshot` seam; do not add a currency, permanent stat inflation,
or full progression economy.

- A new default profile starts with the Phase 2 roster: 2 Characters and 3
  Contracts.
- Completing the first full two-Act Run’s Act 2 Normal Ending unlocks Character
  3 and Contracts 4–6 for later Runs; it does not alter the completed Run.
- Automated and invited-test profiles may pre-unlock all 3 Characters and 6
  Contracts to exercise the roster. The invited study is not progression
  evidence.
- A failed or unsupported profile load preserves the source data and disables
  progression writes. The player-facing recovery state offers an explicit
  profile reset; ordinary victories cannot overwrite the rejected source.
- Other categories remain accessible through ordinary Run/content systems; do
  not add meta locks for Yaku, Relics, Techniques, Tile Modifiers, Events,
  Elites/Bosses, or Rule Breakers during Alpha.
- Verify default state, exact unlock milestone, persistence across restart and
  schema migration, all-unlocked test profiles, and absence of currency/stat
  inflation. Implement after two-Act Run, stable IDs, and save compatibility;
  before Alpha Exit, but not as a Readiness/Hardening/Scale prerequisite.

## 9. Decision and evidence trace

- Two-Act continuity and boundary semantics: [#43](https://github.com/sunnyday9/Forbidden-Table/issues/43).
- Hardening versus genuine system gaps: [#44](https://github.com/sunnyday9/Forbidden-Table/issues/44).
- Save/replay compatibility: [#45](https://github.com/sunnyday9/Forbidden-Table/issues/45).
- Cumulative totals and Act allocation, including the Character/Core Technique parity exception: [#46](https://github.com/sunnyday9/Forbidden-Table/issues/46).
- Simulation/performance thresholds and the gate-order decision: [#47](https://github.com/sunnyday9/Forbidden-Table/issues/47), [#70](https://github.com/sunnyday9/Forbidden-Table/issues/70).
- Pre-Hardening availability of the strict Act 2 Boss reward path: [#71](https://github.com/sunnyday9/Forbidden-Table/issues/71).
- Invited test and gate protocol: [#48](https://github.com/sunnyday9/Forbidden-Table/issues/48).
- Minimum Alpha-exit unlock behavior: [#51](https://github.com/sunnyday9/Forbidden-Table/issues/51).
- Phase 2 Elite contract: [#52](https://github.com/sunnyday9/Forbidden-Table/issues/52), implemented separately in [#53](https://github.com/sunnyday9/Forbidden-Table/issues/53).
- Initial-MVP evidence scope and gate disposition: the [scope decision](STAGE_3_PRE_MVP_SCOPE_DECISION.md), [Readiness/Hardening PASS under the waiver in #57](https://github.com/sunnyday9/Forbidden-Table/issues/57#issuecomment-5843868297), and [Stage 3 Alpha Exit PASS in #69](https://github.com/sunnyday9/Forbidden-Table/issues/69#issuecomment-5843875181). Device evidence was waived; no participant playtest occurred; Stage 4 may begin.
- Phase 2 Boss reward gap: [#49](https://github.com/sunnyday9/Forbidden-Table/issues/49).
