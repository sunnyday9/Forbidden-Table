class_name CombatResolutionQueue
extends RefCounted

const CombatResolutionResultScript = preload("res://src/domain/combat/combat_resolution_result.gd")
const CombatResolutionStepScript = preload("res://src/domain/combat/combat_resolution_step.gd")
const CombatResolutionEffectScript = preload("res://src/domain/combat/combat_resolution_effect.gd")
const CombatReactionWindowScript = preload("res://src/domain/combat/combat_reaction_window.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const EffectContextScript = preload("res://src/domain/effects/effect_context.gd")
const EffectResolutionResultScript = preload("res://src/domain/effects/effect_resolution_result.gd")
const LifecycleResolverScript = preload("res://src/domain/effects/lifecycle_resolver.gd")

const DEFAULT_OPERATION_LIMIT := 256

var _state
var _context
var _lifecycle_boundary: String
var _events: Array = []
var _pending_effects: Array = []
var _pending_triggers: Array = []
var _open_reaction_windows: Dictionary = {}
var _diagnostics: Array = []
var _effect_results: Array = []
var _drained := false
var _accepted := false
var _result
var _operation_limit: int
var _processed_item_count := 0
var _loop_guard_triggered := false
var _failure_status := ""

func _init(state, operation_limit: int = DEFAULT_OPERATION_LIMIT, context = null, lifecycle_boundary: String = LifecycleResolverScript.ACTION) -> void:
	_state = state
	_context = context if context != null else EffectContextScript.new(state)
	_lifecycle_boundary = lifecycle_boundary
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

func fail(status: String, diagnostic: Dictionary = {}, event = null) -> bool:
	if _drained or not _accepted or status.is_empty():
		return false
	_failure_status = status
	_pending_effects.clear()
	_pending_triggers.clear()
	if not diagnostic.is_empty():
		_diagnostics.append(diagnostic.duplicate(true))
	if event != null:
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
	var sequence_index: int = _state._next_effect_sequence_index()
	_events.append(DomainEventScript.new(DomainEventScript.REACTION_WINDOW_CLOSED, {
		"window_id": window_id,
		"reason": "resolved",
		"sequence_index": sequence_index,
	}))
	return true

func set_operation_limit(operation_limit: int) -> void:
	_operation_limit = maxi(1, operation_limit)

func set_lifecycle_boundary(boundary: String) -> void:
	_lifecycle_boundary = boundary

func lifecycle_boundary() -> String:
	return _lifecycle_boundary

func consume_effect(effect_id: String, uses: int = 0, charges: int = 0) -> bool:
	if _drained or not _accepted:
		return false
	var sequence_index: int = _state._next_effect_sequence_index()
	var lifecycle_events := LifecycleResolverScript.new().consume_effect(_state, effect_id, uses, charges, sequence_index)
	_events.append_array(lifecycle_events)
	return not lifecycle_events.is_empty() and lifecycle_events[0].event_type == DomainEventScript.EFFECT_CONSUMED

func pending_item_count() -> int:
	return _pending_effects.size() + _pending_triggers.size()

func is_failed() -> bool:
	return not _failure_status.is_empty()

func effect_context():
	return _context

func open_reaction_window_ids() -> Array:
	var ids: Array = _open_reaction_windows.keys()
	ids.sort()
	return ids

func is_loop_guarded() -> bool:
	return _loop_guard_triggered

func drain(boundary: String = ""):
	if _result != null:
		return _result
	if not boundary.is_empty():
		_lifecycle_boundary = boundary
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
	if not _lifecycle_boundary.is_empty():
		var lifecycle_resolver := LifecycleResolverScript.new()
		var lifecycle_sequence: int = _state._next_effect_sequence_index() if lifecycle_resolver.has_boundary_effect(_state, _lifecycle_boundary) else -1
		_events.append_array(lifecycle_resolver.advance(_state, _lifecycle_boundary, lifecycle_sequence))
	_events.append_array(_state._finish_queue())
	_result = _make_result(_failure_status if not _failure_status.is_empty() else CombatResolutionResultScript.RESOLVED)
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
		var resolution = item.resolve(self, _state, sequence_index)
		if resolution is EffectResolutionResultScript:
			_effect_results.append(resolution)
			item_events = resolution.events
		elif resolution is Array:
			item_events = resolution
	else:
		item_events = _state._apply_step(item, sequence_index)
	if item_events is Array:
		_events.append_array(item_events)
	_processed_item_count += 1
	return true

func _drain_pending_items() -> void:
	while pending_item_count() > 0 and not is_failed():
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
		_effect_results,
	)
