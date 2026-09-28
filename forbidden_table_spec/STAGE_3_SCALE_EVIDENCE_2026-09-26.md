# Stage 3 Scale subgate evidence — 2026-09-26

**Result:** the seeded simulation Scale subgate passed. This is not a Hardening
decision, native-device result, human-study result, Alpha Exit, or Stage 4
authorization. The current [scope decision](STAGE_3_PRE_MVP_SCOPE_DECISION.md)
waives native-device evidence for the initial MVP and schedules any participant
study after release; this report does not claim either result exists.

## Run and artifact

- Project: `/mnt/f/Forbidden Table`
- Godot: `4.7.2.stable.official.ed1daf0bf`
- Gate: `scale`, full 1,000-case corpus; starting-pool fixture
  `phase2.character_biased_complete_hand.v1`
- Manifest hash: `2342bd8136907cae5657d28e0717595f6b6b0dcebb06368ce03370056c1a4842`
- Corpus output: `.cache/alpha_gate_corpus/scale-2026-09-26-contract-effects-resumed.jsonl`
  (local ignored artifact; 1 header + 1,000 case records + 1 summary; 4,624,585,025 bytes)
- Corpus SHA-256:
  `5385d0147a489d1d92d5fa610f57a647558e976b6238d324f5c8c5137b3cf5eb`
- The interrupted earlier output
  `.cache/alpha_gate_corpus/scale-2026-09-26-contract-effects.jsonl` was
  retained unchanged as the resume source. The completed report is a separate
  output.

Invocation:

```sh
timeout 14400 '.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64' \
  --headless --path '/mnt/f/Forbidden Table' \
  --script res://scripts/run_alpha_gate_corpus.gd -- \
  --full --gate scale \
  --resume-from '/mnt/f/Forbidden Table/.cache/alpha_gate_corpus/scale-2026-09-26-contract-effects.jsonl' \
  --output '/mnt/f/Forbidden Table/.cache/alpha_gate_corpus/scale-2026-09-26-contract-effects-resumed.jsonl'
```

## Aggregate

- `run_state=COMPLETE`; `attempts_executed=1000/1000`;
  `simulation_gate_status=PASS`; gate evidence is eligible.
- Exact deterministic repeats: `1000/1000 MATCH`; repeat divergences: `0`.
- Distinct attempts: `1000`; attempt failures, invalid attempts, profile errors,
  unavailable content IDs, crashes, and unexplained replay divergence: `0`.
- Strategy distribution: Partial `334`, Complete `333`, Hybrid `333`.
- Terminal outcomes: 304 valid victories and 696 valid defeats. Defeat is a
  valid correctness outcome; no win-rate threshold is inferred.
- Observed and required coverage matched for both Acts, both Boss outcomes,
  both Act/Boss boundaries, all three strategies, and all five declared reward
  paths, including the Act 2 three-choice Boss reward and its transition to
  Run Summary.

The Stage 3 Scale catalog declares three Characters and six Contracts. The
manifest required and the report observed these exact IDs:

- Characters: `alpha.character.harbor_reader`,
  `base.character.reserve`, `base.character.sequence`.
- Contracts: `alpha.contract.brittle_compass`,
  `alpha.contract.open_ledger`, `alpha.contract.quiet_current`,
  `base.contract.pool_bias`, `base.contract.pressure`,
  `base.contract.refinement_debt`.

The report's `alpha_full_roster_claim` field is `false` by the aggregator's
conservative policy: it reports only coverage against an explicitly declared
matrix and does not infer undeclared content. Here the available, required, and
observed Scale IDs above match the Stage 3 catalog's 3-Character/6-Contract
roster exactly; this evidence makes no claim beyond those declared IDs.

## Validation and limits

- `scripts/test.sh --alpha-scale --run-scene --run-domain --elite-reward --shop-workshop` — passed.
- `scripts/test.sh` — `PASS: full domain, presentation, and Intent Graph test suite`.
- `git diff --check` — passed.
- Godot MCP confirmed the project at the path above and version above. Its
  `run_project` call returned “Godot project started in debug mode,” but the
  immediate debug-output query returned “No active Godot process”; the MCP
  launch is not counted as validation. The headless test suites above are the
  successful automated validation.

This report contains no native-device or invited-human results. Native-device
evidence is waived for the initial MVP scope; the participant study is a
post-release follow-up. The simulation report covers only the seeded Scale
subgate and is not the maintainer's Hardening or Alpha Exit decision. Those
separate decisions are recorded in [#57](https://github.com/sunnyday9/Forbidden-Table/issues/57#issuecomment-5843868297)
and [#69](https://github.com/sunnyday9/Forbidden-Table/issues/69#issuecomment-5843875181):
Readiness/Hardening passed under the scope waiver, and Stage 3 Alpha Exit passed
with Stage 4 authorized. Neither decision claims device or human evidence.
