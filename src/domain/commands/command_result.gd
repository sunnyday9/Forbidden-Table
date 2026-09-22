class_name CommandResult
extends RefCounted

const ACCEPTED := "ACCEPTED"
const REJECTED := "REJECTED"
const PREVIEW_ONLY := "PREVIEW_ONLY"

const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")

var command_id: String
var command_type: String
var actor_id: String
var target_id: String
var accepted: bool
var status: String
var validation
var replayable: bool
var preview: bool
var message: String
var data: Dictionary

var _events: Array
var _before_checkpoint: Dictionary
var _state_checkpoint: Dictionary

var events: Array:
	get:
		return _events.duplicate()

var before_checkpoint: Dictionary:
	get:
		return _before_checkpoint.duplicate(true)

var state_checkpoint: Dictionary:
	get:
		return _state_checkpoint.duplicate(true)

func _init(
	result_command_id: String,
	result_command_type: String,
	result_actor_id: String,
	result_target_id: String,
	result_accepted: bool,
	result_status: String,
	result_validation = null,
	result_events: Array = [],
	result_before_checkpoint: Dictionary = {},
	result_state_checkpoint: Dictionary = {},
	result_preview: bool = false,
	result_message: String = "",
	result_data: Dictionary = {},
) -> void:
	command_id = result_command_id
	command_type = result_command_type
	actor_id = result_actor_id
	target_id = result_target_id
	accepted = result_accepted
	status = result_status
	validation = result_validation if result_validation != null else CommandValidationScript.new(result_accepted)
	_events = result_events.duplicate()
	_before_checkpoint = result_before_checkpoint.duplicate(true)
	_state_checkpoint = result_state_checkpoint.duplicate(true)
	replayable = result_accepted and not result_preview
	preview = result_preview
	message = result_message
	data = result_data.duplicate(true)

func is_accepted() -> bool:
	return accepted

func is_replayable() -> bool:
	return replayable

func serialize() -> String:
	return JSON.stringify(to_dictionary())

func to_dictionary() -> Dictionary:
	var event_data: Array = []
	for event in _events:
		if event != null and event.has_method("to_dictionary"):
			event_data.append(event.to_dictionary())
		elif event is Dictionary:
			event_data.append(event.duplicate(true))
	return {
		"command_id": command_id,
		"command_type": command_type,
		"actor_id": actor_id,
		"target_id": target_id,
		"accepted": accepted,
		"status": status,
		"validation": validation.to_dictionary(),
		"events": event_data,
		"before_checkpoint": before_checkpoint,
		"state_checkpoint": state_checkpoint,
		"replayable": replayable,
		"preview": preview,
		"message": message,
		"data": data.duplicate(true),
	}
