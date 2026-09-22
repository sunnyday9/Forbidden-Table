class_name RewardDraft
extends RefCounted

var draft_id: String
var draft_kind: String
var encounter_id: String
var encounter_kind: String
var options: Array
var reward_rng_state: Dictionary

func _init(
	initial_draft_id: String,
	initial_draft_kind: String,
	initial_encounter_id: String,
	initial_encounter_kind: String,
	initial_options: Array = [],
	initial_reward_rng_state: Dictionary = {},
) -> void:
	draft_id = initial_draft_id
	draft_kind = initial_draft_kind
	encounter_id = initial_encounter_id
	encounter_kind = initial_encounter_kind
	options = initial_options.duplicate()
	reward_rng_state = initial_reward_rng_state.duplicate(true)

func option_by_id(selected_option_id: String):
	for option in options:
		if option != null and option.option_id == selected_option_id:
			return option
	return null

func to_dictionary() -> Dictionary:
	var serialized_options: Array = []
	for option in options:
		if option != null and option.has_method("to_dictionary"):
			serialized_options.append(option.to_dictionary())
	return {
		"draft_id": draft_id,
		"draft_kind": draft_kind,
		"encounter_id": encounter_id,
		"encounter_kind": encounter_kind,
		"options": serialized_options,
		"reward_rng_state": reward_rng_state.duplicate(true),
	}
