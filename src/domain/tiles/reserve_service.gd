class_name ReserveService
extends RefCounted

const BreakPolicyScript = preload("res://src/domain/tiles/break_policy.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const IntegrityCauseScript = preload("res://src/domain/tiles/integrity_cause.gd")
const IntegrityLossScript = preload("res://src/domain/tiles/integrity_loss.gd")
const ReserveActionResultScript = preload("res://src/domain/tiles/reserve_action_result.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")

var zones
var reserve_capacity: int
var _sequence_index := 0

func _init(domain_zones, initial_capacity: int = 3) -> void:
	zones = domain_zones
	reserve_capacity = maxi(0, initial_capacity)
	if zones != null and zones.has_method("set_reserve_capacity"):
		zones.set_reserve_capacity(reserve_capacity)

func set_capacity(new_capacity: int) -> bool:
	var bounded_capacity := maxi(0, new_capacity)
	if zones == null or not zones.set_reserve_capacity(bounded_capacity):
		return false
	reserve_capacity = bounded_capacity
	return true

func store_to_reserve(instance_id: String):
	if zones == null or not zones.contains_in_zone(instance_id, TileZoneScript.HAND):
		return ReserveActionResultScript.new(ReserveActionResultScript.INVALID_TILE)
	if zones.size(TileZoneScript.RESERVE) >= reserve_capacity:
		return ReserveActionResultScript.new(ReserveActionResultScript.RESERVE_CAPACITY_REACHED)
	var tile_instance = _find(instance_id)
	if tile_instance == null or not zones.transfer(instance_id, TileZoneScript.HAND, TileZoneScript.RESERVE):
		return ReserveActionResultScript.new(ReserveActionResultScript.TRANSFER_FAILED)
	var event := DomainEventScript.new(DomainEventScript.RESERVE_STORED, {
		"instance_id": tile_instance.instance_id,
		"definition_id": tile_instance.definition_id,
		"integrity": tile_instance.integrity,
		"sequence_index": _next_sequence(),
	})
	return ReserveActionResultScript.new(ReserveActionResultScript.ACCEPTED, tile_instance, null, [event])

func swap(hand_instance_id: String, reserve_instance_id: String):
	if zones == null or not zones.contains_in_zone(hand_instance_id, TileZoneScript.HAND):
		return ReserveActionResultScript.new(ReserveActionResultScript.INVALID_TILE)
	if not zones.contains_in_zone(reserve_instance_id, TileZoneScript.RESERVE):
		return ReserveActionResultScript.new(ReserveActionResultScript.INVALID_RESERVE_TILE)
	var hand_tile = _find(hand_instance_id)
	var reserve_tile = _find(reserve_instance_id)
	if hand_tile == null or reserve_tile == null or not zones.swap(hand_instance_id, reserve_instance_id):
		return ReserveActionResultScript.new(ReserveActionResultScript.TRANSFER_FAILED)
	var event := DomainEventScript.new(DomainEventScript.RESERVE_SWAPPED, {
		"hand_instance_id": hand_instance_id,
		"reserve_instance_id": reserve_instance_id,
		"hand_definition_id": hand_tile.definition_id,
		"reserve_definition_id": reserve_tile.definition_id,
		"sequence_index": _next_sequence(),
	})
	return ReserveActionResultScript.new(ReserveActionResultScript.ACCEPTED, reserve_tile, hand_tile, [event])

func apply_integrity_loss(instance_id: String, loss):
	if zones == null or not zones.contains_in_zone(instance_id, TileZoneScript.RESERVE):
		return ReserveActionResultScript.new(ReserveActionResultScript.INVALID_TILE)
	if not loss is IntegrityLossScript or not loss.is_valid():
		return ReserveActionResultScript.new(ReserveActionResultScript.INVALID_INTEGRITY_LOSS)
	var tile_instance = _find(instance_id)
	if tile_instance == null or not tile_instance.integrity_initialized():
		return ReserveActionResultScript.new(ReserveActionResultScript.INTEGRITY_NOT_AVAILABLE)
	var previous_integrity: int = tile_instance.integrity
	var actual_loss: int = tile_instance.apply_integrity_loss(loss.amount)
	var sequence_index := _next_sequence()
	var events: Array = [DomainEventScript.new(DomainEventScript.INTEGRITY_CHANGED, {
		"instance_id": instance_id,
		"previous_integrity": previous_integrity,
		"integrity": tile_instance.integrity,
		"amount": actual_loss,
		"cause": loss.cause,
		"break_policy": loss.break_policy,
		"loss": loss.to_dictionary(),
		"sequence_index": sequence_index,
	})]
	if tile_instance.integrity == 0:
		var destination := TileZoneScript.DISCARD if loss.break_policy == BreakPolicyScript.DISCARD else TileZoneScript.EXHAUST
		if zones.transfer(instance_id, TileZoneScript.RESERVE, destination):
			events.append(DomainEventScript.new(DomainEventScript.INTEGRITY_BROKEN, {
				"instance_id": instance_id,
				"cause": loss.cause,
				"break_policy": loss.break_policy,
				"destination": destination,
				"sequence_index": sequence_index,
			}))
	return ReserveActionResultScript.new(ReserveActionResultScript.ACCEPTED, tile_instance, null, events)

func damage_integrity(instance_id: String, amount: int, cause: String = IntegrityCauseScript.ENEMY_DAMAGE, break_policy: String = ""):
	return apply_integrity_loss(instance_id, IntegrityLossScript.new(amount, cause, break_policy))

func repair_integrity(instance_id: String, amount: int):
	if zones == null or not zones.contains(instance_id):
		return ReserveActionResultScript.new(ReserveActionResultScript.INVALID_TILE)
	var tile_instance = _find(instance_id)
	if tile_instance == null or not tile_instance.integrity_initialized() or amount <= 0:
		return ReserveActionResultScript.new(ReserveActionResultScript.INTEGRITY_NOT_AVAILABLE)
	var previous_integrity: int = tile_instance.integrity
	var repaired: int = tile_instance.repair_integrity(amount)
	var event := DomainEventScript.new(DomainEventScript.INTEGRITY_REPAIRED, {
		"instance_id": instance_id,
		"previous_integrity": previous_integrity,
		"integrity": tile_instance.integrity,
		"amount": repaired,
		"cause": IntegrityCauseScript.EXPLICIT_REPAIR,
		"sequence_index": _next_sequence(),
	})
	return ReserveActionResultScript.new(ReserveActionResultScript.ACCEPTED, tile_instance, null, [event])

func repair(instance_id: String, amount: int):
	return repair_integrity(instance_id, amount)

func natural_decay(amount: int = 1) -> Array:
	var events: Array = []
	if zones == null or amount <= 0:
		return events
	var reserve_tiles: Array = zones.contents(TileZoneScript.RESERVE)
	reserve_tiles.sort_custom(func(left, right): return left.instance_id < right.instance_id)
	for tile_instance in reserve_tiles:
		var result = apply_integrity_loss(tile_instance.instance_id, IntegrityLossScript.new(amount, IntegrityCauseScript.NATURAL_DECAY))
		events.append_array(result.events)
	return events

func decay(amount: int = 1) -> Array:
	return natural_decay(amount)

func end_battle(preserve_run_level: bool = false, preserved_instance_ids: Array = []) -> Array:
	var events: Array = []
	if zones == null:
		return events
	for zone in TileZoneScript.all():
		for tile_instance in zones.contents(zone):
			var preserved := preserve_run_level or preserved_instance_ids.has(tile_instance.instance_id)
			if not preserved and tile_instance.integrity_initialized():
				tile_instance.reset_battle_runtime_integrity()
				events.append(DomainEventScript.new(DomainEventScript.BATTLE_RUNTIME_RESET, {
					"instance_id": tile_instance.instance_id,
					"sequence_index": _next_sequence(),
				}))
	return events

func _find(instance_id: String):
	for zone in TileZoneScript.all():
		for tile_instance in zones.contents(zone):
			if tile_instance is TileInstanceScript and tile_instance.instance_id == instance_id:
				return tile_instance
	return null

func _next_sequence() -> int:
	_sequence_index += 1
	return _sequence_index
