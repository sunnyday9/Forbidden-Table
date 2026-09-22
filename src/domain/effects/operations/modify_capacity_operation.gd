class_name ModifyCapacityOperation
extends "res://src/domain/effects/effect_operation.gd"

const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var capacity_key: String
var amount: int

func _init(identifier: String, key: String, delta: int) -> void:
	super(identifier)
	capacity_key = key
	amount = delta

func validate(context, _targets: Dictionary) -> String:
	if not _has_state(context):
		return "NO_STATE"
	var current: int = context.state.get(capacity_key)
	if current + amount < 0:
		return "CAPACITY_BELOW_ZERO"
	if capacity_key == "reserve_capacity" and context.zones != null and current + amount < context.zones.size(TileZoneScript.RESERVE):
		return "CAPACITY_BELOW_OCCUPANCY"
	return ""

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	var previous: int = context.state.get(capacity_key)
	context.state.set(capacity_key, previous + amount)
	return [_event("CapacityChanged", {"effect_id": effect_id, "capacity": capacity_key, "previous": previous, "value": context.state.get(capacity_key), "amount": amount, "sequence_index": sequence_index})]

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "capacity": capacity_key, "amount": amount}
