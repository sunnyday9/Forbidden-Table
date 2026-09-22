class_name RefreshShopCommand
extends "res://src/domain/commands/run_command.gd"

var entry_id: String

func _init(
	identifier: String,
	selected_entry_id: String = "",
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	entry_id = selected_entry_id

func command_type() -> String:
	return "RefreshShop"

func _payload_dictionary() -> Dictionary:
	return {"entry_id": entry_id}

func validate(context) -> RefCounted:
	return context.validate_refresh_shop(entry_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_refresh_shop(entry_id)
