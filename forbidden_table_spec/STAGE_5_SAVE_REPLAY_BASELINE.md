# Stage 5 — 1.0.0 Save and Replay Baseline

**Status:** Immutable RC1 fixtures captured; focused compatibility checks pass against the RC2 source target. Cross-patch verification remains unverified until a later 1.0.x candidate exists.

## Compatibility commitment

The public support window starts at 1.0.0 and covers supported 1.0.x patch updates. Pre-1.0 distributed formats and save downgrades are unsupported. Compatibility after 1.0.x remains undecided.

The fixtures below were captured with the pinned Godot engine from a clean source checkout at the frozen 1.0.0-rc.1 commit. They were not extracted from the exported ZIP; the hash-identified ZIP was built from that same source commit. The fixture hashes and exact source commit are pinned in the manifest and asserted by the compatibility test. These fixtures define the format baseline intended for public 1.0.0 if the release uses this candidate’s source, content, game, and schema identities. Private RC data may reset. Capturing a candidate fixture does not itself publish or establish a public release.

## Frozen candidate

| Identity | Value |
|---|---|
| Candidate version | **1.0.0-rc.1** |
| Source commit | 05b183e6825ccfa8c7674c493644bba2f3840e99 |
| Source tree dirty | No |
| Godot | 4.7.2.stable.official.ed1daf0bf |
| Game identity | game.phase2.v1 |
| Content identity | content.bundle.v1.alpha.act_two@v5+alpha.scale@v12+phase2@v4 |
| SuspendSnapshot / MetaProgress / ReplayRecord schema | 1 / 2 / 1 |
| Windows x64 package SHA-256 (built from this source commit) | 1c24a36d807866cd73533c9f17ab45860e2acdc945f6033b064518e32ecb1e1d |

## Immutable fixtures

The canonical-LF SHA-256 is checked before each fixture is decoded. Tests only open these paths for reading; they never regenerate or rewrite them.

| Source format | File | Canonical-LF SHA-256 | Coverage |
|---|---|---|---|
| SuspendSnapshot schema 1, game.phase2.v1, candidate content identity | [stage5_100_suspend_snapshot.json](../tests/fixtures/stage5_100_suspend_snapshot.json) | e88e3474903950bf2e6cc277f790591f6390bf2978f4e31c6ac936b13a6a1bbb | Stable Map Choice checkpoint; load, compare authoritative state and RNG, then issue Route and Draw commands and compare both continuation checkpoints and final RNG state. |
| ReplayRecord schema 1, game.phase2.v1, candidate content identity | [stage5_100_replay_record.json](../tests/fixtures/stage5_100_replay_record.json) | 8c7fab40e6ff327c5d55a8bb58581828ff6063049a545f85ef6decf2992c50fb | Two accepted Run commands; compare the complete recorded checkpoint sequence and terminal outcome when replay, game, and content identities match. |

The fixture metadata, expected checkpoint hashes, continuation result, and format policy are recorded in [stage5_compatibility_manifest.json](../tests/fixtures/stage5_compatibility_manifest.json).

## Replay policy and validation

The compatibility test always supplies the target content identity to ReplayVerifier.verify. Deterministic replay runs only when replay schema, game identity, and content identity all match. A mismatch, including a missing schema identity, is reported as UNAVAILABLE before the replay factory is called.

On each later 1.0.x candidate, run the full suite so every manifest-listed save fixture is loaded through SaveMapper.load_into_domain and continued using public Run commands, and every replay fixture is checked under the identity policy above. If an updated target cannot load and continue an earlier supported save, add the required explicit schema/content migration before accepting that candidate. Do not rewrite old fixtures to make a new target pass.

Focused and full automated checks passed on the current source target, whose project version is 1.0.0-rc.2:

- GODOT_BIN=<Godot 4.7.2 binary> ./scripts/test.sh --persistence
- GODOT_BIN=<Godot 4.7.2 binary> ./scripts/test.sh --replay
- GODOT_BIN=<Godot 4.7.2 binary> ./scripts/test.sh

The source baseline is the frozen RC1 candidate; the target is the current RC2 source diff. RC2 is not a frozen owner RC, so these checks do not establish owner approval. They do not prove cross-patch compatibility because no later 1.0.x candidate exists yet. Windows 10/11 launch and the private RC gate remain separate Stage 5 evidence.

The current RC2 full-suite verification target is source commit `9279e9070ee45d4298c01ea260a141be8aacc374` with no tracked or untracked changes reported by Git. The exact package and corpus identities, plus the remaining RC gate limits, are listed in [Stage 5 RC2 Candidate Evidence](STAGE_5_RC2_EVIDENCE.md).
