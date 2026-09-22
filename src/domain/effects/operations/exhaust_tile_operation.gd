class_name ExhaustTileOperation
extends "res://src/domain/effects/operations/move_tile_operation.gd"

func _init(tile_instance_id: String) -> void:
	super(tile_instance_id, "", TileZoneScript.EXHAUST)
	operation_id = "ExhaustTile"

func validate(context, _targets: Dictionary) -> String:
	if context == null or context.zones == null or not context.zones.contains(instance_id):
		return "INVALID_TILE_TARGET"
	var current_zone: String = context.zones.zone_of(instance_id)
	return "INVALID_ZONE" if current_zone == target_zone or current_zone.is_empty() else ""

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	var current_zone: String = context.zones.zone_of(instance_id)
	if not context.zones.transfer(instance_id, current_zone, target_zone):
		return []
	return [_event("TileExhausted", {"effect_id": effect_id, "instance_id": instance_id, "source_zone": current_zone, "target_zone": target_zone, "sequence_index": sequence_index})]
