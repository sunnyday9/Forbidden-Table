class_name EventDefinition
extends "res://src/content/definitions/content_definition.gd"

@export var choices: Array

func _init(definition_id: String = "", event_choices: Array = [], references: Array[String] = []) -> void:
	var choice_references := references.duplicate()
	choices = event_choices.duplicate(true)
	for choice in choices:
		if choice is Dictionary and choice.has("content_id"):
			choice_references.append(str(choice["content_id"]))
	super(definition_id, choice_references)

func definition_type_name() -> String:
	return "EventDefinition"

func expected_id_families() -> Array[String]:
	return ["event"]

func validate():
	var report = super.validate()
	var has_explicit_leave := false
	var choice_ids: Dictionary = {}
	for choice in choices:
		if not choice is Dictionary or str(choice.get("choice_id", "")).is_empty():
			report.add_issue(_issue("invalid_event_choice", "EventDefinition choices require stable choice IDs."))
			continue
		var choice_id := str(choice["choice_id"])
		if choice_id.to_lower() in ["skip", "leave"] or bool(choice.get("is_skip", false)):
			has_explicit_leave = true
		if choice_ids.has(choice_id):
			report.add_issue(_issue("duplicate_event_choice", "EventDefinition choice IDs must be unique.", choice_id))
		choice_ids[choice_id] = true
	if choices.size() < 2 and not has_explicit_leave:
		report.add_issue(_issue("insufficient_event_choices", "EventDefinition must declare at least two legal choices or an explicit Skip/Leave choice."))
	return report
