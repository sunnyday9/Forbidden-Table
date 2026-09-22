class_name MapNodeDefinition
extends "res://src/content/definitions/content_definition.gd"

const BATTLE := "BATTLE"
const ELITE := "ELITE"
const EVENT := "EVENT"
const SHOP := "SHOP"
const WORKSHOP := "WORKSHOP"
const BOSS := "BOSS"
const VALID_KINDS := [BATTLE, ELITE, EVENT, SHOP, WORKSHOP, BOSS]

@export var node_kind: String
@export var next_node_ids: Array[String]
@export var content_reference_id: String

func _init(
	definition_id: String = "",
	kind: String = BATTLE,
	next_nodes: Array[String] = [],
	content_reference: String = "",
) -> void:
	var references := next_nodes.duplicate()
	if not content_reference.is_empty():
		references.append(content_reference)
	super(definition_id, references)
	node_kind = kind
	next_node_ids = next_nodes.duplicate()
	content_reference_id = content_reference

func definition_type_name() -> String:
	return "MapNodeDefinition"

func expected_id_families() -> Array[String]:
	return ["map_node", "node"]

func validate():
	var report = super.validate()
	if not VALID_KINDS.has(node_kind):
		report.add_issue(_issue("invalid_map_node_kind", "MapNodeDefinition must declare a supported node kind."))
	if node_kind in [BATTLE, ELITE, EVENT, BOSS] and content_reference_id.is_empty():
		report.add_issue(_issue("missing_map_node_content", "Content-bearing MapNodeDefinition must declare a content reference."))
	return report

func reference_requirements() -> Array[Dictionary]:
	var requirements: Array[Dictionary] = []
	for next_node_id in next_node_ids:
		requirements.append(_reference_requirement(next_node_id, ["MapNodeDefinition"], "next_node_ids"))
	if not content_reference_id.is_empty():
		var expected_types: Array[String] = []
		if node_kind in [BATTLE, ELITE, BOSS]:
			expected_types = ["EncounterDefinition"]
		elif node_kind == EVENT:
			expected_types = ["EventDefinition"]
		requirements.append(_reference_requirement(content_reference_id, expected_types, "content_reference_id"))
	return requirements
