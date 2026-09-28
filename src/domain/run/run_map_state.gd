class_name RunMapState
extends RefCounted

const MapDefinitionScript = preload("res://src/content/definitions/map_definition.gd")

const EXACT := "EXACT"
const PARTIAL := "PARTIAL"

var map_definition_id: String
var map_version: String
var node_ids: Array[String]
var edge_ids: Array[String]
var node_kinds: Dictionary
var payload_ids: Dictionary
var knowledge_state: Dictionary
var current_node_id: String
var visited_node_ids: Array[String]
var ordered_path: Array[String]
var path_edge_ids: Array[String]
var map_rng_state: Dictionary
var last_events: Array

func _init(
	initial_map_definition_id: String = "",
	initial_current_node_id: String = "",
	initial_visited_node_ids: Array[String] = [],
	initial_ordered_path: Array[String] = [],
) -> void:
	map_definition_id = initial_map_definition_id
	map_version = ""
	node_ids = []
	edge_ids = []
	node_kinds = {}
	payload_ids = {}
	knowledge_state = {}
	current_node_id = initial_current_node_id
	visited_node_ids = initial_visited_node_ids.duplicate()
	ordered_path = initial_ordered_path.duplicate()
	path_edge_ids = []
	map_rng_state = {}
	last_events = []

func initialize(definition, map_rng) -> void:
	assert(definition is MapDefinitionScript)
	map_definition_id = definition.content_id
	map_version = definition.map_version
	node_ids = definition.node_ids.duplicate()
	edge_ids = definition.all_edge_ids()
	node_kinds = {}
	payload_ids = {}
	for node_id in node_ids:
		var node = definition.node_definition(node_id)
		node_kinds[node_id] = node.node_kind
		payload_ids[node_id] = node.payload_id_for(map_rng)
	current_node_id = definition.start_node_id
	visited_node_ids = []
	ordered_path = []
	path_edge_ids = []
	last_events = []
	_refresh_knowledge(definition)
	map_rng_state = map_rng.snapshot()

func is_initialized() -> bool:
	return not map_definition_id.is_empty() and not current_node_id.is_empty()

func is_visited(node_id: String) -> bool:
	return visited_node_ids.has(node_id)

func is_terminal() -> bool:
	return node_kinds.get(current_node_id, "") == "BOSS"

func is_pending_entry(definition) -> bool:
	return (
		current_node_id == definition.start_node_id
		and visited_node_ids.is_empty()
		and ordered_path.is_empty()
	)

func selectable_node_ids(definition) -> Array[String]:
	var selectable: Array[String] = []
	if is_pending_entry(definition):
		selectable.append(current_node_id)
		return selectable
	var node = definition.node_definition(current_node_id)
	if node == null:
		return selectable
	for next_node_id in node.next_node_ids:
		if not is_visited(next_node_id):
			selectable.append(next_node_id)
	return selectable

func is_adjacent(node_id: String, definition) -> bool:
	return selectable_node_ids(definition).has(node_id)

func visible_payload_id(node_id: String) -> String:
	return str(payload_ids.get(node_id, "")) if knowledge_state.get(node_id, PARTIAL) == EXACT else ""

func edge_id_to(node_id: String, definition) -> String:
	var node = definition.node_definition(current_node_id)
	return node.edge_id_to(node_id) if node != null else ""

func select_node(node_id: String, definition) -> String:
	var edge_id := edge_id_to(node_id, definition)
	current_node_id = node_id
	visited_node_ids.append(node_id)
	ordered_path.append(node_id)
	if not edge_id.is_empty():
		path_edge_ids.append(edge_id)
	_refresh_knowledge(definition)
	return edge_id

func _refresh_knowledge(definition) -> void:
	knowledge_state = {}
	for node_id in node_ids:
		knowledge_state[node_id] = PARTIAL
	if current_node_id.is_empty():
		return
	knowledge_state[current_node_id] = EXACT
	var current_node = definition.node_definition(current_node_id)
	if current_node == null:
		return
	for next_node_id in current_node.next_node_ids:
		knowledge_state[next_node_id] = EXACT

func to_dictionary() -> Dictionary:
	return {
		"map_definition_id": map_definition_id,
		"map_version": map_version,
		"node_ids": node_ids.duplicate(),
		"edge_ids": edge_ids.duplicate(),
		"node_kinds": node_kinds.duplicate(true),
		"payload_ids": payload_ids.duplicate(true),
		"knowledge_state": knowledge_state.duplicate(true),
		"current_node_id": current_node_id,
		"visited_node_ids": visited_node_ids.duplicate(),
		"ordered_path": ordered_path.duplicate(),
		"path_edge_ids": path_edge_ids.duplicate(),
		"map_rng_state": map_rng_state.duplicate(true),
	}
