class_name IntentGraphTest
extends RefCounted

const CombatResolutionResult = preload("res://src/domain/combat/combat_resolution_result.gd")
const CombatResolver = preload("res://src/domain/combat/combat_resolver.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const EnemyIntent = preload("res://src/domain/combat/enemy_intent.gd")
const IntentGraph = preload("res://src/domain/combat/intent_graph.gd")
const IntentTransition = preload("res://src/domain/combat/intent_transition.gd")
const PublicStateCondition = preload("res://src/domain/combat/public_state_condition.gd")
const BattleController = preload("res://src/presentation/battle/battle_controller.gd")
const EndTurnCommand = preload("res://src/domain/commands/end_turn_command.gd")
const ResolveEnemyIntentCommand = preload("res://src/domain/commands/resolve_enemy_intent_command.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_fixed_transition_resolves_through_queue(failures)
	test_conditional_transition_reads_public_state(failures)
	test_weighted_transition_uses_enemy_rng(failures)
	test_invalid_graph_reports_missing_targets(failures)
	test_exhausted_transition_options_are_structured(failures)
	test_repeated_graph_transitions_remain_stable(failures)
	test_same_seed_repeats_intent_sequence(failures)
	test_enemy_intent_command_and_end_turn_use_domain_resolution(failures)
	test_rejected_end_turn_is_atomic_and_not_replayed(failures)
	test_rejected_end_turn_restores_consumed_rng(failures)
	return failures

func test_fixed_transition_resolves_through_queue(failures: Array[String]) -> void:
	var graph := IntentGraph.new("pressure.rise", [
		EnemyIntent.new("pressure.rise", "Pressure Rise", 2, EnemyIntent.PRESSURE, [
			IntentTransition.fixed("rise.to.surge", "pressure.surge"),
		]),
		EnemyIntent.new("pressure.surge", "Pressure Surge", 3, EnemyIntent.PRESSURE, [
			IntentTransition.fixed("surge.to.rise", "pressure.rise"),
		]),
	])
	var state := CombatState.new(30, 10)
	state.set_intent_graph(graph)
	var result = CombatResolver.new().resolve_enemy_intent(state)

	assert_true(result.status == CombatResolutionResult.RESOLVED, "a valid fixed Intent resolves", failures)
	assert_true(state.pressure == 2, "the graph preserves the prototype Pressure amount", failures)
	assert_true(state.current_intent.intent_id == "pressure.surge", "the fixed target becomes active", failures)
	assert_true(result.events[0].event_type == DomainEvent.PRESSURE_CHANGED, "the Pressure event is causal-first", failures)
	assert_true(result.events[-1].event_type == DomainEvent.ENEMY_INTENT_RESOLVED, "Intent resolution is emitted by the queue", failures)

func test_conditional_transition_reads_public_state(failures: Array[String]) -> void:
	var graph := IntentGraph.new("check", [
		EnemyIntent.new("check", "Check", 0, EnemyIntent.PRESSURE, [
			IntentTransition.conditional(
				"check.high-pressure",
				"pressure.high",
				PublicStateCondition.new("pressure", PublicStateCondition.GREATER_THAN_OR_EQUAL, 3),
			),
			IntentTransition.conditional(
				"check.low-pressure",
				"pressure.low",
				PublicStateCondition.new("pressure", PublicStateCondition.LESS_THAN, 3),
			),
		]),
		EnemyIntent.new("pressure.high", "High", 0),
		EnemyIntent.new("pressure.low", "Low", 0),
	])
	var high_state := CombatState.new(10, 10, 3)
	high_state.set_intent_graph(graph)
	var low_state := CombatState.new(10, 10, 1)
	low_state.set_intent_graph(graph)

	assert_true(high_state.select_next_intent().target_intent_id == "pressure.high", "conditional transitions use public Pressure", failures)
	assert_true(low_state.select_next_intent().target_intent_id == "pressure.low", "the first false condition falls through deterministically", failures)
	assert_true(graph.validation().is_valid(), "public-state conditions produce a valid graph", failures)

func test_weighted_transition_uses_enemy_rng(failures: Array[String]) -> void:
	var graph := IntentGraph.new("weighted", [
		EnemyIntent.new("weighted", "Weighted", 0, EnemyIntent.PRESSURE, [
			IntentTransition.weighted("weighted.a", "a", 1),
			IntentTransition.weighted("weighted.b", "b", 3),
		]),
		EnemyIntent.new("a", "A", 0),
		EnemyIntent.new("b", "B", 0),
	])
	var state := CombatState.new(10, 10)
	state.set_intent_graph(graph)
	state.set_intent_rng(DomainRngStreams.new(7).enemy)
	var selection = state.select_next_intent()

	assert_true(selection.is_selected(), "weighted transitions select one target", failures)
	assert_true(selection.transition_id == "weighted.b", "weighted selection uses the deterministic draw", failures)

func test_invalid_graph_reports_missing_targets(failures: Array[String]) -> void:
	var graph := IntentGraph.new("start", [
		EnemyIntent.new("start", "Start", 0, EnemyIntent.PRESSURE, [
			IntentTransition.fixed("missing.target", "does.not.exist"),
		]),
	])
	var state := CombatState.new(10, 10)
	state.set_intent_graph(graph)
	var result = CombatResolver.new().resolve_enemy_intent(state)

	assert_true(not graph.validation().is_valid(), "a missing target invalidates the graph", failures)
	assert_true(graph.validation().has_code("missing_target"), "missing targets have structured validation", failures)
	assert_true(result.status == CombatResolutionResult.INVALID_INTENT_GRAPH, "invalid graphs fail without a soft-lock", failures)
	assert_true(result.diagnostics[0]["code"] == "INVALID_INTENT_GRAPH", "the failure preserves a diagnostic code", failures)

func test_exhausted_transition_options_are_structured(failures: Array[String]) -> void:
	var graph := IntentGraph.new("terminal", [EnemyIntent.new("terminal", "Terminal", 0)])
	var state := CombatState.new(10, 10)
	state.set_intent_graph(graph)
	var result = CombatResolver.new().resolve_enemy_intent(state)

	assert_true(result.status == CombatResolutionResult.INTENT_TRANSITIONS_EXHAUSTED, "a terminal node reports exhausted options", failures)
	assert_true(result.diagnostics[0]["code"] == "INTENT_TRANSITIONS_EXHAUSTED", "exhaustion is structured", failures)
	assert_true(not state.is_queue_active(), "an exhausted transition cannot leave the queue active", failures)

func test_repeated_graph_transitions_remain_stable(failures: Array[String]) -> void:
	var graph := IntentGraph.new("a", [
		EnemyIntent.new("a", "A", 0, EnemyIntent.PRESSURE, [IntentTransition.fixed("a.to.b", "b")]),
		EnemyIntent.new("b", "B", 0, EnemyIntent.PRESSURE, [IntentTransition.fixed("b.to.c", "c")]),
		EnemyIntent.new("c", "C", 0, EnemyIntent.PRESSURE, [IntentTransition.fixed("c.to.a", "a")]),
	])
	var state := CombatState.new(10, 99)
	state.set_intent_graph(graph)
	var observed: Array[String] = []
	for _step in range(6):
		observed.append(state.current_intent.intent_id)
		CombatResolver.new().resolve_enemy_intent(state)

	assert_true(observed == ["a", "b", "c", "a", "b", "c"], "repeated graph traversal does not drift", failures)

func test_same_seed_repeats_intent_sequence(failures: Array[String]) -> void:
	var first := _weighted_sequence(4242)
	var second := _weighted_sequence(4242)
	assert_true(first == second, "the same seed repeats the accepted-command Intent sequence", failures)

func test_enemy_intent_command_and_end_turn_use_domain_resolution(failures: Array[String]) -> void:
	var controller := BattleController.new()
	var command_result = controller.submit(ResolveEnemyIntentCommand.new("stage1.intent.command"))
	assert_true(command_result.accepted, "the explicit Intent command is accepted", failures)
	assert_true(command_result.command_type == "ResolveEnemyIntent", "Intent resolution uses a Domain command", failures)
	assert_true(controller.presentation.pressure == 2, "the command preserves the prototype Pressure result", failures)
	assert_true(_has_event(command_result.events, DomainEvent.ENEMY_INTENT_RESOLVED), "the command exposes the causal Intent event", failures)

	var end_turn_result = controller.submit(EndTurnCommand.new("stage1.intent.end_turn"))
	assert_true(end_turn_result.accepted, "End Turn remains an accepted Domain command", failures)
	assert_true(controller.presentation.pressure == 5, "End Turn resolves the next Main Intent", failures)
	assert_true(_has_event(end_turn_result.events, DomainEvent.ENEMY_INTENT_RESOLVED), "End Turn emits the Intent resolution event", failures)

func test_rejected_end_turn_is_atomic_and_not_replayed(failures: Array[String]) -> void:
	var controller := BattleController.new(4242)
	var terminal_graph := IntentGraph.new("terminal", [
		EnemyIntent.new("terminal", "Terminal Pressure", 3, EnemyIntent.PRESSURE),
	])
	controller.domain.combat_state.set_intent_graph(terminal_graph)
	controller.domain.combat_state.pressure = 1
	controller.domain.recovery_state.start()
	var before_checkpoint: Dictionary = controller.domain.checkpoint()
	var before_rng: Dictionary = controller.domain.rng_snapshot()
	var before_sequence_index: int = controller.domain.combat_state._next_sequence_index
	var before_replay_count: int = controller.replay_record.commands.size()
	var direct_result = controller.submit(ResolveEnemyIntentCommand.new("stage1.intent.rejected_resolution"))

	assert_true(not direct_result.accepted, "the explicit Intent command rejects when the active Intent has no transition", failures)
	assert_true(direct_result.validation.code == CombatResolutionResult.INTENT_TRANSITIONS_EXHAUSTED, "the explicit Intent command preserves the transition failure status", failures)
	assert_true(controller.replay_record.commands.size() == before_replay_count, "a rejected explicit Intent command is excluded from accepted-only Replay", failures)
	assert_true(controller.domain.checkpoint() == before_checkpoint, "a rejected explicit Intent command restores the battle checkpoint", failures)
	assert_true(controller.domain.rng_snapshot() == before_rng, "a rejected explicit Intent command restores every RNG stream", failures)

	var result = controller.submit(EndTurnCommand.new("stage1.intent.rejected_end_turn"))

	assert_true(not result.accepted, "End Turn rejects when the active Intent has no transition", failures)
	assert_true(result.validation.code == CombatResolutionResult.INTENT_TRANSITIONS_EXHAUSTED, "the rejected End Turn preserves the transition failure status", failures)
	assert_true(controller.replay_record.commands.size() == before_replay_count, "a rejected End Turn is excluded from accepted-only Replay", failures)
	assert_true(controller.domain.checkpoint() == before_checkpoint, "a rejected End Turn restores pressure, recovery, and the battle checkpoint", failures)
	assert_true(controller.domain.rng_snapshot() == before_rng, "a rejected End Turn restores every RNG stream", failures)
	assert_true(controller.domain.combat_state._next_sequence_index == before_sequence_index, "a rejected End Turn restores the combat sequence counter", failures)

func test_rejected_end_turn_restores_consumed_rng(failures: Array[String]) -> void:
	var controller := BattleController.new(4243)
	controller.domain.recovery_state.start()
	controller.domain.combat_resolver = MutatingFailureCombatResolver.new()
	var before_checkpoint: Dictionary = controller.domain.checkpoint()
	var before_rng: Dictionary = controller.domain.rng_snapshot()

	var result = controller.submit(EndTurnCommand.new("stage1.intent.rng_rollback"))

	assert_true(not result.accepted, "End Turn rejects a failed Intent resolution", failures)
	assert_true(result.validation.code == "TEST_INTENT_FAILURE", "End Turn propagates the sub-resolution failure", failures)
	assert_true(controller.domain.checkpoint() == before_checkpoint, "End Turn restores state changed by a failed resolver", failures)
	assert_true(controller.domain.rng_snapshot() == before_rng, "End Turn restores RNG consumed by a failed resolver", failures)

func _weighted_sequence(seed: int) -> Array[String]:
	var graph := IntentGraph.new("start", [
		EnemyIntent.new("start", "Start", 0, EnemyIntent.PRESSURE, [
			IntentTransition.weighted("start.left", "left", 1),
			IntentTransition.weighted("start.right", "right", 1),
		]),
		EnemyIntent.new("left", "Left", 0, EnemyIntent.PRESSURE, [IntentTransition.fixed("left.start", "start")]),
		EnemyIntent.new("right", "Right", 0, EnemyIntent.PRESSURE, [IntentTransition.fixed("right.start", "start")]),
	])
	var state := CombatState.new(10, 99)
	state.set_intent_graph(graph)
	state.set_intent_rng(DomainRngStreams.new(seed).enemy)
	var observed: Array[String] = []
	for _step in range(8):
		var result = CombatResolver.new().resolve_enemy_intent(state)
		if not result.is_resolved():
			break
		observed.append(state.current_intent.intent_id)
	return observed

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

class MutatingFailureCombatResolver:
	extends RefCounted

	func resolve_enemy_intent(state):
		state.pressure += 1
		state.intent_rng.next_int(1, 100)
		state._next_sequence_index += 1
		return FailedIntentResolution.new()

class FailedIntentResolution:
	extends RefCounted

	var status := "TEST_INTENT_FAILURE"
	var events: Array = []

	func is_resolved() -> bool:
		return false

	func to_dictionary() -> Dictionary:
		return {"status": status, "events": events.duplicate()}
