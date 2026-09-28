class_name AlphaActTwoCatalog
extends RefCounted

const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const MiniActMapCatalogScript = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const EnemyDefinitionScript = preload("res://src/content/definitions/enemy_definition.gd")
const EventDefinitionScript = preload("res://src/content/definitions/event_definition.gd")
const MapDefinitionScript = preload("res://src/content/definitions/map_definition.gd")
const MapNodeDefinitionScript = preload("res://src/content/definitions/map_node_definition.gd")
const RewardPoolDefinitionScript = preload("res://src/content/definitions/reward_pool_definition.gd")
const RuleBreakerDefinitionScript = preload("res://src/content/definitions/rule_breaker_definition.gd")
const EnemyIntentScript = preload("res://src/domain/combat/enemy_intent.gd")
const IntentGraphScript = preload("res://src/domain/combat/intent_graph.gd")
const IntentTransitionScript = preload("res://src/domain/combat/intent_transition.gd")

const ACT_TWO_BOSS_RULE_BREAKER_IDS := [
	"alpha.rule_breaker.act_two.settlement_capacity",
	"alpha.rule_breaker.act_two.reserve_capacity",
	"alpha.rule_breaker.act_two.draw_actions",
]
const ACT_TWO_BOSS_RULE_BREAKER_POOL_ID := "alpha.act_two.boss_rule_breaker_pool"
const ACT_TWO_NORMAL_ENEMY_IDS := [
	"alpha.enemy.act_two.tollkeeper",
	"alpha.enemy.act_two.afterimage",
	"alpha.enemy.act_two.pressure_warden",
	"alpha.enemy.act_two.wall_eater",
]
const ACT_TWO_ELITE_ENEMY_ID := "alpha.enemy.act_two.elite.ledger_mimic"
const ACT_TWO_BOSS_ENEMY_ID := "alpha.boss.act_two.final_index"
const ACT_TWO_ALTERNATE_BOSS_ENEMY_ID := "alpha.boss.act_two.tidal_archive"
const ACT_TWO_NORMAL_ENCOUNTER_IDS := [
	"alpha.encounter.act_two.normal.intro",
	"alpha.encounter.act_two.normal.left",
	"alpha.encounter.act_two.normal.right",
	"alpha.encounter.act_two.normal.mid",
]
const ACT_TWO_ELITE_ENCOUNTER_ID := "alpha.encounter.act_two.elite"
const ACT_TWO_BOSS_ENCOUNTER_ID := "alpha.encounter.act_two.boss"
const ACT_TWO_ALTERNATE_BOSS_ENCOUNTER_ID := "alpha.encounter.act_two.boss.c"
const ACT_TWO_EVENT_IDS := [
	"alpha.event.act_two.tile_surgery",
	"alpha.event.act_two.risk_bargain",
	"alpha.event.act_two.gold_exchange",
	"alpha.event.act_two.map_reveal",
	"alpha.event.act_two.contract_clause",
	"alpha.event.act_two.rule_memory",
]
const CONTENT_BUNDLE_ID := "alpha.act_two"
const CONTENT_BUNDLE_VERSION := "v4"

static func register_all(registry) -> RefCounted:
	return registry.register_bundle(CONTENT_BUNDLE_ID, CONTENT_BUNDLE_VERSION, definitions())

static func definitions() -> Array:
	var result: Array = []
	result.append_array(_rule_breaker_definitions())
	result.append_array(_enemy_definitions())
	result.append_array(_encounter_definitions())
	result.append_array(_event_definitions())
	result.append_array(_act_two_map_definitions())
	result.append(_boss_reward_pool_definition())
	return result

static func pool_membership() -> Dictionary:
	return {ACT_TWO_BOSS_RULE_BREAKER_POOL_ID: _sorted_ids(ACT_TWO_BOSS_RULE_BREAKER_IDS)}

static func _rule_breaker_definitions() -> Array:
	return [
		RuleBreakerDefinitionScript.new(
			ACT_TWO_BOSS_RULE_BREAKER_IDS[0],
			"SETTLEMENT_CAPACITY",
			1,
			[Phase2CatalogScript.typed_effect("content.%s" % ACT_TWO_BOSS_RULE_BREAKER_IDS[0], "ModifySettlementCapacity")],
		),
		RuleBreakerDefinitionScript.new(
			ACT_TWO_BOSS_RULE_BREAKER_IDS[1],
			"RESERVE_CAPACITY",
			1,
			[Phase2CatalogScript.typed_effect("content.%s" % ACT_TWO_BOSS_RULE_BREAKER_IDS[1], "ModifyReserveCapacity")],
		),
		RuleBreakerDefinitionScript.new(
			ACT_TWO_BOSS_RULE_BREAKER_IDS[2],
			"DRAW_ACTIONS",
			1,
			[Phase2CatalogScript.typed_effect("content.%s" % ACT_TWO_BOSS_RULE_BREAKER_IDS[2], "ModifyDrawCapacity")],
		),
	]

static func _boss_reward_pool_definition():
	return RewardPoolDefinitionScript.new(
		ACT_TWO_BOSS_RULE_BREAKER_POOL_ID,
		_pool_entries(ACT_TWO_BOSS_RULE_BREAKER_IDS),
		[],
		RewardPoolDefinitionScript.REWARD,
	)

static func _enemy_definitions() -> Array:
	return [
		EnemyDefinitionScript.new(
			ACT_TWO_NORMAL_ENEMY_IDS[0],
			_loop_graph("act_two.tollkeeper", [["count", "Count the Table", 2, "PRESSURE"], ["collect", "Collect the Toll", 1, "PRESSURE"]]),
			EnemyDefinitionScript.NORMAL,
			9,
			{"pressure_limit": 11},
		),
		EnemyDefinitionScript.new(
			ACT_TWO_NORMAL_ENEMY_IDS[1],
			_loop_graph("act_two.afterimage", [
				["mirror", "Mirror the Line", 1, EnemyIntentScript.PRESSURE],
				["repeat", "Repeat the Signal", 2, "AUDIT"],
			]),
			EnemyDefinitionScript.NORMAL,
			10,
			{"pressure_limit": 11},
		),
		EnemyDefinitionScript.new(
			ACT_TWO_NORMAL_ENEMY_IDS[2],
			_loop_graph("act_two.pressure_warden", [
				["watch", "Watch the Pressure", 1, EnemyIntentScript.PRESSURE],
				["press", "Raise the Limit", 3, "INTEGRITY"],
			]),
			EnemyDefinitionScript.NORMAL,
			11,
			{"pressure_limit": 12},
		),
		EnemyDefinitionScript.new(
			ACT_TWO_NORMAL_ENEMY_IDS[3],
			_loop_graph("act_two.wall_eater", [
				["thin", "Thin the Wall", 2, EnemyIntentScript.PRESSURE],
				["consume", "Consume the Margin", 2, "WALL_TAX"],
			]),
			EnemyDefinitionScript.NORMAL,
			10,
			{"pressure_limit": 11},
		),
		EnemyDefinitionScript.new(
			ACT_TWO_ELITE_ENEMY_ID,
			_loop_graph("act_two.ledger_mimic", [
				["audit", "Audit the Ledger", 2, EnemyIntentScript.PRESSURE],
				["mirror", "Mirror the Debt", 3, "INTEGRITY"],
				["close", "Close the Account", 1, EnemyIntentScript.PRESSURE],
			]),
			EnemyDefinitionScript.ELITE,
			16,
			{"pressure_limit": 13},
		),
		EnemyDefinitionScript.new(
			ACT_TWO_BOSS_ENEMY_ID,
			_loop_graph("act_two.final_index", [["catalog", "Catalog the Table", 2, "PRESSURE"], ["reindex", "Reindex the Line", 3, "PRESSURE"]]),
			EnemyDefinitionScript.BOSS,
			42,
			{"pressure_limit": 15},
			{},
			_boss_phases(),
		),
		EnemyDefinitionScript.new(
			ACT_TWO_ALTERNATE_BOSS_ENEMY_ID,
			_loop_graph("act_two.tidal_archive", [
				["float", "Float the Index", 2, EnemyIntentScript.PRESSURE],
				["bury", "Bury the Record", 2, EnemyIntentScript.CONTAMINATION],
			]),
			EnemyDefinitionScript.BOSS,
			46,
			{"pressure_limit": 16, "draw_tax": 1},
			{},
			_tidal_archive_boss_phases(),
		),
	]

static func _encounter_definitions() -> Array:
	var result: Array = []
	for index in ACT_TWO_NORMAL_ENCOUNTER_IDS.size():
		result.append_array(_encounter_variants(
			ACT_TWO_NORMAL_ENCOUNTER_IDS[index],
			ACT_TWO_NORMAL_ENEMY_IDS[index],
			EncounterDefinitionScript.NORMAL,
		))
	result.append_array(_encounter_variants(ACT_TWO_ELITE_ENCOUNTER_ID, ACT_TWO_ELITE_ENEMY_ID, EncounterDefinitionScript.ELITE))
	result.append_array(_encounter_variants(ACT_TWO_BOSS_ENCOUNTER_ID, ACT_TWO_BOSS_ENEMY_ID, EncounterDefinitionScript.BOSS))
	result.append(EncounterDefinitionScript.new(
		ACT_TWO_ALTERNATE_BOSS_ENCOUNTER_ID,
		[ACT_TWO_ALTERNATE_BOSS_ENEMY_ID],
		EncounterDefinitionScript.BOSS,
		{"act": 2, "variant": "c"},
	))
	return result

static func _encounter_variants(base_id: String, enemy_id: String, kind: String) -> Array:
	return [
		EncounterDefinitionScript.new(base_id, [enemy_id], kind, {"act": 2, "variant": "base"}),
		EncounterDefinitionScript.new("%s.a" % base_id, [enemy_id], kind, {"act": 2, "variant": "a"}),
		EncounterDefinitionScript.new("%s.b" % base_id, [enemy_id], kind, {"act": 2, "variant": "b"}),
	]

static func _event_definitions() -> Array:
	return [
		EventDefinitionScript.new(ACT_TWO_EVENT_IDS[0], [
			{"choice_id": "repair_with_token", "label": "Refine the damaged entry", "effects": [_currency_effect("REFINEMENT_TOKENS", -1), _currency_effect("GOLD", 2)]},
			{"choice_id": "leave", "label": "Leave the ledger as written", "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(ACT_TWO_EVENT_IDS[1], [
			{"choice_id": "take_wager", "label": "Risk Gold on the hidden account", "effects": [_currency_effect("GOLD", -2)], "alternatives": [
				{"alternative_id": "favorable_entry", "weight": 1, "effects": [_currency_effect("GOLD", 5)]},
				{"alternative_id": "misread_entry", "weight": 1, "effects": [_currency_effect("GOLD", -3)]},
			]},
			{"choice_id": "leave", "label": "Decline the wager", "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(ACT_TWO_EVENT_IDS[2], [
			{"choice_id": "trade_gold", "label": "Exchange 4 Gold for a Refinement Token", "effects": [_currency_effect("GOLD", -4), _currency_effect("REFINEMENT_TOKENS", 1)]},
			{"choice_id": "leave", "label": "Keep the current funds", "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(ACT_TWO_EVENT_IDS[3], [
			{"choice_id": "reveal_route", "label": "Read the final route", "effects": [{"kind": "MAP_REVEAL", "node_ids": ["base.map_node.act_two.elite", "base.map_node.act_two.boss"]}]},
			{"choice_id": "leave", "label": "Keep the route obscured", "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(ACT_TWO_EVENT_IDS[4], [
			{"choice_id": "carry_clause", "label": "Carry a one-Act clause: +1 Reserve Capacity in later battles this Act", "effects": [_modifier_effect("event.act_two.contract_clause", "ACT", 1, "REPLACE", {})]},
			{"choice_id": "leave", "label": "Decline the clause", "is_skip": true, "effects": []},
		]),
		EventDefinitionScript.new(ACT_TWO_EVENT_IDS[5], [
			{"choice_id": "study_yaku", "label": "Record: +1 TP in later battles this Run and +1 Refinement Token", "effects": [_modifier_effect("event.act_two.rule_memory", "RUN", 1, "UNIQUE", {}), _currency_effect("REFINEMENT_TOKENS", 1)]},
			{"choice_id": "leave", "label": "Leave the old rule undisturbed", "is_skip": true, "effects": []},
		]),
	]

static func _act_two_map_definitions() -> Array:
	var map_definition: MapDefinitionScript = MiniActMapCatalogScript.act_two_definition()
	var result: Array = []
	for node_id in map_definition.node_ids:
		result.append(map_definition.node_definition(node_id))
	result.append(map_definition)
	return result

static func _currency_effect(currency: String, amount: int) -> Dictionary:
	return {"kind": currency, "amount": amount}

static func _modifier_effect(modifier_id: String, scope: String, duration_amount: int, stack_policy: String, parameters: Dictionary) -> Dictionary:
	return {
		"kind": "RUN_MODIFIER",
		"modifier_id": modifier_id,
		"value": 1,
		"scope": scope,
		"duration_amount": duration_amount,
		"stack_policy": stack_policy,
		"source_id": modifier_id,
		"parameters": parameters.duplicate(true),
	}

static func _loop_graph(prefix: String, definitions: Array) -> IntentGraphScript:
	var intents: Array = []
	for index in definitions.size():
		var definition: Array = definitions[index]
		var current_id := "%s.%s" % [prefix, definition[0]]
		var next_id := "%s.%s" % [prefix, definitions[(index + 1) % definitions.size()][0]]
		var action_type := str(definition[3]) if definition.size() > 3 else EnemyIntentScript.PRESSURE
		intents.append(EnemyIntentScript.new(
			current_id,
			str(definition[1]),
			int(definition[2]),
			action_type,
			[IntentTransitionScript.fixed("%s.next" % current_id, next_id)],
		))
	return IntentGraphScript.new("%s.%s" % [prefix, definitions[0][0]], intents)

static func _boss_phases() -> Array:
	return [
		{
			"phase_id": "catalogue",
			"phase_role": "catalogue",
			"max_hp": 18,
			"pressure_limit": 15,
			"pressure_relief": 1,
			"intent_graph": _loop_graph("act_two.final_index.catalogue", [
				["enter", "Open the Index", 2, EnemyIntentScript.PRESSURE],
				["mark", "Mark the Page", 2, "TABLE_INTERFERENCE"],
			]),
		},
		{
			"phase_id": "cross_reference",
			"phase_role": "cross_reference",
			"max_hp": 14,
			"pressure_limit": 13,
			"pressure_relief": 2,
			"intent_graph": _loop_graph("act_two.final_index.cross_reference", [
				["compare", "Cross-reference the Table", 3, EnemyIntentScript.PRESSURE],
				["annotate", "Annotate the Line", 1, "REWARD_TAX"],
			]),
		},
		{
			"phase_id": "final_entry",
			"phase_role": "final_entry",
			"max_hp": 10,
			"pressure_limit": 11,
			"pressure_relief": 3,
			"intent_graph": _loop_graph("act_two.final_index.final_entry", [
				["rewrite", "Write the Final Entry", 3, EnemyIntentScript.PRESSURE],
				["seal", "Seal the Index", 2, "RULE_BREAKER"],
			]),
		},
	]

static func _tidal_archive_boss_phases() -> Array:
	return [
		{
			"phase_id": "high_water",
			"phase_role": "high_water",
			"max_hp": 20,
			"pressure_limit": 16,
			"pressure_relief": 1,
			"intent_graph": _loop_graph("act_two.tidal_archive.high_water", [
				["log", "Log the Current", 2, EnemyIntentScript.AUDIT],
				["rise", "Raise the Waterline", 3, EnemyIntentScript.PRESSURE],
			]),
		},
		{
			"phase_id": "undertow",
			"phase_role": "undertow",
			"max_hp": 15,
			"pressure_limit": 14,
			"pressure_relief": 2,
			"intent_graph": _loop_graph("act_two.tidal_archive.undertow", [
				["pull", "Pull at the Reserve", 2, EnemyIntentScript.WALL_TAX],
				["crack", "Crack the Keel", 2, EnemyIntentScript.INTEGRITY],
			]),
		},
		{
			"phase_id": "ebb",
			"phase_role": "ebb",
			"max_hp": 11,
			"pressure_limit": 12,
			"pressure_relief": 3,
			"intent_graph": _loop_graph("act_two.tidal_archive.ebb", [
				["rewrite", "Rewrite the Ledger", 3, EnemyIntentScript.RULE_BREAKER],
				["close", "Close the Archive", 2, EnemyIntentScript.REWARD_TAX],
			]),
		},
	]

static func _pool_entries(content_ids: Array) -> Array:
	var result: Array = []
	for content_id in _sorted_ids(content_ids):
		result.append({"content_id": content_id, "weight": 1})
	return result

static func _sorted_ids(content_ids: Array) -> Array:
	var result: Array = content_ids.duplicate()
	result.sort()
	return result
