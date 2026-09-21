class_name BattleController
extends RefCounted

signal presentation_changed

const BattleCommandResultScript = preload("res://src/presentation/battle/battle_command_result.gd")
const BattlePresentationStateScript = preload("res://src/presentation/battle/battle_presentation_state.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const SettlePatternCommandScript = preload("res://src/domain/commands/settle_pattern_command.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")
const TileZoneContainerScript = preload("res://src/domain/tiles/tile_zone_container.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const DrawWallScript = preload("res://src/domain/tiles/draw_wall.gd")
const TileActionServiceScript = preload("res://src/domain/tiles/tile_action_service.gd")
const DomainRngStreamsScript = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const PatternEvaluatorScript = preload("res://src/domain/mahjong/pattern/pattern_evaluator.gd")
const PatternCandidateScript = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const SettlementWindowScript = preload("res://src/domain/mahjong/settlement/settlement_window.gd")
const SettlementTurnScript = preload("res://src/domain/mahjong/settlement/settlement_turn.gd")
const MahjongScoreResolverScript = preload("res://src/domain/mahjong/scoring/mahjong_score_resolver.gd")
const CombatConversionProfileScript = preload("res://src/domain/combat/combat_conversion_profile.gd")
const CombatConversionResolverScript = preload("res://src/domain/combat/combat_conversion_resolver.gd")
const CombatStateScript = preload("res://src/domain/combat/combat_state.gd")
const CombatResolverScript = preload("res://src/domain/combat/combat_resolver.gd")

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
var presentation
var _settlement_submitted := false

func _init() -> void:
	presentation = BattlePresentationStateScript.new()
	_build_default_fixture()
	presentation.sync(_snapshot())
	presentation.status = "Draw to find a Pattern."

func submit(command) -> RefCounted:
	if command is DrawCommandScript:
		return _submit_draw(command)
	if command is SettlePatternCommandScript:
		return _submit_settlement(command)
	return BattleCommandResultScript.new(false, "UNKNOWN_COMMAND", [], "Unsupported battle command.")

func can_settle() -> bool:
	return not _settlement_submitted and combat_state != null and combat_state.is_active() and settlement_window != null and settlement_window.is_open() and not settlement_window.candidates().is_empty()

func _submit_draw(_command) -> RefCounted:
	if not combat_state.is_active():
		return BattleCommandResultScript.new(false, "BATTLE_TERMINAL", [], "The battle is already over.")
	var draw_result = tile_actions.draw()
	var events: Array = draw_result.events
	if draw_result.is_accepted():
		settlement_window.open()
	_consume_events(events)
	return BattleCommandResultScript.new(draw_result.is_accepted(), draw_result.status, events)

func _submit_settlement(command) -> RefCounted:
	if not can_settle():
		return BattleCommandResultScript.new(false, "SETTLEMENT_UNAVAILABLE", [], "No highlighted Pattern can be settled.")
	var turn_result = settlement_turn.resolve_partial_settlement(command.instance_ids)
	var settlement_result = turn_result.settlement_result
	if settlement_result == null or not settlement_result.is_accepted():
		return BattleCommandResultScript.new(false, turn_result.status, [], "The selected Pattern was rejected.")

	var events: Array = settlement_result.events
	for replacement_draw in turn_result.replacement_draws:
		events.append_array(replacement_draw.events)

	var score_result = score_resolver.resolve(settlement_result.settled_pattern)
	var combat_output = conversion_resolver.resolve(score_result, conversion_profile, combat_state.to_dictionary())
	var combat_result = combat_resolver.resolve_combat_conversion(combat_state, combat_output)
	events.append_array(combat_result.events)
	_settlement_submitted = true
	_consume_events(events)
	return BattleCommandResultScript.new(true, turn_result.status, events)

func _consume_events(events: Array) -> void:
	for event in events:
		presentation.apply_domain_event(event, _snapshot())
	if events.is_empty():
		presentation.sync(_snapshot())
	presentation_changed.emit()

func _build_default_fixture() -> void:
	var registry := ContentRegistryScript.new()
	for rank in range(1, 10):
		registry.register(TileDefinitionScript.new(
			"base.tile.characters.%d" % rank,
			"characters",
			rank,
		))
	zones = TileZoneContainerScript.new()
	_add_tile(zones, "run.battle.hand.1", 1, TileZoneScript.HAND)
	_add_tile(zones, "run.battle.hand.2", 2, TileZoneScript.HAND)
	var wall_tiles: Array = []
	for rank in range(3, 9):
		wall_tiles.append(_add_tile(zones, "run.battle.wall.%d" % rank, rank, TileZoneScript.TILE_POOL))
	var rng_streams := DomainRngStreamsScript.new(13)
	draw_wall = DrawWallScript.new(zones, rng_streams.draw_wall)
	draw_wall.initialize()
	zones.reorder(TileZoneScript.DRAW_WALL, _tile_ids(wall_tiles))
	tile_actions = TileActionServiceScript.new(draw_wall, zones)
	var evaluator := PatternEvaluatorScript.new(registry)
	settlement_window = SettlementWindowScript.new(evaluator, zones)
	settlement_turn = SettlementTurnScript.new(settlement_window, tile_actions, zones, 3)
	score_resolver = MahjongScoreResolverScript.new({
		PatternCandidateScript.SEQUENCE: {"source_id": "pattern.sequence", "amount": 10},
		PatternCandidateScript.TRIPLET: {"source_id": "pattern.triplet", "amount": 12},
		PatternCandidateScript.QUAD: {"source_id": "pattern.quad", "amount": 16},
	})
	conversion_profile = CombatConversionProfileScript.new({
		"id": "combat_conversion.prototype",
		"damage_curve": {"mode": "linear", "multiplier": 1.0},
		"stability_curve": {"mode": "linear", "multiplier": 0.0},
	})
	conversion_resolver = CombatConversionResolverScript.new()
	combat_state = CombatStateScript.new(30, 10)
	combat_resolver = CombatResolverScript.new()

func _add_tile(target_zones, instance_id: String, rank: int, zone: String):
	var tile := TileInstanceScript.new(instance_id, "base.tile.characters.%d" % rank)
	target_zones.add(tile, zone)
	return tile

func _snapshot() -> Dictionary:
	return {
		"hand": _tile_data(zones.contents(TileZoneScript.HAND)),
		"draw_wall_count": draw_wall.size(),
		"discard": _tile_data(zones.contents(TileZoneScript.DISCARD)),
		"enemy_hp": combat_state.enemy_hp,
		"enemy_max_hp": combat_state.enemy_max_hp,
		"enemy_intent": combat_state.current_intent.to_dictionary(),
		"pressure": combat_state.pressure,
		"pressure_limit": combat_state.pressure_limit,
		"pattern_highlights": _pattern_data(settlement_window.candidates()),
		"outcome": combat_state.terminal_outcome,
	}

func _tile_data(tiles: Array) -> Array:
	var result: Array = []
	for tile in tiles:
		result.append({
			"instance_id": tile.instance_id,
			"definition_id": tile.definition_id,
			"label": _tile_label(tile.definition_id),
		})
	return result

func _pattern_data(candidates: Array) -> Array:
	var result: Array = []
	for candidate in candidates:
		var instance_ids: Array[String] = []
		for tile in candidate.tile_instances:
			instance_ids.append(tile.instance_id)
		result.append({
			"pattern_type": candidate.pattern_type,
			"instance_ids": instance_ids,
			"labels": _tile_labels(candidate.tile_instances),
		})
	return result

func _tile_labels(tiles: Array) -> Array[String]:
	var labels: Array[String] = []
	for tile in tiles:
		labels.append(_tile_label(tile.definition_id))
	return labels

func _tile_label(definition_id: String) -> String:
	return definition_id.get_slice(".", definition_id.get_slice_count(".") - 1)

func _tile_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile in tiles:
		ids.append(tile.instance_id)
	return ids
