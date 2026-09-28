class_name CharacterPassiveDefinition
extends "res://src/content/definitions/content_definition.gd"

const EffectScript = preload("res://src/domain/effects/effect.gd")

const AFTER_COMPLETE_HAND := "AFTER_COMPLETE_HAND"

@export var trigger_id: String
@export var display_name: String
@export var description: String
@export var effects: Array

func _init(
	definition_id: String = "",
	initial_trigger_id: String = "",
	initial_display_name: String = "",
	initial_description: String = "",
	initial_effects: Array = [],
) -> void:
	trigger_id = initial_trigger_id
	display_name = initial_display_name
	description = initial_description
	effects = initial_effects.duplicate()
	super(definition_id)

func definition_type_name() -> String:
	return "CharacterPassiveDefinition"

func expected_id_families() -> Array[String]:
	return ["passive"]

func validate():
	var report = super.validate()
	if trigger_id != AFTER_COMPLETE_HAND:
		report.add_issue(_issue("invalid_character_passive_trigger", "Character Passive must declare a supported gameplay trigger."))
	_required_string(report, display_name, "missing_character_passive_name", "Character Passive name")
	_required_string(report, description, "missing_character_passive_description", "Character Passive description")
	_validate_typed_effects(report, effects, "effects")
	if effects.is_empty():
		report.add_issue(_issue("empty_character_passive_effects", "Character Passive must produce a gameplay effect."))
	return report
