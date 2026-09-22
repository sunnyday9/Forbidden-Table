class_name DamageIntegrityOperation
extends "res://src/domain/effects/effect_operation.gd"

const BreakPolicyScript = preload("res://src/domain/tiles/break_policy.gd")
const IntegrityCauseScript = preload("res://src/domain/tiles/integrity_cause.gd")
const IntegrityLossScript = preload("res://src/domain/tiles/integrity_loss.gd")
const ReserveServiceScript = preload("res://src/domain/tiles/reserve_service.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var instance_id: String
var amount: int
var cause: String
var break_policy: String

func _init(tile_instance_id: String, damage_amount: int, damage_cause: String = IntegrityCauseScript.ENEMY_DAMAGE, requested_break_policy: String = "") -> void:
	super("DamageIntegrity")
	instance_id = tile_instance_id
	amount = damage_amount
	cause = damage_cause
	break_policy = requested_break_policy if not requested_break_policy.is_empty() else IntegrityLossScript.default_break_policy(damage_cause)

func validate(context, _targets: Dictionary) -> String:
	if context == null or context.zones == null:
		return "NO_TILE_ZONES"
	if not context.zones.contains_in_zone(instance_id, TileZoneScript.RESERVE):
		return "INVALID_RESERVE_TILE"
	if amount <= 0 or not IntegrityCauseScript.is_valid(cause) or not BreakPolicyScript.is_valid(break_policy):
		return "INVALID_INTEGRITY_LOSS"
	return ""

func apply(context, _targets: Dictionary, _sequence_index: int, _effect_id: String) -> Array:
	var service = context.reserve_service if context.reserve_service != null else ReserveServiceScript.new(context.zones, context.state.reserve_capacity if context.state != null else 3)
	return service.apply_integrity_loss(instance_id, IntegrityLossScript.new(amount, cause, break_policy)).events

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "instance_id": instance_id, "amount": amount, "cause": cause, "break_policy": break_policy}
