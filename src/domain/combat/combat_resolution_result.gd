class_name CombatResolutionResult
extends RefCounted

const RESOLVED := "RESOLVED"
const BATTLE_ALREADY_TERMINAL := "BATTLE_ALREADY_TERMINAL"
const QUEUE_REJECTED := "QUEUE_REJECTED"

var status: String
var queue_index: int
var terminal_outcome: String
var _events: Array
var state_snapshot: Dictionary

var events: Array:
	get:
		return _events.duplicate()

func _init(
	result_status: String,
	result_queue_index: int,
	result_terminal_outcome: String,
	result_events: Array,
	result_state_snapshot: Dictionary,
) -> void:
	status = result_status
	queue_index = result_queue_index
	terminal_outcome = result_terminal_outcome
	_events = result_events.duplicate()
	state_snapshot = result_state_snapshot.duplicate(true)

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
	}
