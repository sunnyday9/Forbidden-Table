class_name BattleDomain
extends RefCounted

const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
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
var _settlement_submitted := false

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
		settlement_window.open()
	return {
		"accepted": draw_result.is_accepted(),
		"status": draw_result.status,
		"events": events,
	}

func can_settle() -> bool:
	return (
		not _settlement_submitted
		and combat_state != null
		and combat_state.is_active()
		and settlement_window != null
		and settlement_window.is_open()
		and not settlement_window.candidates().is_empty()
	)

func validate_settlement(selected_instance_ids: Array) -> RefCounted:
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

func execute_settlement(selected_instance_ids: Array) -> Dictionary:
	var turn_result = settlement_turn.resolve_partial_settlement(selected_instance_ids)
	var settlement_result = turn_result.settlement_result
	if settlement_result == null or not settlement_result.is_accepted():
		return {
			"accepted": false,
			"status": "SETTLEMENT_REJECTED",
			"message": "The selected Pattern was rejected.",
		}

	var events: Array = settlement_result.events
	for replacement_draw in turn_result.replacement_draws:
		events.append_array(replacement_draw.events)

	var score_result = score_resolver.resolve(settlement_result.settled_pattern)
	var combat_output = conversion_resolver.resolve(score_result, conversion_profile, combat_state.to_dictionary())
	var combat_result = combat_resolver.resolve_combat_conversion(combat_state, combat_output)
	events.append_array(combat_result.events)
	_settlement_submitted = true
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
		"combat_state": combat_state.to_dictionary() if combat_state != null else {},
		"settlement": {
			"submitted": _settlement_submitted,
			"window_open": settlement_window.is_open() if settlement_window != null else false,
			"candidates": candidate_checkpoint,
			"settled_instance_ids": settlement_turn.settled_instance_ids() if settlement_turn != null else [],
		},
	}

func _tile_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile_instance in tiles:
		ids.append(tile_instance.instance_id)
	return ids
