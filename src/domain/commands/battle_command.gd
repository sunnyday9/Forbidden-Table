class_name BattleCommand
extends RefCounted

var command_id: String

func _init(identifier: String) -> void:
	command_id = identifier

func command_type() -> String:
	return "BattleCommand"

func to_dictionary() -> Dictionary:
	return {
		"command_id": command_id,
		"command_type": command_type(),
	}
