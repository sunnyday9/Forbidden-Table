class_name CombatResolutionEffect
extends "res://src/domain/combat/combat_resolution_step.gd"

var effect_id: String
var _resolver: Callable

func _init(
	effect_identifier: String,
	effect_resolver: Callable = Callable(),
	effect_damage_amount: int = 0,
	effect_pressure_delta: int = 0,
) -> void:
	super(effect_identifier, effect_damage_amount, effect_pressure_delta)
	effect_id = effect_identifier
	_resolver = effect_resolver

func resolution_kind() -> String:
	return "EFFECT"

func resolve(queue, state, sequence_index: int) -> Array:
	if _resolver.is_valid():
		var result = _resolver.call(queue, state, sequence_index)
		return result if result is Array else []
	return state._apply_step(self, sequence_index)

func to_dictionary() -> Dictionary:
	var result := super()
	result["effect_id"] = effect_id
	result["resolution_kind"] = resolution_kind()
	return result
