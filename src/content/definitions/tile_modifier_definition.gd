class_name TileModifierDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var modifier_kind: String
@export var max_per_tile: int
@export var effects: Array

func _init(
	definition_id: String = "",
	kind: String = "",
	modifier_limit: int = 1,
	modifier_effects: Array = [],
	references: Array[String] = [],
) -> void:
	super(definition_id, references)
	modifier_kind = kind
	max_per_tile = modifier_limit
	effects = modifier_effects.duplicate()

func definition_type_name() -> String:
	return "TileModifierDefinition"

func expected_id_families() -> Array[String]:
	return ["modifier"]

func validate():
	var report = super.validate()
	_required_string(report, modifier_kind, "missing_modifier_kind", "Modifier kind")
	if max_per_tile < 1:
		report.add_issue(_issue("invalid_modifier_limit", "Tile Modifier maximum per TileInstance must be at least one."))
	return report
