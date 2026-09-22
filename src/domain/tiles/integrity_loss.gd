class_name IntegrityLoss
extends RefCounted

const BreakPolicyScript = preload("res://src/domain/tiles/break_policy.gd")
const IntegrityCauseScript = preload("res://src/domain/tiles/integrity_cause.gd")

var amount: int
var cause: String
var break_policy: String

func _init(loss_amount: int, loss_cause: String, requested_break_policy: String = "") -> void:
	amount = maxi(0, loss_amount)
	cause = loss_cause
	break_policy = requested_break_policy if not requested_break_policy.is_empty() else default_break_policy(loss_cause)

static func default_break_policy(loss_cause: String) -> String:
	return BreakPolicyScript.EXHAUST if loss_cause == IntegrityCauseScript.ACTIVE_MANIPULATION_WEAR else BreakPolicyScript.DISCARD

func is_valid() -> bool:
	return amount > 0 and IntegrityCauseScript.is_valid(cause) and BreakPolicyScript.is_valid(break_policy)

func to_dictionary() -> Dictionary:
	return {
		"amount": amount,
		"cause": cause,
		"break_policy": break_policy,
	}
