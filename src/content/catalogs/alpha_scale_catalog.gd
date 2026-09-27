class_name AlphaScaleCatalog
extends RefCounted

const ContentDefinitionScript = preload("res://src/content/definitions/content_definition.gd")
const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const CharacterPassiveDefinitionScript = preload("res://src/content/definitions/character_passive_definition.gd")
const ContractDefinitionScript = preload("res://src/content/definitions/contract_definition.gd")
const EventDefinitionScript = preload("res://src/content/definitions/event_definition.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const RewardPoolDefinitionScript = preload("res://src/content/definitions/reward_pool_definition.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")
const YakuDefinitionScript = preload("res://src/content/definitions/yaku_definition.gd")

const CHARACTER_ID := "alpha.character.harbor_reader"
const CORE_TECHNIQUE_ID := "alpha.technique.core.harbor_read"
const PASSIVE_ID := "alpha.passive.harbor_read"
const CONTRACT_IDS := [
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
]
const RUN_TECHNIQUE_IDS := [
	"alpha.technique.river_step",
	"alpha.technique.pressure_turn",
	"alpha.technique.reserve_survey",
	"alpha.technique.cleansing_call",
	"alpha.technique.settlement_mirror",
	"alpha.technique.last_measure",
]
const MODIFIER_IDS := [
	"alpha.modifier.harbor_mark",
	"alpha.modifier.double_edge",
	"alpha.modifier.quiet_surface",
]

const ACT_ONE_BUILD_POOL_ID := "alpha.reward_pool.act_one_build"
const ACT_TWO_BUILD_POOL_ID := "alpha.reward_pool.act_two_build"
const ACT_TWO_SHOP_POOL_ID := "alpha.shop_pool.act_two_build"
const WORKSHOP_POOL_ID := "alpha.workshop_pool.scale"
const CONTENT_BUNDLE_ID := "alpha.scale"
const CONTENT_BUNDLE_VERSION := "v1"

static func register_all(registry) -> RefCounted:
	return registry.register_bundle(CONTENT_BUNDLE_ID, CONTENT_BUNDLE_VERSION, definitions())

static func definitions() -> Array:
	var result: Array = [
		CharacterPassiveDefinitionScript.new(
			PASSIVE_ID,
			CharacterPassiveDefinitionScript.AFTER_COMPLETE_HAND,
			"Harbor Read",
			"Once per encounter, your first Complete Hand grants 1 TP.",
			[Phase2CatalogScript.typed_effect("content.%s" % PASSIVE_ID, "GainTP", 1)],
		),
		_character_definition(),
		_core_technique_definition(),	]
	result.append_array(_contract_definitions())
	result.append_array(_yaku_definitions())
	result.append_array(_relic_definitions())
	result.append_array(_run_technique_definitions())
	result.append_array(_modifier_definitions())
	result.append_array(_pool_definitions())
	return result

static func pool_membership() -> Dictionary:
	var baseline_build := _sorted_ids(Phase2CatalogScript.RELIC_IDS + Phase2CatalogScript.RUN_TECHNIQUE_IDS + RUN_TECHNIQUE_IDS)
	var scale_build := _sorted_ids(Phase2CatalogScript.RELIC_IDS + RELIC_IDS + Phase2CatalogScript.RUN_TECHNIQUE_IDS + RUN_TECHNIQUE_IDS)
	return {
		ACT_ONE_BUILD_POOL_ID: baseline_build,
		ACT_TWO_BUILD_POOL_ID: scale_build,
		ACT_TWO_SHOP_POOL_ID: scale_build.duplicate(),
		WORKSHOP_POOL_ID: _sorted_ids(Phase2CatalogScript.MODIFIER_IDS + MODIFIER_IDS),
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
	]

static func _yaku_definitions() -> Array:
	var result: Array = []
	result.append(_yaku(YAKU_IDS[0], "Double Sequence", YakuDefinitionScript.BOTH, YakuDefinitionScript.STRUCTURAL, YakuDefinitionScript.PATTERN_COUNT, {"pattern_type": "Sequence", "target": 2, "label": "sequence", "local_pattern_types": ["Sequence"]}, 8, 14))
	result.append(_yaku(YAKU_IDS[1], "Triplet Row", YakuDefinitionScript.BOTH, YakuDefinitionScript.STRUCTURAL, YakuDefinitionScript.PATTERN_COUNT, {"pattern_type": "Triplet", "target": 3, "label": "triplet", "local_pattern_types": ["Triplet", "Quad"]}, 9, 16))
	result.append(_yaku(YAKU_IDS[2], "Pair Archive", YakuDefinitionScript.BOTH, YakuDefinitionScript.STRUCTURAL, YakuDefinitionScript.PATTERN_COUNT, {"pattern_type": "Pair", "target": 2, "label": "pair", "local_pattern_types": ["Pair"]}, 7, 13))
	result.append(_yaku(YAKU_IDS[3], "Honor Chorus", YakuDefinitionScript.COMPLETE_HAND, YakuDefinitionScript.SUIT_HONOR, YakuDefinitionScript.TILE_CONDITION, {"suit": "honors", "target": 5, "label": "honor tile"}, 0, 15))
	result.append(_yaku(YAKU_IDS[4], "Character Flow", YakuDefinitionScript.BOTH, YakuDefinitionScript.SUIT_HONOR, YakuDefinitionScript.SUIT_CONCENTRATION, {"suit": "characters", "target": 9, "label": "character tile"}, 9, 17))
	result.append(_yaku(YAKU_IDS[5], "Dotted River", YakuDefinitionScript.BOTH, YakuDefinitionScript.SUIT_HONOR, YakuDefinitionScript.SUIT_CONCENTRATION, {"suit": "dots", "target": 9, "label": "dot tile"}, 9, 17))
	result.append(_yaku(YAKU_IDS[6], "Sequence Pair", YakuDefinitionScript.BOTH, YakuDefinitionScript.ROGUELIKE_STRUCTURAL, YakuDefinitionScript.GROUP_SHAPE, {"required_patterns": ["Sequence", "Pair"], "local_pattern_types": ["Sequence", "Pair"]}, 10, 18))
	result.append(_yaku(YAKU_IDS[7], "Mixed Quartet", YakuDefinitionScript.BOTH, YakuDefinitionScript.ROGUELIKE_STRUCTURAL, YakuDefinitionScript.GROUP_SHAPE, {"required_patterns": ["Sequence", "Triplet", "Quad", "Pair"], "local_pattern_types": ["Sequence", "Triplet", "Quad", "Pair"]}, 13, 22))
	return result

static func _yaku(identifier: String, label: String, scope: String, family: String, model: String, config: Dictionary, local_amount: int, complete_amount: int):
	var local_score: Dictionary = {"source_id": identifier, "amount": local_amount, "tags": ["LOCAL_YAKU", "ALPHA_SCALE"]} if scope in [YakuDefinitionScript.LOCAL_SETTLEMENT, YakuDefinitionScript.BOTH] else {}
	var complete_score: Dictionary = {"source_id": "%s.complete" % identifier, "amount": complete_amount, "tags": ["HAND_YAKU", "ALPHA_SCALE"]} if scope in [YakuDefinitionScript.COMPLETE_HAND, YakuDefinitionScript.BOTH] else {}
	return YakuDefinitionScript.new(identifier, label, scope, family, model, config, local_score, complete_score)

static func _relic_definitions() -> Array:
	var configurations := [
		["DrawTile", 1], ["GainTP", 1], ["ModifyReserveCapacity", 1], ["GainStability", 2],		["DrawTile", 1], ["GainTP", 1], ["ModifySettlementCapacity", 1], ["GainStability", 1],
		["PurgeContamination", 1], ["GainTP", 2], ["DrawTile", 1], ["GainStability", 2],
		["GainTP", 1], ["ModifyReserveCapacity", 1], ["GainStability", 3], ["DrawTile", 1],
		["GainStability", 2], ["GainTP", 2],
	]
	var result: Array = []
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
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[3], TechniqueDefinitionScript.REACTION, 2, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[3], "PurgeContamination", 1)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[4], TechniqueDefinitionScript.SETTLEMENT, 2, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[4], "ModifySettlementCapacity", 1)]),
		TechniqueDefinitionScript.new(RUN_TECHNIQUE_IDS[5], TechniqueDefinitionScript.ACTIVE, 3, [Phase2CatalogScript.typed_effect("content.%s" % RUN_TECHNIQUE_IDS[5], "DealDamage", 2)]),
	]

static func _modifier_definitions() -> Array:
	return [
		TileModifierDefinitionScript.new(MODIFIER_IDS[0], "HONOR_MARK", 1, [Phase2CatalogScript.typed_effect("content.%s" % MODIFIER_IDS[0], "GainTP", 1)]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[1], "DOUBLE_EDGE", 1, [Phase2CatalogScript.typed_effect("content.%s" % MODIFIER_IDS[1], "GainStability", 1)]),
		TileModifierDefinitionScript.new(MODIFIER_IDS[2], "QUIET_SURFACE", 1, [Phase2CatalogScript.typed_effect("content.%s" % MODIFIER_IDS[2], "PurgeContamination", 1)]),
	]

static func _pool_definitions() -> Array:
	var membership := pool_membership()
	return [
		RewardPoolDefinitionScript.new(ACT_ONE_BUILD_POOL_ID, _pool_entries(membership[ACT_ONE_BUILD_POOL_ID]), [], RewardPoolDefinitionScript.REWARD),
		RewardPoolDefinitionScript.new(ACT_TWO_BUILD_POOL_ID, _pool_entries(membership[ACT_TWO_BUILD_POOL_ID]), [], RewardPoolDefinitionScript.REWARD),
		RewardPoolDefinitionScript.new(ACT_TWO_SHOP_POOL_ID, _pool_entries(membership[ACT_TWO_SHOP_POOL_ID]), [], RewardPoolDefinitionScript.SHOP),
		RewardPoolDefinitionScript.new(WORKSHOP_POOL_ID, _pool_entries(membership[WORKSHOP_POOL_ID]), [], RewardPoolDefinitionScript.WORKSHOP),
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
