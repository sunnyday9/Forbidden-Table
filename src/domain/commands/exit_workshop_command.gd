class_name ExitWorkshopCommand
extends "res://src/domain/commands/run_command.gd"

func _init(
	identifier: String,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)

func command_type() -> String:
	return "ExitWorkshop"

func validate(context) -> RefCounted:
	return context.validate_exit_workshop()

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_exit_workshop()
