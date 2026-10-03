# Publication verification — 2026-10-02

The maintainer requested the recommended Stage 4 documentation merge and source publication on 2026-10-02. The publication target is a draft pull request from `codex/stage4-5-primary-project` into `main`. Final Stage 4.5 implementation review remains pending; #98 remains open. Stage 5 remains **1.0 Release Candidate**. No release/tag or automatic merge into `main` is part of this publication.

## Merged content and tested source

`881192d70e7d9dcb2107b16bb6a3b2990d2acd1e` merged `research/stage4-alpha-inventory` into the implementation branch. The first-parent diff adds only `STAGE_4_BETA_INVENTORY.md` and `STAGE_4_BETA_SPEC.md`. The branch also contains Stage 4 PASS `0f565b9` and Stage 4.5 implementation `05219b3`.

Checks ran against a `git archive` snapshot of that exact merged commit at `F:\Forbidden Table\.cache\publication-2026-10-02\snapshot`. All 412 files in the historical runtime/source/test/asset manifest match their recorded hashes. Generated translations were bootstrapped from the matching root catalogs and reimported. User-data/cache/temp paths are scoped to `.cache/publication-2026-10-02/` under F. Original local configuration edits, unrelated untracked files and other worktrees were preserved and excluded from publication.

The verification engine is Linux Godot `4.7.2.stable.official.ed1daf0bf`, headless under WSL. Direct engine commands use `--headless --path <snapshot>`; import adds `--editor --import`, full suite adds `--script res://tests/run_tests.gd`, and focused checks add `-- --stage45-ui --stage4-accessibility --run-scene`. Python checks are `python3 scripts/validate_localization.py` and `python3 -m unittest tests/localization_audit_test.py`.

## Fresh results

| Check | Result | Evidence |
|---|---|---|
| Godot import / parse / resource loading | PASS (exit 0) | [Log](publication_2026_10_02/logs/godot-import.log) |
| Default full suite | PASS (exit 0) | [Log](publication_2026_10_02/logs/full-suite.log) |
| UI, Run scene and accessibility (5 modules; 0 failures) | PASS (exit 0) | [Log](publication_2026_10_02/logs/focused-ui-accessibility.log) |
| EN/SC catalogs (1,106 each; 1,006/1,006 stable keys) | PASS (exit 0) | [Log](publication_2026_10_02/logs/localization-audit.log) |
| Python localization regressions (17 tests) | PASS (exit 0) | [Log](publication_2026_10_02/logs/python-localization.log) |

[Execution results](publication_2026_10_02/results.json) record the outer limits and headless wall-clock durations. [Source proof](publication_2026_10_02/source-proof.json) identifies the tested commit and matching manifest count. Durations are verification context, not native game-performance measurements.

The first full-suite attempt reached the 600-second wrapper limit on the F-mounted filesystem before completion. It is excluded from passing evidence. The successful full-suite rerun used a longer outer execution limit without changing source, test assertions, or internal corpus bounds. Final logs have no script, parse, compile or load errors.

## Preserved evidence and limits

The 2026-10-01 default/focused tests and 27 × 38 = 1,026 rendered-frame matrix remain in [the screen evidence package](README.md); they were not recaptured during publication. Native Windows root-project import/startup/F-only storage and focused checks passed on 2026-10-02 as recorded there. Publication did not rerun the 1,000-run corpus, physical controller testing, participant studies, or native PC/Steam Deck performance measurements. No external accessibility conformance is claimed.

GitHub Stage 4 issues #72, #92 and #96 were freshly confirmed closed; #98 was confirmed open. The publication PR includes the documentation from #97 and leaves maintainer review and Stage 5 gates explicit.
