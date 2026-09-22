class_name BattleCommand
extends "res://src/domain/commands/domain_command.gd"

func _init(
	identifier: String = "battle.command",
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)

func command_type() -> String:
	return "BattleCommand"
