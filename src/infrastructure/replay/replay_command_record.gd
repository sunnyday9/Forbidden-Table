class_name ReplayCommandRecord
extends RefCounted

const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const ReplayCommandRecordScript = preload("res://src/infrastructure/replay/replay_command_record.gd")

var command_id: String
var command_type: String
var actor_id: String
var target_id: String
var preview: bool
var payload: Dictionary
var serialized_command: String

func _init(command_data: Dictionary = {}, recorded_serialized_command: String = "") -> void:
	command_id = str(command_data.get("command_id", ""))
	command_type = str(command_data.get("command_type", ""))
	actor_id = str(command_data.get("actor_id", ""))
	target_id = str(command_data.get("target_id", ""))
	preview = bool(command_data.get("preview", false))
	payload = {}
	for key in command_data.keys():
		if not ["command_id", "command_type", "actor_id", "target_id", "preview"].has(str(key)):
			payload[str(key)] = command_data[key]
	serialized_command = recorded_serialized_command if not recorded_serialized_command.is_empty() else DeterministicSerializerScript.serialize_command(to_command_dictionary())

func to_command_dictionary() -> Dictionary:
	var command_data := {
		"command_id": command_id,
		"command_type": command_type,
		"actor_id": actor_id,
		"target_id": target_id,
		"preview": preview,
	}
	for key in payload.keys():
		command_data[key] = payload[key]
	return command_data

func to_dictionary() -> Dictionary:
	return {
		"command_id": command_id,
		"command_type": command_type,
		"actor_id": actor_id,
		"target_id": target_id,
		"preview": preview,
		"payload": payload.duplicate(true),
		"serialized_command": serialized_command,
	}

func serialize() -> String:
	return DeterministicSerializerScript.serialize(to_dictionary())

static func from_dictionary(record_data: Dictionary):
	var command_data := {
		"command_id": record_data.get("command_id", ""),
		"command_type": record_data.get("command_type", ""),
		"actor_id": record_data.get("actor_id", ""),
		"target_id": record_data.get("target_id", ""),
		"preview": record_data.get("preview", false),
	}
	var payload: Dictionary = record_data.get("payload", {})
	for key in payload.keys():
		command_data[str(key)] = payload[key]
	return ReplayCommandRecordScript.new(command_data, str(record_data.get("serialized_command", "")))
