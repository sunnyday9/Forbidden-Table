class_name BattleController
extends RefCounted

signal presentation_changed

const BattlePresentationStateScript = preload("res://src/presentation/battle/battle_presentation_state.gd")
const BattleDomainScript = preload("res://src/domain/battle/battle_domain.gd")
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
const SettlementCapacityScript = preload("res://src/domain/mahjong/settlement/settlement_capacity.gd")
const MahjongScoreResolverScript = preload("res://src/domain/mahjong/scoring/mahjong_score_resolver.gd")
const CombatConversionProfileScript = preload("res://src/domain/combat/combat_conversion_profile.gd")
const CombatConversionResolverScript = preload("res://src/domain/combat/combat_conversion_resolver.gd")
const CombatStateScript = preload("res://src/domain/combat/combat_state.gd")
const CombatResolverScript = preload("res://src/domain/combat/combat_resolver.gd")
const EffectContextScript = preload("res://src/domain/effects/effect_context.gd")
const CompleteHandEvaluatorScript = preload("res://src/domain/mahjong/complete_hand/complete_hand_evaluator.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifierScript = preload("res://src/infrastructure/replay/replay_verifier.gd")

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
var complete_hand_evaluator
var domain
var presentation
var run_seed: int
var content_version: String
var replay_record
var _rng_streams

func _init(initial_run_seed: int = 13, initial_content_version: String = "content.prototype.v1") -> void:
	run_seed = initial_run_seed
	content_version = initial_content_version
	presentation = BattlePresentationStateScript.new()
	_build_default_fixture()
	domain = BattleDomainScript.new(
		zones,
		draw_wall,
		tile_actions,
		settlement_window,
		settlement_turn,
		score_resolver,
		conversion_resolver,
		conversion_profile,
		combat_state,
		combat_resolver,
		null,
		complete_hand_evaluator,
		null,
		3,
		1,
		TileZoneScript.DISCARD,
		null,
		_rng_streams,
	)
	presentation.sync(_snapshot())
	presentation.status = "Draw to find a Pattern."
	replay_record = ReplayRecordScript.new(run_seed, content_version)
	replay_record.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), combat_state.terminal_outcome)

func submit(command) -> RefCounted:
	var result = domain.execute(command)
	_consume_events(result.events)
	if result != null and result.has_method("is_replayable") and result.is_replayable():
		replay_record.record_command(command.to_dictionary(), result.state_checkpoint, domain.rng_snapshot(), combat_state.terminal_outcome, result.events)
	return result

func verify_replay(record = replay_record):
	var replay_factory := func(replay_seed: int, replay_content_version: String):
		return BattleController.new(replay_seed, replay_content_version)
	return ReplayVerifierScript.verify(record, replay_factory, content_version)

func can_settle() -> bool:
	return domain.can_settle()

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
	_rng_streams = DomainRngStreamsScript.new(run_seed)
	draw_wall = DrawWallScript.new(zones, _rng_streams.draw_wall)
	draw_wall.initialize()
	zones.reorder(TileZoneScript.DRAW_WALL, _tile_ids(wall_tiles))
	tile_actions = TileActionServiceScript.new(draw_wall, zones)
	var evaluator := PatternEvaluatorScript.new(registry)
	combat_state = CombatStateScript.new(30, 10, 0, [], 0, 0, 3, 2, 3, 0, null, _rng_streams.enemy)
	settlement_window = SettlementWindowScript.new(evaluator, zones, SettlementCapacityScript.new(combat_state.settlement_capacity))
	var settlement_trigger_context := EffectContextScript.new(combat_state, zones, draw_wall, tile_actions.reserve_service)
	settlement_turn = SettlementTurnScript.new(settlement_window, tile_actions, zones, 3, null, settlement_trigger_context)
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
	combat_resolver = CombatResolverScript.new()
	complete_hand_evaluator = CompleteHandEvaluatorScript.new(registry)

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
			"candidate_id": candidate.candidate_id,
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
