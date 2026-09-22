class_name SelectMapNodeCommand
extends "res://src/domain/commands/run_command.gd"

var node_id: String

func _init(
	identifier: String,
	selected_node_id: String,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	node_id = selected_node_id

func command_type() -> String:
	return "SelectMapNode"

func _payload_dictionary() -> Dictionary:
	return {"node_id": node_id}

func validate(context) -> RefCounted:
	return context.validate_select_map_node(node_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_select_map_node(node_id)
