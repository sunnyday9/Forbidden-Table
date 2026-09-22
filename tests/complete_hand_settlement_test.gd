class_name CompleteHandSettlementTest
extends RefCounted

const BattleDomain = preload("res://src/domain/battle/battle_domain.gd")
const CombatConversionProfile = preload("res://src/domain/combat/combat_conversion_profile.gd")
const CombatConversionResolver = preload("res://src/domain/combat/combat_conversion_resolver.gd")
const CombatResolver = preload("res://src/domain/combat/combat_resolver.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const CompleteHandEvaluator = preload("res://src/domain/mahjong/complete_hand/complete_hand_evaluator.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const DrawWall = preload("res://src/domain/tiles/draw_wall.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const EndTurnCommand = preload("res://src/domain/commands/end_turn_command.gd")
const MahjongScoreResolver = preload("res://src/domain/mahjong/scoring/mahjong_score_resolver.gd")
const PatternEvaluator = preload("res://src/domain/mahjong/pattern/pattern_evaluator.gd")
const SettlementCapacity = preload("res://src/domain/mahjong/settlement/settlement_capacity.gd")
const SettlementTurn = preload("res://src/domain/mahjong/settlement/settlement_turn.gd")
const SettlementWindow = preload("res://src/domain/mahjong/settlement/settlement_window.gd")
const SettleCompleteHandCommand = preload("res://src/domain/commands/settle_complete_hand_command.gd")
const ScoreContribution = preload("res://src/domain/mahjong/scoring/score_contribution.gd")
const TileActionService = preload("res://src/domain/tiles/tile_action_service.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")

class StubHandYakuResolver extends RefCounted:
	var calls := 0

	func resolve(_interpretation) -> Array:
		calls += 1
		return [ScoreContribution.new("yaku.test.hand", 25, ["HAND_YAKU"])]

func run() -> Array[String]:
	var failures: Array[String] = []
	test_complete_hand_command_settles_rebuilds_and_enters_recovery(failures)
	test_complete_hand_rejection_during_recovery_is_atomic(failures)
	test_rebuild_shortfall_is_deterministic_and_exhaust_persists(failures)
	test_recovery_exits_after_turn_and_normal_baseline(failures)
	test_destination_policy_routes_settled_tiles(failures)
	return failures

func test_complete_hand_command_settles_rebuilds_and_enters_recovery(failures: Array[String]) -> void:
	var yaku_resolver := StubHandYakuResolver.new()
	var fixture := _fixture(6, 5, 3, TileZone.DISCARD, yaku_resolver)
	var interpretations: Array = fixture["evaluator"].evaluate(fixture["zones"].contents(TileZone.HAND))
	var interpretation = interpretations[0] if not interpretations.is_empty() else null
	var command := SettleCompleteHandCommand.new("stage1.complete.1", interpretation.interpretation_id)
	var result = fixture["domain"].execute(command)

	assert_true(interpretation != null, "the fixture provides a valid complete-hand interpretation", failures)
	assert_true(result.accepted, "a selected complete hand is accepted through the command flow", failures)
	assert_true(result.status == "COMPLETED", "complete hand settlement returns a completed status", failures)
	assert_true(fixture["yaku_resolver"].calls == 1, "complete hand resolution invokes the Hand Yaku hook", failures)
	assert_true(fixture["zones"].size(TileZone.RESERVE) == 1, "Reserve persists through a complete-hand rebuild", failures)
	assert_true(fixture["zones"].size(TileZone.HAND) == 3, "rebuild restores the configured Recovery Baseline", failures)
	assert_true(fixture["zones"].size(TileZone.DISCARD) == 14, "settled Hand tiles follow the Discard destination policy", failures)
	assert_true(result.data["score"]["total"] >= 125, "complete hand score is large and includes Hand Yaku", failures)
	assert_true(result.data["combat_output"]["stability"] > 0, "complete hand conversion exposes a Stability component", failures)
	assert_true(_has_event(result.events, DomainEvent.COMPLETE_HAND_SETTLED), "completion emits a causal settlement event", failures)
	assert_true(_has_event(result.events, DomainEvent.RECOVERY_STARTED), "completion emits a causal recovery event", failures)
	assert_true(_draw_sources(result.events) == ["COMPLETE_HAND_REBUILD", "COMPLETE_HAND_REBUILD", "COMPLETE_HAND_REBUILD"], "rebuild events use the special DrawSource", failures)

func test_complete_hand_rejection_during_recovery_is_atomic(failures: Array[String]) -> void:
	var fixture := _fixture(6, 5, 3, TileZone.DISCARD)
	var interpretation = fixture["evaluator"].evaluate(fixture["zones"].contents(TileZone.HAND))[0]
	var first = fixture["domain"].execute(SettleCompleteHandCommand.new("stage1.complete.lock", interpretation.interpretation_id))
	var before: Dictionary = fixture["domain"].checkpoint()
	var second = fixture["domain"].execute(SettleCompleteHandCommand.new("stage1.complete.locked", interpretation.interpretation_id))

	assert_true(first.accepted, "the lock test first completes a hand", failures)
	assert_true(not second.accepted, "a second complete hand is rejected during Recovery", failures)
	assert_true(second.validation.code == "RECOVERY_LOCKED", "Recovery rejection exposes a stable validation code", failures)
	assert_true(second.events.is_empty(), "Recovery rejection emits no state-changing events", failures)
	assert_true(fixture["domain"].checkpoint() == before, "Recovery rejection is atomic", failures)

func test_rebuild_shortfall_is_deterministic_and_exhaust_persists(failures: Array[String]) -> void:
	var first := _fixture(0, 5, 3, TileZone.DISCARD)
	var second := _fixture(0, 5, 3, TileZone.DISCARD)
	var first_interpretation = first["evaluator"].evaluate(first["zones"].contents(TileZone.HAND))[0]
	var second_interpretation = second["evaluator"].evaluate(second["zones"].contents(TileZone.HAND))[0]
	var first_result = first["domain"].execute(SettleCompleteHandCommand.new("stage1.shortfall", first_interpretation.interpretation_id))
	var second_result = second["domain"].execute(SettleCompleteHandCommand.new("stage1.shortfall", second_interpretation.interpretation_id))

	assert_true(first_result.accepted and first_result.status == "COMPLETED", "a rebuild can recycle Discard while completion remains accepted", failures)
	assert_true(first["zones"].size(TileZone.HAND) == 3, "a rebuild restores the configured Recovery Baseline from Discard", failures)
	assert_true(first["zones"].size(TileZone.EXHAUST) == 1, "Exhaust is not automatically recovered", failures)
	assert_true(first_result.to_dictionary() == second_result.to_dictionary(), "rebuild shortfall results are deterministic", failures)

func test_recovery_exits_after_turn_and_normal_baseline(failures: Array[String]) -> void:
	var fixture := _fixture(8, 5, 3, TileZone.DISCARD)
	var interpretation = fixture["evaluator"].evaluate(fixture["zones"].contents(TileZone.HAND))[0]
	fixture["domain"].execute(SettleCompleteHandCommand.new("stage1.recovery.exit", interpretation.interpretation_id))
	var first_turn = fixture["domain"].execute(EndTurnCommand.new("stage1.recovery.turn.1"))
	assert_true(first_turn.accepted, "a Recovery Turn can elapse", failures)
	assert_true(fixture["domain"].recovery_state.is_recovering(), "Recovery remains active below the normal Hand Baseline", failures)
	for _draw_index in range(2):
		fixture["domain"].execute(preload("res://src/domain/commands/draw_command.gd").new("stage1.recovery.draw"))
	var second_turn = fixture["domain"].execute(EndTurnCommand.new("stage1.recovery.turn.2"))

	assert_true(second_turn.accepted, "a later turn can evaluate Recovery exit", failures)
	assert_true(not fixture["domain"].recovery_state.is_recovering(), "Recovery exits after a turn and the normal baseline", failures)
	assert_true(_has_event(second_turn.events, DomainEvent.RECOVERY_ENDED), "Recovery exit emits a causal event", failures)

func test_destination_policy_routes_settled_tiles(failures: Array[String]) -> void:
	var fixture := _fixture(3, 5, 3, TileZone.EXHAUST)
	var interpretation = fixture["evaluator"].evaluate(fixture["zones"].contents(TileZone.HAND))[0]
	var result = fixture["domain"].execute(SettleCompleteHandCommand.new("stage1.complete.exhaust", interpretation.interpretation_id))

	assert_true(result.accepted, "a configured complete-hand destination remains legal", failures)
	assert_true(fixture["zones"].size(TileZone.EXHAUST) == 15, "all settled tiles follow the configured Exhaust policy", failures)
	assert_true(fixture["zones"].size(TileZone.DISCARD) == 0, "the destination policy does not silently fall back to Discard", failures)

func _fixture(wall_count: int, normal_baseline: int, recovery_baseline: int, destination: String, yaku_resolver = null) -> Dictionary:
	var registry := ContentRegistry.new()
	for rank in range(1, 10):
		registry.register(preload("res://src/content/definitions/tile_definition.gd").new("base.tile.characters.%d" % rank, "characters", rank))
	var zones := TileZoneContainer.new()
	var hand_ids: Array[String] = []
	var hand_rows: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 1, 1, 2, 2]
	for index in range(hand_rows.size()):
		var tile_id := "run.complete.hand.%02d" % index
		hand_ids.append(tile_id)
		zones.add(TileInstance.new(tile_id, "base.tile.characters.%d" % hand_rows[index]), TileZone.HAND)
	zones.add(TileInstance.new("run.complete.reserve", "base.tile.characters.9"), TileZone.RESERVE)
	zones.add(TileInstance.new("run.complete.exhaust", "base.tile.characters.8"), TileZone.EXHAUST)
	for index in range(wall_count):
		zones.add(TileInstance.new("run.complete.wall.%02d" % index, "base.tile.characters.%d" % ((index % 9) + 1)), TileZone.TILE_POOL)
	var wall := DrawWall.new(zones, DomainRngStreams.new(991).draw_wall)
	wall.initialize()
	var actions := TileActionService.new(wall, zones)
	var pattern_evaluator := PatternEvaluator.new(registry)
	var window := SettlementWindow.new(pattern_evaluator, zones, SettlementCapacity.new(2))
	var state := CombatState.new(200, 50)
	var turn := SettlementTurn.new(window, actions, zones, normal_baseline)
	var score_resolver := MahjongScoreResolver.new()
	var profile := CombatConversionProfile.new({
		"id": "test.complete.profile",
		"damage_curve": {"mode": "linear", "multiplier": 1.0},
		"stability_curve": {"mode": "linear", "multiplier": 0.5},
	})
	var evaluator := CompleteHandEvaluator.new(registry)
	var domain := BattleDomain.new(
		zones,
		wall,
		actions,
		window,
		turn,
		score_resolver,
		CombatConversionResolver.new(),
		profile,
		state,
		CombatResolver.new(),
		null,
		evaluator,
		yaku_resolver,
		normal_baseline,
		recovery_baseline,
		destination,
	)
	return {
		"domain": domain,
		"zones": zones,
		"evaluator": evaluator,
		"yaku_resolver": yaku_resolver,
	}

func _draw_sources(events: Array) -> Array[String]:
	var sources: Array[String] = []
	for event in events:
		if event.event_type == DomainEvent.TILE_DRAWN:
			sources.append(event.data["source"])
	return sources

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
