class_name GainTPOperation
extends "res://src/domain/effects/effect_operation.gd"

var amount: int

func _init(gain_amount: int, _target_key: String = "self") -> void:
	super("GainTP")
	amount = gain_amount

func validate(context, _targets: Dictionary) -> String:
	return "NO_STATE" if not _has_state(context) else ("INVALID_AMOUNT" if amount < 0 else "")

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	var previous: int = context.state.tp
	context.state.tp += amount
	return [_event("TPChanged", {"effect_id": effect_id, "previous_tp": previous, "tp": context.state.tp, "amount": amount, "sequence_index": sequence_index})]

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "amount": amount}
