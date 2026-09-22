class_name EnemyDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var intent_graph: Variant
@export var role: String
@export var max_hp: int
@export var enemy_identity: String
@export var battle_values: Dictionary
@export var contamination_config: Dictionary
@export var boss_phases: Array

const NORMAL := "NORMAL"
const ELITE := "ELITE"
const BOSS := "BOSS"
const VALID_ROLES := [NORMAL, ELITE, BOSS]

func _init(
	definition_id: String = "",
	graph = null,
	enemy_role: String = NORMAL,
	enemy_max_hp: int = 1,
	configured_battle_values: Dictionary = {},
	configured_contamination_config: Dictionary = {},
	configured_boss_phases: Array = [],
) -> void:
	super(definition_id)
	intent_graph = graph
	role = enemy_role
	max_hp = enemy_max_hp
	enemy_identity = definition_id
	battle_values = configured_battle_values.duplicate(true)
	contamination_config = configured_contamination_config.duplicate(true)
	boss_phases = configured_boss_phases.duplicate(true)

func definition_type_name() -> String:
	return "EnemyDefinition"

func expected_id_families() -> Array[String]:
	return ["enemy", "boss"]

func validate():
	var report = super.validate()
	if not VALID_ROLES.has(role):
		report.add_issue(_issue("invalid_enemy_role", "EnemyDefinition must declare a supported role."))
	if intent_graph == null or not intent_graph.has_method("validation") or not intent_graph.validation().is_valid():
		report.add_issue(_issue("invalid_intent_graph", "EnemyDefinition must declare a valid Intent Graph."))
	if max_hp < 1:
		report.add_issue(_issue("invalid_enemy_hp", "EnemyDefinition maximum HP must be positive."))
	if role == BOSS:
		_validate_boss_phases(report)
	return report

func _validate_boss_phases(report) -> void:
	if boss_phases.size() < 3:
		report.add_issue(_issue("invalid_boss_phases", "Boss EnemyDefinition must declare at least three public phases."))
		return
	var phase_ids: Dictionary = {}
	for phase in boss_phases:
		if not phase is Dictionary:
			report.add_issue(_issue("invalid_boss_phase", "Boss phases must be dictionaries."))
			continue
		var phase_id := str(phase.get("phase_id", ""))
		var phase_graph = phase.get("intent_graph")
		var phase_max_hp := int(phase.get("max_hp", 0))
		var phase_pressure_limit := int(phase.get("pressure_limit", 0))
		if phase_id.is_empty() or phase_ids.has(phase_id):
			report.add_issue(_issue("invalid_boss_phase_id", "Boss phase IDs must be unique and non-empty.", phase_id))
		else:
			phase_ids[phase_id] = true
		if phase_graph == null or not phase_graph.has_method("validation") or not phase_graph.validation().is_valid():
			report.add_issue(_issue("invalid_boss_phase_graph", "Each Boss phase must declare a valid Intent Graph.", phase_id))
		if phase_max_hp < 1:
			report.add_issue(_issue("invalid_boss_phase_hp", "Each Boss phase maximum HP must be positive.", phase_id))
		if phase_pressure_limit < 1:
			report.add_issue(_issue("invalid_boss_phase_pressure", "Each Boss phase Pressure limit must be positive.", phase_id))
		if int(phase.get("pressure_relief", 0)) < 0:
			report.add_issue(_issue("invalid_boss_phase_relief", "Boss phase Pressure relief cannot be negative.", phase_id))
