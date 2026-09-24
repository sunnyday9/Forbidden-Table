class_name SimulationCorpusResumeVerifier
extends RefCounted

const AttemptComparatorScript = preload("res://src/infrastructure/simulation/alpha_attempt_comparator.gd")

static func summarize_attempt(attempt: Dictionary) -> Dictionary:
	var checkpoints = attempt.get("checkpoints", [])
	return {
		"attempt_id": str(attempt.get("attempt_id", "")),
		"seed": int(attempt.get("seed", 0)),
		"policy_id": str(attempt.get("policy_id", "")),
		"act_reached": int(attempt.get("act_reached", 0)),
		"terminal": bool(attempt.get("terminal", false)),
		"outcome": str(attempt.get("outcome", "")),
		"accepted_command_count": int(attempt.get("accepted_command_count", 0)),
		"checkpoint_count": checkpoints.size() if checkpoints is Array else -1,
		"replay_status": str(attempt.get("replay_status", "")),
		"failure_classification": str(attempt.get("failure_classification", "")),
	}

static func validate_record(
	record: Dictionary,
	expected_case: Dictionary,
	manifest_hash: String,
	expected_case_number: int,
) -> Dictionary:
	var errors: Array[String] = []
	if str(record.get("record_type", "")) != "case":
		errors.append("record type is not case")
	if int(record.get("case_number", 0)) != expected_case_number:
		errors.append("nonsequential case number")

	var attempt_case_value = record.get("attempt_case", {})
	if not attempt_case_value is Dictionary:
		errors.append("attempt case is not an object")
	elif not _case_matches_manifest_case(attempt_case_value, expected_case):
		errors.append("case fields differ from the manifest")

	var attempt_value = record.get("attempt", {})
	var repeat_attempt_value = record.get("repeat_attempt", {})
	if not attempt_value is Dictionary:
		errors.append("attempt is not an object")
	if not repeat_attempt_value is Dictionary:
		errors.append("repeat attempt is missing or is not an object")

	if attempt_value is Dictionary and repeat_attempt_value is Dictionary:
		var attempt: Dictionary = attempt_value
		var repeat_attempt: Dictionary = repeat_attempt_value
		_append_attempt_identity_errors(attempt, expected_case, manifest_hash, "attempt", errors)
		_append_attempt_identity_errors(repeat_attempt, expected_case, manifest_hash, "repeat attempt", errors)
		var expected_comparison: Dictionary = AttemptComparatorScript.compare(attempt, repeat_attempt)
		var comparison_value = record.get("repeat_comparison", {})
		if not comparison_value is Dictionary or comparison_value != expected_comparison:
			errors.append("repeat comparison does not match the stored attempt pair")
		var expected_summary := summarize_attempt(repeat_attempt)
		var summary_value = record.get("repeat_attempt_summary", {})
		if not summary_value is Dictionary or summary_value != expected_summary:
			errors.append("repeat attempt summary does not match the stored repeat attempt")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
	}

static func _append_attempt_identity_errors(
	attempt: Dictionary,
	expected_case: Dictionary,
	manifest_hash: String,
	label: String,
	errors: Array[String],
) -> void:
	if str(attempt.get("manifest_hash", "")) != manifest_hash:
		errors.append("%s manifest hash differs" % label)
	for key in ["attempt_id", "gate_id", "policy_id", "character_id", "contract_id", "route_id"]:
		if str(attempt.get(key, "")) != str(expected_case.get(key, "")):
			errors.append("%s %s differs from the manifest" % [label, key])
	if int(attempt.get("seed", -1)) != int(expected_case.get("seed", -2)):
		errors.append("%s seed differs from the manifest" % label)

static func _case_matches_manifest_case(actual: Dictionary, expected: Dictionary) -> bool:
	for key in ["attempt_index", "seed"]:
		if int(actual.get(key, -1)) != int(expected.get(key, -2)):
			return false
	for key in ["attempt_id", "gate_id", "policy_id", "character_id", "contract_id", "route_id", "starting_pool_fixture_id"]:
		if str(actual.get(key, "")) != str(expected.get(key, "")):
			return false
	return true
