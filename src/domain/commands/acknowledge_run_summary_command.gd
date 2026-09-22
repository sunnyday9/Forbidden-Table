class_name AcknowledgeRunSummaryCommand
extends "res://src/domain/commands/run_command.gd"

func _init(
	identifier: String = "run.acknowledge_summary",
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)

func command_type() -> String:
	return "AcknowledgeRunSummary"

func validate(context) -> RefCounted:
	return context.validate_acknowledge_run_summary()

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_acknowledge_run_summary()
