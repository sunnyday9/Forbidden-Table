class_name WorkshopState
extends RefCounted

const REMOVE := "REMOVE"
const REMOVE_PAIR := "REMOVE_PAIR"
const REMOVE_PAIR_MINIMUM_POOL_SIZE := 14
const TRANSFORM := "TRANSFORM"
const ADD_MODIFIER := "ADD_MODIFIER"
const REPLACE_MODIFIER := "REPLACE_MODIFIER"
const DUPLICATE := "DUPLICATE"
const REFINEMENT_TOKEN := "REFINEMENT_TOKEN"
const MODIFIER := "MODIFIER"

var active: bool
var completed: bool
var node_id: String
var entry_id: String
var available_service_ids: Array[String]
var used_service_ids: Array[String]
var entry_sequence: int
var completed_node_ids: Array[String]

func _init() -> void:
	active = false
	completed = false
	node_id = ""
	entry_id = ""
	available_service_ids = []
	used_service_ids = []
	entry_sequence = 0
	completed_node_ids = []

func begin(initial_node_id: String, initial_entry_id: String) -> void:
	active = true
	completed = false
	node_id = initial_node_id
	entry_id = initial_entry_id
	available_service_ids = [REMOVE, REMOVE_PAIR, TRANSFORM, MODIFIER, DUPLICATE, REFINEMENT_TOKEN]
	used_service_ids = []
	entry_sequence += 1

func service_key(service_id: String) -> String:
	if service_id in [ADD_MODIFIER, REPLACE_MODIFIER, MODIFIER]:
		return MODIFIER
	return service_id

func is_service_available(service_id: String) -> bool:
	var key := service_key(service_id)
	return available_service_ids.has(key) and not used_service_ids.has(key)

func mark_service_used(service_id: String) -> void:
	var key := service_key(service_id)
	if not used_service_ids.has(key):
		used_service_ids.append(key)

func mark_completed() -> void:
	active = false
	completed = true
	if not node_id.is_empty() and not completed_node_ids.has(node_id):
		completed_node_ids.append(node_id)

func has_completed_node(selected_node_id: String) -> bool:
	return completed_node_ids.has(selected_node_id)

func to_dictionary() -> Dictionary:
	return {
		"active": active,
		"completed": completed,
		"node_id": node_id,
		"entry_id": entry_id,
		"available_service_ids": available_service_ids.duplicate(),
		"used_service_ids": used_service_ids.duplicate(),
		"entry_sequence": entry_sequence,
		"completed_node_ids": completed_node_ids.duplicate(),
	}
