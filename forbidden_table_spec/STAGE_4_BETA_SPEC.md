# Stage 4 — Beta Content Scope

**Status:** Content budget and Beta gates accepted; the implementation issue graph is being recorded. Stage 4 completion is not a release or publication decision.

**Decision source:** The maintainer accepted the content budget in [#75](https://github.com/sunnyday9/Forbidden-Table/issues/75) and the Beta gate recommendation in [#76](https://github.com/sunnyday9/Forbidden-Table/issues/76#issuecomment-5868942424) on 2026-09-28. The optional final Act is deferred beyond 1.0 by [#74](https://github.com/sunnyday9/Forbidden-Table/issues/74).

## 1. Scope and guardrails

Stage 4 targets a content-complete 1.0 game with one continuous Run spanning exactly two Main Acts. After the Act 2 Boss reward is applied, the Run ends with the Normal Ending and Run Summary, following the [Stage 3 two-Act contract](STAGE_3_ALPHA_SPEC.md#3-continuous-two-act-run-contract). The optional final Act is outside the 1.0 target and requires a later explicit scope decision to reopen.

Project Spec §29 describes its figures as content budgets, not immutable constraints. For this scope, the accepted targets below make those budgets verifiable. The selected Boss Rule Breaker and Tile Modifier targets use the lower ends of their published ranges. Do not silently report an explicitly deferred item as complete.

Preserve current typed catalogs, registries, reward pools, map/encounter variants, Events, and Workshop definitions. A content batch does not justify a new core system by itself. A proposed core capability must meet the evidence rule in [#44](https://github.com/sunnyday9/Forbidden-Table/issues/44).

## 2. Accepted 1.0 content budget

| Category | Stage 3 inventory | Accepted Stage 4 target | Required composition and availability |
|---|---:|---:|---|
| Characters | 3 | **3 — complete** | All three are selectable at Run start subject to the existing unlock rules. |
| Contracts | 6 | **8** | Two additions; all eight are selectable at Run start subject to unlock rules. Contracts are Run-wide, not Act-gated. |
| Yaku | 18 registered IDs, including 8 `prototype.*` compatibility fixtures | **24 production definitions** | Count canonical production Yaku once each. Review/promote suitable prototype content with stable production identity or add replacements; preserve compatibility IDs. Yaku remain shared across both Acts. |
| Normal Relics | 36 | **50** | 25 Act 1-eligible Relics and 25 introduced in Act 2. The Act 2 reward/Shop pools include both groups; acquired build state carries across the Act boundary. |
| Boss Rule Breakers | 6 | **10** | Five eligible Rule Breakers per Act; each Act Boss continues to offer three distinct choices from that Act's pool. |
| Run Techniques | 14 | **21** | Seven additions to the shared Run pool, available in both Acts. |
| Core Techniques | 3 | **3 — complete** | One Character-bound Core Technique for each of the three Characters; not Act-specific. |
| Tile Modifiers | 8 | **12** | Four additions to the shared Workshop pool, available in both Acts. |
| Normal enemies | 8 | **14** | Seven per Act. |
| Elites | 2 | **6** | Three per Act. |
| Bosses | 2 | **4** | Two distinct Boss definitions per Act; exactly one Boss fight per Act in a Run. Both definitions per Act must be reachable through existing map encounter-variant data; keep the one-Boss-node map rule. |
| Events | 12 | **24** | Twelve per Act: two Events from each of the six existing families per Act, reachable from that Act's map. |
| Main Acts | 2 | **2 — complete** | Exactly two Acts in 1.0. The optional final Act is deferred. |
| Full-Run duration | Not established by participant evidence | **~60–90 minutes — design target** | Observed player duration is unverified before release and is not a pre-release pass claim. See §4. |

The inventory is based on the [Stage 3 Alpha-to-1.0 audit](https://github.com/sunnyday9/Forbidden-Table/blob/9458b01befeeeff71b26cd8f6f4ae465ea4d2141/forbidden_table_spec/STAGE_4_BETA_INVENTORY.md). It records the accepted Stage 3 catalog totals and the limits of current aggregate count/pool tests.

### Yaku counting rule

The accepted Stage 3 inventory reports 18 registered Yaku IDs: eight `prototype.yaku.*` definitions, two Phase 2 production Yaku, and eight Alpha production Yaku. The Phase 2 specification calls the eight prototype IDs compatibility fixtures. They do not count toward the 24 production target unless the maintainer explicitly promotes them after content review. A Yaku definition with both local and Complete Hand scoring still counts once; score-source IDs and aliases do not add roster entries.

## 3. Availability and Act composition

- **Run-wide selection and pools:** Characters and Contracts are chosen at Run start. Yaku and Run Techniques remain available across both Acts. Core Techniques are bound to their Character. Tile Modifiers use the shared Workshop pool.
- **Relics:** Act 1 may offer its 25 eligible Relics. Act 2 may offer those plus its 25 Act 2-introduced Relics. Acquired build items remain with the continuous Run.
- **Boss rewards:** Maintain separate Act 1 and Act 2 eligibility pools of five Rule Breakers each. Keep the existing three-choice Boss reward flow and verify the choices are distinct and eligible for the current Act.
- **Encounters:** Each Act contains seven Normal enemies, three Elites, and two Boss definitions. The current authored map has one terminal Boss node; make both Boss definitions reachable through that node's existing encounter-variant data. A Run still fights only one Boss in each Act.
- **Events:** Each Act makes twelve Event definitions reachable through its authored Event routes, with two definitions in each existing Event family.
- **Run continuity:** Act transition does not start a new Run. After the Act 2 Boss reward, the Run reaches the Normal Ending and Run Summary.

## 4. Counting, validation, and evidence rules

1. Count unique canonical, player-facing production definitions. Exclude aliases, test-only definitions, encounter-variant wrappers, and compatibility fixtures unless a decision explicitly promotes the underlying content. Preserve old IDs required by save/content compatibility.
2. A registered definition satisfies a target only when the intended player path can offer or encounter it in the relevant Act, reward pool, Shop, Workshop, Event route, or Run-start choice.
3. Stage 4 implementation tickets must cover aggregate roster counts and uniqueness, registry validity, pool membership, and map/Act reachability. They must also cover the new-vs-existing interactions for changed content; a raw count assertion does not prove composition or behavior.
4. Keep numerical balance values in content data. Do not edit core systems to make ordinary content work without a documented #44 evidence case.
5. The Project Spec's ~60–90 minute full-Run duration remains a design target. [#57](https://github.com/sunnyday9/Forbidden-Table/issues/57) and [#68](https://github.com/sunnyday9/Forbidden-Table/issues/68) prohibit human playtesting before the first actual MVP release. Therefore, observed player duration remains **unverified** through pre-release Beta; automated simulation throughput is not player duration. The maintainer may evaluate this target through the already planned post-release study if that study is run.

## 5. Beta entry gate

Enter Beta evaluation only when all of the following are true:

1. The approved content scope in this document is implemented: counts, canonical production IDs, and intended Act/pool/map availability validate.
2. A candidate build is frozen with exact application, content, and save-schema versions.
3. The full automated suite, aggregate content checks, and applicable Phase 2/Alpha regressions pass.
4. The supported save/replay format window is declared. Immutable fixtures exist for the Phase 2 v1 save and every player-distributed Alpha/Beta format in that window; migration and replay checks pass for those fixtures.
5. There are no known unresolved P0/P1 defects under the definitions in §6.

The maintainer records the candidate version and authorizes Beta evaluation. This gate does not mean that human or device evidence has been collected.

## 6. Beta exit evidence

### Content and integration

- Every approved category count, uniqueness rule, and Act allocation in §2–3 passes registry, pool, and map/event reachability validation.
- Every new content family has a focused interaction regression against existing systems; an aggregate count alone does not prove behavior.
- The production roster, build/content version, evidence owner, and any known deferred item are recorded.

### Balance and build viability

- Run a fixed, reproducible corpus of 1,000 complete two-Act simulations across Partial, Complete, and Hybrid policies. Stratify coverage across all 24 Character×Contract pairs under each policy.
- Repeat each declared seed/policy and require matching checkpoint hashes, RNG states, events, and terminal outcomes. Require zero crashes, invalid authoritative state, soft-locks/infinite resolution, or unexplained replay divergence. Defeat is a valid outcome.
- Report outcomes, strategy distributions, and content-use coverage. The content owner reviews and dispositions visible outliers. Do not impose a win-rate quota or claim player-validated balance before the post-release study.

### Onboarding, UX, and controller flow

- Script the new-profile onboarding path, Character and Contract selection, tutorial reset/disable behavior, critical in-Run decisions, both Act boundaries, and Run Summary.
- Scripted keyboard and controller mappings reach every critical action; no critical action is drag-only; visible focus and back/cancel behavior remain correct.
- Report scripted results separately from player comprehension and physical-device usability. Those are not established by automated flows.

### Accessibility and localization readiness

- A screen-by-screen project checklist passes for visible focus, keyboard/controller reachability, non-color-only critical information, readable and non-clipped text at supported UI scale, tutorial reset/disable, and high-priority cues retained in Normal/Fast/Instant presentation modes.
- English is the source locale. All player-facing text is extracted through stable localization keys, interpolation is validated, and a pseudo-localized expansion pass finds no missing keys or clipped critical UI. This gate does not require a translated locale.
- Record exceptions with an owner and explicit disposition. Do not claim external accessibility-standard conformance without selecting and testing a standard.

### Defects and performance

- **P0:** crash, data loss, soft-lock, invalid authoritative state, or determinism/replay corruption. **P1:** a required Run, reward, input, save, or replay path is blocked. Require zero open P0/P1 issues.
- Every remaining **P2** has an owner and explicit fix, defer, or accepted-risk disposition. P2 covers non-blocking UX, balance, localization, and presentation/audio issues.
- Preserve the native PC/Steam Deck measurement waiver in [#57](https://github.com/sunnyday9/Forbidden-Table/issues/57). Record the fixed headless two-Act benchmark as coarse process context only; it is not device performance evidence. Native frame-time and feedback-latency evidence is labelled **waived**, not passed or measured.
- Verify that Domain state and critical input feedback do not wait for presentation animation. Reopen native-device evidence only through an explicit scope decision that names hardware, workload, measures, thresholds, owner, and schedule.

### Presentation, audio, save, and replay

- No broken asset references or undocumented placeholders remain on a required player path. Each production item has its approved label/description and required cue or documented fallback; review Normal/Fast/Instant modes and preserve high-priority Complete Hand, Boss-transition, and victory cues.
- Preserve the Phase 2 v1 fixture and immutable fixtures for every player-distributed Alpha/Beta format in the declared support window. Verify sequential migrations without source overwrite, stable-boundary Suspend/Resume, content-version-correct replay, and exact checkpoint/RNG/event/outcome reproduction.

### Run duration and evidence report

- The ~60–90 minute full-Run length remains a design target. Under [#57](https://github.com/sunnyday9/Forbidden-Table/issues/57) and [#68](https://github.com/sunnyday9/Forbidden-Table/issues/68), do not conduct human playtesting before the first actual MVP release. Observed player duration is therefore **unverified** through pre-release Beta; simulation throughput is not player time. The maintainer may evaluate duration in the planned post-release study if that study is run.
- The Beta report lists exact application/content/schema versions, test commands and seed-corpus results, content/Act coverage, compatibility fixtures, defect dispositions, checklist results, and a `passed`, `failed`, or `waived/unverified` status for each area. The maintainer records the pass/fail decision.

Stage 4 completion remains separate from Stage 5 Release Candidate, MVP release, publication, or distribution.
