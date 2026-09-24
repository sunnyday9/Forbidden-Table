class_name ContentCatalogTest
extends RefCounted

const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const Effect = preload("res://src/domain/effects/effect.gd")
const EnemyDefinition = preload("res://src/content/definitions/enemy_definition.gd")
const EncounterDefinition = preload("res://src/content/definitions/encounter_definition.gd")
const EventDefinition = preload("res://src/content/definitions/event_definition.gd")
const IntentGraph = preload("res://src/domain/combat/intent_graph.gd")
const EnemyIntent = preload("res://src/domain/combat/enemy_intent.gd")
const IntentTransition = preload("res://src/domain/combat/intent_transition.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const RelicDefinition = preload("res://src/content/definitions/relic_definition.gd")
const RuleBreakerDefinition = preload("res://src/content/definitions/rule_breaker_definition.gd")
const RewardPoolDefinition = preload("res://src/content/definitions/reward_pool_definition.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const TileModifierDefinition = preload("res://src/content/definitions/tile_modifier_definition.gd")
const YakuCatalog = preload("res://src/content/catalogs/yaku_catalog.gd")
const YakuDefinition = preload("res://src/content/definitions/yaku_definition.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_lower_bound_catalog_registers_and_validates(failures)
	test_catalog_ids_and_roles_match_phase_2(failures)
	test_characters_and_contracts_expose_distinct_planning_paths(failures)
	test_typed_content_and_data_driven_encounters_are_registered(failures)
	test_boss_exposes_the_three_public_phases(failures)
	test_boss_reward_rule_breakers_are_registered_and_typed(failures)
	test_act_two_boss_rule_breakers_are_separate_stable_typed_content(failures)
	test_yaku_compatibility_and_new_typed_hooks(failures)
	test_pools_have_stable_deterministic_membership(failures)
	test_no_core_code_content_can_be_added_and_validated(failures)
	return failures

func test_lower_bound_catalog_registers_and_validates(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	var registration = Phase2Catalog.register_all(registry)
	assert_true(registration.is_valid(), "the lower-bound catalog registers every definition", failures)
	var validation = registry.validate()
	assert_true(validation.is_valid(), "the lower-bound catalog passes ContentRegistry validation", failures)
	assert_true(registry.content_version() == "content.slice.v2", "the catalog versions the Phase 2 Boss reward content", failures)

func test_catalog_ids_and_roles_match_phase_2(failures: Array[String]) -> void:
	assert_true(Phase2Catalog.CHARACTER_IDS == [
		"base.character.sequence",
		"base.character.reserve",
	], "the catalog exposes the two exact Character IDs", failures)
	assert_true(Phase2Catalog.CONTRACT_IDS == [
		"base.contract.pressure",
		"base.contract.pool_bias",
		"base.contract.refinement_debt",
	], "the catalog exposes the three exact Contract IDs", failures)
	assert_true(Phase2Catalog.RUN_TECHNIQUE_IDS.size() == 8, "the catalog exposes eight obtainable Run Techniques", failures)
	assert_true(Phase2Catalog.CORE_TECHNIQUE_IDS == [
		"base.technique.core.sequence_line",
		"base.technique.core.reserve_ledger",
	], "the catalog exposes the two exact Core Technique IDs", failures)
	assert_true(Phase2Catalog.RELIC_IDS.size() == 18, "the catalog exposes eighteen Relic IDs", failures)
	assert_true(Phase2Catalog.MODIFIER_IDS.size() == 5, "the catalog exposes five Tile Modifier IDs", failures)
	assert_true(Phase2Catalog.NORMAL_ENEMY_IDS == [
		"base.enemy.pressure_sentinel",
		"base.enemy.wall_taxer",
		"base.enemy.integrity_collector",
		"base.enemy.contaminator",
	], "the catalog exposes the four exact Normal enemy IDs", failures)
	assert_true(Phase2Catalog.ELITE_ENEMY_ID == "base.enemy.ledger_hunter", "the catalog exposes the exact Elite ID", failures)
	assert_true(Phase2Catalog.BOSS_ID == "base.boss.table_breaker", "the catalog exposes the exact Boss ID", failures)
	assert_true(Phase2Catalog.EVENT_IDS == [
		"base.event.tile_surgery",
		"base.event.risk_bargain",
		"base.event.gold_exchange",
		"base.event.map_reveal",
		"base.event.contract_clause",
		"base.event.rule_memory",
	], "the catalog exposes the six exact Event IDs", failures)
	assert_true(Phase2Catalog.PROTOTYPE_YAKU_IDS == [
		"prototype.yaku.sequence_path",
		"prototype.yaku.triplet_foundation",
		"prototype.yaku.honor_signal",
		"prototype.yaku.unified_suit",
		"prototype.yaku.standard_complete_hand",
		"prototype.yaku.seven_pairs",
		"prototype.yaku.quad_foundry",
		"prototype.yaku.mixed_table",
	], "the catalog preserves all eight prototype Yaku IDs", failures)
	assert_true(Phase2Catalog.PRODUCTION_YAKU_IDS == [
		"base.yaku.pair_foundation",
		"base.yaku.bamboo_concentration",
	], "the catalog exposes the two exact production Yaku IDs", failures)

func test_characters_and_contracts_expose_distinct_planning_paths(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var sequence = registry.resolve("base.character.sequence")
	var reserve = registry.resolve("base.character.reserve")
	assert_true(sequence.starting_tile_pool_bias != reserve.starting_tile_pool_bias, "Characters declare different starting Tile Pool biases", failures)
	assert_true(sequence.starting_relic_id != reserve.starting_relic_id, "Characters start with different Relics", failures)
	assert_true(sequence.core_technique_id != reserve.core_technique_id, "Characters expose different Core Techniques", failures)
	assert_true(sequence.signature_passive_id != reserve.signature_passive_id, "Characters expose different signature passives", failures)

	var pressure = registry.resolve("base.contract.pressure")
	var pool_bias = registry.resolve("base.contract.pool_bias")
	var refinement_debt = registry.resolve("base.contract.refinement_debt")
	assert_true(pressure.tradeoff_family != pool_bias.tradeoff_family and pool_bias.tradeoff_family != refinement_debt.tradeoff_family, "Contracts use distinct tradeoff families", failures)
	assert_true(pressure.risk != pool_bias.risk and pool_bias.risk != refinement_debt.risk, "Contracts expose distinct risks", failures)
	assert_true(pressure.reward != pool_bias.reward and pool_bias.reward != refinement_debt.reward, "Contracts expose distinct rewards", failures)
	assert_true(pressure.build_bias != pool_bias.build_bias and pool_bias.build_bias != refinement_debt.build_bias, "Contracts expose distinct build biases", failures)
	assert_true(pressure.build_bias.get("preferred_tile_ids", []) != pool_bias.build_bias.get("preferred_tile_ids", []), "Contract selection exposes distinct preferred Tile Pool paths", failures)

func test_typed_content_and_data_driven_encounters_are_registered(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	for relic_id in Phase2Catalog.RELIC_IDS:
		var relic = registry.resolve(relic_id)
		assert_true(relic is RelicDefinition and not relic.effects.is_empty(), "%s has configured Relic Effects" % relic_id, failures)
		_assert_all_typed_effects(relic.effects, relic_id, failures)
	for technique_id in Phase2Catalog.RUN_TECHNIQUE_IDS + Phase2Catalog.CORE_TECHNIQUE_IDS:
		var technique = registry.resolve(technique_id)
		assert_true(technique is TechniqueDefinition and not technique.effects.is_empty(), "%s has configured Technique Effects" % technique_id, failures)
		_assert_all_typed_effects(technique.effects, technique_id, failures)
	for modifier_id in Phase2Catalog.MODIFIER_IDS:
		var modifier = registry.resolve(modifier_id)
		assert_true(modifier is TileModifierDefinition and not modifier.effects.is_empty(), "%s has configured Modifier Effects" % modifier_id, failures)
		_assert_all_typed_effects(modifier.effects, modifier_id, failures)
	for event_id in Phase2Catalog.EVENT_IDS:
		var event = registry.resolve(event_id)
		assert_true(event is EventDefinition and event.choices.size() >= 2, "%s exposes systemic Event choices" % event_id, failures)
		var has_typed_configuration := false
		for choice in event.choices:
			for effect in choice.get("effects", []):
				if effect is Effect:
					has_typed_configuration = true
				elif effect is Dictionary and not str(effect.get("kind", "")).is_empty():
					has_typed_configuration = true
		assert_true(has_typed_configuration, "%s uses typed or explicit declarative Event configuration" % event_id, failures)

	for enemy_id in Phase2Catalog.NORMAL_ENEMY_IDS + [Phase2Catalog.ELITE_ENEMY_ID, Phase2Catalog.BOSS_ID]:
		var enemy = registry.resolve(enemy_id)
		assert_true(enemy is EnemyDefinition, "%s is an EnemyDefinition" % enemy_id, failures)
		assert_true(enemy.intent_graph is IntentGraph and enemy.intent_graph.validation().is_valid(), "%s exposes a valid Intent Graph" % enemy_id, failures)
		assert_true(enemy.intent_graph.intents().size() >= 2, "%s has a learnable multi-step Intent Graph" % enemy_id, failures)

func test_boss_exposes_the_three_public_phases(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var boss = registry.resolve(Phase2Catalog.BOSS_ID)
	assert_true(boss.boss_phases.size() == 3, "the Boss declares exactly three public phases", failures)
	var phase_ids: Array[String] = []
	for phase in boss.boss_phases:
		phase_ids.append(str(phase.get("phase_id", "")))
		assert_true(phase.get("intent_graph") is IntentGraph and phase["intent_graph"].validation().is_valid(), "Boss phase %s has a valid public Intent Graph" % phase.get("phase_id", ""), failures)
	assert_true(phase_ids == ["tempo", "table_interference", "rule_breaker"], "Boss phase IDs expose the required public roles", failures)

func test_boss_reward_rule_breakers_are_registered_and_typed(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	assert_true(Phase2Catalog.BOSS_RULE_BREAKER_IDS.size() == 3, "the Phase 2 Boss pool contains exactly three Rule Breaker choices", failures)
	for identifier in Phase2Catalog.BOSS_RULE_BREAKER_IDS:
		var definition = registry.resolve(identifier)
		assert_true(definition is RuleBreakerDefinition, "%s resolves to a RuleBreakerDefinition" % identifier, failures)
		if definition is RuleBreakerDefinition:
			assert_true(not definition.rule_key.is_empty() and definition.permission_level > 0, "%s declares its table-rule dimension and permission" % identifier, failures)
			assert_true(not definition.effects.is_empty(), "%s carries its configured typed rule effect" % identifier, failures)
			_assert_all_typed_effects(definition.effects, identifier, failures)
	var boss_pool = registry.resolve(Phase2Catalog.BOSS_RULE_BREAKER_POOL_ID)
	assert_true(boss_pool is RewardPoolDefinition, "Boss Rule Breakers use the existing typed reward-pool architecture", failures)
	if boss_pool is RewardPoolDefinition:
		var expected_ids: Array = Phase2Catalog.BOSS_RULE_BREAKER_IDS.duplicate()
		expected_ids.sort()
		assert_true(boss_pool.entry_ids() == expected_ids, "the Boss reward pool exposes the three stable Rule Breaker IDs", failures)

func test_act_two_boss_rule_breakers_are_separate_stable_typed_content(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var act_one_ids: Array = Phase2Catalog.BOSS_RULE_BREAKER_IDS.duplicate()
	var first_act_two_membership: Dictionary = AlphaActTwoCatalog.pool_membership()
	var second_act_two_membership: Dictionary = AlphaActTwoCatalog.pool_membership()
	var registration = AlphaActTwoCatalog.register_all(registry)
	assert_true(registration.is_valid(), "the Act 2 content catalog registers successfully", failures)
	assert_true(registry.validate().is_valid(), "the combined Phase 2 and Act 2 catalogs pass typed content validation", failures)
	assert_true(first_act_two_membership == second_act_two_membership, "Act 2 pool membership is stable across calls", failures)
	assert_true(AlphaActTwoCatalog.ACT_TWO_BOSS_RULE_BREAKER_IDS == [
		"alpha.rule_breaker.act_two.settlement_capacity",
		"alpha.rule_breaker.act_two.reserve_capacity",
		"alpha.rule_breaker.act_two.draw_actions",
	], "the catalog registers exactly the three stable Act 2 Rule Breaker IDs", failures)
	assert_true(AlphaActTwoCatalog.ACT_TWO_BOSS_RULE_BREAKER_IDS.size() == 3, "the Act 2 content budget adds exactly three Rule Breaker definitions", failures)
	assert_true(act_one_ids.size() + AlphaActTwoCatalog.ACT_TWO_BOSS_RULE_BREAKER_IDS.size() == 6, "the two Boss pools define the six unique Alpha Rule Breakers", failures)
	for identifier in AlphaActTwoCatalog.ACT_TWO_BOSS_RULE_BREAKER_IDS:
		var definition = registry.resolve(identifier)
		assert_true(definition is RuleBreakerDefinition, "%s resolves to a typed RuleBreakerDefinition" % identifier, failures)
		if definition is RuleBreakerDefinition:
			assert_true(not definition.effects.is_empty(), "%s has a typed Rule Breaker effect" % identifier, failures)
			_assert_all_typed_effects(definition.effects, identifier, failures)
		assert_true(not act_one_ids.has(identifier), "the Act 2 ID is distinct from the unchanged Phase 2 Act 1 pool", failures)
	var act_two_pool = registry.resolve(AlphaActTwoCatalog.ACT_TWO_BOSS_RULE_BREAKER_POOL_ID)
	assert_true(act_two_pool is RewardPoolDefinition, "the Act 2 eligibility pool uses the existing typed RewardPoolDefinition", failures)
	if act_two_pool is RewardPoolDefinition:
		var expected_ids: Array = AlphaActTwoCatalog.ACT_TWO_BOSS_RULE_BREAKER_IDS.duplicate()
		expected_ids.sort()
		assert_true(act_two_pool.entry_ids() == expected_ids, "the Act 2 pool contains exactly the three Act 2 Rule Breakers", failures)
	var invalid_act_two_pool := RewardPoolDefinition.new(
		"base.act_two.boss_rule_breaker_pool",
		[{"content_id": AlphaActTwoCatalog.ACT_TWO_BOSS_RULE_BREAKER_IDS[0], "weight": 1}],
		[],
		RewardPoolDefinition.REWARD,
	)
	assert_true(invalid_act_two_pool.validate().has_code("invalid_pool_family"), "Act 2 pool IDs use the Alpha-specific typed namespace", failures)
	var act_one_pool = registry.resolve(Phase2Catalog.BOSS_RULE_BREAKER_POOL_ID)
	act_one_ids.sort()
	assert_true(act_one_pool.entry_ids() == act_one_ids, "the Phase 2 Act 1 Boss pool contract remains unchanged", failures)

func test_yaku_compatibility_and_new_typed_hooks(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var fresh_prototypes := YakuCatalog.representative_definitions()
	for expected in fresh_prototypes:
		var actual = registry.resolve(expected.content_id)
		assert_true(actual is YakuDefinition, "%s remains registered as a YakuDefinition" % expected.content_id, failures)
		assert_true(_yaku_signature(actual) == _yaku_signature(expected), "%s retains prototype behavior configuration" % expected.content_id, failures)
	var pair = registry.resolve("base.yaku.pair_foundation")
	var bamboo = registry.resolve("base.yaku.bamboo_concentration")
	assert_true(pair.progress_model == YakuDefinition.PATTERN_COUNT and pair.progress_config.get("pattern_type", "") == "Pair", "Pair Foundation uses typed Pair progress", failures)
	assert_true(not pair.complete_score.is_empty() and pair.complete_score.get("source_id", "") == "base.yaku.pair_foundation", "Pair Foundation exposes a typed score hook", failures)
	assert_true(bamboo.progress_model == YakuDefinition.SUIT_CONCENTRATION and bamboo.progress_config.get("suit", "") == "bamboo", "Bamboo Concentration uses typed Bamboo progress", failures)
	assert_true(not bamboo.complete_score.is_empty() and bamboo.complete_score.get("source_id", "") == "base.yaku.bamboo_concentration", "Bamboo Concentration exposes a typed score hook", failures)

func test_pools_have_stable_deterministic_membership(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var first_membership: Dictionary = Phase2Catalog.pool_membership()
	var second_membership: Dictionary = Phase2Catalog.pool_membership()
	assert_true(first_membership == second_membership, "content pool membership is deterministic", failures)
	for pool_id in Phase2Catalog.POOL_IDS:
		var pool = registry.resolve(pool_id)
		assert_true(pool is RewardPoolDefinition, "%s is a typed content pool" % pool_id, failures)
		assert_true(pool.entry_ids() == first_membership[pool_id], "%s has stable ordered membership" % pool_id, failures)
		for content_id in pool.entry_ids():
			assert_true(registry.resolve(content_id) != null, "%s only contains registered content IDs" % pool_id, failures)

func test_no_core_code_content_can_be_added_and_validated(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var effect: Effect = Phase2Catalog.typed_effect("no_core_test.effect", "GainTP", 1)
	var relic := RelicDefinition.new("base.relic.no_core_test", [effect])
	var technique := TechniqueDefinition.new("base.technique.no_core_test", TechniqueDefinition.ACTIVE, 1, [Phase2Catalog.typed_effect("no_core_test.technique", "GainStability", 1)])
	var yaku := YakuDefinition.new(
		"base.yaku.no_core_test",
		"No-Core Yaku",
		YakuDefinition.BOTH,
		YakuDefinition.ROGUELIKE_STRUCTURAL,
		YakuDefinition.PATTERN_COUNT,
		{"pattern_type": "Triplet", "target": 1},
		{"source_id": "base.yaku.no_core_test", "amount": 1, "tags": ["LOCAL_YAKU"]},
		{"source_id": "base.yaku.no_core_test.complete", "amount": 2, "tags": ["HAND_YAKU"]},
	)
	var graph := IntentGraph.new("test", [
		EnemyIntent.new("test", "No-Core", 1, EnemyIntent.PRESSURE, [IntentTransition.fixed("test.loop", "test")]),
	])
	var enemy := EnemyDefinition.new("base.enemy.no_core_test", graph, EnemyDefinition.NORMAL, 3)
	var encounter := EncounterDefinition.new("base.encounter.no_core_test", [enemy.content_id], EncounterDefinition.NORMAL)
	var event := EventDefinition.new("base.event.no_core_test", [
		{"choice_id": "apply", "effects": [Phase2Catalog.typed_effect("no_core_test.event", "ModifyRunCurrency", 1)]},
		{"choice_id": "leave", "is_skip": true, "effects": []},
	])
	var pool := RewardPoolDefinition.new("base.reward_pool.no_core_test", [
		{"content_id": relic.content_id, "weight": 1},
		{"content_id": technique.content_id, "weight": 1},
	])
	for definition in [relic, technique, yaku, enemy, encounter, event, pool]:
		assert_true(registry.register(definition).is_valid(), "No-Core-Code content registers: %s" % definition.content_id, failures)
	assert_true(registry.validate().is_valid(), "No-Core-Code representative content passes registry validation", failures)
	var expected_pool_ids: Array[String] = [relic.content_id, technique.content_id]
	expected_pool_ids.sort()
	assert_true(pool.entry_ids() == expected_pool_ids, "No-Core-Code content can join a stable pool", failures)
	assert_true(relic.effects[0] is Effect and technique.effects[0] is Effect, "No-Core-Code Relic and Technique use typed Effects", failures)
	assert_true(enemy.intent_graph.validation().is_valid(), "No-Core-Code Normal enemy uses a valid Intent Graph", failures)
	assert_true(event.choice_by_id("apply").effects[0] is Effect, "No-Core-Code Event uses a typed Effect", failures)

func _assert_all_typed_effects(effects: Array, content_id: String, failures: Array[String]) -> void:
	for effect in effects:
		assert_true(effect is Effect, "%s contains only typed Effect values" % content_id, failures)

func _yaku_signature(yaku) -> Dictionary:
	return {
		"display_name": yaku.display_name,
		"scope": yaku.scope,
		"family": yaku.family,
		"progress_model": yaku.progress_model,
		"progress_config": yaku.progress_config,
		"local_score": yaku.local_score,
		"complete_score": yaku.complete_score,
	}

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
