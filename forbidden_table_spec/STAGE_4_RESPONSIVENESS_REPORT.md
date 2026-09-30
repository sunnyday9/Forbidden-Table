# Stage 4 Responsiveness Evidence — Issue #95

**Evidence date:** 2026-09-30
**Disposition:** Fixed headless benchmark completed. The measured times are process-only WSL2 context, not game frame or input-latency results.

## Frozen candidate and versions

| Item | Value |
| --- | --- |
| Candidate commit | `9480fd404167a2ab1608959b14848d60866a4fab` |
| Project build version | `stage3-alpha-playable-1` |
| Default Stage 4 content bundle | `content.bundle.v1.alpha.act_two@v5+alpha.scale@v12+phase2@v4` |
| Fixed Hardening benchmark content bundle | `content.bundle.v1.alpha.act_two@v5+phase2@v4` |
| Game version | `game.phase2.v1` |
| SuspendSnapshot schema | `1` |
| ReplayRecord schema | `1` |
| SimulationManifest schema | `1` |
| Benchmark | `alpha.fixed-complete-run.v5` |
| Benchmark manifest hash | `45660c1211b41a1d8ca76972bd9c4bbdf0c159abd382dbf88d3a92611fb52557` |

The benchmark deliberately uses the existing `hardening` gate profile, which registers the Act Two bundle without the Scale bundle. The default production registry includes Scale. These are separately recorded so the benchmark's actual content identity is not confused with the candidate's default content bundle.

## Fixed headless benchmark

Exact command run from the repository root:

```sh
GODOT_BIN=/home/ubuntu/.codex/recovery/forbidden-table-review-remediation/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 python3 scripts/benchmark_alpha_fixed_run.py
```

The unchanged harness (`scripts/benchmark_alpha_fixed_run.py`) ran five repetitions, each as one complete Godot headless process including engine startup. Its internal process command uses `/usr/bin/time -f "%e %U %S %M"` and `scripts/alpha_fixed_run_attempt.gd`.

| Fixed workload/result | Value |
| --- | --- |
| Gate / seed / policy | `hardening` / `57002` / `Complete` |
| Character / contract / route | `base.character.reserve` / `base.contract.pool_bias` / `SERVICE` |
| Command limit | `1,024` |
| Runs | `5/5` completed with identical determinism fields |
| Accepted commands per run | `304` |
| Checkpoints per run | `305` |
| Terminal result | Act 2 reached; `VICTORY`; replay `MATCH`; failure classification `NONE` |
| Unavailable content paths | `0` |
| Median process wall time | `15.55 s` |
| Median process CPU time | `15.69 s` |
| Median peak process RSS | `398,924 KiB` |

The run exited `0`. These are five-run medians of whole-process measurements, including engine startup. They are observational context only; the harness defines no performance threshold. Its recorded comparison note also says the previous v4 timing is not directly comparable because Act 2 payloads and Complete-policy bounds changed.

**Execution context (coarse process context only):** Linux x86_64 under WSL2, kernel `6.6.87.2-microsoft-standard-WSL2`; Godot `4.7.2.stable.official.ed1daf0bf`, binary SHA-256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`. This does not identify or measure a native PC or Steam Deck.

## Domain and presentation responsiveness boundary

The existing presentation regression in [`tests/run_presentation_test.gd`](../tests/run_presentation_test.gd) exercises the real Complete Hand and authored Boss path in Normal, Fast, and Instant modes. It verifies that the Domain command returns an accepted result and authoritative checkpoint before feedback is refreshed, that Boss phase and victory resolver results/events are returned before their cues are rendered, and that Complete Hand → Boss phase → BattleWon ordering is preserved. The test also checks that RunScene renders the fallback cues as visible text. The Stage 4 presentation report records the focused `--presentation` command as passing on this candidate: [`STAGE_4_PRESENTATION_AUDIO_REVIEW.md`](STAGE_4_PRESENTATION_AUDIO_REVIEW.md).

Source ordering agrees with that regression: `RunPresentationController.submit()` calls `domain.execute(command)` before `_refresh(events)` emits the presentation update, and Run/Battle Domain code has no presentation, animation, or transition dependency. The presentation review found no animation/tween playback path. Critical feedback is therefore available synchronously after authoritative resolution; no visual animation or transition completion gates the state change. This is a state-ordering result, not a measured command-to-visible-feedback duration.

## Waived and unverified device measures

| Measure | Status |
| --- | --- |
| Native PC frame time | **WAIVED / UNVERIFIED — NOT MEASURED** |
| Native PC command-to-visible-feedback latency | **WAIVED / UNVERIFIED — NOT MEASURED** |
| Steam Deck frame time | **WAIVED / UNVERIFIED — NOT MEASURED** |
| Steam Deck command-to-visible-feedback latency | **WAIVED / UNVERIFIED — NOT MEASURED** |

The #57 native-device waiver remains in effect. No device-measurement reopening proposal or collection is included in this report. Reopening requires a separate maintainer decision that names the hardware, workload, measures, thresholds, owner, and schedule before collection. Nothing here marks native device performance as passed or measured.

## Defects and limits

The fixed harness reported no failed attempts, replay divergence, or unavailable content paths. The existing presentation regression supports the synchronous state/cue ordering described above. No defect was found within these checks. The benchmark does not measure interactive rendering, native responsiveness, physical-device behavior, or participant experience.
