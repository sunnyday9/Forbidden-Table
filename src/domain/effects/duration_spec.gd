class_name DurationSpec
extends RefCounted

const PERMANENT := "PERMANENT"
const ACTION := "ACTION"
const WINDOW := "WINDOW"
const SETTLEMENT_WINDOW := "SETTLEMENT_WINDOW"
const TURN := "TURN"
const N_TURNS := TURN
const BATTLE := "BATTLE"
const BOSS_PHASE := "BOSS_PHASE"
const ACT := "ACT"
const RUN := "RUN"
const USES := "USES"
const CHARGES := "CHARGES"

var scope: String
var amount: int

func _init(duration_scope: String = PERMANENT, duration_amount: int = 0) -> void:
	scope = duration_scope if not duration_scope.is_empty() else PERMANENT
	amount = maxi(0, duration_amount)
	if scope == PERMANENT:
		amount = 0

func is_permanent() -> bool:
	return scope == PERMANENT

func is_consumable() -> bool:
	return scope == USES or scope == CHARGES

func is_boundary_duration() -> bool:
	return scope == ACTION or scope == WINDOW or scope == SETTLEMENT_WINDOW or scope == TURN or scope == BATTLE or scope == BOSS_PHASE or scope == ACT or scope == RUN

func matches_boundary(boundary: String) -> bool:
	return is_boundary_duration() and (scope == boundary or (scope == WINDOW and boundary == SETTLEMENT_WINDOW) or (scope == SETTLEMENT_WINDOW and boundary == WINDOW))

func to_dictionary() -> Dictionary:
	return {"scope": scope, "amount": amount}
