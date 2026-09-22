class_name RelicDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var effects: Array
@export var active: bool

func _init(definition_id: String = "", relic_effects: Array = [], is_active: bool = false, references: Array[String] = []) -> void:
	super(definition_id, references)
	effects = relic_effects.duplicate()
	active = is_active

func definition_type_name() -> String:
	return "RelicDefinition"

func expected_id_families() -> Array[String]:
	return ["relic"]

func validate():
	var report = super.validate()
	_validate_typed_effects(report, effects, "effects")
	return report
