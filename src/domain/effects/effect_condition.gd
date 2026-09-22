class_name EffectCondition
extends RefCounted

func evaluate(_context, _targets: Dictionary) -> bool:
	return true

func failure_reason() -> String:
	return "CONDITION_FALSE"

func to_dictionary() -> Dictionary:
	return {"condition": "EffectCondition"}
