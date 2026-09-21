class_name SettlementWindow
extends RefCounted

const PartialSettlementResultScript = preload("res://src/domain/mahjong/settlement/partial_settlement_result.gd")
const PartialSettlementScript = preload("res://src/domain/mahjong/settlement/partial_settlement.gd")
const PatternCandidateScript = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var _pattern_evaluator
var _zones
var _partial_settlement
var _open := false
var _candidates: Array = []
var _settled_instance_ids: Dictionary = {}

func _init(pattern_evaluator, zones) -> void:
	_pattern_evaluator = pattern_evaluator
	_zones = zones
	_partial_settlement = PartialSettlementScript.new(zones)

func open() -> bool:
	if _open:
		return true
	_refresh_candidates()
	_open = not _candidates.is_empty()
	return _open

func is_open() -> bool:
	return _open

func candidates() -> Array:
	return _candidates.duplicate()

func refresh() -> void:
	if not _open:
		return
	_refresh_candidates()

func resolve(selected_instance_ids: Array):
	if not _open:
		return PartialSettlementResultScript.new(PartialSettlementResultScript.WINDOW_CLOSED)
	_refresh_candidates()
	var result = _partial_settlement.resolve(
		_candidates,
		selected_instance_ids,
		_settled_instance_ids,
	)
	if result.is_accepted():
		for instance_id in result.settled_pattern.tile_instance_ids:
			_settled_instance_ids[instance_id] = true
		_refresh_candidates()
	return result

func _refresh_candidates() -> void:
	_candidates = []
	if _pattern_evaluator == null or _zones == null:
		return
	for candidate in _pattern_evaluator.evaluate(_zones.contents(TileZoneScript.HAND)):
		if not [PatternCandidateScript.SEQUENCE, PatternCandidateScript.TRIPLET, PatternCandidateScript.QUAD].has(candidate.pattern_type):
			continue
		if _uses_settled_tile(candidate):
			continue
		_candidates.append(candidate)

func _uses_settled_tile(candidate) -> bool:
	for tile_instance in candidate.tile_instances:
		if _settled_instance_ids.has(tile_instance.instance_id):
			return true
	return false
