class_name IntentTransitionSelection
extends RefCounted

const SELECTED := "SELECTED"
const INVALID_GRAPH := "INVALID_GRAPH"
const MISSING_CURRENT_INTENT := "MISSING_CURRENT_INTENT"
const TRANSITIONS_EXHAUSTED := "TRANSITIONS_EXHAUSTED"
const RNG_UNAVAILABLE := "RNG_UNAVAILABLE"

var status: String
var transition_id: String
var target_intent_id: String
var message: String
var details: Dictionary

func _init(
	result_status: String,
	result_transition_id: String = "",
	result_target_intent_id: String = "",
	result_message: String = "",
	result_details: Dictionary = {},
) -> void:
	status = result_status
	transition_id = result_transition_id
	target_intent_id = result_target_intent_id
	message = result_message
	details = result_details.duplicate(true)

func is_selected() -> bool:
	return status == SELECTED

func to_dictionary() -> Dictionary:
	return {
		"status": status,
		"transition_id": transition_id,
		"target_intent_id": target_intent_id,
		"message": message,
		"details": details.duplicate(true),
	}
