class_name RuleBreakerDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var rule_key: String
@export var permission_level: int
@export var effects: Array

func _init(
	definition_id: String = "",
	breaker_rule_key: String = "",
	breaker_permission_level: int = 0,
	breaker_effects: Array = [],
	references: Array[String] = [],
) -> void:
	super(definition_id, references)
	rule_key = breaker_rule_key
	permission_level = breaker_permission_level
	effects = breaker_effects.duplicate()

func definition_type_name() -> String:
	return "RuleBreakerDefinition"

func expected_id_families() -> Array[String]:
	return ["rule_breaker"]

func validate():
	var report = super.validate()
	_required_string(report, rule_key, "missing_rule_key", "Rule Breaker rule key")
	if permission_level < 1:
		report.add_issue(_issue("invalid_permission_level", "Rule Breaker permission level must be positive."))
	_validate_typed_effects(report, effects, "effects")
	return report
