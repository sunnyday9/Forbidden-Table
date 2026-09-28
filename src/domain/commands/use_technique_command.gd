class_name UseTechniqueCommand
extends "res://src/domain/commands/battle_command.gd"

var technique_id: String

func _init(
	identifier: String,
	selected_technique_id: String,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	technique_id = selected_technique_id

func command_type() -> String:
	return "UseTechnique"

func _payload_dictionary() -> Dictionary:
	return {"technique_id": technique_id}

func validate(context) -> RefCounted:
	return context.validate_use_technique(technique_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_use_technique(technique_id)
