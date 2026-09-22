class_name EnemyIntent
extends RefCounted

const PRESSURE := "PRESSURE"

var intent_id: String
var display_name: String
var action_type: String
var pressure_amount: int
var transitions: Array

func _init(
	result_intent_id: String,
	result_display_name: String,
	result_pressure_amount: int,
	result_action_type: String = PRESSURE,
	result_transitions: Array = [],
) -> void:
	intent_id = result_intent_id
	display_name = result_display_name
	pressure_amount = maxi(0, result_pressure_amount)
	action_type = result_action_type
	transitions = result_transitions.duplicate()

func to_dictionary() -> Dictionary:
	return {
		"intent_id": intent_id,
		"display_name": display_name,
		"action_type": action_type,
		"pressure_amount": pressure_amount,
		"transitions": _transition_data(),
	}

func _transition_data() -> Array:
	var result: Array = []
	for transition in transitions:
		result.append(transition.to_dictionary() if transition != null and transition.has_method("to_dictionary") else {})
	return result
