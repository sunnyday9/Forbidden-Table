# Stage 3 Alpha and Stage 4 Beta save/replay compatibility matrix

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

## Stage 4 Beta support window

Evidence checked on 2026-09-29 for issue #88. The earliest supported source
boundary is the Phase 2 v1 baseline required by #45. The continuous compatibility
window includes every player-distributed Alpha format from Alpha support,
preserves the #45 Alpha guarantee through Alpha exit, and carries those formats
forward along with every Stage 4 Beta format distributed before the Stage 4 Beta
exit decision. The guarantee ends at Beta exit. GitHub Releases and tags contain
no distribution artifacts as of this check, and no out-of-band Alpha/Beta save
or replay artifact was identified in the repository or upstream issue context.
Therefore the only historical source format evidenced/carried into this window
is the Phase 2 v1 suspend baseline mandated by #45; this is a compatibility
baseline, not a claim that a public build was distributed. Test-generated
content identities below are not distribution evidence.

The machine-readable [Stage 4 Beta compatibility manifest](../tests/fixtures/stage4_beta_compatibility_manifest.json)
pins canonical-LF source-fixture SHA-256 hashes and candidate record versions.
The hash check normalizes CRLF to LF so Windows `core.autocrlf` checkout
conversion does not produce a false failure; it does not modify the historical
fixtures or their Git blob contents.

The frozen Phase 2 v1 source fixtures are [typed stable MAP_NODE baseline](../tests/fixtures/phase2_v1_suspend_snapshot.gd),
[serialized stable checkpoint](../tests/fixtures/phase2_v1_serialized_suspend_snapshot.json),
[archived-validator-accepted checkpoint](../tests/fixtures/phase2_v1_archived_valid_suspend_snapshot.json),
and [typed pending Boss REWARD checkpoint](../tests/fixtures/phase2_v1_boss_reward_suspend_snapshot.gd).

| Record | Supported source format and fixture | Candidate schema | Candidate game/content identity | Handling |
| --- | --- | --- | --- | --- |
| SuspendSnapshot | `schema_version=1`, `game.phase2.v1`, `content.slice.v1`; the four Phase 2 v1 fixtures listed in the manifest. No other player-distributed Alpha/Beta suspend format is evidenced as of this check. | `1 -> 1` for schema; no schema step is required. | Default RunScene: `content.bundle.v1.alpha.act_two@v5+alpha.scale@v12+phase2@v4` (`ACT_TWO_SCALE_V13`). Act Two without Scale: `content.bundle.v1.alpha.act_two@v5+phase2@v4` (`ACT_TWO_V5`). | The explicit Phase 2 v1 content migration targets the selected registry and leaves the source DTO and fixture bytes unchanged. Schema migration never changes `content_version`. Unsupported or semantically unverifiable sources are rejected and preserved. |
| MetaProgressSnapshot | Schema-v1 input is source-defined by the existing migration test; no immutable fixture or player distribution is evidenced. | `1 -> 2`, the current candidate schema. The existing `MigrationPipeline` runs its registered step in sequence. | `game.phase2.v1` / `alpha.meta.v1`. | The schema step preserves `content_version`; unknown content/schema versions fail closed, and rejected source bytes remain unchanged. Freeze an immutable pre-migration artifact before any such format is distributed. |
| ReplayRecord | Schema-v1 record format is source-defined; no player-distributed replay artifact or immutable replay fixture is evidenced. | `1 -> 1`; no replay schema migration is currently needed. | `game.phase2.v1`; replay retains its recorded content identity and is verified only against that exact content/rules version. | Unsupported game, schema, or content versions report reproduction unavailable. Records are not relabeled or rewritten when the matching bundle is unavailable. |

The Phase 2 v1 suspend source and candidate boundary coverage is exercised by
`--persistence` (including source immutability, explicit content migration,
RNG continuation, and a pending Boss reward fixture) and `--run-scene` (the
default full registry and unsupported-source preservation). Stable-boundary
Suspend/Resume is covered by reward type: Normal Reward Choice (`--reward-economy`),
Elite draft (`--elite-reward`), Boss Rule Breaker draft (`--boss-rule-breaker-reward`),
and the Act 1 reward-to-Act 2 map transition plus Act 2 Boss reward (`--map`).
The source-defined MetaProgress migration is exercised by `--meta-progress`;
exact replay version rejection and checkpoint/RNG/event/outcome matching are
exercised by `--replay`. These existing seams cover the behavior; this issue
adds no persistence or replay runtime system.

Verification commands for this matrix update (pinned Godot 4.7.2):

```sh
GODOT_BIN=/home/ubuntu/.codex/recovery/forbidden-table-review-remediation/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 ./scripts/test.sh --persistence
GODOT_BIN=/home/ubuntu/.codex/recovery/forbidden-table-review-remediation/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 ./scripts/test.sh --meta-progress
GODOT_BIN=/home/ubuntu/.codex/recovery/forbidden-table-review-remediation/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 ./scripts/test.sh --replay
GODOT_BIN=/home/ubuntu/.codex/recovery/forbidden-table-review-remediation/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 ./scripts/test.sh --map
GODOT_BIN=/home/ubuntu/.codex/recovery/forbidden-table-review-remediation/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 ./scripts/test.sh --run-scene
GODOT_BIN=/home/ubuntu/.codex/recovery/forbidden-table-review-remediation/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 ./scripts/test.sh --reward-economy
GODOT_BIN=/home/ubuntu/.codex/recovery/forbidden-table-review-remediation/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 ./scripts/test.sh --elite-reward
GODOT_BIN=/home/ubuntu/.codex/recovery/forbidden-table-review-remediation/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 ./scripts/test.sh --boss-rule-breaker-reward
```

Result: PASS for all eight commands. The Phase 2 fixture integrity assertions
run as part of `--persistence`; the individual suites cover the compatibility seams.
The full project suite, player-duration testing, the 1,000-case corpus, and
Beta/release gates are outside this issue's verification claim.
