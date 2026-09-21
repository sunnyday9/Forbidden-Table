class_name PartialSettlement
extends RefCounted

const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const PartialSettlementResultScript = preload("res://src/domain/mahjong/settlement/partial_settlement_result.gd")
const SettledPatternScript = preload("res://src/domain/mahjong/settlement/settled_pattern.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var _zones

func _init(zones) -> void:
	_zones = zones

func resolve(candidates: Array, selected_instance_ids: Array, settled_instance_ids: Dictionary):
	if _zones == null:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.TRANSFER_FAILED)

	var duplicate_ids: Dictionary = {}
	for instance_id in selected_instance_ids:
		if not instance_id is String or instance_id.is_empty():
			return PartialSettlementResultScript.new(PartialSettlementResultScript.INVALID_SELECTION)
		if duplicate_ids.has(instance_id):
			return PartialSettlementResultScript.new(PartialSettlementResultScript.DUPLICATE_SELECTION)
		duplicate_ids[instance_id] = true

	for instance_id in selected_instance_ids:
		if settled_instance_ids.has(instance_id):
			return PartialSettlementResultScript.new(PartialSettlementResultScript.TILE_ALREADY_SETTLED)
		if not _zones.contains(instance_id):
			return PartialSettlementResultScript.new(PartialSettlementResultScript.INVALID_SELECTION)
		if not _zones.contains_in_zone(instance_id, TileZoneScript.HAND):
			return PartialSettlementResultScript.new(PartialSettlementResultScript.STALE_SELECTION)

	var matching_candidate = null
	var matching_count := 0
	for candidate in candidates:
		if _same_instance_ids(candidate.tile_instances, selected_instance_ids):
			matching_candidate = candidate
			matching_count += 1
	if matching_count != 1:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.INVALID_SELECTION)

	var transferred_ids: Array[String] = []
	for tile_instance in matching_candidate.tile_instances:
		if not _zones.transfer(tile_instance.instance_id, TileZoneScript.HAND, TileZoneScript.DISCARD):
			_rollback(transferred_ids)
			return PartialSettlementResultScript.new(PartialSettlementResultScript.TRANSFER_FAILED)
		transferred_ids.append(tile_instance.instance_id)

	var settled_pattern := SettledPatternScript.new(
		matching_candidate.pattern_type,
		matching_candidate.tile_instances,
	)
	var event := DomainEventScript.new(DomainEventScript.PATTERN_SETTLED, {
		"pattern_type": settled_pattern.pattern_type,
		"instance_ids": settled_pattern.tile_instance_ids,
		"definition_ids": settled_pattern.definition_ids,
	})
	return PartialSettlementResultScript.new(
		PartialSettlementResultScript.ACCEPTED,
		settled_pattern,
		[event],
	)

func _same_instance_ids(candidate_tiles: Array, selected_instance_ids: Array) -> bool:
	if candidate_tiles.size() != selected_instance_ids.size():
		return false
	var candidate_ids: Array[String] = []
	for tile_instance in candidate_tiles:
		candidate_ids.append(tile_instance.instance_id)
	candidate_ids.sort()
	var requested_ids: Array = selected_instance_ids.duplicate()
	requested_ids.sort()
	return candidate_ids == requested_ids

func _rollback(transferred_ids: Array[String]) -> void:
	for index in range(transferred_ids.size() - 1, -1, -1):
		_zones.transfer(transferred_ids[index], TileZoneScript.DISCARD, TileZoneScript.HAND)
