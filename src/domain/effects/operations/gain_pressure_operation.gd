class_name GainPressureOperation
extends "res://src/domain/effects/effect_operation.gd"

var amount: int

func _init(gain_amount: int) -> void:
	super("GainPressure")
	amount = gain_amount

func validate(context, _targets: Dictionary) -> String:
	return "NO_STATE" if not _has_state(context) else ("INVALID_AMOUNT" if amount < 0 else "")

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	return context.state._apply_pressure(amount, effect_id, sequence_index)

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "amount": amount}
