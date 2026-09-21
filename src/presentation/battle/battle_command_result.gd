class_name BattleCommandResult
extends RefCounted

var accepted: bool
var status: String
var _events: Array
var message: String

var events: Array:
	get:
		return _events.duplicate()

func _init(result_accepted: bool, result_status: String, result_events: Array = [], result_message: String = "") -> void:
	accepted = result_accepted
	status = result_status
	_events = result_events.duplicate()
	message = result_message

func to_dictionary() -> Dictionary:
	var event_data: Array = []
	for event in _events:
		event_data.append({
			"event_type": event.event_type,
			"data": event.data.duplicate(true),
		})
	return {
		"accepted": accepted,
		"status": status,
		"events": event_data,
		"message": message,
	}
