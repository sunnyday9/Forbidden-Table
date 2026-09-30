# Stage 4 Beta Evidence Report — Issue #96

**Evidence assembled:** 2026-09-30

**Gate decision:** **PENDING MAINTAINER**

**Scope:** Stage 4 Beta / Content Complete only. This report does not pass Stage 4, authorize Stage 5, release, publication, or distribution.

## Decision needed

The maintainer must inspect the 18 rendered screenshots linked in the [Stage 4 accessibility checklist](STAGE_4_ACCESSIBILITY_CHECKLIST.md) against that checklist, record the result on [issue #92](https://github.com/sunnyday9/Forbidden-Table/issues/92), then review this report and record an explicit Beta **PASS** or **FAIL**. No human screenshot review is claimed here. The 1,000-run corpus passed for its recorded authoritative simulation snapshot and accepted content identity; its recorded full runtime-source hash predates later presentation/localization work, so it is not a byte-identical full-tree run of this frozen review candidate (details below).

The [Stage 4.5 map, issue #98](https://github.com/sunnyday9/Forbidden-Table/issues/98), remains downstream of a recorded Stage 4 PASS. Its UI/UX design work does not substitute for this gate. Stage 5 keeps its existing name and scope.

## Frozen candidate and support window

| Identifier | Frozen value |
| --- | --- |
| Application source revision | `e7060c6922bef05d4d17996b16a2a8179928aae4` (`fix: add Stage 4 presentation feedback cues (#94)`) |
| Evidence review baseline | `39606f26693f5bf6d111a38a1e41cf37067d402a` (`codex/stage4-beta-content`); later commits in this baseline record evidence/scope decisions |
| Project build version | `stage3-alpha-playable-1` |
| Engine | Godot `4.7.2-stable` official, build hash `ed1daf0bf` |
| Default production content bundle | `content.bundle.v1.alpha.act_two@v5+alpha.scale@v12+phase2@v4` |
| Game / replay rules version | `game.phase2.v1` |
| SuspendSnapshot schema | `1` |
| MetaProgressSnapshot schema | `2` |
| ReplayRecord schema | `1` |
| Simulation manifest schema / corpus format | `1` / `alpha.gate-corpus-jsonl.v3` |
| Fixed headless benchmark | `alpha.fixed-complete-run.v5`; its Hardening fixture uses `content.bundle.v1.alpha.act_two@v5+phase2@v4` (Scale is intentionally excluded from that benchmark profile) |

**Supported save/replay window:** the Phase 2 v1 suspend baseline required by #45, plus every player-distributed Alpha format within the continuous Alpha-to-Beta support interval and any Beta format distributed before Beta exit. The compatibility inventory dated 2026-09-29 found no GitHub Release, tag, or out-of-band Alpha/Beta save/replay artifact. Therefore only the Phase 2 v1 suspend has an immutable historical fixture; MetaProgress v1 and Replay v1 are source-defined test inputs, not evidence of player distribution. This is a compatibility baseline, not a claim that a public build was distributed. The support window ends at the Stage 4 Beta exit decision.

## Entry gate

The accepted measurable criteria are in [issue #76](https://github.com/sunnyday9/Forbidden-Table/issues/76#issuecomment-5868942424), with the later [presentation-scope clarification](https://github.com/sunnyday9/Forbidden-Table/issues/76#issuecomment-5911200135). Entry evidence for the frozen candidate is:

| Entry check | Owner | Result | Evidence |
| --- | --- | --- | --- |
| Exact application, content, game, save, replay, and manifest identifiers recorded | Release / Runtime Engineering | **PASS** | Frozen identifiers above; compatibility manifest below. |
| Accepted #75 scope and intended availability | Content Engineering | **PASS** | [#75 decision](https://github.com/sunnyday9/Forbidden-Table/issues/75#issuecomment-5867795290), [#87 aggregate gate](https://github.com/sunnyday9/Forbidden-Table/issues/87#issuecomment-5879899532), and [`tests/stage4_content_completeness_test.gd`](../tests/stage4_content_completeness_test.gd). The production totals are 3 Characters, 8 Contracts, 24 canonical Yaku, 50 Relics, 10 Boss Rule Breakers, 21 Run Techniques, 3 Character-bound Core Techniques, 12 Tile Modifiers, 14 Normal enemies, 6 Elites, 4 Bosses, 24 Events, and exactly 2 Main Acts. Relics split 25 Act 1-eligible / 25 introduced in Act 2; Rule Breakers are 5 per Act; Normal enemies, Elites, Bosses are 7/3/2 per Act; Events are 12 per Act, two per family. Intended pools and two-Act map/ending reachability are checked. |
| Full automated project suite and current-candidate Phase 2 / Alpha regressions | Runtime / QA | **PASS** | The full `./scripts/test.sh` suite passed on the final #94 source candidate; the #94 record reports no Godot script, parse, compile, load, or runtime errors. Compatibility regression categories include persistence, meta migration, replay, map/reward transitions, RunScene, and Stage 3 Alpha combat/content behavior. See [#94 close evidence](https://github.com/sunnyday9/Forbidden-Table/issues/94#issuecomment-5911011903) and the exact commands below. |
| Phase 2 v1 compatibility fixtures and declared source window | Persistence / Replay | **PASS (declared window)** | [`STAGE_3_ALPHA_COMPATIBILITY_MATRIX.md`](STAGE_3_ALPHA_COMPATIBILITY_MATRIX.md), [`stage4_beta_compatibility_manifest.json`](../tests/fixtures/stage4_beta_compatibility_manifest.json), and [#88 verification](https://github.com/sunnyday9/Forbidden-Table/issues/88#issuecomment-5880371787). Four frozen Phase 2 v1 SuspendSnapshot fixtures are hashed and tested. MetaProgress v1 and Replay v1 have no immutable player-distributed fixture; the documented source-defined cases pass. |
| No open P0/P1 defects | Maintainer / QA | **PASS (tracker snapshot and recorded gates)** | The 2026-09-30 open-issue inventory contains no open defect issue labeled P0 or P1; #89 records zero failed attempts, invalid states, soft-locks, hangs, and unexplained replay divergence; the current-candidate full suite passed. The tracker query is recorded under Commands. This is not a claim that an unreported defect cannot exist. |

## Exit evidence and status

Each accepted area has an evidence owner and a visible disposition. `UNVERIFIED` is kept for work the current evidence cannot establish.

| Exit area | Evidence owner | Status | Evidence and boundary |
| --- | --- | --- | --- |
| Content, pool, and map coverage | Content Engineering | **PASS** | [#87 report](https://github.com/sunnyday9/Forbidden-Table/issues/87#issuecomment-5879899532); aggregate counts, unique production IDs, per-Act pools, shop/workshop/event/map availability, two-Act path, Act 2 Boss reward, Normal Ending and Run Summary. |
| 1,000-run balance/build-viability simulation | Simulation / QA; Content owner reviews outliers | **PASS for authoritative domain simulation; exact full-tree hash not rerun** | [#89 report](https://github.com/sunnyday9/Forbidden-Table/issues/89#issuecomment-5896065558); local generated [final report](../.godot/stage4_beta_1000_corpus_20260929_final/final-report.md), [manifest](../.godot/stage4_beta_1000_corpus_20260929_final/manifest.json), and [summary JSONL](../.godot/stage4_beta_1000_corpus_20260929_final/final-summary.jsonl). The historical run completed 1,000 cases and exact repeats, with all 72 Character × Contract × Policy combinations represented, 0 failed attempts, invalid states, unavailable content, repeat mismatches, or visible outliers; there is no win-rate quota. Its runtime-source snapshot SHA-256 is `7cef332987080e27856159070742e7f4919eb76277af8c739a7b30134dcd6d3d`, based on the #89-era source snapshot (manifest base revision `54a8d09635a6ab136ac3c1ce10bca4508799053b`). Later localization, content-label, test, and presentation changes mean the corpus was **not** rerun against the exact current full-tree hash. No `src/domain/**` file changed after the #89 implementation commit `804bd10`, and the accepted content bundle identity is unchanged; the current full suite also passes. This supports the authoritative domain-simulation result, but must not be described as a byte-identical whole-candidate rerun. |
| Onboarding and critical Run flow | Run UX / QA | **PASS (scripted mechanics); comprehension not evaluated** | [#90 verification](https://github.com/sunnyday9/Forbidden-Table/issues/90#issuecomment-5897244110). Covers new-profile choices, tutorial reset/disable, both Acts, rewards, ending/summary, and subsequent Run. The deterministic test registry modifies combat values to keep the UI flow short; it does not prove production combat balance or player comprehension. Human study remains deferred under #57/#68. |
| Keyboard and controller mapping | Input / QA | **PASS (scripted virtual input)** | [#91 verification](https://github.com/sunnyday9/Forbidden-Table/issues/91#issuecomment-5900148578). Keyboard and controller mappings each recorded 90 accepted inputs and 85 authoritative Run outcomes through tested actions. No physical controller, Steam Deck, or native PC usability test is claimed. |
| Accessibility checklist and screenshots | Accessibility / Run presentation; maintainer performs visual review | **UNVERIFIED — maintainer review pending** | [`STAGE_4_ACCESSIBILITY_CHECKLIST.md`](STAGE_4_ACCESSIBILITY_CHECKLIST.md) and 18 PNGs in [`evidence/stage4_accessibility/`](evidence/stage4_accessibility/). Scripted audit passed 12 phases, 19 critical-state buckets, 90 keyboard accepts, 90 virtual-controller accepts, and 57 cue comparisons across Normal/Fast/Instant; capture probe reported zero layout/flow failures. The implementing and root software agents inspected captures; these do not count as maintainer/human participant review. [#92 is OPEN](https://github.com/sunnyday9/Forbidden-Table/issues/92). No external accessibility conformance, assistive-technology, physical-device, or participant testing is claimed. |
| English-source localization readiness | Localization / QA | **PASS (English source only)** | [`STAGE_4_LOCALIZATION_READINESS.md`](STAGE_4_LOCALIZATION_READINESS.md), [#93 evidence](https://github.com/sunnyday9/Forbidden-Table/issues/93#issuecomment-5910030508), and the current #94 verification. #93 recorded 959/959 stable keys; later #94 verification records 962/962 current keys, 305 dynamic content IDs, 171 dynamic words, and zero unresolved/format errors. Pseudo-localization expands representative strings by 30% at 960×540 with `critical_layout=CHECKED`. No translated locale or translation-quality claim. |
| Production presentation, required cues, audio/fallback | Run presentation | **PASS (clarified Stage 4 scope)** | [`STAGE_4_PRESENTATION_AUDIO_REVIEW.md`](STAGE_4_PRESENTATION_AUDIO_REVIEW.md), [#94 final review](https://github.com/sunnyday9/Forbidden-Table/issues/94#issuecomment-5911011903), and [maintainer clarification on #76](https://github.com/sunnyday9/Forbidden-Table/issues/76#issuecomment-5911200135). Maintainer clarification aligns with `PROJECT_SPEC.md` §1.2: Stage 4 requires approved labels and accurate summaries already exposed on player paths, not bespoke prose for every production item. The audit covers 179 production definitions and ordered localized Complete Hand → Boss phase → Victory cues in Normal/Fast/Instant. There are no audio assets/player or animation path; visible localized text is the documented Beta fallback. New contextual detail surfaces and a player-facing mode selector are assigned to #98. |
| Responsiveness and headless process context | Runtime / Performance | **PASS (state-order and process-context evidence)** | [`STAGE_4_RESPONSIVENESS_REPORT.md`](STAGE_4_RESPONSIVENESS_REPORT.md), [#95 evidence](https://github.com/sunnyday9/Forbidden-Table/issues/95#issuecomment-5911023288). Five identical fixed-run repetitions completed on the recorded benchmark profile: Act 2 Victory, 304 commands, 305 checkpoints, replay MATCH; median process wall 15.55 s, CPU 15.69 s, peak RSS 398,924 KiB under WSL2. Domain authority is available before cues refresh; this is not a frame-time or input-latency result. |
| Native PC / Steam Deck frame time and command-to-feedback latency | Runtime / Performance; waiver owner Maintainer | **WAIVED / NOT MEASURED** | Explicit initial-MVP scope waiver under [#57](https://github.com/sunnyday9/Forbidden-Table/issues/57#issuecomment-5843532234). WSL2 process timings do not substitute for native measurements and are not a pass. |
| Save/replay compatibility | Persistence / Replay | **PASS (declared support window)** | Compatibility matrix and manifest above; Phase 2 fixture hashes are listed below. Eight focused suites passed at #88 and remain in the current full-suite gate. No player-distributed Alpha/Beta snapshot outside the Phase 2 fixture was evidenced as of the inventory; source-defined MetaProgress/Replay tests are not historical distribution artifacts. |
| P0/P1 and remaining P2 dispositions | Maintainer / QA; area owners listed below | **PASS for recorded issues; no unresolved documented Stage 4 P2** | Current open tracker snapshot contains only #40, #68, #72, #92, #96, and #98; none is an open P0/P1 defect. Earlier #92 readability/focus/cue issues are fixed in its ledger. Non-blocking dispositions are listed in the next section. A newly discovered issue during maintainer screenshot review must still be severity-rated and dispositioned. |
| Observed player Run duration / participant testing | Product / Study owner | **DEFERRED — not performed pre-release** | The ~60–90 minute duration remains a design target, not a measured result. Under #57/#68, participant testing is post-release follow-up and is not a Stage 4 Beta prerequisite. No player duration or comprehension result is claimed. |

### P2 and other residual dispositions

No open issue records a remaining Stage 4 P2 after the accepted fixes. These known notes remain visible with owners and disposition:

| Finding or follow-up | Owner | Disposition |
| --- | --- | --- |
| Contract Select captions and long Run Tile Pool label had readability/clipping problems; Run Complete lacked guaranteed initial focus; a Battle phase event could expose an internal identifier. | Run presentation | **Fixed in #92** with concise focusable action names, wrapped selected-action detail, post-layout measurement, initial New Run focus, and a localized phase cue. Automated/layout checks pass; maintainer inspection of the screenshots is still pending. |
| Complete Hand, Boss-phase, and victory events lacked distinct player feedback. | Run presentation | **Fixed in #94** with localized ordered text cues and Normal/Fast/Instant regression. |
| No authored audio or animation playback path exists. | Presentation | **Accepted Beta fallback:** localized visible text; no audio playback is claimed. |
| `EnemyIntent` display strings can affect persisted state hashes if locale changes. | Domain / Persistence | **Accepted bounded risk for English-only Beta.** Revisit before locale switching or translated persisted Runs. |
| Some test teardown paths repeat cleanup on early-return branches. | Test / QA | **Deferred low-priority maintainability note** from #91 Standards review; no player-path defect or P2 was reported. |
| Victory cue append logic is duplicated across alternative event branches. | Run presentation | **Deferred low-priority maintainability cleanup** from #94 Standards review; no hard code-standard violation or player-path defect was reported. |
| Additional contextual object detail and a player-facing Normal/Fast/Instant affordance. | Product / Stage 4.5 (#98) | **Deferred by scope** to #98 after Stage 4 receives a recorded PASS; not a remaining Stage 4 P2. |

## Compatibility fixture hashes

The machine-readable compatibility manifest records canonical-LF hashes for the frozen Phase 2 v1 fixture files; CRLF checkout normalization is tested.

| Fixture | SHA-256 (canonical LF) |
| --- | --- |
| `phase2_v1_suspend_snapshot.gd` | `f6570bdda8d22b170b8232b8cfe44cfc31049e71d8665098889201d4f0c067a3` |
| `phase2_v1_serialized_suspend_snapshot.json` | `c720d065338a75a22657b54c0745bbf8d2aa2412b55d69f5d86e0fcd15877150` |
| `phase2_v1_archived_valid_suspend_snapshot.json` | `c720d065338a75a22657b54c0745bbf8d2aa2412b55d69f5d86e0fcd15877150` |
| `phase2_v1_boss_reward_suspend_snapshot.gd` | `d7aba10ae87decd95fb38056a77fc12a59c4ea90860cbea0569dc6767b4274cb` |

Other evidence artifact hashes checked while assembling this report:

| Artifact | SHA-256 |
| --- | --- |
| `tests/fixtures/stage4_beta_compatibility_manifest.json` (working-tree bytes) | `7b54dfbc883848564ae669d4e5512ba1a557e117c53b6e226e92078f594df473` |
| `STAGE_3_ALPHA_COMPATIBILITY_MATRIX.md` (working-tree bytes) | `7d21c4c24118ad2cfa7fb77335ff8da0a4dec43092e978b5217943ceca2d954f` |
| #89 corpus manifest (local, ignored artifact) | `5df2e52634015661e3b0e49a7eabbbceed1e170c9cb32a1212f94705dc5b472b` |
| #89 summary JSONL (local, ignored artifact) | `77bb9c970f702ee930f1bed9e300d81f911c8e0c1395704367c5bfc76096b777` |
| #89 final report (local, ignored artifact) | `328fbfff2a0221175dadbcb8ca7e5f1e6aba634222ebb75e587ad67c3285b9fc` |
| #95 benchmark manifest | `45660c1211b41a1d8ca76972bd9c4bbdf0c159abd382dbf88d3a92611fb52557` |

The #89 corpus files currently exist at `.godot/stage4_beta_1000_corpus_20260929_final/`, but `.godot/` is ignored by Git. The GitHub #89 close comment preserves the hashes and results; the raw JSONL/chunk artifacts are local-only and would not be present in a fresh clone.

## Reproduction commands and evidence sources

Commands below were recorded as passing on Godot 4.7.2. The full-suite result was recorded after the #94 source changes; #94 issue evidence and the committed reports contain the output summaries. The report does not claim they were rerun while assembling #96.

```sh
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --stage4-content
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --runner-dispatch
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --map
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --stage4-onboarding-flow
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --stage4-accessibility
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --stage4-localization
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --presentation
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --battle-integration
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --persistence
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --meta-progress
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --replay
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --run-scene
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --reward-economy
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --elite-reward
GODOT_BIN="$PWD/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ./scripts/test.sh --boss-rule-breaker-reward
python3 tests/localization_audit_test.py
python3 scripts/validate_localization.py
```

The #89 corpus used `scripts/run_alpha_gate_corpus_chunk.py` for 50 bounded chunks of 20 cases, then `scripts/run_alpha_gate_corpus.gd -- --full --finalize --gate stage4_beta ...` to merge/finalize. Each chunk used GNU `timeout`, the pinned Godot binary, `--process-timeout-seconds 4830`, and `--process-timeout-enforced`; the complete 50-chunk/finalization argv is in the local ignored `final-report.md`. The finalizer exited `0`; 50/50 chunk process statuses were `0`, with no timeouts. Do not treat this historical run as newly executed for #96.

The #95 benchmark command was:

```sh
GODOT_BIN=/home/ubuntu/.codex/recovery/forbidden-table-review-remediation/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 python3 scripts/benchmark_alpha_fixed_run.py
```

Screenshot capture used:

```sh
DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 ./.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path "$PWD" --script res://tests/stage4_accessibility_capture_probe.gd
```

The tracker snapshot used to assess open defect issues was:

```sh
GH_REPO=sunnyday9/Forbidden-Table gh issue list --state open --limit 200 --json number,title,labels,assignees,url
```

## Maintainer record

**Beta decision:** `PENDING MAINTAINER`

**Decision date:** pending

**Decision owner:** maintainer

**Decision notes / approved limitations:** pending

Before recording PASS or FAIL, the maintainer should:

1. Inspect the 18 screenshots against the checklist and record findings or approval on #92. The captures are linked from the checklist.
2. Review the evidence matrix, including the distinction between the #89 authoritative-domain corpus PASS and its older full-tree source hash.
3. Record a Beta **PASS** or **FAIL** for the frozen identifiers above, with any additional P2 owner/disposition from screenshot review.

The Beta decision is not an authorization to release, publish, or distribute. Issue #96 and the Stage 4 map #72 must remain open until that maintainer record is completed.
