class_name EnterEventCommand
extends "res://src/domain/commands/run_command.gd"

var event_id: String

func _init(
	identifier: String,
	selected_event_id: String = "",
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	event_id = selected_event_id

func command_type() -> String:
	return "EnterEvent"

func _payload_dictionary() -> Dictionary:
	return {"event_id": event_id}

func validate(context) -> RefCounted:
	return context.validate_enter_event(event_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_enter_event(event_id)
