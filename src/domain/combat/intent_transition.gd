class_name IntentTransition
extends RefCounted

const IntentTransitionScript = preload("res://src/domain/combat/intent_transition.gd")

const FIXED := "FIXED"
const CONDITIONAL := "CONDITIONAL"
const WEIGHTED := "WEIGHTED"

var transition_id: String
var target_intent_id: String
var transition_type: String
var condition
var weight: int

func _init(
	identifier: String,
	target_identifier: String,
	type: String = FIXED,
	transition_condition = null,
	transition_weight: int = 0,
) -> void:
	transition_id = identifier
	target_intent_id = target_identifier
	transition_type = type
	condition = transition_condition
	weight = transition_weight

static func fixed(identifier: String, target_identifier: String):
	return IntentTransitionScript.new(identifier, target_identifier, FIXED)

static func conditional(identifier: String, target_identifier: String, transition_condition):
	return IntentTransitionScript.new(identifier, target_identifier, CONDITIONAL, transition_condition)

static func weighted(identifier: String, target_identifier: String, transition_weight: int):
	return IntentTransitionScript.new(identifier, target_identifier, WEIGHTED, null, transition_weight)

func to_dictionary() -> Dictionary:
	return {
		"transition_id": transition_id,
		"target_intent_id": target_intent_id,
		"transition_type": transition_type,
		"condition": condition.to_dictionary() if condition != null and condition.has_method("to_dictionary") else {},
		"weight": weight,
	}
