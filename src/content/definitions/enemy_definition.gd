class_name EnemyDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var intent_graph: Variant
@export var role: String
@export var max_hp: int

func _init(definition_id: String = "", graph = null, enemy_role: String = "NORMAL", enemy_max_hp: int = 1) -> void:
	super(definition_id)
	intent_graph = graph
	role = enemy_role
	max_hp = enemy_max_hp

func definition_type_name() -> String:
	return "EnemyDefinition"

func expected_id_families() -> Array[String]:
	return ["enemy", "boss"]

func validate():
	var report = super.validate()
	if intent_graph == null or not intent_graph.has_method("validation") or not intent_graph.validation().is_valid():
		report.add_issue(_issue("invalid_intent_graph", "EnemyDefinition must declare a valid Intent Graph."))
	if max_hp < 1:
		report.add_issue(_issue("invalid_enemy_hp", "EnemyDefinition maximum HP must be positive."))
	return report
