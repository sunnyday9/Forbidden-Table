class_name CombatResolutionQueue
extends RefCounted

const CombatResolutionResultScript = preload("res://src/domain/combat/combat_resolution_result.gd")
const CombatResolutionStepScript = preload("res://src/domain/combat/combat_resolution_step.gd")

var _state
var _events: Array = []
var _drained := false
var _accepted := false
var _result

func _init(state) -> void:
	_state = state
	_accepted = _state != null and _state._start_queue()

func add_step(step) -> bool:
	if _drained or not _accepted or not step is CombatResolutionStepScript:
		return false
	var sequence_index: int = _state._next_effect_sequence_index()
	_events.append_array(_state._apply_step(step, sequence_index))
	return true

func add_event(event) -> bool:
	if _drained or not _accepted or event == null:
		return false
	_events.append(event)
	return true

func drain():
	if _result != null:
		return _result
	_drained = true
	if not _accepted:
		_result = CombatResolutionResultScript.new(
			CombatResolutionResultScript.QUEUE_REJECTED,
			_state.queue_index if _state != null else 0,
			_state.terminal_outcome if _state != null else "",
			[],
			_state.to_dictionary() if _state != null else {},
		)
		return _result

	_events.append_array(_state._finish_queue())
	_result = CombatResolutionResultScript.new(
		CombatResolutionResultScript.RESOLVED,
		_state.queue_index,
		_state.terminal_outcome,
		_events,
		_state.to_dictionary(),
	)
	return _result
