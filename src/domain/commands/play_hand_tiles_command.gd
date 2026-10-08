class_name PlayHandTilesCommand
extends "res://src/domain/commands/battle_command.gd"

var instance_ids: Array[String] = []

func _init(identifier: String, selected_ids: Array = [], actor_identifier: String = "", target_identifier: String = "", preview_command: bool = false) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	for instance_id in selected_ids:
		instance_ids.append(str(instance_id))

func command_type() -> String:
	return "PlayHandTiles"

func _payload_dictionary() -> Dictionary:
	return {"instance_ids": instance_ids.duplicate()}

func validate(context) -> RefCounted:
	return context.validate_play_hand_tiles(instance_ids)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_play_hand_tiles(instance_ids)
