class_name RunCommand
extends "res://src/domain/commands/domain_command.gd"

func _init(
	identifier: String = "run.command",
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)

func command_type() -> String:
	return "RunCommand"
