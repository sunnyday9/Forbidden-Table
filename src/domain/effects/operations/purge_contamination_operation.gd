class_name PurgeContaminationOperation
extends "res://src/domain/effects/effect_operation.gd"

const ContaminationResultScript = preload("res://src/domain/tiles/contamination_result.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var instance_id: String

func _init(tile_instance_id: String) -> void:
	super("PurgeContamination")
	instance_id = tile_instance_id

func validate(context, _targets: Dictionary) -> String:
	var service = context.resolve_contamination_service() if context != null and context.has_method("resolve_contamination_service") else null
	if service == null:
		return "NO_CONTAMINATION_SERVICE"
	var resolved_instance_id := _resolved_instance_id(context, service)
	if resolved_instance_id.is_empty():
		return "NO_PURGE_TARGET"
	var tile = service.observe(resolved_instance_id)
	if tile == null:
		if instance_id.is_empty() and context != null and str(context.get("target_instance_id")) == resolved_instance_id and context.zones != null and context.zones.contains(resolved_instance_id):
			return "NO_PURGE_TARGET"
		return ContaminationResultScript.INVALID_TILE
	if not tile.can_purge_contamination:
		if instance_id.is_empty() and context != null and str(context.get("target_instance_id")) == resolved_instance_id:
			return "NO_PURGE_TARGET"
		return ContaminationResultScript.CANNOT_PURGE
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, _effect_id: String) -> Array:
	var service = context.resolve_contamination_service()
	var resolved_instance_id := _resolved_instance_id(context, service)
	return service.purge_contamination(resolved_instance_id, sequence_index).events

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "instance_id": instance_id}

func _resolved_instance_id(context, service) -> String:
	if not instance_id.is_empty():
		return instance_id
	if context != null and not str(context.get("target_instance_id")).is_empty():
		return str(context.get("target_instance_id"))
	if context == null or context.zones == null or service == null:
		return ""
	var candidates: Array[String] = []
	for zone in TileZoneScript.all():
		for tile in context.zones.contents(zone):
			if tile != null and tile.can_purge_contamination and service.observe(tile.instance_id) != null:
				candidates.append(tile.instance_id)
	candidates.sort()
	return candidates[0] if not candidates.is_empty() else ""
