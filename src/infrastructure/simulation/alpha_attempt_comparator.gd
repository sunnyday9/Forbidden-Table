class_name AlphaAttemptComparator
extends RefCounted

const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")

const DETERMINISTIC_FIELDS := [
	"manifest_hash",
	"gate_id",
	"seed",
	"policy_id",
	"character_id",
	"contract_id",
	"route_id",
	"accepted_command_count",
	"accepted_commands",
	"checkpoint_hashes",
	"rng_snapshots",
	"events",
	"strategy",
	"outcome",
	"two_act_profile",
	"configured_act_count",
	"act_reached",
	"progress_status",
	"terminal",
	"content_available",
	"unavailable_content_paths",
	"failure_classification",
]

static func compare(expected: Dictionary, actual: Dictionary) -> Dictionary:
	var expected_fields := field_fingerprints(expected)
	var actual_fields := field_fingerprints(actual)
	return compare_field_fingerprints(expected_fields, actual_fields)

static func field_fingerprints(attempt: Dictionary) -> Dictionary:
	var result := {}
	for field in DETERMINISTIC_FIELDS:
		result[field] = DeterministicSerializerScript.hash({
			"present": attempt.has(field),
			"value": _fingerprint_value(attempt.get(field)),
		})
	return result

static func _fingerprint_value(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key in value.keys():
				result[str(key)] = _fingerprint_value(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_fingerprint_value(item))
			return result
		TYPE_INT:
			return value
		TYPE_FLOAT:
			var number := float(value)
			if is_finite(number) and floor(number) == number and number >= -9007199254740991.0 and number <= 9007199254740991.0:
				return int(number)
			return value
		TYPE_OBJECT:
			if value != null and value.has_method("to_dictionary"):
				return _fingerprint_value(value.to_dictionary())
	return value

static func compare_field_fingerprints(expected: Dictionary, actual: Dictionary) -> Dictionary:
	var differences: Array[String] = []
	for field in DETERMINISTIC_FIELDS:
		if str(expected.get(field, "")) != str(actual.get(field, "")):
			differences.append(field)
	return {
		"matches": differences.is_empty(),
		"status": "MATCH" if differences.is_empty() else "DIVERGED",
		"differences": differences,
		"expected_projection_hash": DeterministicSerializerScript.hash(expected),
		"actual_projection_hash": DeterministicSerializerScript.hash(actual),
		"expected_field_hashes": expected.duplicate(true),
		"actual_field_hashes": actual.duplicate(true),
	}
