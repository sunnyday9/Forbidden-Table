class_name ExhaustContaminationOperation
extends "res://src/domain/effects/operations/purge_contamination_operation.gd"

func _init(tile_instance_id: String) -> void:
	super(tile_instance_id)
	operation_id = "ExhaustContamination"

func validate(context, _targets: Dictionary) -> String:
	var service = context.resolve_contamination_service() if context != null and context.has_method("resolve_contamination_service") else null
	if service == null:
		return "NO_CONTAMINATION_SERVICE"
	var tile = service.observe(instance_id)
	if tile == null:
		return "INVALID_TILE"
	if not tile.can_exhaust_contamination:
		return "CANNOT_EXHAUST"
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, _effect_id: String) -> Array:
	return context.resolve_contamination_service().exhaust_contamination(instance_id, sequence_index).events
