class_name ResolutionQueueTest
extends RefCounted

const CombatReactionWindow = preload("res://src/domain/combat/combat_reaction_window.gd")
const CombatResolutionEffect = preload("res://src/domain/combat/combat_resolution_effect.gd")
const CombatResolutionStep = preload("res://src/domain/combat/combat_resolution_step.gd")
const CombatResolutionTrigger = preload("res://src/domain/combat/combat_resolution_trigger.gd")
const CombatResolver = preload("res://src/domain/combat/combat_resolver.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const CombatResolutionResult = preload("res://src/domain/combat/combat_resolution_result.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")

var _order: Array = []
var _loop_effect
var _reaction_window_opened := false
var _illegal_window_rejected := false

func run() -> Array[String]:
	var failures: Array[String] = []
	test_effects_and_triggers_use_causal_fifo_order(failures)
	test_state_based_checks_wait_for_deferred_chain_boundary(failures)
	test_same_atomic_effect_terminal_tie_favors_defeat(failures)
	test_predeclared_reaction_window_can_be_represented_after_lethal_threshold(failures)
	test_loop_guard_reports_unresolved_work_without_a_boundary(failures)
	return failures

func test_effects_and_triggers_use_causal_fifo_order(failures: Array[String]) -> void:
	_order = []
	var state = CombatState.new(10, 10)
	var first_effect = CombatResolutionEffect.new("causal.effect", Callable(self, "_record_effect"))
	var second_effect = CombatResolutionEffect.new("causal.sibling", Callable(self, "_record_sibling"))
	var queue = CombatResolver.new().begin_queue(state)
	queue.enqueue_effect(first_effect)
	queue.enqueue_effect(second_effect)
	var result = queue.drain()

	assert_true(result.status == CombatResolutionResult.RESOLVED, "the deferred resolution queue drains", failures)
	assert_true(_order == ["effect:1", "trigger:2", "sibling:3"], "effects and triggered work resolve in explicit causal order", failures)
	assert_true(state.state_based_check_count == 1, "one State-Based Check runs at the drain boundary", failures)

func _record_effect(queue, _state, sequence_index: int) -> Array:
	_order.append("effect:%d" % sequence_index)
	queue.enqueue_trigger(CombatResolutionTrigger.new("causal.trigger", Callable(self, "_record_trigger")))
	return []

func _record_trigger(_queue, _state, sequence_index: int) -> Array:
	_order.append("trigger:%d" % sequence_index)
	return []

func _record_sibling(_queue, _state, sequence_index: int) -> Array:
	_order.append("sibling:%d" % sequence_index)
	return []

func test_state_based_checks_wait_for_deferred_chain_boundary(failures: Array[String]) -> void:
	var state = CombatState.new(2, 5, 3)
	var queue = CombatResolver.new().begin_queue(state)
	queue.enqueue_effect(CombatResolutionStep.new("pressure.effect", 0, 2))
	queue.enqueue_effect(CombatResolutionStep.new("damage.effect", 2, 0))

	assert_true(state.pressure == 3 and state.enemy_hp == 2, "deferred effects do not mutate state before draining", failures)
	assert_true(state.queue_index == 0 and state.state_based_check_count == 0, "no boundary check runs before the chain drains", failures)
	var result = queue.drain()
	assert_true(result.terminal_outcome == CombatState.DEFEAT, "the earlier lethal Pressure outcome wins", failures)
	assert_true(state.enemy_hp == 0 and state.pressure == 5, "the full atomic chain resolves before the boundary", failures)
	assert_true(state.state_based_check_count == 1 and state.queue_index == 1, "State-Based Checks run exactly at the queue boundary", failures)

func test_same_atomic_effect_terminal_tie_favors_defeat(failures: Array[String]) -> void:
	var state = CombatState.new(1, 5, 4)
	var queue = CombatResolver.new().begin_queue(state)
	queue.enqueue_effect(CombatResolutionStep.new("same.atomic.effect", 1, 1))
	var result = queue.drain()

	assert_true(state.pending_death_sequence_index == 1, "the atomic effect records the Victory causal sequence", failures)
	assert_true(state.pending_defeat_sequence_index == 1, "the atomic effect records the Defeat causal sequence", failures)
	assert_true(result.terminal_outcome == CombatState.DEFEAT, "an exact same-causal-sequence terminal tie favors Defeat", failures)
	assert_true(state.terminal_sequence_index == 1, "the tie preserves the shared terminal causal sequence", failures)

func test_predeclared_reaction_window_can_be_represented_after_lethal_threshold(failures: Array[String]) -> void:
	_reaction_window_opened = false
	_illegal_window_rejected = false
	var state = CombatState.new(5, 5)
	var queue = CombatResolver.new().begin_queue(state)
	queue.add_step(CombatResolutionStep.new("reaction.lethal", 0, 5))
	_reaction_window_opened = queue.open_reaction_window(CombatReactionWindow.new("predeclared.guard", "guard", true, true))
	_illegal_window_rejected = not queue.open_reaction_window(CombatReactionWindow.new("new.choice", "choice", false, false))
	var result = queue.drain()

	assert_true(_reaction_window_opened, "a predeclared legal Reaction Window can open after a lethal threshold", failures)
	assert_true(_illegal_window_rejected, "a new non-legal choice is rejected after a lethal threshold", failures)
	assert_true(_has_event(result.events, DomainEvent.REACTION_WINDOW_OPENED), "Reaction Window opening is auditable", failures)
	assert_true(_has_event(result.events, DomainEvent.REACTION_WINDOW_CLOSED), "the queue closes Reaction Windows at its boundary", failures)
	assert_true(result.terminal_outcome == CombatState.DEFEAT, "the legal window does not grant an unbounded post-lethal choice", failures)

func test_loop_guard_reports_unresolved_work_without_a_boundary(failures: Array[String]) -> void:
	_loop_effect = CombatResolutionEffect.new("loop.effect", Callable(self, "_requeue_loop"))
	var state = CombatState.new(5, 5)
	var queue = CombatResolver.new().begin_queue(state, 3)
	queue.enqueue_effect(_loop_effect)
	var result = queue.drain()

	assert_true(result.status == CombatResolutionResult.LOOP_GUARD_TRIGGERED, "an infinite queue returns a diagnostic status", failures)
	assert_true(result.diagnostics.size() == 1, "the loop guard exposes one structured diagnostic", failures)
	assert_true(result.remaining_item_count == 1, "the guard reports work it did not silently discard", failures)
	assert_true(not state.is_queue_active() and state.state_based_check_count == 0, "a guarded queue does not pretend to reach a State-Based Check boundary", failures)
	assert_true(_has_event(result.events, DomainEvent.INFINITE_LOOP_GUARD), "the loop guard emits an auditable domain event", failures)

func _requeue_loop(queue, _state, _sequence_index: int) -> Array:
	queue.enqueue_effect(_loop_effect)
	return []

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
