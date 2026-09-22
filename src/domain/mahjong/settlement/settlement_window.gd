class_name SettlementWindow
extends RefCounted

const PartialSettlementResultScript = preload("res://src/domain/mahjong/settlement/partial_settlement_result.gd")
const PartialSettlementScript = preload("res://src/domain/mahjong/settlement/partial_settlement.gd")
const PatternCandidateScript = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const SettlementCapacityScript = preload("res://src/domain/mahjong/settlement/settlement_capacity.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var _pattern_evaluator
var _zones
var _partial_settlement
var _open := false
var _candidates: Array = []
var _settled_instance_ids: Dictionary = {}
var _known_candidate_ids: Dictionary = {}
var _settlement_capacity
var _allow_tile_overlap := false

func _init(pattern_evaluator, zones, settlement_capacity = null, settlement_rules: Dictionary = {}) -> void:
	_pattern_evaluator = pattern_evaluator
	_zones = zones
	_partial_settlement = PartialSettlementScript.new(zones)
	_settlement_capacity = settlement_capacity
	if _settlement_capacity == null:
		_settlement_capacity = SettlementCapacityScript.new()
	elif not _settlement_capacity.has_method("reset"):
		_settlement_capacity = SettlementCapacityScript.new(_settlement_capacity)
	_allow_tile_overlap = bool(settlement_rules.get("allow_tile_overlap", false)) or bool(settlement_rules.get("allow_settled_tile_overlap", false))

func open() -> bool:
	if _open:
		return true
	_settlement_capacity.reset()
	_settled_instance_ids = {}
	_known_candidate_ids = {}
	_refresh_candidates()
	_open = not _candidates.is_empty() and _settlement_capacity.can_spend()
	return _open

func is_open() -> bool:
	return _open

func candidates() -> Array:
	return _candidates.duplicate()

func settlement_capacity():
	return _settlement_capacity

func set_settlement_capacity(settlement_capacity) -> void:
	if settlement_capacity == null:
		return
	if not settlement_capacity.has_method("reset"):
		settlement_capacity = SettlementCapacityScript.new(settlement_capacity)
	_settlement_capacity = settlement_capacity

func has_capacity() -> bool:
	return _open and _settlement_capacity.can_spend()

func settled_instance_ids() -> Array[String]:
	var ids: Array[String] = []
	for instance_id in _settled_instance_ids.keys():
		ids.append(instance_id)
	ids.sort()
	return ids

func close() -> void:
	_open = false

func validate(selected_instance_ids: Array):
	if not _open:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.WINDOW_CLOSED)
	if not _settlement_capacity.can_spend():
		return PartialSettlementResultScript.new(PartialSettlementResultScript.CAPACITY_EXHAUSTED)
	_refresh_candidates()
	return _partial_settlement.validate(
		_candidates,
		selected_instance_ids,
		_settled_instance_ids if not _allow_tile_overlap else {},
	)

func validate_candidate(candidate_id: String):
	if not _open:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.WINDOW_CLOSED)
	if not _settlement_capacity.can_spend():
		return PartialSettlementResultScript.new(PartialSettlementResultScript.CAPACITY_EXHAUSTED)
	_refresh_candidates()
	var validation = _partial_settlement.validate_candidate(
		_candidates,
		candidate_id,
		_settled_instance_ids if not _allow_tile_overlap else {},
	)
	if validation.status == PartialSettlementResultScript.INVALID_SELECTION and _known_candidate_ids.has(candidate_id):
		return PartialSettlementResultScript.new(PartialSettlementResultScript.STALE_SELECTION)
	return validation

func refresh() -> void:
	if not _open:
		return
	_refresh_candidates()

func resolve(selected_instance_ids: Array):
	if not _open:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.WINDOW_CLOSED)
	if not _settlement_capacity.can_spend():
		return PartialSettlementResultScript.new(PartialSettlementResultScript.CAPACITY_EXHAUSTED)
	_refresh_candidates()
	var result = _partial_settlement.resolve(
		_candidates,
		selected_instance_ids,
		_settled_instance_ids if not _allow_tile_overlap else {},
	)
	if result.is_accepted():
		_settlement_capacity.consume()
		for instance_id in result.settled_pattern.tile_instance_ids:
			_settled_instance_ids[instance_id] = true
		_refresh_candidates()
	return result

func resolve_candidate(candidate_id: String):
	if not _open:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.WINDOW_CLOSED)
	if not _settlement_capacity.can_spend():
		return PartialSettlementResultScript.new(PartialSettlementResultScript.CAPACITY_EXHAUSTED)
	_refresh_candidates()
	var result = _partial_settlement.resolve_candidate(
		_candidates,
		candidate_id,
		_settled_instance_ids if not _allow_tile_overlap else {},
	)
	if result.status == PartialSettlementResultScript.INVALID_SELECTION and _known_candidate_ids.has(candidate_id):
		return PartialSettlementResultScript.new(PartialSettlementResultScript.STALE_SELECTION)
	if result.is_accepted():
		_settlement_capacity.consume()
		for instance_id in result.settled_pattern.tile_instance_ids:
			_settled_instance_ids[instance_id] = true
		_refresh_candidates()
	return result

func _refresh_candidates() -> void:
	for candidate in _candidates:
		_known_candidate_ids[candidate.candidate_id] = true
	_candidates = []
	if _pattern_evaluator == null or _zones == null:
		return
	for candidate in _pattern_evaluator.evaluate(_zones.contents(TileZoneScript.HAND)):
		if not [PatternCandidateScript.SEQUENCE, PatternCandidateScript.TRIPLET, PatternCandidateScript.QUAD].has(candidate.pattern_type):
			continue
		if not _allow_tile_overlap and _uses_settled_tile(candidate):
			continue
		_candidates.append(candidate)

func _uses_settled_tile(candidate) -> bool:
	for tile_instance in candidate.tile_instances:
		if _settled_instance_ids.has(tile_instance.instance_id):
			return true
	return false
