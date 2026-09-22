class_name IntentCondition
extends RefCounted

func evaluate(_public_battle_state: Dictionary) -> bool:
	return false

func is_valid() -> bool:
	return false

func validation_code() -> String:
	return "invalid_condition"

func to_dictionary() -> Dictionary:
	return {"condition": "INVALID"}
