class_name TechniqueDefinition
extends "res://src/content/definitions/content_definition.gd"

const ACTIVE := "ACTIVE"
const PASSIVE := "PASSIVE"
const SETTLEMENT := "SETTLEMENT"
const REACTION := "REACTION"
const CORE := "CORE"
const VALID_KINDS := [ACTIVE, PASSIVE, SETTLEMENT, REACTION, CORE]

@export var technique_kind: String
@export var tp_cost: int
@export var effects: Array

func _init(
	definition_id: String = "",
	kind: String = ACTIVE,
	cost: int = 0,
	technique_effects: Array = [],
	references: Array[String] = [],
) -> void:
	super(definition_id, references)
	technique_kind = kind
	tp_cost = cost
	effects = technique_effects.duplicate()

func definition_type_name() -> String:
	return "TechniqueDefinition"

func expected_id_families() -> Array[String]:
	return ["technique"]

func validate():
	var report = super.validate()
	if not VALID_KINDS.has(technique_kind):
		report.add_issue(_issue("invalid_technique_kind", "TechniqueDefinition must declare a supported kind."))
	if tp_cost < 0:
		report.add_issue(_issue("invalid_technique_cost", "TechniqueDefinition TP cost cannot be negative."))
	_validate_typed_effects(report, effects, "effects")
	return report
