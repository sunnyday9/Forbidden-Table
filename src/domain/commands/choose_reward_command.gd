class_name ChooseRewardCommand
extends "res://src/domain/commands/run_command.gd"

var option_id: String
var draft_id: String

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
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	option_id = selected_option_id
	draft_id = selected_draft_id

func command_type() -> String:
	return "ChooseReward"

func _payload_dictionary() -> Dictionary:
	return {
		"draft_id": draft_id,
		"option_id": option_id,
	}

func validate(context) -> RefCounted:
	return context.validate_choose_reward(draft_id, option_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_choose_reward(draft_id, option_id)
