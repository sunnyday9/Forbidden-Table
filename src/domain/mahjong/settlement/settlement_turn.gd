class_name SettlementTurn
extends RefCounted

const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")
const PartialSettlementResultScript = preload("res://src/domain/mahjong/settlement/partial_settlement_result.gd")
const SettlementTurnResultScript = preload("res://src/domain/mahjong/settlement/settlement_turn_result.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var _settlement_window
var _tile_actions
var _zones
var _hand_baseline: int
var _settled_instance_ids: Dictionary = {}
var _settlement_resolved := false
var _ended := false
var _last_result
var _end_result

func _init(settlement_window, tile_actions, zones, hand_baseline: int) -> void:
	_settlement_window = settlement_window
	_tile_actions = tile_actions
	_zones = zones
	_hand_baseline = maxi(0, hand_baseline)

func resolve_partial_settlement(selected_instance_ids: Array, combat_output = null):
	if _ended:
		return _result(
			SettlementTurnResultScript.TURN_ENDED,
			null,
			[],
			0,
			0,
			0,
			combat_output,
		)

	for instance_id in selected_instance_ids:
		if _settled_instance_ids.has(instance_id):
			var already_settled = PartialSettlementResultScript.new(PartialSettlementResultScript.TILE_ALREADY_SETTLED)
			return _result(SettlementTurnResultScript.SETTLEMENT_REJECTED, already_settled, [], 0, 0, 0, combat_output)
	if _settlement_resolved:
		return _result(SettlementTurnResultScript.SETTLEMENT_ALREADY_RESOLVED, null, [], 0, 0, 0, combat_output)

	var settlement_result = _settlement_window.resolve(selected_instance_ids)
	if not settlement_result.is_accepted():
		_last_result = _result(SettlementTurnResultScript.SETTLEMENT_REJECTED, settlement_result, [], 0, 0, 0, combat_output)
		return _last_result

	for instance_id in settlement_result.settled_pattern.tile_instance_ids:
		_settled_instance_ids[instance_id] = true
	_settlement_resolved = true

	var replacement_requested := maxi(0, _hand_baseline - _zones.size(TileZoneScript.HAND))
	var replacement_draws: Array = []
	for _draw_index in range(replacement_requested):
		var draw_result = _tile_actions.draw(DrawSourceScript.SETTLEMENT_REPLACEMENT)
		replacement_draws.append(draw_result)
		if not draw_result.is_accepted():
			break

	var replacement_drawn := replacement_requested - _replacement_shortfall(replacement_requested, replacement_draws)
	var replacement_shortfall := replacement_requested - replacement_drawn
	_settlement_window.refresh()
	var result_status := SettlementTurnResultScript.COMPLETED
	if replacement_shortfall > 0:
		result_status = SettlementTurnResultScript.DRAW_EXHAUSTED
	_last_result = _result(
		result_status,
		settlement_result,
		replacement_draws,
		replacement_requested,
		replacement_drawn,
		replacement_shortfall,
		combat_output,
	)
	return _last_result

func end_turn(combat_output = null):
	if _ended:
		return _end_result
	_ended = true
	if _settlement_window != null:
		_settlement_window.refresh()
	var prior_settlement = null
	var prior_draws: Array = []
	var prior_requested := 0
	var prior_drawn := 0
	var prior_shortfall := 0
	var prior_combat_output = combat_output
	if _last_result != null:
		prior_settlement = _last_result.settlement_result
		prior_draws = _last_result.replacement_draws
		prior_requested = _last_result.replacement_requested
		prior_drawn = _last_result.replacement_drawn
		prior_shortfall = _last_result.replacement_shortfall
		if prior_combat_output == null:
			prior_combat_output = _last_result.combat_output
	_end_result = _result(
		SettlementTurnResultScript.END_TURN,
		prior_settlement,
		prior_draws,
		prior_requested,
		prior_drawn,
		prior_shortfall,
		prior_combat_output,
	)
	return _end_result

func settled_instance_ids() -> Array[String]:
	var ids: Array[String] = []
	for instance_id in _settled_instance_ids.keys():
		ids.append(instance_id)
	ids.sort()
	return ids

func _replacement_shortfall(requested: int, draw_results: Array) -> int:
	var drawn := 0
	for draw_result in draw_results:
		drawn += draw_result.drawn
	return requested - drawn

func _result(
	result_status: String,
	settlement_result,
	replacement_draws: Array,
	replacement_requested: int,
	replacement_drawn: int,
	replacement_shortfall: int,
	combat_output = null,
):
	var candidates: Array = []
	if _settlement_window != null:
		candidates = _settlement_window.candidates()
	return SettlementTurnResultScript.new(
		result_status,
		settlement_result,
		replacement_draws,
		replacement_requested,
		replacement_drawn,
		replacement_shortfall,
		candidates,
		settled_instance_ids(),
		combat_output,
		true,
	)
