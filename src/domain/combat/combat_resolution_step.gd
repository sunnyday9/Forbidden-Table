class_name CombatResolutionStep
extends RefCounted

var source_id: String
var damage_amount: int
var pressure_delta: int

func _init(step_source_id: String, step_damage_amount: int = 0, step_pressure_delta: int = 0) -> void:
	source_id = step_source_id
	damage_amount = maxi(0, step_damage_amount)
	pressure_delta = step_pressure_delta

func resolution_kind() -> String:
	return "EFFECT"

func to_dictionary() -> Dictionary:
	return {
		"source_id": source_id,
		"damage_amount": damage_amount,
		"pressure_delta": pressure_delta,
		"resolution_kind": resolution_kind(),
	}
