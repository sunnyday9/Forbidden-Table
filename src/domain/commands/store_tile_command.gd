class_name StoreTileCommand
extends "res://src/domain/commands/battle_command.gd"

var instance_id: String

func _init(
	identifier: String,
	selected_instance_id: String,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	instance_id = selected_instance_id

func command_type() -> String:
	return "StoreTile"

func _payload_dictionary() -> Dictionary:
	return {"instance_id": instance_id}

func validate(context) -> RefCounted:
	return context.validate_store_tile(instance_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_store_tile(instance_id)
