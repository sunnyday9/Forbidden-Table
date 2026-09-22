class_name ChooseContractCommand
extends "res://src/domain/commands/run_command.gd"

var contract_id: String

func _init(
	identifier: String,
	selected_contract_id: String,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	contract_id = selected_contract_id

func command_type() -> String:
	return "ChooseContract"

func _payload_dictionary() -> Dictionary:
	return {"contract_id": contract_id}

func validate(context) -> RefCounted:
	return context.validate_choose_contract(contract_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_choose_contract(contract_id)
