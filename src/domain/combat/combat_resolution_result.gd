class_name CombatResolutionResult
extends RefCounted

const RESOLVED := "RESOLVED"
const BATTLE_ALREADY_TERMINAL := "BATTLE_ALREADY_TERMINAL"
const QUEUE_REJECTED := "QUEUE_REJECTED"
const LOOP_GUARD_TRIGGERED := "LOOP_GUARD_TRIGGERED"
const INVALID_INTENT_GRAPH := "INVALID_INTENT_GRAPH"
const INTENT_TRANSITIONS_EXHAUSTED := "INTENT_TRANSITIONS_EXHAUSTED"
const INTENT_RNG_UNAVAILABLE := "INTENT_RNG_UNAVAILABLE"
const INTENT_ACTION_FAILED := "INTENT_ACTION_FAILED"

var status: String
var queue_index: int
var terminal_outcome: String
var _events: Array
var state_snapshot: Dictionary
var diagnostics: Array
var processed_item_count: int
var remaining_item_count: int
var _effect_results: Array

var events: Array:
	get:
		return _events.duplicate()

func _init(
	result_status: String,
	result_queue_index: int,
	result_terminal_outcome: String,
	result_events: Array,
	result_state_snapshot: Dictionary,
	result_diagnostics: Array = [],
	result_processed_item_count: int = 0,
	result_remaining_item_count: int = 0,
	result_effect_results: Array = [],
) -> void:
	status = result_status
	queue_index = result_queue_index
	terminal_outcome = result_terminal_outcome
	_events = result_events.duplicate()
	state_snapshot = result_state_snapshot.duplicate(true)
	diagnostics = result_diagnostics.duplicate(true)
	processed_item_count = result_processed_item_count
	remaining_item_count = result_remaining_item_count
	_effect_results = result_effect_results.duplicate()

var effect_results: Array:
	get:
		return _effect_results.duplicate()

func is_resolved() -> bool:
	return status == RESOLVED

func update_state(state) -> void:
	state_snapshot = state.to_dictionary()
	terminal_outcome = state.terminal_outcome
	queue_index = state.queue_index

func to_dictionary() -> Dictionary:
	var event_data: Array = []
	for event in _events:
		event_data.append({
			"event_type": event.event_type,
			"data": event.data.duplicate(true),
		})
	return {
		"status": status,
		"queue_index": queue_index,
		"terminal_outcome": terminal_outcome,
		"events": event_data,
		"state": state_snapshot.duplicate(true),
		"diagnostics": diagnostics.duplicate(true),
		"processed_item_count": processed_item_count,
		"remaining_item_count": remaining_item_count,
		"effect_results": _effect_result_data(),
	}

func _effect_result_data() -> Array:
	var result: Array = []
	for effect_result in _effect_results:
		result.append(effect_result.to_dictionary())
	return result
