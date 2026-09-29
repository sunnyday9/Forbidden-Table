class_name SimulationCorpusResumeVerifier
extends RefCounted

const AttemptComparatorScript = preload("res://src/infrastructure/simulation/alpha_attempt_comparator.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const SimulationGateRunnerScript = preload("res://src/infrastructure/simulation/simulation_gate_runner.gd")

static func summarize_compact_attempt(attempt: Dictionary, expected_gate_id: String) -> Dictionary:
	var summary := SimulationGateRunnerScript.summarize_attempt(attempt, expected_gate_id)
	var field_hashes := AttemptComparatorScript.field_fingerprints(attempt)
	summary["deterministic_field_hashes"] = field_hashes
	summary["deterministic_projection_hash"] = DeterministicSerializerScript.hash(field_hashes)
	summary["compact_summary_hash"] = DeterministicSerializerScript.hash(_stable_digest_value(summary))
	return summary

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
	if record.has("attempt_summary"):
		_validate_compact_record(record, expected_case, manifest_hash, errors)
		return {"valid": errors.is_empty(), "errors": errors}

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
		if not summary_value is Dictionary or not _summary_matches(expected_summary, summary_value):
			errors.append("repeat attempt summary does not match the stored repeat attempt")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
	}

static func _validate_compact_record(
	record: Dictionary,
	expected_case: Dictionary,
	manifest_hash: String,
	errors: Array[String],
) -> void:
	if record.has("attempt") or record.has("repeat_attempt"):
		errors.append("compact case retains a full attempt trace")
	var attempt_value = record.get("attempt_summary", {})
	var repeat_value = record.get("repeat_attempt_summary", {})
	if not attempt_value is Dictionary:
		errors.append("attempt summary is missing or is not an object")
	if not repeat_value is Dictionary:
		errors.append("repeat attempt summary is missing or is not an object")
	if not attempt_value is Dictionary or not repeat_value is Dictionary:
		return
	var attempt: Dictionary = attempt_value
	var repeated: Dictionary = repeat_value
	_append_compact_identity_errors(attempt, expected_case, manifest_hash, "attempt summary", errors)
	_append_compact_identity_errors(repeated, expected_case, manifest_hash, "repeat attempt summary", errors)
	var attempt_fingerprints := _validate_compact_summary(attempt, "attempt summary", errors)
	var repeated_fingerprints := _validate_compact_summary(repeated, "repeat attempt summary", errors)
	var comparison_value = record.get("repeat_comparison", {})
	if not comparison_value is Dictionary:
		errors.append("repeat comparison is not an object")
		return
	var comparison: Dictionary = comparison_value
	var expected_hashes_value = comparison.get("expected_field_hashes", {})
	var actual_hashes_value = comparison.get("actual_field_hashes", {})
	if not expected_hashes_value is Dictionary or not actual_hashes_value is Dictionary:
		errors.append("repeat comparison field hashes are missing")
		return
	var expected_hashes: Dictionary = expected_hashes_value
	var actual_hashes: Dictionary = actual_hashes_value
	var required_fields: Array = AttemptComparatorScript.DETERMINISTIC_FIELDS
	if expected_hashes.size() != required_fields.size() or actual_hashes.size() != required_fields.size():
		errors.append("repeat comparison field hash count is invalid")
		return
	for field in required_fields:
		if not expected_hashes.has(field) or not actual_hashes.has(field):
			errors.append("repeat comparison is missing field hash %s" % str(field))
			return
		if typeof(expected_hashes[field]) != TYPE_STRING or typeof(actual_hashes[field]) != TYPE_STRING or str(expected_hashes[field]).is_empty() or str(actual_hashes[field]).is_empty():
			errors.append("repeat comparison contains invalid field hash %s" % str(field))
			return
	if expected_hashes != attempt_fingerprints or actual_hashes != repeated_fingerprints:
		errors.append("repeat comparison fingerprints differ from their compact attempt summaries")
	var projection := AttemptComparatorScript.compare_field_fingerprints(expected_hashes, actual_hashes)
	var reported_differences = comparison.get("differences", null)
	var differences_valid := reported_differences is Array
	if differences_valid:
		var prior_field_index := -1
		for difference_value in reported_differences:
			var field_index: int = required_fields.find(str(difference_value))
			if field_index <= prior_field_index:
				differences_valid = false
				break
			prior_field_index = field_index
		for hashed_difference in projection.get("differences", []):
			if not reported_differences.has(hashed_difference):
				differences_valid = false
				break
	var reported_matches := bool(comparison.get("matches", false))
	var expected_status := "MATCH" if reported_differences is Array and reported_differences.is_empty() else "DIVERGED"
	if (
		comparison.size() != 7
		or not differences_valid
		or reported_matches != (expected_status == "MATCH")
		or str(comparison.get("status", "")) != expected_status
		or str(comparison.get("expected_projection_hash", "")) != str(projection.get("expected_projection_hash", ""))
		or str(comparison.get("actual_projection_hash", "")) != str(projection.get("actual_projection_hash", ""))
	):
		errors.append("repeat comparison fields do not match the deterministic fingerprints")

static func _append_compact_identity_errors(
	summary: Dictionary,
	expected_case: Dictionary,
	manifest_hash: String,
	label: String,
	errors: Array[String],
) -> void:
	if str(summary.get("manifest_hash", "")) != manifest_hash:
		errors.append("%s manifest hash differs" % label)
	for key in ["attempt_id", "gate_id", "policy_id", "character_id", "contract_id", "route_id"]:
		if str(summary.get(key, "")) != str(expected_case.get(key, "")):
			errors.append("%s %s differs from the manifest" % [label, key])
	if int(summary.get("seed", -1)) != int(expected_case.get("seed", -2)):
		errors.append("%s seed differs from the manifest" % label)
	if str(summary.get("strategy_policy_id", "")) != str(expected_case.get("policy_id", "")):
		errors.append("%s strategy policy differs from the manifest" % label)
	if not summary.get("coverage_contribution", null) is Dictionary:
		errors.append("%s coverage contribution is missing" % label)

static func _validate_compact_summary(summary: Dictionary, label: String, errors: Array[String]) -> Dictionary:
	var hashes_value = summary.get("deterministic_field_hashes", {})
	if not hashes_value is Dictionary:
		errors.append("%s deterministic field hashes are missing" % label)
		return {}
	var hashes: Dictionary = hashes_value
	if hashes.size() != AttemptComparatorScript.DETERMINISTIC_FIELDS.size():
		errors.append("%s deterministic field hash count is invalid" % label)
		return {}
	for field in AttemptComparatorScript.DETERMINISTIC_FIELDS:
		if not hashes.has(field) or typeof(hashes[field]) != TYPE_STRING or str(hashes[field]).is_empty():
			errors.append("%s deterministic field hash %s is invalid" % [label, str(field)])
			return {}
	var projection_hash := DeterministicSerializerScript.hash(hashes)
	if str(summary.get("deterministic_projection_hash", "")) != projection_hash:
		errors.append("%s deterministic projection hash does not match its field hashes" % label)
	var digest_source := summary.duplicate(true)
	var stored_digest := str(digest_source.get("compact_summary_hash", ""))
	digest_source.erase("compact_summary_hash")
	if stored_digest.is_empty() or stored_digest != DeterministicSerializerScript.hash(_stable_digest_value(digest_source)):
		errors.append("%s compact summary/content digest is invalid" % label)
	return hashes

static func _stable_digest_value(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key in value.keys():
				result[str(key)] = _stable_digest_value(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_stable_digest_value(item))
			return result
		TYPE_FLOAT:
			var number := float(value)
			if is_finite(number) and floor(number) == number and number >= -9007199254740991.0 and number <= 9007199254740991.0:
				return int(number)
	return value

static func _summary_matches(expected: Dictionary, actual: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key in expected:
		if not actual.has(key):
			return false
		var expected_value = expected[key]
		var actual_value = actual[key]
		if typeof(expected_value) == TYPE_INT:
			if not _matches_json_integer(actual_value, int(expected_value)):
				return false
		elif typeof(expected_value) == TYPE_BOOL:
			if typeof(actual_value) != TYPE_BOOL or actual_value != expected_value:
				return false
		elif typeof(expected_value) == TYPE_STRING:
			if typeof(actual_value) != TYPE_STRING or actual_value != expected_value:
				return false
		else:
			return false
	return true

static func _matches_json_integer(value: Variant, expected: int) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) == expected
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	if not is_finite(number) or floor(number) != number:
		return false
	if number < -9223372036854775808.0 or number >= 9223372036854775808.0:
		return false
	return int(number) == expected

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
