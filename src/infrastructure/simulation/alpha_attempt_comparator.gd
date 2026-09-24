class_name AlphaAttemptComparator
extends RefCounted

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
	var differences: Array[String] = []
	for field in DETERMINISTIC_FIELDS:
		if expected.has(field) != actual.has(field) or expected.get(field) != actual.get(field):
			differences.append(field)
	return {
		"matches": differences.is_empty(),
		"status": "MATCH" if differences.is_empty() else "DIVERGED",
		"differences": differences,
	}
