class_name SettlementTurn
extends RefCounted

const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")
const CombatResolutionTriggerScript = preload("res://src/domain/combat/combat_resolution_trigger.gd")
const CombatResolverScript = preload("res://src/domain/combat/combat_resolver.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const EffectTriggerScript = preload("res://src/domain/effects/effect_trigger.gd")
const SettlementTurnResultScript = preload("res://src/domain/mahjong/settlement/settlement_turn_result.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

var _settlement_window
var _tile_actions
var _zones
var _hand_baseline: int
var _settled_instance_ids: Dictionary = {}
var _ended := false
var _last_result
var _end_result
var _settlement_trigger_context
var _settlement_trigger_data: Dictionary = {}

func _init(
	settlement_window,
	tile_actions,
	zones,
	hand_baseline: int,
	settlement_capacity = null,
	settlement_trigger_context = null,
) -> void:
	_settlement_window = settlement_window
	_tile_actions = tile_actions
	_zones = zones
	_hand_baseline = maxi(0, hand_baseline)
	_settlement_trigger_context = settlement_trigger_context
	if settlement_capacity != null and _settlement_window != null:
		_settlement_window.set_settlement_capacity(settlement_capacity)

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
	if combat_output == null and _last_result != null:
		combat_output = _last_result.combat_output

	var settlement_result = _settlement_window.resolve(selected_instance_ids)
	return _finish_settlement(settlement_result, combat_output)

func resolve_partial_settlement_candidate(candidate_id: String, combat_output = null):
	if _ended:
		return _result(SettlementTurnResultScript.TURN_ENDED, null, [], 0, 0, 0, combat_output)
	if combat_output == null and _last_result != null:
		combat_output = _last_result.combat_output
	var settlement_result = _settlement_window.resolve_candidate(candidate_id)
	return _finish_settlement(settlement_result, combat_output)

func _finish_settlement(settlement_result, combat_output):
	if not settlement_result.is_accepted():
		var result_status := SettlementTurnResultScript.SETTLEMENT_REJECTED
		if settlement_result.is_capacity_exhausted():
			result_status = SettlementTurnResultScript.CAPACITY_EXHAUSTED
		_last_result = _result(result_status, settlement_result, [], 0, 0, 0, combat_output)
		return _last_result

	var events: Array = settlement_result.events
	events.append_array(_resolve_settlement_triggers(settlement_result.settled_pattern))
	var replacement_requested := maxi(0, _hand_baseline - _zones.size(TileZoneScript.HAND))
	var replacement_draws: Array = []
	for _draw_index in range(replacement_requested):
		var draw_result = _tile_actions.draw(DrawSourceScript.SETTLEMENT_REPLACEMENT)
		replacement_draws.append(draw_result)
		if draw_result.shortfall > 0:
			break

	var replacement_drawn := replacement_requested - _replacement_shortfall(replacement_requested, replacement_draws)
	var replacement_shortfall := replacement_requested - replacement_drawn
	_settlement_window.refresh()
	var result_status := SettlementTurnResultScript.COMPLETED
	if _settlement_window.settlement_capacity().remaining == 0:
		result_status = SettlementTurnResultScript.CAPACITY_EXHAUSTED
	elif replacement_shortfall > 0:
		result_status = SettlementTurnResultScript.DRAW_EXHAUSTED
	_settled_instance_ids = _settled_ids_from_window()
	for replacement_draw in replacement_draws:
		events.append_array(replacement_draw.events)
	_last_result = _result(
		result_status,
		settlement_result,
		replacement_draws,
		replacement_requested,
		replacement_drawn,
		replacement_shortfall,
		combat_output,
		events,
	)
	return _last_result

func _resolve_settlement_triggers(settled_pattern) -> Array:
	var trigger_data := {
		"pattern_type": settled_pattern.pattern_type,
		"instance_ids": settled_pattern.tile_instance_ids,
	}
	if _settlement_trigger_context == null or _settlement_trigger_context.state == null:
		return [DomainEventScript.new(DomainEventScript.SETTLEMENT_TRIGGERS_RESOLVED, trigger_data)]

	_settlement_trigger_data = trigger_data
	var queue = CombatResolverScript.new().begin_queue(
		_settlement_trigger_context.state,
		256,
		_settlement_trigger_context,
		"",
	)
	var trigger := CombatResolutionTriggerScript.new(
		EffectTriggerScript.SETTLEMENT,
		Callable(self, "_resolve_settlement_trigger"),
	)
	if not queue.enqueue_trigger(trigger):
		_settlement_trigger_data = {}
		return [DomainEventScript.new(DomainEventScript.SETTLEMENT_TRIGGERS_RESOLVED, trigger_data)]
	var trigger_result = queue.drain()
	_settlement_trigger_data = {}
	if trigger_result.is_resolved() and not trigger_result.events.is_empty():
		return trigger_result.events
	return [DomainEventScript.new(DomainEventScript.SETTLEMENT_TRIGGERS_RESOLVED, trigger_data)]

func _resolve_settlement_trigger(_queue, _state, sequence_index: int) -> Array:
	var event_data := _settlement_trigger_data.duplicate(true)
	event_data["sequence_index"] = sequence_index
	return [DomainEventScript.new(DomainEventScript.SETTLEMENT_TRIGGERS_RESOLVED, event_data)]

func end_turn(combat_output = null):
	if _ended:
		return _end_result
	_ended = true
	if _settlement_window != null:
		_settlement_window.refresh()
		_settlement_window.close()
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
		_last_result.events if _last_result != null else [],
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
	events: Array = [],
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
		events,
		_settlement_window.settlement_capacity().maximum if _settlement_window != null else 0,
		_settlement_window.settlement_capacity().remaining if _settlement_window != null else 0,
	)

func _settled_ids_from_window() -> Dictionary:
	var ids: Dictionary = {}
	if _settlement_window == null:
		return ids
	for instance_id in _settlement_window.settled_instance_ids():
		ids[instance_id] = true
	return ids
