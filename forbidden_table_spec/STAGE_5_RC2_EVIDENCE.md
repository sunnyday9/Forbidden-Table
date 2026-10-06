# Stage 5 — RC2 Candidate Evidence

**Evidence assembled:** 2026-10-06

**Candidate:** `1.0.0-rc.2`
**Status:** Automated source/package checks and the seeded simulation subgate **PASS**. Private Windows owner validation **UNVERIFIED**. This is not a public-release go/no-go.

## Frozen candidate identity

| Item | Value |
|---|---|
| Source commit | `9279e9070ee45d4298c01ea260a141be8aacc374` (`fix(stage5): reject coerced corpus resume arguments`) |
| Source tree | `source_dirty=false` in the package manifest; Git worktree was clean when evidence was assembled |
| Project version | `1.0.0-rc.2` |
| Godot | `4.7.2.stable.official.ed1daf0bf` |
| Game identity | `game.phase2.v1` |
| Content identity | `content.bundle.v1.alpha.act_two@v5+alpha.scale@v12+phase2@v4` |
| Save schemas | Suspend `1`; Meta Progress `2` |
| Replay schema | `1` |
| Platform package | `windows-x86_64` portable ZIP |
| RC ZIP SHA-256 | `3c460f48d5556778da18cd9ef80621d61cd400fd6e68342141f2bfa0a86600f6` |
| Runtime source snapshot SHA-256 | `55184c663c7f4a0cd8290e9a943f7a568c14a6d0de97afd0f6e571c276ac69c5` (262 hashed paths) |

The package was built twice from the same commit; both ZIPs were 72,413,416 bytes and had the same hash above. The ZIP integrity check passed. It contains `ForbiddenTable.exe`, `ForbiddenTable.pck`, and `README.txt`. The build manifest and checksum are preserved beside this report in [`evidence/stage5/`](evidence/stage5/).

The corpus report has a field named `base_git_revision` set by a constant to `54a8d09635a6ab136ac3c1ce10bca4508799053b`. That is the corpus's historical baseline identifier, **not** the commit tested for RC2. The corpus ran from the clean RC2 worktree at `9279e9070ee45d4298c01ea260a141be8aacc374`; each of its 262 recorded source-file hashes matches that worktree. Its recorded source-file list includes the ignored generated file `scripts/__pycache__/validate_localization.cpython-312.pyc`; the Windows ZIP has no `.pyc` entry. The source-snapshot digest therefore identifies the exact test worktree, while the package checksum identifies the actual ZIP.

## Automated verification

All Godot execution used headless mode. The fresh checks on the RC2 source passed:

| Check | Result |
|---|---|
| `GODOT_BIN=<pinned Godot 4.7.2 binary> ./scripts/test.sh` | **PASS** — full runtime, content, presentation, Guided Sample, save/replay, localization-runtime, and Stage 4 regression suite |
| `GODOT_BIN=<pinned Godot 4.7.2 binary> ./scripts/test.sh --alpha-gate-corpus-resume` | **PASS** — package CLI resume path and rejection of non-string resume arguments |
| `python3 tests/test_windows_release_package.py` | **PASS** — 15 package CLI tests |
| `python3 scripts/validate_localization.py` | **PASS** — 1,076/1,076 stable keys; 1,203 entries in English and Simplified Chinese; no unresolved items |
| `python3 -m unittest tests.localization_audit_test` | **PASS** — 21 tests |
| Two Windows package builds from commit `9279e90` | **PASS** — byte-identical ZIPs; SHA-256 above |

The immutable RC1 save and replay fixtures were rechecked against the RC2 source through `SaveMapper.load_into_domain`, continued Run commands, and `ReplayVerifier.verify`. Replay is deterministic only when game, content, and schema identities match; otherwise it is reported unavailable. No later 1.0.x candidate exists, so cross-patch compatibility remains **UNVERIFIED**. See [the save/replay baseline](STAGE_5_SAVE_REPLAY_BASELINE.md).

The Guided Sample's scripted path, action gating, and campaign-state isolation pass. Player comprehension and physical-device usability remain **UNVERIFIED**; scripted coverage is not a player study. See [Guided Sample evidence](STAGE_5_GUIDED_SAMPLE_EVIDENCE.md).

## Fixed 1,000-case two-Act simulation subgate

The headless corpus covered seeds `57000`–`57999`, with two executions per case. It completed all 50 twenty-case chunks; all chunk processes and the finalizer exited `0`, and all chunk output hashes matched their status sidecars.

The generated `final-report.md` labels `600` seconds as the per-chunk process timeout. That value came from the separate finalizer invocation: every chunk's verified sidecar records a `4,830` second GNU timeout with a 30 second kill-after, while the finalizer sidecar records `600` seconds. No chunk or finalizer timed out. Treat the raw chunk sidecars in the evidence archive as authoritative for chunk bounds; the generated report's timeout label is a reporting defect to correct before the next corpus run.

| Measure | Result |
|---|---:|
| Cases / repeated comparisons | 1,000 / 1,000 exact matches |
| Simulation gate | **PASS** (`simulation_gate_pass=true`, eligible evidence) |
| Failure classifications / invalid authoritative states | 0 / 0 |
| Content unavailable / gate validation errors | 0 / 0 |
| Visible outliers / repeat divergences | 0 / 0 |
| Act 2 reached | 665 cases |
| Act 2 Boss reward-to-summary boundary | Covered |
| Act 2 three-choice Boss reward path | Covered |
| Terminal outcomes | 530 defeats; 470 victories |
| Attempt watchdog | 120 seconds; longest observed attempt 16.292 seconds |

There is no win-rate or performance target in this gate. Elapsed attempt time is only a watchdog diagnostic. The output records no content-owner outlier disposition because the corpus found no visible outliers. The preserved [`rc2-corpus-evidence.tar.gz`](evidence/stage5/rc2-corpus-evidence.tar.gz) contains all chunk JSONL files and process-status sidecars, the manifest, final summary and status, generated report, and captured corpus/finalizer logs. Its SHA-256 is recorded in the adjacent `.sha256` file.

Godot printed shutdown diagnostics (`2 ObjectDB instances were leaked` and `1 resources still in use`) after each short-lived corpus process. All 50 chunk processes and the finalizer nevertheless returned `0`, produced hash-verified outputs, and reported no attempt timeout. A fresh source review traced the retained reference to the static `GnuTimeoutLocator` cache and Godot static-script lifetime; this is recorded as a tooling warning, not silently treated as absent or as a corpus failure.

## Gate status and remaining work

| Gate area | Status | Evidence boundary |
|---|---|---|
| Exact source, engine, content, save/replay identity | **PASS** | Frozen identities above; source snapshot and package hash recorded |
| Windows export/package CLI | **PASS** | 15 tests and two byte-identical package builds |
| Current-source full test, localization, content, and regression checks | **PASS** | Commands and results above; Godot was headless |
| Fixed 1,000-seed simulation subgate | **PASS** | Exact repeats, Act 2 boundaries, hash-verified chunks, and no visible outliers |
| RC1 save/replay fixtures on matching RC2 identities | **PASS** | Focused fixture and full-suite evidence |
| Compatibility across a later 1.0.x patch | **UNVERIFIED** | No later patch candidate exists yet |
| Guided Sample scripted actions and isolation | **PASS** | Automated sequence only |
| Player comprehension / external user feedback | **UNVERIFIED** | No participant testing is planned for the private RC |
| Windows 10 x64 native launch and full owner smoke test | **UNVERIFIED** | Must be run by the maintainer on Windows 10 x64 |
| Windows 11 x64 native launch and full owner smoke test | **UNVERIFIED** | Must be run by the maintainer on Windows 11 x64 |
| Current P0/P1 and P2 owner disposition audit | **UNVERIFIED** | This report does not replace the maintainer's issue/severity disposition |
| Public-source/license readiness and go/no-go | **BLOCKED BY OWNER DECISION** | License remains deferred as agreed; repository must stay private until resolved |
| Public GitHub Release | **NOT PUBLISHED** | Separate explicit public go/no-go and post-visibility download checks remain required |

At evidence capture, GitHub issues [#102–#107](https://github.com/sunnyday9/Forbidden-Table/issues) were still open, and `sunnyday9/Forbidden-Table` remained private. This evidence commit does not close or comment on issues, change visibility, or publish a release.

The maintainer's next RC action is to extract and test the exact ZIP on Windows 10 x64 and Windows 11 x64: launch, settings and resolution behavior, the Guided Sample, a normal two-Act Run, save/resume, completion, and clean exit. Record the exact Windows builds and findings against this hash. A later patch must separately load and continue the immutable 1.0.0 fixtures before a 1.0.x compatibility claim is made.
