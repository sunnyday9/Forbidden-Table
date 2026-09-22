class_name MapDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var node_ids: Array[String]
@export var start_node_id: String
@export var node_definitions: Dictionary
@export var map_version: String

func _init(
	definition_id: String = "",
	nodes: Array[String] = [],
	start_node: String = "",
	definitions: Dictionary = {},
	version: String = "1",
) -> void:
	super(definition_id, nodes)
	node_ids = nodes.duplicate()
	start_node_id = start_node
	node_definitions = definitions.duplicate()
	map_version = version
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
	for issue in graph_issues():
		report.add_issue(_issue(issue["code"], issue["message"], str(issue.get("reference_id", ""))))
	return report

func reference_requirements() -> Array[Dictionary]:
	var requirements: Array[Dictionary] = []
	for node_id in node_ids:
		requirements.append(_reference_requirement(node_id, ["MapNodeDefinition"], "node_ids"))
	return requirements

func node_definition(node_id: String):
	return node_definitions.get(node_id)

func all_edge_ids() -> Array[String]:
	var result: Array[String] = []
	for node_id in node_ids:
		var node = node_definition(node_id)
		if node == null:
			continue
		for edge_id in node.edge_ids:
			result.append(edge_id)
	return result

func outgoing_edges(node_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var node = node_definition(node_id)
	if node == null:
		return result
	for index in node.next_node_ids.size():
		result.append({
			"edge_id": node.edge_ids[index],
			"from_node_id": node_id,
			"to_node_id": node.next_node_ids[index],
		})
	return result

func count_nodes_of_kind(kind: String) -> int:
	var count := 0
	for node_id in node_ids:
		var node = node_definition(node_id)
		if node != null and node.node_kind == kind:
			count += 1
	return count

func branch_decision_count_before(node_id: String) -> int:
	var distances: Dictionary = {start_node_id: 0}
	var queue: Array[String] = [start_node_id]
	while not queue.is_empty():
		var current_id: String = queue.pop_front()
		if current_id == node_id:
			return distances[current_id]
		var node = node_definition(current_id)
		if node == null:
			continue
		for next_node_id in node.next_node_ids:
			if not distances.has(next_node_id):
				distances[next_node_id] = distances[current_id] + (1 if node.next_node_ids.size() > 1 else 0)
				queue.append(next_node_id)
	return -1

func has_route_through(required_node_ids: Array[String], destination_node_id: String) -> bool:
	var required := {}
	for required_node_id in required_node_ids:
		required[required_node_id] = true
	return _find_route(start_node_id, destination_node_id, required, {})

func graph_issues() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if node_definitions.is_empty():
		return issues
	var known_nodes := {}
	for node_id in node_ids:
		known_nodes[node_id] = true
		if not node_definitions.has(node_id):
			issues.append({"code": "missing_map_node_definition", "message": "MapDefinition must provide every authored MapNodeDefinition.", "reference_id": node_id})
	var seen_edges := {}
	for node_id in node_ids:
		var node = node_definition(node_id)
		if node == null:
			continue
		if node.node_kind != "BOSS" and node.next_node_ids.is_empty():
			issues.append({"code": "map_dead_end", "message": "Every non-terminal map node must have a forward edge.", "reference_id": node_id})
		if node.node_kind == "BOSS" and not node.next_node_ids.is_empty():
			issues.append({"code": "boss_has_outgoing_edges", "message": "The Boss must be the only terminal encounter node.", "reference_id": node_id})
		if node.edge_ids.size() != node.next_node_ids.size():
			issues.append({"code": "invalid_map_edges", "message": "Every map edge must have a stable edge ID.", "reference_id": node_id})
		for index in node.next_node_ids.size():
			var next_node_id: String = node.next_node_ids[index]
			if not known_nodes.has(next_node_id):
				issues.append({"code": "missing_map_edge_target", "message": "Map edges must target authored nodes.", "reference_id": next_node_id})
			var edge_id: String = node.edge_ids[index] if index < node.edge_ids.size() else ""
			if edge_id.is_empty() or seen_edges.has(edge_id):
				issues.append({"code": "duplicate_map_edge_id", "message": "Map edge IDs must be unique and non-empty.", "reference_id": edge_id})
			seen_edges[edge_id] = true
	var reachable := _reachable_from(start_node_id)
	for node_id in node_ids:
		if not reachable.has(node_id):
			issues.append({"code": "unreachable_map_node", "message": "Every authored map node must be reachable from the entry point.", "reference_id": node_id})
	var boss_ids: Array[String] = []
	for node_id in node_ids:
		var node = node_definition(node_id)
		if node != null and node.node_kind == "BOSS":
			boss_ids.append(node_id)
	if boss_ids.is_empty():
		issues.append({"code": "missing_map_boss", "message": "An authored map must contain a Boss node."})
	else:
		if boss_ids.size() != 1:
			issues.append({"code": "invalid_map_boss_count", "message": "An authored Mini-Act map must contain exactly one Boss node."})
		var can_reach_boss := _nodes_that_can_reach(boss_ids)
		for node_id in node_ids:
			if not can_reach_boss.has(node_id):
				issues.append({"code": "map_route_dead_end", "message": "Every authored node must have a route to a Boss.", "reference_id": node_id})
	return issues

func _reachable_from(node_id: String) -> Dictionary:
	var reachable := {}
	var queue: Array[String] = [node_id]
	while not queue.is_empty():
		var current_id: String = queue.pop_front()
		if reachable.has(current_id):
			continue
		reachable[current_id] = true
		var node = node_definition(current_id)
		if node == null:
			continue
		for next_node_id in node.next_node_ids:
			queue.append(next_node_id)
	return reachable

func _nodes_that_can_reach(destination_ids: Array[String]) -> Dictionary:
	var result := {}
	var changed := true
	for destination_id in destination_ids:
		result[destination_id] = true
	while changed:
		changed = false
		for node_id in node_ids:
			var node = node_definition(node_id)
			if node == null or result.has(node_id):
				continue
			for next_node_id in node.next_node_ids:
				if result.has(next_node_id):
					result[node_id] = true
					changed = true
					break
	return result

func _find_route(current_id: String, destination_id: String, required: Dictionary, visited: Dictionary) -> bool:
	if visited.has(current_id):
		return false
	visited[current_id] = true
	var remaining := required.duplicate()
	remaining.erase(current_id)
	if current_id == destination_id:
		return remaining.is_empty()
	var node = node_definition(current_id)
	if node == null:
		return false
	for next_node_id in node.next_node_ids:
		if _find_route(next_node_id, destination_id, remaining, visited.duplicate()):
			return true
	return false
