class_name TileZoneTest
extends RefCounted

const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_tile_instances_keep_unique_stable_ids(failures)
	test_zone_vocabulary_matches_domain_language(failures)
	test_tile_can_be_added_to_tile_pool(failures)
	test_duplicate_instance_ids_are_rejected(failures)
	test_tile_transfer_updates_both_zone_contents(failures)
	test_tile_can_move_through_all_four_zones(failures)
	test_invalid_transfers_leave_zone_contents_unchanged(failures)
	test_invalid_tiles_and_zones_are_rejected(failures)
	return failures

func test_tile_instances_keep_unique_stable_ids(failures: Array[String]) -> void:
	var first = TileInstance.new("run.tile.001", "base.tile.man.5")
	var second = TileInstance.new("run.tile.002", "base.tile.man.5")

	assert_true(first.instance_id == "run.tile.001", "a TileInstance exposes its stable instance ID", failures)
	assert_true(second.instance_id == "run.tile.002", "each TileInstance keeps the ID it was created with", failures)
	assert_true(first.instance_id != second.instance_id, "separately created TileInstances have unique IDs", failures)
	assert_true(first.definition_id == "base.tile.man.5", "a TileInstance stores a definition ID instead of mutating a definition", failures)

func test_zone_vocabulary_matches_domain_language(failures: Array[String]) -> void:
	assert_true(
		TileZone.all() == [TileZone.TILE_POOL, TileZone.DRAW_WALL, TileZone.HAND, TileZone.DISCARD, TileZone.RESERVE, TileZone.EXHAUST],
		"the zone vocabulary contains circulation, Reserve, and Exhaust zones",
		failures
	)

func test_tile_can_be_added_to_tile_pool(failures: Array[String]) -> void:
	var zones = TileZoneContainer.new()
	var tile = TileInstance.new("run.tile.003", "base.tile.man.5")

	var added: bool = zones.add(tile, TileZone.TILE_POOL)

	assert_true(added, "a valid TileInstance can be added to the Tile Pool", failures)
	assert_true(zones.contents(TileZone.TILE_POOL).size() == 1, "the Tile Pool exposes its contents after an add", failures)
	assert_true(zones.contents(TileZone.TILE_POOL)[0].instance_id == "run.tile.003", "the Tile Pool exposes the added TileInstance", failures)

func test_duplicate_instance_ids_are_rejected(failures: Array[String]) -> void:
	var zones = TileZoneContainer.new()
	var first = TileInstance.new("run.tile.duplicate", "base.tile.man.5")
	var duplicate = TileInstance.new("run.tile.duplicate", "base.tile.man.6")

	assert_true(zones.add(first, TileZone.TILE_POOL), "the first TileInstance with an ID is accepted", failures)
	assert_true(not zones.add(duplicate, TileZone.HAND), "a duplicate TileInstance ID is rejected", failures)
	assert_true(zones.size(TileZone.TILE_POOL) == 1, "duplicate rejection keeps the original zone contents", failures)
	assert_true(zones.size(TileZone.HAND) == 0, "duplicate rejection does not add to the target zone", failures)
	assert_true(zones.zone_of("run.tile.duplicate") == TileZone.TILE_POOL, "the first owner remains authoritative after duplicate rejection", failures)

func test_tile_transfer_updates_both_zone_contents(failures: Array[String]) -> void:
	var zones = TileZoneContainer.new()
	var tile = TileInstance.new("run.tile.transfer", "base.tile.man.5")
	zones.add(tile, TileZone.TILE_POOL)

	var transferred: bool = zones.transfer("run.tile.transfer", TileZone.TILE_POOL, TileZone.DRAW_WALL)

	assert_true(transferred, "a tile can transfer from Tile Pool to Draw Wall", failures)
	assert_true(zones.contents(TileZone.TILE_POOL).is_empty(), "successful transfer removes the tile from its source", failures)
	assert_true(zones.contents(TileZone.DRAW_WALL).size() == 1, "successful transfer adds the tile to its target", failures)
	assert_true(zones.contains_in_zone("run.tile.transfer", TileZone.DRAW_WALL), "successful transfer reports the new owner", failures)
	assert_true(not zones.contains_in_zone("run.tile.transfer", TileZone.TILE_POOL), "successful transfer reports no source ownership", failures)

func test_tile_can_move_through_all_four_zones(failures: Array[String]) -> void:
	var zones = TileZoneContainer.new()
	var tile = TileInstance.new("run.tile.circulation", "base.tile.man.5")
	zones.add(tile, TileZone.TILE_POOL)

	var to_wall: bool = zones.transfer("run.tile.circulation", TileZone.TILE_POOL, TileZone.DRAW_WALL)
	var to_hand: bool = zones.transfer("run.tile.circulation", TileZone.DRAW_WALL, TileZone.HAND)
	var to_discard: bool = zones.transfer("run.tile.circulation", TileZone.HAND, TileZone.DISCARD)

	assert_true(to_wall and to_hand and to_discard, "a TileInstance can circulate through every Stage 0 zone", failures)
	assert_true(zones.size(TileZone.TILE_POOL) == 0, "the circulated tile is no longer in Tile Pool", failures)
	assert_true(zones.size(TileZone.DRAW_WALL) == 0, "the circulated tile is no longer in Draw Wall", failures)
	assert_true(zones.size(TileZone.HAND) == 0, "the circulated tile is no longer in Hand", failures)
	assert_true(zones.size(TileZone.DISCARD) == 1, "the circulated tile ends in Discard", failures)

func test_invalid_tiles_and_zones_are_rejected(failures: Array[String]) -> void:
	var zones = TileZoneContainer.new()
	var missing_instance_id = TileInstance.new("", "base.tile.man.5")
	var missing_definition_id = TileInstance.new("run.tile.missing_definition", "")
	var valid_tile = TileInstance.new("run.tile.valid", "base.tile.man.5")

	assert_true(not zones.add(missing_instance_id, TileZone.TILE_POOL), "a TileInstance without an instance ID is rejected", failures)
	assert_true(not zones.add(missing_definition_id, TileZone.TILE_POOL), "a TileInstance without a definition ID is rejected", failures)
	assert_true(not zones.add(valid_tile, "Unknown Zone"), "adding to an unknown zone is rejected", failures)
	assert_true(zones.size(TileZone.TILE_POOL) == 0, "rejected additions leave all zone contents unchanged", failures)

func test_invalid_transfers_leave_zone_contents_unchanged(failures: Array[String]) -> void:
	var zones = TileZoneContainer.new()
	var tile = TileInstance.new("run.tile.invalid", "base.tile.man.5")
	zones.add(tile, TileZone.HAND)

	var wrong_source: bool = zones.transfer("run.tile.invalid", TileZone.DRAW_WALL, TileZone.DISCARD)
	var invalid_target: bool = zones.transfer("run.tile.invalid", TileZone.HAND, "Unknown Zone")
	var unknown_tile: bool = zones.transfer("run.tile.missing", TileZone.HAND, TileZone.DISCARD)

	assert_true(not wrong_source, "a transfer with invalid source membership is rejected", failures)
	assert_true(not invalid_target, "a transfer with an invalid target zone is rejected", failures)
	assert_true(not unknown_tile, "a transfer for an unknown TileInstance is rejected", failures)
	assert_true(zones.size(TileZone.HAND) == 1, "rejected transfers leave the source contents unchanged", failures)
	assert_true(zones.size(TileZone.DRAW_WALL) == 0, "rejected transfers do not populate an unrelated zone", failures)
	assert_true(zones.size(TileZone.DISCARD) == 0, "rejected transfers do not populate the requested target", failures)
	assert_true(zones.zone_of("run.tile.invalid") == TileZone.HAND, "rejected transfers leave ownership unchanged", failures)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
