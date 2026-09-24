class_name ReplayRecord
extends RefCounted

const SCHEMA_VERSION := 1
const SnapshotDtoScript = preload("res://src/infrastructure/persistence/snapshot_dto.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const ReplayCommandRecordScript = preload("res://src/infrastructure/replay/replay_command_record.gd")
const ReplayCheckpointScript = preload("res://src/infrastructure/replay/replay_checkpoint.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")

var schema_version: int
var game_version: String
var run_seed: int
var run_id: String
var content_version: String
var commands: Array
var checkpoints: Array
var terminal_outcome: String

func _init(replay_seed: int, replay_content_version: String, replay_run_id: String = "", replay_game_version: String = SnapshotDtoScript.GAME_VERSION) -> void:
	schema_version = SCHEMA_VERSION
	game_version = replay_game_version
	run_seed = replay_seed
	run_id = replay_run_id
	content_version = replay_content_version
	commands = []
	checkpoints = []
	terminal_outcome = "ONGOING"

func record_initial_checkpoint(domain_checkpoint: Dictionary, rng_state: Dictionary, outcome: String, domain_events: Array = []) -> void:
	if not checkpoints.is_empty():
		return
	checkpoints.append(ReplayCheckpointScript.new(0, 0, domain_checkpoint, rng_state, outcome, _event_data(domain_events)))
	terminal_outcome = outcome

func record_command(command_data: Dictionary, domain_checkpoint: Dictionary, rng_state: Dictionary, outcome: String, domain_events: Array = []) -> void:
	var command := ReplayCommandRecordScript.new(command_data)
	commands.append(command)
	checkpoints.append(ReplayCheckpointScript.new(checkpoints.size(), commands.size(), domain_checkpoint, rng_state, outcome, _event_data(domain_events)))
	terminal_outcome = outcome

func to_dictionary() -> Dictionary:
	var command_data: Array = []
	for command in commands:
		command_data.append(command.to_dictionary())
	var checkpoint_data: Array = []
	for checkpoint in checkpoints:
		checkpoint_data.append(checkpoint.to_dictionary())
	return {
		"schema_version": schema_version,
		"game_version": game_version,
		"run_seed": run_seed,
		"run_id": run_id,
		"content_version": content_version,
		"commands": command_data,
		"checkpoints": checkpoint_data,
		"terminal_outcome": terminal_outcome,
	}

func serialize() -> String:
	return DeterministicSerializerScript.serialize(to_dictionary())

static func from_dictionary(record_data: Dictionary):
	var record := ReplayRecordScript.new(int(record_data.get("run_seed", 0)), str(record_data.get("content_version", "")), str(record_data.get("run_id", "")))
	record.schema_version = int(record_data.get("schema_version", SCHEMA_VERSION))
	# Missing game_version remains unsupported instead of being silently relabeled as the current game.
	record.game_version = str(record_data.get("game_version", ""))
	for command_data in record_data.get("commands", []):
		record.commands.append(ReplayCommandRecordScript.from_dictionary(command_data))
	for checkpoint_data in record_data.get("checkpoints", []):
		record.checkpoints.append(ReplayCheckpointScript.from_dictionary(checkpoint_data))
	record.terminal_outcome = str(record_data.get("terminal_outcome", "ONGOING"))
	return record

static func _event_data(events: Array) -> Array:
	var result: Array = []
	for event in events:
		if event != null and event.has_method("to_dictionary"):
			result.append(event.to_dictionary())
		elif event is Dictionary:
			result.append(event.duplicate(true))
	return result
