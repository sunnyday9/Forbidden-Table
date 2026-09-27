class_name SettlementTurn
extends RefCounted

const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")
const CombatResolutionTriggerScript = preload("res://src/domain/combat/combat_resolution_trigger.gd")
const CombatResolverScript = preload("res://src/domain/combat/combat_resolver.gd")
const BuildEffectResolverScript = preload("res://src/domain/battle/build_effect_resolver.gd")
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
var _build_effect_resolver
var _settlement_trigger_data: Dictionary = {}
var _last_trigger_accepted := true
var _last_trigger_failure: Dictionary = {}

func _init(
	settlement_window,
	tile_actions,
	zones,
	hand_baseline: int,
	settlement_capacity = null,
	settlement_trigger_context = null,
	build_effect_resolver = null,
) -> void:
	_settlement_window = settlement_window
	_tile_actions = tile_actions
	_zones = zones
	_hand_baseline = maxi(0, hand_baseline)
	_settlement_trigger_context = settlement_trigger_context
	_build_effect_resolver = build_effect_resolver if build_effect_resolver is BuildEffectResolverScript else null
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
	if not _last_trigger_accepted:
		_last_result = _result("BUILD_EFFECT_REJECTED", null, [], 0, 0, 0, combat_output)
		return _last_result
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
	_last_trigger_accepted = true
	_last_trigger_failure = {}
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
	_last_trigger_accepted = trigger_result.is_resolved()
	if not _last_trigger_accepted:
		_last_trigger_failure = {
			"reason": trigger_result.status,
			"diagnostics": trigger_result.diagnostics.duplicate(true),
		}
		return []
	if _build_effect_resolver != null:
		_build_effect_resolver.sync_capacity_services(
			_settlement_trigger_context.state,
			_settlement_trigger_context.reserve_service,
			_settlement_window,
			trigger_result.events,
		)
	if trigger_result.is_resolved() and not trigger_result.events.is_empty():
		return trigger_result.events
	return [DomainEventScript.new(DomainEventScript.SETTLEMENT_TRIGGERS_RESOLVED, trigger_data)]

func _resolve_settlement_trigger(_queue, _state, sequence_index: int) -> Array:
	var event_data := _settlement_trigger_data.duplicate(true)
	event_data["sequence_index"] = sequence_index
	if _build_effect_resolver != null and _settlement_trigger_context != null:
		var result: Dictionary = _build_effect_resolver.enqueue_tile_modifier_effects(
			_queue,
			_settlement_trigger_context,
			_settlement_trigger_data.get("instance_ids", []),
		)
		if not result.get("accepted", false):
			_queue.fail("BUILD_EFFECT_REJECTED", {
				"effect_id": str(result.get("effect_id", "")),
				"reason": str(result.get("reason", "BUILD_EFFECT_REJECTED")),
			})
			return []
	return [DomainEventScript.new(DomainEventScript.SETTLEMENT_TRIGGERS_RESOLVED, event_data)]

func validate_tile_modifier_effects(instance_ids: Array) -> Dictionary:
	if _build_effect_resolver == null or _settlement_trigger_context == null:
		return {"accepted": true}
	return _build_effect_resolver.validate_tile_modifier_effects(_settlement_trigger_context, instance_ids)

func resolve_tile_modifier_effects(instance_ids: Array, lifecycle_boundary: String = "") -> Dictionary:
	if _build_effect_resolver == null or _settlement_trigger_context == null:
		return {"accepted": true, "events": []}
	var selection: Dictionary = validate_tile_modifier_effects(instance_ids)
	if not selection.get("accepted", false):
		return {"accepted": false, "reason": str(selection.get("reason", "BUILD_EFFECT_REJECTED")), "effect_id": str(selection.get("effect_id", "")), "events": []}
	if selection.get("entries", []).is_empty():
		return {"accepted": true, "events": []}
	var queue = CombatResolverScript.new().begin_queue(
		_settlement_trigger_context.state,
		256,
		_settlement_trigger_context,
		lifecycle_boundary,
	)
	var enqueue_result: Dictionary = _build_effect_resolver.enqueue_tile_modifier_effects(queue, _settlement_trigger_context, instance_ids)
	if not enqueue_result.get("accepted", false):
		queue.fail("BUILD_EFFECT_REJECTED", {
			"effect_id": str(enqueue_result.get("effect_id", "")),
			"reason": str(enqueue_result.get("reason", "BUILD_EFFECT_REJECTED")),
		})
	var result = queue.drain()
	if not result.is_resolved():
		return {"accepted": false, "reason": result.status, "events": result.events.duplicate()}
	_build_effect_resolver.sync_capacity_services(
		_settlement_trigger_context.state,
		_settlement_trigger_context.reserve_service,
		_settlement_window,
		result.events,
	)
	return {"accepted": true, "events": result.events.duplicate()}

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

func transaction_snapshot() -> Dictionary:
	return {
		"ended": _ended,
		"last_result": _last_result,
		"end_result": _end_result,
		"trigger_accepted": _last_trigger_accepted,
		"trigger_failure": _last_trigger_failure.duplicate(true),
		"settlement_trigger_data": _settlement_trigger_data.duplicate(true),
	}

func restore_transaction_snapshot(snapshot: Dictionary) -> void:
	_ended = bool(snapshot.get("ended", _ended))
	_last_result = snapshot.get("last_result", _last_result)
	_end_result = snapshot.get("end_result", _end_result)
	_last_trigger_accepted = bool(snapshot.get("trigger_accepted", _last_trigger_accepted))
	_last_trigger_failure = snapshot.get("trigger_failure", _last_trigger_failure).duplicate(true)
	_settlement_trigger_data = snapshot.get("settlement_trigger_data", _settlement_trigger_data).duplicate(true)

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
