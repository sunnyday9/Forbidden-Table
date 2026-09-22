class_name AtomicReserveSwapOperation
extends "res://src/domain/effects/effect_operation.gd"

const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var hand_instance_id: String
var reserve_instance_id: String

func _init(hand_tile_id: String, reserve_tile_id: String) -> void:
	super("AtomicReserveSwap")
	hand_instance_id = hand_tile_id
	reserve_instance_id = reserve_tile_id

func validate(context, _targets: Dictionary) -> String:
	if context == null or context.zones == null:
		return "NO_TILE_ZONES"
	if not context.zones.contains_in_zone(hand_instance_id, TileZoneScript.HAND):
		return "INVALID_HAND_TILE"
	if not context.zones.contains_in_zone(reserve_instance_id, TileZoneScript.RESERVE):
		return "INVALID_RESERVE_TILE"
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	if not context.zones.swap(hand_instance_id, reserve_instance_id):
		return []
	return [_event("ReserveSwapped", {"effect_id": effect_id, "operation": operation_id, "hand_instance_id": hand_instance_id, "reserve_instance_id": reserve_instance_id, "sequence_index": sequence_index})]

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "hand_instance_id": hand_instance_id, "reserve_instance_id": reserve_instance_id}
