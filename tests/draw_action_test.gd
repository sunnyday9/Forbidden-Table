class_name DrawActionTest
extends RefCounted

const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const TileActionService = preload("res://src/domain/tiles/tile_action_service.gd")
const DrawActionResult = preload("res://src/domain/tiles/draw_action_result.gd")
const DiscardActionResult = preload("res://src/domain/tiles/discard_action_result.gd")
const DrawSource = preload("res://src/domain/tiles/draw_source.gd")
const DrawWall = preload("res://src/domain/tiles/draw_wall.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_fixed_seed_repeats_draw_wall_order(failures)
	test_draw_moves_one_tile_to_hand_and_emits_event(failures)
	test_discard_moves_selected_hand_tile_and_emits_event(failures)
	test_insufficient_draw_is_explicit_and_atomic(failures)
	test_invalid_discard_is_explicit_and_atomic(failures)
	return failures

func test_fixed_seed_repeats_draw_wall_order(failures: Array[String]) -> void:
	var first = _create_wall(90210)
	var second = _create_wall(90210)
	var first_order := _tile_ids(first.contents())
	var second_order := _tile_ids(second.contents())

	assert_true(first_order == second_order, "a fixed seed produces the same Draw Wall order", failures)
	assert_true(first_order.size() == 5, "Draw Wall setup keeps every TileInstance", failures)
	assert_true(first_order.has("run.tile.001"), "Draw Wall keeps the first stable TileInstance", failures)
	assert_true(first_order.has("run.tile.005"), "Draw Wall keeps the last stable TileInstance", failures)

func test_draw_moves_one_tile_to_hand_and_emits_event(failures: Array[String]) -> void:
	var zones = TileZoneContainer.new()
	var first_tile = TileInstance.new("run.tile.draw.001", "base.tile.man.1")
	var second_tile = TileInstance.new("run.tile.draw.002", "base.tile.man.2")
	zones.add(first_tile, TileZone.TILE_POOL)
	zones.add(second_tile, TileZone.TILE_POOL)
	var wall = DrawWall.new(zones, DomainRngStreams.new(1).draw_wall)
	wall.initialize()
	var actions = TileActionService.new(wall, zones)

	var result = actions.draw(DrawSource.NORMAL_ACTION)

	assert_true(result.status == DrawActionResult.ACCEPTED, "a draw action is accepted when the Draw Wall has a tile", failures)
	assert_true(result.requested == 1 and result.drawn == 1 and result.shortfall == 0, "an accepted draw reports one drawn tile and no shortfall", failures)
	assert_true(result.tile_instance != null, "an accepted draw reports the drawn TileInstance", failures)
	if result.tile_instance != null:
		assert_true(zones.contains_in_zone(result.tile_instance.instance_id, TileZone.HAND), "drawing transfers the TileInstance to Hand", failures)
	assert_true(zones.size(TileZone.DRAW_WALL) == 1, "drawing removes one TileInstance from Draw Wall", failures)
	assert_true(result.events.size() == 1, "an accepted draw emits one domain event", failures)
	assert_true(result.events[0].event_type == "TileDrawn", "the draw event is auditable as TileDrawn", failures)
	assert_true(result.events[0].data["source"] == DrawSource.NORMAL_ACTION, "the draw event records its DrawSource", failures)

func test_discard_moves_selected_hand_tile_and_emits_event(failures: Array[String]) -> void:
	var zones = TileZoneContainer.new()
	var tile = TileInstance.new("run.tile.discard.001", "base.tile.man.5")
	zones.add(tile, TileZone.HAND)
	var actions = TileActionService.new(null, zones)

	var result = actions.discard(tile.instance_id)

	assert_true(result.status == DiscardActionResult.ACCEPTED, "a hand TileInstance can be discarded", failures)
	assert_true(zones.contains_in_zone(tile.instance_id, TileZone.DISCARD), "discarding transfers the selected TileInstance to Discard", failures)
	assert_true(zones.size(TileZone.HAND) == 0, "discarding removes the selected TileInstance from Hand", failures)
	assert_true(result.events.size() == 1, "an accepted discard emits one domain event", failures)
	assert_true(result.events[0].event_type == "TileDiscarded", "the discard event is auditable as TileDiscarded", failures)
	assert_true(result.events[0].data["instance_id"] == tile.instance_id, "the discard event records the selected instance", failures)

func test_insufficient_draw_is_explicit_and_atomic(failures: Array[String]) -> void:
	var zones = TileZoneContainer.new()
	var hand_tile = TileInstance.new("run.tile.existing.hand", "base.tile.man.5")
	zones.add(hand_tile, TileZone.HAND)
	var wall = DrawWall.new(zones, DomainRngStreams.new(2).draw_wall)
	wall.initialize()
	var actions = TileActionService.new(wall, zones)

	var result = actions.draw(DrawSource.NORMAL_ACTION)

	assert_true(result.status == DrawActionResult.INSUFFICIENT_TILES, "an empty Draw Wall returns an explicit insufficient result", failures)
	assert_true(result.requested == 1 and result.drawn == 0 and result.shortfall == 1, "an insufficient draw reports its shortfall", failures)
	assert_true(result.events.size() >= 1, "a Starvation draw emits a causal state event", failures)
	assert_true(zones.size(TileZone.HAND) == 1, "an insufficient draw leaves Hand unchanged", failures)
	assert_true(zones.size(TileZone.DRAW_WALL) == 0, "an insufficient draw leaves Draw Wall unchanged", failures)

func test_invalid_discard_is_explicit_and_atomic(failures: Array[String]) -> void:
	var zones = TileZoneContainer.new()
	var hand_tile = TileInstance.new("run.tile.valid.hand", "base.tile.man.5")
	var wall_tile = TileInstance.new("run.tile.valid.wall", "base.tile.man.6")
	zones.add(hand_tile, TileZone.HAND)
	zones.add(wall_tile, TileZone.DRAW_WALL)
	var actions = TileActionService.new(null, zones)

	var result = actions.discard(wall_tile.instance_id)

	assert_true(result.status == DiscardActionResult.INVALID_TILE, "discarding a non-Hand TileInstance returns an explicit invalid result", failures)
	assert_true(result.events.is_empty(), "an invalid discard emits no accepted-action event", failures)
	assert_true(zones.contains_in_zone(wall_tile.instance_id, TileZone.DRAW_WALL), "an invalid discard leaves the selected TileInstance unchanged", failures)
	assert_true(zones.contains_in_zone(hand_tile.instance_id, TileZone.HAND), "an invalid discard leaves Hand unchanged", failures)

func _create_wall(seed: int):
	var zones = TileZoneContainer.new()
	for index in range(1, 6):
		zones.add(TileInstance.new("run.tile.%03d" % index, "base.tile.man.%d" % index), TileZone.TILE_POOL)
	var wall = DrawWall.new(zones, DomainRngStreams.new(seed).draw_wall)
	wall.initialize()
	return wall

func _tile_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile in tiles:
		ids.append(tile.instance_id)
	return ids

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
