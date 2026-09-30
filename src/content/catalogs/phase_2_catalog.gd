class_name Phase2Catalog
extends RefCounted
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const ContentDefinitionScript = preload("res://src/content/definitions/content_definition.gd")
const EffectScript = preload("res://src/domain/effects/effect.gd")
const EffectTriggerScript = preload("res://src/domain/effects/effect_trigger.gd")
const DurationSpecScript = preload("res://src/domain/effects/duration_spec.gd")
const StackPolicyScript = preload("res://src/domain/effects/stack_policy.gd")
const ApplyRunModifierOperationScript = preload("res://src/domain/effects/operations/apply_run_modifier_operation.gd")
const DealDamageOperationScript = preload("res://src/domain/effects/operations/deal_damage_operation.gd")
const DrawTileOperationScript = preload("res://src/domain/effects/operations/draw_tile_operation.gd")
const GainPressureOperationScript = preload("res://src/domain/effects/operations/gain_pressure_operation.gd")
const GainStabilityOperationScript = preload("res://src/domain/effects/operations/gain_stability_operation.gd")
const GainTPOperationScript = preload("res://src/domain/effects/operations/gain_tp_operation.gd")
const ModifyDrawCapacityOperationScript = preload("res://src/domain/effects/operations/modify_draw_capacity_operation.gd")
const ModifyReserveCapacityOperationScript = preload("res://src/domain/effects/operations/modify_reserve_capacity_operation.gd")
const ModifyRunCurrencyOperationScript = preload("res://src/domain/effects/operations/modify_run_currency_operation.gd")
const ModifySettlementCapacityOperationScript = preload("res://src/domain/effects/operations/modify_settlement_capacity_operation.gd")
const PurgeContaminationOperationScript = preload("res://src/domain/effects/operations/purge_contamination_operation.gd")
const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")
const EnemyDefinitionScript = preload("res://src/content/definitions/enemy_definition.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const EnemyIntentScript = preload("res://src/domain/combat/enemy_intent.gd")
const IntentGraphScript = preload("res://src/domain/combat/intent_graph.gd")
const IntentTransitionScript = preload("res://src/domain/combat/intent_transition.gd")
const PublicStateConditionScript = preload("res://src/domain/combat/public_state_condition.gd")
const EventDefinitionScript = preload("res://src/content/definitions/event_definition.gd")
const MapDefinitionScript = preload("res://src/content/definitions/map_definition.gd")
const MiniActMapCatalogScript = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const RuleBreakerDefinitionScript = preload("res://src/content/definitions/rule_breaker_definition.gd")
const RewardPoolDefinitionScript = preload("res://src/content/definitions/reward_pool_definition.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")
const YakuDefinitionScript = preload("res://src/content/definitions/yaku_definition.gd")
const YakuCatalogScript = preload("res://src/content/catalogs/yaku_catalog.gd")

const CHARACTER_IDS := [
	"base.character.sequence",
	"base.character.reserve",
]
const CONTRACT_IDS := [
	"base.contract.pressure",
	"base.contract.pool_bias",
	"base.contract.refinement_debt",
]
const PROTOTYPE_YAKU_IDS := [
	"prototype.yaku.sequence_path",
	"prototype.yaku.triplet_foundation",
	"prototype.yaku.honor_signal",
	"prototype.yaku.unified_suit",
	"prototype.yaku.standard_complete_hand",
	"prototype.yaku.seven_pairs",
	"prototype.yaku.quad_foundry",
	"prototype.yaku.mixed_table",
]
const PRODUCTION_YAKU_IDS := [
	"base.yaku.pair_foundation",
	"base.yaku.bamboo_concentration",
]
const RELIC_IDS := [
	"base.relic.open_hand",
	"base.relic.sequence_lens",
	"base.relic.triplet_lens",
	"base.relic.yaku_notebook",
	"base.relic.reserve_sleeve",
	"base.relic.integrity_seal",
	"base.relic.calm_pressure",
	"base.relic.fatigue_buffer",
	"base.relic.clean_table",
	"base.relic.wall_survey",
	"base.relic.reward_pivot",
	"base.relic.skip_stipend",
	"base.relic.shop_ledger",
	"base.relic.workshop_kit",
	"base.relic.elite_bounty",
	"base.relic.complete_hand_insurance",
	"base.relic.contamination_filter",
	"base.relic.rule_memory",
]
const RUN_TECHNIQUE_IDS := [
	"base.technique.draw_surge",
	"base.technique.reserve_exchange",
	"base.technique.settlement_focus",
	"base.technique.stability_breath",
	"base.technique.pressure_break",
	"base.technique.clean_table",
	"base.technique.yaku_insight",
	"base.technique.reaction_guard",
]
const CORE_TECHNIQUE_IDS := [
	"base.technique.core.sequence_line",
	"base.technique.core.reserve_ledger",
]
const MODIFIER_IDS := [
	"base.modifier.flexible_identity",
	"base.modifier.reserve_bound",
	"base.modifier.settlement_focus",
	"base.modifier.recycling",
	"base.modifier.clean_surface",
]
const NORMAL_ENEMY_IDS := [
	"base.enemy.pressure_sentinel",
	"base.enemy.wall_taxer",
	"base.enemy.integrity_collector",
	"base.enemy.contaminator",
]
const ELITE_ENEMY_ID := "base.enemy.ledger_hunter"
const BOSS_ID := "base.boss.table_breaker"
const EVENT_IDS := [
	"base.event.tile_surgery",
	"base.event.risk_bargain",
	"base.event.gold_exchange",
	"base.event.map_reveal",
	"base.event.contract_clause",
	"base.event.rule_memory",
]

const BOSS_RULE_BREAKER_IDS := [
	"base.rule_breaker.open_table",
	"base.rule_breaker.reserve_witness",
	"base.rule_breaker.draw_twice",
]

const REWARD_POOL_ID := "base.reward_pool.normal"
const BOSS_RULE_BREAKER_POOL_ID := "base.reward_pool.boss_rule_breaker"
const SHOP_POOL_ID := "base.shop_pool.act_one"
const WORKSHOP_POOL_ID := "base.workshop_pool.act_one"
const POOL_IDS := [REWARD_POOL_ID, BOSS_RULE_BREAKER_POOL_ID, SHOP_POOL_ID, WORKSHOP_POOL_ID]
const CONTENT_BUNDLE_ID := "phase2"
const CONTENT_BUNDLE_VERSION := "v4"

static func register_all(registry) -> RefCounted:
	return registry.register_bundle(CONTENT_BUNDLE_ID, CONTENT_BUNDLE_VERSION, definitions())

static func definitions() -> Array:
	var result: Array = []
	result.append_array(_tile_definitions())
	result.append_array(_passive_definitions())
	result.append_array(_character_definitions())
	result.append_array(_contract_definitions())
	result.append_array(_yaku_definitions())
	result.append_array(_rule_breaker_definitions())
	result.append_array(_relic_definitions())
	result.append_array(_technique_definitions())
	result.append_array(_modifier_definitions())
	result.append_array(_enemy_definitions())
	result.append_array(_encounter_definitions())
	result.append_array(_event_definitions())
	result.append_array(_map_definitions())
	result.append_array(_pool_definitions())
	return result

static func pool_membership() -> Dictionary:
	var obtainable := _sorted_ids(RELIC_IDS + RUN_TECHNIQUE_IDS)
	return {
		REWARD_POOL_ID: obtainable.duplicate(),
		BOSS_RULE_BREAKER_POOL_ID: _sorted_ids(BOSS_RULE_BREAKER_IDS),
		SHOP_POOL_ID: obtainable.duplicate(),
		WORKSHOP_POOL_ID: _sorted_ids(MODIFIER_IDS),
	}

static func typed_effect(effect_id: String, operation_kind: String, amount: int = 1):
	var operation = null
	match operation_kind:
		"ApplyRunModifier":
			operation = ApplyRunModifierOperationScript.new(
				effect_id,
				amount,
				DurationSpecScript.new(DurationSpecScript.RUN, 1),
				StackPolicyScript.REPLACE,
				effect_id,
			)
		"DealDamage":
			operation = DealDamageOperationScript.new(amount)
		"DrawTile":
			operation = DrawTileOperationScript.new(DrawSourceScript.EFFECT)
		"GainPressure":
			operation = GainPressureOperationScript.new(amount)
		"GainStability":
			operation = GainStabilityOperationScript.new(amount)
		"GainTP":
			operation = GainTPOperationScript.new(amount)
		"ModifyDrawCapacity":
			operation = ModifyDrawCapacityOperationScript.new(amount)
		"ModifyReserveCapacity":
			operation = ModifyReserveCapacityOperationScript.new(amount)
		"ModifyRunCurrency":
			operation = ModifyRunCurrencyOperationScript.new(RunEconomyScript.GOLD, amount, effect_id)
		"ModifyRefinementTokens":
			operation = ModifyRunCurrencyOperationScript.new(RunEconomyScript.REFINEMENT_TOKENS, amount, effect_id)
		"ModifySettlementCapacity":
			operation = ModifySettlementCapacityOperationScript.new(amount)
		"PurgeContamination":
			operation = PurgeContaminationOperationScript.new("")
		_:
			return null
	return EffectScript.new(
		effect_id,
		EffectTriggerScript.new(EffectTriggerScript.MANUAL),
		[],
		[],
		[operation],
		DurationSpecScript.new(),
		StackPolicyScript.REPLACE,
		effect_id,
	)

static func _tile_definitions() -> Array:
	var result: Array = []
	for suit in ["characters", "bamboo", "dots"]:
		for rank in range(1, 10):
			result.append(TileDefinitionScript.new("base.tile.%s.%d" % [suit, rank], suit, rank))
	for honor in ["east", "south", "west", "north", "red", "green", "white"]:
		result.append(TileDefinitionScript.new("base.tile.honors.%s" % honor, "honors", 0))
	return result

static func _passive_definitions() -> Array:
	return [
		ContentDefinitionScript.new("base.passive.sequence"),
		ContentDefinitionScript.new("base.passive.reserve"),
	]

static func _character_definitions() -> Array:
	return [
		CharacterDefinitionScript.new(
			CHARACTER_IDS[0],
			_tile_bias("characters"),
			"base.relic.open_hand",
			CORE_TECHNIQUE_IDS[0],
			"base.passive.sequence",
		),
		CharacterDefinitionScript.new(
			CHARACTER_IDS[1],
			_tile_bias("bamboo"),
			"base.relic.reserve_sleeve",
			CORE_TECHNIQUE_IDS[1],
			"base.passive.reserve",
		),
	]

static func _tile_bias(suit: String) -> Array[String]:
	var result: Array[String] = []
	for rank in range(1, 10):
		result.append("base.tile.%s.%d" % [suit, rank])
	return result

static func _contract_definitions() -> Array:
	return [
		ContractDefinitionScript.new(
			CONTRACT_IDS[0],
			ContractDefinitionScript.PRESSURE,
			{"pressure_per_battle": 2, "visible": true},
			{"tp": 2, "tempo": true},
			{"path": "pressure", "flexibility": "normal", "preferred_tile_ids": ["base.tile.characters.1", "base.tile.characters.2"]},
		),
		ContractDefinitionScript.new(
			CONTRACT_IDS[1],
			ContractDefinitionScript.POOL_BIAS,
			{"off_suit_pool_weight": 2, "composition_cost": true},
			{"starting_bias": "bamboo", "yaku_signal": true},
			{"path": "pool_bias", "flexibility": "reduced", "preferred_tile_ids": ["base.tile.bamboo.1", "base.tile.bamboo.2"]},
		),
		ContractDefinitionScript.new(
			CONTRACT_IDS[2],
			ContractDefinitionScript.REFINEMENT_DEBT,
			{"gold": 5, "route_cost": true},
			{"refinement_tokens": 2, "map_opportunity": true},
			{"path": "refinement", "flexibility": "route-dependent", "preferred_tile_ids": ["base.tile.dots.1", "base.tile.dots.2"]},
		),
	]

static func _yaku_definitions() -> Array:
	var result: Array = YakuCatalogScript.representative_definitions()
	result.append(YakuDefinitionScript.new(
		PRODUCTION_YAKU_IDS[0],
		LocalizationCatalogScript.text("CONTENT_PHASE2_0001"),
		YakuDefinitionScript.BOTH,
		YakuDefinitionScript.STRUCTURAL,
		YakuDefinitionScript.PATTERN_COUNT,
		{"pattern_type": "Pair", "target": 1, "label": LocalizationCatalogScript.text("CONTENT_PHASE2_LABEL_0029"), "local_pattern_types": ["Pair"]},
		{"source_id": PRODUCTION_YAKU_IDS[0], "amount": 5, "tags": ["LOCAL_YAKU", "PAIR"]},
		{"source_id": PRODUCTION_YAKU_IDS[0], "amount": 10, "tags": ["HAND_YAKU", "PAIR"]},
	))
	result.append(YakuDefinitionScript.new(
		PRODUCTION_YAKU_IDS[1],
		LocalizationCatalogScript.text("CONTENT_PHASE2_0002"),
		YakuDefinitionScript.BOTH,
		YakuDefinitionScript.SUIT_HONOR,
		YakuDefinitionScript.SUIT_CONCENTRATION,
		{"suit": "bamboo", "target": 9, "label": LocalizationCatalogScript.text("CONTENT_PHASE2_0003")},
		{"source_id": PRODUCTION_YAKU_IDS[1], "amount": 9, "tags": ["LOCAL_YAKU", "SUIT"]},
		{"source_id": PRODUCTION_YAKU_IDS[1], "amount": 16, "tags": ["HAND_YAKU", "SUIT"]},
	))
	return result

static func _relic_definitions() -> Array:
	var configurations := [
		["DrawTile", 1, false],
		["GainTP", 1, false],
		["GainTP", 2, false],
		["GainTP", 1, false],
		["ModifyReserveCapacity", 1, false],
		["GainStability", 1, false],
		["GainStability", 1, false],
		["GainStability", 2, false],
		["PurgeContamination", 1, true],
		["DrawTile", 1, false],
		["GainTP", 1, false],
		["ModifyRunCurrency", 2, false],
		["ModifyRunCurrency", 1, false],
		["ApplyRunModifier", 1, false],
		["ModifyRunCurrency", 3, false],
		["GainStability", 2, false],
		["PurgeContamination", 1, false],
		["ApplyRunModifier", 1, false],
	]
	var result: Array = []
	for index in RELIC_IDS.size():
		var configuration: Array = configurations[index]
		result.append(RelicDefinitionScript.new(
			RELIC_IDS[index],
			[typed_effect("content.%s" % RELIC_IDS[index], configuration[0], configuration[1])],
			configuration[2],
		))
	return result

static func _rule_breaker_definitions() -> Array:
	return [
		RuleBreakerDefinitionScript.new(
			BOSS_RULE_BREAKER_IDS[0],
			"SETTLEMENT_CAPACITY",
			1,
			[typed_effect("content.%s" % BOSS_RULE_BREAKER_IDS[0], "ModifySettlementCapacity")],
		),
		RuleBreakerDefinitionScript.new(
			BOSS_RULE_BREAKER_IDS[1],
			"RESERVE_CAPACITY",
			1,
			[typed_effect("content.%s" % BOSS_RULE_BREAKER_IDS[1], "ModifyReserveCapacity")],
		),
		RuleBreakerDefinitionScript.new(
			BOSS_RULE_BREAKER_IDS[2],
			"DRAW_ACTIONS",
			1,
			[typed_effect("content.%s" % BOSS_RULE_BREAKER_IDS[2], "ModifyDrawCapacity")],
		),
	]

static func _technique_definitions() -> Array:
	var result: Array = [
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[0], TechniqueDefinitionScript.ACTIVE, 1, [typed_effect("content.%s" % RUN_TECHNIQUE_IDS[0], "DrawTile")]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[1], TechniqueDefinitionScript.ACTIVE, 1, [typed_effect("content.%s" % RUN_TECHNIQUE_IDS[1], "ModifyReserveCapacity")]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[2], TechniqueDefinitionScript.SETTLEMENT, 2, [typed_effect("content.%s" % RUN_TECHNIQUE_IDS[2], "ModifySettlementCapacity")]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[3], TechniqueDefinitionScript.ACTIVE, 1, [typed_effect("content.%s" % RUN_TECHNIQUE_IDS[3], "GainStability")]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[4], TechniqueDefinitionScript.ACTIVE, 2, [typed_effect("content.%s" % RUN_TECHNIQUE_IDS[4], "GainStability", 2)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[5], TechniqueDefinitionScript.REACTION, 1, [typed_effect("content.%s" % RUN_TECHNIQUE_IDS[5], "PurgeContamination")], [], TechniqueDefinitionScript.REACTION_ENEMY_CONTAMINATION_ADDED),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[6], TechniqueDefinitionScript.ACTIVE, 1, [typed_effect("content.%s" % RUN_TECHNIQUE_IDS[6], "GainTP")]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[7], TechniqueDefinitionScript.REACTION, 2, [typed_effect("content.%s" % RUN_TECHNIQUE_IDS[7], "GainStability")], [], TechniqueDefinitionScript.REACTION_ENEMY_STABILITY_LOST),
		TechniqueDefinitionScript.new(CORE_TECHNIQUE_IDS[0], TechniqueDefinitionScript.CORE, 0, [typed_effect("content.%s" % CORE_TECHNIQUE_IDS[0], "GainTP")]),
		TechniqueDefinitionScript.new(CORE_TECHNIQUE_IDS[1], TechniqueDefinitionScript.CORE, 0, [typed_effect("content.%s" % CORE_TECHNIQUE_IDS[1], "ModifyReserveCapacity")]),
	]
	return result

static func _modifier_definitions() -> Array:
	return [
		TileModifierDefinitionScript.new(MODIFIER_IDS[0], "FLEXIBLE_IDENTITY", 1, [typed_effect("content.%s" % MODIFIER_IDS[0], "GainTP")]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[1], "RESERVE_BOUND", 1, [typed_effect("content.%s" % MODIFIER_IDS[1], "ModifyReserveCapacity")]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[2], "SETTLEMENT_FOCUS", 1, [typed_effect("content.%s" % MODIFIER_IDS[2], "ModifySettlementCapacity")]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[3], "RECYCLING", 1, [typed_effect("content.%s" % MODIFIER_IDS[3], "DrawTile")]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[4], "CLEAN_SURFACE", 1, [typed_effect("content.%s" % MODIFIER_IDS[4], "PurgeContamination")]),
	]

static func _enemy_definitions() -> Array:
	var result: Array = [
		EnemyDefinitionScript.new(
			NORMAL_ENEMY_IDS[0],
			_loop_graph("pressure_sentinel", [["pressure", LocalizationCatalogScript.text("CONTENT_PHASE2_0004"), 2, "PRESSURE"], ["recover", LocalizationCatalogScript.text("CONTENT_PHASE2_0005"), 1, "PRESSURE"]]),
			EnemyDefinitionScript.NORMAL,
			8,
			{"pressure_limit": 10, "integrity_damage": 0},
		),
		EnemyDefinitionScript.new(
			NORMAL_ENEMY_IDS[1],
			_loop_graph("wall_taxer", [["tax", LocalizationCatalogScript.text("CONTENT_PHASE2_0006"), 1, "WALL_TAX"], ["wait", LocalizationCatalogScript.text("CONTENT_PHASE2_0007"), 0, "PRESSURE"]]),
			EnemyDefinitionScript.NORMAL,
			7,
			{"draw_tax": 1, "pressure_limit": 9},
		),
		EnemyDefinitionScript.new(
			NORMAL_ENEMY_IDS[2],
			_loop_graph("integrity_collector", [["collect", LocalizationCatalogScript.text("CONTENT_PHASE2_0008"), 1, "INTEGRITY"], ["seal", LocalizationCatalogScript.text("CONTENT_PHASE2_0009"), 2, "INTEGRITY"]]),
			EnemyDefinitionScript.NORMAL,
			9,
			{"integrity_damage": 1, "pressure_limit": 10},
		),
		EnemyDefinitionScript.new(
			NORMAL_ENEMY_IDS[3],
			_loop_graph("contaminator", [["seed", LocalizationCatalogScript.text("CONTENT_PHASE2_0010"), 1, "CONTAMINATION"], ["spread", LocalizationCatalogScript.text("CONTENT_PHASE2_0011"), 2, "CONTAMINATION"]]),
			EnemyDefinitionScript.NORMAL,
			8,
			{"pressure_limit": 10},
			{"contamination_id": "base.contamination.clutter", "injection_count": 1},
		),
		EnemyDefinitionScript.new(
			ELITE_ENEMY_ID,
			_ledger_hunter_graph(),
			EnemyDefinitionScript.ELITE,
			14,
			{"pressure_limit": 12, "draw_tax": 1, "reward_multiplier": 2},
			{"contamination_id": "base.contamination.pressure_dross", "injection_count": 1},
		),
		EnemyDefinitionScript.new(
			BOSS_ID,
			_loop_graph("table_breaker", [["tempo", LocalizationCatalogScript.text("CONTENT_PHASE2_0012"), 2, "PRESSURE"], ["interfere", LocalizationCatalogScript.text("CONTENT_PHASE2_0013"), 2, "TABLE_INTERFERENCE"]]),
			EnemyDefinitionScript.BOSS,
			30,
			{"pressure_limit": 14, "boss": true},
			{"contamination_id": "base.contamination.fatigue_mold", "injection_count": 1},
			_boss_phases(),
		),
	]
	return result

static func _loop_graph(prefix: String, definitions: Array) -> IntentGraphScript:
	var intents: Array = []
	for index in definitions.size():
		var definition: Array = definitions[index]
		var current_id := "%s.%s" % [prefix, definition[0]]
		var next_id := "%s.%s" % [prefix, definitions[(index + 1) % definitions.size()][0]]
		intents.append(EnemyIntentScript.new(
			current_id,
			str(definition[1]),
			int(definition[2]),
			str(definition[3]),
			[IntentTransitionScript.fixed("%s.next" % current_id, next_id)],
		))
	return IntentGraphScript.new("%s.%s" % [prefix, definitions[0][0]], intents)

static func _ledger_hunter_graph() -> IntentGraphScript:
	var watch_id := "ledger_hunter.watch"
	var hunt_id := "ledger_hunter.hunt"
	var collect_id := "ledger_hunter.collect"
	var watch := EnemyIntentScript.new(
		watch_id,
		LocalizationCatalogScript.text("CONTENT_PHASE2_0014"),
		1,
		"AUDIT",
		[
			IntentTransitionScript.conditional(
				"ledger_hunter.high_pressure",
				hunt_id,
				PublicStateConditionScript.new("pressure", PublicStateConditionScript.GREATER_THAN_OR_EQUAL, 4),
			),
			IntentTransitionScript.conditional(
				"ledger_hunter.low_pressure",
				collect_id,
				PublicStateConditionScript.new("pressure", PublicStateConditionScript.LESS_THAN, 4),
			),
		],
	)
	var hunt := EnemyIntentScript.new(hunt_id, LocalizationCatalogScript.text("CONTENT_PHASE2_0015"), 3, "HUNT", [IntentTransitionScript.fixed("ledger_hunter.hunt.next", watch_id)])
	var collect := EnemyIntentScript.new(collect_id, LocalizationCatalogScript.text("CONTENT_PHASE2_0016"), 1, "REWARD_TAX", [IntentTransitionScript.fixed("ledger_hunter.collect.next", watch_id)])
	return IntentGraphScript.new(watch_id, [watch, hunt, collect])

static func _boss_phases() -> Array:
	return [
		{
			"phase_id": "tempo",
			"phase_role": "tempo",
			"max_hp": 30,
			"pressure_limit": 14,
			"pressure_relief": 1,
			"intent_graph": _loop_graph("table_breaker.tempo", [["open", LocalizationCatalogScript.text("CONTENT_PHASE2_0017"), 2, "PRESSURE"], ["echo", LocalizationCatalogScript.text("CONTENT_PHASE2_0018"), 1, "PRESSURE"]]),
		},
		{
			"phase_id": "table_interference",
			"phase_role": "table_interference",
			"max_hp": 20,
			"pressure_limit": 12,
			"pressure_relief": 2,
			"intent_graph": _loop_graph("table_breaker.interference", [["jam", LocalizationCatalogScript.text("CONTENT_PHASE2_0019"), 2, "TABLE_INTERFERENCE"], ["tax", LocalizationCatalogScript.text("CONTENT_PHASE2_0020"), 1, "WALL_TAX"]]),
		},
		{
			"phase_id": "rule_breaker",
			"phase_role": "rule_breaker",
			"max_hp": 10,
			"pressure_limit": 10,
			"pressure_relief": 3,
			"intent_graph": _loop_graph("table_breaker.rule_breaker", [["rewrite", LocalizationCatalogScript.text("CONTENT_PHASE2_0021"), 3, "RULE_BREAKER"], ["seal", LocalizationCatalogScript.text("CONTENT_PHASE2_0022"), 2, "RULE_BREAKER"]]),
		},
	]

static func _encounter_definitions() -> Array:
	var result: Array = []
	result.append_array(_encounter_variants("base.encounter.intro", NORMAL_ENEMY_IDS[0], EncounterDefinitionScript.NORMAL))
	result.append_array(_encounter_variants("base.encounter.normal.left", NORMAL_ENEMY_IDS[1], EncounterDefinitionScript.NORMAL))
	result.append_array(_encounter_variants("base.encounter.normal.right", NORMAL_ENEMY_IDS[2], EncounterDefinitionScript.NORMAL))
	result.append_array(_encounter_variants("base.encounter.normal.mid", NORMAL_ENEMY_IDS[3], EncounterDefinitionScript.NORMAL))
	result.append_array(_encounter_variants("base.encounter.elite", ELITE_ENEMY_ID, EncounterDefinitionScript.ELITE))
	result.append_array(_encounter_variants("base.encounter.boss", BOSS_ID, EncounterDefinitionScript.BOSS))
	return result

static func _encounter_variants(base_id: String, enemy_id: String, kind: String) -> Array:
	return [
		EncounterDefinitionScript.new(base_id, [enemy_id], kind, {"variant": "base"}),
		EncounterDefinitionScript.new("%s.a" % base_id, [enemy_id], kind, {"variant": "a"}),
		EncounterDefinitionScript.new("%s.b" % base_id, [enemy_id], kind, {"variant": "b"}),
	]

static func _event_definitions() -> Array:
	return [
		EventDefinitionScript.new(EVENT_IDS[0], [
			{"choice_id": "spend_token", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_0023"), "effects": [typed_effect("event.tile_surgery.spend", "ModifyRefinementTokens", -1)]},
			{"choice_id": "leave", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_LABEL_0030"), "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(EVENT_IDS[1], [
			{"choice_id": "accept", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_0024"), "effects": [typed_effect("event.risk_bargain.accept", "ApplyRunModifier", 1)]},
			{"choice_id": "leave", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_LABEL_0031"), "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(EVENT_IDS[2], [
			{"choice_id": "exchange", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_0025"), "effects": [typed_effect("event.gold_exchange.exchange", "ModifyRunCurrency", -3)]},
			{"choice_id": "leave", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_LABEL_0032"), "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(EVENT_IDS[3], [
			{"choice_id": "reveal", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_0026"), "effects": [{"kind": "MAP_REVEAL", "node_ids": ["base.map_node.shop", "base.map_node.workshop", "base.map_node.elite"]}]},
			{"choice_id": "leave", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_LABEL_0033"), "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(EVENT_IDS[4], [
			{"choice_id": "carry_clause", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_0027"), "effects": [typed_effect("event.contract_clause.apply", "ApplyRunModifier", 1)]},
			{"choice_id": "leave", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_LABEL_0034"), "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(EVENT_IDS[5], [
			{"choice_id": "remember", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_0028"), "effects": [typed_effect("event.rule_memory.remember", "GainTP", 1)]},
			{"choice_id": "leave", "label": LocalizationCatalogScript.text("CONTENT_PHASE2_LABEL_0035"), "is_skip": true, "effects": []},
		]),
	]

static func _map_definitions() -> Array:
	var map_definition: MapDefinitionScript = MiniActMapCatalogScript.definition()
	var result: Array = []
	for node_id in map_definition.node_ids:
		result.append(map_definition.node_definition(node_id))
	result.append(map_definition)
	return result

static func _pool_definitions() -> Array:
	var membership := pool_membership()
	return [
		RewardPoolDefinitionScript.new(REWARD_POOL_ID, _pool_entries(membership[REWARD_POOL_ID]), [], RewardPoolDefinitionScript.REWARD),
		RewardPoolDefinitionScript.new(BOSS_RULE_BREAKER_POOL_ID, _pool_entries(membership[BOSS_RULE_BREAKER_POOL_ID]), [], RewardPoolDefinitionScript.REWARD),
		RewardPoolDefinitionScript.new(SHOP_POOL_ID, _pool_entries(membership[SHOP_POOL_ID]), [], RewardPoolDefinitionScript.SHOP),
		RewardPoolDefinitionScript.new(WORKSHOP_POOL_ID, _pool_entries(membership[WORKSHOP_POOL_ID]), [], RewardPoolDefinitionScript.WORKSHOP),
	]

static func _pool_entries(content_ids: Array) -> Array:
	var result: Array = []
	for content_id in content_ids:
		result.append({"content_id": content_id, "weight": 1})
	return result

static func _sorted_ids(content_ids: Array) -> Array:
	var result: Array = content_ids.duplicate()
	result.sort()
	return result
