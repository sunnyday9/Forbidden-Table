class_name SettlePatternCommand
extends "res://src/domain/commands/battle_command.gd"

var _instance_ids: Array[String]

var instance_ids: Array[String]:
	get:
		return _instance_ids.duplicate()

func _init(
	identifier: String,
	selected_instance_ids: Array,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	_instance_ids = []
	for instance_id in selected_instance_ids:
		if instance_id is String:
			_instance_ids.append(instance_id)

func command_type() -> String:
	return "SettlePattern"

func _payload_dictionary() -> Dictionary:
	var serialized_ids: Array[String] = instance_ids
	serialized_ids.sort()
	return {"instance_ids": serialized_ids}

func validate(context) -> RefCounted:
	return context.validate_settlement(instance_ids)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_settlement(instance_ids)
