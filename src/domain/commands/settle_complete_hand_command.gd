class_name SettleCompleteHandCommand
extends "res://src/domain/commands/battle_command.gd"

var interpretation_id: String

func _init(
	identifier: String,
	selected_interpretation_id: String,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	interpretation_id = selected_interpretation_id

func command_type() -> String:
	return "SettleCompleteHand"

func _payload_dictionary() -> Dictionary:
	return {"interpretation_id": interpretation_id}

func validate(context) -> RefCounted:
	return context.validate_complete_hand(interpretation_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_complete_hand(interpretation_id)
