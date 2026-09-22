class_name EndTurnCommand
extends "res://src/domain/commands/battle_command.gd"

func _init(
	identifier: String = "battle.end_turn",
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)

func command_type() -> String:
	return "EndTurn"

func validate(context) -> RefCounted:
	return context.validate_end_turn()

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_end_turn()
