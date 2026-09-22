class_name GainStabilityOperation
extends "res://src/domain/effects/effect_operation.gd"

var amount: int

func _init(gain_amount: int) -> void:
	super("GainStability")
	amount = gain_amount

func validate(context, _targets: Dictionary) -> String:
	return "NO_STATE" if not _has_state(context) else ("INVALID_AMOUNT" if amount < 0 else "")

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	var events: Array = []
	var previous_stability: int = context.state.stability
	var previous_pressure: int = context.state.pressure
	context.state.stability += amount
	context.state.pressure = maxi(0, context.state.pressure - amount)
	events.append(_event("StabilityChanged", {"effect_id": effect_id, "previous_stability": previous_stability, "stability": context.state.stability, "amount": amount, "sequence_index": sequence_index}))
	if previous_pressure != context.state.pressure:
		events.append(_event("PressureChanged", {"source_id": effect_id, "previous_pressure": previous_pressure, "pressure": context.state.pressure, "pressure_limit": context.state.pressure_limit, "amount": context.state.pressure - previous_pressure, "sequence_index": sequence_index}))
	return events

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "amount": amount}
