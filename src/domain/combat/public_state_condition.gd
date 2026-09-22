class_name PublicStateCondition
extends "res://src/domain/combat/intent_condition.gd"

const EQUAL := "EQUAL"
const GREATER_THAN := "GREATER_THAN"
const GREATER_THAN_OR_EQUAL := "GREATER_THAN_OR_EQUAL"
const LESS_THAN := "LESS_THAN"
const LESS_THAN_OR_EQUAL := "LESS_THAN_OR_EQUAL"

const PUBLIC_STATE_KEYS := {
	"enemy_hp": true,
	"enemy_max_hp": true,
	"pressure": true,
	"pressure_limit": true,
	"fatigue": true,
	"starvation_count": true,
	"starvation_active": true,
	"tp": true,
	"stability": true,
	"draw_capacity": true,
	"settlement_capacity": true,
	"reserve_capacity": true,
	"terminal_outcome": true,
	"current_intent_id": true,
	"boss_phase_index": true,
	"boss_phase_id": true,
	"boss_phase_count": true,
}

var state_key: String
var comparator: String
var expected

func _init(key: String, comparison: String, value) -> void:
	state_key = key
	comparator = comparison
	expected = value

func evaluate(public_battle_state: Dictionary) -> bool:
	if not is_valid() or not public_battle_state.has(state_key):
		return false
	var actual = public_battle_state[state_key]
	if comparator == EQUAL:
		return actual == expected
	if not (actual is int or actual is float) or not (expected is int or expected is float):
		return false
	if comparator == GREATER_THAN:
		return actual > expected
	if comparator == GREATER_THAN_OR_EQUAL:
		return actual >= expected
	if comparator == LESS_THAN:
		return actual < expected
	if comparator == LESS_THAN_OR_EQUAL:
		return actual <= expected
	return false

func is_valid() -> bool:
	return PUBLIC_STATE_KEYS.has(state_key) and [EQUAL, GREATER_THAN, GREATER_THAN_OR_EQUAL, LESS_THAN, LESS_THAN_OR_EQUAL].has(comparator)

func validation_code() -> String:
	if not PUBLIC_STATE_KEYS.has(state_key):
		return "non_public_state_key"
	if not [EQUAL, GREATER_THAN, GREATER_THAN_OR_EQUAL, LESS_THAN, LESS_THAN_OR_EQUAL].has(comparator):
		return "invalid_condition_comparator"
	return ""

func to_dictionary() -> Dictionary:
	return {
		"condition": "PUBLIC_STATE",
		"state_key": state_key,
		"comparator": comparator,
		"expected": expected,
	}
