# Stage 3 Alpha save/replay compatibility matrix

Evidence checked on 2026-09-23 for issue #54. This matrix distinguishes a
format defined by the source/spec from a format known to have been distributed
to players; repository tests that construct DTOs are not distribution evidence.

| Record format | Source-defined version | Player-distribution evidence | Frozen fixture and required handling |
| --- | --- | --- | --- |
| SuspendSnapshot | `schema_version=1`, `game_version=game.phase2.v1`, `content_version=content.slice.v1` | The Phase 2 v1 stable checkpoint is the compatibility baseline required by #54. The originally reported raw JSON bytes were not present in the repository or available in the current task attachments. | `tests/fixtures/phase2_v1_suspend_snapshot.gd` preserves the typed baseline; `tests/fixtures/phase2_v1_serialized_suspend_snapshot.json` is a valid stable DTO serialized by archived Phase 2 v1 `SaveCoordinator`; `tests/fixtures/phase2_v1_boss_reward_suspend_snapshot.gd` preserves the stable pre-draft Boss checkpoint. Explicit fixture-tested content migration only; schema migration does not change `content_version`. |
| MetaProgressSnapshot | Schema v1 DTO defined by Phase 2; `game_version` is in the envelope. | No player-distributed MetaProgressSnapshot artifact is evidenced in the repository. The DTO's construction in unit tests is not distribution evidence. GitHub Releases and repository tags were both empty when checked. | No distributed-format fixture is claimed. Freeze an immutable pre-migration fixture before changing any format that is later distributed. |
| ReplayRecord | Schema v1 DTO with `game_version=game.phase2.v1` and a record-pinned `content_version`, as required for version validation. | No player-distributed ReplayRecord artifact is evidenced in the repository. Runtime/unit-test records are not distribution evidence. GitHub Releases and repository tags were both empty when checked. | No distributed-format fixture is claimed. Preserve each record's original content/rules version; verify only with its matching bundle or report reproduction unavailable without changing the record. Freeze a fixture before changing any format that is later distributed. |

## Version-field boundary

The immutable Phase 2 DTO envelope includes `schema_version`, `game_version`,
and `content_version`; it does not define a persisted `engine_version` field
(`PHASE_2_SPEC.md` §11.1 and `PROJECT_SPEC.md` §23.2). Compatibility validation
therefore tests the existing `game_version` contract and does not add an
`engine_version` field to the v1 format.

The application retains its single-continuation-save contract. No additional
save slots or rollback formats are introduced by this matrix.
