class_name NaturalIntegrityDecayOperation
extends "res://src/domain/effects/effect_operation.gd"

const ReserveServiceScript = preload("res://src/domain/tiles/reserve_service.gd")

var amount: int

func _init(decay_amount: int = 1) -> void:
	super("NaturalIntegrityDecay")
	amount = decay_amount

func validate(context, _targets: Dictionary) -> String:
	return "NO_TILE_ZONES" if context == null or context.zones == null else ("INVALID_INTEGRITY_LOSS" if amount <= 0 else "")

func apply(context, _targets: Dictionary, _sequence_index: int, _effect_id: String) -> Array:
	var service = context.reserve_service if context.reserve_service != null else ReserveServiceScript.new(context.zones, context.state.reserve_capacity if context.state != null else 3)
	return service.natural_decay(amount)

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "amount": amount}
