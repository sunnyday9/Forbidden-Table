class_name ContaminationService
extends RefCounted

const ContaminationCleanupPolicyScript = preload("res://src/domain/tiles/contamination_cleanup_policy.gd")
const ContaminationDefinitionScript = preload("res://src/domain/tiles/contamination_definition.gd")
const ContaminationResultScript = preload("res://src/domain/tiles/contamination_result.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")
const TileLifetimeScript = preload("res://src/domain/tiles/tile_lifetime.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var zones
var _sequence_index := 0

func _init(domain_zones, domain_state = null) -> void:
	zones = domain_zones

func apply_contamination(instance_id: String, contamination, sequence_index: int = -1):
	var definition = _normalize_definition(contamination)
	if definition == null or not definition.is_valid():
		return ContaminationResultScript.new(ContaminationResultScript.INVALID_CONTAMINATION)
	var tile = _active_tile(instance_id)
	if tile == null:
		return ContaminationResultScript.new(ContaminationResultScript.INVALID_TILE)
	if tile.is_contaminated():
		return ContaminationResultScript.new(ContaminationResultScript.ALREADY_CONTAMINATED, tile)
	if not tile.apply_contamination(definition):
		return ContaminationResultScript.new(ContaminationResultScript.INVALID_CONTAMINATION, tile)
	var event_sequence := _sequence(sequence_index)
	var event := DomainEventScript.new(DomainEventScript.CONTAMINATION_APPLIED, {
		"instance_id": tile.instance_id,
		"definition_id": tile.definition_id,
		"contamination_id": tile.contamination_id,
		"origin": tile.origin,
		"lifetime": tile.lifetime,
		"configured_effect": definition.configured_effect,
		"sequence_index": event_sequence,
	})
	return ContaminationResultScript.new(ContaminationResultScript.ACCEPTED, tile, [event])

func apply(instance_id: String, contamination, sequence_index: int = -1):
	return apply_contamination(instance_id, contamination, sequence_index)

func inject_contamination(
	instance_id: String,
	tile_definition_id: String,
	contamination,
	target_zone: String = TileZoneScript.DRAW_WALL,
	sequence_index: int = -1,
):
	var definition = _normalize_definition(contamination)
	if definition == null or not definition.is_valid():
		return ContaminationResultScript.new(ContaminationResultScript.INVALID_CONTAMINATION)
	if instance_id.is_empty() or tile_definition_id.is_empty() or zones == null:
		return ContaminationResultScript.new(ContaminationResultScript.INVALID_TILE)
	if not TileZoneScript.all().has(target_zone) or target_zone == TileZoneScript.TILE_POOL or zones.contains(instance_id):
		return ContaminationResultScript.new(ContaminationResultScript.INVALID_TILE)
	var tile := TileInstanceScript.new(instance_id, tile_definition_id, definition.origin, definition.lifetime)
	if not tile.apply_contamination(definition):
		return ContaminationResultScript.new(ContaminationResultScript.INVALID_CONTAMINATION)
	if not zones.add(tile, target_zone):
		return ContaminationResultScript.new(ContaminationResultScript.TRANSFER_FAILED)
	var injection_sequence := _sequence(sequence_index)
	var contamination_sequence := _sequence(sequence_index)
	var events: Array = [DomainEventScript.new(DomainEventScript.TILE_INJECTED, {
		"instance_id": tile.instance_id,
		"definition_id": tile.definition_id,
		"target_zone": target_zone,
		"contamination_id": definition.contamination_id,
		"sequence_index": injection_sequence,
	}), DomainEventScript.new(DomainEventScript.CONTAMINATION_APPLIED, {
		"instance_id": tile.instance_id,
		"definition_id": tile.definition_id,
		"contamination_id": tile.contamination_id,
		"origin": tile.origin,
		"lifetime": tile.lifetime,
		"configured_effect": definition.configured_effect,
		"sequence_index": contamination_sequence,
	})]
	return ContaminationResultScript.new(ContaminationResultScript.ACCEPTED, tile, events)

func inject(instance_id: String, tile_definition_id: String, contamination, target_zone: String = TileZoneScript.DRAW_WALL, sequence_index: int = -1):
	return inject_contamination(instance_id, tile_definition_id, contamination, target_zone, sequence_index)

func observe(instance_id: String):
	var tile = _active_tile(instance_id)
	return tile if tile != null and tile.is_contaminated() else null

func observe_contamination(instance_id: String):
	var tile = observe(instance_id)
	return tile.contamination if tile != null else null

func contamination_for(instance_id: String):
	return observe_contamination(instance_id)

func exhaust_contamination(instance_id: String, sequence_index: int = -1):
	var tile_result = _validate_contaminated_tile(instance_id)
	if not tile_result.get("valid", false):
		return ContaminationResultScript.new(tile_result.get("status", ContaminationResultScript.INVALID_TILE), tile_result.get("tile"))
	var tile = tile_result["tile"]
	if not tile.can_exhaust_contamination:
		return ContaminationResultScript.new(ContaminationResultScript.CANNOT_EXHAUST, tile)
	var source_zone: String = zones.zone_of(instance_id)
	if source_zone == TileZoneScript.EXHAUST or not zones.transfer(instance_id, source_zone, TileZoneScript.EXHAUST):
		return ContaminationResultScript.new(ContaminationResultScript.TRANSFER_FAILED, tile)
	var event_sequence := _sequence(sequence_index)
	return ContaminationResultScript.new(ContaminationResultScript.ACCEPTED, tile, [DomainEventScript.new(DomainEventScript.TILE_EXHAUSTED, {
		"instance_id": tile.instance_id,
		"definition_id": tile.definition_id,
		"contamination_id": tile.contamination_id,
		"source_zone": source_zone,
		"target_zone": TileZoneScript.EXHAUST,
		"operation": "CONTAMINATION_EXHAUST",
		"lifecycle_cleanup": false,
		"sequence_index": event_sequence,
	})])

func exhaust(instance_id: String, sequence_index: int = -1):
	return exhaust_contamination(instance_id, sequence_index)

func purge_contamination(instance_id: String, sequence_index: int = -1):
	var tile_result = _validate_contaminated_tile(instance_id)
	if not tile_result.get("valid", false):
		return ContaminationResultScript.new(tile_result.get("status", ContaminationResultScript.INVALID_TILE), tile_result.get("tile"))
	var tile = tile_result["tile"]
	if not tile.can_purge_contamination:
		return ContaminationResultScript.new(ContaminationResultScript.CANNOT_PURGE, tile)
	var source_zone: String = zones.zone_of(instance_id)
	if not zones.purge(instance_id):
		return ContaminationResultScript.new(ContaminationResultScript.TRANSFER_FAILED, tile)
	var event_sequence := _sequence(sequence_index)
	return ContaminationResultScript.new(ContaminationResultScript.ACCEPTED, tile, [DomainEventScript.new(DomainEventScript.TILE_PURGED, {
		"instance_id": tile.instance_id,
		"definition_id": tile.definition_id,
		"contamination_id": tile.contamination_id,
		"source_zone": source_zone,
		"target_zone": TileZoneScript.PURGED,
		"operation": "CONTAMINATION_PURGE",
		"lifecycle_cleanup": false,
		"sequence_index": event_sequence,
	})])

func purge(instance_id: String, sequence_index: int = -1):
	return purge_contamination(instance_id, sequence_index)

func cleanup_battle(sequence_index: int = -1) -> Array:
	var events: Array = []
	if zones == null:
		return events
	var tiles: Array = []
	for zone in TileZoneScript.all():
		for tile in zones.contents(zone):
			if tile is TileInstanceScript and tile.is_contaminated() and TileLifetimeScript.is_battle_only(tile.lifetime):
				tiles.append(tile)
	tiles.sort_custom(func(left, right): return left.instance_id < right.instance_id)
	for tile in tiles:
		var source_zone: String = zones.zone_of(tile.instance_id)
		var contamination_id: String = tile.contamination_id
		var cleanup_action := "CLEARED"
		var removed_from_battle := false
		if tile.base_lifetime != TileLifetimeScript.RUN and tile.cleanup_policy != ContaminationCleanupPolicyScript.CLEAR_CONTAMINATION:
			removed_from_battle = zones.purge(tile.instance_id)
			cleanup_action = "REMOVED"
		tile.clear_contamination()
		var event_sequence := _sequence(sequence_index)
		events.append(DomainEventScript.new(DomainEventScript.BATTLE_CONTAMINATION_CLEANED, {
			"instance_id": tile.instance_id,
			"definition_id": tile.definition_id,
			"contamination_id": contamination_id,
			"source_zone": source_zone,
			"target_zone": TileZoneScript.PURGED if removed_from_battle else source_zone,
			"cleanup_action": cleanup_action,
			"lifecycle_cleanup": true,
			"reward_triggers": false,
			"sequence_index": event_sequence,
		}))
	return events

func cleanup(sequence_index: int = -1) -> Array:
	return cleanup_battle(sequence_index)

func _validate_contaminated_tile(instance_id: String) -> Dictionary:
	var tile = _active_tile(instance_id)
	if tile == null:
		return {"valid": false, "status": ContaminationResultScript.INVALID_TILE}
	if not tile.is_contaminated():
		return {"valid": false, "status": ContaminationResultScript.NOT_CONTAMINATED, "tile": tile}
	return {"valid": true, "tile": tile}

func _active_tile(instance_id: String):
	if zones == null or instance_id.is_empty() or not zones.contains(instance_id):
		return null
	var zone: String = zones.zone_of(instance_id)
	if not TileZoneScript.all().has(zone):
		return null
	for tile in zones.contents(zone):
		if tile is TileInstanceScript and tile.instance_id == instance_id:
			return tile
	return null

func _normalize_definition(contamination):
	if contamination is ContaminationDefinitionScript:
		return contamination
	if contamination is Dictionary:
		return ContaminationDefinitionScript.from_dictionary(contamination)
	if contamination is String and not contamination.is_empty():
		return ContaminationDefinitionScript.new(contamination)
	return null

func _sequence(sequence_index: int) -> int:
	if sequence_index >= 0:
		return sequence_index
	_sequence_index += 1
	return _sequence_index
