class_name Stage4ContentCompletenessTest
extends RefCounted

const ActTwo = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const Scale = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const Character = preload("res://src/content/definitions/character_definition.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const Encounter = preload("res://src/content/definitions/encounter_definition.gd")
const Enemy = preload("res://src/content/definitions/enemy_definition.gd")
const Event = preload("res://src/content/definitions/event_definition.gd")
const Map = preload("res://src/content/definitions/map_definition.gd")
const MapNode = preload("res://src/content/definitions/map_node_definition.gd")
const MapCatalog = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const MetaCoordinator = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaState = preload("res://src/domain/run/meta_progress_state.gd")
const Phase2 = preload("res://src/content/catalogs/phase_2_catalog.gd")
const Relic = preload("res://src/content/definitions/relic_definition.gd")
const RewardPool = preload("res://src/content/definitions/reward_pool_definition.gd")
const RunEconomy = preload("res://src/domain/run/run_economy.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunController = preload("res://src/presentation/run/run_presentation_controller.gd")
const ShopOffer = preload("res://src/domain/run/shop_offer.gd")
const ShopSelector = preload("res://src/domain/run/shop_offer_selector.gd")
const Technique = preload("res://src/content/definitions/technique_definition.gd")

const EVENT_FAMILIES := ["tile_surgery", "risk_bargain", "gold_exchange", "map_reveal", "contract_clause", "rule_memory"]

func run() -> Array[String]:
	var failures: Array[String] = []
	var registry := ContentRegistry.new()
	assert_true(Phase2.register_all(registry).is_valid(), "Phase 2 catalog registers", failures)
	assert_true(ActTwo.register_all(registry).is_valid(), "Act 2 catalog registers", failures)
	assert_true(Scale.register_all(registry).is_valid(), "Scale catalog registers", failures)
	assert_true(registry.validate().is_valid(), "combined production catalog validates", failures)
	test_production_roster_counts(registry, failures)
	test_act_pools(registry, failures)
	test_run_start_choices(registry, failures)
	test_map_reachability(registry, failures)
	return failures

func test_production_roster_counts(registry: ContentRegistry, failures: Array[String]) -> void:
	var characters: Array = Scale.all_character_ids()
	var contracts: Array = Scale.all_contract_ids()
	var production_yaku: Array = Phase2.PRODUCTION_YAKU_IDS + Scale.YAKU_IDS
	var relics: Array = Phase2.RELIC_IDS + Scale.ACT_ONE_RELIC_IDS + Scale.RELIC_IDS
	var rule_breakers: Array = Scale.ACT_ONE_BOSS_RULE_BREAKER_IDS + Scale.ACT_TWO_BOSS_RULE_BREAKER_IDS
	var run_techniques: Array = Phase2.RUN_TECHNIQUE_IDS + Scale.RUN_TECHNIQUE_IDS
	var core_techniques: Array = Phase2.CORE_TECHNIQUE_IDS + [Scale.CORE_TECHNIQUE_ID]
	var modifiers: Array = Phase2.MODIFIER_IDS + Scale.MODIFIER_IDS
	var act_one_normals: Array = Phase2.NORMAL_ENEMY_IDS + Scale.ACT_ONE_NORMAL_ENEMY_IDS
	var act_two_normals: Array = ActTwo.ACT_TWO_NORMAL_ENEMY_IDS + Scale.ACT_TWO_NORMAL_ENEMY_IDS
	var act_one_elites: Array = [Phase2.ELITE_ENEMY_ID] + Scale.ACT_ONE_ELITE_ENEMY_IDS
	var act_two_elites: Array = [ActTwo.ACT_TWO_ELITE_ENEMY_ID] + Scale.ACT_TWO_ELITE_ENEMY_IDS
	var act_one_bosses: Array = [Phase2.BOSS_ID, Scale.ACT_ONE_BOSS_ENEMY_ID]
	var act_two_bosses: Array = [ActTwo.ACT_TWO_BOSS_ENEMY_ID, ActTwo.ACT_TWO_ALTERNATE_BOSS_ENEMY_ID]
	var act_one_events: Array = Phase2.EVENT_IDS + Scale.ACT_ONE_EVENT_IDS
	var act_two_events: Array = ActTwo.ACT_TWO_EVENT_IDS + ActTwo.ACT_TWO_ADDITIONAL_EVENT_IDS
	var all_production_ids: Array = characters + contracts + production_yaku + relics + rule_breakers + run_techniques + core_techniques + modifiers + act_one_normals + act_two_normals + act_one_elites + act_two_elites + act_one_bosses + act_two_bosses + act_one_events + act_two_events
	_assert_roster(registry, "Characters", characters, 3, "CharacterDefinition", failures)
	_assert_roster(registry, "Contracts", contracts, 8, "ContractDefinition", failures)
	_assert_roster(registry, "canonical production Yaku", production_yaku, 24, "YakuDefinition", failures)
	_assert_roster(registry, "Relics", relics, 50, "RelicDefinition", failures)
	_assert_roster(registry, "Boss Rule Breakers", rule_breakers, 10, "RuleBreakerDefinition", failures)
	_assert_roster(registry, "Run Techniques", run_techniques, 21, "TechniqueDefinition", failures)
	_assert_roster(registry, "Character-bound Core Techniques", core_techniques, 3, "TechniqueDefinition", failures)
	_assert_roster(registry, "Tile Modifiers", modifiers, 12, "TileModifierDefinition", failures)
	_assert_roster(registry, "Act 1 Normal enemies", act_one_normals, 7, "EnemyDefinition", failures)
	_assert_roster(registry, "Act 2 Normal enemies", act_two_normals, 7, "EnemyDefinition", failures)
	_assert_roster(registry, "Act 1 Elites", act_one_elites, 3, "EnemyDefinition", failures)
	_assert_roster(registry, "Act 2 Elites", act_two_elites, 3, "EnemyDefinition", failures)
	_assert_roster(registry, "Act 1 Boss definitions", act_one_bosses, 2, "EnemyDefinition", failures)
	_assert_roster(registry, "Act 2 Boss definitions", act_two_bosses, 2, "EnemyDefinition", failures)
	_assert_roster(registry, "Act 1 Events", act_one_events, 12, "EventDefinition", failures)
	_assert_roster(registry, "Act 2 Events", act_two_events, 12, "EventDefinition", failures)
	_assert_registry_roster(registry, "CharacterDefinition", characters, "Characters", failures)
	_assert_registry_roster(registry, "ContractDefinition", contracts, "Contracts", failures)
	var registered_yaku := _registry_ids(registry, "YakuDefinition")
	var registered_production_yaku: Array[String] = []
	for yaku_id in registered_yaku:
		if not Phase2.PROTOTYPE_YAKU_IDS.has(yaku_id):
			registered_production_yaku.append(yaku_id)
	_assert_exact_ids(registered_production_yaku, production_yaku, "canonical production Yaku registry", failures)
	_assert_exact_ids(registered_yaku, production_yaku + Phase2.PROTOTYPE_YAKU_IDS, "complete Yaku registry including only the eight compatibility prototypes", failures)
	_assert_registry_roster(registry, "RelicDefinition", relics, "Relics", failures)
	_assert_registry_roster(registry, "RuleBreakerDefinition", rule_breakers, "Boss Rule Breakers", failures)
	_assert_registry_roster(registry, "TileModifierDefinition", modifiers, "Tile Modifiers", failures)
	_assert_registry_roster(registry, "EventDefinition", act_one_events + act_two_events, "Events across both Acts", failures)
	var expected_enemies: Array = act_one_normals + act_two_normals + act_one_elites + act_two_elites + act_one_bosses + act_two_bosses
	_assert_registry_roster(registry, "EnemyDefinition", expected_enemies, "canonical Enemy definitions across all Acts", failures)
	_assert_exact_ids(_enemy_ids_for_role(registry, Enemy.NORMAL), act_one_normals + act_two_normals, "canonical Normal Enemy registry", failures)
	_assert_exact_ids(_enemy_ids_for_role(registry, Enemy.ELITE), act_one_elites + act_two_elites, "canonical Elite Enemy registry", failures)
	_assert_exact_ids(_enemy_ids_for_role(registry, Enemy.BOSS), act_one_bosses + act_two_bosses, "canonical Boss Enemy registry", failures)
	var expected_techniques: Array = run_techniques + core_techniques
	_assert_registry_roster(registry, "TechniqueDefinition", expected_techniques, "all Techniques across Run and Core categories", failures)
	_assert_exact_ids(_technique_ids_for_core_category(registry, false), run_techniques, "Run Technique registry", failures)
	_assert_exact_ids(_technique_ids_for_core_category(registry, true), core_techniques, "Core Technique registry", failures)
	assert_true(_unique_count(all_production_ids) == all_production_ids.size(), "canonical production IDs are unique across the complete Stage 4 roster", failures)
	assert_true(Scale.ACT_ONE_BOSS_RULE_BREAKER_IDS.size() == 5 and Scale.ACT_TWO_BOSS_RULE_BREAKER_IDS.size() == 5, "each Act defines exactly five Boss Rule Breakers", failures)
	assert_true(_unique_count(production_yaku + Phase2.PROTOTYPE_YAKU_IDS) == 32, "eight compatibility Yaku prototypes stay outside the 24-production-Yaku budget", failures)
	assert_true(_unique_count(act_one_normals + act_two_normals) == 14, "the two Act Normal rosters contain fourteen unique definitions", failures)
	assert_true(_unique_count(act_one_elites + act_two_elites) == 6, "the two Act Elite rosters contain six unique definitions", failures)
	assert_true(_unique_count(act_one_bosses + act_two_bosses) == 4, "the two Act Boss rosters contain four unique definitions", failures)
	var act_one_relics := 0
	var act_two_relics := 0
	for relic_id in relics:
		var definition = registry.resolve(str(relic_id))
		if definition is Relic:
			act_one_relics += int(definition.available_from_act == 1)
			act_two_relics += int(definition.available_from_act == 2)
	assert_true(act_one_relics == 25 and act_two_relics == 25, "Relics split into 25 Act 1-eligible and 25 Act 2-introduced definitions", failures)
	var bound_core_ids: Array[String] = []
	for character_id in characters:
		var character = registry.resolve(str(character_id))
		if character is Character:
			bound_core_ids.append(character.core_technique_id)
			var technique = registry.resolve(character.core_technique_id)
			assert_true(technique is Technique and technique.technique_kind == Technique.CORE, "%s binds a registered Core Technique" % character_id, failures)
	assert_true(_same_set(bound_core_ids, core_techniques), "the three Core Techniques bind one-to-one to the three Characters", failures)
	var main_act_ids := _registry_ids(registry, "MapDefinition")
	assert_true(main_act_ids.size() == 2, "exactly two Main Act maps are registered", failures)
	assert_true(_same_set(main_act_ids, ["base.map.act_one", "base.map.act_two"]), "the production registry contains exactly the two Main Act maps", failures)
	assert_true(RunDomain.new_alpha_run("stage4.act-count", 8701, registry).state.act_count == 2, "a production Alpha Run has exactly two Main Acts", failures)

func test_act_pools(registry: ContentRegistry, failures: Array[String]) -> void:
	var membership: Dictionary = Scale.pool_membership()
	var act_one_build: Array = Phase2.RELIC_IDS + Scale.ACT_ONE_RELIC_IDS + Phase2.RUN_TECHNIQUE_IDS + Scale.RUN_TECHNIQUE_IDS
	var act_two_build: Array = Phase2.RELIC_IDS + Scale.ACT_ONE_RELIC_IDS + Scale.RELIC_IDS + Phase2.RUN_TECHNIQUE_IDS + Scale.RUN_TECHNIQUE_IDS
	_assert_pool(registry, Scale.ACT_ONE_BUILD_POOL_ID, membership, act_one_build, failures)
	_assert_pool(registry, Scale.ACT_TWO_BUILD_POOL_ID, membership, act_two_build, failures)
	_assert_pool(registry, Scale.ACT_TWO_SHOP_POOL_ID, membership, act_two_build, failures)
	_assert_pool(registry, Scale.WORKSHOP_POOL_ID, membership, Phase2.MODIFIER_IDS + Scale.MODIFIER_IDS, failures)
	_assert_pool(registry, Scale.ACT_ONE_BOSS_RULE_BREAKER_POOL_ID, membership, Scale.ACT_ONE_BOSS_RULE_BREAKER_IDS, failures)
	_assert_pool(registry, Scale.ACT_TWO_BOSS_RULE_BREAKER_POOL_ID, membership, Scale.ACT_TWO_BOSS_RULE_BREAKER_IDS, failures)
	_assert_shop_candidates(registry, 1, Phase2.RELIC_IDS + Scale.ACT_ONE_RELIC_IDS, Phase2.RUN_TECHNIQUE_IDS + Scale.RUN_TECHNIQUE_IDS, failures)
	_assert_shop_candidates(registry, 2, Phase2.RELIC_IDS + Scale.ACT_ONE_RELIC_IDS + Scale.RELIC_IDS, Phase2.RUN_TECHNIQUE_IDS + Scale.RUN_TECHNIQUE_IDS, failures)
	for relic_id in Phase2.RELIC_IDS + Scale.ACT_ONE_RELIC_IDS:
		assert_true(membership[Scale.ACT_ONE_BUILD_POOL_ID].has(relic_id) and membership[Scale.ACT_TWO_BUILD_POOL_ID].has(relic_id), "%s is eligible in both Act pools" % relic_id, failures)
	for relic_id in Scale.RELIC_IDS:
		assert_true(not membership[Scale.ACT_ONE_BUILD_POOL_ID].has(relic_id) and membership[Scale.ACT_TWO_BUILD_POOL_ID].has(relic_id), "%s is introduced only in the Act 2 pool" % relic_id, failures)
	for technique_id in Phase2.RUN_TECHNIQUE_IDS + Scale.RUN_TECHNIQUE_IDS:
		assert_true(membership[Scale.ACT_ONE_BUILD_POOL_ID].has(technique_id) and membership[Scale.ACT_TWO_BUILD_POOL_ID].has(technique_id), "%s is available in both Act pools" % technique_id, failures)

func test_run_start_choices(registry: ContentRegistry, failures: Array[String]) -> void:
	var unlock_state = MetaState.all_unlocked_test_profile()
	var domain = RunDomain.new_alpha_run("stage4.run-start", 8702, registry, "", null, null, unlock_state)
	var controller = RunController.new(domain, null, MetaCoordinator.new(null, unlock_state))
	var character_actions: Array = controller.action_descriptors().filter(func(action): return action.get("kind", "") == "CHARACTER")
	assert_true(_same_set(_action_ids(character_actions), Scale.all_character_ids()), "Run start offers all three Characters after the approved unlock", failures)
	if character_actions.is_empty():
		return
	assert_true(controller.confirm(str(character_actions[0].get("id", ""))).accepted, "a Character choice reaches Contract selection", failures)
	var contract_actions: Array = controller.action_descriptors().filter(func(action): return action.get("kind", "") == "CONTRACT")
	assert_true(_same_set(_action_ids(contract_actions), Scale.all_contract_ids()), "Run start offers all eight Contracts after the approved unlock", failures)

func test_map_reachability(registry: ContentRegistry, failures: Array[String]) -> void:
	var act_one_map = MapCatalog.definition_for_act(1, registry)
	var act_two_map = MapCatalog.definition_for_act(2, registry)
	assert_true(act_one_map is Map and act_one_map.validate().is_valid(), "Act 1 authored map validates", failures)
	assert_true(act_two_map is Map and act_two_map.validate().is_valid(), "Act 2 authored map validates", failures)
	if not act_one_map is Map or not act_two_map is Map:
		return
	_assert_map_enemies(registry, act_one_map, MapNode.BATTLE, Phase2.NORMAL_ENEMY_IDS + Scale.ACT_ONE_NORMAL_ENEMY_IDS, "Act 1 Normal", failures)
	_assert_map_enemies(registry, act_two_map, MapNode.BATTLE, ActTwo.ACT_TWO_NORMAL_ENEMY_IDS + Scale.ACT_TWO_NORMAL_ENEMY_IDS, "Act 2 Normal", failures)
	_assert_map_enemies(registry, act_one_map, MapNode.ELITE, [Phase2.ELITE_ENEMY_ID] + Scale.ACT_ONE_ELITE_ENEMY_IDS, "Act 1 Elite", failures)
	_assert_map_enemies(registry, act_two_map, MapNode.ELITE, [ActTwo.ACT_TWO_ELITE_ENEMY_ID] + Scale.ACT_TWO_ELITE_ENEMY_IDS, "Act 2 Elite", failures)
	_assert_map_enemies(registry, act_one_map, MapNode.BOSS, [Phase2.BOSS_ID, Scale.ACT_ONE_BOSS_ENEMY_ID], "Act 1 Boss", failures)
	_assert_map_enemies(registry, act_two_map, MapNode.BOSS, [ActTwo.ACT_TWO_BOSS_ENEMY_ID, ActTwo.ACT_TWO_ALTERNATE_BOSS_ENEMY_ID], "Act 2 Boss", failures)
	var act_one_events: Array = Phase2.EVENT_IDS + Scale.ACT_ONE_EVENT_IDS
	var act_two_events: Array = ActTwo.ACT_TWO_EVENT_IDS + ActTwo.ACT_TWO_ADDITIONAL_EVENT_IDS
	_assert_event_families(act_one_events, "Act 1", failures)
	_assert_event_families(act_two_events, "Act 2", failures)
	_assert_map_events(registry, act_one_map, act_one_events, "Act 1", failures)
	_assert_map_events(registry, act_two_map, act_two_events, "Act 2", failures)

func _assert_roster(registry: ContentRegistry, label: String, ids: Array, expected_count: int, type_name: String, failures: Array[String]) -> void:
	assert_true(ids.size() == expected_count, "%s count is %d" % [label, expected_count], failures)
	assert_true(_unique_count(ids) == expected_count, "%s IDs are unique" % label, failures)
	for id_value in ids:
		var definition = registry.resolve(str(id_value))
		assert_true(definition != null, "%s resolves in the production registry" % id_value, failures)
		if definition != null:
			assert_true(definition.definition_type_name() == type_name, "%s is a canonical %s" % [id_value, type_name], failures)

func _assert_pool(registry: ContentRegistry, pool_id: String, membership: Dictionary, expected: Array, failures: Array[String]) -> void:
	var pool = registry.resolve(pool_id)
	assert_true(pool is RewardPool, "%s is a registered pool" % pool_id, failures)
	assert_true(membership.has(pool_id), "%s has catalogued membership" % pool_id, failures)
	if pool is RewardPool and membership.has(pool_id):
		assert_true(_same_set(pool.entry_ids(), expected), "%s publishes its complete intended content roster" % pool_id, failures)
		assert_true(_same_set(membership[pool_id], expected), "%s registered membership matches its catalog" % pool_id, failures)

func _assert_shop_candidates(registry: ContentRegistry, act_index: int, expected_relics: Array, expected_techniques: Array, failures: Array[String]) -> void:
	var domain = RunDomain.new_alpha_run("stage4.shop.act-%d" % act_index, 8703 + act_index, registry)
	domain.state.act_index = act_index
	var slots: Array[int] = []
	for index in range(100):
		slots.append(index)
	var offers: Array = ShopSelector.new().create_offers(domain.state, registry, null, "stage4.shop.act-%d" % act_index, 0, slots, {}, RunEconomy.new())
	var relic_ids: Array[String] = []
	var technique_ids: Array[String] = []
	for offer in offers:
		if offer.kind == ShopOffer.RELIC:
			relic_ids.append(offer.content_id)
		elif offer.kind == ShopOffer.TECHNIQUE:
			technique_ids.append(offer.content_id)
	assert_true(_same_set(relic_ids, expected_relics), "Act %d Shop candidates offer exactly its approved Relic roster" % act_index, failures)
	assert_true(_same_set(technique_ids, expected_techniques), "Act %d Shop candidates offer all shared Run Techniques" % act_index, failures)

func _assert_map_enemies(registry: ContentRegistry, map: Map, kind: String, expected: Array, label: String, failures: Array[String]) -> void:
	var reachable := _reachable_nodes(map)
	var found: Dictionary = {}
	for node_id in map.node_ids:
		if not reachable.has(node_id):
			continue
		var node = map.node_definition(node_id)
		if node == null or node.node_kind != kind:
			continue
		var required: Array[String] = [str(node_id)]
		assert_true(map.has_route_through(required, _boss_node_id(map)), "%s node has a route to its Act Boss" % node_id, failures)
		for encounter_id in node.payload_options:
			var encounter = registry.resolve(str(encounter_id))
			if encounter is Encounter:
				for enemy_id in encounter.enemy_ids:
					if registry.resolve(enemy_id) is Enemy:
						found[enemy_id] = true
	assert_true(_same_set(found.keys(), expected), "%s map payloads reach exactly the canonical Enemy IDs; encounter wrappers do not add to counts" % label, failures)

func _assert_map_events(registry: ContentRegistry, map: Map, expected: Array, label: String, failures: Array[String]) -> void:
	var reachable := _reachable_nodes(map)
	var mapped: Array = []
	var routes := 0
	for node_id in map.node_ids:
		var node = map.node_definition(node_id)
		if node == null or node.node_kind != MapNode.EVENT or not reachable.has(node_id):
			continue
		routes += 1
		var required: Array[String] = [str(node_id)]
		assert_true(map.has_route_through(required, _boss_node_id(map)), "%s Event route can lead to its Act Boss" % label, failures)
		for event_id in node.payload_options:
			mapped.append(str(event_id))
			assert_true(registry.resolve(str(event_id)) is Event, "%s map route selects a registered Event" % event_id, failures)
	assert_true(routes == 2, "%s exposes two reachable Event routes" % label, failures)
	assert_true(_same_set(mapped, expected), "%s Event routes expose all twelve canonical Event IDs" % label, failures)

func _assert_event_families(ids: Array, label: String, failures: Array[String]) -> void:
	var counts: Dictionary = {}
	for event_id_value in ids:
		var fields := str(event_id_value).split(".")
		var family := str(fields[2]) if fields[0] == "base" else str(fields[3]) if fields.size() >= 4 else ""
		counts[family] = int(counts.get(family, 0)) + 1
	assert_true(_same_set(counts.keys(), EVENT_FAMILIES), "%s includes each of the six existing Event families" % label, failures)
	for family in EVENT_FAMILIES:
		assert_true(int(counts.get(family, 0)) == 2, "%s has two Events in %s" % [label, family], failures)

func _registry_ids(registry: ContentRegistry, type_name: String) -> Array[String]:
	var ids: Array[String] = []
	for definition in registry.enumerate():
		if definition.definition_type_name() == type_name:
			ids.append(definition.content_id)
	return ids

func _assert_registry_roster(registry: ContentRegistry, type_name: String, expected: Array, label: String, failures: Array[String]) -> void:
	_assert_exact_ids(_registry_ids(registry, type_name), expected, "%s registry" % label, failures)

func _assert_exact_ids(actual: Array, expected: Array, label: String, failures: Array[String]) -> void:
	assert_true(_unique_count(actual) == actual.size(), "%s IDs are unique" % label, failures)
	assert_true(_same_set(actual, expected), "%s contains exactly the expected canonical IDs" % label, failures)

func _enemy_ids_for_role(registry: ContentRegistry, role: String) -> Array[String]:
	var ids: Array[String] = []
	for definition in registry.enumerate():
		if definition is Enemy and definition.role == role:
			ids.append(definition.content_id)
	return ids

func _technique_ids_for_core_category(registry: ContentRegistry, core: bool) -> Array[String]:
	var ids: Array[String] = []
	for definition in registry.enumerate():
		if definition is Technique and (definition.technique_kind == Technique.CORE) == core:
			ids.append(definition.content_id)
	return ids

func _action_ids(actions: Array) -> Array[String]:
	var ids: Array[String] = []
	for action in actions:
		ids.append(str(action.get("target_id", "")))
	return ids

func _reachable_nodes(map: Map) -> Dictionary:
	var reachable: Dictionary = {}
	var pending: Array[String] = [map.start_node_id]
	while not pending.is_empty():
		var node_id: String = pending.pop_front()
		if reachable.has(node_id):
			continue
		reachable[node_id] = true
		var node = map.node_definition(node_id)
		if node is MapNode:
			pending.append_array(node.next_node_ids)
	return reachable

func _boss_node_id(map: Map) -> String:
	for node_id in map.node_ids:
		var node = map.node_definition(node_id)
		if node is MapNode and node.node_kind == MapNode.BOSS:
			return str(node_id)
	return ""

func _unique_count(ids: Array) -> int:
	var seen: Dictionary = {}
	for id_value in ids:
		seen[str(id_value)] = true
	return seen.size()

func _same_set(actual: Array, expected: Array) -> bool:
	var left: Array[String] = []
	var right: Array[String] = []
	for id_value in actual:
		left.append(str(id_value))
	for id_value in expected:
		right.append(str(id_value))
	left.sort()
	right.sort()
	return left == right

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
