class_name SettlePatternCommand
extends "res://src/domain/commands/battle_command.gd"

var _instance_ids: Array[String]

var instance_ids: Array[String]:
	get:
		return _instance_ids.duplicate()

func _init(identifier: String, selected_instance_ids: Array) -> void:
	super(identifier)
	_instance_ids = []
	for instance_id in selected_instance_ids:
		if instance_id is String:
			_instance_ids.append(instance_id)

func command_type() -> String:
	return "SettlePattern"

func to_dictionary() -> Dictionary:
	var result := super()
	result["instance_ids"] = instance_ids
	return result
