# Stage 4.5 implemented-screen evidence

Maintainer implementation review is **pending**. Design approval was recorded on 2026-10-01 for V2.2; it does not close [#98](https://github.com/sunnyday9/Forbidden-Table/issues/98) or authorize release. Stage 5 remains **1.0 Release Candidate**.

Open [the offline gallery](gallery.html) to compare English, Simplified Chinese, text scale and viewport. Matching frames link to the preserved [Stage 4 before captures](../stage4_accessibility/); their source and historical limitations remain in the Stage 4 evidence report. The implemented behavior, ownership, approval and defect dispositions are in [the implementation record](../../STAGE_4_5_IMPLEMENTATION_RECORD.md). The approved reference is [the design package](../../design/stage4_5/README.md).

## Verification environment and provenance

Godot `4.7.2.stable.official.ed1daf0bf`, Linux under WSLg, Compatibility/OpenGL with the software `llvmpipe` renderer and Dummy audio. Graphical captures use the requested logical viewport with `CONTENT_SCALE_MODE_VIEWPORT` and `CONTENT_SCALE_ASPECT_KEEP`, independently of WSLg window-manager chrome/resizing; focused/default suites use the pinned headless engine. Unsupported V-Sync diagnostics from this driver are recorded in raw logs. No native PC/Steam Deck timing, physical controller, participant study or external accessibility conformance is claimed.

The implementation is in `codex/stage4-5-uiux-design`, based on approved design `91a1013` and Stage 4 PASS `0f565b9`; only the Stage 4.5 spec was carried from stale `9003451`. The engine's existing application build string `stage3-alpha-playable-1` is unchanged. Source hashes and commit provenance, rather than that historical application label, identify this implementation.

For the historical 2026-10-01 verification, the then-current C-drive checkout had unusually slow Linux filesystem access, so execution used `/tmp/forbidden-table-stage45-validation`. [source-manifest.json](source-manifest.json) records SHA-256 equality of all 412 runtime/source/test/asset files between the test mirror and checkout at verification, excluding generated UIDs, translations and Python caches. Changed task text is normalized to LF for Git/review afterward; `sha256_lf` verifies LF-normalized Git content against those tested bytes. Unchanged files keep their existing line endings. The mirror is a test transport, not a separate implementation. Each entry also records `sha256_lf`, which normalizes CRLF to LF for text files so the same content can be checked against LF-normalized Git blobs after normal checkout normalization; binary hashes are unchanged. Native Windows full-suite checks were unsuitable because existing corpus provenance tests require Linux `which` and GNU `timeout`.

## Coverage and retention

The capture probe traverses real Run/controller commands with a test-only Stage 4 registry: enemy HP 1, pressure limit 1000 and core damage 1 for bounded two-Act traversal; deliberate 13/14-tile hands and enemy HP 1000 for Pattern/Complete Hand inspection; gold 0/1000 for unavailable and available service states; Pressure Intent amount 1 and pressure limit 1 for guaranteed defeat. It uses isolated invalid save/profile files and a store that denies preservation for recovery error states. Production rules/content are unchanged. These are screen/input fixtures, not balance evidence or an unmodified human playthrough.

The matrix is English and Simplified Chinese × `960×540`, `1280×720`, `1280×800`, `1920×1080` × 100/125/150% text scale, plus English pseudo-localization with 30% expansion at `960×540` and all three scales: 27 cells. Each cell renders the 38 states listed in its manifest. Audits check text/control geometry, map label enclosure, tile recognition metadata, reachable scrolling and persistent selection focus. Screen coverage includes both Act maps, normal/Elite/Boss rewards, service confirmations, Battle/Pattern/Complete Hand/recovery, Settings/Help/tutorial variants, victory/defeat, resume/replace confirmation, and save/profile disclosure/manual-recovery states.

All frame PNGs are retained for English 100%, Chinese 100%, Chinese 150% and English pseudo 150% at `960×540`. Other cells retain Act 2 map, selected Complete Hand and language Settings images; every cell retains the complete manifest and raw log. `retained_capture_states` distinguishes the saved subset. The remaining raw images are reproducible with the checked-in probe; they are not represented as committed files. The gallery only links retained images.

## Reproduction

Use the pinned Linux executable and a Linux-readable checkout/mirror with identical source. After importing the project, run:

```bash
FT_GODOT='/path/to/Godot_v4.7.2-stable_linux.x86_64'
FT_PROJECT='/path/to/forbidden-table-checkout'
"$FT_GODOT" --headless --path "$FT_PROJECT" --editor --import
"$FT_GODOT" --headless --path "$FT_PROJECT" --script res://tests/run_tests.gd
"$FT_GODOT" --headless --path "$FT_PROJECT" --script res://tests/run_tests.gd -- --stage45-ui --stage4-accessibility --run-scene
"$FT_GODOT" --path "$FT_PROJECT" --audio-driver Dummy --script res://tests/stage45_capture_probe.gd -- --locale=zh_CN --scale=1.5 --viewport=960x540
"$FT_GODOT" --path "$FT_PROJECT" --audio-driver Dummy --script res://tests/stage45_capture_probe.gd -- --locale=en --scale=1.5 --viewport=960x540 --pseudo
python3 scripts/validate_localization.py
python3 -m unittest tests/localization_audit_test.py
```

Repeat the graphical command with each matrix locale/scale/viewport. Require exit 0, no script/load/assertion errors, 38 unique captures and empty layout/flow failures. The graphical probe needs a display and must not use `--headless`; `frame_post_draw` is the evidence boundary. It isolates presentation preferences and test save/profile paths and cleans its files.

The existing `scripts/test.sh` has CRLF line endings in this checkout. Direct pinned-engine invocation was used instead of changing that unrelated wrapper; the same `tests/run_tests.gd` entrypoint and default suites run.

For maintainer play review, use the F-only Windows launchers in `F:\Forbidden Table`: double-click `PLAY_FORBIDDEN_TABLE.cmd` to import and play, or `EDIT_FORBIDDEN_TABLE.cmd` to open Godot 4.7.2 and then press F5. The launchers scope `APPDATA`, `LOCALAPPDATA`, `TEMP` and `TMP` to the root project's ignored `.cache/windows/` folder, so Godot saves/preferences/editor cache and logs stay under the F-drive project. Directly starting the bare Godot exe does not inherit these settings. The previous project-specific Windows user data was relocated byte-for-byte into the new F-drive data folder. Choose English/简体中文, text scale, feedback mode and reduced motion in Settings; Apply saves these presentation preferences. Enter/Tab/arrows/Esc and controller A/B/D-pad/shoulders retain the existing mappings. Card focus or selection previews detail; the separate confirm button commits. Shop/Workshop purchases and replacing a suspended Run add review/cancel states.

The maintainer subsequently requested the current implementation directly in the root project. `F:\Forbidden Table\project.godot` now opens the Stage 4.5 implementation on `codex/stage4-5-primary-project`, based on `412b065`. The former research branch remains in Git history; unrelated local files and configuration edits were preserved. Use `F:\Forbidden Table\EDIT_FORBIDDEN_TABLE.cmd` to open the root project and keep runtime data on F. The maintainer authorized source publication on 2026-10-02; final implementation review and issue #98 remain open.

## Storage relocation (2026-10-02)

At the maintainer's instruction, the implementation worktree, cached resources, four local design captures and existing project-specific Windows user data were relocated under `F:\Forbidden Table`. The worktree retained implementation commit `05219b3`; 1,500 worktree files, four design captures and 49 user-data files were byte-verified before the old task-owned C-drive copies were removed. Unrelated files and worktrees were preserved. All subsequent project edits, artifacts and explicit logs use F-drive paths.

Native Windows Godot `4.7.2.stable.official.ed1daf0bf` passed the actual `PLAY_FORBIDDEN_TABLE.cmd --import-only` invocation (exit 0) and a separate headless storage probe (exit 0). The probe verified that data/config/cache/user-data paths and TEMP/TMP resolve under the F-drive worktree, then successfully wrote and removed a `user://` probe file. No script, parse or load errors appeared. Local verification logs are `.cache/f-only-import-console.log` and `.cache/f-only-storage-console.log`; engine logs are under `.cache/windows/logs/`. The prior full suite was not rerun, and no new human gameplay/performance result is claimed.

This location change does not alter the historical verification environment or rewrite the original capture/log provenance. The launcher/storage verification is separate from the original full-suite and screenshot evidence.

## Root-project promotion (2026-10-02)

The current implementation was checked out directly at `F:\Forbidden Table`, on `codex/stage4-5-primary-project` based on `412b065`. Existing local edits to `.gitignore` and editor formatting in `project.godot` were backed up under `.cache/main-checkout-promotion-2026-10-02/` and reapplied without dropping the new localization/autoload settings. Unrelated untracked files remained in place. The 49 existing project-specific user-data files were copied and byte-verified into the root project’s `.cache/windows/` folder. Six additional default Windows log/shader-cache files, created before promotion by a bare Godot launch, were also preserved and byte-verified under the F-drive backup before their old C-drive project folder was removed. Reopen Godot with the root editor launcher to retain F-only runtime storage.

Native Windows Godot `4.7.2.stable.official.ed1daf0bf` passed final import, main-scene headless startup (`--quit-after 120`), F-only storage paths/user-data write probe, and the focused `--stage45-ui --stage4-accessibility --run-scene` suites. The report records five UI modules, zero failures, and accessibility PASS. Initial import generated the missing locale resources; final import and validation logs contain no script, parse or load errors. All 411 non-configuration manifest files match the implementation tested previously; the only manifest difference is preserved editor formatting in `project.godot`. Verification logs and source proof are under `.cache/main-project-verification/` on F. The full suite and physical-device/human playtests were not rerun for this promotion. At the time of the root-project promotion, no push, issue closure or release had been performed.

## Source publication verification (2026-10-02)

The maintainer requested the recommended Beta documentation merge and source publication. The merged committed snapshot passed a fresh Linux Godot import, default full suite, focused UI/Run/accessibility checks, both 1,106-key locale catalogs and 17 Python localization tests. The first full-suite run exceeded the 600-second outer limit and is excluded; the successful rerun used a 1,800-second outer limit with unchanged source/assertions. See [the publication verification record](PUBLICATION_VERIFICATION_2026_10_02.md) for tested commit, raw logs, source proof and evidence limits. Source publication uses a draft PR; final implementation review/#98 and Stage 5 release gates remain pending.

## Fresh results

Completed on 2026-10-01 against the frozen implementation source represented by [source-manifest.json](source-manifest.json). All commands exited 0; final logs contain no script, load, assertion or ObjectDB teardown errors. Earlier interrupted/failed attempts are excluded.

| Check | Fresh result | Evidence |
|---|---|---|
| Godot import / parse / resource loading | PASS | [Import log](logs/godot-import.log) |
| Default full suite | PASS | [Full suite](logs/full-suite.log) |
| Stage 4.5 UI + Run scene + accessibility | PASS: five modules, zero failures; 12 phases, eight critical Battle action kinds; scripted keyboard/controller and actual mouse/motion checks | [Focused log](logs/focused-ui-accessibility.log) |
| Normal / Fast / Instant feedback | PASS: 57 critical cue states plus live cosmetic tween/cancellation regressions | [Focused log](logs/focused-ui-accessibility.log) |
| Locale catalog / typed placeholder audit | PASS: 1,106 keys per language; 1,006/1,006 stable source references; zero unresolved/locale errors | [Catalog audit](logs/localization-audit.log) |
| Python localization regressions | PASS: 17 tests | [Python log](logs/python-localization-tests.log) |
| Rendered layout / flow matrix | PASS: 27 cells × 38 states = 1,026 frames; zero layout/flow failures | [Matrix results](matrix-results.json) and per-cell logs/manifests |
| Source transport proof | PASS: 412 source/asset files match the tested mirror; LF-normalized hashes identify Git content | [Source manifest](source-manifest.json) |

The gallery retains 221 PNGs. Each manifest lists all 38 rendered states, image hashes and its retained subset. This is automated and rendered evidence; implemented-screen approval, human comprehension, native hardware performance and physical input testing remain unclaimed.

| Language | 960×540 | 1280×720 | 1280×800 | 1920×1080 |
|---|---|---|---|---|
| English | 100/125/150% PASS | 100/125/150% PASS | 100/125/150% PASS | 100/125/150% PASS |
| 简体中文 | 100/125/150% PASS | 100/125/150% PASS | 100/125/150% PASS | 100/125/150% PASS |
| English pseudo, 30% expansion | 100/125/150% PASS | — | — | — |
