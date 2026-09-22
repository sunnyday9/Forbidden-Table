class_name SettlementTurnTest
extends RefCounted

const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const CombatState = preload("res://src/domain/combat/combat_state.gd")
const DrawSource = preload("res://src/domain/tiles/draw_source.gd")
const DrawWall = preload("res://src/domain/tiles/draw_wall.gd")
const EffectContext = preload("res://src/domain/effects/effect_context.gd")
const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const PatternEvaluator = preload("res://src/domain/mahjong/pattern/pattern_evaluator.gd")
const SettlementCapacity = preload("res://src/domain/mahjong/settlement/settlement_capacity.gd")
const SettlementTurn = preload("res://src/domain/mahjong/settlement/settlement_turn.gd")
const SettlementWindow = preload("res://src/domain/mahjong/settlement/settlement_window.gd")
const TileActionService = preload("res://src/domain/tiles/tile_action_service.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_replacement_draw_uses_source_and_updates_zones(failures)
	test_settled_tile_cannot_be_consumed_again(failures)
	test_exhaustion_is_explicit_and_end_turn_is_idempotent(failures)
	test_capacity_exhaustion_defers_remaining_patterns_to_a_later_window(failures)
	return failures

func test_replacement_draw_uses_source_and_updates_zones(failures: Array[String]) -> void:
	var registry = _registry([1, 2, 3, 4, 7, 8, 9])
	var zones := TileZoneContainer.new()
	var settled_tiles := _add_hand_tiles(zones, [1, 2, 3, 4], "run.tile.hand")
	var replacement_tiles := _add_pool_tiles(zones, [7, 8, 9], "run.tile.replacement")
	var wall := DrawWall.new(zones, DomainRngStreams.new(11).draw_wall)
	wall.initialize()
	zones.reorder(TileZone.DRAW_WALL, _tile_ids(replacement_tiles))
	var actions := TileActionService.new(wall, zones)
	var window := SettlementWindow.new(PatternEvaluator.new(registry), zones)
	var trigger_state := CombatState.new(30, 10)
	var trigger_context := EffectContext.new(trigger_state, zones, wall, actions.reserve_service)
	var turn = SettlementTurn.new(window, actions, zones, 4, null, trigger_context)
	window.open()

	var combat_output := {"damage": 20, "stability": 3}
	var result = turn.resolve_partial_settlement(_tile_ids(settled_tiles.slice(0, 3)), combat_output)

	assert_true(result.is_completed(), "a settlement with available replacements completes", failures)
	assert_true(result.replacement_requested == 3, "replacement draw requests the consumed Hand shortfall", failures)
	assert_true(result.replacement_drawn == 3, "replacement draw reports every available replacement", failures)
	assert_true(result.replacement_shortfall == 0, "available replacements report no shortfall", failures)
	assert_true(result.capacity_maximum == 2 and result.capacity_remaining == 1, "replacement draws do not refresh shared Settlement Capacity", failures)
	assert_true(result.events.size() == 5, "the settlement result preserves settlement, trigger, and three replacement events", failures)
	if result.events.size() >= 3:
		assert_true(result.events[0].event_type == "PatternSettled", "PatternSettled precedes Replacement Draw events", failures)
		assert_true(result.events[1].event_type == "SettlementTriggersResolved", "settlement triggers resolve after PatternSettled", failures)
		assert_true(result.events[2].event_type == "TileDrawn", "the first Replacement Draw follows settlement triggers", failures)
	assert_true(zones.size(TileZone.HAND) == 4, "replacement draws restore Hand to the baseline", failures)
	assert_true(zones.size(TileZone.DISCARD) == 3, "settled tiles remain in Discard", failures)
	for tile_instance in replacement_tiles:
		assert_true(zones.contains_in_zone(tile_instance.instance_id, TileZone.HAND), "replacement TileInstances move into Hand", failures)
	for draw_result in result.replacement_draws:
		assert_true(draw_result.events.size() == 1, "each replacement draw emits one event", failures)
		if draw_result.events.size() == 1:
			assert_true(draw_result.events[0].data["source"] == DrawSource.SETTLEMENT_REPLACEMENT, "replacement draw records its explicit DrawSource", failures)
	assert_true(_has_candidate(result.candidates, ["run.tile.replacement.7", "run.tile.replacement.8", "run.tile.replacement.9"]), "Hand is re-evaluated and exposes a candidate formed by replacement tiles", failures)
	assert_true(result.combat_output == combat_output, "the turn result preserves Combat Output", failures)
	var chain_result = turn.resolve_partial_settlement(["run.tile.replacement.7", "run.tile.replacement.8", "run.tile.replacement.9"])
	assert_true(chain_result.status == "CAPACITY_EXHAUSTED", "the shared window capacity ends the settlement chain", failures)
	assert_true(chain_result.settlement_result.is_accepted(), "the second chained Pattern is still resolved before capacity is reported", failures)
	assert_true(chain_result.replacement_drawn == 0, "the exhausted chain performs no unavailable replacement draws", failures)
	assert_true(chain_result.events[0].event_type == "PatternSettled", "the chained settlement event is emitted first", failures)
	var end_result = turn.end_turn()
	assert_true(end_result.combat_output == combat_output, "stable End Turn preserves Combat Output", failures)
	assert_true(end_result.to_dictionary()["combat_output"] == combat_output, "stable End Turn serializes Combat Output", failures)

func test_settled_tile_cannot_be_consumed_again(failures: Array[String]) -> void:
	var registry = _registry([1, 2, 3, 4, 5, 6, 7])
	var zones := TileZoneContainer.new()
	var settled_tiles := _add_hand_tiles(zones, [1, 2, 3, 7], "run.tile.reuse.hand")
	var replacement_tiles := _add_pool_tiles(zones, [4, 5, 6], "run.tile.reuse.replacement")
	var wall := DrawWall.new(zones, DomainRngStreams.new(12).draw_wall)
	wall.initialize()
	zones.reorder(TileZone.DRAW_WALL, _tile_ids(replacement_tiles))
	var window := SettlementWindow.new(PatternEvaluator.new(registry), zones)
	var turn = SettlementTurn.new(window, TileActionService.new(wall, zones), zones, 4)
	window.open()

	var first_result = turn.resolve_partial_settlement(_tile_ids(settled_tiles.slice(0, 3)))
	var hand_before_reuse := _tile_ids(zones.contents(TileZone.HAND))
	var reuse_result = turn.resolve_partial_settlement(_tile_ids(settled_tiles.slice(0, 3)))

	assert_true(first_result.is_completed(), "the first settlement succeeds before reuse is attempted", failures)
	assert_true(reuse_result.status == "SETTLEMENT_REJECTED", "a second settlement attempt is rejected", failures)
	assert_true(reuse_result.settlement_result.status == "TILE_ALREADY_SETTLED", "the rejected attempt explicitly identifies the settled TileInstances", failures)
	assert_true(_tile_ids(zones.contents(TileZone.HAND)) == hand_before_reuse, "rejecting settled TileInstances does not mutate Hand", failures)
	assert_true(reuse_result.replacement_drawn == 0, "a rejected reuse does not perform replacement draws", failures)

func test_exhaustion_is_explicit_and_end_turn_is_idempotent(failures: Array[String]) -> void:
	var registry = _registry([1, 2, 3, 4])
	var zones := TileZoneContainer.new()
	var settled_tiles := _add_hand_tiles(zones, [1, 2, 3, 4], "run.tile.exhaustion.hand")
	var wall := DrawWall.new(zones, DomainRngStreams.new(13).draw_wall)
	wall.initialize()
	var window := SettlementWindow.new(PatternEvaluator.new(registry), zones)
	var turn = SettlementTurn.new(window, TileActionService.new(wall, zones), zones, 4)
	window.open()

	var result = turn.resolve_partial_settlement(_tile_ids(settled_tiles.slice(0, 3)))
	var end_result = turn.end_turn()
	var repeated_end_result = turn.end_turn()

	assert_true(result.is_exhausted(), "an unavailable replacement reports explicit draw exhaustion", failures)
	assert_true(result.replacement_requested == 3 and result.replacement_drawn == 0 and result.replacement_shortfall == 3, "exhaustion reports the complete replacement shortfall", failures)
	assert_true(result.replacement_draws.size() == 1, "the exhausted draw attempt is retained in the result", failures)
	assert_true(zones.size(TileZone.HAND) == 1, "exhaustion leaves the unconsumed Hand tile intact", failures)
	assert_true(zones.size(TileZone.DISCARD) == 3, "exhaustion leaves settled tiles in Discard", failures)
	assert_true(end_result.status == "END_TURN" and end_result.is_stable(), "End Turn reports a stable domain state", failures)
	assert_true(end_result.to_dictionary() == repeated_end_result.to_dictionary(), "repeated End Turn is idempotent", failures)

func test_capacity_exhaustion_defers_remaining_patterns_to_a_later_window(failures: Array[String]) -> void:
	var registry = _registry([1, 2, 3, 4, 5, 6])
	var zones := TileZoneContainer.new()
	var tiles := _add_hand_tiles(zones, [1, 2, 3, 4, 5, 6], "run.tile.capacity")
	var wall := DrawWall.new(zones, DomainRngStreams.new(14).draw_wall)
	wall.initialize()
	var actions := TileActionService.new(wall, zones)
	var window := SettlementWindow.new(PatternEvaluator.new(registry), zones, SettlementCapacity.new(1))
	var first_turn = SettlementTurn.new(window, actions, zones, 6)
	window.open()
	var first = first_turn.resolve_partial_settlement(_tile_ids(tiles.slice(0, 3)))

	assert_true(first.status == "CAPACITY_EXHAUSTED", "capacity exhaustion is a structured turn result", failures)
	assert_true(first.candidates.size() > 0, "remaining Patterns stay visible after capacity exhaustion", failures)
	var candidates_before: int = first.candidates.size()
	first_turn.end_turn()
	var later_turn = SettlementTurn.new(window, actions, zones, 3)
	assert_true(window.open(), "a later legal window can reopen the remaining Patterns", failures)
	var later = later_turn.resolve_partial_settlement(_tile_ids(window.candidates()[0].tile_instances))
	assert_true(later.settlement_result != null and later.settlement_result.is_accepted(), "a later window can settle a previously deferred Pattern", failures)
	assert_true(candidates_before > 0, "the exhaustion fixture retains an observable deferred candidate", failures)

func _has_candidate(candidates: Array, expected_ids: Array[String]) -> bool:
	for candidate in candidates:
		if _tile_ids(candidate.tile_instances) == expected_ids:
			return true
	return false

func _registry(ranks: Array):
	var registry := ContentRegistry.new()
	for rank in ranks:
		registry.register(TileDefinition.new("base.tile.characters.%d" % rank, "characters", rank))
	return registry

func _add_hand_tiles(zones, ranks: Array, id_prefix: String) -> Array:
	var tiles: Array = []
	for rank in ranks:
		var tile := TileInstance.new("%s.%d" % [id_prefix, rank], "base.tile.characters.%d" % rank)
		zones.add(tile, TileZone.HAND)
		tiles.append(tile)
	return tiles

func _add_pool_tiles(zones, ranks: Array, id_prefix: String) -> Array:
	var tiles: Array = []
	for rank in ranks:
		var tile := TileInstance.new("%s.%d" % [id_prefix, rank], "base.tile.characters.%d" % rank)
		zones.add(tile, TileZone.TILE_POOL)
		tiles.append(tile)
	return tiles

func _tile_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile_instance in tiles:
		ids.append(tile_instance.instance_id)
	return ids

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
