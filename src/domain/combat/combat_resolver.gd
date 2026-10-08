class_name CombatResolver
extends RefCounted

const CombatResolutionQueueScript = preload("res://src/domain/combat/combat_resolution_queue.gd")
const CombatResolutionResultScript = preload("res://src/domain/combat/combat_resolution_result.gd")
const CombatResolutionStepScript = preload("res://src/domain/combat/combat_resolution_step.gd")
const CombatResolutionEffectScript = preload("res://src/domain/combat/combat_resolution_effect.gd")
const CombatStateScript = preload("res://src/domain/combat/combat_state.gd")
const ContaminationCatalogScript = preload("res://src/domain/tiles/contamination_catalog.gd")
const ContaminationServiceScript = preload("res://src/domain/tiles/contamination_service.gd")
const EnemyIntentScript = preload("res://src/domain/combat/enemy_intent.gd")
const IntegrityCauseScript = preload("res://src/domain/tiles/integrity_cause.gd")
const IntegrityLossScript = preload("res://src/domain/tiles/integrity_loss.gd")
const ReserveServiceScript = preload("res://src/domain/tiles/reserve_service.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
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

func resolve_enemy_intent(state, reaction_handler: Callable = Callable(), contamination_config: Dictionary = {}):
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
	if intent.action_type == EnemyIntentScript.PRESSURE:
		queue.enqueue_effect(CombatResolutionStepScript.new(intent.intent_id, 0, intent.pressure_amount))
	else:
		queue.enqueue_effect(CombatResolutionEffectScript.new(
			"intent.action.%s" % intent.intent_id,
			Callable(self, "_resolve_enemy_intent_action").bind(reaction_handler, contamination_config.duplicate(true)),
		))
	queue.enqueue_effect(CombatResolutionEffectScript.new(
		"intent.transition.%s" % intent.intent_id,
		Callable(self, "_resolve_intent_transition"),
	))
	var result = queue.drain()
	return result

func _resolve_enemy_intent_action(queue, state, sequence_index: int, reaction_handler: Callable = Callable(), contamination_config: Dictionary = {}) -> Array:
	var intent = state.current_intent
	if intent == null:
		return []
	var requested_amount: int = maxi(1, intent.pressure_amount)
	var events: Array = []
	var applied_amount := 0
	var target_instance_id := ""
	var channel := ""
	match intent.action_type:
		EnemyIntentScript.WALL_TAX:
			channel = "draw_capacity"
			var current_capacity: int = maxi(0, state.draw_capacity)
			var minimum_capacity: int = mini(1, current_capacity)
			var next_capacity: int = maxi(minimum_capacity, current_capacity - requested_amount)
			applied_amount = current_capacity - next_capacity
			state.draw_capacity = next_capacity
			if applied_amount > 0:
				events.append(DomainEventScript.new(DomainEventScript.CAPACITY_CHANGED, {
					"effect_id": intent.intent_id,
					"capacity": channel,
					"previous": current_capacity,
					"value": next_capacity,
					"amount": -applied_amount,
					"sequence_index": sequence_index,
				}))
		EnemyIntentScript.INTEGRITY, EnemyIntentScript.HUNT:
			channel = "reserve_integrity"
			var target = _reserve_target(state, intent.action_type == EnemyIntentScript.HUNT)
			if target != null:
				target_instance_id = str(target.instance_id)
				var service := ReserveServiceScript.new(state.zones, state.reserve_capacity)
				var loss := IntegrityLossScript.new(requested_amount, IntegrityCauseScript.ENEMY_DAMAGE)
				var result = service.apply_integrity_loss(target_instance_id, loss)
				for event in result.events:
					event.data["sequence_index"] = sequence_index
					events.append(event)
				for event in result.events:
					if event.event_type == DomainEventScript.INTEGRITY_CHANGED:
						applied_amount = int(event.data.get("amount", 0))
						break
		EnemyIntentScript.CONTAMINATION:
			channel = "draw_wall"
			if state.zones == null:
				_fail_enemy_intent_action(queue, intent, "NO_TILE_ZONES", sequence_index)
				return events
			var service = state.contamination_service if state.contamination_service != null else ContaminationServiceScript.new(state.zones, state)
			var contamination_id := str(contamination_config.get("contamination_id", "base.contamination.clutter"))
			var contamination = ContaminationCatalogScript.by_id(contamination_id)
			if service == null or contamination == null or not contamination.is_valid():
				_fail_enemy_intent_action(queue, intent, "CONTAMINATION_SERVICE_UNAVAILABLE", sequence_index)
				return events
			if contamination_config.has("injection_count"):
				requested_amount = maxi(1, int(contamination_config.get("injection_count", requested_amount)))
			for injection_index in requested_amount:
				var instance_id := "battle.intent.%d.%s.%d" % [state.queue_index, intent.intent_id, injection_index]
				var injection = service.inject_contamination(
					instance_id,
					"base.tile.honors.white",
					contamination,
					TileZoneScript.DRAW_WALL,
					sequence_index,
				)
				if injection == null or not injection.is_accepted():
					_fail_enemy_intent_action(queue, intent, str(injection.status) if injection != null else "INJECTION_FAILED", sequence_index)
					return events
				applied_amount += 1
				events.append_array(injection.events)
		EnemyIntentScript.TABLE_INTERFERENCE:
			channel = "stability"
			var previous_stability: int = maxi(0, state.stability)
			applied_amount = mini(requested_amount, previous_stability)
			state.stability = previous_stability - applied_amount
			if applied_amount > 0:
				events.append(DomainEventScript.new(DomainEventScript.STABILITY_CHANGED, {
					"effect_id": intent.intent_id,
					"previous_stability": previous_stability,
					"stability": state.stability,
					"amount": -applied_amount,
					"sequence_index": sequence_index,
				}))
		EnemyIntentScript.RULE_BREAKER:
			channel = "tp"
			var previous_tp: int = maxi(0, state.tp)
			applied_amount = mini(requested_amount, previous_tp)
			state.tp = previous_tp - applied_amount
			if applied_amount > 0:
				events.append(DomainEventScript.new(DomainEventScript.TP_CHANGED, {
					"effect_id": intent.intent_id,
					"previous_tp": previous_tp,
					"tp": state.tp,
					"amount": -applied_amount,
					"sequence_index": sequence_index,
				}))
		EnemyIntentScript.AUDIT:
			channel = "fatigue"
			for _increase_index in requested_amount:
				events.append_array(state.increment_fatigue(intent.intent_id, sequence_index))
				applied_amount += 1
		EnemyIntentScript.REWARD_TAX:
			channel = "reward_tax"
			state.reward_tax += requested_amount
			applied_amount = requested_amount
		_:
			return []
	events.append(DomainEventScript.new(DomainEventScript.ENEMY_INTENT_EFFECT_APPLIED, {
		"intent_id": intent.intent_id,
		"action_type": intent.action_type,
		"requested_amount": requested_amount,
		"amount": applied_amount,
		"channel": channel,
		"target_instance_id": target_instance_id,
		"sequence_index": sequence_index,
	}))
	if applied_amount > 0 and reaction_handler.is_valid() and intent.action_type in [EnemyIntentScript.CONTAMINATION, EnemyIntentScript.TABLE_INTERFERENCE]:
		queue.enqueue_trigger(CombatResolutionEffectScript.new(
			"intent.reactions.%s" % intent.intent_id,
			reaction_handler.bind(intent.action_type, intent.intent_id, applied_amount),
		))
	return events

func _fail_enemy_intent_action(queue, intent, reason: String, sequence_index: int) -> void:
	var diagnostic := {
		"code": "INTENT_ACTION_FAILED",
		"intent_id": intent.intent_id if intent != null else "",
		"action_type": intent.action_type if intent != null else "",
		"reason": reason,
		"sequence_index": sequence_index,
	}
	queue.fail(
		CombatResolutionResultScript.INTENT_ACTION_FAILED,
		diagnostic,
		DomainEventScript.new(DomainEventScript.ENEMY_INTENT_FAILED, diagnostic),
	)

func _reserve_target(state, weakest: bool):
	if state == null or state.zones == null:
		return null
	var reserve_tiles: Array = state.zones.contents(TileZoneScript.RESERVE)
	if reserve_tiles.is_empty():
		return null
	if weakest:
		reserve_tiles.sort_custom(func(left, right):
			if left.integrity != right.integrity:
				return left.integrity < right.integrity
			return left.instance_id < right.instance_id
		)
	else:
		reserve_tiles.sort_custom(func(left, right): return left.instance_id < right.instance_id)
	return reserve_tiles[0]

func _resolve_intent_transition(queue, state, sequence_index: int) -> Array:
	if queue.is_failed():
		return []
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
