class_name CharacterDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var starting_tile_pool_bias: Array[String]
@export var starting_relic_id: String
@export var core_technique_id: String
@export var signature_passive_id: String

func _init(
	definition_id: String = "",
	tile_pool_bias: Array[String] = [],
	starting_relic: String = "",
	core_technique: String = "",
	signature_passive: String = "",
	additional_references: Array[String] = [],
) -> void:
	starting_tile_pool_bias = tile_pool_bias.duplicate()
	starting_relic_id = starting_relic
	core_technique_id = core_technique
	signature_passive_id = signature_passive
	var references := additional_references.duplicate()
	references.append_array(starting_tile_pool_bias)
	for reference_id in [starting_relic_id, core_technique_id, signature_passive_id]:
		if not reference_id.is_empty():
			references.append(reference_id)
	super(definition_id, references)

func definition_type_name() -> String:
	return "CharacterDefinition"

func expected_id_families() -> Array[String]:
	return ["character"]

func validate():
	var report = super.validate()
	if starting_tile_pool_bias.is_empty():
		report.add_issue(_issue("missing_tile_pool_bias", "CharacterDefinition must declare a starting Tile Pool bias."))
	_required_string(report, starting_relic_id, "missing_starting_relic", "Starting Relic ID")
	_required_string(report, core_technique_id, "missing_core_technique", "Core Technique ID")
	if signature_passive_id.is_empty():
		report.add_issue(_issue("missing_signature_passive", "CharacterDefinition must declare a Signature Passive ID."))
	return report

func reference_requirements() -> Array[Dictionary]:
	var requirements: Array[Dictionary] = []
	for tile_id in starting_tile_pool_bias:
		requirements.append(_reference_requirement(tile_id, ["TileDefinition"], "starting_tile_pool_bias"))
	requirements.append(_reference_requirement(starting_relic_id, ["RelicDefinition"], "starting_relic_id"))
	requirements.append(_reference_requirement(core_technique_id, ["TechniqueDefinition"], "core_technique_id"))
	# Phase 2 passives are catalog placeholders represented by ContentDefinition;
	# Alpha-authored passives use the typed effect definition.
	var passive_types: Array[String] = ["CharacterPassiveDefinition", "ContentDefinition"]
	if signature_passive_id.begins_with("alpha.passive."):
		passive_types = ["CharacterPassiveDefinition"]
	requirements.append(_reference_requirement(signature_passive_id, passive_types, "signature_passive_id"))
	return requirements
