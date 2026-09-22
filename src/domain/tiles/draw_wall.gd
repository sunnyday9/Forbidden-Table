class_name DrawWall
extends RefCounted

const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var _zones
var _draw_wall_rng
var _initialized := false

func _init(zones, draw_wall_rng) -> void:
	_zones = zones
	_draw_wall_rng = draw_wall_rng

func initialize() -> bool:
	if _initialized or _zones == null or _draw_wall_rng == null:
		return false

	var tile_pool: Array = _zones.contents(TileZoneScript.TILE_POOL)
	for tile_instance in tile_pool:
		if not _zones.transfer(tile_instance.instance_id, TileZoneScript.TILE_POOL, TileZoneScript.DRAW_WALL):
			return false

	if not _shuffle(TileZoneScript.DRAW_WALL):
		return false
	_initialized = true
	return true

func is_initialized() -> bool:
	return _initialized

func contents() -> Array:
	if not _initialized:
		return []
	return _zones.contents(TileZoneScript.DRAW_WALL)

func size() -> int:
	return contents().size()

func draw_one():
	if not _initialized or size() == 0:
		return null

	var tile_instance = contents()[0]
	if not _zones.transfer(tile_instance.instance_id, TileZoneScript.DRAW_WALL, TileZoneScript.HAND):
		return null
	return tile_instance

func reshuffle_discard() -> bool:
	if not _initialized or _zones == null:
		return false
	var discarded: Array = _zones.contents(TileZoneScript.DISCARD)
	if discarded.is_empty():
		return false
	for tile_instance in discarded:
		if not _zones.transfer(tile_instance.instance_id, TileZoneScript.DISCARD, TileZoneScript.DRAW_WALL):
			return false
	return _shuffle(TileZoneScript.DRAW_WALL)

func _shuffle(zone: String) -> bool:
	var ordered_tiles: Array = _zones.contents(zone)
	for index in range(ordered_tiles.size() - 1, 0, -1):
		var swap_index: int = _draw_wall_rng.next_int(0, index)
		var temporary_tile = ordered_tiles[index]
		ordered_tiles[index] = ordered_tiles[swap_index]
		ordered_tiles[swap_index] = temporary_tile
	return _zones.reorder(zone, _tile_ids(ordered_tiles))

func _tile_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile_instance in tiles:
		ids.append(tile_instance.instance_id)
	return ids
