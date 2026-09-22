class_name EventState
extends RefCounted

const EventDefinitionScript = preload("res://src/content/definitions/event_definition.gd")

var active: bool
var completed: bool
var node_id: String
var entry_id: String
var event_id: String
var choices: Array
var selected_choice_id: String
var resolved_alternative_id: String
var entry_sequence: int
var event_rng_state: Dictionary
var completed_node_ids: Array[String]

func _init() -> void:
	active = false
	completed = false
	node_id = ""
	entry_id = ""
	event_id = ""
	choices = []
	selected_choice_id = ""
	resolved_alternative_id = ""
	entry_sequence = 0
	event_rng_state = {}
	completed_node_ids = []

func begin(
	initial_node_id: String,
	initial_entry_id: String,
	definition,
	initial_rng_state: Dictionary,
) -> bool:
	if not definition is EventDefinitionScript:
		return false
	active = true
	completed = false
	node_id = initial_node_id
	entry_id = initial_entry_id
	event_id = definition.content_id
	choices = definition.choices.duplicate(true)
	selected_choice_id = ""
	resolved_alternative_id = ""
	event_rng_state = initial_rng_state.duplicate(true)
	entry_sequence += 1
	return true

func choice_by_id(choice_id: String):
	for choice in choices:
		if choice is Dictionary and str(choice.get("choice_id", "")) == choice_id:
			return choice
	return null

func legal_choice_ids() -> Array[String]:
	var ids: Array[String] = []
	for choice in choices:
		if choice is Dictionary:
			var choice_id := str(choice.get("choice_id", ""))
			if not choice_id.is_empty():
				ids.append(choice_id)
	return ids

func mark_completed(choice_id: String, alternative_id: String = "") -> void:
	selected_choice_id = choice_id
	resolved_alternative_id = alternative_id
	active = false
	completed = true
	if not node_id.is_empty() and not completed_node_ids.has(node_id):
		completed_node_ids.append(node_id)

func has_completed_node(selected_node_id: String) -> bool:
	return completed_node_ids.has(selected_node_id)

func to_dictionary() -> Dictionary:
	var serialized_choices: Array = []
	for choice in choices:
		serialized_choices.append(_serialize_value(choice))
	return {
		"active": active,
		"completed": completed,
		"node_id": node_id,
		"entry_id": entry_id,
		"event_id": event_id,
		"choices": serialized_choices,
		"selected_choice_id": selected_choice_id,
		"resolved_alternative_id": resolved_alternative_id,
		"entry_sequence": entry_sequence,
		"event_rng_state": event_rng_state.duplicate(true),
		"completed_node_ids": completed_node_ids.duplicate(),
	}

func _serialize_value(value):
	if value is Object and value.has_method("to_dictionary"):
		return value.to_dictionary()
	if value is Dictionary:
		var serialized: Dictionary = {}
		for key in value.keys():
			serialized[key] = _serialize_value(value[key])
		return serialized
	if value is Array:
		var serialized_array: Array = []
		for item in value:
			serialized_array.append(_serialize_value(item))
		return serialized_array
	return value
