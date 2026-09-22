class_name EffectResolutionResult
extends RefCounted

const RESOLVED := "RESOLVED"
const REJECTED_CONDITION := "REJECTED_CONDITION"
const REJECTED_TARGET := "REJECTED_TARGET"
const REJECTED_OPERATION := "REJECTED_OPERATION"

var status: String
var effect_id: String
var trigger_id: String
var reason: String
var _events: Array

var events: Array:
	get:
		return _events.duplicate()

func _init(result_status: String, identifier: String, trigger: String, result_reason: String = "", result_events: Array = []) -> void:
	status = result_status
	effect_id = identifier
	trigger_id = trigger
	reason = result_reason
	_events = result_events.duplicate()

func is_resolved() -> bool:
	return status == RESOLVED

func to_dictionary() -> Dictionary:
	var event_data: Array = []
	for event in _events:
		event_data.append(event.to_dictionary() if event != null and event.has_method("to_dictionary") else event)
	return {"status": status, "effect_id": effect_id, "trigger_id": trigger_id, "reason": reason, "events": event_data}
