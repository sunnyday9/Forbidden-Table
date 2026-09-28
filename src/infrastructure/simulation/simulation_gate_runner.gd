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

static func aggregate(gate_profile: Dictionary, attempt_results: Array) -> Dictionary:
	var gate_id := str(gate_profile.get("gate_id", ""))
	var profile_attempt_count := int(gate_profile.get("attempt_count", 0))
	var profile_required_count := int(gate_profile.get("required_run_count", REQUIRED_ATTEMPT_COUNT))
	var profile_errors: Array[String] = []
	if gate_id.is_empty():
		profile_errors.append("MISSING_GATE_ID")
	if profile_required_count != REQUIRED_ATTEMPT_COUNT:
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
	var required_boundaries := _with_required(
		_strings(gate_profile.get("required_act_boundaries", [])),
		REQUIRED_ACT_BOUNDARIES,
	)
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

	var observed := {
		"acts": {},
		"act_boss_boundaries": {},
		"boss_outcomes": {},
		"reward_paths": {},
		"characters": {},
		"contracts": {},
		"policies": {},
		"act_2_boss_three_choice_pool_available": false,
		"unavailable_content_ids": {},
	}
	var seen_attempt_ids := {}
	var duplicate_attempt_ids: Array[String] = []
	var invalid_attempts: Array[Dictionary] = []
	var attempt_failure_count := 0
	var valid_victory_count := 0
	var valid_defeat_count := 0
	var outcome_counts := {"VICTORY": 0, "DEFEAT": 0}

	for index in range(attempt_results.size()):
		var attempt_value = attempt_results[index]
		if not attempt_value is Dictionary:
			invalid_attempts.append({"index": index, "attempt_id": "", "errors": ["INVALID_ATTEMPT_RECORD"]})
			attempt_failure_count += 1
			continue
		var attempt: Dictionary = attempt_value
		var attempt_id := str(attempt.get("attempt_id", ""))
		var errors := _attempt_errors(attempt, gate_id)
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
		if errors.is_empty():
			if outcome == "VICTORY":
				valid_victory_count += 1
			else:
				valid_defeat_count += 1
		else:
			attempt_failure_count += 1
			invalid_attempts.append({"index": index, "attempt_id": attempt_id, "errors": errors})

		if gate_id.is_empty() or str(attempt.get("gate_id", "")) == gate_id:
			_collect_attempt_coverage(attempt, observed)

	duplicate_attempt_ids.sort()
	var attempt_count_met := attempt_results.size() == REQUIRED_ATTEMPT_COUNT
	var profile_attempt_count_met := profile_attempt_count == REQUIRED_ATTEMPT_COUNT
	var result_count_status := "EXACT" if attempt_count_met else "UNDER" if attempt_results.size() < REQUIRED_ATTEMPT_COUNT else "OVER"
	var actual_characters := _keys(observed["characters"])
	var actual_contracts := _keys(observed["contracts"])
	var actual_policies := _keys(observed["policies"])
	var actual_acts := _keys(observed["acts"])
	var actual_boundaries := _keys(observed["act_boss_boundaries"])
	var actual_rewards := _keys(observed["reward_paths"])
	var no_not_yet_ids: Array[String] = []
	for reward_path in not_yet_reward_paths:
		actual_rewards.erase(reward_path)
		if observed["reward_paths"].has(reward_path):
			profile_errors.append("NOT_YET_AVAILABLE_REWARD_PATH_WAS_OBSERVED:%s" % reward_path)
	var act_two_pool_available := available_reward_paths.has(ACT_2_BOSS_THREE_CHOICE_PATH)

	var not_yet_characters := _filter_observed(
		_strings(gate_profile.get("not_yet_introduced_character_ids", [])) + _strings(gate_profile.get("missing_character_content_ids", [])),
		actual_characters,
	)
	var not_yet_contracts := _filter_observed(
		_strings(gate_profile.get("not_yet_introduced_contract_ids", [])) + _strings(gate_profile.get("missing_contract_content_ids", [])),
		actual_contracts,
	)
	var not_yet_boundaries := _filter_observed(
		_strings(gate_profile.get("not_yet_introduced_act_boundaries", [])),
		actual_boundaries,
	)
	var not_yet_rewards := not_yet_reward_paths.duplicate()
	var unavailable_content_ids := _strings(gate_profile.get("not_yet_introduced_content_ids", []))
	for observed_unavailable_id in _keys(observed["unavailable_content_ids"]):
		_append_unique(unavailable_content_ids, observed_unavailable_id)
	if not act_two_pool_available and not_yet_reward_paths.has(ACT_2_BOSS_THREE_CHOICE_PATH):
		_append_unique(unavailable_content_ids, ACT_2_BOSS_POOL_CONTENT_ID)
	if observed["unavailable_content_ids"].has(ACT_2_BOSS_POOL_CONTENT_ID) and act_two_pool_available:
		profile_errors.append("PROFILE_MARKED_ACT_2_BOSS_POOL_AVAILABLE_BUT_ATTEMPT_REPORTED_UNAVAILABLE")
	unavailable_content_ids.sort()

	var coverage := {
		"acts": _coverage_detail(REQUIRED_ACTS, actual_acts, no_not_yet_ids),
		"act_boss_boundaries": _coverage_detail(required_boundaries, actual_boundaries, not_yet_boundaries),
		"boss_outcomes": _coverage_detail(REQUIRED_BOSS_OUTCOMES, _keys(observed["boss_outcomes"]), no_not_yet_ids),
		"reward_paths": _reward_coverage_detail(
			required_rewards,
			actual_rewards,
			not_yet_rewards,
			available_reward_paths,
		),
		"characters": _coverage_detail(required_characters, actual_characters, not_yet_characters),
		"contracts": _coverage_detail(required_contracts, actual_contracts, not_yet_contracts),
		"policies": _coverage_detail(required_policies, actual_policies, no_not_yet_ids),
	}
	var coverage_complete := true
	for dimension in ["acts", "act_boss_boundaries", "boss_outcomes", "reward_paths", "characters", "contracts", "policies"]:
		if not bool(coverage[dimension].get("coverage_complete", false)):
			coverage_complete = false

	var not_yet_introduced := {
		"characters": not_yet_characters,
		"contracts": not_yet_contracts,
		"act_boundaries": not_yet_boundaries,
		"reward_paths": not_yet_rewards,
		"content_ids": unavailable_content_ids,
		"other": _strings(gate_profile.get("not_yet_introduced_requirement_ids", [])),
	}
	var attempt_integrity_valid := invalid_attempts.is_empty() and duplicate_attempt_ids.is_empty()
	var gate_pass := (
		profile_errors.is_empty()
		and profile_attempt_count_met
		and attempt_count_met
		and attempt_integrity_valid
		and attempt_failure_count == 0
		and coverage_complete
	)
	var gate_status := "PASS" if gate_pass else _gate_status(
		profile_errors,
		profile_attempt_count_met,
		attempt_count_met,
		attempt_integrity_valid,
		attempt_failure_count,
		coverage,
	)

	return {
		"gate_id": gate_id,
		"result_scope": "SEEDED_SIMULATION_COVERAGE_ONLY",
		"report_valid": true,
		"required_attempt_count": REQUIRED_ATTEMPT_COUNT,
		"profile_attempt_count": profile_attempt_count,
		"attempts_received": attempt_results.size(),
		"profile_attempt_count_met": profile_attempt_count_met,
		"attempt_count_met": attempt_count_met,
		"attempt_count_status": result_count_status,
		"distinct_attempt_count": seen_attempt_ids.size(),
		"duplicate_attempt_ids": duplicate_attempt_ids,
		"profile_errors": profile_errors,
		"attempt_integrity_valid": attempt_integrity_valid,
		"invalid_attempts": invalid_attempts,
		"attempt_failure_count": attempt_failure_count,
		"valid_victory_count": valid_victory_count,
		"valid_defeat_count": valid_defeat_count,
		"terminal_outcome_counts": outcome_counts,
		"policy_distribution": _policy_distribution(attempt_results),
		"coverage": coverage,
		"coverage_complete": coverage_complete,
		"unavailable_content_ids": unavailable_content_ids,
		"observed_act_two_three_choice_draft": bool(observed["act_2_boss_three_choice_pool_available"]),
		"not_yet_introduced_requirements": not_yet_introduced,
		"alpha_full_roster_claim": false,
		"gate_pass": gate_pass,
		"gate_status": gate_status,
	}

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
				_append_observed(observed["characters"], str(data.get("character_id", "")))
			"ContractSelected":
				observed["acts"]["ACT_1"] = true
				_append_observed(observed["contracts"], str(data.get("contract_id", "")))
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
					if bool(boss_won_by_act.get(1, false)) and bool(boss_three_choice_reward_selected_by_act.get(1, false)):
						observed["act_boss_boundaries"]["ACT_1_BOSS_REWARD_TO_ACT_2"] = true
					active_act = 2
			"RunSummaryReached":
				var summary_data = data.get("summary_data", {})
				if not summary_data is Dictionary:
					summary_data = {}
				var summary_act := int(summary_data.get("act_index", active_act))
				if (
					summary_act == 2
					and str(data.get("outcome", "")) == "VICTORY"
					and bool(boss_won_by_act.get(2, false))
					and bool(boss_three_choice_reward_selected_by_act.get(2, false))
				):
					observed["act_boss_boundaries"]["ACT_2_BOSS_REWARD_TO_SUMMARY"] = true

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
