class_name ChooseCharacterCommand
extends "res://src/domain/commands/run_command.gd"

var character_id: String
var excluded_suit: String

func _init(
	identifier: String,
	selected_character_id: String,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
	selected_excluded_suit: String = "",
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	character_id = selected_character_id
	excluded_suit = selected_excluded_suit

func command_type() -> String:
	return "ChooseCharacter"

func _payload_dictionary() -> Dictionary:
	var result := {"character_id": character_id}
	if not excluded_suit.is_empty():
		result["excluded_suit"] = excluded_suit
	return result

func validate(context) -> RefCounted:
	return context.validate_choose_character(character_id, excluded_suit)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_choose_character(character_id, excluded_suit)
