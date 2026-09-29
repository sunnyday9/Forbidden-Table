class_name AlphaSimulationCoverageTest
extends RefCounted

const SimulationGateRunnerScript = preload("res://src/infrastructure/simulation/simulation_gate_runner.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_small_profiles_cannot_pass_the_gate(failures)
	test_coverage_comes_from_factual_attempt_events(failures)
	test_real_normal_reward_event_shape_counts_as_coverage(failures)
	test_exact_gate_cohort_counts_valid_defeat_and_actual_coverage(failures)
	test_not_yet_introduced_requirements_are_reported_without_coverage(failures)
	test_streaming_aggregate_matches_batch_without_retaining_attempts(failures)
	test_streaming_rejects_wrong_gate_like_batch_aggregation(failures)
	test_content_use_reports_observed_ids_and_declared_unused_catalog_items(failures)
	for failure in failures:
		push_error(failure)
	return failures

func test_small_profiles_cannot_pass_the_gate(failures: Array[String]) -> void:
	var small_profile := _profile(6)
	var one_attempt: Array = [_successful_attempt(0, "base.character.a", "base.contract.a")]
	var small_result: Dictionary = SimulationGateRunnerScript.aggregate(small_profile, one_attempt)
	assert_true(small_result.get("required_attempt_count", 0) == 1000, "the gate result carries the exact 1,000-attempt requirement", failures)
	assert_true(small_result.get("report_valid", false), "a structurally valid report is distinct from a passing gate", failures)
	assert_true(small_result.get("profile_attempt_count_met", true) == false, "a small manifest profile cannot satisfy the required count", failures)
	assert_true(small_result.get("attempt_count_met", true) == false, "a small result set cannot satisfy the required count", failures)
	assert_true(small_result.get("gate_pass", true) == false, "a small test profile is never reported as a gate pass", failures)

	var one_thousand_attempts := _successful_attempts(1000)
	var declared_small_result: Dictionary = SimulationGateRunnerScript.aggregate(small_profile, one_thousand_attempts)
	assert_true(declared_small_result.get("attempt_count_met", false), "the supplied result count is measured independently", failures)
	assert_true(declared_small_result.get("gate_pass", true) == false, "1,000 results cannot turn a manifest profile of six into a gate workload", failures)

	var full_profile := _profile(1000)
	var short_results := _successful_attempts(999)
	var short_result: Dictionary = SimulationGateRunnerScript.aggregate(full_profile, short_results)
	assert_true(short_result.get("profile_attempt_count_met", false), "the profile can declare the exact required count", failures)
	assert_true(short_result.get("attempt_count_met", true) == false, "999 result records are not rounded up to the requirement", failures)
	assert_true(short_result.get("gate_pass", true) == false, "an underfilled cohort is not a gate pass", failures)

func test_coverage_comes_from_factual_attempt_events(failures: Array[String]) -> void:
	var profile := _profile(1)
	var attempt := _successful_attempt(0, "base.character.a", "base.contract.a")
	attempt["character_id"] = "base.character.a"
	attempt["contract_id"] = "base.contract.a"
	attempt["events"] = []
	var result: Dictionary = SimulationGateRunnerScript.aggregate(profile, [attempt])
	var coverage: Dictionary = result.get("coverage", {})
	var characters: Dictionary = coverage.get("characters", {})
	var contracts: Dictionary = coverage.get("contracts", {})
	var acts: Dictionary = coverage.get("acts", {})
	assert_true(characters.get("observed_ids", []).is_empty(), "scheduled Character labels do not count as factual roster coverage", failures)
	assert_true(contracts.get("observed_ids", []).is_empty(), "scheduled Contract labels do not count as factual roster coverage", failures)
	assert_true(acts.get("observed_ids", []).is_empty(), "declared Act-boundary labels do not count as reached Acts", failures)
	assert_true(characters.get("missing_required_ids", []).has("base.character.a"), "the unsourced Character remains a missing coverage requirement", failures)
	assert_true(result.get("gate_pass", true) == false, "declared but unreached coverage cannot pass", failures)

func test_real_normal_reward_event_shape_counts_as_coverage(failures: Array[String]) -> void:
	var profile := _profile(1)
	var attempt := _successful_attempt(0, "base.character.a", "base.contract.a")
	for index in attempt["events"].size():
		var event: Dictionary = attempt["events"][index]
		if event.get("event_type", "") == "RewardSelected" and event.get("data", {}).get("kind", "") == "ADD_TILE":
			attempt["events"][index] = _event("RewardSelected", {"kind": "ADD_TILE", "phase": "MAP_CHOICE"})
			break
	var result: Dictionary = SimulationGateRunnerScript.aggregate(profile, [attempt])
	var reward_paths: Dictionary = result.get("coverage", {}).get("reward_paths", {})
	assert_true(
		reward_paths.get("observed_ids", []).has("NORMAL_REWARD"),
		"the actual Domain RewardSelected shape (phase=MAP_CHOICE, no reward_phase field) counts as Normal reward coverage",
		failures,
	)

func test_exact_gate_cohort_counts_valid_defeat_and_actual_coverage(failures: Array[String]) -> void:
	var attempts := _successful_attempts(1000)
	attempts[0] = _valid_act_one_defeat()
	var future_profile := _profile(1000)
	future_profile.available_reward_paths.append("ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES")
	future_profile.not_yet_introduced_reward_paths.erase("ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES")
	future_profile.not_yet_introduced_content_ids.erase("alpha.act_two.boss_rule_breaker_pool")
	var result: Dictionary = SimulationGateRunnerScript.aggregate(future_profile, attempts)
	var coverage: Dictionary = result.get("coverage", {})
	assert_true(result.get("attempt_count_met", false), "exactly 1,000 attempt results meet the cohort size", failures)
	assert_true(result.get("profile_attempt_count_met", false), "the manifest profile also declares exactly 1,000", failures)
	assert_true(result.get("valid_defeat_count", 0) == 1, "a valid terminal Defeat remains a valid gameplay attempt", failures)
	assert_true(result.get("attempt_failure_count", -1) == 0, "valid Defeat is not counted as a harness failure", failures)
	assert_true(result.get("gate_pass", false), "complete factual coverage and valid outcomes satisfy this simulation gate", failures)
	assert_true(coverage.get("acts", {}).get("observed_ids", []) == ["ACT_1", "ACT_2"], "reached Acts are aggregated from selection and transition events", failures)
	assert_true(coverage.get("act_boss_boundaries", {}).get("observed_ids", []).size() == 2, "both Boss reward boundaries are aggregated from factual events", failures)
	assert_true(coverage.get("boss_outcomes", {}).get("observed_ids", []) == ["ACT_1_BOSS", "ACT_2_BOSS"], "both Boss outcomes are required and aggregated from factual events", failures)
	assert_true(coverage.get("reward_paths", {}).get("observed_ids", []) == ["ACT_1_BOSS_RULE_BREAKER_THREE_CHOICES", "ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES", "BOSS_RULE_BREAKER", "ELITE_REWARD", "NORMAL_REWARD"], "reward paths count actual applied choices and both verified three-choice Boss pools", failures)
	assert_true(coverage.get("characters", {}).get("observed_ids", []) == ["base.character.a", "base.character.b"], "roster coverage uses CharacterSelected events rather than attempt labels", failures)
	assert_true(coverage.get("contracts", {}).get("observed_ids", []) == ["base.contract.a", "base.contract.b", "base.contract.c"], "roster coverage uses ContractSelected events rather than attempt labels", failures)
	assert_true(coverage.get("policies", {}).get("observed_ids", []) == ["Complete", "Hybrid", "Partial"], "all three required strategy policies are evidenced by actual attempt records", failures)
	assert_true(not result.get("alpha_full_roster_claim", true), "current-gate evidence is not mislabeled as full Alpha-roster evidence", failures)

func test_not_yet_introduced_requirements_are_reported_without_coverage(failures: Array[String]) -> void:
	var profile := _profile(1000)
	profile["not_yet_introduced_character_ids"] = ["alpha.character.third"]
	profile["not_yet_introduced_contract_ids"] = ["alpha.contract.six"]
	profile.not_yet_introduced_reward_paths.append("FUTURE_REWARD_PATH")
	var unavailable_attempts := _act_two_pool_unavailable_attempts(1000)
	var result: Dictionary = SimulationGateRunnerScript.aggregate(profile, unavailable_attempts)
	var coverage: Dictionary = result.get("coverage", {})
	var not_yet: Dictionary = result.get("not_yet_introduced_requirements", {})
	assert_true(not_yet.get("characters", []).has("alpha.character.third"), "unintroduced Character content is reported explicitly", failures)
	assert_true(not_yet.get("contracts", []).has("alpha.contract.six"), "unintroduced Contract content is reported explicitly", failures)
	assert_true(not_yet.get("reward_paths", []).has("FUTURE_REWARD_PATH"), "an unintroduced future reward path is reported explicitly", failures)
	assert_true(not_yet.get("reward_paths", []).has("ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"), "the separate Act 2 three-choice reward path is a mandatory explicit requirement", failures)
	assert_true(not_yet.get("content_ids", []).has("alpha.act_two.boss_rule_breaker_pool"), "the established stable unavailable-content ID appears in the baseline report", failures)
	assert_true(result.get("unavailable_content_ids", []).has("alpha.act_two.boss_rule_breaker_pool"), "the unavailable-content ID is also available as a top-level report field", failures)
	assert_true(not coverage.get("characters", {}).get("observed_ids", []).has("alpha.character.third"), "unintroduced content is never inferred as covered", failures)
	assert_true(not coverage.get("contracts", {}).get("observed_ids", []).has("alpha.contract.six"), "unintroduced roster entries are never inferred as covered", failures)
	assert_true(not coverage.get("reward_paths", {}).get("observed_ids", []).has("ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"), "an unavailable Act 2 pool is never inferred as covered", failures)
	var unavailable_path_status := _reward_path_status(coverage.get("reward_paths", {}), "ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES")
	assert_true(unavailable_path_status.get("availability_status", "") == "NOT_AVAILABLE", "the absent three-choice pool is reported as NOT_AVAILABLE", failures)
	assert_true(unavailable_path_status.get("coverage_status", "") == "NOT_COVERED", "the absent three-choice pool is reported as NOT_COVERED", failures)
	assert_true(result.get("report_valid", false), "a validly formed failure report remains valid as a report", failures)
	assert_true(not result.get("gate_pass", true), "unavailable mandatory content can never produce a simulation gate pass", failures)
	assert_true(result.get("gate_status", "") == "REQUIREMENTS_NOT_YET_AVAILABLE", "the baseline gate reports unavailable content separately from ordinary coverage gaps", failures)
	assert_true(not result.get("alpha_full_roster_claim", true), "a baseline gate cannot claim full Alpha-roster coverage", failures)

func test_streaming_aggregate_matches_batch_without_retaining_attempts(failures: Array[String]) -> void:
	var profile := _profile(1000)
	var attempts := _successful_attempts(1000)
	for attempt_index in range(attempts.size()):
		var attempt: Dictionary = attempts[attempt_index]
		var strategy: Dictionary = attempt.get("strategy", {})
		strategy["accepted_action_counts"] = {"EndTurn": 1}
		strategy["partial_settlements"] = 1
		strategy["complete_hand_settlements"] = 2
		attempt["strategy"] = strategy
	var batch: Dictionary = SimulationGateRunnerScript.aggregate(profile, attempts)
	var accumulator: Dictionary = SimulationGateRunnerScript.new_streaming_accumulator(profile)
	for attempt in attempts:
		SimulationGateRunnerScript.accumulate_attempt(accumulator, attempt)
	var streamed: Dictionary = SimulationGateRunnerScript.finish_streaming_aggregate(accumulator)
	assert_true(streamed == batch, "incremental aggregation yields the same coverage and failures as the existing batch report", failures)
	assert_true(not accumulator.has("attempt_results") and not accumulator.has("aggregate_attempts"), "the streaming accumulator stores counts and coverage sets, not attempt traces", failures)
	assert_true(streamed.get("policy_outcome_counts", {}).get("Complete", {}).get("VICTORY", 0) == 334 and streamed.get("policy_outcome_counts", {}).get("Hybrid", {}).get("VICTORY", 0) == 333 and streamed.get("policy_outcome_counts", {}).get("Partial", {}).get("VICTORY", 0) == 333, "streaming and batch reports retain terminal outcomes separately for each policy", failures)
	var complete_strategy: Dictionary = streamed.get("strategy_distributions", {}).get("Complete", {})
	assert_true(complete_strategy.get("attempt_count", 0) == 334 and complete_strategy.get("accepted_command_count", 0) == 668, "strategy distributions retain attempts and command totals by policy", failures)
	assert_true(complete_strategy.get("accepted_action_counts", {}).get("EndTurn", 0) == 334 and complete_strategy.get("partial_settlements", 0) == 334 and complete_strategy.get("complete_hand_settlements", 0) == 668, "strategy distributions aggregate accepted actions and both settlement types", failures)

func test_streaming_rejects_wrong_gate_like_batch_aggregation(failures: Array[String]) -> void:
	var profile := _profile(1000)
	var wrong_gate_attempt := _successful_attempt(0, "base.character.a", "base.contract.a")
	wrong_gate_attempt["gate_id"] = "wrong.gate"
	var batch: Dictionary = SimulationGateRunnerScript.aggregate(profile, [wrong_gate_attempt])
	var accumulator: Dictionary = SimulationGateRunnerScript.new_streaming_accumulator(profile)
	SimulationGateRunnerScript.accumulate_attempt(accumulator, wrong_gate_attempt)
	var streamed: Dictionary = SimulationGateRunnerScript.finish_streaming_aggregate(accumulator)
	assert_true(streamed == batch, "streaming validation rejects a wrong-gate attempt exactly like batch aggregation", failures)
	assert_true(streamed.get("invalid_attempts", []).size() == 1, "wrong-gate attempt remains a visible failure in the compact aggregate", failures)
	var errors: Array = streamed.get("invalid_attempts", [{}])[0].get("errors", [])
	assert_true(errors.has("GATE_ID_MISMATCH"), "streaming error details include the expected-gate mismatch", failures)

func test_content_use_reports_observed_ids_and_declared_unused_catalog_items(failures: Array[String]) -> void:
	var profile := _profile(1)
	profile["content_use_catalog"] = {
		"source": "GitHub issue #87 accepted production content budget",
		"categories": {
			"characters": ["base.character.a", "base.character.unused"],
			"contracts": ["base.contract.a", "base.contract.unused"],
			"yaku": ["base.yaku.used", "base.yaku.unused"],
			"relics": ["alpha.relic.selected", "alpha.relic.owned", "alpha.relic.unused"],
			"rule_breakers": ["alpha.rule_breaker.selected", "alpha.rule_breaker.unused"],
			"techniques": {
				"ids": ["alpha.technique.used", "alpha.technique.owned", "alpha.technique.unused", "alpha.technique.core.owned", "alpha.technique.core.unused"],
				"source": "GitHub issue #87: 21 Run Techniques plus 3 Character Core Techniques",
				"subcategories": {
					"run_techniques": ["alpha.technique.used", "alpha.technique.owned", "alpha.technique.unused"],
					"core_techniques": ["alpha.technique.core.owned", "alpha.technique.core.unused"],
				},
			},
			"modifiers": ["alpha.modifier.used", "alpha.modifier.unused"],
			"normal_enemies": {
				"ids": ["alpha.enemy.normal", "alpha.enemy.normal_unused"],
				"subcategories": {
					"act_1": {"ids": ["alpha.enemy.normal"], "evidence_kind": "act_1_encountered", "source": "#87 Act 1 Normal budget"},
					"act_2": {"ids": ["alpha.enemy.normal_unused"], "evidence_kind": "act_2_encountered", "source": "#87 Act 2 Normal budget"},
				},
			},
			"elite_enemies": ["alpha.enemy.elite", "alpha.enemy.elite_unused"],
			"bosses": ["alpha.boss.act_one", "alpha.boss.act_two", "alpha.boss.unused"],
			"events": ["alpha.event.used", "alpha.event.unused"],
			"acts": ["ACT_1", "ACT_2"],
		},
		"unobservable_categories": ["Tile definitions have observed IDs but no #87 production denominator."],
	}
	var attempt := _successful_attempt(0, "base.character.a", "base.contract.a")
	attempt.events.insert(2, _event("BattleStarted", {"encounter_kind": "NORMAL", "enemy_ids": ["alpha.enemy.normal"]}))
	attempt.events.insert(2, _event("BattleStarted", {"encounter_kind": "ELITE", "enemy_ids": ["alpha.enemy.elite"]}))
	attempt.events.insert(2, _event("BattleStarted", {"encounter_kind": "BOSS", "enemy_ids": ["alpha.boss.act_one"]}))
	attempt.events.append(_event("EventEntered", {"event_id": "alpha.event.used"}))
	attempt.events.append(_event("TechniqueUsed", {"technique_id": "alpha.technique.used"}))
	attempt.events.append(_event("RunModifierChanged", {"modifier_id": "alpha.modifier.used"}))
	attempt.events.append(_event("RewardSelected", {"kind": "RELIC", "content_id": "alpha.relic.selected"}))
	attempt.events.append(_event("RewardSelected", {"kind": "RULE_BREAKER", "content_id": "alpha.rule_breaker.selected"}))
	for index in range(attempt.events.size()):
		var event: Dictionary = attempt.events[index]
		if str(event.get("event_type", "")) == "RunSummaryReached":
			var data: Dictionary = event.get("data", {})
			data["summary_data"] = {
				"act_index": 2,
				"core_yaku": {"base.yaku.used": 1},
				"relics": ["alpha.relic.owned"],
				"techniques": ["alpha.technique.owned", "alpha.technique.core.owned"],
				"rule_breakers": ["alpha.rule_breaker.selected"],
			}
			event["data"] = data
			attempt.events[index] = event
			break
	var result: Dictionary = SimulationGateRunnerScript.aggregate(profile, [attempt])
	var content_use: Dictionary = result.get("coverage", {}).get("content_use", {})
	var categories: Dictionary = content_use.get("categories", {})
	assert_true(content_use.get("scope", "") == "OBSERVED_SELECTION_OWNERSHIP_ACTIVATION_SCORING_AND_ENCOUNTER_EVIDENCE", "content IDs are reported with distinct observed evidence kinds, not a completeness or interaction claim", failures)
	assert_true(content_use.get("catalog_source", "") == "GitHub issue #87 accepted production content budget", "content denominators name the accepted budget source", failures)
	assert_true(content_use.get("unobservable_categories", []).has("Tile definitions have observed IDs but no #87 production denominator."), "categories without an accepted denominator are called out explicitly", failures)
	assert_true(categories.get("characters", {}).get("catalog_id_count", 0) == 2 and categories.get("characters", {}).get("unused_ids", []) == ["base.character.unused"], "character use reports its catalog denominator and unused IDs", failures)
	assert_true(categories.get("relics", {}).get("observed_ids", []) == ["alpha.relic.owned", "alpha.relic.selected"], "relic use includes selected and final owned IDs", failures)
	assert_true(categories.get("relics", {}).get("evidence", {}).get("selected_ids", []) == ["alpha.relic.selected"] and categories.get("relics", {}).get("evidence", {}).get("owned_at_summary_ids", []) == ["alpha.relic.owned"], "relic selection and final ownership remain separately visible", failures)
	assert_true(categories.get("techniques", {}).get("observed_ids", []) == ["alpha.technique.core.owned", "alpha.technique.owned", "alpha.technique.used"], "Technique evidence combines but distinguishes actual activation and final ownership", failures)
	assert_true(categories.get("techniques", {}).get("subcategories", {}).get("run_techniques", {}).get("catalog_id_count", 0) == 3 and categories.get("techniques", {}).get("subcategories", {}).get("core_techniques", {}).get("catalog_id_count", 0) == 2, "the combined Technique denominator retains separate Run and Character Core budgets", failures)
	assert_true(categories.get("techniques", {}).get("evidence", {}).get("activated_ids", []) == ["alpha.technique.used"] and categories.get("techniques", {}).get("evidence", {}).get("owned_at_summary_ids", []) == ["alpha.technique.core.owned", "alpha.technique.owned"], "Technique activation and ownership are distinct observed facts", failures)
	assert_true(categories.get("yaku", {}).get("unused_ids", []) == ["base.yaku.unused"], "Yaku use reports content present in the budget but not observed in the Run", failures)
	assert_true(categories.get("normal_enemies", {}).get("observed_ids", []) == ["alpha.enemy.normal"], "enemy coverage is classified from the factual BattleStarted encounter kind", failures)
	assert_true(categories.get("normal_enemies", {}).get("subcategories", {}).get("act_1", {}).get("observed_ids", []) == ["alpha.enemy.normal"] and categories.get("normal_enemies", {}).get("subcategories", {}).get("act_2", {}).get("unused_ids", []) == ["alpha.enemy.normal_unused"], "enemy catalog subcategories retain Act-qualified observed-versus-unused IDs", failures)

func _profile(attempt_count: int) -> Dictionary:
	return {
		"gate_id": "hardening",
		"attempt_count": attempt_count,
		"required_run_count": 1000,
		"required_character_ids": ["base.character.a", "base.character.b"],
		"required_contract_ids": ["base.contract.a", "base.contract.b", "base.contract.c"],
		"required_policy_ids": ["Complete", "Hybrid", "Partial"],
		"required_act_boundaries": ["ACT_1_BOSS_REWARD_TO_ACT_2", "ACT_2_BOSS_REWARD_TO_SUMMARY"],
		"required_reward_paths": ["NORMAL_REWARD", "ELITE_REWARD", "BOSS_RULE_BREAKER"],
		"available_reward_paths": ["NORMAL_REWARD", "ELITE_REWARD", "BOSS_RULE_BREAKER", "ACT_1_BOSS_RULE_BREAKER_THREE_CHOICES"],
		"not_yet_introduced_reward_paths": ["ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"],
		"not_yet_introduced_content_ids": ["alpha.act_two.boss_rule_breaker_pool"],
		"full_alpha_roster_claim": false,
	}

func _successful_attempts(count: int) -> Array:
	var attempts: Array = []
	var characters := ["base.character.a", "base.character.b"]
	var contracts := ["base.contract.a", "base.contract.b", "base.contract.c"]
	for index in range(count):
		attempts.append(_successful_attempt(index, characters[index % characters.size()], contracts[index % contracts.size()]))
	return attempts

func _successful_attempt(index: int, character_id: String, contract_id: String) -> Dictionary:
	return {
		"gate_id": "hardening",
		"attempt_id": "hardening.%05d" % (index + 1),
		"two_act_profile": true,
		"policy_id": ["Complete", "Hybrid", "Partial"][index % 3],
		"act_reached": 2,
		"terminal": true,
		"outcome": "VICTORY",
		"failure_classification": "NONE",
		"replay_status": "MATCH",
		"authoritative_state_valid": true,
		"accepted_command_count": 2,
		"accepted_commands": [{"command_type": "ChooseCharacter"}, {"command_type": "ChooseContract"}],
		"checkpoints": [{"state_hash": "checkpoint.0"}, {"state_hash": "checkpoint.1"}, {"state_hash": "checkpoint.2"}],
		"checkpoint_hashes": ["hash.0", "hash.1", "hash.2"],
		"rng_snapshots": [{}, {}, {}],
		"strategy": {"policy_id": ["Complete", "Hybrid", "Partial"][index % 3]},
		"character_id": "scheduled.character.label.must.not.count",
		"contract_id": "scheduled.contract.label.must.not.count",
		"events": [
			_event("CharacterSelected", {"character_id": character_id}),
			_event("ContractSelected", {"contract_id": contract_id}),
			_event("RewardSelected", {"phase": "MAP_CHOICE", "kind": "ADD_TILE"}),
			_event("RewardSelected", {"reward_phase": "ELITE_REWARD", "kind": "RELIC"}),
			_event("BattleOutcomeTransferred", {"encounter_kind": "BOSS", "outcome": "VICTORY"}),
			_boss_draft_event("act1"),
			_event("RewardSelected", {"reward_phase": "BOSS_REWARD", "kind": "RULE_BREAKER"}),
			_event("ActTransitioned", {"from_act": 1, "to_act": 2}),
			_event("BattleOutcomeTransferred", {"encounter_kind": "BOSS", "outcome": "VICTORY"}),
			_boss_draft_event("act2"),
			_event("RewardSelected", {"reward_phase": "BOSS_REWARD", "kind": "RULE_BREAKER"}),
			_event("RunSummaryReached", {"outcome": "VICTORY", "summary_data": {"act_index": 2}}),
		],
	}

func _act_two_pool_unavailable_attempts(count: int) -> Array:
	var attempts: Array = []
	for index in range(count):
		attempts.append({
			"gate_id": "hardening",
			"attempt_id": "hardening.%05d" % (index + 1),
			"two_act_profile": true,
			"act_reached": 2,
			"terminal": false,
			"outcome": "ONGOING",
			"failure_classification": "CONTENT_UNAVAILABLE",
			"replay_status": "MATCH",
			"authoritative_state_valid": null,
			"unavailable_content_paths": ["alpha.act_two.boss_rule_breaker_pool"],
			"events": [
				_event("CharacterSelected", {"character_id": "base.character.a"}),
				_event("ContractSelected", {"contract_id": "base.contract.a"}),
				_event("BattleOutcomeTransferred", {"encounter_kind": "BOSS", "outcome": "VICTORY"}),
				_boss_draft_event("act1"),
				_event("RewardSelected", {"reward_phase": "BOSS_REWARD", "kind": "RULE_BREAKER"}),
				_event("ActTransitioned", {"from_act": 1, "to_act": 2}),
				_event("BattleOutcomeTransferred", {"encounter_kind": "BOSS", "outcome": "VICTORY"}),
				_event("RewardDraftCreated", {"draft": _boss_draft("act2", 2)}),
			],
		})
	return attempts

func _boss_draft_event(prefix: String) -> Dictionary:
	return _event("RewardDraftCreated", {"draft": _boss_draft(prefix, 3)})

func _boss_draft(prefix: String, option_count: int) -> Dictionary:
	var options: Array[Dictionary] = []
	for index in range(option_count):
		options.append({
			"option_id": "%s.option.%d" % [prefix, index + 1],
			"kind": "RULE_BREAKER",
			"content_id": "%s.rule_breaker.%d" % [prefix, index + 1],
		})
	return {
		"draft_kind": "BOSS_RULE_BREAKER",
		"encounter_kind": "BOSS",
		"options": options,
	}

func _valid_act_one_defeat() -> Dictionary:
	return {
		"gate_id": "hardening",
		"attempt_id": "hardening.00001",
		"two_act_profile": true,
		"policy_id": "Partial",
		"act_reached": 1,
		"terminal": true,
		"outcome": "DEFEAT",
		"failure_classification": "NONE",
		"replay_status": "MATCH",
		"authoritative_state_valid": true,
		"accepted_command_count": 2,
		"accepted_commands": [{"command_type": "ChooseCharacter"}, {"command_type": "ChooseContract"}],
		"checkpoints": [{"state_hash": "checkpoint.0"}, {"state_hash": "checkpoint.1"}, {"state_hash": "checkpoint.2"}],
		"checkpoint_hashes": ["hash.0", "hash.1", "hash.2"],
		"rng_snapshots": [{}, {}, {}],
		"strategy": {"policy_id": "Partial"},
		"events": [
			_event("CharacterSelected", {"character_id": "base.character.a"}),
			_event("ContractSelected", {"contract_id": "base.contract.a"}),
			_event("BattleOutcomeTransferred", {"encounter_kind": "BOSS", "outcome": "DEFEAT"}),
			_event("RunSummaryReached", {"outcome": "DEFEAT", "summary_data": {"act_index": 1}}),
		],
	}

func _event(event_type: String, data: Dictionary) -> Dictionary:
	return {"event_type": event_type, "data": data}

func _reward_path_status(reward_detail: Dictionary, reward_path_id: String) -> Dictionary:
	for status_value in reward_detail.get("requirement_statuses", []):
		if status_value is Dictionary and str(status_value.get("id", "")) == reward_path_id:
			return status_value
	return {}

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
