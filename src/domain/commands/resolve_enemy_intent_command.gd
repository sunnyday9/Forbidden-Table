class_name ResolveEnemyIntentCommand
extends "res://src/domain/commands/battle_command.gd"

func _init(
	identifier: String = "battle.resolve_enemy_intent",
	actor_identifier: String = "enemy",
	target_identifier: String = "battle",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)

func command_type() -> String:
	return "ResolveEnemyIntent"

func validate(context) -> RefCounted:
	return context.validate_enemy_intent()

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_enemy_intent()
