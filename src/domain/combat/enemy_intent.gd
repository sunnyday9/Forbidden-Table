class_name EnemyIntent
extends RefCounted

const PRESSURE := "PRESSURE"

var intent_id: String
var display_name: String
var action_type: String
var pressure_amount: int

func _init(
	result_intent_id: String,
	result_display_name: String,
	result_pressure_amount: int,
	result_action_type: String = PRESSURE,
) -> void:
	intent_id = result_intent_id
	display_name = result_display_name
	pressure_amount = maxi(0, result_pressure_amount)
	action_type = result_action_type

func to_dictionary() -> Dictionary:
	return {
		"intent_id": intent_id,
		"display_name": display_name,
		"action_type": action_type,
		"pressure_amount": pressure_amount,
	}
