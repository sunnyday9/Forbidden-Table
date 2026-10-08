class_name ChooseRewardCommand
extends "res://src/domain/commands/run_command.gd"

var option_id: String
var draft_id: String
var target_tile_id: String

var reward_id: String:
	get:
		return option_id

func _init(
	identifier: String,
	selected_option_id: String,
	selected_draft_id: String = "",
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
	selected_target_tile_id: String = "",
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	option_id = selected_option_id
	draft_id = selected_draft_id
	target_tile_id = selected_target_tile_id

func command_type() -> String:
	return "ChooseReward"

func _payload_dictionary() -> Dictionary:
	var payload := {
		"draft_id": draft_id,
		"option_id": option_id,
	}
	if not target_tile_id.is_empty():
		payload["target_tile_id"] = target_tile_id
	return payload

func validate(context) -> RefCounted:
	return context.validate_choose_reward(draft_id, option_id, target_tile_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_choose_reward(draft_id, option_id, target_tile_id)
