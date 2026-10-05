class_name AlphaSimulationTest
extends RefCounted

const SimulationManifestScript = preload("res://src/infrastructure/simulation/simulation_manifest.gd")
const AlphaAttemptComparatorScript = preload("res://src/infrastructure/simulation/alpha_attempt_comparator.gd")
const AlphaFailureClassifierScript = preload("res://src/infrastructure/simulation/alpha_failure_classifier.gd")
const AlphaSimulationRunnerScript = preload("res://src/infrastructure/simulation/alpha_simulation_runner.gd")
const AlphaSimulationStartingPoolFixtureScript = preload("res://src/infrastructure/simulation/alpha_simulation_starting_pool_fixture.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_gate_manifest_is_stable_and_does_not_overclaim_roster_coverage(failures)
	test_repeated_attempts_compare_authoritative_trace_not_machine_timing(failures)
	test_valid_defeat_and_harness_failures_are_classified_separately(failures)
	test_act_two_boss_reward_gap_is_content_unavailable_not_a_soft_lock(failures)
	test_runner_emits_a_real_replayable_run_attempt(failures)
	test_stage4_beta_case_00686_reaches_a_valid_run_ending(failures)
	test_hybrid_discards_excess_hand_with_bounded_work(failures)
	test_complete_discards_when_reserve_is_full_and_hand_grows(failures)
	test_runner_content_version_tracks_conditional_scale_bundle(failures)
	test_complete_policy_completes_real_two_act_run_and_reward_flow(failures)
	test_act_two_seed_57001_is_a_replayable_victory_within_draw_budget(failures)
	test_runner_ends_turn_when_draw_sources_are_empty(failures)
	test_service_route_reaches_a_workshop(failures)
	return failures

func test_gate_manifest_is_stable_and_does_not_overclaim_roster_coverage(failures: Array[String]) -> void:
	var config := {
		"schema_version": 1,
		"content_version": AlphaSimulationRunnerScript.content_version_for_gate("hardening"),
		"gate_profiles": [{
			"gate_id": "hardening",
			"attempt_count": 6,
			"seed_start": 7300,
			"policy_ids": ["Partial", "Complete", "Hybrid"],
			"character_ids": Phase2CatalogScript.CHARACTER_IDS,
			"contract_ids": Phase2CatalogScript.CONTRACT_IDS,
			"route_ids": ["SHOP_WORKSHOP", "EVENT"],
			"required_character_ids": Phase2CatalogScript.CHARACTER_IDS + ["alpha.character.not-authored"],
			"required_contract_ids": Phase2CatalogScript.CONTRACT_IDS + ["alpha.contract.not-authored"],
			"required_act_boundaries": ["ACT_1_BOSS_REWARD_TO_ACT_2", "ACT_2_BOSS_REWARD_TO_SUMMARY"],
			"required_reward_paths": ["NORMAL_REWARD", "ELITE_REWARD", "BOSS_RULE_BREAKER"],
		}],
	}
	var first = SimulationManifestScript.new(config, Phase2CatalogScript.CHARACTER_IDS, Phase2CatalogScript.CONTRACT_IDS)
	var repeated = SimulationManifestScript.new(config, Phase2CatalogScript.CHARACTER_IDS, Phase2CatalogScript.CONTRACT_IDS)
	var first_data: Dictionary = first.to_dictionary()
	var gate: Dictionary = first_data.get("gates", {}).get("hardening", {})
	var cases: Array = gate.get("cases", [])
	var policy_counts := {"Partial": 0, "Complete": 0, "Hybrid": 0}
	for attempt_case in cases:
		var policy_id: String = str(attempt_case.get("policy_id", ""))
		if policy_counts.has(policy_id):
			policy_counts[policy_id] += 1

	assert_true(first.is_valid(), "a gate-specific simulation manifest accepts supported policy and coverage dimensions", failures)
	assert_true(first.serialize() == repeated.serialize(), "the same seed and gate inputs produce byte-stable manifest serialization", failures)
	assert_true(first.manifest_hash() == repeated.manifest_hash(), "the same seed and gate inputs produce the same manifest hash", failures)
	assert_true(first_data.get("starting_pool_fixture_id", "") == AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID, "the simulation manifest pins its harness-only starting-pool fixture", failures)
	assert_true(cases.size() == 6, "the manifest schedules the configured number of runs for this gate", failures)
	assert_true(cases[0].get("starting_pool_fixture_id", "") == AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID, "each scheduled attempt carries the starting-pool fixture identity", failures)
	assert_true(policy_counts == {"Partial": 2, "Complete": 2, "Hybrid": 2}, "the manifest distributes runs across all three configured strategies", failures)
	assert_true(gate.get("required_act_boundaries", []).size() == 2, "each gate carries its own declared Act and Boss-boundary coverage", failures)
	assert_true(gate.get("available_reward_paths", []).has("BOSS_RULE_BREAKER"), "the baseline manifest reports implemented Boss rewards as available", failures)
	assert_true(gate.get("available_reward_paths", []).has("ACT_1_BOSS_RULE_BREAKER_THREE_CHOICES"), "the baseline manifest reports the implemented Act 1 three-choice draft as available", failures)
	assert_true(gate.get("available_reward_paths", []).has("ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"), "the baseline manifest reports the Act 2 three-choice reward as available for Hardening", failures)
	assert_true(not gate.get("not_yet_introduced_reward_paths", []).has("ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"), "the available Act 2 reward is not classified as not-yet-introduced", failures)
	assert_true(not gate.get("not_yet_introduced_content_ids", []).has("alpha.act_two.boss_rule_breaker_pool"), "the Act 2 Boss reward pool is not left in the unavailable ID list", failures)
	assert_true(gate.get("missing_character_content_ids", []) == ["alpha.character.not-authored"], "unavailable Alpha Character content remains an explicit coverage gap", failures)
	assert_true(gate.get("missing_contract_content_ids", []) == ["alpha.contract.not-authored"], "unavailable Alpha Contract content remains an explicit coverage gap", failures)
	assert_true(not gate.get("full_alpha_roster_claim", true), "the manifest never promotes a partial configured roster to full Alpha coverage", failures)

	var readiness_config: Dictionary = config.duplicate(true)
	readiness_config.gate_profiles[0]["gate_id"] = "readiness"
	var readiness_manifest = SimulationManifestScript.new(readiness_config, Phase2CatalogScript.CHARACTER_IDS, Phase2CatalogScript.CONTRACT_IDS)
	var readiness_gate: Dictionary = readiness_manifest.to_dictionary().gates.readiness
	assert_true(readiness_gate.get("available_reward_paths", []).has("ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"), "the Readiness manifest also reports the Act 2 three-choice reward as available", failures)
	assert_true(not readiness_gate.get("not_yet_introduced_content_ids", []).has("alpha.act_two.boss_rule_breaker_pool"), "the Readiness manifest treats the Act 2 pool as introduced", failures)

	var future_config: Dictionary = config.duplicate(true)
	future_config.gate_profiles[0]["available_reward_paths"] = [
		"NORMAL_REWARD",
		"ELITE_REWARD",
		"BOSS_RULE_BREAKER",
		"ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES",
	]
	var future_manifest = SimulationManifestScript.new(future_config, Phase2CatalogScript.CHARACTER_IDS, Phase2CatalogScript.CONTRACT_IDS)
	var future_gate: Dictionary = future_manifest.to_dictionary().gates.hardening
	assert_true(future_gate.get("available_reward_paths", []).has("ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"), "a later gate can declare the Act 2 Boss pool available", failures)
	assert_true(not future_gate.get("not_yet_introduced_reward_paths", []).has("ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"), "future available content is not mislabeled as unavailable", failures)
	assert_true(not future_gate.get("not_yet_introduced_content_ids", []).has("alpha.act_two.boss_rule_breaker_pool"), "future available Boss content is not left in the unavailable ID list", failures)

func test_repeated_attempts_compare_authoritative_trace_not_machine_timing(failures: Array[String]) -> void:
	var first := {
		"manifest_hash": "manifest.1",
		"gate_id": "hardening",
		"seed": 901,
		"policy_id": "Hybrid",
		"character_id": "base.character.sequence",
		"contract_id": "base.contract.pressure",
		"route_id": "EVENT",
		"accepted_command_count": 3,
		"accepted_commands": [{"command_type": "Draw"}, {"command_type": "SettlePattern"}, {"command_type": "EndTurn"}],
		"checkpoint_hashes": ["hash.0", "hash.1"],
		"rng_snapshots": [{"Combat": 17, "Map": 29}],
		"events": [{"type": "TileDrawn"}, {"type": "PatternSettled"}],
		"strategy": {"policy_id": "Hybrid", "partial_settlements": 1, "complete_hands": 0},
		"outcome": "DEFEAT",
		"failure_classification": "NONE",
		"wall_time_ms": 21.0,
		"cpu_time_ms": 18.0,
		"peak_rss_bytes": 4096,
	}
	var identical := first.duplicate(true)
	identical["wall_time_ms"] = 700.0
	identical["cpu_time_ms"] = 300.0
	identical["peak_rss_bytes"] = 999999
	var matching_report: Dictionary = AlphaAttemptComparatorScript.compare(first, identical)
	var changed_rng := identical.duplicate(true)
	changed_rng["rng_snapshots"][0]["Combat"] = 18
	var mismatch_report: Dictionary = AlphaAttemptComparatorScript.compare(first, changed_rng)
	var json_first: Dictionary = JSON.parse_string(JSON.stringify(first))
	var json_identical: Dictionary = JSON.parse_string(JSON.stringify(identical))
	var json_round_trip_report: Dictionary = AlphaAttemptComparatorScript.compare(json_first, json_identical)
	var fractional_numeric := first.duplicate(true)
	fractional_numeric["rng_snapshots"][0]["fractional"] = 0.125
	var json_fractional_numeric: Dictionary = JSON.parse_string(JSON.stringify(fractional_numeric))
	var fractional_numeric_report: Dictionary = AlphaAttemptComparatorScript.compare(fractional_numeric, json_fractional_numeric)
	var large_integer_numeric := first.duplicate(true)
	large_integer_numeric["rng_snapshots"][0]["large_integer"] = 9007199254740993
	var json_large_integer_numeric: Dictionary = JSON.parse_string(JSON.stringify(large_integer_numeric))
	var large_integer_numeric_report: Dictionary = AlphaAttemptComparatorScript.compare(large_integer_numeric, json_large_integer_numeric)

	assert_true(matching_report.get("matches", false), "repeated seed and policy runs match when authoritative traces match", failures)
	assert_true(matching_report.get("differences", []).is_empty(), "machine timing is excluded from deterministic comparison", failures)
	assert_true(matching_report.get("status", "") == "MATCH", "the compact repeat report names exact equality", failures)
	assert_true(str(matching_report.get("expected_projection_hash", "")).length() == 64, "the repeat report records a SHA-256 deterministic projection", failures)
	assert_true(matching_report.get("expected_projection_hash", "") == matching_report.get("actual_projection_hash", ""), "matching repeats retain equal deterministic projection hashes", failures)
	assert_true(not mismatch_report.get("matches", true), "a changed RNG snapshot is reported as deterministic divergence", failures)
	assert_true(mismatch_report.get("differences", []).has("rng_snapshots"), "the comparator identifies the divergent authoritative field", failures)
	assert_true(mismatch_report.get("expected_projection_hash", "") != mismatch_report.get("actual_projection_hash", ""), "a changed RNG snapshot changes the deterministic projection hash", failures)
	assert_true(matching_report.get("expected_field_hashes", {}) == json_round_trip_report.get("expected_field_hashes", {}), "JSON decoding leaves the expected deterministic field fingerprints unchanged", failures)
	assert_true(matching_report.get("actual_field_hashes", {}) == json_round_trip_report.get("actual_field_hashes", {}), "JSON decoding leaves the repeated deterministic field fingerprints unchanged", failures)
	assert_true(fractional_numeric_report.get("matches", false), "fractional RNG values preserve exact fingerprints through a JSON round trip", failures)
	assert_true(not large_integer_numeric_report.get("matches", true) and large_integer_numeric_report.get("differences", []).has("rng_snapshots"), "JSON precision loss in an unsafe-integer RNG state is reported as divergence instead of normalized away", failures)
	assert_true(large_integer_numeric_report.get("expected_field_hashes", {}).get("rng_snapshots", "") != large_integer_numeric_report.get("actual_field_hashes", {}).get("rng_snapshots", ""), "unsafe-integer RNG fingerprints preserve the original and decoded values as distinct evidence", failures)

func test_valid_defeat_and_harness_failures_are_classified_separately(failures: Array[String]) -> void:
	var defeat := {"terminal": true, "outcome": "DEFEAT", "authoritative_state_valid": true}
	var defeat_classification: Dictionary = AlphaFailureClassifierScript.classify(defeat)
	var replay_divergence := {"terminal": true, "outcome": "DEFEAT", "authoritative_state_valid": true, "replay_status": "DIVERGED"}
	var invalid_state := {"terminal": true, "outcome": "VICTORY", "authoritative_state_valid": false}
	var soft_lock := {"terminal": false, "outcome": "ONGOING", "authoritative_state_valid": true, "soft_lock_detected": true}
	var missing_content := {"terminal": false, "outcome": "", "content_available": false}

	assert_true(defeat_classification.get("failure_classification", "") == "NONE", "a terminal Defeat is a valid gameplay outcome, not a harness failure", failures)
	assert_true(defeat_classification.get("valid_gameplay_outcome", false), "valid Defeat is explicitly marked as an acceptable terminal outcome", failures)
	assert_true(AlphaFailureClassifierScript.classify(replay_divergence).get("failure_classification", "") == "REPLAY_DIVERGENCE", "replay divergence is not hidden by a valid terminal outcome", failures)
	assert_true(AlphaFailureClassifierScript.classify(invalid_state).get("failure_classification", "") == "INVALID_AUTHORITATIVE_STATE", "invalid authoritative state has its own failure class", failures)
	assert_true(AlphaFailureClassifierScript.classify(soft_lock).get("failure_classification", "") == "SOFT_LOCK", "a nonterminal soft-lock has its own failure class", failures)
	assert_true(AlphaFailureClassifierScript.classify(missing_content).get("failure_classification", "") == "CONTENT_UNAVAILABLE", "missing content is a visible coverage blocker, not a passing run", failures)

func test_act_two_boss_reward_gap_is_content_unavailable_not_a_soft_lock(failures: Array[String]) -> void:
	assert_true(
		AlphaSimulationRunnerScript.is_unavailable_act_two_boss_reward("BOSS_REWARD", 2, 2, null),
		"an Act 2 Boss with no eligible three-choice draft is an explicit not-yet-introduced content gap",
		failures,
	)
	assert_true(
		not AlphaSimulationRunnerScript.is_unavailable_act_two_boss_reward("BOSS_REWARD", 1, 2, null),
		"an Act 1 Boss reward is not confused with the unavailable Act 2 reward pool",
		failures,
	)
	assert_true(
		not AlphaSimulationRunnerScript.is_unavailable_act_two_boss_reward("BOSS_REWARD", 2, 2, RefCounted.new()),
		"an Act 2 Boss with an active reward draft is not reported as unavailable",
		failures,
	)

func test_runner_emits_a_real_replayable_run_attempt(failures: Array[String]) -> void:
	var config := {
		"schema_version": 1,
		"content_version": AlphaSimulationRunnerScript.content_version_for_gate("hardening"),
		"gate_profiles": [{
			"gate_id": "hardening",
			"attempt_count": 1,
			"seed_start": 8800,
			"policy_ids": ["Hybrid"],
			"character_ids": ["base.character.sequence"],
			"contract_ids": ["base.contract.pressure"],
			"route_ids": ["EVENT"],
		}],
	}
	var manifest = SimulationManifestScript.new(config, Phase2CatalogScript.CHARACTER_IDS, Phase2CatalogScript.CONTRACT_IDS)
	var gate: Dictionary = manifest.to_dictionary().gates.hardening
	var attempt_case: Dictionary = gate.cases[0]
	var attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, manifest.manifest_hash(), 1024)
	var repeated_attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, manifest.manifest_hash(), 2)
	var repeated_attempt_again: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, manifest.manifest_hash(), 2)
	var checkpoints: Array = attempt.get("checkpoints", [])
	var rng_snapshots: Array = attempt.get("rng_snapshots", [])

	assert_true(attempt.get("two_act_profile", false), "the runner uses the named two-Act Alpha Run profile", failures)
	assert_true(attempt.get("starting_pool_fixture_id", "") == AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID, "the attempt reports the exact harness-only starting-pool fixture", failures)
	assert_true(attempt.get("starting_pool_tile_count", 0) == AlphaSimulationStartingPoolFixtureScript.TILE_COUNT, "the fixed fixture materializes the declared 14-tile Phase 2 simulation hand", failures)
	assert_true(not str(attempt.get("starting_pool_hash", "")).is_empty(), "the attempt records a deterministic hash for the initial tile pool", failures)
	assert_true(attempt.get("terminal", false), "a complete gameplay attempt reaches its actual Run Summary", failures)
	assert_true(attempt.get("configured_act_count", 0) == 2, "the attempt records that the Run uses the two-Act profile", failures)
	assert_true(attempt.get("act_reached", 0) == 2, "seed 8800's actual terminal Defeat occurs in Act 2", failures)
	assert_true(attempt.get("progress_status", "") == "TERMINAL_AFTER_FINAL_ACT", "the attempt records its real Act 2 terminal outcome", failures)
	assert_true(attempt.get("outcome", "") == "DEFEAT", "seed 8800 reaches a real terminal Act 2 Defeat", failures)
	assert_true(attempt.get("failure_classification", "") == "NONE", "a terminal Victory or Defeat is not classified as a harness failure", failures)
	assert_true(_has_event(attempt.get("events", []), "RunSummaryReached"), "the attempt records its final Run Summary event", failures)
	assert_true(_has_event(attempt.get("events", []), "ActTransitioned"), "the attempt reaches Act 2 through its real Act transition", failures)
	assert_true(attempt.get("authoritative_state_validation_status", "") == "VALID", "the terminal authoritative state passes the real stable-save validator", failures)
	assert_true(attempt.get("accepted_command_count", -1) == attempt.get("accepted_commands", []).size(), "the attempt count equals the recorded accepted authoritative commands", failures)
	assert_true(checkpoints.size() == attempt.get("accepted_command_count", -2) + 1, "the record includes the initial and every accepted-command checkpoint", failures)
	assert_true(attempt.get("checkpoint_hashes", []).size() == checkpoints.size(), "the record has a hash for every checkpoint", failures)
	assert_true(rng_snapshots.size() == checkpoints.size(), "the record retains an RNG snapshot for every checkpoint", failures)
	assert_true(not attempt.get("events", []).is_empty(), "the record retains the factual Domain events", failures)
	assert_true(_has_command_type(attempt.get("accepted_commands", []), "EnterEvent"), "the representative fixed attempt exercises an authored Event", failures)
	assert_true(_has_command_type(attempt.get("accepted_commands", []), "ChooseEventOption"), "the simulation policy chooses a domain-valid Event option", failures)
	assert_true(_has_event(attempt.get("events", []), "EventResolved"), "the accepted Event choice resolves through the authoritative Domain", failures)
	assert_true(attempt.get("replay_status", "") == "MATCH", "the accepted-command attempt verifies through the existing Run replay seam", failures)
	var repeated_report: Dictionary = AlphaAttemptComparatorScript.compare(repeated_attempt, repeated_attempt_again)
	assert_true(repeated_report.get("matches", false), "repeating the same seed/policy prefix reproduces its authoritative output exactly", failures)
	assert_true(repeated_attempt.get("failure_classification", "") == "INCOMPLETE_RUN", "a deliberately bounded nonterminal attempt is incomplete rather than an invalid-state pass", failures)

func test_hybrid_discards_excess_hand_with_bounded_work(failures: Array[String]) -> void:
	var attempt_case := {
		"attempt_id": "hybrid.hand-cap.8803",
		"attempt_index": 0,
		"gate_id": "hardening",
		"seed": 8803,
		"policy_id": "Hybrid",
		"character_id": "base.character.sequence",
		"contract_id": "base.contract.pressure",
		"route_id": "EVENT",
	}
	var runner = AlphaSimulationRunnerScript.new()
	var attempt: Dictionary = runner.run_attempt(attempt_case, "hybrid.hand-cap", 200)
	var action_counts: Dictionary = attempt.get("strategy", {}).get("accepted_action_counts", {})
	var maximum_hand_size := 0
	var normal_hand_baseline := 13
	for checkpoint_value in attempt.get("checkpoints", []):
		if not checkpoint_value is Dictionary:
			continue
		var run_state: Dictionary = checkpoint_value.get("domain_snapshot", {}).get("data", {}).get("run_state", {})
		var battle_snapshot: Dictionary = run_state.get("current_battle_snapshot", {})
		var zones: Dictionary = battle_snapshot.get("zones", {})
		var checkpoint_hand: Variant = zones.get("Hand", null)
		if checkpoint_hand is Array:
			maximum_hand_size = maxi(maximum_hand_size, checkpoint_hand.size())
			var recovery: Dictionary = battle_snapshot.get("recovery", {})
			normal_hand_baseline = int(recovery.get("normal_hand_baseline", normal_hand_baseline))

	assert_true(attempt.get("accepted_command_count", 0) <= 200, "the deterministic Hybrid stress prefix respects its bounded command limit", failures)
	assert_true(int(action_counts.get("DiscardTile", 0)) > 0, "Hybrid uses accepted authoritative DiscardTile commands when its Hand grows beyond baseline", failures)
	assert_true(maximum_hand_size <= normal_hand_baseline + 2, "Hybrid keeps every recorded Hand near baseline, allowing a just-drawn tile and the following discard", failures)
	assert_true(attempt.get("failure_classification", "") in ["NONE", "INCOMPLETE_RUN"], "the bounded policy prefix reaches no rejected-command or invalid-replay state", failures)
	assert_true(attempt.get("replay_status", "") == "MATCH", "the bounded Hybrid prefix replays exactly after policy discards", failures)

func test_complete_discards_when_reserve_is_full_and_hand_grows(failures: Array[String]) -> void:
	var config := {
		"schema_version": 1,
		"content_version": AlphaSimulationRunnerScript.content_version_for_gate("hardening"),
		"gate_profiles": [{
			"gate_id": "hardening",
			"attempt_count": 1,
			"seed_start": 57003,
			"policy_ids": ["Complete"],
			"character_ids": ["base.character.reserve"],
			"contract_ids": ["base.contract.pool_bias"],
			"route_ids": ["SERVICE"],
		}],
	}
	var manifest = SimulationManifestScript.new(config, Phase2CatalogScript.CHARACTER_IDS, Phase2CatalogScript.CONTRACT_IDS)
	var attempt_case: Dictionary = manifest.to_dictionary().get("gates", {}).get("hardening", {}).get("cases", [])[0]
	var attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, manifest.manifest_hash(), 128)
	var checkpoints: Array = attempt.get("checkpoints", [])
	var max_hand := 0
	var baseline := 13
	for checkpoint_value in checkpoints:
		if not checkpoint_value is Dictionary:
			continue
		var run_state: Dictionary = checkpoint_value.get("domain_snapshot", {}).get("data", {}).get("run_state", {})
		var battle_snapshot: Dictionary = run_state.get("current_battle_snapshot", {})
		var hand: Variant = battle_snapshot.get("zones", {}).get("Hand", null)
		if hand is Array:
			max_hand = maxi(max_hand, hand.size())
			baseline = int(battle_snapshot.get("recovery", {}).get("normal_hand_baseline", baseline))
	var action_counts: Dictionary = attempt.get("strategy", {}).get("accepted_action_counts", {})

	assert_true(attempt.get("accepted_command_count", -1) == 128, "the Complete policy stress prefix is bounded to 128 accepted commands", failures)
	assert_true(max_hand <= baseline + 2, "Complete keeps Hand near its public recovery baseline after Reserve fills", failures)
	assert_true(int(action_counts.get("DiscardTile", 0)) > 0, "Complete uses the authoritative DiscardTile command when Reserve is full", failures)
	assert_true(attempt.get("strategy", {}).get("policy_rule_id", "") == "alpha.complete.v8", "bounded Complete storage uses its explicit policy version", failures)
	assert_true(attempt.get("failure_classification", "") == "INCOMPLETE_RUN", "the stress prefix remains an honest bounded incomplete attempt", failures)
	assert_true(attempt.get("replay_status", "") == "MATCH", "the bounded Complete policy trace replays after tile discards", failures)

func test_runner_content_version_tracks_conditional_scale_bundle(failures: Array[String]) -> void:
	var attempt_case := {
		"attempt_id": "version.identity",
		"attempt_index": 0,
		"gate_id": "hardening",
		"seed": 31,
		"policy_id": "unsupported-version-test-policy",
		"character_id": Phase2CatalogScript.CHARACTER_IDS[0],
		"contract_id": Phase2CatalogScript.CONTRACT_IDS[0],
		"route_id": "EVENT",
	}
	var hardening_attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, "version.identity", 0)
	var scale_case: Dictionary = attempt_case.duplicate(true)
	scale_case["gate_id"] = "scale"
	var scale_attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(scale_case, "version.identity", 0)
	var repeated_scale_attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(scale_case, "version.identity", 0)
	var beta_case: Dictionary = attempt_case.duplicate(true)
	beta_case["gate_id"] = "stage4_beta"
	var beta_attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(beta_case, "version.identity", 0)
	var hardening_version := _initial_content_version(hardening_attempt)
	var scale_version := _initial_content_version(scale_attempt)
	var repeated_scale_version := _initial_content_version(repeated_scale_attempt)
	var beta_version := _initial_content_version(beta_attempt)

	assert_true(not hardening_version.is_empty() and hardening_version != ContentRegistryScript.CONTENT_VERSION, "the runner does not label its unconditional Act Two bundle as Phase 2 v2", failures)
	assert_true(not scale_version.is_empty() and scale_version != hardening_version, "the Scale gate's conditional catalog registration changes the run content identity", failures)
	assert_true(scale_version == repeated_scale_version, "the same Scale gate receives the same deterministic content identity", failures)
	assert_true(hardening_version == AlphaSimulationRunnerScript.content_version_for_gate("hardening"), "the hardening manifest identity matches the run's registered bundles", failures)
	assert_true(scale_version == AlphaSimulationRunnerScript.content_version_for_gate("scale"), "the Scale manifest identity matches the run's registered bundles", failures)
	assert_true(beta_version == scale_version, "the Stage 4 Beta gate loads the complete three-Character/eight-Contract Scale bundle", failures)
	assert_true(beta_version == AlphaSimulationRunnerScript.content_version_for_gate("stage4_beta"), "the Stage 4 Beta manifest identity matches the run's registered bundles", failures)

func test_complete_policy_completes_real_two_act_run_and_reward_flow(failures: Array[String]) -> void:
	# Complete policy v8 bounds deterministic tile manipulation while preserving the real two-Act flow.
	var attempt_case := {
		"attempt_id": "readiness.00002",
		"attempt_index": 1,
		"gate_id": "readiness",
		"seed": 57002,
		"policy_id": "Complete",
		"character_id": "base.character.reserve",
		"contract_id": "base.contract.pool_bias",
		"route_id": "SERVICE",
		"starting_pool_fixture_id": AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID,
	}
	var attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, "regression.seed-57002", 1024)
	var repeated_attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, "regression.seed-57002", 1024)
	var commands: Array = attempt.get("accepted_commands", [])
	var checkpoints: Array = attempt.get("checkpoints", [])
	var second_phase_checkpoint := -1
	var second_phase_damage := 0
	var second_phase_attack_command_type := ""
	var second_phase_store_count := 0
	var boss_reward_transition := false
	var boss_reward_choice_type := ""
	var draw_budget_respected := true
	var store_budget_respected := checkpoints.size() == commands.size() + 1
	if checkpoints.size() == commands.size() + 1:
		for command_index in range(commands.size()):
			var command_type := str(commands[command_index].get("command_type", ""))
			if command_type == "StoreTile":
				var before_store: Dictionary = checkpoints[command_index].get("domain_snapshot", {}).get("data", {}).get("run_state", {}).get("current_battle_snapshot", {})
				var before_store_state: Dictionary = before_store.get("combat_state", {})
				var after_store: Dictionary = checkpoints[command_index + 1].get("domain_snapshot", {}).get("data", {}).get("run_state", {}).get("current_battle_snapshot", {})
				var after_store_state: Dictionary = after_store.get("combat_state", {})
				if (
					int(before_store_state.get("draw_actions_used_this_turn", 0)) <= 0
					or bool(before_store_state.get("tile_manipulation_used_this_draw", true))
					or not bool(after_store_state.get("tile_manipulation_used_this_draw", false))
				):
					store_budget_respected = false
			if command_type != "Draw":
				continue
			var draw_checkpoint: Dictionary = checkpoints[command_index + 1].get("domain_snapshot", {}).get("data", {}).get("run_state", {}).get("current_battle_snapshot", {})
			var draw_state: Dictionary = draw_checkpoint.get("combat_state", {})
			var used_actions := int(draw_state.get("draw_actions_used_this_turn", 0))
			var draw_capacity := int(draw_state.get("draw_capacity", 0))
			if used_actions < 1 or used_actions > draw_capacity:
				draw_budget_respected = false
	assert_true(attempt.get("strategy", {}).get("policy_rule_id", "") == "alpha.complete.v8", "the bounded Complete tile policy uses its own explicit version", failures)
	var decision_rule := str(attempt.get("strategy", {}).get("decision_rule", ""))
	assert_true(
		decision_rule.contains("Once per normal Draw") and decision_rule.contains("when Reserve is full, discard"),
		"the policy text states its one-manipulation-per-Draw budget and full-Reserve fallback",
		failures,
	)
	assert_true(store_budget_respected, "every accepted Store follows an unused normal-Draw manipulation allowance", failures)
	if checkpoints.size() == commands.size() + 1:
		for checkpoint_index in range(1, checkpoints.size()):
			var checkpoint: Dictionary = checkpoints[checkpoint_index]
			var command_type := str(commands[checkpoint_index - 1].get("command_type", ""))
			if second_phase_checkpoint >= 0 and checkpoint_index > second_phase_checkpoint and command_type == "StoreTile":
				second_phase_store_count += 1
			for event in checkpoint.get("domain_events", []):
				if not event is Dictionary:
					continue
				var event_type := str(event.get("event_type", ""))
				var event_data: Dictionary = event.get("data", {})
				if event_type == "BossPhaseChanged" and str(event_data.get("phase_id", "")) == "table_interference":
					second_phase_checkpoint = checkpoint_index
				elif second_phase_checkpoint >= 0 and checkpoint_index > second_phase_checkpoint and event_type == "EnemyHpChanged":
					if int(event_data.get("amount", 0)) > 0:
						second_phase_damage += 1
						second_phase_attack_command_type = command_type
				if (
					event_type == "RunPhaseChanged"
					and str(event_data.get("from_phase", "")) == "BATTLE"
					and str(event_data.get("to_phase", "")) == "BOSS_REWARD"
				):
					boss_reward_transition = true
					if checkpoint_index < commands.size():
						boss_reward_choice_type = str(commands[checkpoint_index].get("command_type", ""))

	assert_true(second_phase_checkpoint >= 0, "the fixed corpus seed reaches the Act 1 Boss's real second phase", failures)
	assert_true(
		second_phase_damage > 0,
		"the Complete policy's accepted Domain settlements damage the Act 1 Boss after its second phase begins",
		failures,
	)
	assert_true(
		second_phase_store_count > 0 and second_phase_attack_command_type == "SettleCompleteHand",
		"the policy stores surplus tiles with an authoritative command, then damages the Boss with a real Complete Hand settlement",
		failures,
	)
	assert_true(
		boss_reward_transition,
		"the fixed Complete-policy attempt defeats the Act 1 Boss through a real Boss reward transition",
		failures,
	)
	assert_true(
		boss_reward_choice_type == "ChooseReward",
		"the runner resolves the real Act 1 Boss draft with an authoritative ChooseReward command",
		failures,
	)
	assert_true(draw_budget_respected, "the replacement full-run seed keeps every accepted Draw within the authoritative Draw Action budget", failures)
	assert_true(_has_event(attempt.get("events", []), "ActTransitioned"), "the selected Boss reward advances the same Run through its real Act 2 transition", failures)
	var expected_act_two_ids: Array = AlphaScaleCatalogScript.ACT_TWO_BOSS_RULE_BREAKER_IDS.duplicate()
	expected_act_two_ids.sort()
	var in_act_two := false
	var act_one_rule_breaker_id := ""
	var act_two_normal_victory := false
	var act_two_boss_victory := false
	var act_two_boss_choice_ids: Array[String] = []
	var act_two_selected_id := ""
	for event in attempt.get("events", []):
		var event_type := str(event.get("event_type", ""))
		var event_data: Dictionary = event.get("data", {})
		if event_type == "ActTransitioned" and int(event_data.get("to_act", 0)) == 2:
			in_act_two = true
		elif event_type == "RewardSelected" and str(event_data.get("kind", "")) == "RULE_BREAKER":
			if in_act_two:
				act_two_selected_id = str(event_data.get("content_id", ""))
			else:
				act_one_rule_breaker_id = str(event_data.get("content_id", ""))
		elif in_act_two and event_type == "BattleOutcomeTransferred":
			var encounter_kind := str(event_data.get("encounter_kind", ""))
			var outcome := str(event_data.get("outcome", ""))
			if encounter_kind == "NORMAL" and outcome == "VICTORY":
				act_two_normal_victory = true
			if encounter_kind == "BOSS" and outcome == "VICTORY":
				act_two_boss_victory = true
		elif in_act_two and event_type == "RewardDraftCreated":
			var draft: Dictionary = event_data.get("draft", {})
			if str(draft.get("draft_kind", "")) == "BOSS_RULE_BREAKER":
				for option in draft.get("options", []):
					act_two_boss_choice_ids.append(str(option.get("content_id", "")))
		act_two_boss_choice_ids.sort()
	var unique_act_two_choice_ids: Dictionary = {}
	for content_id in act_two_boss_choice_ids:
		unique_act_two_choice_ids[content_id] = true
	assert_true(act_one_rule_breaker_id in AlphaScaleCatalogScript.ACT_ONE_BOSS_RULE_BREAKER_IDS, "the real Act 1 Boss reward selects and applies one eligible Rule Breaker before the Act transition", failures)
	assert_true(act_two_normal_victory, "the same Run defeats an Act 2 Normal encounter through authoritative runner commands", failures)
	assert_true(act_two_boss_victory, "the same Run defeats the Act 2 Boss through authoritative runner commands", failures)
	assert_true(
		act_two_boss_choice_ids.size() == 3 and unique_act_two_choice_ids.size() == 3 and act_two_boss_choice_ids.all(func(content_id): return content_id in expected_act_two_ids),
		"the real Act 2 Boss reward draft contains three distinct eligible Act 2 Rule Breakers",
		failures,
	)
	assert_true(
		act_two_selected_id in expected_act_two_ids and act_two_selected_id != act_one_rule_breaker_id,
		"the runner applies one of the offered Act 2 Rule Breakers after acquiring the Act 1 choice",
		failures,
	)
	assert_true(
		attempt.get("outcome", "") == "VICTORY" and attempt.get("progress_status", "") == "TERMINAL_AFTER_FINAL_ACT",
		"the fixed-seed attempt reaches the real Act 2 ending in a valid Run victory",
		failures,
	)
	assert_true(attempt.get("replay_status", "") == "MATCH", "the fixed-seed Boss progression remains replayable", failures)
	assert_true(
		attempt.get("authoritative_state_validation_status", "") == "VALID",
		"the fixed-seed terminal Run passes authoritative stable-save validation",
		failures,
	)
	assert_true(
		AlphaAttemptComparatorScript.compare(attempt, repeated_attempt).get("matches", false),
		"repeating the full fixed-seed policy attempt reproduces its commands, checkpoints, RNG states, events, and outcome",
		failures,
	)

func test_act_two_seed_57001_is_a_replayable_victory_within_draw_budget(failures: Array[String]) -> void:
	var attempt_case := {
		"attempt_id": "readiness.act-two-victory.57001",
		"attempt_index": 0,
		"gate_id": "readiness",
		"seed": 57001,
		"policy_id": "Complete",
		"character_id": "base.character.reserve",
		"contract_id": "base.contract.pool_bias",
		"route_id": "SERVICE",
		"starting_pool_fixture_id": AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID,
	}
	var attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, "regression.act-two-victory.seed-57001", 1024)
	var repeated_attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, "regression.act-two-victory.seed-57001", 1024)
	var commands: Array = attempt.get("accepted_commands", [])
	var checkpoints: Array = attempt.get("checkpoints", [])
	var reached_act_two := false
	var act_two_boss_victory := false
	var run_summary_seen := false
	var draw_budget_respected := checkpoints.size() == commands.size() + 1
	if checkpoints.size() == commands.size() + 1:
		for index in range(commands.size()):
			if str(commands[index].get("command_type", "")) == "Draw":
				var battle_snapshot: Dictionary = checkpoints[index + 1].get("domain_snapshot", {}).get("data", {}).get("run_state", {}).get("current_battle_snapshot", {})
				var combat_state: Dictionary = battle_snapshot.get("combat_state", {})
				var used_actions := int(combat_state.get("draw_actions_used_this_turn", 0))
				var draw_capacity := int(combat_state.get("draw_capacity", 0))
				if used_actions < 1 or used_actions > draw_capacity:
					draw_budget_respected = false
		for checkpoint_index in range(1, checkpoints.size()):
			for event in checkpoints[checkpoint_index].get("domain_events", []):
				if not event is Dictionary:
					continue
				var event_type := str(event.get("event_type", ""))
				var event_data: Dictionary = event.get("data", {})
				if event_type == "ActTransitioned" and int(event_data.get("to_act", 0)) == 2:
					reached_act_two = true
				elif reached_act_two and event_type == "BattleOutcomeTransferred":
					act_two_boss_victory = (
						str(event_data.get("encounter_kind", "")) == "BOSS"
						and str(event_data.get("outcome", "")) == "VICTORY"
					)
				elif event_type == "RunSummaryReached":
					run_summary_seen = true
	assert_true(attempt.get("terminal", false) and attempt.get("outcome", "") == "VICTORY", "seed 57001 records a terminal two-Act Victory under Complete policy v8", failures)
	assert_true(int(attempt.get("act_reached", 0)) == 2 and reached_act_two and act_two_boss_victory, "seed 57001 reaches Act 2 and defeats its Boss", failures)
	assert_true(run_summary_seen, "seed 57001 reaches the authoritative Run Summary", failures)
	assert_true(attempt.get("failure_classification", "") == "NONE", "seed 57001's Victory is not classified as a harness failure", failures)
	assert_true(attempt.get("replay_status", "") == "MATCH", "seed 57001's accepted-command trace replays exactly", failures)
	assert_true(attempt.get("authoritative_state_validation_status", "") == "VALID", "seed 57001's terminal Victory has a valid authoritative stable state", failures)
	assert_true(draw_budget_respected, "every accepted Draw in seed 57001 stays within its combat Draw Action capacity", failures)
	assert_true(AlphaAttemptComparatorScript.compare(attempt, repeated_attempt).get("matches", false), "repeating seed 57001 reproduces its Victory and accepted trace", failures)

func test_runner_ends_turn_when_draw_sources_are_empty(failures: Array[String]) -> void:
	var attempt_case := {
		"attempt_id": "readiness.00001",
		"attempt_index": 0,
		"gate_id": "readiness",
		"seed": 57000,
		"policy_id": "Partial",
		"character_id": "base.character.reserve",
		"contract_id": "base.contract.pool_bias",
		"route_id": "EVENT",
		"starting_pool_fixture_id": AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID,
	}
	var attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, "regression.seed-57000", 1024)
	assert_true(
		attempt.get("strategy", {}).get("policy_rule_id", "") == "alpha.partial.v7",
		"the empty-source End Turn behavior has an explicit, versioned simulation policy",
		failures,
	)
	var commands: Array = attempt.get("accepted_commands", [])
	var checkpoints: Array = attempt.get("checkpoints", [])
	if checkpoints.size() != commands.size() + 1:
		assert_true(false, "the fixed-seed attempt has a preceding checkpoint for every accepted command", failures)
		return

	var empty_source_draws := 0
	var empty_source_end_turns := 0
	var draw_budget_respected := true
	for index in range(commands.size()):
		var command_type := str(commands[index].get("command_type", ""))
		if command_type == "Draw":
			var battle_checkpoint: Dictionary = checkpoints[index + 1].get("domain_snapshot", {}).get("data", {}).get("run_state", {}).get("current_battle_snapshot", {})
			var combat_state: Dictionary = battle_checkpoint.get("combat_state", {})
			var used_actions := int(combat_state.get("draw_actions_used_this_turn", 0))
			var draw_capacity := int(combat_state.get("draw_capacity", 0))
			if used_actions < 1 or used_actions > draw_capacity:
				draw_budget_respected = false
		if command_type != "Draw" and command_type != "EndTurn":
			continue
		var snapshot: Dictionary = checkpoints[index].get("domain_snapshot", {}).get("data", {}).get("run_state", {}).get("current_battle_snapshot", {})
		var zones: Dictionary = snapshot.get("zones", {})
		if not zones.has("Draw Wall") or not zones.has("Discard"):
			continue
		if not zones["Draw Wall"].is_empty() or not zones["Discard"].is_empty():
			continue
		if command_type == "Draw":
			empty_source_draws += 1
		else:
			empty_source_end_turns += 1

	assert_true(
		empty_source_draws == 0 and empty_source_end_turns > 0,
		"the fixed-seed runner ends a turn instead of requesting a Draw from empty Wall and Discard (empty Draws: %d, empty End Turns: %d)" % [empty_source_draws, empty_source_end_turns],
		failures,
	)
	assert_true(draw_budget_respected, "every accepted simulation Draw stays within the authoritative battle Draw Action capacity", failures)

func test_service_route_reaches_a_workshop(failures: Array[String]) -> void:
	var attempt_case := {
		"attempt_id": "readiness.service-route",
		"attempt_index": 0,
		"gate_id": "readiness",
		"seed": 57011,
		"policy_id": "Hybrid",
		"character_id": "base.character.sequence",
		"contract_id": "base.contract.pressure",
		"route_id": "SERVICE",
		"starting_pool_fixture_id": AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID,
	}
	var attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, "regression.service-route", 80)
	assert_true(
		_has_command_type(attempt.get("accepted_commands", []), "EnterWorkshop"),
		"the fixed-seed SERVICE route selects and enters its available Workshop node",
		failures,
	)
	assert_true(
		_has_command_type(attempt.get("accepted_commands", []), "ExitWorkshop"),
		"the runner returns from Workshop through the existing authoritative ExitWorkshop command",
		failures,
	)
	assert_true(
		not _has_command_type(attempt.get("accepted_commands", []), "UseWorkshopService"),
		"the runner does not invent a paid Workshop action when this fixed attempt cannot afford one",
		failures,
	)
	assert_true(
		attempt.get("strategy", {}).get("policy_rule_id", "") == "alpha.hybrid.v7",
		"the changed SERVICE route selection is represented by a new explicit simulation policy version",
		failures,
	)

func test_stage4_beta_case_00686_reaches_a_valid_run_ending(failures: Array[String]) -> void:
	var attempt_case := {
		"attempt_id": "stage4_beta.00686",
		"attempt_index": 685,
		"character_id": "alpha.character.harbor_reader",
		"contract_id": "alpha.contract.house_tithe",
		"gate_id": "stage4_beta",
		"policy_id": "Hybrid",
		"route_id": "EVENT",
		"seed": 57685,
		"starting_pool_fixture_id": "phase2.character_biased_complete_hand.v1",
	}
	var attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, "regression.stage4_beta.case-00686", 1024)
	var repeated_attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(attempt_case, "regression.stage4_beta.case-00686", 1024)
	var repeat_report: Dictionary = AlphaAttemptComparatorScript.compare(attempt, repeated_attempt)

	assert_true(attempt.get("terminal", false), "Stage 4 Beta seed 57685 reaches a Run ending instead of a rejected SettlePattern", failures)
	assert_true(attempt.get("failure_classification", "") == "NONE", "Stage 4 Beta seed 57685 has no simulation harness failure", failures)
	assert_true(attempt.get("authoritative_state_validation_status", "") == "VALID", "Stage 4 Beta seed 57685 ends with valid authoritative state", failures)
	assert_true(repeat_report.get("matches", false), "Stage 4 Beta seed 57685 remains deterministic across repeated attempts", failures)

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("event_type", "")) == event_type:
			return true
	return false

func _has_command_type(commands: Array, command_type: String) -> bool:
	for command in commands:
		if command is Dictionary and str(command.get("command_type", "")) == command_type:
			return true
	return false

func _initial_content_version(attempt: Dictionary) -> String:
	var checkpoints: Array = attempt.get("checkpoints", [])
	if checkpoints.is_empty():
		return ""
	var domain_snapshot: Dictionary = checkpoints[0].get("domain_snapshot", {})
	var snapshot_data: Dictionary = domain_snapshot.get("data", {})
	var run_state: Dictionary = snapshot_data.get("run_state", {})
	return str(run_state.get("content_version", ""))

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
