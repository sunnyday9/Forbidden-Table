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
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_fixed_transition_resolves_through_queue(failures)
	test_wall_tax_intent_suppresses_draw_capacity(failures)
	test_integrity_intent_targets_stable_reserve_tile(failures)
	test_hunt_targets_the_weakest_reserve_tile(failures)
	test_contamination_intent_adds_battle_only_wall_tile(failures)
	test_table_interference_reduces_stability(failures)
	test_rule_breaker_taxes_tp(failures)
	test_audit_accelerates_fatigue(failures)
	test_reward_tax_is_battle_local_saved_state(failures)
	test_rejected_contamination_action_is_atomic(failures)
	test_unsupported_action_type_is_rejected_before_mutation(failures)
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

func test_wall_tax_intent_suppresses_draw_capacity(failures: Array[String]) -> void:
	var graph := IntentGraph.new("wall_tax", [
		EnemyIntent.new("wall_tax", "Tax the Wall", 1, "WALL_TAX", [IntentTransition.fixed("wall_tax.loop", "wall_tax")]),
	])
	var state := CombatState.new(10, 10)
	state.set_intent_graph(graph)
	var result = CombatResolver.new().resolve_enemy_intent(state)

	assert_true(result.status == CombatResolutionResult.RESOLVED, "a valid Wall Tax intent resolves", failures)
	assert_true(state.pressure == 0, "Wall Tax does not also apply its amount as Pressure", failures)
	assert_true(state.draw_capacity == 2, "Wall Tax suppresses one Draw Action for the battle", failures)
	assert_true(state.current_intent.intent_id == "wall_tax", "Wall Tax still advances the Intent Graph", failures)
	var typed_event = _event_of_type(result.events, "EnemyIntentEffectApplied")
	assert_true(typed_event != null, "typed Intent resolution emits a causal effect event", failures)
	if typed_event != null:
		assert_true(typed_event.data.get("action_type", "") == "WALL_TAX", "the causal effect event preserves its typed action", failures)
		assert_true(typed_event.data.get("amount", 0) == 1, "the causal effect event records the applied magnitude", failures)
	CombatResolver.new().resolve_enemy_intent(state)
	CombatResolver.new().resolve_enemy_intent(state)
	assert_true(state.draw_capacity == 1, "repeated Wall Tax cannot reduce the battle to zero Draw Actions", failures)

func test_unsupported_action_type_is_rejected_before_mutation(failures: Array[String]) -> void:
	var graph := IntentGraph.new("unknown", [
		EnemyIntent.new("unknown", "Unknown Action", 2, "UNSUPPORTED", [IntentTransition.fixed("unknown.loop", "unknown")]),
	])
	var state := CombatState.new(10, 10)
	state.set_intent_graph(graph)
	var before: Dictionary = state.to_dictionary()
	var result = CombatResolver.new().resolve_enemy_intent(state)

	assert_true(not graph.validation().is_valid(), "unsupported action types invalidate the authored graph", failures)
	assert_true(graph.validation().has_code("unsupported_action_type"), "unsupported action types have a stable validation code", failures)
	assert_true(result.status == CombatResolutionResult.INVALID_INTENT_GRAPH, "an unsupported action rejects before resolution", failures)
	assert_true(state.to_dictionary() == before, "rejecting an unsupported type leaves the battle checkpoint unchanged", failures)

func test_integrity_intent_targets_stable_reserve_tile(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new(3)
	var tile_b := TileInstance.new("reserve.b", "base.tile.characters.2")
	var tile_a := TileInstance.new("reserve.a", "base.tile.characters.1")
	zones.add(tile_b, TileZone.RESERVE)
	zones.add(tile_a, TileZone.RESERVE)
	var graph := IntentGraph.new("integrity", [
		EnemyIntent.new("integrity", "Collect Integrity", 1, EnemyIntent.INTEGRITY, [IntentTransition.fixed("integrity.loop", "integrity")]),
	])
	var state := CombatState.new(10, 10)
	state.zones = zones
	state.set_intent_graph(graph)
	var result = CombatResolver.new().resolve_enemy_intent(state)

	assert_true(result.is_resolved(), "a valid Integrity intent resolves", failures)
	assert_true(tile_a.integrity == 2 and tile_b.integrity == 3, "Integrity damages the first stable Reserve ID", failures)
	assert_true(state.pressure == 0, "Integrity does not apply its amount as Pressure", failures)
	var typed_event = _event_of_type(result.events, DomainEvent.ENEMY_INTENT_EFFECT_APPLIED)
	assert_true(typed_event != null, "Integrity emits a typed causal event", failures)
	if typed_event != null:
		assert_true(typed_event.data.get("target_instance_id", "") == tile_a.instance_id, "Integrity records its public Reserve target", failures)
		assert_true(typed_event.data.get("amount", 0) == 1, "Integrity metadata reports the actual integrity loss", failures)

func test_hunt_targets_the_weakest_reserve_tile(failures: Array[String]) -> void:
	var zones := TileZoneContainer.new(3)
	var tile_a := TileInstance.new("reserve.a", "base.tile.characters.1")
	var tile_b := TileInstance.new("reserve.b", "base.tile.characters.2")
	zones.add(tile_a, TileZone.RESERVE)
	zones.add(tile_b, TileZone.RESERVE)
	tile_b.apply_integrity_loss(2)
	var graph := IntentGraph.new("hunt", [
		EnemyIntent.new("hunt", "Hunt the Weak Line", 1, EnemyIntent.HUNT, [IntentTransition.fixed("hunt.loop", "hunt")]),
	])
	var state := CombatState.new(10, 10)
	state.zones = zones
	state.set_intent_graph(graph)
	var result = CombatResolver.new().resolve_enemy_intent(state)

	assert_true(result.is_resolved(), "a valid Hunt intent resolves", failures)
	assert_true(not zones.contains_in_zone(tile_b.instance_id, TileZone.RESERVE), "Hunt breaks the weakest Reserve tile first", failures)
	assert_true(zones.contains_in_zone(tile_a.instance_id, TileZone.RESERVE) and tile_a.integrity == 3, "Hunt leaves a stronger Reserve tile intact", failures)
	var typed_event = _event_of_type(result.events, DomainEvent.ENEMY_INTENT_EFFECT_APPLIED)
	assert_true(typed_event != null and typed_event.data.get("target_instance_id", "") == tile_b.instance_id, "Hunt records its weakest public target", failures)
	assert_true(typed_event != null and typed_event.data.get("amount", 0) == 1, "Hunt metadata reports the actual integrity loss", failures)

func test_contamination_intent_adds_battle_only_wall_tile(failures: Array[String]) -> void:
	var graph := IntentGraph.new("contaminate", [
		EnemyIntent.new("contaminate", "Seed Contamination", 1, EnemyIntent.CONTAMINATION, [IntentTransition.fixed("contaminate.loop", "contaminate")]),
	])
	var first_zones := TileZoneContainer.new(3)
	var first_state := CombatState.new(10, 10)
	first_state.zones = first_zones
	first_state.set_intent_graph(graph)
	var first_result = CombatResolver.new().resolve_enemy_intent(first_state)
	var injected_tiles: Array = first_zones.contents(TileZone.DRAW_WALL)

	assert_true(first_result.is_resolved(), "a valid Contamination intent resolves", failures)
	assert_true(injected_tiles.size() == 1, "Contamination injects one tile into the Draw Wall", failures)
	assert_true(first_zones.size(TileZone.TILE_POOL) == 0, "enemy contamination does not pollute the Run Tile Pool", failures)
	if injected_tiles.size() == 1:
		assert_true(injected_tiles[0].contamination_id == "base.contamination.clutter", "Contamination uses the battle-only clutter definition", failures)
		assert_true(injected_tiles[0].lifetime == "BATTLE" and injected_tiles[0].origin == "ENEMY", "the injected tile is enemy-origin Battle-only state", failures)
	var typed_event = _event_of_type(first_result.events, DomainEvent.ENEMY_INTENT_EFFECT_APPLIED)
	assert_true(typed_event != null and typed_event.data.get("amount", 0) == 1, "Contamination records one applied injection", failures)

	var replay_zones := TileZoneContainer.new(3)
	var replay_state := CombatState.new(10, 10)
	replay_state.zones = replay_zones
	replay_state.set_intent_graph(graph)
	var replay_result = CombatResolver.new().resolve_enemy_intent(replay_state)
	assert_true(first_result.to_dictionary() == replay_result.to_dictionary(), "Contamination action and injected instance ID are deterministic", failures)

func test_table_interference_reduces_stability(failures: Array[String]) -> void:
	var graph := IntentGraph.new("interfere", [
		EnemyIntent.new("interfere", "Interfere with the Table", 2, EnemyIntent.TABLE_INTERFERENCE, [IntentTransition.fixed("interfere.loop", "interfere")]),
	])
	var state := CombatState.new(10, 10)
	state.stability = 3
	state.set_intent_graph(graph)
	var result = CombatResolver.new().resolve_enemy_intent(state)
	var stability_event = _event_of_type(result.events, "StabilityChanged")

	assert_true(result.is_resolved(), "a valid Table Interference intent resolves", failures)
	assert_true(state.stability == 1, "Table Interference reduces the existing Pressure-relief Stability channel", failures)
	assert_true(stability_event != null and stability_event.data.get("amount", 0) == -2, "the Stability event reports the truthful negative change", failures)
	var typed_event = _event_of_type(result.events, DomainEvent.ENEMY_INTENT_EFFECT_APPLIED)
	assert_true(typed_event != null and typed_event.data.get("channel", "") == "stability", "Table Interference identifies the altered channel", failures)
	CombatResolver.new().resolve_enemy_intent(state)
	assert_true(state.stability == 0, "repeated Table Interference floors Stability without underflow", failures)

func test_rule_breaker_taxes_tp(failures: Array[String]) -> void:
	var graph := IntentGraph.new("rewrite", [
		EnemyIntent.new("rewrite", "Rewrite the Rule", 2, EnemyIntent.RULE_BREAKER, [IntentTransition.fixed("rewrite.loop", "rewrite")]),
	])
	var state := CombatState.new(10, 10, 0, [], 3)
	state.set_intent_graph(graph)
	var result = CombatResolver.new().resolve_enemy_intent(state)
	var tp_event = _event_of_type(result.events, DomainEvent.TP_CHANGED)

	assert_true(result.is_resolved(), "a valid Rule Breaker intent resolves", failures)
	assert_true(state.tp == 1, "Rule Breaker reduces available TP by its authored amount", failures)
	assert_true(tp_event != null and tp_event.data.get("amount", 0) == -2, "the TP event records the truthful negative change", failures)
	var typed_event = _event_of_type(result.events, DomainEvent.ENEMY_INTENT_EFFECT_APPLIED)
	assert_true(typed_event != null and typed_event.data.get("channel", "") == "tp", "Rule Breaker identifies the taxed channel", failures)

func test_audit_accelerates_fatigue(failures: Array[String]) -> void:
	var graph := IntentGraph.new("audit", [
		EnemyIntent.new("audit", "Audit the Run", 2, EnemyIntent.AUDIT, [IntentTransition.fixed("audit.loop", "audit")]),
	])
	var state := CombatState.new(10, 10)
	state.fatigue = 1
	state.set_intent_graph(graph)
	var result = CombatResolver.new().resolve_enemy_intent(state)

	assert_true(result.is_resolved(), "a valid Audit intent resolves", failures)
	assert_true(state.fatigue == 3, "Audit adds its authored amount to battle Fatigue", failures)
	assert_true(_count_events(result.events, DomainEvent.FATIGUE_CHANGED) == 2, "Audit records each deterministic Fatigue increase", failures)
	var typed_event = _event_of_type(result.events, DomainEvent.ENEMY_INTENT_EFFECT_APPLIED)
	assert_true(typed_event != null and typed_event.data.get("channel", "") == "fatigue", "Audit identifies the accelerated channel", failures)

func test_reward_tax_is_battle_local_saved_state(failures: Array[String]) -> void:
	var graph := IntentGraph.new("tax_reward", [
		EnemyIntent.new("tax_reward", "Collect the Ledger", 2, EnemyIntent.REWARD_TAX, [IntentTransition.fixed("tax_reward.loop", "tax_reward")]),
	])
	var state := CombatState.new(10, 10)
	state.set_intent_graph(graph)
	var result = CombatResolver.new().resolve_enemy_intent(state)

	assert_true(result.is_resolved(), "a valid Reward Tax intent resolves", failures)
	assert_true(state.to_dictionary().get("reward_tax", -1) == 2, "Reward Tax records its amount in battle runtime state", failures)
	assert_true(state.public_battle_state().get("reward_tax", -1) == 2, "the battle-local reward tax remains public battle state", failures)
	var typed_event = _event_of_type(result.events, DomainEvent.ENEMY_INTENT_EFFECT_APPLIED)
	assert_true(typed_event != null and typed_event.data.get("channel", "") == "reward_tax", "Reward Tax identifies its battle-local marker", failures)

func test_rejected_contamination_action_is_atomic(failures: Array[String]) -> void:
	var controller := BattleController.new(5521)
	var graph := IntentGraph.new("contaminate", [
		EnemyIntent.new("contaminate", "Seed Contamination", 1, EnemyIntent.CONTAMINATION, [IntentTransition.fixed("contaminate.next", "next")]),
		EnemyIntent.new("next", "Next", 0, EnemyIntent.PRESSURE, [IntentTransition.fixed("next.loop", "next")]),
	])
	controller.domain.combat_state.set_intent_graph(graph)
	controller.domain.zones.add(TileInstance.new("battle.intent.0.contaminate.0", "base.tile.honors.white"), TileZone.DISCARD)
	var before_checkpoint: Dictionary = controller.domain.checkpoint()
	var before_rng: Dictionary = controller.domain.rng_snapshot()
	var before_replay_count: int = controller.replay_record.commands.size()
	var result = controller.submit(ResolveEnemyIntentCommand.new("contamination.rejected"))

	assert_true(not result.accepted, "a rejected contamination injection rejects the Main Intent", failures)
	assert_true(result.validation.code == "INTENT_ACTION_FAILED", "the rejected typed action returns a stable failure status", failures)
	assert_true(controller.domain.checkpoint() == before_checkpoint, "a rejected typed action leaves battle zones and intent unchanged", failures)
	assert_true(controller.domain.rng_snapshot() == before_rng, "a rejected typed action restores every RNG stream", failures)
	assert_true(controller.replay_record.commands.size() == before_replay_count, "a rejected typed action is excluded from accepted-only replay", failures)

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

func _event_of_type(events: Array, event_type: String):
	for event in events:
		if event.event_type == event_type:
			return event
	return null

func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for event in events:
		if event.event_type == event_type:
			count += 1
	return count

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
