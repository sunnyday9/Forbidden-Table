class_name DomainCommand
extends RefCounted

const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")

var command_id: String
var actor_id: String
var target_id: String
var preview: bool

var _last_result

func _init(
	identifier: String,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	command_id = identifier
	actor_id = actor_identifier
	target_id = target_identifier
	preview = preview_command

func command_type() -> String:
	return "DomainCommand"

func is_preview() -> bool:
	return preview

func is_authoritative() -> bool:
	return not preview

func validate(_context) -> RefCounted:
	return CommandValidationScript.new(false, "UNSUPPORTED_COMMAND", "This command has no validation implementation.")

func execute(context) -> RefCounted:
	var before_checkpoint := _checkpoint(context)
	if preview:
		return _remember_result(CommandResultScript.new(
			command_id,
			command_type(),
			actor_id,
			target_id,
			false,
			CommandResultScript.PREVIEW_ONLY,
			CommandValidationScript.new(false, CommandResultScript.PREVIEW_ONLY, "Preview commands do not mutate authoritative state."),
			[],
			before_checkpoint,
			before_checkpoint,
			true,
			"Preview execution is not authoritative.",
		))

	var validation = validate(context)
	if validation == null or not validation.is_valid():
		if validation == null:
			validation = CommandValidationScript.new(false, "INVALID_COMMAND", "Command validation failed.")
		return _remember_result(CommandResultScript.new(
			command_id,
			command_type(),
			actor_id,
			target_id,
			false,
			CommandResultScript.REJECTED,
			validation,
			[],
			before_checkpoint,
			before_checkpoint,
			false,
			validation.message,
		))

	var execution: Dictionary = _execute_authoritatively(context)
	var accepted := bool(execution.get("accepted", false))
	var state_checkpoint := _checkpoint(context)
	var result_status: String = str(execution.get("status", CommandResultScript.ACCEPTED)) if accepted else CommandResultScript.REJECTED
	var result_events: Array = execution.get("events", []) if accepted else []
	var result_validation = validation if accepted else CommandValidationScript.new(
		false,
		execution.get("status", "EXECUTION_REJECTED"),
		execution.get("message", "Command execution was rejected."),
	)
	return _remember_result(CommandResultScript.new(
		command_id,
		command_type(),
		actor_id,
		target_id,
		accepted,
		result_status,
		result_validation,
		result_events,
		before_checkpoint,
		state_checkpoint,
		false,
		execution.get("message", ""),
		execution.get("data", {}),
	))

func result():
	return _last_result

func to_dictionary() -> Dictionary:
	var result := {
		"command_id": command_id,
		"command_type": command_type(),
		"actor_id": actor_id,
		"target_id": target_id,
		"preview": preview,
	}
	var payload := _payload_dictionary()
	for key in payload.keys():
		result[key] = payload[key]
	return result

func serialize() -> String:
	return JSON.stringify(to_dictionary())

func _payload_dictionary() -> Dictionary:
	return {}

func _execute_authoritatively(_context) -> Dictionary:
	return {
		"accepted": false,
		"status": "UNSUPPORTED_COMMAND",
		"message": "This command has no execution implementation.",
	}

func _checkpoint(context) -> Dictionary:
	if context != null and context.has_method("checkpoint"):
		return context.checkpoint()
	return {}

func _remember_result(result_value):
	_last_result = result_value
	return result_value
