class_name AlphaActTwoCatalog
extends RefCounted

const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RewardPoolDefinitionScript = preload("res://src/content/definitions/reward_pool_definition.gd")
const RuleBreakerDefinitionScript = preload("res://src/content/definitions/rule_breaker_definition.gd")

const ACT_TWO_BOSS_RULE_BREAKER_IDS := [
	"alpha.rule_breaker.act_two.settlement_capacity",
	"alpha.rule_breaker.act_two.reserve_capacity",
	"alpha.rule_breaker.act_two.draw_actions",
]
const ACT_TWO_BOSS_RULE_BREAKER_POOL_ID := "alpha.act_two.boss_rule_breaker_pool"
const CONTENT_BUNDLE_ID := "alpha.act_two"
const CONTENT_BUNDLE_VERSION := "v1"

static func register_all(registry) -> RefCounted:
	return registry.register_bundle(CONTENT_BUNDLE_ID, CONTENT_BUNDLE_VERSION, definitions())

static func definitions() -> Array:
	return _rule_breaker_definitions() + [_boss_reward_pool_definition()]

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

static func _pool_entries(content_ids: Array) -> Array:
	var result: Array = []
	for content_id in _sorted_ids(content_ids):
		result.append({"content_id": content_id, "weight": 1})
	return result

static func _sorted_ids(content_ids: Array) -> Array:
	var result: Array = content_ids.duplicate()
	result.sort()
	return result
