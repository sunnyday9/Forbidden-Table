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

	var validation_result = validate(candidates, selected_instance_ids, settled_instance_ids)
	if not validation_result.is_accepted():
		return validation_result

	var matching_candidate = _matching_candidate(candidates, selected_instance_ids)
	return _resolve_candidate(matching_candidate)

func resolve_candidate(candidates: Array, candidate_id: String, settled_instance_ids: Dictionary):
	if _zones == null:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.TRANSFER_FAILED)

	var validation_result = validate_candidate(candidates, candidate_id, settled_instance_ids)
	if not validation_result.is_accepted():
		return validation_result

	return _resolve_candidate(_candidate_by_id(candidates, candidate_id))

func _resolve_candidate(matching_candidate):
	var transferred_ids: Array[String] = []
	for tile_instance in matching_candidate.tile_instances:
		if not _zones.transfer(tile_instance.instance_id, TileZoneScript.HAND, TileZoneScript.DISCARD):
			_rollback(transferred_ids)
			return PartialSettlementResultScript.new(PartialSettlementResultScript.TRANSFER_FAILED)
		transferred_ids.append(tile_instance.instance_id)

	return _accepted_result(matching_candidate)

func validate(candidates: Array, selected_instance_ids: Array, settled_instance_ids: Dictionary):
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

	if _matching_candidate(candidates, selected_instance_ids) == null:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.INVALID_SELECTION)
	return PartialSettlementResultScript.new(PartialSettlementResultScript.ACCEPTED)

func validate_candidate(candidates: Array, candidate_id: String, settled_instance_ids: Dictionary):
	if _zones == null:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.TRANSFER_FAILED)
	var matching_candidate = _candidate_by_id(candidates, candidate_id)
	if matching_candidate == null:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.INVALID_SELECTION)
	for tile_instance in matching_candidate.tile_instances:
		if settled_instance_ids.has(tile_instance.instance_id):
			return PartialSettlementResultScript.new(PartialSettlementResultScript.TILE_ALREADY_SETTLED)
		if not _zones.contains(tile_instance.instance_id):
			return PartialSettlementResultScript.new(PartialSettlementResultScript.INVALID_SELECTION)
		if not _zones.contains_in_zone(tile_instance.instance_id, TileZoneScript.HAND):
			return PartialSettlementResultScript.new(PartialSettlementResultScript.STALE_SELECTION)
	return PartialSettlementResultScript.new(PartialSettlementResultScript.ACCEPTED)

func _matching_candidate(candidates: Array, selected_instance_ids: Array):
	var matching_candidate = null
	var matching_count := 0
	for candidate in candidates:
		if _same_instance_ids(candidate.tile_instances, selected_instance_ids):
			matching_candidate = candidate
			matching_count += 1
	if matching_count != 1:
		return null
	return matching_candidate

func _candidate_by_id(candidates: Array, candidate_id: String):
	for candidate in candidates:
		if candidate.candidate_id == candidate_id:
			return candidate
	return null

func _accepted_result(matching_candidate):
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
