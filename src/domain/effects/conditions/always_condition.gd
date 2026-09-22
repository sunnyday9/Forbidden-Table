class_name AlwaysEffectCondition
extends "res://src/domain/effects/effect_condition.gd"

func evaluate(_context, _targets: Dictionary) -> bool:
	return true

func to_dictionary() -> Dictionary:
	return {"condition": "ALWAYS"}
