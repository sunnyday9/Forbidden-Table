class_name RelicDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var effects: Array
@export var active: bool
@export var available_from_act: int

func _init(definition_id: String = "", relic_effects: Array = [], is_active: bool = false, references: Array[String] = [], first_available_act: int = 1) -> void:
	super(definition_id, references)
	effects = relic_effects.duplicate()
	active = is_active
	available_from_act = maxi(1, first_available_act)

func definition_type_name() -> String:
	return "RelicDefinition"

func expected_id_families() -> Array[String]:
	return ["relic"]

func validate():
	var report = super.validate()
	if available_from_act < 1 or available_from_act > 2:
		report.add_issue(_issue("invalid_relic_act_availability", "RelicDefinition Act availability must be Act 1 or Act 2."))
	_validate_typed_effects(report, effects, "effects")
	return report
