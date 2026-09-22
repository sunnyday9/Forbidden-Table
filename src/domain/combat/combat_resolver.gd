class_name CombatResolver
extends RefCounted

const CombatResolutionQueueScript = preload("res://src/domain/combat/combat_resolution_queue.gd")
const CombatResolutionResultScript = preload("res://src/domain/combat/combat_resolution_result.gd")
const CombatResolutionStepScript = preload("res://src/domain/combat/combat_resolution_step.gd")
const CombatResolutionEffectScript = preload("res://src/domain/combat/combat_resolution_effect.gd")
const CombatStateScript = preload("res://src/domain/combat/combat_state.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const LifecycleResolverScript = preload("res://src/domain/effects/lifecycle_resolver.gd")
const IntentTransitionSelectionScript = preload("res://src/domain/combat/intent_transition_selection.gd")

func begin_queue(state, operation_limit: int = CombatResolutionQueueScript.DEFAULT_OPERATION_LIMIT, context = null, lifecycle_boundary: String = LifecycleResolverScript.ACTION):
	return CombatResolutionQueueScript.new(state, operation_limit, context, lifecycle_boundary)

func resolve_atomic_queue(state, steps: Array, context = null, lifecycle_boundary: String = LifecycleResolverScript.ACTION):
	var queue = begin_queue(state, CombatResolutionQueueScript.DEFAULT_OPERATION_LIMIT, context, lifecycle_boundary)
	for step in steps:
		queue.enqueue_effect(step)
	return queue.drain()

func resolve_player_action(state, damage_amount: int, pressure_delta: int = 0):
	if not state is CombatStateScript or not state.is_active():
		return _terminal_result(state)
	return resolve_atomic_queue(state, [
		CombatResolutionStepScript.new("player.action", damage_amount, pressure_delta),
	])

func resolve_combat_conversion(state, combat_output):
	if not state is CombatStateScript or not state.is_active() or combat_output == null:
		return _terminal_result(state)
	return resolve_atomic_queue(state, [
		CombatResolutionStepScript.new(
			"combat_conversion.%s" % combat_output.profile_id,
			combat_output.damage,
			-combat_output.stability,
		),
	])

func resolve_enemy_intent(state):
	if not state is CombatStateScript or not state.is_active():
		return _terminal_result(state)
	if state.intent_graph == null or not state.intent_graph.validation().is_valid():
		return _intent_failure_result(state, CombatResolutionResultScript.INVALID_INTENT_GRAPH, {
			"code": "INVALID_INTENT_GRAPH",
			"issues": _graph_issues(state),
		})
	if state.current_intent == null:
		return _intent_failure_result(state, CombatResolutionResultScript.INVALID_INTENT_GRAPH, {
			"code": "MISSING_CURRENT_INTENT",
		})
	var intent = state.current_intent
	var queue = begin_queue(state)
	queue.enqueue_effect(CombatResolutionStepScript.new(intent.intent_id, 0, intent.pressure_amount))
	queue.enqueue_effect(CombatResolutionEffectScript.new(
		"intent.transition.%s" % intent.intent_id,
		Callable(self, "_resolve_intent_transition"),
	))
	var result = queue.drain()
	return result

func _resolve_intent_transition(queue, state, sequence_index: int) -> Array:
	var current_intent = state.current_intent
	if current_intent == null:
		queue.fail(
			CombatResolutionResultScript.INVALID_INTENT_GRAPH,
			{"code": "MISSING_CURRENT_INTENT", "sequence_index": sequence_index},
			DomainEventScript.new(DomainEventScript.ENEMY_INTENT_FAILED, {
				"code": "MISSING_CURRENT_INTENT",
				"sequence_index": sequence_index,
			}),
		)
		return []
	if not state.is_active():
		queue.add_event(DomainEventScript.new(DomainEventScript.ENEMY_INTENT_RESOLVED, {
			"intent_id": current_intent.intent_id,
			"display_name": current_intent.display_name,
			"action_type": current_intent.action_type,
			"pressure_amount": current_intent.pressure_amount,
			"next_intent_id": current_intent.intent_id,
			"transition_id": "",
			"sequence_index": sequence_index,
		}))
		return []

	var selection = state.select_next_intent()
	if not selection.is_selected():
		var failure_status := _selection_failure_status(selection.status)
		var diagnostic := {
			"code": failure_status,
			"intent_id": current_intent.intent_id,
			"message": selection.message,
			"details": selection.details.duplicate(true),
			"sequence_index": sequence_index,
		}
		queue.fail(failure_status, diagnostic, DomainEventScript.new(DomainEventScript.ENEMY_INTENT_FAILED, diagnostic))
		return []

	var next_intent = state.intent_graph.intent(selection.target_intent_id)
	if next_intent == null:
		var missing_diagnostic := {
			"code": "MISSING_TARGET",
			"intent_id": current_intent.intent_id,
			"transition_id": selection.transition_id,
			"target_intent_id": selection.target_intent_id,
			"sequence_index": sequence_index,
		}
		queue.fail(CombatResolutionResultScript.INVALID_INTENT_GRAPH, missing_diagnostic, DomainEventScript.new(DomainEventScript.ENEMY_INTENT_FAILED, missing_diagnostic))
		return []

	queue.add_event(DomainEventScript.new(DomainEventScript.ENEMY_INTENT_RESOLVED, {
		"intent_id": current_intent.intent_id,
		"display_name": current_intent.display_name,
		"action_type": current_intent.action_type,
		"pressure_amount": current_intent.pressure_amount,
		"next_intent_id": next_intent.intent_id,
		"transition_id": selection.transition_id,
		"sequence_index": sequence_index,
	}))
	state.advance_intent(next_intent.intent_id)
	return []

func _selection_failure_status(selection_status: String) -> String:
	if selection_status == IntentTransitionSelectionScript.TRANSITIONS_EXHAUSTED:
		return CombatResolutionResultScript.INTENT_TRANSITIONS_EXHAUSTED
	if selection_status == IntentTransitionSelectionScript.RNG_UNAVAILABLE:
		return CombatResolutionResultScript.INTENT_RNG_UNAVAILABLE
	return CombatResolutionResultScript.INVALID_INTENT_GRAPH

func _intent_failure_result(state, status: String, diagnostic: Dictionary):
	return CombatResolutionResultScript.new(
		status,
		state.queue_index,
		state.terminal_outcome,
		[],
		state.to_dictionary(),
		[diagnostic],
	)

func _graph_issues(state) -> Array:
	return state.intent_graph.validation_issues()

func _terminal_result(state):
	return CombatResolutionResultScript.new(
		CombatResolutionResultScript.BATTLE_ALREADY_TERMINAL,
		state.queue_index if state != null else 0,
		state.terminal_outcome if state != null else CombatStateScript.ONGOING,
		[],
		state.to_dictionary() if state != null else {},
	)
