class_name BattleDomain
extends RefCounted

const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const CombatConversionProfileScript = preload("res://src/domain/combat/combat_conversion_profile.gd")
const CompleteHandInterpretationScript = preload("res://src/domain/mahjong/complete_hand/complete_hand_interpretation.gd")
const CompleteHandSettlementResultScript = preload("res://src/domain/mahjong/settlement/complete_hand_settlement_result.gd")
const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")
const ReserveActionResultScript = preload("res://src/domain/tiles/reserve_action_result.gd")
const ReserveServiceScript = preload("res://src/domain/tiles/reserve_service.gd")
const RecoveryStateScript = preload("res://src/domain/recovery/recovery_state.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")

var zones
var draw_wall
var tile_actions
var settlement_window
var settlement_turn
var score_resolver
var conversion_resolver
var conversion_profile
var combat_state
var combat_resolver
var reserve_service
var complete_hand_evaluator
var hand_yaku_resolver
var local_yaku_resolver
var recovery_state
var complete_hand_destination: String
var _complete_hand_conversion_profile

func _init(
	domain_zones,
	domain_draw_wall,
	domain_tile_actions,
	domain_settlement_window,
	domain_settlement_turn,
	domain_score_resolver,
	domain_conversion_resolver,
	domain_conversion_profile,
	domain_combat_state,
	domain_combat_resolver,
	domain_reserve_service = null,
	domain_complete_hand_evaluator = null,
	domain_hand_yaku_resolver = null,
	domain_normal_hand_baseline: int = 13,
	domain_recovery_baseline: int = 10,
	domain_complete_hand_destination: String = TileZoneScript.DISCARD,
	domain_local_yaku_resolver = null,
) -> void:
	zones = domain_zones
	draw_wall = domain_draw_wall
	tile_actions = domain_tile_actions
	settlement_window = domain_settlement_window
	settlement_turn = domain_settlement_turn
	score_resolver = domain_score_resolver
	conversion_resolver = domain_conversion_resolver
	conversion_profile = domain_conversion_profile
	combat_state = domain_combat_state
	combat_resolver = domain_combat_resolver
	reserve_service = domain_reserve_service
	complete_hand_evaluator = domain_complete_hand_evaluator
	hand_yaku_resolver = domain_hand_yaku_resolver
	local_yaku_resolver = domain_local_yaku_resolver
	complete_hand_destination = domain_complete_hand_destination
	recovery_state = RecoveryStateScript.new(domain_normal_hand_baseline, domain_recovery_baseline)
	_complete_hand_conversion_profile = _build_complete_hand_conversion_profile()
	if reserve_service == null and tile_actions != null:
		reserve_service = tile_actions.reserve_service
	if reserve_service == null:
		reserve_service = ReserveServiceScript.new(zones, combat_state.reserve_capacity if combat_state != null else 3)
	if combat_state != null:
		combat_state.zones = zones
		combat_state.draw_wall = draw_wall
		reserve_service.set_capacity(combat_state.reserve_capacity)

func execute(command):
	if command == null or not command.has_method("execute"):
		return CommandResultScript.new(
			"",
			"UnknownCommand",
			"",
			"",
			false,
			CommandResultScript.REJECTED,
			CommandValidationScript.new(false, "UNKNOWN_COMMAND", "Unsupported domain command."),
		)
	return command.execute(self)

func validate_draw() -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	if tile_actions == null or draw_wall == null or not draw_wall.is_initialized():
		return CommandValidationScript.new(false, "DRAW_WALL_NOT_READY", "The Draw Wall is not ready.")
	if draw_wall.size() == 0:
		return CommandValidationScript.new(false, "INSUFFICIENT_TILES", "The Draw Wall has no available tiles.")
	return CommandValidationScript.new(true)

func execute_draw() -> Dictionary:
	var draw_result = tile_actions.draw()
	var events: Array = draw_result.events if draw_result.is_accepted() else []
	if draw_result.is_accepted():
		if settlement_window != null:
			settlement_window.open()
	return {
		"accepted": draw_result.is_accepted(),
		"status": draw_result.status,
		"events": events,
	}

func validate_end_turn() -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	return CommandValidationScript.new(true)

func execute_end_turn() -> Dictionary:
	var events: Array = []
	if recovery_state != null and recovery_state.is_recovering():
		events.append(DomainEventScript.new(DomainEventScript.RECOVERY_TURN_ELAPSED, {
			"turns_elapsed": recovery_state.turns_elapsed + 1,
			"hand_size": zones.size(TileZoneScript.HAND),
		}))
		if recovery_state.advance_turn(zones.size(TileZoneScript.HAND)):
			events.append(DomainEventScript.new(DomainEventScript.RECOVERY_ENDED, {
				"turns_elapsed": recovery_state.turns_elapsed,
				"hand_size": zones.size(TileZoneScript.HAND),
				"normal_hand_baseline": recovery_state.normal_hand_baseline,
			}))
	return {
		"accepted": true,
		"status": "RECOVERY_ENDED" if not recovery_state.is_recovering() and not events.is_empty() and events[-1].event_type == DomainEventScript.RECOVERY_ENDED else "TURN_ENDED",
		"events": events,
		"data": {"recovery": recovery_state.to_dictionary()},
	}

func validate_store_tile(instance_id: String) -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	if tile_actions == null or zones == null or not zones.contains_in_zone(instance_id, TileZoneScript.HAND):
		return CommandValidationScript.new(false, ReserveActionResultScript.INVALID_TILE, "The selected TileInstance is not in Hand.")
	if zones.size(TileZoneScript.RESERVE) >= combat_state.reserve_capacity:
		return CommandValidationScript.new(false, ReserveActionResultScript.RESERVE_CAPACITY_REACHED, "Reserve is full.")
	return CommandValidationScript.new(true)

func execute_store_tile(instance_id: String) -> Dictionary:
	var result = tile_actions.store_to_reserve(instance_id)
	return {"accepted": result.is_accepted(), "status": result.status, "events": result.events}

func validate_swap_reserve_tiles(hand_instance_id: String, reserve_instance_id: String) -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	if zones == null or not zones.contains_in_zone(hand_instance_id, TileZoneScript.HAND):
		return CommandValidationScript.new(false, ReserveActionResultScript.INVALID_TILE, "The selected Hand TileInstance is invalid.")
	if not zones.contains_in_zone(reserve_instance_id, TileZoneScript.RESERVE):
		return CommandValidationScript.new(false, ReserveActionResultScript.INVALID_RESERVE_TILE, "The selected Reserve TileInstance is invalid.")
	return CommandValidationScript.new(true)

func execute_swap_reserve_tiles(hand_instance_id: String, reserve_instance_id: String) -> Dictionary:
	var result = tile_actions.swap_with_reserve(hand_instance_id, reserve_instance_id)
	return {"accepted": result.is_accepted(), "status": result.status, "events": result.events}

func can_settle() -> bool:
	if settlement_window != null and settlement_window.is_open():
		settlement_window.refresh()
	return (
		combat_state != null
		and combat_state.is_active()
		and settlement_window != null
		and settlement_window.has_capacity()
		and not settlement_window.candidates().is_empty()
	)

func validate_settlement(selected_instance_ids: Array) -> RefCounted:
	if settlement_window != null and settlement_window.is_open():
		settlement_window.refresh()
	if not can_settle():
		return CommandValidationScript.new(
			false,
			"SETTLEMENT_UNAVAILABLE",
			"No highlighted Pattern can be settled.",
		)
	var selection_result = settlement_window.validate(selected_instance_ids)
	if selection_result == null or not selection_result.is_accepted():
		return CommandValidationScript.new(
			false,
			"SETTLEMENT_REJECTED",
			"The selected Pattern was rejected.",
			{"reason": selection_result.status if selection_result != null else "INVALID_SELECTION"},
		)
	return CommandValidationScript.new(true)

func validate_settlement_candidate(candidate_id: String) -> RefCounted:
	if not can_settle():
		return CommandValidationScript.new(
			false,
			"SETTLEMENT_UNAVAILABLE",
			"No highlighted Pattern can be settled.",
		)
	var selection_result = settlement_window.validate_candidate(candidate_id)
	if selection_result == null or not selection_result.is_accepted():
		return CommandValidationScript.new(
			false,
			"SETTLEMENT_REJECTED",
			"The selected Pattern was rejected.",
			{"reason": selection_result.status if selection_result != null else "INVALID_SELECTION"},
		)
	return CommandValidationScript.new(true)

func complete_hand_interpretations() -> Array:
	if complete_hand_evaluator == null or zones == null:
		return []
	return complete_hand_evaluator.evaluate(zones.contents(TileZoneScript.HAND))

func can_complete_hand() -> bool:
	return combat_state != null and combat_state.is_active() and recovery_state != null and recovery_state.can_complete_hand() and not complete_hand_interpretations().is_empty()

func is_recovering() -> bool:
	return recovery_state != null and recovery_state.is_recovering()

func validate_complete_hand(interpretation_id: String) -> RefCounted:
	if combat_state == null or not combat_state.is_active():
		return CommandValidationScript.new(false, "BATTLE_TERMINAL", "The battle is already over.")
	if recovery_state != null and recovery_state.is_recovering():
		return CommandValidationScript.new(false, "RECOVERY_LOCKED", "Complete Hand is unavailable during Recovery.")
	var interpretation = _complete_hand_by_id(interpretation_id)
	if interpretation == null:
		return CommandValidationScript.new(false, "INVALID_INTERPRETATION", "The selected Complete Hand interpretation is not available.")
	if not _valid_complete_hand_destination():
		return CommandValidationScript.new(false, "INVALID_DESTINATION", "The Complete Hand destination policy is invalid.")
	return CommandValidationScript.new(true)

func execute_complete_hand(interpretation_id: String) -> Dictionary:
	var interpretation = _complete_hand_by_id(interpretation_id)
	if interpretation == null:
		return {"accepted": false, "status": CompleteHandSettlementResultScript.INVALID_INTERPRETATION}
	var settled_ids: Array[String] = []
	for tile_instance in interpretation.tile_instances:
		if not zones.contains_in_zone(tile_instance.instance_id, TileZoneScript.HAND):
			return {"accepted": false, "status": CompleteHandSettlementResultScript.TRANSFER_FAILED}
	for tile_instance in interpretation.tile_instances:
		if not zones.transfer(tile_instance.instance_id, TileZoneScript.HAND, complete_hand_destination):
			for moved_id in settled_ids:
				zones.transfer(moved_id, complete_hand_destination, TileZoneScript.HAND)
			return {"accepted": false, "status": CompleteHandSettlementResultScript.TRANSFER_FAILED}
		settled_ids.append(tile_instance.instance_id)

	var score_result = score_resolver.resolve_complete_hand(interpretation, hand_yaku_resolver, _yaku_state()) if score_resolver != null and score_resolver.has_method("resolve_complete_hand") else score_resolver.resolve(interpretation)
	var combat_output = conversion_resolver.resolve(score_result, _complete_hand_conversion_profile, combat_state.to_dictionary())
	var combat_result = combat_resolver.resolve_combat_conversion(combat_state, combat_output)
	var events: Array = [DomainEventScript.new(DomainEventScript.COMPLETE_HAND_SETTLED, {
		"interpretation_id": interpretation.interpretation_id,
		"hand_type": interpretation.hand_type,
		"instance_ids": settled_ids,
		"destination": complete_hand_destination,
		"score": score_result.total,
	})]
	events.append_array(combat_result.events)
	var recovery_baseline: int = recovery_state.recovery_baseline
	events.append(DomainEventScript.new(DomainEventScript.COMPLETE_HAND_REBUILD_STARTED, {
		"requested": maxi(0, recovery_baseline - zones.size(TileZoneScript.HAND)),
		"source": DrawSourceScript.COMPLETE_HAND_REBUILD,
		"recovery_baseline": recovery_baseline,
	}))
	var rebuild_draws: Array = []
	while zones.size(TileZoneScript.HAND) < recovery_baseline:
		var draw_result = tile_actions.draw(DrawSourceScript.COMPLETE_HAND_REBUILD)
		rebuild_draws.append(draw_result)
		events.append_array(draw_result.events)
		if not draw_result.is_accepted():
			break
	recovery_state.start()
	events.append(DomainEventScript.new(DomainEventScript.RECOVERY_STARTED, recovery_state.to_dictionary()))
	var result_status := CompleteHandSettlementResultScript.COMPLETED
	if zones.size(TileZoneScript.HAND) < recovery_baseline:
		result_status = CompleteHandSettlementResultScript.REBUILD_SHORTFALL
	var settlement_result := CompleteHandSettlementResultScript.new(
		result_status,
		interpretation,
		score_result,
		combat_output,
		settled_ids,
		rebuild_draws,
		events,
		recovery_state.to_dictionary(),
	)
	return {
		"accepted": settlement_result.is_accepted(),
		"status": settlement_result.status,
		"events": settlement_result.events,
		"data": settlement_result.to_dictionary(),
	}

func execute_settlement(selected_instance_ids: Array) -> Dictionary:
	var turn_result = settlement_turn.resolve_partial_settlement(selected_instance_ids)
	return _execute_settlement_result(turn_result)

func execute_settlement_candidate(candidate_id: String) -> Dictionary:
	var turn_result = settlement_turn.resolve_partial_settlement_candidate(candidate_id)
	return _execute_settlement_result(turn_result)

func _execute_settlement_result(turn_result) -> Dictionary:
	var settlement_result = turn_result.settlement_result
	if settlement_result == null or not settlement_result.is_accepted():
		return {
			"accepted": false,
			"status": "SETTLEMENT_REJECTED",
			"message": "The selected Pattern was rejected.",
		}

	var events: Array = turn_result.events

	var score_result = score_resolver.resolve(settlement_result.settled_pattern, local_yaku_resolver, _yaku_state())
	var combat_output = conversion_resolver.resolve(score_result, conversion_profile, combat_state.to_dictionary())
	var combat_result = combat_resolver.resolve_combat_conversion(combat_state, combat_output)
	events.append_array(combat_result.events)
	return {
		"accepted": true,
		"status": turn_result.status,
		"events": events,
		"data": {
			"settlement": turn_result.to_dictionary(),
			"score": score_result.to_dictionary(),
			"combat_output": combat_output.to_dictionary(),
		},
	}

func resolve_enemy_intent():
	if combat_resolver == null:
		return {"accepted": false, "status": "COMBAT_RESOLVER_NOT_READY", "events": []}
	var result = combat_resolver.resolve_enemy_intent(combat_state)
	var events: Array = result.events.duplicate()
	if result.is_resolved() and reserve_service != null and combat_state.is_active():
		events.append_array(reserve_service.natural_decay())
	return {"accepted": result.is_resolved(), "status": result.status, "events": events}

func end_battle(preserve_run_level: bool = false, preserved_instance_ids: Array = []) -> Array:
	if reserve_service == null:
		return []
	return reserve_service.end_battle(preserve_run_level, preserved_instance_ids)

func checkpoint() -> Dictionary:
	var zone_checkpoint: Dictionary = {}
	if zones != null:
		for zone in TileZoneScript.all():
			zone_checkpoint[zone] = _tile_ids(zones.contents(zone))
	var candidate_checkpoint: Array = []
	if settlement_window != null:
		for candidate in settlement_window.candidates():
			candidate_checkpoint.append(_tile_ids(candidate.tile_instances))
	return {
		"schema_version": 2,
		"zones": zone_checkpoint,
		"draw_wall": _tile_ids(draw_wall.contents()) if draw_wall != null else [],
		"reserve": _tile_ids(zones.contents(TileZoneScript.RESERVE)) if zones != null else [],
		"integrity": _integrity_snapshot(),
		"combat_state": combat_state.to_dictionary() if combat_state != null else {},
		"settlement": {
			"submitted": settlement_turn != null and not settlement_turn.settled_instance_ids().is_empty(),
			"window_open": settlement_window.is_open() if settlement_window != null else false,
			"candidates": candidate_checkpoint,
			"settled_instance_ids": settlement_turn.settled_instance_ids() if settlement_turn != null else [],
			"capacity": settlement_window.settlement_capacity().to_dictionary() if settlement_window != null else {},
		},
		"complete_hand": {
			"interpretations": _interpretation_checkpoints(),
			"destination": complete_hand_destination,
		},
		"recovery": recovery_state.to_dictionary() if recovery_state != null else {},
	}

func _complete_hand_by_id(interpretation_id: String):
	for interpretation in complete_hand_interpretations():
		if interpretation is CompleteHandInterpretationScript and interpretation.interpretation_id == interpretation_id:
			return interpretation
	return null

func _valid_complete_hand_destination() -> bool:
	return [TileZoneScript.DISCARD, TileZoneScript.EXHAUST, TileZoneScript.DRAW_WALL].has(complete_hand_destination)

func _interpretation_checkpoints() -> Array:
	var result: Array = []
	for interpretation in complete_hand_interpretations():
		result.append(interpretation.to_dictionary())
	return result

func _build_complete_hand_conversion_profile():
	if conversion_profile is CombatConversionProfileScript:
		var config: Dictionary = conversion_profile.to_dictionary()
		var stability_curve: Dictionary = config.get("stability_curve", {}).duplicate(true)
		if float(stability_curve.get("multiplier", 0.0)) <= 0.0:
			stability_curve["multiplier"] = 0.5
		config["stability_curve"] = stability_curve
		config["id"] = "%s.complete_hand" % conversion_profile.profile_id
		return CombatConversionProfileScript.new(config)
	return CombatConversionProfileScript.new({
		"id": "combat_conversion.complete_hand",
		"damage_curve": {"mode": "linear", "multiplier": 1.0},
		"stability_curve": {"mode": "linear", "multiplier": 0.5},
	})

func _tile_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile_instance in tiles:
		ids.append(tile_instance.instance_id)
	return ids

func _integrity_snapshot() -> Array:
	var snapshot: Array = []
	if zones == null:
		return snapshot
	for zone in TileZoneScript.all():
		for tile_instance in zones.contents(zone):
			if tile_instance.integrity_initialized():
				snapshot.append({"instance_id": tile_instance.instance_id, "integrity": tile_instance.integrity, "max_integrity": tile_instance.max_integrity})
	snapshot.sort_custom(func(left, right): return left.instance_id < right.instance_id)
	return snapshot

func _yaku_state() -> Dictionary:
	return {
		"hand": zones.contents(TileZoneScript.HAND) if zones != null else [],
		"reserve": zones.contents(TileZoneScript.RESERVE) if zones != null else [],
	}
