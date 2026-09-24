class_name Phase2FoundationsTest
extends RefCounted

const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const YakuDefinition = preload("res://src/content/definitions/yaku_definition.gd")
const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const RelicDefinition = preload("res://src/content/definitions/relic_definition.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const TileModifierDefinition = preload("res://src/content/definitions/tile_modifier_definition.gd")
const EnemyDefinition = preload("res://src/content/definitions/enemy_definition.gd")
const EncounterDefinition = preload("res://src/content/definitions/encounter_definition.gd")
const EventDefinition = preload("res://src/content/definitions/event_definition.gd")
const MapDefinition = preload("res://src/content/definitions/map_definition.gd")
const MapNodeDefinition = preload("res://src/content/definitions/map_node_definition.gd")
const RewardPoolDefinition = preload("res://src/content/definitions/reward_pool_definition.gd")
const RuleBreakerDefinition = preload("res://src/content/definitions/rule_breaker_definition.gd")
const EnemyIntent = preload("res://src/domain/combat/enemy_intent.gd")
const IntentGraph = preload("res://src/domain/combat/intent_graph.gd")
const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_all_phase_2_definition_types_register_and_validate(failures)
	test_registry_rejects_invalid_namespaces_and_definition_type_prefixes(failures)
	test_registry_exposes_phase_2_content_version(failures)
	test_registry_rejects_duplicate_ids_and_missing_references(failures)
	test_registry_rejects_wrong_typed_references(failures)
	test_event_rejects_duplicate_choice_ids(failures)
	test_tile_and_yaku_families_reject_cross_family_ids_but_allow_prototypes(failures)
	test_new_rng_streams_are_deterministic_snapshotable_and_isolated(failures)
	return failures

func test_all_phase_2_definition_types_register_and_validate(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	var tile := TileDefinition.new("base.tile.man.1", "characters", 1)
	var relic := RelicDefinition.new("base.relic.open_hand")
	var technique := TechniqueDefinition.new("base.technique.core.sequence_line", TechniqueDefinition.CORE, 1)
	var passive := ContentDefinition.new("base.passive.sequence")
	var character := CharacterDefinition.new(
		"base.character.sequence",
		["base.tile.man.1"],
		"base.relic.open_hand",
		"base.technique.core.sequence_line",
		"base.passive.sequence",
	)
	var contract := ContractDefinition.new("base.contract.pressure", "PRESSURE", {"pressure": 1}, {"draw_actions": 1})
	var modifier := TileModifierDefinition.new("base.modifier.flexible_identity", "FLEXIBLE_IDENTITY", 1)
	var graph := IntentGraph.new("pressure", [EnemyIntent.new("pressure", "Pressure", 1)])
	var enemy := EnemyDefinition.new("base.enemy.pressure_sentinel", graph)
	var encounter := EncounterDefinition.new("base.encounter.pressure", ["base.enemy.pressure_sentinel"])
	var event := EventDefinition.new("base.event.risk_bargain", [
		{"choice_id": "accept", "label": "Accept"},
		{"choice_id": "leave", "label": "Leave"},
	])
	var node := MapNodeDefinition.new("base.map_node.start", "BATTLE", [], "base.encounter.pressure")
	var map := MapDefinition.new("base.map.act_one", ["base.map_node.start"], "base.map_node.start")
	var reward_pool := RewardPoolDefinition.new("base.reward_pool.normal", [{"content_id": "base.relic.open_hand", "weight": 1}])
	var rule_breaker := RuleBreakerDefinition.new("base.rule_breaker.open_table", "SETTLEMENT_CAPACITY", 1)

	for definition in [tile, relic, technique, passive, character, contract, modifier, enemy, encounter, event, node, map, reward_pool, rule_breaker]:
		var registration = registry.register(definition)
		assert_true(registration.is_valid(), "registers %s" % definition.content_id, failures)

	var validation = registry.validate()
	assert_true(validation.is_valid(), "all Phase 2 definition foundations validate", failures)
	assert_true(registry.resolve("base.character.sequence") is CharacterDefinition, "registry preserves typed CharacterDefinition", failures)
	assert_true(registry.resolve("base.map.act_one") is MapDefinition, "registry preserves typed MapDefinition", failures)

func test_registry_rejects_invalid_namespaces_and_definition_type_prefixes(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	var invalid_namespace = CharacterDefinition.new("mods.character.external")
	var invalid_prefix = CharacterDefinition.new("base.relic.not_a_character")

	var namespace_report = registry.register(invalid_namespace)
	var prefix_report = registry.register(invalid_prefix)
	assert_true(not namespace_report.is_valid(), "production registry rejects non-base/non-prototype namespaces", failures)
	assert_true(not prefix_report.is_valid(), "typed definition rejects a stable ID from another content family", failures)
	assert_true(namespace_report.has_code("invalid_namespace"), "namespace rejection is reported deterministically", failures)
	assert_true(prefix_report.has_code("invalid_definition_type"), "type-prefix rejection is reported deterministically", failures)

func test_registry_exposes_phase_2_content_version(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	assert_true(ContentRegistry.CONTENT_VERSION == "content.slice.v2", "Phase 2 content version advances for the Boss reward definitions", failures)
	assert_true(registry.content_version() == "content.slice.v2", "registry exposes the updated Phase 2 content version", failures)

func test_registry_rejects_duplicate_ids_and_missing_references(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	var first := RelicDefinition.new("base.relic.open_hand")
	var duplicate := RelicDefinition.new("base.relic.open_hand")
	var dependent := CharacterDefinition.new("base.character.missing", ["base.tile.missing"], "base.relic.missing", "base.technique.missing", "base.passive.missing")

	assert_true(registry.register(first).is_valid(), "first typed definition registers", failures)
	var duplicate_report = registry.register(duplicate)
	assert_true(not duplicate_report.is_valid() and duplicate_report.has_code("duplicate_id"), "duplicate typed IDs are rejected", failures)
	assert_true(registry.register(dependent).is_valid(), "definitions with unresolved references can be staged for validation", failures)
	var validation = registry.validate()
	assert_true(validation.has_code("missing_reference"), "missing typed references are rejected during validation", failures)

func test_event_rejects_duplicate_choice_ids(failures: Array[String]) -> void:
	var event := EventDefinition.new("base.event.duplicate_choices", [
		{"choice_id": "accept", "label": "Accept"},
		{"choice_id": "accept", "label": "Accept again"},
	])
	var validation = event.validate()
	assert_true(not validation.is_valid(), "EventDefinition rejects duplicate choice IDs", failures)
	assert_true(validation.has_code("duplicate_event_choice"), "duplicate Event choice IDs report duplicate_event_choice", failures)

func test_registry_rejects_wrong_typed_references(failures: Array[String]) -> void:
	var registry := ContentRegistry.new()
	registry.register(TileDefinition.new("base.tile.man.1", "characters", 1))
	registry.register(TechniqueDefinition.new("base.technique.core.sequence_line", TechniqueDefinition.CORE, 1))
	registry.register(ContentDefinition.new("base.passive.sequence"))
	registry.register(CharacterDefinition.new(
		"base.character.wrong_reference",
		["base.tile.man.1"],
		"base.passive.sequence",
		"base.technique.core.sequence_line",
		"base.passive.sequence",
	))
	var validation = registry.validate()
	assert_true(validation.has_code("invalid_reference_type"), "registry rejects a reference with the wrong typed definition", failures)

func test_tile_and_yaku_families_reject_cross_family_ids_but_allow_prototypes(failures: Array[String]) -> void:
	var invalid_tile := TileDefinition.new("base.yaku.not_a_tile", "characters", 1)
	var invalid_yaku := YakuDefinition.new("base.tile.not_a_yaku", "Not a Yaku")
	var prototype_tile := TileDefinition.new("prototype.tile.man.1", "characters", 1)
	var prototype_yaku := YakuDefinition.new("prototype.yaku.fixture", "Prototype Yaku")

	var invalid_tile_report = invalid_tile.validate()
	var invalid_yaku_report = invalid_yaku.validate()
	assert_true(invalid_tile_report.has_code("invalid_definition_type"), "TileDefinition rejects a Yaku family ID", failures)
	assert_true(invalid_yaku_report.has_code("invalid_definition_type"), "YakuDefinition rejects a Tile family ID", failures)
	assert_true(prototype_tile.validate().is_valid(), "prototype TileDefinition IDs remain compatible", failures)
	assert_true(prototype_yaku.validate().is_valid(), "prototype YakuDefinition IDs remain compatible", failures)

func test_new_rng_streams_are_deterministic_snapshotable_and_isolated(failures: Array[String]) -> void:
	var first := DomainRngStreams.new(424242)
	var second := DomainRngStreams.new(424242)
	var gameplay_streams: Array = [first.map, first.reward, first.shop, first.event]
	var second_gameplay_streams: Array = [second.map, second.reward, second.shop, second.event]
	for index in gameplay_streams.size():
		assert_true(gameplay_streams[index].next_int(0, 1000) == second_gameplay_streams[index].next_int(0, 1000), "same seed repeats new RNG stream %s" % gameplay_streams[index].stream_id, failures)

	var saved := first.snapshot()
	var expected_map: int = first.map.next_int(0, 1000)
	var expected_cosmetic: int = first.cosmetic.next_int(0, 1000)
	assert_true(first.restore(saved), "all Phase 2 RNG streams restore through the existing contract", failures)
	assert_true(first.map.next_int(0, 1000) == expected_map, "Map stream restores its sequence", failures)
	assert_true(first.cosmetic.next_int(0, 1000) == expected_cosmetic, "Cosmetic stream restores its sequence", failures)

	var isolated := DomainRngStreams.new(424242)
	var reference := DomainRngStreams.new(424242)
	for _index in 8:
		isolated.cosmetic.next_int(0, 1000)
	assert_true(isolated.map.next_int(0, 1000) == reference.map.next_int(0, 1000), "Cosmetic RNG cannot advance Map RNG", failures)
	assert_true(isolated.reward.next_int(0, 1000) == reference.reward.next_int(0, 1000), "Cosmetic RNG cannot advance Reward RNG", failures)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
