class_name RepairIntegrityOperation
extends "res://src/domain/effects/effect_operation.gd"

const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const ReserveServiceScript = preload("res://src/domain/tiles/reserve_service.gd")

var instance_id: String
var amount: int

func _init(tile_instance_id: String, repair_amount: int) -> void:
	super("RepairIntegrity")
	instance_id = tile_instance_id
	amount = repair_amount

func validate(context, _targets: Dictionary) -> String:
	if context == null or context.zones == null:
		return "NO_TILE_ZONES"
	if not context.zones.contains(instance_id) or amount <= 0:
		return "INVALID_INTEGRITY_REPAIR"
	var tile_instance = _find(context.zones)
	return "INTEGRITY_NOT_AVAILABLE" if tile_instance == null or not tile_instance.integrity_initialized() else ""

func apply(context, _targets: Dictionary, _sequence_index: int, _effect_id: String) -> Array:
	var service = context.reserve_service if context.reserve_service != null else ReserveServiceScript.new(context.zones, context.state.reserve_capacity if context.state != null else 3)
	return service.repair_integrity(instance_id, amount).events

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "instance_id": instance_id, "amount": amount}

func _find(domain_zones):
	for zone in TileZoneScript.all():
		for tile_instance in domain_zones.contents(zone):
			if tile_instance.instance_id == instance_id:
				return tile_instance
	return null
