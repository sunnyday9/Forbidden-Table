# Stage 4 — Beta Content Scope

**Status:** Content-budget decision accepted; measurable Beta gates remain open in [#76](https://github.com/sunnyday9/Forbidden-Table/issues/76). This is not the completed Stage 4 specification or an implementation authorization.

**Decision source:** The maintainer accepted the recommendation recorded in [#75](https://github.com/sunnyday9/Forbidden-Table/issues/75#issuecomment-5866818223) on 2026-09-28. The optional final Act is deferred beyond 1.0 by [#74](https://github.com/sunnyday9/Forbidden-Table/issues/74).

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

## 5. Remaining Stage 4 decisions

This document records content scope only. [#76](https://github.com/sunnyday9/Forbidden-Table/issues/76) must define measurable Beta entry and exit gates for balance/build viability, onboarding/UX, controller flow, accessibility, localization readiness, defects, performance, presentation/audio, and content/save/replay compatibility. It must preserve the pre-release evidence boundaries in #57/#68. The finished Stage 4 specification and implementation issue graph follow after those gates are accepted.

Stage 4 completion remains separate from Stage 5 Release Candidate, MVP release, publication, or distribution.
