class_name ReplayCheckpoint
extends RefCounted

const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const DomainSnapshotScript = preload("res://src/infrastructure/serialization/domain_snapshot.gd")
const ReplayCheckpointScript = preload("res://src/infrastructure/replay/replay_checkpoint.gd")

var sequence_index: int
var command_index: int
var domain_state_hash: String
var domain_snapshot
var rng_state: Dictionary
var domain_events: Array
var terminal_outcome: String

func _init(
	checkpoint_sequence_index: int = 0,
	checkpoint_command_index: int = 0,
	checkpoint_snapshot: Dictionary = {},
	checkpoint_rng_state: Dictionary = {},
	checkpoint_terminal_outcome: String = "ONGOING",
	checkpoint_domain_events: Array = [],
) -> void:
	sequence_index = checkpoint_sequence_index
	command_index = checkpoint_command_index
	domain_snapshot = DomainSnapshotScript.new(checkpoint_snapshot)
	domain_state_hash = domain_snapshot.state_hash
	rng_state = checkpoint_rng_state.duplicate(true)
	domain_events = checkpoint_domain_events.duplicate(true)
	terminal_outcome = checkpoint_terminal_outcome

func to_dictionary() -> Dictionary:
	return {
		"sequence_index": sequence_index,
		"command_index": command_index,
		"domain_state_hash": domain_state_hash,
		"domain_snapshot": domain_snapshot.to_dictionary(),
		"rng_state": rng_state.duplicate(true),
		"domain_events": domain_events.duplicate(true),
		"terminal_outcome": terminal_outcome,
	}

func serialize() -> String:
	return DeterministicSerializerScript.serialize(to_dictionary())

static func from_dictionary(checkpoint_data: Dictionary):
	var snapshot_data: Dictionary = checkpoint_data.get("domain_snapshot", {}).get("data", {})
	var checkpoint := ReplayCheckpointScript.new(
		int(checkpoint_data.get("sequence_index", 0)),
		int(checkpoint_data.get("command_index", 0)),
		snapshot_data,
		checkpoint_data.get("rng_state", {}),
		str(checkpoint_data.get("terminal_outcome", "ONGOING")),
		checkpoint_data.get("domain_events", []),
	)
	if checkpoint_data.has("domain_state_hash"):
		checkpoint.domain_state_hash = str(checkpoint_data["domain_state_hash"])
	return checkpoint
