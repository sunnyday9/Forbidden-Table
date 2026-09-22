class_name DealDamageOperation
extends "res://src/domain/effects/effect_operation.gd"

var amount: int
var target_key: String

func _init(damage_amount: int, target: String = "") -> void:
	super("DealDamage")
	amount = damage_amount
	target_key = target

func validate(context, targets: Dictionary) -> String:
	if not _has_state(context):
		return "NO_STATE"
	if amount < 0:
		return "INVALID_AMOUNT"
	if not target_key.is_empty() and not _target_matches(targets, target_key, "ENEMY"):
		return "INVALID_TARGET"
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	return context.state._apply_damage(amount, effect_id, sequence_index)

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "amount": amount, "target_key": target_key}
