class_name SimulationGateRunner
extends RefCounted

const REQUIRED_ATTEMPT_COUNT := 1000
const REQUIRED_POLICIES: Array[String] = ["Complete", "Hybrid", "Partial"]
const REQUIRED_ACTS: Array[String] = ["ACT_1", "ACT_2"]
const REQUIRED_ACT_BOUNDARIES: Array[String] = [
	"ACT_1_BOSS_REWARD_TO_ACT_2",
	"ACT_2_BOSS_REWARD_TO_SUMMARY",
]
const REQUIRED_BOSS_OUTCOMES: Array[String] = ["ACT_1_BOSS", "ACT_2_BOSS"]
const REQUIRED_REWARD_PATHS: Array[String] = ["NORMAL_REWARD", "ELITE_REWARD", "BOSS_RULE_BREAKER"]
const ACT_1_BOSS_THREE_CHOICE_PATH := "ACT_1_BOSS_RULE_BREAKER_THREE_CHOICES"
const ACT_2_BOSS_THREE_CHOICE_PATH := "ACT_2_BOSS_RULE_BREAKER_THREE_CHOICES"
const ACT_2_BOSS_POOL_CONTENT_ID := "alpha.act_two.boss_rule_breaker_pool"
const VALID_OUTCOMES := ["VICTORY", "DEFEAT"]
const CONTENT_USE_FAMILIES := [
	"acts",
	"characters",
	"contracts",
	"yaku",
	"relics",
	"rule_breakers",
	"techniques",
	"modifiers",
	"normal_enemies",
	"elite_enemies",
	"bosses",
	"events",
	"tiles",
]

static func aggregate(gate_profile: Dictionary, attempt_results: Array) -> Dictionary:
	var observed := _empty_observed()
	var seen_attempt_ids := {}
	var duplicate_attempt_ids: Array[String] = []
	var invalid_attempts: Array[Dictionary] = []
	var attempt_failure_count := 0
	var valid_victory_count := 0
	var valid_defeat_count := 0
	var outcome_counts := {"VICTORY": 0, "DEFEAT": 0}
	var policy_outcome_counts := _empty_policy_outcomes()
	var strategy_distributions := _empty_strategy_distributions()

	for index in range(attempt_results.size()):
		var attempt_value = attempt_results[index]
		if not attempt_value is Dictionary:
			invalid_attempts.append({"index": index, "attempt_id": "", "errors": ["INVALID_ATTEMPT_RECORD"]})
			attempt_failure_count += 1
			continue
		var attempt: Dictionary = attempt_value
		var attempt_id := str(attempt.get("attempt_id", ""))
		var errors := _attempt_errors(attempt, str(gate_profile.get("gate_id", "")))
		if attempt_id.is_empty():
			errors.append("MISSING_ATTEMPT_ID")
		elif seen_attempt_ids.has(attempt_id):
			if not duplicate_attempt_ids.has(attempt_id):
				duplicate_attempt_ids.append(attempt_id)
			errors.append("DUPLICATE_ATTEMPT_ID")
		else:
			seen_attempt_ids[attempt_id] = true

		var outcome := str(attempt.get("outcome", ""))
		if outcome_counts.has(outcome) and bool(attempt.get("terminal", false)):
			outcome_counts[outcome] += 1
			var policy_outcomes: Dictionary = policy_outcome_counts.get(str(attempt.get("policy_id", "")), {})
			if policy_outcomes.has(outcome):
				policy_outcomes[outcome] += 1
		if errors.is_empty():
			if outcome == "VICTORY":
				valid_victory_count += 1
			else:
				valid_defeat_count += 1
		else:
			attempt_failure_count += 1
			invalid_attempts.append({"index": index, "attempt_id": attempt_id, "errors": errors})

		if str(gate_profile.get("gate_id", "")).is_empty() or str(attempt.get("gate_id", "")) == str(gate_profile.get("gate_id", "")):
			_collect_attempt_coverage(attempt, observed)
		_accumulate_strategy_distribution(strategy_distributions, _strategy_distribution_summary(attempt))

	duplicate_attempt_ids.sort()
	return _assemble_aggregate_result(
		gate_profile,
		observed,
		attempt_results.size(),
		seen_attempt_ids.size(),
		duplicate_attempt_ids,
		invalid_attempts,
		attempt_failure_count,
		valid_victory_count,
		valid_defeat_count,
		outcome_counts,
		_policy_distribution(attempt_results),
		policy_outcome_counts,
		strategy_distributions,
	)

static func _assemble_aggregate_result(
	gate_profile: Dictionary,
	observed: Dictionary,
	attempt_count: int,
	distinct_attempt_count: int,
	duplicate_attempt_ids: Array,
	invalid_attempts: Array,
	attempt_failure_count: int,
	valid_victory_count: int,
	valid_defeat_count: int,
	outcome_counts: Dictionary,
	policy_distribution: Dictionary,
	policy_outcome_counts: Dictionary,
	strategy_distributions: Dictionary,
) -> Dictionary:
	var gate_id := str(gate_profile.get("gate_id", ""))
	var profile_attempt_count := int(gate_profile.get("attempt_count", 0))
	var profile_errors: Array[String] = []
	if gate_id.is_empty():
		profile_errors.append("MISSING_GATE_ID")
	if int(gate_profile.get("required_run_count", REQUIRED_ATTEMPT_COUNT)) != REQUIRED_ATTEMPT_COUNT:
		profile_errors.append("REQUIRED_RUN_COUNT_MISMATCH")
	if profile_attempt_count != REQUIRED_ATTEMPT_COUNT:
		profile_errors.append("PROFILE_ATTEMPT_COUNT_MISMATCH")

	var required_characters := _strings(gate_profile.get("required_character_ids", gate_profile.get("character_ids", [])))
	var required_contracts := _strings(gate_profile.get("required_contract_ids", gate_profile.get("contract_ids", [])))
	var required_policies := _with_required(_strings(gate_profile.get("required_policy_ids", [])), REQUIRED_POLICIES)
	if required_characters.is_empty():
		profile_errors.append("MISSING_REQUIRED_CHARACTERS")
	if required_contracts.is_empty():
		profile_errors.append("MISSING_REQUIRED_CONTRACTS")
	var required_boundaries := _with_required(_strings(gate_profile.get("required_act_boundaries", [])), REQUIRED_ACT_BOUNDARIES)
	var required_rewards := _with_required(
		_strings(gate_profile.get("required_reward_paths", [])),
		REQUIRED_REWARD_PATHS + [ACT_1_BOSS_THREE_CHOICE_PATH, ACT_2_BOSS_THREE_CHOICE_PATH],
	)
	var available_reward_paths := _strings(gate_profile.get("available_reward_paths", []))
	var not_yet_reward_paths := _strings(gate_profile.get("not_yet_introduced_reward_paths", []))
	for reward_path in required_rewards:
		var declared_available := available_reward_paths.has(reward_path)
		var declared_not_yet := not_yet_reward_paths.has(reward_path)
		if declared_available == declared_not_yet:
			profile_errors.append("REWARD_PATH_AVAILABILITY_UNDECLARED_OR_CONFLICTING:%s" % reward_path)

	var actual_characters := _keys(observed.get("characters", {}))
	var actual_contracts := _keys(observed.get("contracts", {}))
	var actual_policies := _keys(observed.get("policies", {}))
	var actual_acts := _keys(observed.get("acts", {}))
	var actual_boundaries := _keys(observed.get("act_boss_boundaries", {}))
	var actual_rewards := _keys(observed.get("reward_paths", {}))
	for reward_path in not_yet_reward_paths:
		actual_rewards.erase(reward_path)
		if observed.get("reward_paths", {}).has(reward_path):
			profile_errors.append("NOT_YET_AVAILABLE_REWARD_PATH_WAS_OBSERVED:%s" % reward_path)
	var no_not_yet_ids: Array[String] = []
	var not_yet_characters := _filter_observed(
		_strings(gate_profile.get("not_yet_introduced_character_ids", [])) + _strings(gate_profile.get("missing_character_content_ids", [])),
		actual_characters,
	)
	var not_yet_contracts := _filter_observed(
		_strings(gate_profile.get("not_yet_introduced_contract_ids", [])) + _strings(gate_profile.get("missing_contract_content_ids", [])),
		actual_contracts,
	)
	var not_yet_boundaries := _filter_observed(_strings(gate_profile.get("not_yet_introduced_act_boundaries", [])), actual_boundaries)
	var unavailable_content_ids := _strings(gate_profile.get("not_yet_introduced_content_ids", []))
	for observed_unavailable_id in _keys(observed.get("unavailable_content_ids", {})):
		_append_unique(unavailable_content_ids, observed_unavailable_id)
	var act_two_pool_available := available_reward_paths.has(ACT_2_BOSS_THREE_CHOICE_PATH)
	if not act_two_pool_available and not_yet_reward_paths.has(ACT_2_BOSS_THREE_CHOICE_PATH):
		_append_unique(unavailable_content_ids, ACT_2_BOSS_POOL_CONTENT_ID)
	if observed.get("unavailable_content_ids", {}).has(ACT_2_BOSS_POOL_CONTENT_ID) and act_two_pool_available:
		profile_errors.append("PROFILE_MARKED_ACT_2_BOSS_POOL_AVAILABLE_BUT_ATTEMPT_REPORTED_UNAVAILABLE")
	unavailable_content_ids.sort()

	var coverage := {
		"acts": _coverage_detail(REQUIRED_ACTS, actual_acts, no_not_yet_ids),
		"act_boss_boundaries": _coverage_detail(required_boundaries, actual_boundaries, not_yet_boundaries),
		"boss_outcomes": _coverage_detail(REQUIRED_BOSS_OUTCOMES, _keys(observed.get("boss_outcomes", {})), no_not_yet_ids),
		"reward_paths": _reward_coverage_detail(required_rewards, actual_rewards, not_yet_reward_paths, available_reward_paths),
		"characters": _coverage_detail(required_characters, actual_characters, not_yet_characters),
		"contracts": _coverage_detail(required_contracts, actual_contracts, not_yet_contracts),
		"policies": _coverage_detail(required_policies, actual_policies, no_not_yet_ids),
		"content_use": _content_use_report(gate_profile, observed),
	}
	var coverage_complete := true
	for dimension in ["acts", "act_boss_boundaries", "boss_outcomes", "reward_paths", "characters", "contracts", "policies"]:
		if not bool(coverage[dimension].get("coverage_complete", false)):
			coverage_complete = false
	var not_yet_introduced := {
		"characters": not_yet_characters,
		"contracts": not_yet_contracts,
		"act_boundaries": not_yet_boundaries,
		"reward_paths": not_yet_reward_paths,
		"content_ids": unavailable_content_ids,
		"other": _strings(gate_profile.get("not_yet_introduced_requirement_ids", [])),
	}
	var duplicate_ids: Array[String] = []
	for identifier in duplicate_attempt_ids:
		duplicate_ids.append(str(identifier))
	duplicate_ids.sort()
	var integrity_valid := invalid_attempts.is_empty() and duplicate_ids.is_empty()
	var profile_attempt_count_met := profile_attempt_count == REQUIRED_ATTEMPT_COUNT
	var attempt_count_met := attempt_count == REQUIRED_ATTEMPT_COUNT
	var result_count_status := "EXACT" if attempt_count_met else "UNDER" if attempt_count < REQUIRED_ATTEMPT_COUNT else "OVER"
	var gate_pass := (
		profile_errors.is_empty()
		and profile_attempt_count_met
		and attempt_count_met
		and integrity_valid
		and attempt_failure_count == 0
		and coverage_complete
	)
	var gate_status := "PASS" if gate_pass else _gate_status(
		profile_errors,
		profile_attempt_count_met,
		attempt_count_met,
		integrity_valid,
		attempt_failure_count,
		coverage,
	)
	return {
		"gate_id": gate_id,
		"result_scope": "SEEDED_SIMULATION_COVERAGE_ONLY",
		"report_valid": true,
		"required_attempt_count": REQUIRED_ATTEMPT_COUNT,
		"profile_attempt_count": profile_attempt_count,
		"attempts_received": attempt_count,
		"profile_attempt_count_met": profile_attempt_count_met,
		"attempt_count_met": attempt_count_met,
		"attempt_count_status": result_count_status,
		"distinct_attempt_count": distinct_attempt_count,
		"duplicate_attempt_ids": duplicate_ids,
		"profile_errors": profile_errors,
		"attempt_integrity_valid": integrity_valid,
		"invalid_attempts": invalid_attempts,
		"attempt_failure_count": attempt_failure_count,
		"valid_victory_count": valid_victory_count,
		"valid_defeat_count": valid_defeat_count,
		"terminal_outcome_counts": outcome_counts,
		"policy_distribution": policy_distribution,
		"policy_outcome_counts": policy_outcome_counts,
		"strategy_distributions": strategy_distributions,
		"coverage": coverage,
		"coverage_complete": coverage_complete,
		"unavailable_content_ids": unavailable_content_ids,
		"observed_act_two_three_choice_draft": bool(observed.get("act_2_boss_three_choice_pool_available", false)),
		"not_yet_introduced_requirements": not_yet_introduced,
		"alpha_full_roster_claim": false,
		"gate_pass": gate_pass,
		"gate_status": gate_status,
	}

static func new_streaming_accumulator(gate_profile: Dictionary) -> Dictionary:
	var baseline: Dictionary = aggregate(gate_profile, [])
	return {
		"baseline": baseline,
		"gate_profile": gate_profile.duplicate(true),
		"gate_id": str(baseline.get("gate_id", "")),
		"profile_errors": baseline.get("profile_errors", []).duplicate(),
		"profile_attempt_count": int(baseline.get("profile_attempt_count", 0)),
		"profile_attempt_count_met": bool(baseline.get("profile_attempt_count_met", false)),
		"observed": _empty_observed(),
		"seen_attempt_ids": {},
		"duplicate_attempt_ids": [],
		"invalid_attempts": [],
		"attempt_count": 0,
		"attempt_failure_count": 0,
		"valid_victory_count": 0,
		"valid_defeat_count": 0,
		"outcome_counts": {"VICTORY": 0, "DEFEAT": 0},
		"policy_distribution": {"Complete": 0, "Hybrid": 0, "Partial": 0},
		"policy_outcome_counts": _empty_policy_outcomes(),
		"strategy_distributions": _empty_strategy_distributions(),
	}

static func summarize_attempt(attempt: Dictionary, expected_gate_id = null) -> Dictionary:
	var attempt_gate_id := str(attempt.get("gate_id", ""))
	var validation_gate_id := attempt_gate_id if expected_gate_id == null else str(expected_gate_id)
	var observed := _empty_observed()
	if validation_gate_id.is_empty() or attempt_gate_id == validation_gate_id:
		_collect_attempt_coverage(attempt, observed)
	var strategy = attempt.get("strategy", {})
	return {
		"manifest_hash": str(attempt.get("manifest_hash", "")),
		"attempt_id": str(attempt.get("attempt_id", "")),
		"gate_id": attempt_gate_id,
		"seed": int(attempt.get("seed", 0)),
		"policy_id": str(attempt.get("policy_id", "")),
		"strategy_policy_id": str(strategy.get("policy_id", "")) if strategy is Dictionary else "",
		"strategy_distribution": _strategy_distribution_summary(attempt),
		"character_id": str(attempt.get("character_id", "")),
		"contract_id": str(attempt.get("contract_id", "")),
		"route_id": str(attempt.get("route_id", "")),
		"act_reached": int(attempt.get("act_reached", 0)),
		"terminal": bool(attempt.get("terminal", false)),
		"outcome": str(attempt.get("outcome", "")),
		"two_act_profile": bool(attempt.get("two_act_profile", false)),
		"configured_act_count": int(attempt.get("configured_act_count", 0)),
		"accepted_command_count": int(attempt.get("accepted_command_count", -1)),
		"accepted_command_array_count": attempt.get("accepted_commands", []).size() if attempt.get("accepted_commands", null) is Array else -1,
		"checkpoint_count": attempt.get("checkpoints", []).size() if attempt.get("checkpoints", null) is Array else -1,
		"checkpoint_hash_count": attempt.get("checkpoint_hashes", []).size() if attempt.get("checkpoint_hashes", null) is Array else -1,
		"rng_snapshot_count": attempt.get("rng_snapshots", []).size() if attempt.get("rng_snapshots", null) is Array else -1,
		"checkpoint_hashes_nonempty": _all_checkpoint_hashes_nonempty(attempt.get("checkpoint_hashes", [])),
		"event_count": attempt.get("events", []).size() if attempt.get("events", null) is Array else -1,
		"failure_classification": str(attempt.get("failure_classification", "")),
		"failure_detail": str(attempt.get("failure_detail", "")),
		"replay_status": str(attempt.get("replay_status", "")),
		"authoritative_state_valid": attempt.get("authoritative_state_valid", null),
		"content_available": bool(attempt.get("content_available", false)),
		"unavailable_content_paths": _strings(attempt.get("unavailable_content_paths", [])),
		"elapsed_msec": int(attempt.get("elapsed_msec", 0)),
		"gate_validation_errors": _attempt_errors(attempt, validation_gate_id),
		"coverage_contribution": _coverage_snapshot(observed),
	}

static func accumulate_attempt(accumulator: Dictionary, attempt: Dictionary) -> void:
	accumulate_summary(accumulator, summarize_attempt(attempt, str(accumulator.get("gate_id", ""))))

static func accumulate_summary(accumulator: Dictionary, summary: Dictionary) -> void:
	if not accumulator.has("observed"):
		return
	var index := int(accumulator.get("attempt_count", 0))
	accumulator["attempt_count"] = index + 1
	var attempt_id := str(summary.get("attempt_id", ""))
	var errors: Array[String] = []
	var error_values = summary.get("gate_validation_errors", [])
	if error_values is Array:
		for error_value in error_values:
			errors.append(str(error_value))
	else:
		errors.append("MISSING_GATE_VALIDATION_SUMMARY")
	if attempt_id.is_empty():
		errors.append("MISSING_ATTEMPT_ID")
	elif accumulator.seen_attempt_ids.has(attempt_id):
		if not accumulator.duplicate_attempt_ids.has(attempt_id):
			accumulator.duplicate_attempt_ids.append(attempt_id)
		errors.append("DUPLICATE_ATTEMPT_ID")
	else:
		accumulator.seen_attempt_ids[attempt_id] = true
	var outcome := str(summary.get("outcome", ""))
	if bool(summary.get("terminal", false)) and accumulator.outcome_counts.has(outcome):
		accumulator.outcome_counts[outcome] += 1
		var policy_outcomes: Dictionary = accumulator.policy_outcome_counts.get(str(summary.get("policy_id", "")), {})
		if policy_outcomes.has(outcome):
			policy_outcomes[outcome] += 1
	if errors.is_empty():
		if outcome == "VICTORY":
			accumulator["valid_victory_count"] = int(accumulator.get("valid_victory_count", 0)) + 1
		else:
			accumulator["valid_defeat_count"] = int(accumulator.get("valid_defeat_count", 0)) + 1
	else:
		accumulator["attempt_failure_count"] = int(accumulator.get("attempt_failure_count", 0)) + 1
		accumulator.invalid_attempts.append({"index": index, "attempt_id": attempt_id, "errors": errors})
	var policy_id := str(summary.get("policy_id", ""))
	if accumulator.policy_distribution.has(policy_id):
		accumulator.policy_distribution[policy_id] += 1
	_accumulate_strategy_distribution(accumulator.strategy_distributions, summary.get("strategy_distribution", {}))
	var contribution = summary.get("coverage_contribution", {})
	if contribution is Dictionary:
		_merge_coverage(accumulator.observed, contribution)

static func finish_streaming_aggregate(accumulator: Dictionary) -> Dictionary:
	if not accumulator.has("baseline") or not accumulator.get("gate_profile", null) is Dictionary:
		return {"report_valid": false, "gate_pass": false, "gate_status": "INVALID_ACCUMULATOR"}
	var duplicate_attempt_ids: Array = accumulator.get("duplicate_attempt_ids", []).duplicate()
	duplicate_attempt_ids.sort()
	return _assemble_aggregate_result(
		accumulator.get("gate_profile", {}),
		accumulator.get("observed", _empty_observed()),
		int(accumulator.get("attempt_count", 0)),
		accumulator.get("seen_attempt_ids", {}).size(),
		duplicate_attempt_ids,
		accumulator.get("invalid_attempts", []).duplicate(true),
		int(accumulator.get("attempt_failure_count", 0)),
		int(accumulator.get("valid_victory_count", 0)),
		int(accumulator.get("valid_defeat_count", 0)),
		accumulator.get("outcome_counts", {"VICTORY": 0, "DEFEAT": 0}).duplicate(true),
		accumulator.get("policy_distribution", {}).duplicate(true),
		accumulator.get("policy_outcome_counts", {}).duplicate(true),
		accumulator.get("strategy_distributions", _empty_strategy_distributions()).duplicate(true),
	)

static func _empty_observed() -> Dictionary:
	var content_use := {}
	for family in CONTENT_USE_FAMILIES:
		content_use[family] = {}
	return {
		"acts": {},
		"act_boss_boundaries": {},
		"boss_outcomes": {},
		"reward_paths": {},
		"characters": {},
		"contracts": {},
		"policies": {},
		"act_2_boss_three_choice_pool_available": false,
		"unavailable_content_ids": {},
		"content_use": content_use,
	}

static func _empty_policy_outcomes() -> Dictionary:
	return {
		"Complete": {"VICTORY": 0, "DEFEAT": 0},
		"Hybrid": {"VICTORY": 0, "DEFEAT": 0},
		"Partial": {"VICTORY": 0, "DEFEAT": 0},
	}

static func _empty_strategy_distributions() -> Dictionary:
	var distributions := {}
	for policy_id in REQUIRED_POLICIES:
		distributions[policy_id] = {
			"attempt_count": 0,
			"accepted_command_count": 0,
			"accepted_action_counts": {},
			"partial_settlements": 0,
			"complete_hand_settlements": 0,
		}
	distributions["UNKNOWN"] = {
		"attempt_count": 0,
		"accepted_command_count": 0,
		"accepted_action_counts": {},
		"partial_settlements": 0,
		"complete_hand_settlements": 0,
	}
	return distributions

static func _strategy_distribution_summary(attempt: Dictionary) -> Dictionary:
	var strategy_value = attempt.get("strategy", {})
	var strategy: Dictionary = strategy_value if strategy_value is Dictionary else {}
	var action_counts_value = strategy.get("accepted_action_counts", {})
	var action_counts: Dictionary = action_counts_value.duplicate(true) if action_counts_value is Dictionary else {}
	return {
		"policy_id": str(strategy.get("policy_id", "")),
		"accepted_command_count": maxi(0, int(attempt.get("accepted_command_count", 0))),
		"accepted_action_counts": action_counts,
		"partial_settlements": maxi(0, int(strategy.get("partial_settlements", 0))),
		"complete_hand_settlements": maxi(0, int(strategy.get("complete_hand_settlements", 0))),
	}

static func _accumulate_strategy_distribution(distributions: Dictionary, summary_value) -> void:
	var summary: Dictionary = summary_value if summary_value is Dictionary else {}
	var policy_id := str(summary.get("policy_id", ""))
	if not distributions.has(policy_id):
		policy_id = "UNKNOWN"
	var bucket: Dictionary = distributions.get(policy_id, {})
	if bucket.is_empty():
		return
	bucket["attempt_count"] = int(bucket.get("attempt_count", 0)) + 1
	bucket["accepted_command_count"] = int(bucket.get("accepted_command_count", 0)) + int(summary.get("accepted_command_count", 0))
	bucket["partial_settlements"] = int(bucket.get("partial_settlements", 0)) + int(summary.get("partial_settlements", 0))
	bucket["complete_hand_settlements"] = int(bucket.get("complete_hand_settlements", 0)) + int(summary.get("complete_hand_settlements", 0))
	var action_counts_value = summary.get("accepted_action_counts", {})
	if action_counts_value is Dictionary:
		var action_counts: Dictionary = bucket.get("accepted_action_counts", {})
		for action_value in action_counts_value.keys():
			var action_id := str(action_value)
			action_counts[action_id] = int(action_counts.get(action_id, 0)) + maxi(0, int(action_counts_value[action_value]))
		bucket["accepted_action_counts"] = action_counts
	distributions[policy_id] = bucket

static func _coverage_snapshot(observed: Dictionary) -> Dictionary:
	var result := {}
	for dimension in ["acts", "act_boss_boundaries", "boss_outcomes", "reward_paths", "characters", "contracts", "policies", "unavailable_content_ids"]:
		result[dimension] = _keys(observed.get(dimension, {}))
	result["act_2_boss_three_choice_pool_available"] = bool(observed.get("act_2_boss_three_choice_pool_available", false))
	result["content_use"] = _content_use_snapshot(observed.get("content_use", {}))
	return result

static func _merge_coverage(observed: Dictionary, contribution: Dictionary) -> void:
	for dimension in ["acts", "act_boss_boundaries", "boss_outcomes", "reward_paths", "characters", "contracts", "policies", "unavailable_content_ids"]:
		for identifier in _strings(contribution.get(dimension, [])):
			observed[dimension][identifier] = true
	observed["act_2_boss_three_choice_pool_available"] = bool(observed.get("act_2_boss_three_choice_pool_available", false)) or bool(contribution.get("act_2_boss_three_choice_pool_available", false))
	_merge_content_use(observed.get("content_use", {}), contribution.get("content_use", {}))

static func _content_use_snapshot(content_use: Dictionary) -> Dictionary:
	var result := {}
	for family in CONTENT_USE_FAMILIES:
		var evidence_sets: Dictionary = content_use.get(family, {})
		var evidence := {}
		for evidence_kind in evidence_sets:
			evidence["%s_ids" % str(evidence_kind)] = _keys(evidence_sets[evidence_kind])
		result[family] = evidence
	return result

static func _merge_content_use(target: Dictionary, contribution_value) -> void:
	if not contribution_value is Dictionary:
		return
	var contribution: Dictionary = contribution_value
	for family in CONTENT_USE_FAMILIES:
		var evidence_value = contribution.get(family, {})
		if not evidence_value is Dictionary:
			continue
		for evidence_kind in evidence_value:
			var ids = evidence_value[evidence_kind]
			if not ids is Array:
				continue
			for identifier in _strings(ids):
				_append_content_use(target, family, str(evidence_kind).trim_suffix("_ids"), identifier)

static func _append_content_use(observed: Dictionary, family: String, evidence_kind: String, identifier: String) -> void:
	var normalized_id := identifier.strip_edges()
	if normalized_id.is_empty() or not observed.has(family):
		return
	if not observed[family].has(evidence_kind):
		observed[family][evidence_kind] = {}
	observed[family][evidence_kind][normalized_id] = true

static func _append_content_values(observed: Dictionary, family: String, evidence_kind: String, values) -> void:
	if values is Array:
		for value in values:
			_append_content_use(observed, family, evidence_kind, str(value))
	elif values is Dictionary:
		for key in values.keys():
			_append_content_use(observed, family, evidence_kind, str(key))
	elif values is String:
		_append_content_use(observed, family, evidence_kind, values)

static func _content_use_report(gate_profile: Dictionary, observed: Dictionary) -> Dictionary:
	var catalog_value = gate_profile.get("content_use_catalog", {})
	var catalog: Dictionary = catalog_value if catalog_value is Dictionary else {}
	var catalog_categories_value = catalog.get("categories", {})
	var catalog_categories: Dictionary = catalog_categories_value if catalog_categories_value is Dictionary else {}
	var catalog_source := str(catalog.get("source", gate_profile.get("content_use_catalog_source", "")))
	var categories := {}
	var families := CONTENT_USE_FAMILIES.duplicate()
	for family_value in catalog_categories.keys():
		var family := str(family_value)
		if family not in families:
			families.append(family)
	families.sort()
	var observed_content: Dictionary = _content_use_snapshot(observed.get("content_use", {}))
	for family in families:
		var evidence_value = observed_content.get(family, {})
		var evidence: Dictionary = evidence_value if evidence_value is Dictionary else {}
		var observed_ids: Array[String] = []
		for ids_value in evidence.values():
			for identifier in _strings(ids_value):
				_append_unique(observed_ids, identifier)
		observed_ids.sort()
		var family_catalog_value = catalog_categories.get(family, null)
		var family_catalog: Dictionary = family_catalog_value if family_catalog_value is Dictionary else {}
		var catalog_ids_value = family_catalog.get("ids", family_catalog_value)
		var catalog_declared := catalog_categories.has(family) and catalog_ids_value is Array
		var catalog_ids = _strings(catalog_ids_value) if catalog_declared else []
		catalog_ids.sort()
		var unused_ids: Array[String] = []
		var observed_in_catalog: Array[String] = []
		var unexpected_ids: Array[String] = []
		for catalog_id in catalog_ids:
			if observed_ids.has(catalog_id):
				observed_in_catalog.append(catalog_id)
			else:
				unused_ids.append(catalog_id)
		for observed_id in observed_ids:
			if catalog_declared and not catalog_ids.has(observed_id):
				unexpected_ids.append(observed_id)
		var family_source := str(family_catalog.get("source", catalog_source)) if not family_catalog.is_empty() else catalog_source
		var category_report := {
			"catalog_status": "DECLARED" if catalog_declared else "NO_ACCEPTED_DENOMINATOR",
			"catalog_source": family_source,
			"catalog_id_count": catalog_ids.size() if catalog_declared else null,
			"observed_ids": observed_ids,
			"observed_id_count": observed_ids.size(),
			"observed_in_catalog_count": observed_in_catalog.size(),
			"unused_ids": unused_ids,
			"unexpected_observed_ids": unexpected_ids,
			"evidence": evidence,
		}
		var subcategories_value = family_catalog.get("subcategories", {})
		if subcategories_value is Dictionary:
			var subcategory_reports := {}
			for subcategory_value in subcategories_value:
				var subcategory := str(subcategory_value)
				var subcategory_definition = subcategories_value[subcategory_value]
				var subcategory_config: Dictionary = subcategory_definition if subcategory_definition is Dictionary else {}
				var subcategory_ids := _strings(subcategory_config.get("ids", subcategory_definition))
				subcategory_ids.sort()
				var evidence_kind := str(subcategory_config.get("evidence_kind", ""))
				var evidence_ids := _strings(evidence.get("%s_ids" % evidence_kind, [])) if not evidence_kind.is_empty() else observed_ids
				var subcategory_observed: Array[String] = []
				for identifier in subcategory_ids:
					if evidence_ids.has(identifier):
						subcategory_observed.append(identifier)
				var subcategory_unused: Array[String] = []
				for identifier in subcategory_ids:
					if not subcategory_observed.has(identifier):
						subcategory_unused.append(identifier)
				subcategory_reports[subcategory] = {
					"catalog_id_count": subcategory_ids.size(),
					"observed_ids": subcategory_observed,
					"unused_ids": subcategory_unused,
					"evidence_kind": evidence_kind,
					"catalog_source": str(subcategory_config.get("source", family_source)),
				}
			category_report["subcategories"] = subcategory_reports
		categories[family] = category_report
	return {
		"scope": "OBSERVED_SELECTION_OWNERSHIP_ACTIVATION_SCORING_AND_ENCOUNTER_EVIDENCE",
		"catalog_source": catalog_source,
		"categories": categories,
		"unobservable_categories": _strings(catalog.get("unobservable_categories", [])),
	}

static func _all_checkpoint_hashes_nonempty(values) -> bool:
	if not values is Array:
		return false
	for value in values:
		if str(value).is_empty():
			return false
	return true

static func _attempt_errors(attempt: Dictionary, expected_gate_id: String) -> Array[String]:
	var errors: Array[String] = []
	if str(attempt.get("attempt_id", "")).is_empty():
		errors.append("MISSING_ATTEMPT_ID")
	if str(attempt.get("gate_id", "")) != expected_gate_id:
		errors.append("GATE_ID_MISMATCH")
	var policy_id := str(attempt.get("policy_id", ""))
	if policy_id not in REQUIRED_POLICIES:
		errors.append("UNSUPPORTED_POLICY")
	var strategy = attempt.get("strategy", {})
	if not strategy is Dictionary or str(strategy.get("policy_id", "")) != policy_id:
		errors.append("STRATEGY_POLICY_MISMATCH")
	var commands = attempt.get("accepted_commands", null)
	var checkpoints = attempt.get("checkpoints", null)
	var checkpoint_hashes = attempt.get("checkpoint_hashes", null)
	var rng_snapshots = attempt.get("rng_snapshots", null)
	if not commands is Array or not checkpoints is Array or not checkpoint_hashes is Array or not rng_snapshots is Array:
		errors.append("MISSING_TRACE_DATA")
	else:
		if int(attempt.get("accepted_command_count", -1)) != commands.size():
			errors.append("ACCEPTED_COMMAND_COUNT_MISMATCH")
		if checkpoints.size() != commands.size() + 1:
			errors.append("CHECKPOINT_COUNT_MISMATCH")
		if checkpoint_hashes.size() != checkpoints.size() or rng_snapshots.size() != checkpoints.size():
			errors.append("CHECKPOINT_METADATA_COUNT_MISMATCH")
		for checkpoint_hash in checkpoint_hashes:
			if str(checkpoint_hash).is_empty():
				errors.append("EMPTY_CHECKPOINT_HASH")
				break
	var events = attempt.get("events", null)
	if not events is Array or events.is_empty():
		errors.append("MISSING_FACTUAL_EVENTS")
	if not bool(attempt.get("two_act_profile", false)):
		errors.append("NOT_TWO_ACT_PROFILE")
	if not bool(attempt.get("terminal", false)) or str(attempt.get("outcome", "")) not in VALID_OUTCOMES:
		errors.append("INCOMPLETE_RUN")
	if str(attempt.get("failure_classification", "")) != "NONE":
		errors.append("ATTEMPT_FAILURE:%s" % str(attempt.get("failure_classification", "UNCLASSIFIED")))
	if str(attempt.get("replay_status", "")) != "MATCH":
		errors.append("REPLAY_NOT_MATCHED")
	if attempt.get("authoritative_state_valid", false) != true:
		errors.append("AUTHORITATIVE_STATE_NOT_VALID")
	return errors

static func _collect_attempt_coverage(attempt: Dictionary, observed: Dictionary) -> void:
	_append_observed(observed["policies"], str(attempt.get("policy_id", "")))
	for unavailable_id in _strings(attempt.get("unavailable_content_paths", [])):
		observed["unavailable_content_ids"][unavailable_id] = true
	var active_act := 1
	var boss_won_by_act := {}
	var boss_three_choice_reward_selected_by_act := {}
	var act_one_three_choice_draft_valid := false
	var act_two_three_choice_draft_valid := false
	var act_one_pool_content_ids := {}
	var events = attempt.get("events", [])
	if not events is Array:
		return
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var event_type := str(event.get("event_type", ""))
		var data = event.get("data", {})
		if not data is Dictionary:
			continue
		match event_type:
			"CharacterSelected":
				observed["acts"]["ACT_1"] = true
				var character_id := str(data.get("character_id", ""))
				_append_observed(observed["characters"], character_id)
				_append_content_use(observed["content_use"], "characters", "selected", character_id)
				_append_content_use(observed["content_use"], "acts", "reached", "ACT_1")
			"ContractSelected":
				observed["acts"]["ACT_1"] = true
				var contract_id := str(data.get("contract_id", ""))
				_append_observed(observed["contracts"], contract_id)
				_append_content_use(observed["content_use"], "contracts", "selected", contract_id)
				_append_content_use(observed["content_use"], "acts", "reached", "ACT_1")
			"BattleStarted":
				var enemy_family := _enemy_content_family(str(data.get("encounter_kind", "")))
				if not enemy_family.is_empty():
					_append_content_values(observed["content_use"], enemy_family, "encountered", data.get("enemy_ids", []))
					_append_content_values(observed["content_use"], enemy_family, "act_%d_encountered" % active_act, data.get("enemy_ids", []))
			"EventEntered":
				_append_content_use(observed["content_use"], "events", "activated", str(data.get("event_id", "")))
			"TechniqueUsed":
				_append_content_use(observed["content_use"], "techniques", "activated", str(data.get("technique_id", "")))
			"RunModifierChanged", "WorkshopServiceUsed":
				_append_content_use(observed["content_use"], "modifiers", "activated", str(data.get("modifier_id", "")))
			"BattleOutcomeTransferred":
				if str(data.get("encounter_kind", "")) == "BOSS":
					observed["acts"]["ACT_%d" % active_act] = true
					observed["boss_outcomes"]["ACT_%d_BOSS" % active_act] = true
					boss_won_by_act[active_act] = str(data.get("outcome", "")) == "VICTORY"
			"RewardDraftCreated":
				if active_act == 1:
					var act_one_content_ids := _three_choice_boss_draft_content_ids(data.get("draft", {}), {})
					if act_one_content_ids.size() == 3:
						act_one_three_choice_draft_valid = true
						for content_id in act_one_content_ids:
							act_one_pool_content_ids[content_id] = true
				elif active_act == 2:
					var act_two_content_ids := _three_choice_boss_draft_content_ids(data.get("draft", {}), act_one_pool_content_ids)
					if act_two_content_ids.size() == 3:
						act_two_three_choice_draft_valid = true
						observed["act_2_boss_three_choice_pool_available"] = true
			"RewardSelected":
				_collect_reward_content_use(observed["content_use"], data)
				var reward_phase := str(data.get("reward_phase", ""))
				if reward_phase.is_empty() and str(data.get("phase", "")) == "MAP_CHOICE":
					reward_phase = "REWARD_CHOICE"
				if reward_phase == "REWARD_CHOICE":
					observed["reward_paths"]["NORMAL_REWARD"] = true
				elif reward_phase == "ELITE_REWARD":
					observed["reward_paths"]["ELITE_REWARD"] = true
				elif reward_phase == "BOSS_REWARD" and str(data.get("kind", "")) == "RULE_BREAKER":
					observed["reward_paths"]["BOSS_RULE_BREAKER"] = true
					if active_act == 1 and act_one_three_choice_draft_valid:
						boss_three_choice_reward_selected_by_act[active_act] = true
						observed["reward_paths"][ACT_1_BOSS_THREE_CHOICE_PATH] = true
					elif active_act == 2 and act_two_three_choice_draft_valid:
						boss_three_choice_reward_selected_by_act[active_act] = true
						observed["reward_paths"][ACT_2_BOSS_THREE_CHOICE_PATH] = true
			"ActTransitioned":
				if int(data.get("from_act", -1)) == 1 and int(data.get("to_act", -1)) == 2:
					observed["acts"]["ACT_2"] = true
					_append_content_use(observed["content_use"], "acts", "reached", "ACT_2")
					if bool(boss_won_by_act.get(1, false)) and bool(boss_three_choice_reward_selected_by_act.get(1, false)):
						observed["act_boss_boundaries"]["ACT_1_BOSS_REWARD_TO_ACT_2"] = true
					active_act = 2
			"RunSummaryReached":
				var summary_data = data.get("summary_data", {})
				if not summary_data is Dictionary:
					summary_data = {}
				_collect_summary_content_use(observed["content_use"], summary_data)
				var summary_act := int(summary_data.get("act_index", active_act))
				if (
					summary_act == 2
					and str(data.get("outcome", "")) == "VICTORY"
					and bool(boss_won_by_act.get(2, false))
					and bool(boss_three_choice_reward_selected_by_act.get(2, false))
				):
					observed["act_boss_boundaries"]["ACT_2_BOSS_REWARD_TO_SUMMARY"] = true

static func _enemy_content_family(encounter_kind: String) -> String:
	match encounter_kind:
		"NORMAL":
			return "normal_enemies"
		"ELITE":
			return "elite_enemies"
		"BOSS":
			return "bosses"
	return ""

static func _collect_reward_content_use(content_use: Dictionary, data: Dictionary) -> void:
	var kind := str(data.get("kind", ""))
	var content_id := str(data.get("content_id", ""))
	match kind:
		"RELIC":
			_append_content_use(content_use, "relics", "selected", content_id)
		"RUN_TECHNIQUE":
			_append_content_use(content_use, "techniques", "selected", content_id)
		"RULE_BREAKER":
			_append_content_use(content_use, "rule_breakers", "selected", content_id)
		"ADD_TILE":
			_append_content_use(content_use, "tiles", "selected", str(data.get("tile_id", content_id)))
		"MODIFIED_TILE":
			_append_content_use(content_use, "modifiers", "selected", str(data.get("modifier_id", "")))
	if not str(data.get("modifier_id", "")).is_empty():
		_append_content_use(content_use, "modifiers", "selected", str(data.get("modifier_id", "")))
	if not str(data.get("tile_id", "")).is_empty():
		_append_content_use(content_use, "tiles", "selected", str(data.get("tile_id", "")))

static func _collect_summary_content_use(content_use: Dictionary, summary_data: Dictionary) -> void:
	_append_content_values(content_use, "relics", "owned_at_summary", summary_data.get("relics", []))
	_append_content_values(content_use, "techniques", "owned_at_summary", summary_data.get("techniques", []))
	_append_content_values(content_use, "rule_breakers", "owned_at_summary", summary_data.get("rule_breakers", []))
	_append_content_values(content_use, "yaku", "scored", summary_data.get("core_yaku", {}))
	var tile_pool = summary_data.get("final_tile_pool", [])
	if tile_pool is Array:
		for tile_value in tile_pool:
			if tile_value is Dictionary:
				_append_content_use(content_use, "tiles", "owned_at_summary", str(tile_value.get("definition_id", "")))

static func _three_choice_boss_draft_content_ids(draft_value, excluded_content_ids: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not draft_value is Dictionary:
		return result
	var draft: Dictionary = draft_value
	if str(draft.get("draft_kind", "")) != "BOSS_RULE_BREAKER" or str(draft.get("encounter_kind", "")) != "BOSS":
		return result
	var options = draft.get("options", [])
	if not options is Array or options.size() != 3:
		return result
	var option_ids := {}
	for option_value in options:
		if not option_value is Dictionary:
			return []
		var option: Dictionary = option_value
		var option_id := str(option.get("option_id", ""))
		var content_id := str(option.get("content_id", ""))
		if str(option.get("kind", "")) != "RULE_BREAKER" or option_id.is_empty() or content_id.is_empty():
			return []
		if option_ids.has(option_id) or excluded_content_ids.has(content_id) or result.has(content_id):
			return []
		option_ids[option_id] = true
		result.append(content_id)
	return result

static func _coverage_detail(required_ids: Array[String], observed_ids: Array[String], not_yet_ids: Array[String]) -> Dictionary:
	var missing: Array[String] = []
	for required_id in required_ids:
		if not observed_ids.has(required_id):
			missing.append(required_id)
	return {
		"required_ids": required_ids.duplicate(),
		"observed_ids": observed_ids.duplicate(),
		"missing_required_ids": missing,
		"not_yet_introduced_ids": not_yet_ids.duplicate(),
		"coverage_complete": missing.is_empty(),
	}

static func _reward_coverage_detail(
	required_ids: Array[String],
	observed_ids: Array[String],
	not_yet_ids: Array[String],
	available_ids: Array[String],
) -> Dictionary:
	var detail := _coverage_detail(required_ids, observed_ids, not_yet_ids)
	var statuses: Array[Dictionary] = []
	var all_requirements_covered := true
	for reward_path in required_ids:
		var availability_status := "AVAILABLE" if available_ids.has(reward_path) else "NOT_AVAILABLE" if not_yet_ids.has(reward_path) else "UNDECLARED"
		var covered := availability_status == "AVAILABLE" and observed_ids.has(reward_path)
		if not covered:
			all_requirements_covered = false
		statuses.append({
			"id": reward_path,
			"availability_status": availability_status,
			"coverage_status": "COVERED" if covered else "NOT_COVERED",
			"observed_three_choice_draft": observed_ids.has(reward_path),
			"covered": covered,
		})
	detail["requirement_statuses"] = statuses
	detail["coverage_complete"] = all_requirements_covered
	return detail

static func _gate_status(
	profile_errors: Array[String],
	profile_attempt_count_met: bool,
	attempt_count_met: bool,
	attempt_integrity_valid: bool,
	attempt_failure_count: int,
	coverage: Dictionary,
) -> String:
	if not profile_errors.is_empty():
		return "INVALID_PROFILE"
	if not profile_attempt_count_met or not attempt_count_met:
		return "INCOMPLETE_ATTEMPT_COUNT"
	var reward_detail: Dictionary = coverage.get("reward_paths", {})
	for status in reward_detail.get("requirement_statuses", []):
		if str(status.get("availability_status", "")) == "NOT_AVAILABLE":
			return "REQUIREMENTS_NOT_YET_AVAILABLE"
		if str(status.get("availability_status", "")) == "UNDECLARED":
			return "INVALID_PROFILE"
	if not attempt_integrity_valid or attempt_failure_count > 0:
		return "ATTEMPT_FAILURES"
	for dimension in ["acts", "act_boss_boundaries", "boss_outcomes", "reward_paths", "characters", "contracts", "policies"]:
		var detail: Dictionary = coverage.get(dimension, {})
		if not bool(detail.get("coverage_complete", false)):
			return "COVERAGE_GAP"
	return "PASS"

static func _policy_distribution(attempt_results: Array) -> Dictionary:
	var counts := {"Complete": 0, "Hybrid": 0, "Partial": 0}
	for attempt_value in attempt_results:
		if not attempt_value is Dictionary:
			continue
		var policy_id := str(attempt_value.get("policy_id", ""))
		if counts.has(policy_id):
			counts[policy_id] += 1
	return counts

static func _with_required(configured: Array[String], required: Array) -> Array[String]:
	var result := configured.duplicate()
	for identifier_value in required:
		var identifier := str(identifier_value)
		if not result.has(identifier):
			result.append(identifier)
	result.sort()
	return result

static func _strings(values) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		if value is String and not value.is_empty() and not result.has(value):
			result.append(value)
	result.sort()
	return result

static func _filter_observed(values: Array[String], observed_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if not observed_ids.has(value):
			_append_unique(result, value)
	result.sort()
	return result

static func _append_unique(values: Array[String], value: String) -> void:
	if not value.is_empty() and not values.has(value):
		values.append(value)

static func _append_observed(observed: Dictionary, value: String) -> void:
	if not value.is_empty():
		observed[value] = true

static func _keys(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for value in values.keys():
		result.append(str(value))
	result.sort()
	return result
