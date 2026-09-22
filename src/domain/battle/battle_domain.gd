class_name BattleDomain
extends RefCounted

const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const ReserveActionResultScript = preload("res://src/domain/tiles/reserve_action_result.gd")
const ReserveServiceScript = preload("res://src/domain/tiles/reserve_service.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

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

	var score_result = score_resolver.resolve(settlement_result.settled_pattern)
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
		"schema_version": 1,
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
	}

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
