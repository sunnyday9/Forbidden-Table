class_name CombatResolver
extends RefCounted

const CombatResolutionQueueScript = preload("res://src/domain/combat/combat_resolution_queue.gd")
const CombatResolutionResultScript = preload("res://src/domain/combat/combat_resolution_result.gd")
const CombatResolutionStepScript = preload("res://src/domain/combat/combat_resolution_step.gd")
const CombatStateScript = preload("res://src/domain/combat/combat_state.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")

func begin_queue(state, operation_limit: int = CombatResolutionQueueScript.DEFAULT_OPERATION_LIMIT, context = null):
	return CombatResolutionQueueScript.new(state, operation_limit, context)

func resolve_atomic_queue(state, steps: Array, context = null):
	var queue = begin_queue(state, CombatResolutionQueueScript.DEFAULT_OPERATION_LIMIT, context)
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
	var intent = state.current_intent
	var queue = begin_queue(state)
	queue.enqueue_effect(CombatResolutionStepScript.new(intent.intent_id, 0, intent.pressure_amount))
	queue.add_event(DomainEventScript.new(DomainEventScript.ENEMY_INTENT_RESOLVED, {
		"intent_id": intent.intent_id,
		"display_name": intent.display_name,
		"action_type": intent.action_type,
		"pressure_amount": intent.pressure_amount,
		"next_intent_id": state.peek_next_intent().intent_id,
	}))
	var result = queue.drain()
	if result.is_resolved() and state.is_active():
		state.advance_intent()
		result.update_state(state)
	return result

func _terminal_result(state):
	return CombatResolutionResultScript.new(
		CombatResolutionResultScript.BATTLE_ALREADY_TERMINAL,
		state.queue_index if state != null else 0,
		state.terminal_outcome if state != null else CombatStateScript.ONGOING,
		[],
		state.to_dictionary() if state != null else {},
	)
