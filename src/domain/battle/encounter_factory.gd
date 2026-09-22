class_name EncounterFactory
extends RefCounted

const BattleContextScript = preload("res://src/domain/battle/battle_context.gd")
const BattleDomainScript = preload("res://src/domain/battle/battle_domain.gd")
const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const CombatConversionProfileScript = preload("res://src/domain/combat/combat_conversion_profile.gd")
const CombatConversionResolverScript = preload("res://src/domain/combat/combat_conversion_resolver.gd")
const CombatResolverScript = preload("res://src/domain/combat/combat_resolver.gd")
const CombatStateScript = preload("res://src/domain/combat/combat_state.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const DrawWallScript = preload("res://src/domain/tiles/draw_wall.gd")
const EffectContextScript = preload("res://src/domain/effects/effect_context.gd")
const EnemyDefinitionScript = preload("res://src/content/definitions/enemy_definition.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const MahjongScoreResolverScript = preload("res://src/domain/mahjong/scoring/mahjong_score_resolver.gd")
const PatternEvaluatorScript = preload("res://src/domain/mahjong/pattern/pattern_evaluator.gd")
const SettlementCapacityScript = preload("res://src/domain/mahjong/settlement/settlement_capacity.gd")
const SettlementTurnScript = preload("res://src/domain/mahjong/settlement/settlement_turn.gd")
const SettlementWindowScript = preload("res://src/domain/mahjong/settlement/settlement_window.gd")
const TileActionServiceScript = preload("res://src/domain/tiles/tile_action_service.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")
const TileOriginScript = preload("res://src/domain/tiles/tile_origin.gd")
const TileLifetimeScript = preload("res://src/domain/tiles/tile_lifetime.gd")
const TileZoneContainerScript = preload("res://src/domain/tiles/tile_zone_container.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const CompleteHandEvaluatorScript = preload("res://src/domain/mahjong/complete_hand/complete_hand_evaluator.gd")

var content_registry
var last_error: Dictionary

func _init(domain_content_registry = null) -> void:
	content_registry = domain_content_registry if domain_content_registry != null else ContentRegistryScript.new()
	last_error = {}

func validate(run_state, encounter_id: String, expected_kind: String = "") -> Dictionary:
	var encounter = content_registry.resolve(encounter_id) if content_registry != null else null
	if not encounter is EncounterDefinitionScript:
		return _error("INVALID_ENCOUNTER_ID", "The encounter ID is not registered as an EncounterDefinition.", {"encounter_id": encounter_id})
	var encounter_report = encounter.validate()
	if not encounter_report.is_valid():
		return _error("INVALID_ENCOUNTER_DEFINITION", "The EncounterDefinition is invalid.", {"issues": _issues(encounter_report)})
	if not expected_kind.is_empty() and encounter.encounter_kind != expected_kind:
		return _error("ENCOUNTER_KIND_MISMATCH", "The encounter kind does not match the selected Map Node.", {"expected": expected_kind, "actual": encounter.encounter_kind})
	if run_state == null:
		return _error("MISSING_RUN_STATE", "A RunState is required to create a BattleDomain.")
	var character = content_registry.resolve(run_state.character_id)
	if not character is CharacterDefinitionScript:
		return _error("INVALID_CHARACTER_CONTEXT", "The selected Character is not registered.", {"character_id": run_state.character_id})
	var contract = content_registry.resolve(run_state.contract_id)
	if not contract is ContractDefinitionScript:
		return _error("INVALID_CONTRACT_CONTEXT", "The selected Contract is not registered.", {"contract_id": run_state.contract_id})
	for enemy_id in encounter.enemy_ids:
		var enemy = content_registry.resolve(enemy_id)
		if not enemy is EnemyDefinitionScript:
			return _error("INVALID_ENEMY_ID", "The encounter references a non-enemy definition.", {"enemy_id": enemy_id})
		var enemy_report = enemy.validate()
		if not enemy_report.is_valid():
			return _error("INVALID_ENEMY_DEFINITION", "The EncounterDefinition references an invalid EnemyDefinition.", {"enemy_id": enemy_id, "issues": _issues(enemy_report)})
		var expected_role: String = encounter.encounter_kind
		if enemy.role != expected_role:
			return _error("ENEMY_ROLE_MISMATCH", "The EncounterDefinition kind must match every EnemyDefinition role.", {"enemy_id": enemy_id, "expected": expected_role, "actual": enemy.role})
	return {"accepted": true, "status": "VALID", "encounter": encounter}

func create(run_state, encounter_id: String, domain_rng_streams, expected_kind: String = ""):
	last_error = {}
	var validation := validate(run_state, encounter_id, expected_kind)
	if not validation.get("accepted", false):
		last_error = validation.duplicate(true)
		return null
	var encounter = validation["encounter"]
	var enemies: Array = []
	for enemy_id in encounter.enemy_ids:
		enemies.append(content_registry.resolve(enemy_id))
	var primary_enemy = enemies[0]
	var values: Dictionary = primary_enemy.battle_values.duplicate(true)
	for key in encounter.battle_values.keys():
		values[key] = encounter.battle_values[key]
	var contamination: Dictionary = primary_enemy.contamination_config.duplicate(true)
	for key in encounter.contamination_config.keys():
		contamination[key] = encounter.contamination_config[key]
	var tile_pool: Array = _tile_pool_snapshot(run_state)
	var context := BattleContextScript.new(
		encounter_id,
		encounter.encounter_kind,
		encounter.enemy_ids,
		run_state.character_id,
		run_state.contract_id,
		content_registry.resolve(run_state.character_id),
		content_registry.resolve(run_state.contract_id),
		run_state.build_ownership.to_dictionary(),
		contamination,
		domain_rng_streams,
		content_registry,
		tile_pool,
		run_state.to_dictionary(),
	)
	var zones := TileZoneContainerScript.new(int(values.get("reserve_capacity", 3)))
	for record in tile_pool:
		var origin := str(record.get("origin", TileOriginScript.RUN_POOL))
		var lifetime := str(record.get("lifetime", record.get("lifetime_scope", TileLifetimeScript.RUN)))
		zones.add(TileInstanceScript.new(str(record["instance_id"]), str(record["definition_id"]), origin, lifetime), TileZoneScript.TILE_POOL)
	var draw_wall := DrawWallScript.new(zones, domain_rng_streams.draw_wall)
	if not draw_wall.initialize():
		last_error = _error("DRAW_WALL_INIT_FAILED", "The BattleDomain Draw Wall could not be initialized.")
		return null
	var tile_actions := TileActionServiceScript.new(draw_wall, zones)
	var state := CombatStateScript.new(
		primary_enemy.max_hp,
		int(values.get("pressure_limit", 10)),
		int(values.get("initial_pressure", 0)),
		[],
		int(values.get("tp", 0)),
		int(values.get("stability", 0)),
		int(values.get("draw_capacity", 3)),
		int(values.get("settlement_capacity", 2)),
		int(values.get("reserve_capacity", 3)),
		int(values.get("fatigue", 0)),
		primary_enemy.intent_graph,
		domain_rng_streams.enemy,
	)
	if primary_enemy.role == EnemyDefinitionScript.BOSS and not state.configure_boss_phases(primary_enemy.boss_phases):
		last_error = _error("INVALID_BOSS_PHASES", "The Boss EnemyDefinition phases could not configure CombatState.", {"enemy_id": primary_enemy.content_id})
		return null
	var pattern_evaluator := PatternEvaluatorScript.new(content_registry)
	var settlement_window := SettlementWindowScript.new(pattern_evaluator, zones, SettlementCapacityScript.new(state.settlement_capacity))
	var settlement_context := EffectContextScript.new(state, zones, draw_wall, tile_actions.reserve_service)
	var settlement_turn := SettlementTurnScript.new(settlement_window, tile_actions, zones, int(values.get("normal_hand_baseline", 13)), null, settlement_context)
	var domain := BattleDomainScript.new(
		zones,
		draw_wall,
		tile_actions,
		settlement_window,
		settlement_turn,
		MahjongScoreResolverScript.new(),
		CombatConversionResolverScript.new(),
		CombatConversionProfileScript.new({
			"id": "combat_conversion.%s" % encounter_id,
			"damage_curve": values.get("damage_curve", {"mode": "linear", "multiplier": 1.0}),
			"stability_curve": values.get("stability_curve", {"mode": "linear", "multiplier": 0.0}),
		}),
		state,
		CombatResolverScript.new(),
		null,
		CompleteHandEvaluatorScript.new(content_registry),
		null,
		int(values.get("normal_hand_baseline", 13)),
		int(values.get("recovery_baseline", 10)),
		TileZoneScript.DISCARD,
		null,
		domain_rng_streams,
	)
	domain.encounter_id = encounter_id
	domain.encounter_kind = encounter.encounter_kind
	domain.encounter_definition = encounter
	domain.enemy_definition = primary_enemy
	domain.enemy_definitions = enemies
	domain.context = context
	return domain

func create_battle(run_state, encounter_id: String, domain_rng_streams, expected_kind: String = ""):
	return create(run_state, encounter_id, domain_rng_streams, expected_kind)

func _tile_pool_snapshot(run_state) -> Array:
	var records: Array = []
	if run_state == null or run_state.tile_pool == null:
		return records
	for record in run_state.tile_pool.tile_instances:
		records.append(record.to_dictionary())
	records.sort_custom(func(left, right): return left["instance_id"] < right["instance_id"])
	return records

func _error(status: String, message: String, details: Dictionary = {}) -> Dictionary:
	return {"accepted": false, "status": status, "message": message, "details": details.duplicate(true)}

func _issues(report) -> Array:
	var issues: Array = []
	for issue in report.issues:
		issues.append({"code": issue.code, "content_id": issue.content_id, "reference_id": issue.reference_id, "message": issue.message})
	return issues
