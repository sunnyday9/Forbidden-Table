class_name RunMapState
extends RefCounted

var map_definition_id: String
var current_node_id: String
var visited_node_ids: Array[String]
var ordered_path: Array[String]

func _init(
	initial_map_definition_id: String = "",
	initial_current_node_id: String = "",
	initial_visited_node_ids: Array[String] = [],
	initial_ordered_path: Array[String] = [],
) -> void:
	map_definition_id = initial_map_definition_id
	current_node_id = initial_current_node_id
	visited_node_ids = initial_visited_node_ids.duplicate()
	ordered_path = initial_ordered_path.duplicate()

func to_dictionary() -> Dictionary:
	return {
		"map_definition_id": map_definition_id,
		"current_node_id": current_node_id,
		"visited_node_ids": visited_node_ids.duplicate(),
		"ordered_path": ordered_path.duplicate(),
	}
