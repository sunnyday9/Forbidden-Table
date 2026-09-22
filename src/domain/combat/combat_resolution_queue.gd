class_name CombatResolutionQueue
extends RefCounted

const CombatResolutionResultScript = preload("res://src/domain/combat/combat_resolution_result.gd")
const CombatResolutionStepScript = preload("res://src/domain/combat/combat_resolution_step.gd")
const CombatResolutionEffectScript = preload("res://src/domain/combat/combat_resolution_effect.gd")
const CombatReactionWindowScript = preload("res://src/domain/combat/combat_reaction_window.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")

const DEFAULT_OPERATION_LIMIT := 256

var _state
var _events: Array = []
var _pending_effects: Array = []
var _pending_triggers: Array = []
var _open_reaction_windows: Dictionary = {}
var _diagnostics: Array = []
var _drained := false
var _accepted := false
var _result
var _operation_limit: int
var _processed_item_count := 0
var _loop_guard_triggered := false

func _init(state, operation_limit: int = DEFAULT_OPERATION_LIMIT) -> void:
	_state = state
	_operation_limit = maxi(1, operation_limit)
	_accepted = _state != null and _state._start_queue()

# Existing callers use this as an atomic append. Keep it immediate so Stage 0
# callers can inspect pending terminal state before the queue boundary.
func add_step(step) -> bool:
	if not _can_accept_item(step):
		return false
	_apply_item(step)
	return true

func add_effect(effect) -> bool:
	return enqueue_effect(effect)

func add_trigger(trigger) -> bool:
	return enqueue_trigger(trigger)

func enqueue_effect(effect) -> bool:
	if not _can_accept_item(effect):
		return false
	_pending_effects.append(effect)
	return true

func enqueue_trigger(trigger) -> bool:
	if not _can_accept_item(trigger):
		return false
	_pending_triggers.append(trigger)
	return true

func add_event(event) -> bool:
	if _drained or not _accepted or event == null:
		return false
	_events.append(event)
	return true

func open_reaction_window(window) -> bool:
	if _drained or not _accepted or not window is CombatReactionWindowScript:
		return false
	if _state.has_pending_terminal() and not window.can_open_after_lethal():
		return false
	if _open_reaction_windows.has(window.window_id):
		return false
	var sequence_index: int = _state._next_effect_sequence_index()
	_open_reaction_windows[window.window_id] = window
	_events.append(DomainEventScript.new(DomainEventScript.REACTION_WINDOW_OPENED, {
		"window": window.to_dictionary(),
		"sequence_index": sequence_index,
	}))
	return true

func enqueue_reaction_effect(window_id: String, effect) -> bool:
	if not _open_reaction_windows.has(window_id) or not _can_accept_item(effect):
		return false
	var window = _open_reaction_windows[window_id]
	if _state.has_pending_terminal() and not window.can_open_after_lethal():
		return false
	return enqueue_trigger(effect)

func close_reaction_window(window_id: String) -> bool:
	if not _open_reaction_windows.has(window_id) or _drained:
		return false
	_open_reaction_windows.erase(window_id)
	_events.append(DomainEventScript.new(DomainEventScript.REACTION_WINDOW_CLOSED, {
		"window_id": window_id,
		"reason": "resolved",
	}))
	return true

func set_operation_limit(operation_limit: int) -> void:
	_operation_limit = maxi(1, operation_limit)

func pending_item_count() -> int:
	return _pending_effects.size() + _pending_triggers.size()

func open_reaction_window_ids() -> Array:
	var ids: Array = _open_reaction_windows.keys()
	ids.sort()
	return ids

func is_loop_guarded() -> bool:
	return _loop_guard_triggered

func drain():
	if _result != null:
		return _result
	if not _accepted:
		_drained = true
		_result = CombatResolutionResultScript.new(
			CombatResolutionResultScript.QUEUE_REJECTED,
			_state.queue_index if _state != null else 0,
			_state.terminal_outcome if _state != null else "",
			[],
			_state.to_dictionary() if _state != null else {},
		)
		return _result

	_drain_pending_items()
	if _loop_guard_triggered:
		_state._abort_queue_without_boundary()
		_result = _make_result(CombatResolutionResultScript.LOOP_GUARD_TRIGGERED)
		_drained = true
		return _result

	_close_remaining_reaction_windows()
	_events.append_array(_state._finish_queue())
	_result = _make_result(CombatResolutionResultScript.RESOLVED)
	_drained = true
	return _result

func _can_accept_item(item) -> bool:
	return (
		not _drained
		and _accepted
		and not _loop_guard_triggered
		and (item is CombatResolutionStepScript or item is CombatResolutionEffectScript)
	)

func _apply_item(item) -> bool:
	if _processed_item_count >= _operation_limit:
		_record_loop_guard()
		return false
	var sequence_index: int = _state._next_effect_sequence_index()
	var item_events: Array = []
	if item is CombatResolutionEffectScript:
		item_events = item.resolve(self, _state, sequence_index)
	else:
		item_events = _state._apply_step(item, sequence_index)
	if item_events is Array:
		_events.append_array(item_events)
	_processed_item_count += 1
	return true

func _drain_pending_items() -> void:
	while pending_item_count() > 0:
		if _processed_item_count >= _operation_limit:
			_record_loop_guard()
			return
		# A trigger raised by an effect resolves before the next sibling effect.
		# Both queues remain FIFO, and each dequeue gets one causal index.
		var item = _pending_triggers.pop_front() if not _pending_triggers.is_empty() else _pending_effects.pop_front()
		_apply_item(item)

func _record_loop_guard() -> void:
	_loop_guard_triggered = true
	var diagnostic := {
		"code": "INFINITE_RESOLUTION_QUEUE",
		"operation_limit": _operation_limit,
		"processed_item_count": _processed_item_count,
		"remaining_item_count": pending_item_count(),
		"open_reaction_windows": open_reaction_window_ids(),
	}
	_diagnostics.append(diagnostic)
	_events.append(DomainEventScript.new(DomainEventScript.INFINITE_LOOP_GUARD, diagnostic))

func _close_remaining_reaction_windows() -> void:
	var remaining_ids: Array = open_reaction_window_ids()
	for window_id in remaining_ids:
		_open_reaction_windows.erase(window_id)
		_events.append(DomainEventScript.new(DomainEventScript.REACTION_WINDOW_CLOSED, {
			"window_id": window_id,
			"reason": "queue_boundary",
		}))

func _make_result(result_status: String):
	return CombatResolutionResultScript.new(
		result_status,
		_state.queue_index,
		_state.terminal_outcome,
		_events,
		_state.to_dictionary(),
		_diagnostics,
		_processed_item_count,
		pending_item_count(),
	)
