class_name ApplyContaminationOperation
extends "res://src/domain/effects/effect_operation.gd"

const ContaminationDefinitionScript = preload("res://src/domain/tiles/contamination_definition.gd")
const ContaminationResultScript = preload("res://src/domain/tiles/contamination_result.gd")

var instance_id: String
var contamination

func _init(tile_instance_id: String, contamination_definition) -> void:
	super("ApplyContamination")
	instance_id = tile_instance_id
	contamination = contamination_definition

func validate(context, _targets: Dictionary) -> String:
	var service = context.resolve_contamination_service() if context != null and context.has_method("resolve_contamination_service") else null
	if service == null:
		return "NO_CONTAMINATION_SERVICE"
	var definition = _definition()
	if definition == null or not definition.is_valid():
		return ContaminationResultScript.INVALID_CONTAMINATION
	if service.observe(instance_id) != null:
		return ContaminationResultScript.ALREADY_CONTAMINATED
	if context.zones == null or not context.zones.contains(instance_id):
		return ContaminationResultScript.INVALID_TILE
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, _effect_id: String) -> Array:
	var result = context.resolve_contamination_service().apply_contamination(instance_id, _definition(), sequence_index)
	return result.events

func to_dictionary() -> Dictionary:
	return {
		"operation_id": operation_id,
		"instance_id": instance_id,
		"contamination": _definition().to_dictionary() if _definition() != null else contamination,
	}

func _definition():
	if contamination is ContaminationDefinitionScript:
		return contamination
	if contamination is Dictionary:
		return ContaminationDefinitionScript.from_dictionary(contamination)
	if contamination is String and not contamination.is_empty():
		return ContaminationDefinitionScript.new(contamination)
	return null
