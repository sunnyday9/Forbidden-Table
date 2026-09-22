class_name MapDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var node_ids: Array[String]
@export var start_node_id: String

func _init(definition_id: String = "", nodes: Array[String] = [], start_node: String = "") -> void:
	super(definition_id, nodes)
	node_ids = nodes.duplicate()
	start_node_id = start_node
	if not start_node.is_empty() and not referenced_content_ids.has(start_node):
		referenced_content_ids.append(start_node)

func definition_type_name() -> String:
	return "MapDefinition"

func expected_id_families() -> Array[String]:
	return ["map"]

func validate():
	var report = super.validate()
	if node_ids.is_empty():
		report.add_issue(_issue("missing_map_nodes", "MapDefinition must declare at least one MapNodeDefinition."))
	_required_string(report, start_node_id, "missing_map_start", "Start MapNode ID")
	if not start_node_id.is_empty() and not node_ids.has(start_node_id):
		report.add_issue(_issue("invalid_map_start", "MapDefinition start node must be one of its nodes.", start_node_id))
	return report

func reference_requirements() -> Array[Dictionary]:
	var requirements: Array[Dictionary] = []
	for node_id in node_ids:
		requirements.append(_reference_requirement(node_id, ["MapNodeDefinition"], "node_ids"))
	return requirements
