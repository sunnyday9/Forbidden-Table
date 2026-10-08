class_name InjectContaminationOperation
extends "res://src/domain/effects/effect_operation.gd"

const ContaminationDefinitionScript = preload("res://src/domain/tiles/contamination_definition.gd")
const ContaminationResultScript = preload("res://src/domain/tiles/contamination_result.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var instance_id: String
var tile_definition_id: String
var contamination
var target_zone: String

func _init(tile_instance_id: String, definition_id: String, contamination_definition, destination_zone: String = TileZoneScript.DRAW_WALL) -> void:
	super("InjectContamination")
	instance_id = tile_instance_id
	tile_definition_id = definition_id
	contamination = contamination_definition
	target_zone = destination_zone

func validate(context, _targets: Dictionary) -> String:
	var service = context.resolve_contamination_service() if context != null and context.has_method("resolve_contamination_service") else null
	if service == null:
		return "NO_CONTAMINATION_SERVICE"
	var definition = _definition()
	if definition == null or not definition.is_valid():
		return ContaminationResultScript.INVALID_CONTAMINATION
	if instance_id.is_empty() or tile_definition_id.is_empty():
		return ContaminationResultScript.INVALID_TILE
	if context.zones == null or context.zones.contains(instance_id):
		return ContaminationResultScript.INVALID_TILE
	if not TileZoneScript.all().has(target_zone) or target_zone == TileZoneScript.TILE_POOL:
		return ContaminationResultScript.INVALID_ZONE
	return ""

func hand_addition_demand(_context, _targets: Dictionary) -> int:
	return 1 if target_zone == TileZoneScript.HAND else 0

func apply(context, _targets: Dictionary, sequence_index: int, _effect_id: String) -> Array:
	return context.resolve_contamination_service().inject_contamination(instance_id, tile_definition_id, _definition(), target_zone, sequence_index).events

func to_dictionary() -> Dictionary:
	return {
		"operation_id": operation_id,
		"instance_id": instance_id,
		"tile_definition_id": tile_definition_id,
		"target_zone": target_zone,
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
