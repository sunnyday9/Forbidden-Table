class_name ContentCatalogTest
extends RefCounted

const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const MiniActMapCatalog = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const ContentVersionMigration = preload("res://src/infrastructure/persistence/content_version_migration.gd")
const Phase2V1SuspendSnapshotFixture = preload("res://tests/fixtures/phase2_v1_suspend_snapshot.gd")
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
	test_act_two_encounters_events_and_map_payloads_are_typed(failures)
	test_stage_four_enemy_rosters_use_existing_act_payloads(failures)
	test_content_version_identifies_registered_catalog_bundles(failures)
	test_catalogued_build_techniques_declare_battle_timings(failures)
	test_failed_catalog_registration_does_not_change_bundle_identity(failures)
	test_yaku_compatibility_and_new_typed_hooks(failures)
	test_pools_have_stable_deterministic_membership(failures)
	test_scale_relic_act_groups_and_pool_membership(failures)
	test_stage_four_modifiers_are_typed_shared_workshop_content(failures)
	test_no_core_code_content_can_be_added_and_validated(failures)
	return failures

func test_lower_bound_catalog_registers_and_validates(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	var registration = Phase2Catalog.register_all(registry)
	assert_true(registration.is_valid(), "the lower-bound catalog registers every definition", failures)
	var validation = registry.validate()
	assert_true(validation.is_valid(), "the lower-bound catalog passes ContentRegistry validation", failures)
	assert_true(registry.content_version() == "content.slice.v4", "the catalog versions current deterministic Reaction content", failures)

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

func test_content_version_identifies_registered_catalog_bundles(failures: Array[String]) -> void:
	var phase2_registry := ContentRegistry.new()
	Phase2Catalog.register_all(phase2_registry)
	var phase2_version: String = phase2_registry.content_version()

	var act_two_registry := ContentRegistry.new()
	Phase2Catalog.register_all(act_two_registry)
	AlphaActTwoCatalog.register_all(act_two_registry)
	var act_two_version: String = act_two_registry.content_version()

	var repeated_act_two_registry := ContentRegistry.new()
	Phase2Catalog.register_all(repeated_act_two_registry)
	AlphaActTwoCatalog.register_all(repeated_act_two_registry)
	var repeated_act_two_version: String = repeated_act_two_registry.content_version()

	var scale_registry := ContentRegistry.new()
	Phase2Catalog.register_all(scale_registry)
	AlphaActTwoCatalog.register_all(scale_registry)
	AlphaScaleCatalog.register_all(scale_registry)
	var scale_version: String = scale_registry.content_version()

	var repeated_scale_registry := ContentRegistry.new()
	AlphaScaleCatalog.register_all(repeated_scale_registry)
	AlphaActTwoCatalog.register_all(repeated_scale_registry)
	Phase2Catalog.register_all(repeated_scale_registry)
	var repeated_scale_version: String = repeated_scale_registry.content_version()

	assert_true(phase2_version == "content.slice.v4", "Phase 2 Technique reaction semantics use a new explicit content identity", failures)
	assert_true(phase2_version != "content.slice.v3", "old Phase 2 v3 content cannot share the updated gameplay identity", failures)
	assert_true(act_two_version != phase2_version, "the Act 2 bundle has a distinct content identity", failures)
	assert_true(act_two_version.contains("alpha.act_two@v4") and act_two_version.contains("phase2@v4"), "Act 2 and shared Phase 2 Technique semantics both carry their updated versions", failures)
	assert_true(act_two_version == repeated_act_two_version, "the same Phase 2 and Act 2 bundle combination has a deterministic identity", failures)
	assert_true(scale_version != act_two_version and scale_version != phase2_version, "the Scale bundle has a distinct content identity", failures)
	assert_true(scale_version == repeated_scale_version, "the same Scale bundle combination has a deterministic identity", failures)
	assert_true(scale_version.contains("alpha.scale@v11"), "the Scale bundle identity advances for the Stage 4 Boss roster", failures)
	var alpha_migration_target: Dictionary = ContentVersionMigration.migrate_phase2_v1_suspend_snapshot(Phase2V1SuspendSnapshotFixture.suspend_snapshot(), act_two_registry)
	assert_true(alpha_migration_target.get("accepted", false), "the Phase 2 v1 migration explicitly accepts the current Act Two-only identity", failures)
	if alpha_migration_target.get("accepted", false):
		assert_true(alpha_migration_target.data.content_version == act_two_registry.content_version(), "the Phase 2 v1 migration stamps the exact Act Two-only identity", failures)

func test_catalogued_build_techniques_declare_battle_timings(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	var phase2_registration = Phase2Catalog.register_all(registry)
	var scale_registration = AlphaScaleCatalog.register_all(registry)
	assert_true(phase2_registration.is_valid() and scale_registration.is_valid(), "both Technique bundles register with explicit reaction timings", failures)
	if not phase2_registration.is_valid() or not scale_registration.is_valid():
		return
	var clean_table = registry.resolve("base.technique.clean_table")
	var reaction_guard = registry.resolve("base.technique.reaction_guard")
	var cleansing_call = registry.resolve("alpha.technique.cleansing_call")
	var reserve_survey = registry.resolve("alpha.technique.reserve_survey")
	assert_true(clean_table != null and clean_table.technique_kind == TechniqueDefinition.REACTION and clean_table.reaction_trigger_id == TechniqueDefinition.REACTION_ENEMY_CONTAMINATION_ADDED, "Clean Table is a Contamination-triggered Reaction", failures)
	assert_true(cleansing_call != null and cleansing_call.technique_kind == TechniqueDefinition.REACTION and cleansing_call.reaction_trigger_id == TechniqueDefinition.REACTION_ENEMY_CONTAMINATION_ADDED, "Cleansing Call is a Contamination-triggered Reaction", failures)
	assert_true(reaction_guard != null and reaction_guard.technique_kind == TechniqueDefinition.REACTION and reaction_guard.reaction_trigger_id == TechniqueDefinition.REACTION_ENEMY_STABILITY_LOST, "Reaction Guard responds only after enemy Stability loss", failures)
	assert_true(reserve_survey != null and reserve_survey.technique_kind == TechniqueDefinition.PASSIVE and reserve_survey.reaction_trigger_id.is_empty(), "Reserve Survey remains a Passive without a manual Reaction trigger", failures)
	var unconfigured_reaction := TechniqueDefinition.new("base.technique.unconfigured_reaction", TechniqueDefinition.REACTION, 1, [Phase2Catalog.typed_effect("content.unconfigured_reaction", "PurgeContamination")])
	var unconfigured_report = unconfigured_reaction.validate()
	assert_true(not unconfigured_report.is_valid() and unconfigured_report.has_code("invalid_reaction_trigger"), "catalog validation rejects a Reaction without explicit trigger metadata", failures)

func test_act_two_encounters_events_and_map_payloads_are_typed(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	var registration = AlphaActTwoCatalog.register_all(registry)
	assert_true(registration.is_valid(), "the expanded Act 2 content bundle registers without changing Act 1 IDs", failures)

	var expected_normal_enemy_ids := [
		"alpha.enemy.act_two.tollkeeper",
		"alpha.enemy.act_two.afterimage",
		"alpha.enemy.act_two.pressure_warden",
		"alpha.enemy.act_two.wall_eater",
	]
	for enemy_id in expected_normal_enemy_ids:
		var enemy = registry.resolve(enemy_id)
		assert_true(enemy is EnemyDefinition, "%s resolves to an Act 2 EnemyDefinition" % enemy_id, failures)
		if enemy is EnemyDefinition:
			assert_true(enemy.role == EnemyDefinition.NORMAL, "%s is an Act 2 Normal enemy" % enemy_id, failures)
			assert_true(enemy.intent_graph is IntentGraph and enemy.intent_graph.validation().is_valid(), "%s has a valid Act 2 Intent Graph" % enemy_id, failures)
	for enemy_id in ["alpha.enemy.act_two.elite.ledger_mimic", "alpha.boss.act_two.final_index"]:
		var enemy = registry.resolve(enemy_id)
		assert_true(enemy is EnemyDefinition, "%s resolves to an Act 2 EnemyDefinition" % enemy_id, failures)
	if registry.resolve("alpha.enemy.act_two.elite.ledger_mimic") is EnemyDefinition:
		assert_true(registry.resolve("alpha.enemy.act_two.elite.ledger_mimic").role == EnemyDefinition.ELITE, "the Act 2 Elite has the matching role", failures)
	var afterimage = registry.resolve("alpha.enemy.act_two.afterimage")
	if afterimage is EnemyDefinition:
		var repeat_intent = afterimage.intent_graph.intent("act_two.afterimage.repeat")
		assert_true(
			repeat_intent.action_type == "AUDIT",
			"Afterimage uses an existing typed intent identity",
			failures,
		)
		var copied_graph = IntentGraph.from_intent_loop(afterimage.intent_graph.intents())
		var copied_repeat = copied_graph.intent("act_two.afterimage.repeat")
		assert_true(copied_repeat.action_type == repeat_intent.action_type, "IntentGraph copies retain the authored Act 2 action type", failures)
	var wall_eater = registry.resolve("alpha.enemy.act_two.wall_eater")
	if wall_eater is EnemyDefinition:
		var consume_intent = wall_eater.intent_graph.intent("act_two.wall_eater.consume")
		assert_true(consume_intent.action_type == "WALL_TAX", "Wall Eater uses the existing Wall Tax intent identity", failures)
	var ledger_mimic = registry.resolve("alpha.enemy.act_two.elite.ledger_mimic")
	if ledger_mimic is EnemyDefinition:
		var mirror_intent = ledger_mimic.intent_graph.intent("act_two.ledger_mimic.mirror")
		assert_true(mirror_intent.action_type == "INTEGRITY", "Ledger Mimic uses the existing Integrity intent identity", failures)
	var act_two_boss = registry.resolve("alpha.boss.act_two.final_index")
	assert_true(act_two_boss is EnemyDefinition and act_two_boss.role == EnemyDefinition.BOSS, "the Act 2 Boss has the matching role", failures)
	if act_two_boss is EnemyDefinition:
		assert_true(act_two_boss.boss_phases.size() >= 3, "the Act 2 Boss has multiple public phases", failures)
		var mark_intent = act_two_boss.boss_phases[0].intent_graph.intent("act_two.final_index.catalogue.mark")
		assert_true(mark_intent.action_type == "TABLE_INTERFERENCE", "the Act 2 Boss uses an existing Table Interference intent identity", failures)

	var expected_event_ids := [
		"alpha.event.act_two.tile_surgery",
		"alpha.event.act_two.risk_bargain",
		"alpha.event.act_two.gold_exchange",
		"alpha.event.act_two.map_reveal",
		"alpha.event.act_two.contract_clause",
		"alpha.event.act_two.rule_memory",
	]
	for event_id in expected_event_ids:
		var event = registry.resolve(event_id)
		assert_true(event is EventDefinition and event.choices.size() >= 2, "%s resolves to a typed Act 2 Event" % event_id, failures)
		if event is EventDefinition:
			assert_true(event.validate().is_valid(), "%s declares valid stable choices and effects" % event_id, failures)

	var map_definition = MiniActMapCatalog.act_two_definition()
	var mapped_enemy_ids: Dictionary = {}
	var mapped_event_ids: Dictionary = {}
	for node_id in map_definition.node_ids:
		var node = map_definition.node_definition(node_id)
		if node.node_kind in ["BATTLE", "ELITE", "BOSS"]:
			for encounter_id in node.payload_options:
				var encounter = registry.resolve(encounter_id)
				assert_true(encounter is EncounterDefinition, "%s resolves to an Act 2 EncounterDefinition" % encounter_id, failures)
				if encounter is EncounterDefinition:
					assert_true(encounter_id.begins_with("alpha.encounter.act_two."), "%s is an Act 2 map binding" % encounter_id, failures)
					for enemy_id in encounter.enemy_ids:
						mapped_enemy_ids[enemy_id] = true
		if node.node_kind == "EVENT":
			for event_id in node.payload_options:
				var event = registry.resolve(event_id)
				assert_true(event is EventDefinition, "%s resolves to a typed Act 2 EventDefinition" % event_id, failures)
				assert_true(event_id.begins_with("alpha.event.act_two."), "%s is an Act 2 map binding" % event_id, failures)
				mapped_event_ids[event_id] = true
	var sorted_mapped_enemies: Array = mapped_enemy_ids.keys()
	sorted_mapped_enemies.sort()
	var expected_enemies := expected_normal_enemy_ids + [
		"alpha.enemy.act_two.elite.ledger_mimic",
		"alpha.boss.act_two.final_index",
		AlphaActTwoCatalog.ACT_TWO_ALTERNATE_BOSS_ENEMY_ID,
	]
	expected_enemies.sort()
	assert_true(sorted_mapped_enemies == expected_enemies, "the Act 2 Map reaches exactly its four Normal enemies, Elite, and Boss", failures)
	var sorted_mapped_events: Array = mapped_event_ids.keys()
	sorted_mapped_events.sort()
	expected_event_ids.sort()
	assert_true(sorted_mapped_events == expected_event_ids, "the Act 2 Event nodes expose all six existing Event families", failures)
	assert_true(registry.validate().is_valid(), "all Act 2 map payload references pass typed registry validation", failures)

func test_stage_four_enemy_rosters_use_existing_act_payloads(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	AlphaScaleCatalog.register_all(registry)
	var act_one_map = MiniActMapCatalog.definition_for_act(1, registry)
	var act_two_map = MiniActMapCatalog.definition_for_act(2, registry)
	for encounter_id in AlphaScaleCatalog.ACT_ONE_NORMAL_ENCOUNTER_IDS + AlphaScaleCatalog.ACT_ONE_ELITE_ENCOUNTER_IDS:
		assert_true(_map_has_payload(act_one_map, encounter_id), "%s is selectable from the Act 1 map payloads" % encounter_id, failures)
		assert_true(not _map_has_payload(act_two_map, encounter_id), "%s is excluded from the Act 2 map payloads" % encounter_id, failures)
	for encounter_id in AlphaScaleCatalog.ACT_TWO_NORMAL_ENCOUNTER_IDS + AlphaScaleCatalog.ACT_TWO_ELITE_ENCOUNTER_IDS:
		assert_true(_map_has_payload(act_two_map, encounter_id), "%s is selectable from the Act 2 map payloads" % encounter_id, failures)
		assert_true(not _map_has_payload(act_one_map, encounter_id), "%s is excluded from the Act 1 map payloads" % encounter_id, failures)
	var act_two_only_encounters := _encounter_variant_ids(AlphaActTwoCatalog.ACT_TWO_NORMAL_ENCOUNTER_IDS)
	act_two_only_encounters.append_array(_encounter_variant_ids([
		AlphaActTwoCatalog.ACT_TWO_ELITE_ENCOUNTER_ID,
		AlphaActTwoCatalog.ACT_TWO_BOSS_ENCOUNTER_ID,
	]))
	act_two_only_encounters.append_array(AlphaScaleCatalog.ACT_TWO_NORMAL_ENCOUNTER_IDS)
	act_two_only_encounters.append_array(AlphaScaleCatalog.ACT_TWO_ELITE_ENCOUNTER_IDS)
	for encounter_id in act_two_only_encounters:
		assert_true(not _map_has_payload(act_one_map, encounter_id), "Act 1 cannot select the Act 2-only encounter %s" % encounter_id, failures)
	var existing_normal_ids: Array = Phase2Catalog.NORMAL_ENEMY_IDS + AlphaActTwoCatalog.ACT_TWO_NORMAL_ENEMY_IDS
	var new_normal_ids: Array = AlphaScaleCatalog.ACT_ONE_NORMAL_ENEMY_IDS + AlphaScaleCatalog.ACT_TWO_NORMAL_ENEMY_IDS
	for enemy_id in existing_normal_ids + new_normal_ids:
		var enemy = registry.resolve(enemy_id)
		assert_true(enemy is EnemyDefinition and enemy.role == EnemyDefinition.NORMAL, "%s remains a registered Normal enemy" % enemy_id, failures)
	var existing_elite_ids: Array = [Phase2Catalog.ELITE_ENEMY_ID, AlphaActTwoCatalog.ACT_TWO_ELITE_ENEMY_ID]
	var new_elite_ids: Array = AlphaScaleCatalog.ACT_ONE_ELITE_ENEMY_IDS + AlphaScaleCatalog.ACT_TWO_ELITE_ENEMY_IDS
	for enemy_id in existing_elite_ids + new_elite_ids:
		var enemy = registry.resolve(enemy_id)
		assert_true(enemy is EnemyDefinition and enemy.role == EnemyDefinition.ELITE, "%s remains a registered Elite" % enemy_id, failures)
	for index in AlphaScaleCatalog.ACT_ONE_NORMAL_ENCOUNTER_IDS.size():
		var encounter_id: String = AlphaScaleCatalog.ACT_ONE_NORMAL_ENCOUNTER_IDS[index]
		var encounter = registry.resolve(encounter_id)
		assert_true(encounter is EncounterDefinition and encounter.encounter_kind == EncounterDefinition.NORMAL and encounter.enemy_ids == [AlphaScaleCatalog.ACT_ONE_NORMAL_ENEMY_IDS[index]], "%s resolves to its intended Act 1 Normal" % encounter_id, failures)
	for index in AlphaScaleCatalog.ACT_TWO_NORMAL_ENCOUNTER_IDS.size():
		var encounter_id: String = AlphaScaleCatalog.ACT_TWO_NORMAL_ENCOUNTER_IDS[index]
		var encounter = registry.resolve(encounter_id)
		assert_true(encounter is EncounterDefinition and encounter.encounter_kind == EncounterDefinition.NORMAL and encounter.enemy_ids == [AlphaScaleCatalog.ACT_TWO_NORMAL_ENEMY_IDS[index]], "%s resolves to its intended Act 2 Normal" % encounter_id, failures)
	for index in AlphaScaleCatalog.ACT_ONE_ELITE_ENCOUNTER_IDS.size():
		var encounter_id: String = AlphaScaleCatalog.ACT_ONE_ELITE_ENCOUNTER_IDS[index]
		var encounter = registry.resolve(encounter_id)
		assert_true(encounter is EncounterDefinition and encounter.encounter_kind == EncounterDefinition.ELITE and encounter.enemy_ids == [AlphaScaleCatalog.ACT_ONE_ELITE_ENEMY_IDS[index]], "%s resolves to its intended Act 1 Elite" % encounter_id, failures)
	for index in AlphaScaleCatalog.ACT_TWO_ELITE_ENCOUNTER_IDS.size():
		var encounter_id: String = AlphaScaleCatalog.ACT_TWO_ELITE_ENCOUNTER_IDS[index]
		var encounter = registry.resolve(encounter_id)
		assert_true(encounter is EncounterDefinition and encounter.encounter_kind == EncounterDefinition.ELITE and encounter.enemy_ids == [AlphaScaleCatalog.ACT_TWO_ELITE_ENEMY_IDS[index]], "%s resolves to its intended Act 2 Elite" % encounter_id, failures)
	assert_true(registry.validate().is_valid(), "new encounter references and existing Act content remain valid", failures)

func _map_has_payload(map_definition, target_payload_id: String) -> bool:
	for node_id in map_definition.node_ids:
		var node = map_definition.node_definition(node_id)
		if node.payload_options.has(target_payload_id):
			return true
	return false


func _encounter_variant_ids(base_ids: Array) -> Array:
	var variants: Array = []
	for value in base_ids:
		variants.append(str(value))
		variants.append("%s.a" % value)
		variants.append("%s.b" % value)
	return variants

func test_failed_catalog_registration_does_not_change_bundle_identity(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	var version_before_failed_registration: String = registry.content_version()
	registry.register(ContentDefinition.new(AlphaScaleCatalog.PASSIVE_ID))
	var registration = AlphaScaleCatalog.register_all(registry)

	assert_true(not registration.is_valid(), "a catalog with an existing ID collision fails registration", failures)
	assert_true(registry.content_version() == version_before_failed_registration, "a failed Scale registration does not claim its bundle version", failures)
	assert_true(registry.resolve(AlphaScaleCatalog.CHARACTER_ID) == null, "a failed catalog registration does not partially add Scale definitions", failures)

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

func test_scale_relic_act_groups_and_pool_membership(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	var registration = AlphaScaleCatalog.register_all(registry)
	assert_true(registration.is_valid() and registry.validate().is_valid(), "the expanded Scale catalog remains valid typed content", failures)
	assert_true(AlphaScaleCatalog.ACT_ONE_RELIC_IDS.size() == 7, "Scale adds seven Relics eligible from Act 1", failures)
	assert_true(AlphaScaleCatalog.NEW_ACT_TWO_RELIC_IDS.size() == 7, "Scale adds seven Relics introduced in Act 2", failures)
	assert_true(AlphaScaleCatalog.RELIC_IDS.size() == 25, "the Act 2 introduction group contains its original eighteen plus seven additions", failures)
	for relic_id in AlphaScaleCatalog.NEW_ACT_TWO_RELIC_IDS:
		assert_true(AlphaScaleCatalog.RELIC_IDS.has(relic_id), "%s is listed in the Act 2 introduction group" % relic_id, failures)
	var production_relic_ids: Array = Phase2Catalog.RELIC_IDS + AlphaScaleCatalog.ACT_ONE_RELIC_IDS + AlphaScaleCatalog.RELIC_IDS
	var unique_relic_ids: Dictionary = {}
	var act_one_count := 0
	var act_two_count := 0
	for relic_id in production_relic_ids:
		assert_true(not unique_relic_ids.has(relic_id), "%s appears only once in the production roster" % relic_id, failures)
		unique_relic_ids[relic_id] = true
		var relic = registry.resolve(relic_id)
		assert_true(relic is RelicDefinition, "%s resolves in the full production catalog" % relic_id, failures)
		if relic is RelicDefinition:
			act_one_count += int(relic.available_from_act == 1)
			act_two_count += int(relic.available_from_act == 2)
	assert_true(unique_relic_ids.size() == 50, "the production Relic roster contains exactly fifty unique IDs", failures)
	assert_true(act_one_count == 25 and act_two_count == 25, "the production Relic roster splits exactly 25 Act 1 eligible and 25 Act 2 introduced", failures)
	for relic_id in AlphaScaleCatalog.ACT_ONE_RELIC_IDS:
		var relic = registry.resolve(relic_id)
		assert_true(relic is RelicDefinition and relic.available_from_act == 1 and not relic.active, "%s is a Normal Relic available from Act 1" % relic_id, failures)
		if relic is RelicDefinition:
			_assert_all_typed_effects(relic.effects, relic_id, failures)
	for relic_id in AlphaScaleCatalog.RELIC_IDS:
		var relic = registry.resolve(relic_id)
		assert_true(relic is RelicDefinition and relic.available_from_act == 2 and not relic.active, "%s is a Normal Relic introduced in Act 2" % relic_id, failures)
		if relic is RelicDefinition:
			_assert_all_typed_effects(relic.effects, relic_id, failures)
	var membership: Dictionary = AlphaScaleCatalog.pool_membership()
	for relic_id in AlphaScaleCatalog.ACT_ONE_RELIC_IDS:
		assert_true(membership[AlphaScaleCatalog.ACT_ONE_BUILD_POOL_ID].has(relic_id), "%s joins the Act 1 build pool" % relic_id, failures)
		assert_true(membership[AlphaScaleCatalog.ACT_TWO_BUILD_POOL_ID].has(relic_id), "%s remains available in the Act 2 build pool" % relic_id, failures)
	for relic_id in AlphaScaleCatalog.RELIC_IDS:
		assert_true(not membership[AlphaScaleCatalog.ACT_ONE_BUILD_POOL_ID].has(relic_id), "%s is excluded from the Act 1 build pool" % relic_id, failures)
		assert_true(membership[AlphaScaleCatalog.ACT_TWO_BUILD_POOL_ID].has(relic_id), "%s joins the Act 2 build pool" % relic_id, failures)
		assert_true(membership[AlphaScaleCatalog.ACT_TWO_SHOP_POOL_ID].has(relic_id), "%s joins the Act 2 Shop pool" % relic_id, failures)

func test_stage_four_modifiers_are_typed_shared_workshop_content(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	var registration = AlphaScaleCatalog.register_all(registry)
	assert_true(registration.is_valid() and registry.validate().is_valid(), "Scale modifiers register as valid typed content", failures)
	var expected_operations := {
		"alpha.modifier.wide_channel": ["ModifyDrawCapacity"],
		"alpha.modifier.sharp_current": ["DealDamage"],
		"alpha.modifier.trade_mark": ["ModifyRunCurrency", "GainStability"],
		"alpha.modifier.refinement_trace": ["ModifyRunCurrency", "GainTP"],
	}
	var membership: Dictionary = AlphaScaleCatalog.pool_membership()
	var workshop_pool = registry.resolve(AlphaScaleCatalog.WORKSHOP_POOL_ID)
	for modifier_id in expected_operations:
		assert_true(AlphaScaleCatalog.MODIFIER_IDS.has(modifier_id), "%s is in the Scale production Modifier roster" % modifier_id, failures)
		var modifier = registry.resolve(modifier_id)
		assert_true(modifier is TileModifierDefinition and modifier.validate().is_valid(), "%s has valid Tile Modifier metadata" % modifier_id, failures)
		if not modifier is TileModifierDefinition:
			continue
		assert_true(not modifier.modifier_kind.is_empty() and modifier.max_per_tile == 1, "%s declares a kind and the existing one-per-tile limit" % modifier_id, failures)
		var expected_modifier_operations: Array = expected_operations[modifier_id]
		assert_true(modifier.effects.size() == expected_modifier_operations.size(), "%s configures its distinct existing operation set" % modifier_id, failures)
		if modifier.effects.size() != expected_modifier_operations.size():
			continue
		for effect_index in expected_modifier_operations.size():
			var effect = modifier.effects[effect_index]
			assert_true(effect.operations.size() == 1, "%s keeps each operation in its own typed Effect" % modifier_id, failures)
			if effect.operations.size() != 1:
				continue
			var operation = effect.operations[0]
			assert_true(operation.operation_id == expected_modifier_operations[effect_index], "%s uses its authored existing operation" % modifier_id, failures)
			if modifier_id == "alpha.modifier.trade_mark" and effect_index == 0:
				assert_true(operation.currency == "GOLD", "%s grants the existing Gold currency" % modifier_id, failures)
			elif modifier_id == "alpha.modifier.refinement_trace" and effect_index == 0:
				assert_true(operation.currency == "REFINEMENT_TOKENS", "%s grants the existing Refinement Token currency" % modifier_id, failures)
		assert_true(membership[AlphaScaleCatalog.WORKSHOP_POOL_ID].has(modifier_id), "%s is available in the shared Workshop pool membership" % modifier_id, failures)
		assert_true(workshop_pool is RewardPoolDefinition and workshop_pool.entry_ids().has(modifier_id), "%s is published through the registered shared Workshop pool" % modifier_id, failures)

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
