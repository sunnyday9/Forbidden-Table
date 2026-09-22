class_name UseWorkshopServiceCommand
extends "res://src/domain/commands/run_command.gd"

const REMOVE := "REMOVE"
const TRANSFORM := "TRANSFORM"
const ADD_MODIFIER := "ADD_MODIFIER"
const REPLACE_MODIFIER := "REPLACE_MODIFIER"
const DUPLICATE := "DUPLICATE"
const REFINEMENT_TOKEN := "REFINEMENT_TOKEN"

var service_id: String
var instance_id: String
var value_id: String
var modifier_id: String
var replace_existing: bool

func _init(
	identifier: String,
	selected_service_id: String,
	selected_instance_id: String = "",
	selected_value_id: String = "",
	selected_modifier_id: String = "",
	should_replace: bool = false,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	service_id = selected_service_id
	instance_id = selected_instance_id
	value_id = selected_value_id
	modifier_id = selected_modifier_id
	replace_existing = should_replace or service_id == REPLACE_MODIFIER

func command_type() -> String:
	return "UseWorkshopService"

func _payload_dictionary() -> Dictionary:
	return {
		"service_id": service_id,
		"instance_id": instance_id,
		"value_id": value_id,
		"modifier_id": modifier_id,
		"replace_existing": replace_existing,
	}

func validate(context) -> RefCounted:
	return context.validate_use_workshop_service(service_id, instance_id, value_id, modifier_id, replace_existing)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_use_workshop_service(service_id, instance_id, value_id, modifier_id, replace_existing)
