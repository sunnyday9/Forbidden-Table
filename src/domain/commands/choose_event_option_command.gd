class_name ChooseEventOptionCommand
extends "res://src/domain/commands/run_command.gd"

var option_id: String
var event_id: String
var entry_id: String

func _init(
	identifier: String,
	selected_option_id: String,
	selected_event_id: String = "",
	selected_entry_id: String = "",
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	option_id = selected_option_id
	event_id = selected_event_id
	entry_id = selected_entry_id

func command_type() -> String:
	return "ChooseEventOption"

func _payload_dictionary() -> Dictionary:
	return {
		"event_id": event_id,
		"entry_id": entry_id,
		"option_id": option_id,
	}

func validate(context) -> RefCounted:
	return context.validate_choose_event_option(event_id, entry_id, option_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_choose_event_option(event_id, entry_id, option_id)
