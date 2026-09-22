class_name ChooseCharacterCommand
extends "res://src/domain/commands/run_command.gd"

var character_id: String

func _init(
	identifier: String,
	selected_character_id: String,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	character_id = selected_character_id

func command_type() -> String:
	return "ChooseCharacter"

func _payload_dictionary() -> Dictionary:
	return {"character_id": character_id}

func validate(context) -> RefCounted:
	return context.validate_choose_character(character_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_choose_character(character_id)
