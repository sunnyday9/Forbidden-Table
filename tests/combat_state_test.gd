class_name CombatStateTest
extends RefCounted

const CombatResolutionStep = preload("res://src/domain/combat/combat_resolution_step.gd")
const CombatConversionResult = preload("res://src/domain/combat/combat_conversion_result.gd")
const CombatResolver = preload("res://src/domain/combat/combat_resolver.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_intent_is_visible_and_loops_deterministically(failures)
	test_player_resolution_changes_enemy_hp_predictably(failures)
	test_combat_conversion_channels_resolve_through_combat_state(failures)
	test_pressure_limit_marks_pending_defeat_before_queue_drain(failures)
	test_pending_death_waits_for_queue_boundary_after_remaining_steps(failures)
	test_terminal_ordering_uses_causal_sequence_and_defeat_tie_break(failures)
	return failures

func test_intent_is_visible_and_loops_deterministically(failures: Array[String]) -> void:
	var state = CombatState.new(10, 10)
	var resolver := CombatResolver.new()

	assert_true(state.current_intent.intent_id == "pressure_rise", "CombatState exposes the first fixed Intent", failures)
	assert_true(state.to_dictionary()["current_intent"]["intent_id"] == "pressure_rise", "serialized domain state exposes current Intent", failures)

	var first_result = resolver.resolve_enemy_intent(state)
	assert_true(first_result.is_resolved(), "the first enemy Intent resolves", failures)
	assert_true(state.pressure == 2, "the first Intent adds its fixed Pressure amount", failures)
	assert_true(state.current_intent.intent_id == "pressure_surge", "the fixed loop advances to its next Intent", failures)
	assert_true(_has_event(first_result.events, DomainEvent.ENEMY_INTENT_RESOLVED), "enemy resolution emits an explicit Intent event", failures)

	var second_result = resolver.resolve_enemy_intent(state)
	assert_true(second_result.is_resolved(), "the second enemy Intent resolves", failures)
	assert_true(state.pressure == 5, "the second Intent adds its fixed Pressure amount", failures)
	assert_true(state.current_intent.intent_id == "pressure_rise", "the fixed Intent loop wraps to its first Intent", failures)

func test_player_resolution_changes_enemy_hp_predictably(failures: Array[String]) -> void:
	var state = CombatState.new(12, 10)
	var result = CombatResolver.new().resolve_player_action(state, 4)

	assert_true(result.is_resolved(), "a player combat action resolves", failures)
	assert_true(state.enemy_hp == 8, "player damage reduces enemy HP by the requested amount", failures)
	assert_true(state.pressure == 0, "player damage does not add implicit Pressure", failures)
	assert_true(_has_event(result.events, DomainEvent.ENEMY_HP_CHANGED), "damage emits an explicit enemy HP event", failures)

func test_combat_conversion_channels_resolve_through_combat_state(failures: Array[String]) -> void:
	var state = CombatState.new(12, 10, 3)
	var combat_output = CombatConversionResult.new(10, 4, 2, "test.profile")
	var result = CombatResolver.new().resolve_combat_conversion(state, combat_output)

	assert_true(result.is_resolved(), "a CombatConversionResult resolves through CombatState", failures)
	assert_true(state.enemy_hp == 8, "CombatConversion Damage reduces enemy HP", failures)
	assert_true(state.pressure == 1, "CombatConversion Stability removes existing Pressure", failures)

func test_pressure_limit_marks_pending_defeat_before_queue_drain(failures: Array[String]) -> void:
	var state = CombatState.new(10, 5, 3)
	var resolver := CombatResolver.new()
	var queue = resolver.begin_queue(state)
	queue.add_step(CombatResolutionStep.new("enemy.pressure", 0, 4))
	queue.add_step(CombatResolutionStep.new("after.lethal.pressure", 1, 1))

	assert_true(state.pressure == 5, "Pressure is capped at the Pressure Limit", failures)
	assert_true(state.enemy_hp == 9, "the queue continues applying steps after pending_defeat", failures)
	assert_true(state.pending_defeat, "lethal Pressure marks pending_defeat during queue resolution", failures)
	assert_true(state.terminal_outcome == CombatState.ONGOING, "pending defeat does not resolve before queue drain", failures)
	assert_true(state.queue_index == 0, "the queue index changes only at a queue boundary", failures)

	var result = queue.drain()
	assert_true(result.is_resolved(), "the Pressure queue drains successfully", failures)
	assert_true(state.queue_index == 1, "draining the queue advances the queue index", failures)
	assert_true(state.terminal_outcome == CombatState.DEFEAT, "State-Based Checks resolve defeat at the queue boundary", failures)
	assert_true(_has_event(result.events, DomainEvent.BATTLE_LOST), "queue-boundary defeat emits BattleLost", failures)

func test_pending_death_waits_for_queue_boundary_after_remaining_steps(failures: Array[String]) -> void:
	var state = CombatState.new(3, 10)
	var resolver := CombatResolver.new()
	var queue = resolver.begin_queue(state)
	queue.add_step(CombatResolutionStep.new("player.damage", 3, 0))
	queue.add_step(CombatResolutionStep.new("player.pressure", 0, 2))

	assert_true(state.pending_death, "zero enemy HP marks pending_death during queue resolution", failures)
	assert_true(state.pressure == 2, "the queue continues applying steps after pending death", failures)
	assert_true(state.terminal_outcome == CombatState.ONGOING, "pending death does not resolve mid-queue", failures)

	var result = queue.drain()
	assert_true(result.terminal_outcome == CombatState.VICTORY, "State-Based Checks resolve victory only after the queue drains", failures)
	assert_true(state.enemy_hp == 0, "enemy HP is clamped at zero", failures)

func test_terminal_ordering_uses_causal_sequence_and_defeat_tie_break(failures: Array[String]) -> void:
	var defeat_first_state = CombatState.new(1, 5, 4)
	var defeat_first_queue = CombatResolver.new().begin_queue(defeat_first_state)
	defeat_first_queue.add_step(CombatResolutionStep.new("enemy.pressure", 0, 1))
	defeat_first_queue.add_step(CombatResolutionStep.new("player.damage", 1, 0))
	var defeat_first_result = defeat_first_queue.drain()
	assert_true(defeat_first_result.terminal_outcome == CombatState.DEFEAT, "earlier lethal Pressure wins causal ordering", failures)

	var victory_first_state = CombatState.new(1, 5, 4)
	var victory_first_queue = CombatResolver.new().begin_queue(victory_first_state)
	victory_first_queue.add_step(CombatResolutionStep.new("player.damage", 1, 0))
	victory_first_queue.add_step(CombatResolutionStep.new("enemy.pressure", 0, 1))
	var victory_first_result = victory_first_queue.drain()
	assert_true(victory_first_result.terminal_outcome == CombatState.VICTORY, "earlier lethal damage wins causal ordering", failures)

	var tie_state = CombatState.new(1, 5, 4)
	var tie_queue = CombatResolver.new().begin_queue(tie_state)
	tie_queue.add_step(CombatResolutionStep.new("same.atomic.effect", 1, 1))
	var tie_result = tie_queue.drain()
	assert_true(tie_result.terminal_outcome == CombatState.DEFEAT, "an exact same-effect terminal tie favors Defeat", failures)
	assert_true(tie_state.terminal_sequence_index == 1, "terminal causal index records the shared effect sequence", failures)

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
