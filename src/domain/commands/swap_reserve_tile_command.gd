class_name SwapReserveTileCommand
extends "res://src/domain/commands/battle_command.gd"

var hand_instance_id: String
var reserve_instance_id: String

func _init(
	identifier: String,
	selected_hand_instance_id: String,
	selected_reserve_instance_id: String,
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	hand_instance_id = selected_hand_instance_id
	reserve_instance_id = selected_reserve_instance_id

func command_type() -> String:
	return "SwapReserveTile"

func _payload_dictionary() -> Dictionary:
	return {
		"hand_instance_id": hand_instance_id,
		"reserve_instance_id": reserve_instance_id,
	}

func validate(context) -> RefCounted:
	return context.validate_swap_reserve_tiles(hand_instance_id, reserve_instance_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_swap_reserve_tiles(hand_instance_id, reserve_instance_id)
