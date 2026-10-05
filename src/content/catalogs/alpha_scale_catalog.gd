class_name AlphaScaleCatalog
extends RefCounted
const ContentTextCatalogScript = preload("res://src/content/text/content_text_catalog.gd")

const ContentDefinitionScript = preload("res://src/content/definitions/content_definition.gd")
const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const CharacterPassiveDefinitionScript = preload("res://src/content/definitions/character_passive_definition.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const EventDefinitionScript = preload("res://src/content/definitions/event_definition.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const EnemyDefinitionScript = preload("res://src/content/definitions/enemy_definition.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const RewardPoolDefinitionScript = preload("res://src/content/definitions/reward_pool_definition.gd")
const RuleBreakerDefinitionScript = preload("res://src/content/definitions/rule_breaker_definition.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")
const YakuDefinitionScript = preload("res://src/content/definitions/yaku_definition.gd")
const EnemyIntentScript = preload("res://src/domain/combat/enemy_intent.gd")
const IntentGraphScript = preload("res://src/domain/combat/intent_graph.gd")
const IntentTransitionScript = preload("res://src/domain/combat/intent_transition.gd")

const CHARACTER_ID := "alpha.character.harbor_reader"
const CORE_TECHNIQUE_ID := "alpha.technique.core.harbor_read"
const PASSIVE_ID := "alpha.passive.harbor_read"
const CONTRACT_IDS := [
	"alpha.contract.quiet_current",
	"alpha.contract.open_ledger",
	"alpha.contract.brittle_compass",
	"alpha.contract.long_current",
	"alpha.contract.house_tithe",
]
## These are the Scale Contracts present in persisted Stage 3 unlock profiles.
const STAGE_3_CONTRACT_IDS := [
	"alpha.contract.quiet_current",
	"alpha.contract.open_ledger",
	"alpha.contract.brittle_compass",
]
const YAKU_IDS := [
	"alpha.yaku.double_sequence",
	"alpha.yaku.triplet_row",
	"alpha.yaku.pair_archive",
	"alpha.yaku.honor_chorus",
	"alpha.yaku.character_flow",
	"alpha.yaku.dotted_river",
	"alpha.yaku.sequence_pair",
	"alpha.yaku.mixed_quartet",
	"alpha.yaku.sequence_cascade",
	"alpha.yaku.triplet_duet",
	"alpha.yaku.quad_duet",
	"alpha.yaku.pair_triad",
	"alpha.yaku.sequence_triplet",
	"alpha.yaku.sequence_quad",
	"alpha.yaku.triplet_quad",
	"alpha.yaku.triplet_pair",
	"alpha.yaku.quad_pair",
	"alpha.yaku.sequence_triplet_pair",
	"alpha.yaku.honor_beacon",
	"alpha.yaku.honor_gathering",
	"alpha.yaku.character_majority",
	"alpha.yaku.dot_majority",
]
const ACT_ONE_RELIC_IDS := [
	"alpha.relic.act_one.tide_whistle",
	"alpha.relic.act_one.ceramic_dial",
	"alpha.relic.act_one.harbor_notch",
	"alpha.relic.act_one.settlement_chart",
	"alpha.relic.act_one.steady_keel",
	"alpha.relic.act_one.clean_wake",
	"alpha.relic.act_one.trade_current",
]
const NEW_ACT_TWO_RELIC_IDS := [
	"alpha.relic.act_two.echo_lens",
	"alpha.relic.act_two.crosswind_signal",
	"alpha.relic.act_two.deep_reserve",
	"alpha.relic.act_two.settlement_chart",
	"alpha.relic.act_two.pressure_rivet",
	"alpha.relic.act_two.ink_filter",
	"alpha.relic.act_two.cargo_ledger",
]
const RELIC_IDS := [
	"alpha.relic.act_two.echo_index",
	"alpha.relic.act_two.twin_current",
	"alpha.relic.act_two.reserve_lamp",
	"alpha.relic.act_two.pressure_vent",
	"alpha.relic.act_two.wall_surveyor",
	"alpha.relic.act_two.ledger_shard",
	"alpha.relic.act_two.settlement_seal",
	"alpha.relic.act_two.quiet_coin",
	"alpha.relic.act_two.clean_ink",
	"alpha.relic.act_two.triplet_compass",
	"alpha.relic.act_two.sequence_compass",
	"alpha.relic.act_two.pairing_knot",
	"alpha.relic.act_two.honor_chime",
	"alpha.relic.act_two.reserve_ribbon",
	"alpha.relic.act_two.stability_cord",
	"alpha.relic.act_two.draw_wick",
	"alpha.relic.act_two.pressure_bell",
	"alpha.relic.act_two.final_margin",
	"alpha.relic.act_two.echo_lens",
	"alpha.relic.act_two.crosswind_signal",
	"alpha.relic.act_two.deep_reserve",
	"alpha.relic.act_two.settlement_chart",
	"alpha.relic.act_two.pressure_rivet",
	"alpha.relic.act_two.ink_filter",
	"alpha.relic.act_two.cargo_ledger",
]
const RUN_TECHNIQUE_IDS := [
	"alpha.technique.river_step",
	"alpha.technique.pressure_turn",
	"alpha.technique.reserve_survey",
	"alpha.technique.cleansing_call",
	"alpha.technique.settlement_mirror",
	"alpha.technique.last_measure",
	"alpha.technique.draw_capacity",
	"alpha.technique.pressure_dividend",
	"alpha.technique.harbor_strike",
	"alpha.technique.tide_draw",
	"alpha.technique.ledger_wind",
	"alpha.technique.refinement_practice",
	"alpha.technique.first_measure",
]
const MODIFIER_IDS := [
	"alpha.modifier.harbor_mark",
	"alpha.modifier.double_edge",
	"alpha.modifier.quiet_surface",
	"alpha.modifier.wide_channel",
	"alpha.modifier.sharp_current",
	"alpha.modifier.trade_mark",
	"alpha.modifier.refinement_trace",
]
const ACT_ONE_EVENT_IDS := [
	"alpha.event.act_one.tile_surgery",
	"alpha.event.act_one.risk_bargain",
	"alpha.event.act_one.gold_exchange",
	"alpha.event.act_one.map_reveal",
	"alpha.event.act_one.contract_clause",
	"alpha.event.act_one.rule_memory",
]

const ACT_ONE_BOSS_RULE_BREAKER_IDS := [
	"base.rule_breaker.open_table",
	"base.rule_breaker.reserve_witness",
	"base.rule_breaker.draw_twice",
	"alpha.rule_breaker.act_one.stability_surge",
	"alpha.rule_breaker.act_one.tactical_reserve",
]
const ACT_TWO_BOSS_RULE_BREAKER_IDS := [
	"alpha.rule_breaker.act_two.settlement_capacity",
	"alpha.rule_breaker.act_two.reserve_capacity",
	"alpha.rule_breaker.act_two.draw_actions",
	"alpha.rule_breaker.act_two.ledger_dividend",
	"alpha.rule_breaker.act_two.early_tile",
]

const ACT_ONE_BUILD_POOL_ID := "alpha.reward_pool.act_one_build"
const ACT_TWO_BUILD_POOL_ID := "alpha.reward_pool.act_two_build"
const ACT_TWO_SHOP_POOL_ID := "alpha.shop_pool.act_two_build"
const WORKSHOP_POOL_ID := "alpha.workshop_pool.scale"
const ACT_ONE_BOSS_RULE_BREAKER_POOL_ID := "alpha.reward_pool.boss_rule_breaker_act_one"
const ACT_TWO_BOSS_RULE_BREAKER_POOL_ID := "alpha.reward_pool.boss_rule_breaker_act_two"
const CONTENT_BUNDLE_ID := "alpha.scale"
const CONTENT_BUNDLE_VERSION := "v12"
const ACT_ONE_BOSS_ENEMY_ID := "alpha.boss.act_one.harbor_arbiter"
const ACT_ONE_BOSS_ENCOUNTER_ID := "base.encounter.boss.c"
const ACT_ONE_NORMAL_ENEMY_IDS := [
	"alpha.enemy.act_one.fog_caller",
	"alpha.enemy.act_one.margin_taker",
	"alpha.enemy.act_one.signal_keeper",
]
const ACT_TWO_NORMAL_ENEMY_IDS := [
	"alpha.enemy.act_two.contract_harrier",
	"alpha.enemy.act_two.echo_courier",
	"alpha.enemy.act_two.lien_keeper",
]
const ACT_ONE_ELITE_ENEMY_IDS := [
	"alpha.enemy.act_one.elite.clockwork_auditor",
	"alpha.enemy.act_one.elite.drift_captain",
]
const ACT_TWO_ELITE_ENEMY_IDS := [
	"alpha.enemy.act_two.elite.margin_enforcer",
	"alpha.enemy.act_two.elite.infernal_index",
]
const ACT_ONE_NORMAL_ENCOUNTER_IDS := [
	"alpha.encounter.act_one.normal.fog_caller",
	"alpha.encounter.act_one.normal.margin_taker",
	"alpha.encounter.act_one.normal.signal_keeper",
]
const ACT_TWO_NORMAL_ENCOUNTER_IDS := [
	"alpha.encounter.act_two.normal.contract_harrier",
	"alpha.encounter.act_two.normal.echo_courier",
	"alpha.encounter.act_two.normal.lien_keeper",
]
const ACT_ONE_ELITE_ENCOUNTER_IDS := [
	"alpha.encounter.act_one.elite.clockwork_auditor",
	"alpha.encounter.act_one.elite.drift_captain",
]
const ACT_TWO_ELITE_ENCOUNTER_IDS := [
	"alpha.encounter.act_two.elite.margin_enforcer",
	"alpha.encounter.act_two.elite.infernal_index",
]

static func register_all(registry) -> RefCounted:
	return registry.register_bundle(CONTENT_BUNDLE_ID, CONTENT_BUNDLE_VERSION, definitions())

static func definitions() -> Array:
	var result: Array = [
		CharacterPassiveDefinitionScript.new(
			PASSIVE_ID,
			CharacterPassiveDefinitionScript.AFTER_COMPLETE_HAND,
			ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0001"),
			ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0002"),
			[Phase2CatalogScript.typed_effect("content.%s" % PASSIVE_ID, "GainTP", 1)],
		),
		_character_definition(),
		_core_technique_definition(),	]
	result.append_array(_contract_definitions())
	result.append_array(_yaku_definitions())
	result.append_array(_relic_definitions())
	result.append_array(_run_technique_definitions())
	result.append_array(_modifier_definitions())
	result.append_array(_rule_breaker_definitions())
	result.append_array(_enemy_definitions())
	result.append_array(_encounter_definitions())
	result.append_array(_event_definitions())
	result.append_array(_pool_definitions())
	result.append_array(_boss_rule_breaker_pool_definitions())
	return result

static func _event_definitions() -> Array:
	return [
		EventDefinitionScript.new(ACT_ONE_EVENT_IDS[0], [
			{
				"choice_id": "trade_gold",
				"label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0003"),
				"effects": [_event_currency_effect("GOLD", -2), _event_currency_effect("REFINEMENT_TOKENS", 1)],
			},
			{"choice_id": "leave", "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0004"), "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(ACT_ONE_EVENT_IDS[1], [
			{
				"choice_id": "take_advance",
				"label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0005"),
				"effects": [_event_currency_effect("REFINEMENT_TOKENS", -1)],
				"alternatives": [
					{"alternative_id": "paid_on_time", "weight": 1, "effects": [_event_currency_effect("GOLD", 6)]},
					{"alternative_id": "missed_payment", "weight": 1, "effects": [_event_currency_effect("GOLD", -2)]},
				],
			},
			{"choice_id": "leave", "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0006"), "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(ACT_ONE_EVENT_IDS[2], [
			{
				"choice_id": "exchange",
				"label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0007"),
				"effects": [_event_currency_effect("GOLD", -3), _event_currency_effect("REFINEMENT_TOKENS", 1)],
			},
			{"choice_id": "leave", "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0008"), "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(ACT_ONE_EVENT_IDS[3], [
			{"choice_id": "reveal_route", "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0009"), "effects": [{"kind": "MAP_REVEAL", "node_ids": ["base.map_node.elite", "base.map_node.boss"]}]},
			{"choice_id": "leave", "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0010"), "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(ACT_ONE_EVENT_IDS[4], [
			{"choice_id": "carry_clause", "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0011"), "effects": [_event_modifier_effect("event.contract_clause.apply", "RUN", 1, "REPLACE", [{"operation_id": "ModifySettlementCapacity", "amount": 1}])]},
			{"choice_id": "leave", "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0012"), "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(ACT_ONE_EVENT_IDS[5], [
			{"choice_id": "remember_rule", "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0013"), "effects": [_event_modifier_effect("event.act_two.rule_memory", "RUN", 1, "UNIQUE", [{"operation_id": "GainTP", "amount": 1}]), _event_currency_effect("REFINEMENT_TOKENS", 1)]},
			{"choice_id": "leave", "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0014"), "is_skip": true, "effects": []},
		]),
	]

static func _event_currency_effect(currency: String, amount: int) -> Dictionary:
	return {"kind": currency, "amount": amount}

static func _event_modifier_effect(modifier_id: String, scope: String, duration_amount: int, stack_policy: String, battle_entry_operations: Array = []) -> Dictionary:
	return {
		"kind": "RUN_MODIFIER",
		"modifier_id": modifier_id,
		"value": 1,
		"scope": scope,
		"duration_amount": duration_amount,
		"stack_policy": stack_policy,
		"source_id": modifier_id,
		"parameters": {"battle_entry_operations": battle_entry_operations.duplicate(true)},
	}

static func _enemy_definitions() -> Array:
	return [
		EnemyDefinitionScript.new(
			ACT_ONE_NORMAL_ENEMY_IDS[0],
			_loop_graph("fog_caller", [["seed", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0015"), 1, EnemyIntentScript.CONTAMINATION], ["press", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0016"), 2, EnemyIntentScript.PRESSURE]]),
			EnemyDefinitionScript.NORMAL,
			8,
			{"pressure_limit": 10},
		),
		EnemyDefinitionScript.new(
			ACT_ONE_NORMAL_ENEMY_IDS[1],
			_loop_graph("margin_taker", [["tax", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0017"), 1, EnemyIntentScript.WALL_TAX], ["collect", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0018"), 2, EnemyIntentScript.INTEGRITY]]),
			EnemyDefinitionScript.NORMAL,
			9,
			{"draw_tax": 1, "pressure_limit": 10, "integrity_damage": 1},
		),
		EnemyDefinitionScript.new(
			ACT_ONE_NORMAL_ENEMY_IDS[2],
			_loop_graph("signal_keeper", [["audit", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0019"), 1, EnemyIntentScript.AUDIT], ["press", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0020"), 2, EnemyIntentScript.PRESSURE]]),
			EnemyDefinitionScript.NORMAL,
			8,
			{"pressure_limit": 10},
		),
		EnemyDefinitionScript.new(
			ACT_TWO_NORMAL_ENEMY_IDS[0],
			_loop_graph("contract_harrier", [["audit", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0021"), 1, EnemyIntentScript.AUDIT], ["hunt", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0022"), 3, EnemyIntentScript.HUNT]]),
			EnemyDefinitionScript.NORMAL,
			10,
			{"pressure_limit": 11},
		),
		EnemyDefinitionScript.new(
			ACT_TWO_NORMAL_ENEMY_IDS[1],
			_loop_graph("echo_courier", [["echo", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0023"), 1, EnemyIntentScript.CONTAMINATION], ["thin", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0024"), 2, EnemyIntentScript.WALL_TAX]]),
			EnemyDefinitionScript.NORMAL,
			10,
			{"pressure_limit": 11, "draw_tax": 1},
		),
		EnemyDefinitionScript.new(
			ACT_TWO_NORMAL_ENEMY_IDS[2],
			_loop_graph("lien_keeper", [["lien", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0025"), 2, EnemyIntentScript.INTEGRITY], ["collect", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0026"), 1, EnemyIntentScript.REWARD_TAX]]),
			EnemyDefinitionScript.NORMAL,
			11,
			{"pressure_limit": 12, "integrity_damage": 1},
		),
		EnemyDefinitionScript.new(
			ACT_ONE_ELITE_ENEMY_IDS[0],
			_loop_graph("clockwork_auditor", [["audit", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0027"), 2, EnemyIntentScript.AUDIT], ["collect", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0028"), 1, EnemyIntentScript.REWARD_TAX], ["hunt", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0029"), 3, EnemyIntentScript.HUNT]]),
			EnemyDefinitionScript.ELITE,
			15,
			{"pressure_limit": 12, "draw_tax": 1, "reward_multiplier": 2},
		),
		EnemyDefinitionScript.new(
			ACT_ONE_ELITE_ENEMY_IDS[1],
			_loop_graph("drift_captain", [["hunt", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0030"), 3, EnemyIntentScript.HUNT], ["tax", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0031"), 2, EnemyIntentScript.WALL_TAX], ["press", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0032"), 2, EnemyIntentScript.PRESSURE]]),
			EnemyDefinitionScript.ELITE,
			16,
			{"pressure_limit": 12, "draw_tax": 1, "reward_multiplier": 2},
		),
		EnemyDefinitionScript.new(
			ACT_TWO_ELITE_ENEMY_IDS[0],
			_loop_graph("margin_enforcer", [["audit", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0033"), 2, EnemyIntentScript.AUDIT], ["tax", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0034"), 2, EnemyIntentScript.WALL_TAX], ["integrity", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0035"), 2, EnemyIntentScript.INTEGRITY]]),
			EnemyDefinitionScript.ELITE,
			18,
			{"pressure_limit": 13, "draw_tax": 1, "integrity_damage": 1, "reward_multiplier": 2},
		),
		EnemyDefinitionScript.new(
			ACT_TWO_ELITE_ENEMY_IDS[1],
			_loop_graph("infernal_index", [["index", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0036"), 2, EnemyIntentScript.CONTAMINATION], ["burn", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0037"), 3, EnemyIntentScript.PRESSURE], ["audit", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0038"), 2, EnemyIntentScript.AUDIT]]),
			EnemyDefinitionScript.ELITE,
			19,
			{"pressure_limit": 13, "reward_multiplier": 2},
		),
		EnemyDefinitionScript.new(
			ACT_ONE_BOSS_ENEMY_ID,
			_loop_graph("act_one.harbor_arbiter", [
				["survey", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0039"), 1, EnemyIntentScript.AUDIT],
				["press", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0040"), 3, EnemyIntentScript.PRESSURE],
			]),
			EnemyDefinitionScript.BOSS,
			40,
			{"pressure_limit": 15, "draw_tax": 1},
			{},
			_harbor_arbiter_boss_phases(),
		),
	]

static func _encounter_definitions() -> Array:
	var result: Array = []
	for index in ACT_ONE_NORMAL_ENEMY_IDS.size():
		result.append(EncounterDefinitionScript.new(
			ACT_ONE_NORMAL_ENCOUNTER_IDS[index],
			[ACT_ONE_NORMAL_ENEMY_IDS[index]],
			EncounterDefinitionScript.NORMAL,
			{"act": 1, "variant": "scale"},
		))
	for index in ACT_TWO_NORMAL_ENEMY_IDS.size():
		result.append(EncounterDefinitionScript.new(
			ACT_TWO_NORMAL_ENCOUNTER_IDS[index],
			[ACT_TWO_NORMAL_ENEMY_IDS[index]],
			EncounterDefinitionScript.NORMAL,
			{"act": 2, "variant": "scale"},
		))
	for index in ACT_ONE_ELITE_ENEMY_IDS.size():
		result.append(EncounterDefinitionScript.new(
			ACT_ONE_ELITE_ENCOUNTER_IDS[index],
			[ACT_ONE_ELITE_ENEMY_IDS[index]],
			EncounterDefinitionScript.ELITE,
			{"act": 1, "variant": "scale"},
		))
	for index in ACT_TWO_ELITE_ENEMY_IDS.size():
		result.append(EncounterDefinitionScript.new(
			ACT_TWO_ELITE_ENCOUNTER_IDS[index],
			[ACT_TWO_ELITE_ENEMY_IDS[index]],
			EncounterDefinitionScript.ELITE,
			{"act": 2, "variant": "scale"},
		))
	result.append(EncounterDefinitionScript.new(
			ACT_ONE_BOSS_ENCOUNTER_ID,
			[ACT_ONE_BOSS_ENEMY_ID],
			EncounterDefinitionScript.BOSS,
			{"act": 1, "variant": "c"},
		))
	return result

static func _harbor_arbiter_boss_phases() -> Array:
	return [
		{
			"phase_id": "soundings",
			"phase_role": "soundings",
			"max_hp": 18,
			"pressure_limit": 15,
			"pressure_relief": 1,
			"intent_graph": _loop_graph("act_one.harbor_arbiter.soundings", [
				["measure", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0041"), 1, EnemyIntentScript.AUDIT],
				["draft", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0042"), 2, EnemyIntentScript.PRESSURE],
			]),
		},
		{
			"phase_id": "crosswind",
			"phase_role": "crosswind",
			"max_hp": 13,
			"pressure_limit": 13,
			"pressure_relief": 2,
			"intent_graph": _loop_graph("act_one.harbor_arbiter.crosswind", [
				["thin", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0043"), 2, EnemyIntentScript.WALL_TAX],
				["collect", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0044"), 2, EnemyIntentScript.INTEGRITY],
			]),
		},
		{
			"phase_id": "low_tide",
			"phase_role": "low_tide",
			"max_hp": 9,
			"pressure_limit": 11,
			"pressure_relief": 3,
			"intent_graph": _loop_graph("act_one.harbor_arbiter.low_tide", [
				["seal", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0045"), 2, EnemyIntentScript.RULE_BREAKER],
				["claim", ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0046"), 1, EnemyIntentScript.REWARD_TAX],
			]),
		},
	]

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

static func pool_membership() -> Dictionary:
	var baseline_build := _sorted_ids(Phase2CatalogScript.RELIC_IDS + ACT_ONE_RELIC_IDS + Phase2CatalogScript.RUN_TECHNIQUE_IDS + RUN_TECHNIQUE_IDS)
	var scale_build := _sorted_ids(Phase2CatalogScript.RELIC_IDS + ACT_ONE_RELIC_IDS + RELIC_IDS + Phase2CatalogScript.RUN_TECHNIQUE_IDS + RUN_TECHNIQUE_IDS)
	return {
		ACT_ONE_BUILD_POOL_ID: baseline_build,
		ACT_TWO_BUILD_POOL_ID: scale_build,
		ACT_TWO_SHOP_POOL_ID: scale_build.duplicate(),
		WORKSHOP_POOL_ID: _sorted_ids(Phase2CatalogScript.MODIFIER_IDS + MODIFIER_IDS),
		ACT_ONE_BOSS_RULE_BREAKER_POOL_ID: _sorted_ids(ACT_ONE_BOSS_RULE_BREAKER_IDS),
		ACT_TWO_BOSS_RULE_BREAKER_POOL_ID: _sorted_ids(ACT_TWO_BOSS_RULE_BREAKER_IDS),
	}

static func all_character_ids() -> Array[String]:
	return _string_ids(Phase2CatalogScript.CHARACTER_IDS + [CHARACTER_ID])

static func all_contract_ids() -> Array[String]:
	return _string_ids(Phase2CatalogScript.CONTRACT_IDS + CONTRACT_IDS)

static func _character_definition():
	return CharacterDefinitionScript.new(
		CHARACTER_ID,
		_honor_tile_bias(),
		"base.relic.rule_memory",
		CORE_TECHNIQUE_ID,
		PASSIVE_ID,
	)

static func _core_technique_definition():
	return TechniqueDefinitionScript.new(
		CORE_TECHNIQUE_ID,
		TechniqueDefinitionScript.CORE,
		0,
		[Phase2CatalogScript.typed_effect("content.%s" % CORE_TECHNIQUE_ID, "GainStability", 1)],
	)

static func _contract_definitions() -> Array:
	return [
		ContractDefinitionScript.new(
			CONTRACT_IDS[0],
			ContractDefinitionScript.PRESSURE,
			{"initial_pressure_per_battle": 2},
			{"starting_tp_per_battle": 1, "refinement_tokens_on_elite_skip": 1},
			{"path": "quiet_current", "flexibility": "normal", "preferred_tile_ids": ["base.tile.honors.east", "base.tile.honors.south"]},
		),
		ContractDefinitionScript.new(
			CONTRACT_IDS[1],
			ContractDefinitionScript.POOL_BIAS,
			{"normal_reward_off_suit_choice_cap": 0},
			{"reward_tile_suit_bias": "characters", "yaku_signal": "Sequence"},
			{"path": "open_ledger", "flexibility": "reduced", "preferred_tile_ids": ["base.tile.characters.4", "base.tile.characters.5", "base.tile.characters.6"]},
		),
		ContractDefinitionScript.new(
			CONTRACT_IDS[2],
			ContractDefinitionScript.REFINEMENT_DEBT,
			{"elite_skip_gold_penalty": 2, "workshop_refinement_gold_surcharge": 1},
			{"refinement_tokens_on_contract_selection": 1, "extra_modified_tile_choice": true},
			{"path": "brittle_compass", "flexibility": "route-dependent", "preferred_tile_ids": ["base.tile.dots.4", "base.tile.dots.5", "base.tile.dots.6"]},
		),
		ContractDefinitionScript.new(
			CONTRACT_IDS[3],
			ContractDefinitionScript.PRESSURE,
			{"initial_pressure_per_battle": 3},
			{"starting_tp_per_battle": 2},
			{"path": "long_current", "flexibility": "steady", "preferred_tile_ids": ["base.tile.honors.west", "base.tile.honors.north"]},
		),
		ContractDefinitionScript.new(
			CONTRACT_IDS[4],
			ContractDefinitionScript.REFINEMENT_DEBT,
			{"elite_skip_gold_penalty": 4},
			{"refinement_tokens_on_elite_skip": 2},
			{"path": "house_tithe", "flexibility": "route-dependent", "preferred_tile_ids": ["base.tile.bamboo.2", "base.tile.bamboo.3"]},
		),
	]

static func _yaku_definitions() -> Array:
	var result: Array = []
	result.append(_yaku(YAKU_IDS[0], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0047"), YakuDefinitionScript.BOTH, YakuDefinitionScript.STRUCTURAL, YakuDefinitionScript.PATTERN_COUNT, {"pattern_type": "Sequence", "target": 2, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_LABEL_0076"), "local_pattern_types": ["Sequence"]}, 8, 14))
	result.append(_yaku(YAKU_IDS[1], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0048"), YakuDefinitionScript.BOTH, YakuDefinitionScript.STRUCTURAL, YakuDefinitionScript.PATTERN_COUNT, {"pattern_type": "Triplet", "target": 3, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_LABEL_0077"), "local_pattern_types": ["Triplet", "Quad"]}, 9, 16))
	result.append(_yaku(YAKU_IDS[2], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0049"), YakuDefinitionScript.BOTH, YakuDefinitionScript.STRUCTURAL, YakuDefinitionScript.PATTERN_COUNT, {"pattern_type": "Pair", "target": 2, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_LABEL_0078"), "local_pattern_types": ["Pair"]}, 7, 13))
	result.append(_yaku(YAKU_IDS[3], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0050"), YakuDefinitionScript.COMPLETE_HAND, YakuDefinitionScript.SUIT_HONOR, YakuDefinitionScript.TILE_CONDITION, {"suit": "honors", "target": 5, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0051")}, 0, 15))
	result.append(_yaku(YAKU_IDS[4], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0052"), YakuDefinitionScript.BOTH, YakuDefinitionScript.SUIT_HONOR, YakuDefinitionScript.SUIT_CONCENTRATION, {"suit": "characters", "target": 9, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0053")}, 9, 17))
	result.append(_yaku(YAKU_IDS[5], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0054"), YakuDefinitionScript.BOTH, YakuDefinitionScript.SUIT_HONOR, YakuDefinitionScript.SUIT_CONCENTRATION, {"suit": "dots", "target": 9, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0055")}, 9, 17))
	result.append(_yaku(YAKU_IDS[6], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0056"), YakuDefinitionScript.BOTH, YakuDefinitionScript.ROGUELIKE_STRUCTURAL, YakuDefinitionScript.GROUP_SHAPE, {"required_patterns": ["Sequence", "Pair"], "local_pattern_types": ["Sequence", "Pair"]}, 10, 18))
	result.append(_yaku(YAKU_IDS[7], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0057"), YakuDefinitionScript.BOTH, YakuDefinitionScript.ROGUELIKE_STRUCTURAL, YakuDefinitionScript.GROUP_SHAPE, {"required_patterns": ["Sequence", "Triplet", "Quad", "Pair"], "local_pattern_types": ["Sequence", "Triplet", "Quad", "Pair"]}, 13, 22))
	result.append(_yaku(YAKU_IDS[8], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0058"), YakuDefinitionScript.BOTH, YakuDefinitionScript.STRUCTURAL, YakuDefinitionScript.PATTERN_COUNT, {"pattern_type": "Sequence", "target": 3, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_LABEL_0079"), "local_pattern_types": ["Sequence"]}, 9, 16))
	result.append(_yaku(YAKU_IDS[9], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0059"), YakuDefinitionScript.BOTH, YakuDefinitionScript.STRUCTURAL, YakuDefinitionScript.PATTERN_COUNT, {"pattern_type": "Triplet", "target": 2, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_LABEL_0080"), "local_pattern_types": ["Triplet", "Quad"]}, 9, 16))
	result.append(_yaku(YAKU_IDS[10], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0060"), YakuDefinitionScript.LOCAL_SETTLEMENT, YakuDefinitionScript.STRUCTURAL, YakuDefinitionScript.PATTERN_COUNT, {"pattern_type": "Quad", "target": 2, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_LABEL_0081"), "local_pattern_types": ["Quad"]}, 12, 0))
	result.append(_yaku(YAKU_IDS[11], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0061"), YakuDefinitionScript.LOCAL_SETTLEMENT, YakuDefinitionScript.STRUCTURAL, YakuDefinitionScript.PATTERN_COUNT, {"pattern_type": "Pair", "target": 3, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_LABEL_0082"), "local_pattern_types": ["Pair"]}, 10, 0))
	result.append(_yaku(YAKU_IDS[12], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0062"), YakuDefinitionScript.BOTH, YakuDefinitionScript.ROGUELIKE_STRUCTURAL, YakuDefinitionScript.GROUP_SHAPE, {"required_patterns": ["Sequence", "Triplet"], "local_pattern_types": ["Sequence", "Triplet"]}, 10, 18))
	result.append(_yaku(YAKU_IDS[13], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0063"), YakuDefinitionScript.BOTH, YakuDefinitionScript.ROGUELIKE_STRUCTURAL, YakuDefinitionScript.GROUP_SHAPE, {"required_patterns": ["Sequence", "Quad"], "local_pattern_types": ["Sequence", "Quad"]}, 12, 20))
	result.append(_yaku(YAKU_IDS[14], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0064"), YakuDefinitionScript.BOTH, YakuDefinitionScript.ROGUELIKE_STRUCTURAL, YakuDefinitionScript.GROUP_SHAPE, {"required_patterns": ["Triplet", "Quad"], "local_pattern_types": ["Triplet", "Quad"]}, 12, 20))
	# Complete Hand interpretations store their pair separately from `groups`, so pair-shaped Yaku stay local.
	result.append(_yaku(YAKU_IDS[15], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0065"), YakuDefinitionScript.LOCAL_SETTLEMENT, YakuDefinitionScript.ROGUELIKE_STRUCTURAL, YakuDefinitionScript.GROUP_SHAPE, {"required_patterns": ["Triplet", "Pair"], "local_pattern_types": ["Triplet", "Pair"]}, 9, 0))
	result.append(_yaku(YAKU_IDS[16], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0066"), YakuDefinitionScript.LOCAL_SETTLEMENT, YakuDefinitionScript.ROGUELIKE_STRUCTURAL, YakuDefinitionScript.GROUP_SHAPE, {"required_patterns": ["Quad", "Pair"], "local_pattern_types": ["Quad", "Pair"]}, 11, 0))
	result.append(_yaku(YAKU_IDS[17], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0067"), YakuDefinitionScript.LOCAL_SETTLEMENT, YakuDefinitionScript.ROGUELIKE_STRUCTURAL, YakuDefinitionScript.GROUP_SHAPE, {"required_patterns": ["Sequence", "Triplet", "Pair"], "local_pattern_types": ["Sequence", "Triplet", "Pair"]}, 12, 0))
	result.append(_yaku(YAKU_IDS[18], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0068"), YakuDefinitionScript.COMPLETE_HAND, YakuDefinitionScript.SUIT_HONOR, YakuDefinitionScript.TILE_CONDITION, {"suit": "honors", "target": 3, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0069")}, 0, 16))
	result.append(_yaku(YAKU_IDS[19], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0070"), YakuDefinitionScript.COMPLETE_HAND, YakuDefinitionScript.SUIT_HONOR, YakuDefinitionScript.TILE_CONDITION, {"suit": "honors", "target": 7, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0071")}, 0, 24))
	result.append(_yaku(YAKU_IDS[20], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0072"), YakuDefinitionScript.COMPLETE_HAND, YakuDefinitionScript.SUIT_HONOR, YakuDefinitionScript.SUIT_CONCENTRATION, {"suit": "characters", "target": 12, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0073")}, 0, 22))
	result.append(_yaku(YAKU_IDS[21], ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0074"), YakuDefinitionScript.COMPLETE_HAND, YakuDefinitionScript.SUIT_HONOR, YakuDefinitionScript.SUIT_CONCENTRATION, {"suit": "dots", "target": 12, "label": ContentTextCatalogScript.canonical_text("CONTENT_SCALE_0075")}, 0, 22))
	return result

static func _yaku(identifier: String, label: String, scope: String, family: String, model: String, config: Dictionary, local_amount: int, complete_amount: int):
	var local_score: Dictionary = {"source_id": identifier, "amount": local_amount, "tags": ["LOCAL_YAKU", "ALPHA_SCALE"]} if scope in [YakuDefinitionScript.LOCAL_SETTLEMENT, YakuDefinitionScript.BOTH] else {}
	var complete_score: Dictionary = {"source_id": "%s.complete" % identifier, "amount": complete_amount, "tags": ["HAND_YAKU", "ALPHA_SCALE"]} if scope in [YakuDefinitionScript.COMPLETE_HAND, YakuDefinitionScript.BOTH] else {}
	return YakuDefinitionScript.new(identifier, label, scope, family, model, config, local_score, complete_score)

static func _relic_definitions() -> Array:
	var act_one_configurations := [
		["DrawTile", 1],
		["GainTP", 1],
		["ModifyReserveCapacity", 1],
		["ModifySettlementCapacity", 1],
		["GainStability", 2],
		["PurgeContamination", 1],
		["ModifyRunCurrency", 1],
	]
	var configurations := [
		["DrawTile", 1], ["GainTP", 1], ["ModifyReserveCapacity", 1], ["GainStability", 2],
		["DrawTile", 1], ["GainTP", 1], ["ModifySettlementCapacity", 1], ["GainStability", 1],
		["PurgeContamination", 1], ["GainTP", 2], ["DrawTile", 1], ["GainStability", 2],
		["GainTP", 1], ["ModifyReserveCapacity", 1], ["GainStability", 3], ["DrawTile", 1],
		["GainStability", 2], ["GainTP", 2],
		["GainTP", 2],
		["DrawTile", 1],
		["ModifyReserveCapacity", 2],
		["ModifySettlementCapacity", 1],
		["GainStability", 3],
		["PurgeContamination", 2],
		["ModifyRunCurrency", 2],
	]
	var result: Array = []
	for index in ACT_ONE_RELIC_IDS.size():
		result.append(RelicDefinitionScript.new(
			ACT_ONE_RELIC_IDS[index],
			[Phase2CatalogScript.typed_effect("content.%s" % ACT_ONE_RELIC_IDS[index], str(act_one_configurations[index][0]), int(act_one_configurations[index][1]))],
			false,
			[],
			1,
		))
	for index in RELIC_IDS.size():
		var configuration: Array = configurations[index]
		result.append(RelicDefinitionScript.new(
			RELIC_IDS[index],
			[Phase2CatalogScript.typed_effect("content.%s" % RELIC_IDS[index], str(configuration[0]), int(configuration[1]))],
			false,
			[],
			2,
		))
	return result

static func _run_technique_definitions() -> Array:
	return [
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[0], TechniqueDefinitionScript.ACTIVE, 1, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[0], "GainStability", 1)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[1], TechniqueDefinitionScript.ACTIVE, 2, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[1], "GainTP", 1)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[2], TechniqueDefinitionScript.PASSIVE, 0, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[2], "ModifyReserveCapacity", 1)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[3], TechniqueDefinitionScript.REACTION, 2, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[3], "PurgeContamination", 1)], [], TechniqueDefinitionScript.REACTION_ENEMY_CONTAMINATION_ADDED),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[4], TechniqueDefinitionScript.SETTLEMENT, 2, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[4], "ModifySettlementCapacity", 1)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[5], TechniqueDefinitionScript.ACTIVE, 3, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[5], "DealDamage", 2)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[6], TechniqueDefinitionScript.ACTIVE, 1, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[6], "ModifyDrawCapacity", 1)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[7], TechniqueDefinitionScript.ACTIVE, 2, [
			Phase2CatalogScript.typed_effect("content.%s.tp" % RUN_TECHNIQUE_IDS[7], "GainTP", 3),
			Phase2CatalogScript.typed_effect("content.%s.pressure" % RUN_TECHNIQUE_IDS[7], "GainPressure", 1),
		]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[8], TechniqueDefinitionScript.ACTIVE, 2, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[8], "DealDamage", 4)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[9], TechniqueDefinitionScript.ACTIVE, 2, [
			Phase2CatalogScript.typed_effect("content.%s.draw" % RUN_TECHNIQUE_IDS[9], "DrawTile", 1),
			Phase2CatalogScript.typed_effect("content.%s.stability" % RUN_TECHNIQUE_IDS[9], "GainStability", 1),
		]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[10], TechniqueDefinitionScript.PASSIVE, 0, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[10], "ModifyRunCurrency", 1)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[11], TechniqueDefinitionScript.PASSIVE, 0, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[11], "ModifyRefinementTokens", 1)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[12], TechniqueDefinitionScript.PASSIVE, 0, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[12], "GainTP", 1)]),
	]

static func _modifier_definitions() -> Array:
	return [
		TileModifierDefinitionScript.new(MODIFIER_IDS[0], "HONOR_MARK", 1, [Phase2CatalogScript.typed_effect("content.%s" % MODIFIER_IDS[0], "GainTP", 1)]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[1], "DOUBLE_EDGE", 1, [Phase2CatalogScript.typed_effect("content.%s" % MODIFIER_IDS[1], "GainStability", 1)]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[2], "QUIET_SURFACE", 1, [Phase2CatalogScript.typed_effect("content.%s" % MODIFIER_IDS[2], "PurgeContamination", 1)]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[3], "WIDE_CHANNEL", 1, [Phase2CatalogScript.typed_effect("content.%s" % MODIFIER_IDS[3], "ModifyDrawCapacity", 1)]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[4], "SHARP_CURRENT", 1, [Phase2CatalogScript.typed_effect("content.%s" % MODIFIER_IDS[4], "DealDamage", 1)]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[5], "TRADE_MARK", 1, [
			Phase2CatalogScript.typed_effect("content.%s.gold" % MODIFIER_IDS[5], "ModifyRunCurrency", 1),
			Phase2CatalogScript.typed_effect("content.%s.stability" % MODIFIER_IDS[5], "GainStability", 1),
		]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[6], "REFINEMENT_TRACE", 1, [
			Phase2CatalogScript.typed_effect("content.%s.tokens" % MODIFIER_IDS[6], "ModifyRefinementTokens", 1),
			Phase2CatalogScript.typed_effect("content.%s.tp" % MODIFIER_IDS[6], "GainTP", 1),
		]),
	]

static func _rule_breaker_definitions() -> Array:
	return [
		RuleBreakerDefinitionScript.new(
			ACT_ONE_BOSS_RULE_BREAKER_IDS[3],
			"STABILITY_SURGE",
			1,
			[Phase2CatalogScript.typed_effect("content.%s" % ACT_ONE_BOSS_RULE_BREAKER_IDS[3], "GainStability", 1)],
		),
		RuleBreakerDefinitionScript.new(
			ACT_ONE_BOSS_RULE_BREAKER_IDS[4],
			"TACTICAL_RESERVE",
			1,
			[Phase2CatalogScript.typed_effect("content.%s" % ACT_ONE_BOSS_RULE_BREAKER_IDS[4], "GainTP", 1)],
		),
		RuleBreakerDefinitionScript.new(
			ACT_TWO_BOSS_RULE_BREAKER_IDS[3],
			"LEDGER_DIVIDEND",
			1,
			[Phase2CatalogScript.typed_effect("content.%s" % ACT_TWO_BOSS_RULE_BREAKER_IDS[3], "ModifyRunCurrency", 1)],
		),
		RuleBreakerDefinitionScript.new(
			ACT_TWO_BOSS_RULE_BREAKER_IDS[4],
			"EARLY_TILE",
			1,
			[Phase2CatalogScript.typed_effect("content.%s" % ACT_TWO_BOSS_RULE_BREAKER_IDS[4], "DrawTile", 1)],
		),
	]

static func _pool_definitions() -> Array:
	var membership := pool_membership()
	return [
		RewardPoolDefinitionScript.new(ACT_ONE_BUILD_POOL_ID, _pool_entries(membership[ACT_ONE_BUILD_POOL_ID]), [], RewardPoolDefinitionScript.REWARD),
		RewardPoolDefinitionScript.new(ACT_TWO_BUILD_POOL_ID, _pool_entries(membership[ACT_TWO_BUILD_POOL_ID]), [], RewardPoolDefinitionScript.REWARD),
		RewardPoolDefinitionScript.new(ACT_TWO_SHOP_POOL_ID, _pool_entries(membership[ACT_TWO_SHOP_POOL_ID]), [], RewardPoolDefinitionScript.SHOP),
		RewardPoolDefinitionScript.new(WORKSHOP_POOL_ID, _pool_entries(membership[WORKSHOP_POOL_ID]), [], RewardPoolDefinitionScript.WORKSHOP),
	]

static func _boss_rule_breaker_pool_definitions() -> Array:
	var membership := pool_membership()
	return [
		RewardPoolDefinitionScript.new(ACT_ONE_BOSS_RULE_BREAKER_POOL_ID, _pool_entries(membership[ACT_ONE_BOSS_RULE_BREAKER_POOL_ID]), [], RewardPoolDefinitionScript.REWARD),
		RewardPoolDefinitionScript.new(ACT_TWO_BOSS_RULE_BREAKER_POOL_ID, _pool_entries(membership[ACT_TWO_BOSS_RULE_BREAKER_POOL_ID]), [], RewardPoolDefinitionScript.REWARD),
	]

static func _pool_entries(content_ids: Array) -> Array:
	var entries: Array = []
	for content_id in content_ids:
		entries.append({"content_id": content_id, "weight": 1})
	return entries

static func _honor_tile_bias() -> Array[String]:
	var result: Array[String] = []
	for honor in ["east", "south", "west", "north", "red", "green", "white"]:
		result.append("base.tile.honors.%s" % honor)
	return result

static func _sorted_ids(content_ids: Array) -> Array:
	var result: Array = content_ids.duplicate()
	result.sort()
	return result

static func _string_ids(content_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for content_id in content_ids:
		result.append(str(content_id))
	return result
