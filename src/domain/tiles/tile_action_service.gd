class_name TileActionService
extends RefCounted

const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const DrawActionResultScript = preload("res://src/domain/tiles/draw_action_result.gd")
const DiscardActionResultScript = preload("res://src/domain/tiles/discard_action_result.gd")
const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var _draw_wall
var _zones

func _init(draw_wall, zones) -> void:
	_draw_wall = draw_wall
	_zones = zones

func draw(source: String = DrawSourceScript.NORMAL_ACTION):
	if not DrawSourceScript.is_valid(source):
		return DrawActionResultScript.new(DrawActionResultScript.INVALID_SOURCE, 1, 0, 1)
	if _draw_wall == null or not _draw_wall.is_initialized():
		return DrawActionResultScript.new(DrawActionResultScript.DRAW_WALL_NOT_READY, 1, 0, 1)
	if _draw_wall.size() == 0:
		return DrawActionResultScript.new(DrawActionResultScript.INSUFFICIENT_TILES, 1, 0, 1)

	var tile_instance = _draw_wall.draw_one()
	if tile_instance == null:
		return DrawActionResultScript.new(DrawActionResultScript.TRANSFER_FAILED, 1, 0, 1)

	var event := DomainEventScript.new(DomainEventScript.TILE_DRAWN, {
		"instance_id": tile_instance.instance_id,
		"definition_id": tile_instance.definition_id,
		"source": source,
	})
	return DrawActionResultScript.new(DrawActionResultScript.ACCEPTED, 1, 1, 0, tile_instance, [event])

func discard(instance_id: String):
	if _zones == null or not _zones.contains_in_zone(instance_id, TileZoneScript.HAND):
		return DiscardActionResultScript.new(DiscardActionResultScript.INVALID_TILE)

	var tile_instance = _find_in_hand(instance_id)
	if tile_instance == null:
		return DiscardActionResultScript.new(DiscardActionResultScript.INVALID_TILE)
	if not _zones.transfer(instance_id, TileZoneScript.HAND, TileZoneScript.DISCARD):
		return DiscardActionResultScript.new(DiscardActionResultScript.TRANSFER_FAILED)

	var event := DomainEventScript.new(DomainEventScript.TILE_DISCARDED, {
		"instance_id": tile_instance.instance_id,
		"definition_id": tile_instance.definition_id,
	})
	return DiscardActionResultScript.new(DiscardActionResultScript.ACCEPTED, tile_instance, [event])

func _find_in_hand(instance_id: String):
	for tile_instance in _zones.contents(TileZoneScript.HAND):
		if tile_instance.instance_id == instance_id:
			return tile_instance
	return null
