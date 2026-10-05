# Stage 5 — Guided Sample Evidence

**Status:** Scripted flow and isolation checks **PASS**. Player comprehension **UNVERIFIED**. Physical-device usability **UNVERIFIED**.

## Build and test identity

| Item | Value |
|---|---|
| Tested source commit | `bff2bebbbf76cffbe6583dd82eb210e7998ed672` |
| Application version | `1.0.0-rc.2` |
| Godot | `4.7.2.stable.official.ed1daf0bf` |
| Focused command | `GODOT_BIN=<pinned Godot 4.7.2 binary> ./scripts/test.sh --guided-sample` |
| Focused result | **PASS** — isolated Guided Sample lifecycle, action-gating, and persistence tests |
| Full-suite command | `GODOT_BIN=<pinned Godot 4.7.2 binary> ./scripts/test.sh` |
| Full-suite result | **PASS** at `5b52f63`; `bff2beb` changes only Windows export exclusions, not the sample or its tests |
| Localization audit | **PASS** — `python3 scripts/validate_localization.py`: 1,076/1,076 stable keys; 1,203 English and Simplified Chinese entries; 0 unresolved items |
| Audit unit tests | **PASS** — `python3 -m unittest tests.localization_audit_test`: 21 tests |

All Godot tests were run with `--headless`.

## Scripted acceptance coverage

`tests/guided_sample_test.gd` verifies:

- The sample uses a separate one-Act Run controller, map, content registry, and no campaign save or meta-progression adapters.
- The short route is reachable and covers the authored Character, Contract, map, Battle, reward, Event, Shop, and Workshop sequence.
- Only accepted instructed actions advance a step; unrelated or rejected actions do not satisfy it, and Complete Hand does not satisfy the Pattern lesson.
- `test_sample_replay_reconstructs_its_authored_map` verifies deterministic replay through entry into the first Battle (before any Battle action). The separate full-route test uses real Run actions through completion and exercises the required Battle decisions; it does not assert replay after the final step.
- Entry, restart, skip, cancel, and exit preserve the suspended campaign domain, save file, and profile state.
- Scene-level input tests exercise keyboard accept/cancel and Joypad accept/cancel. The full suite passes its localization-runtime and interface checks; the separate localization audit above reports complete stable-key extraction for English and Simplified Chinese.

## Evidence limits

- **Player comprehension: UNVERIFIED.** No external player study was approved or run. Passing a scripted sequence shows mechanical progression and isolation, not that a new player understands the terms or decisions.
- **Physical-device usability: UNVERIFIED.** Input checks use simulated events; no physical keyboard, mouse, or controller session was performed.
- Windows 10/11 owner validation remains part of the separate private RC gate.
