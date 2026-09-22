class_name DrawCommand
extends "res://src/domain/commands/battle_command.gd"

func _init(
	identifier: String = "battle.draw",
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)

func command_type() -> String:
	return "Draw"

func validate(context) -> RefCounted:
	return context.validate_draw()

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_draw()
