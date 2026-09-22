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
@export var payload_options: Array[String]
@export var edge_ids: Array[String]

func _init(
	definition_id: String = "",
	kind: String = BATTLE,
	next_nodes: Array[String] = [],
	content_reference: String = "",
	payloads: Array[String] = [],
	authored_edge_ids: Array[String] = [],
) -> void:
	var references := next_nodes.duplicate()
	if not content_reference.is_empty():
		references.append(content_reference)
	super(definition_id, references)
	node_kind = kind
	next_node_ids = next_nodes.duplicate()
	content_reference_id = content_reference
	payload_options = payloads.duplicate()
	if payload_options.is_empty() and not content_reference.is_empty():
		payload_options.append(content_reference)
	edge_ids = authored_edge_ids.duplicate()
	if edge_ids.is_empty():
		for next_node_id in next_node_ids:
			edge_ids.append(_default_edge_id(next_node_id))

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

func payload_id_for(map_rng) -> String:
	if payload_options.is_empty():
		return content_reference_id
	var payload_index: int = map_rng.next_int(0, payload_options.size() - 1)
	return payload_options[payload_index]

func edge_id_to(next_node_id: String) -> String:
	var next_index := next_node_ids.find(next_node_id)
	return edge_ids[next_index] if next_index >= 0 and next_index < edge_ids.size() else ""

func _default_edge_id(next_node_id: String) -> String:
	return "%s.edge.%s" % [content_id, next_node_id]
