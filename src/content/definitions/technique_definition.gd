class_name TechniqueDefinition
extends "res://src/content/definitions/content_definition.gd"
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

const ACTIVE := "ACTIVE"
const PASSIVE := "PASSIVE"
const SETTLEMENT := "SETTLEMENT"
const REACTION := "REACTION"
const CORE := "CORE"
const VALID_KINDS := [ACTIVE, PASSIVE, SETTLEMENT, REACTION, CORE]
const REACTION_ENEMY_CONTAMINATION_ADDED := "ENEMY_CONTAMINATION_ADDED"
const REACTION_ENEMY_STABILITY_LOST := "ENEMY_STABILITY_LOST"
const VALID_REACTION_TRIGGERS := [REACTION_ENEMY_CONTAMINATION_ADDED, REACTION_ENEMY_STABILITY_LOST]

@export var technique_kind: String
@export var tp_cost: int
@export var effects: Array
@export var reaction_trigger_id: String

func _init(
	definition_id: String = "",
	kind: String = ACTIVE,
	cost: int = 0,
	technique_effects: Array = [],
	references: Array[String] = [],
	technique_reaction_trigger_id: String = "",
) -> void:
	super(definition_id, references)
	technique_kind = kind
	tp_cost = cost
	effects = technique_effects.duplicate()
	reaction_trigger_id = technique_reaction_trigger_id

func definition_type_name() -> String:
	return "TechniqueDefinition"

func expected_id_families() -> Array[String]:
	return ["technique"]

func validate():
	var report = super.validate()
	if not VALID_KINDS.has(technique_kind):
		report.add_issue(_issue("invalid_technique_kind", LocalizationCatalogScript.text("CONTENT_TECHNIQUE_0001")))
	if tp_cost < 0:
		report.add_issue(_issue("invalid_technique_cost", LocalizationCatalogScript.text("CONTENT_TECHNIQUE_0002")))
	if technique_kind == REACTION and not VALID_REACTION_TRIGGERS.has(reaction_trigger_id):
		report.add_issue(_issue("invalid_reaction_trigger", LocalizationCatalogScript.text("CONTENT_TECHNIQUE_0003")))
	elif technique_kind != REACTION and not reaction_trigger_id.is_empty():
		report.add_issue(_issue("unexpected_reaction_trigger", LocalizationCatalogScript.text("CONTENT_TECHNIQUE_0004")))
	_validate_typed_effects(report, effects, "effects")
	return report

static func reaction_trigger_label(trigger_id: String) -> String:
	match trigger_id:
		REACTION_ENEMY_CONTAMINATION_ADDED:
			return LocalizationCatalogScript.canonical_text("CONTENT_TECHNIQUE_0005")
		REACTION_ENEMY_STABILITY_LOST:
			return LocalizationCatalogScript.canonical_text("CONTENT_TECHNIQUE_0006")
		_:
			return LocalizationCatalogScript.canonical_text("CONTENT_TECHNIQUE_0007")
