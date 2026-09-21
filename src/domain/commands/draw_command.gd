class_name DrawCommand
extends "res://src/domain/commands/battle_command.gd"

func _init(identifier: String = "battle.draw") -> void:
	super(identifier)

func command_type() -> String:
	return "Draw"
