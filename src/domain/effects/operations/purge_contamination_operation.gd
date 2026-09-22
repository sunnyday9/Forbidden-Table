class_name PurgeContaminationOperation
extends "res://src/domain/effects/effect_operation.gd"

const ContaminationResultScript = preload("res://src/domain/tiles/contamination_result.gd")

var instance_id: String

func _init(tile_instance_id: String) -> void:
	super("PurgeContamination")
	instance_id = tile_instance_id

func validate(context, _targets: Dictionary) -> String:
	var service = context.resolve_contamination_service() if context != null and context.has_method("resolve_contamination_service") else null
	if service == null:
		return "NO_CONTAMINATION_SERVICE"
	var tile = service.observe(instance_id)
	if tile == null:
		return ContaminationResultScript.INVALID_TILE
	if not tile.can_purge_contamination:
		return ContaminationResultScript.CANNOT_PURGE
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, _effect_id: String) -> Array:
	return context.resolve_contamination_service().purge_contamination(instance_id, sequence_index).events

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "instance_id": instance_id}
