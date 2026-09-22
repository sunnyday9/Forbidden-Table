class_name MoveTileOperation
extends "res://src/domain/effects/effect_operation.gd"

const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")

var instance_id: String
var source_zone: String
var target_zone: String

func _init(tile_instance_id: String, source: String, target: String) -> void:
	super("MoveTile")
	instance_id = tile_instance_id
	source_zone = source
	target_zone = target

func validate(context, _targets: Dictionary) -> String:
	if context == null or context.zones == null:
		return "NO_TILE_ZONES"
	if not TileZoneScript.is_active(source_zone) or not TileZoneScript.is_active(target_zone) or source_zone == target_zone:
		return "INVALID_ZONE"
	if not context.zones.contains_in_zone(instance_id, source_zone):
		return "INVALID_TILE_TARGET"
	var exhaust_reason := _validate_exhaust_permission(context, source_zone)
	if not exhaust_reason.is_empty():
		return exhaust_reason
	if target_zone == TileZoneScript.RESERVE and context.state != null and context.zones.size(target_zone) >= context.state.reserve_capacity:
		return "RESERVE_CAPACITY_REACHED"
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	var moved: bool = context.zones.transfer(instance_id, source_zone, target_zone)
	if not moved:
		return []
	return [_event("TileMoved", {"effect_id": effect_id, "instance_id": instance_id, "source_zone": source_zone, "target_zone": target_zone, "sequence_index": sequence_index})]

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "instance_id": instance_id, "source_zone": source_zone, "target_zone": target_zone}

func _validate_exhaust_permission(context, current_zone: String) -> String:
	if target_zone != TileZoneScript.EXHAUST:
		return ""
	for tile_instance in context.zones.contents(current_zone):
		if tile_instance is TileInstanceScript and tile_instance.instance_id == instance_id and tile_instance.is_contaminated() and not tile_instance.can_exhaust_contamination:
			return "CANNOT_EXHAUST"
	return ""
