class_name RunTutorialState
extends RefCounted

var active_step_id: String
var completed_step_ids: Array[String]

func _init(initial_active_step_id: String = "") -> void:
	active_step_id = initial_active_step_id
	completed_step_ids = []

func to_dictionary() -> Dictionary:
	return {
		"active_step_id": active_step_id,
		"completed_step_ids": completed_step_ids.duplicate(),
	}
