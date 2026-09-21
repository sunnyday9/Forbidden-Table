class_name Stage0ExitReviewTest
extends RefCounted

const BattleController = preload("res://src/presentation/battle/battle_controller.gd")
const CombatResolver = preload("res://src/domain/combat/combat_resolver.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const CompleteHandEvaluator = preload("res://src/domain/mahjong/complete_hand/complete_hand_evaluator.gd")
const CompleteHandInterpretation = preload("res://src/domain/mahjong/complete_hand/complete_hand_interpretation.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const DrawCommand = preload("res://src/domain/commands/draw_command.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const PatternEvaluator = preload("res://src/domain/mahjong/pattern/pattern_evaluator.gd")
const PatternCandidate = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const SettlePatternCommand = preload("res://src/domain/commands/settle_pattern_command.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_player_can_follow_draw_pattern_settlement_damage(failures)
	test_partial_settlement_has_immediate_and_future_value(failures)
	test_complete_hand_is_attractive_but_optional(failures)
	test_pressure_is_urgent_failure_state_not_player_hp(failures)
	test_identical_scenarios_reproduce_identical_results(failures)
	return failures

func test_player_can_follow_draw_pattern_settlement_damage(failures: Array[String]) -> void:
	var controller := BattleController.new()
	assert_true(controller.presentation.status == "Draw to find a Pattern.", "the initial presentation explains the first Draw step", failures)

	var draw_result = controller.submit(DrawCommand.new("stage0.draw.1"))
	assert_true(draw_result.accepted, "the Draw command is accepted", failures)
	assert_true(controller.presentation.status == "Drew a tile.", "the presentation confirms the Draw step", failures)
	assert_true(not controller.presentation.pattern_highlights.is_empty(), "the Draw step exposes a Pattern", failures)
	if controller.presentation.pattern_highlights.is_empty():
		return

	var pattern = controller.presentation.pattern_highlights[0]
	assert_true(pattern["pattern_type"] == PatternCandidate.SEQUENCE, "the Pattern step names a Scoring Pattern", failures)
	var settlement_result = controller.submit(SettlePatternCommand.new(
		"stage0.settle.1",
		pattern["instance_ids"],
	))
	assert_true(settlement_result.accepted, "the Settlement command is accepted", failures)
	assert_true(_event_index(settlement_result.events, DomainEvent.PATTERN_SETTLED) >= 0, "Settlement emits a PatternSettled event", failures)
	assert_true(_event_index(settlement_result.events, DomainEvent.ENEMY_HP_CHANGED) > _event_index(settlement_result.events, DomainEvent.PATTERN_SETTLED), "Damage follows Settlement in the event flow", failures)
	assert_true(controller.presentation.enemy_hp < controller.presentation.enemy_max_hp, "the Settlement step produces visible Damage", failures)
	assert_true(controller.presentation.status.begins_with("Damage:"), "the presentation names the Damage result", failures)

func test_partial_settlement_has_immediate_and_future_value(failures: Array[String]) -> void:
	var controller := BattleController.new()
	controller.submit(DrawCommand.new("stage0.partial.draw"))
	var pattern = controller.presentation.pattern_highlights[0]
	var initial_enemy_hp: int = controller.presentation.enemy_hp
	var settlement_result = controller.submit(SettlePatternCommand.new(
		"stage0.partial.settle",
		pattern["instance_ids"],
	))

	assert_true(settlement_result.accepted, "a Partial Settlement is accepted", failures)
	assert_true(controller.presentation.enemy_hp < initial_enemy_hp, "Partial Settlement has immediate combat value", failures)
	assert_true(controller.presentation.discard.size() == 3, "settled tiles leave the Hand for Discard", failures)
	assert_true(controller.presentation.hand.size() == 3, "Replacement Draw restores the Hand baseline", failures)
	assert_true(_has_pattern(controller.presentation.pattern_highlights, ["run.battle.wall.4", "run.battle.wall.5", "run.battle.wall.6"]), "Replacement Draw leaves a future Pattern to pursue", failures)

func test_complete_hand_is_attractive_but_optional(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	for rank in range(1, 10):
		registry.register(TileDefinition.new("base.tile.characters.%d" % rank, "characters", rank))
	registry.register(TileDefinition.new("base.tile.dots.5", "dots", 5))
	registry.register(TileDefinition.new("base.tile.dots.6", "dots", 6))

	var hand: Array = []
	for rank in range(1, 10):
		hand.append(TileInstance.new("stage0.complete.sequence.%d" % rank, "base.tile.characters.%d" % rank))
	for index in range(3):
		hand.append(TileInstance.new("stage0.complete.triplet.%d" % index, "base.tile.dots.5"))
	for index in range(2):
		hand.append(TileInstance.new("stage0.complete.pair.%d" % index, "base.tile.dots.6"))

	var interpretations: Array = CompleteHandEvaluator.new(registry).evaluate(hand)
	var standard_interpretation = _first_hand_type(interpretations, CompleteHandInterpretation.STANDARD)
	var partial_patterns: Array = PatternEvaluator.new(registry).evaluate(hand)
	assert_true(standard_interpretation != null, "the same kind of hand can pursue a Complete Hand", failures)
	if standard_interpretation != null:
		assert_true(standard_interpretation.groups.size() == 4 and standard_interpretation.pair != null, "Complete Hand pursuit has the attractive four-groups-plus-pair payoff shape", failures)
	assert_true(_has_scoring_pattern(partial_patterns), "the Complete Hand opportunity also contains an available Partial Settlement", failures)

	var partial_controller := BattleController.new()
	partial_controller.submit(DrawCommand.new("stage0.optional.draw"))
	var partial_result = partial_controller.submit(SettlePatternCommand.new(
		"stage0.optional.settle",
		partial_controller.presentation.pattern_highlights[0]["instance_ids"],
	))
	assert_true(partial_result.accepted, "the player can take the Partial Settlement route without a Complete Hand", failures)

func test_pressure_is_urgent_failure_state_not_player_hp(failures: Array[String]) -> void:
	var state := CombatState.new(30, 5)
	var resolver := CombatResolver.new()
	var initial_enemy_hp: int = state.enemy_hp

	var first_intent = resolver.resolve_enemy_intent(state)
	assert_true(first_intent.is_resolved(), "the visible enemy Intent resolves", failures)
	assert_true(state.pressure == 2 and state.enemy_hp == initial_enemy_hp, "enemy Intent raises visible Pressure without changing enemy HP", failures)

	var second_intent = resolver.resolve_enemy_intent(state)
	assert_true(second_intent.is_resolved(), "the next visible enemy Intent resolves", failures)
	assert_true(state.pressure == state.pressure_limit, "Pressure reaches its visible limit", failures)
	assert_true(state.terminal_outcome == CombatState.DEFEAT, "reaching the Pressure limit creates an urgent defeat", failures)
	assert_true(state.enemy_hp == initial_enemy_hp, "Pressure is not hidden player HP damage", failures)
	assert_true(not state.to_dictionary().has("player_hp"), "the domain state has no player HP meter", failures)

func test_identical_scenarios_reproduce_identical_results(failures: Array[String]) -> void:
	var first := _run_default_loop()
	var second := _run_default_loop()
	assert_true(JSON.stringify(first) == JSON.stringify(second), "same accepted commands reproduce the same headless result", failures)
	assert_true(first["enemy_hp"] == 20, "the deterministic scenario has a known Damage result", failures)
	assert_true(first["pressure"] == 0, "the deterministic settlement does not add hidden Pressure", failures)

func _run_default_loop() -> Dictionary:
	var controller := BattleController.new()
	var draw_result = controller.submit(DrawCommand.new("stage0.deterministic.draw"))
	var pattern = controller.presentation.pattern_highlights[0]
	var settlement_result = controller.submit(SettlePatternCommand.new(
		"stage0.deterministic.settle",
		pattern["instance_ids"],
	))
	return {
		"draw": draw_result.to_dictionary(),
		"settlement": settlement_result.to_dictionary(),
		"hand": controller.presentation.hand,
		"discard": controller.presentation.discard,
		"enemy_hp": controller.presentation.enemy_hp,
		"pressure": controller.presentation.pressure,
		"outcome": controller.presentation.outcome,
		"events": controller.presentation.last_event_types,
		"status": controller.presentation.status,
	}

func _first_hand_type(interpretations: Array, hand_type: String):
	for interpretation in interpretations:
		if interpretation.hand_type == hand_type:
			return interpretation
	return null

func _has_scoring_pattern(patterns: Array) -> bool:
	for pattern in patterns:
		if [PatternCandidate.SEQUENCE, PatternCandidate.TRIPLET, PatternCandidate.QUAD].has(pattern.pattern_type):
			return true
	return false

func _has_pattern(patterns: Array, expected_instance_ids: Array[String]) -> bool:
	for pattern in patterns:
		var actual_ids: Array[String] = pattern["instance_ids"].duplicate()
		actual_ids.sort()
		var expected_ids: Array[String] = expected_instance_ids.duplicate()
		expected_ids.sort()
		if actual_ids == expected_ids:
			return true
	return false

func _event_index(events: Array, event_type: String) -> int:
	for index in range(events.size()):
		if events[index].event_type == event_type:
			return index
	return -1

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
