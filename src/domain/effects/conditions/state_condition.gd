class_name StateEffectCondition
extends "res://src/domain/effects/effect_condition.gd"

const EQUAL := "EQUAL"
const GREATER_THAN := "GREATER_THAN"
const GREATER_THAN_OR_EQUAL := "GREATER_THAN_OR_EQUAL"
const LESS_THAN := "LESS_THAN"
const LESS_THAN_OR_EQUAL := "LESS_THAN_OR_EQUAL"

var state_key: String
var comparator: String
var expected: int

func _init(key: String, comparison: String, value: int) -> void:
	state_key = key
	comparator = comparison
	expected = value

func evaluate(context, _targets: Dictionary) -> bool:
	if context == null or context.state == null or context.state.get(state_key) == null:
		return false
	var actual = context.state.get(state_key)
	if comparator == EQUAL:
		return actual == expected
	if comparator == GREATER_THAN:
		return actual > expected
	if comparator == GREATER_THAN_OR_EQUAL:
		return actual >= expected
	if comparator == LESS_THAN:
		return actual < expected
	if comparator == LESS_THAN_OR_EQUAL:
		return actual <= expected
	return false

func failure_reason() -> String:
	return "STATE_CONDITION_FALSE"

func to_dictionary() -> Dictionary:
	return {"condition": "STATE", "state_key": state_key, "comparator": comparator, "expected": expected}
