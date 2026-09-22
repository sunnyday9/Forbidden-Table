class_name EncounterDefinition
extends "res://src/content/definitions/content_definition.gd"

const NORMAL := "NORMAL"
const ELITE := "ELITE"
const BOSS := "BOSS"
const VALID_KINDS := [NORMAL, ELITE, BOSS]

@export var enemy_ids: Array[String]
@export var encounter_kind: String
@export var battle_values: Dictionary
@export var contamination_config: Dictionary

func _init(
	definition_id: String = "",
	enemies: Array[String] = [],
	kind: String = NORMAL,
	configured_battle_values: Dictionary = {},
	configured_contamination_config: Dictionary = {},
) -> void:
	super(definition_id, enemies)
	enemy_ids = enemies.duplicate()
	encounter_kind = kind
	battle_values = configured_battle_values.duplicate(true)
	contamination_config = configured_contamination_config.duplicate(true)

func definition_type_name() -> String:
	return "EncounterDefinition"

func expected_id_families() -> Array[String]:
	return ["encounter"]

func validate():
	var report = super.validate()
	if enemy_ids.is_empty():
		report.add_issue(_issue("missing_encounter_enemies", "EncounterDefinition must declare at least one Enemy ID."))
	if not VALID_KINDS.has(encounter_kind):
		report.add_issue(_issue("invalid_encounter_kind", "EncounterDefinition must declare a supported kind."))
	return report

func reference_requirements() -> Array[Dictionary]:
	var requirements: Array[Dictionary] = []
	for enemy_id in enemy_ids:
		requirements.append(_reference_requirement(enemy_id, ["EnemyDefinition"], "enemy_ids"))
	return requirements
