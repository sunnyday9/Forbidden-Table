class_name SettlePatternCommand
extends "res://src/domain/commands/battle_command.gd"

var _instance_ids: Array[String]
var candidate_id: String

var instance_ids: Array[String]:
	get:
		return _instance_ids.duplicate()

func _init(
	identifier: String,
	selected_instance_ids: Array,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
	selected_candidate_id: String = "",
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	candidate_id = selected_candidate_id
	_instance_ids = []
	for instance_id in selected_instance_ids:
		if instance_id is String:
			_instance_ids.append(instance_id)

func command_type() -> String:
	return "SettlePattern"

func _payload_dictionary() -> Dictionary:
	var serialized_ids: Array[String] = instance_ids
	serialized_ids.sort()
	var payload := {"instance_ids": serialized_ids}
	if not candidate_id.is_empty():
		payload["candidate_id"] = candidate_id
	return payload

func validate(context) -> RefCounted:
	if not candidate_id.is_empty():
		return context.validate_settlement_candidate(candidate_id)
	return context.validate_settlement(instance_ids)

func _execute_authoritatively(context) -> Dictionary:
	if not candidate_id.is_empty():
		return context.execute_settlement_candidate(candidate_id)
	return context.execute_settlement(instance_ids)
