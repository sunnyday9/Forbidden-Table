class_name TileActionService
extends RefCounted

const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const DrawActionResultScript = preload("res://src/domain/tiles/draw_action_result.gd")
const DiscardActionResultScript = preload("res://src/domain/tiles/discard_action_result.gd")
const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")
const ReserveServiceScript = preload("res://src/domain/tiles/reserve_service.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var _draw_wall
var _zones
var reserve_service
var _settlement_window

func _init(draw_wall, zones, settlement_window = null) -> void:
	_draw_wall = draw_wall
	_zones = zones
	_settlement_window = settlement_window
	reserve_service = ReserveServiceScript.new(zones)

func set_settlement_window(settlement_window) -> void:
	_settlement_window = settlement_window

func store_to_reserve(instance_id: String):
	var result = reserve_service.store_to_reserve(instance_id)
	_refresh_settlement_checkpoint(result)
	return result

func store(instance_id: String):
	return store_to_reserve(instance_id)

func swap_with_reserve(hand_instance_id: String, reserve_instance_id: String):
	var result = reserve_service.swap(hand_instance_id, reserve_instance_id)
	_refresh_settlement_checkpoint(result)
	return result

func swap(hand_instance_id: String, reserve_instance_id: String):
	return swap_with_reserve(hand_instance_id, reserve_instance_id)

func apply_integrity_loss(instance_id: String, loss):
	return reserve_service.apply_integrity_loss(instance_id, loss)

func repair_integrity(instance_id: String, amount: int):
	return reserve_service.repair_integrity(instance_id, amount)

func natural_decay(amount: int = 1) -> Array:
	return reserve_service.natural_decay(amount)

func end_battle(preserve_run_level: bool = false, preserved_instance_ids: Array = []) -> Array:
	return reserve_service.end_battle(preserve_run_level, preserved_instance_ids)

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

func _refresh_settlement_checkpoint(result) -> void:
	if result == null or not result.is_accepted() or _settlement_window == null:
		return
	if _settlement_window.is_open():
		_settlement_window.refresh()
	else:
		_settlement_window.open()
