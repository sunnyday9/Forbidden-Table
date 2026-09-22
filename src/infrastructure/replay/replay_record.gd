class_name ReplayRecord
extends RefCounted

const SCHEMA_VERSION := 1
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const ReplayCommandRecordScript = preload("res://src/infrastructure/replay/replay_command_record.gd")
const ReplayCheckpointScript = preload("res://src/infrastructure/replay/replay_checkpoint.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")

var schema_version: int
var run_seed: int
var content_version: String
var commands: Array
var checkpoints: Array
var terminal_outcome: String

func _init(replay_seed: int, replay_content_version: String) -> void:
	schema_version = SCHEMA_VERSION
	run_seed = replay_seed
	content_version = replay_content_version
	commands = []
	checkpoints = []
	terminal_outcome = "ONGOING"

func record_initial_checkpoint(domain_checkpoint: Dictionary, rng_state: Dictionary, outcome: String) -> void:
	if not checkpoints.is_empty():
		return
	checkpoints.append(ReplayCheckpointScript.new(0, 0, domain_checkpoint, rng_state, outcome))
	terminal_outcome = outcome

func record_command(command_data: Dictionary, domain_checkpoint: Dictionary, rng_state: Dictionary, outcome: String) -> void:
	var command := ReplayCommandRecordScript.new(command_data)
	commands.append(command)
	checkpoints.append(ReplayCheckpointScript.new(checkpoints.size(), commands.size(), domain_checkpoint, rng_state, outcome))
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
		"run_seed": run_seed,
		"content_version": content_version,
		"commands": command_data,
		"checkpoints": checkpoint_data,
		"terminal_outcome": terminal_outcome,
	}

func serialize() -> String:
	return DeterministicSerializerScript.serialize(to_dictionary())

static func from_dictionary(record_data: Dictionary):
	var record := ReplayRecordScript.new(int(record_data.get("run_seed", 0)), str(record_data.get("content_version", "")))
	record.schema_version = int(record_data.get("schema_version", SCHEMA_VERSION))
	for command_data in record_data.get("commands", []):
		record.commands.append(ReplayCommandRecordScript.from_dictionary(command_data))
	for checkpoint_data in record_data.get("checkpoints", []):
		record.checkpoints.append(ReplayCheckpointScript.from_dictionary(checkpoint_data))
	record.terminal_outcome = str(record_data.get("terminal_outcome", "ONGOING"))
	return record
