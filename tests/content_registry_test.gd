class_name ContentRegistryTest
extends RefCounted

const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_registers_and_resolves_a_minimal_tile_definition(failures)
	test_rejects_duplicate_content_ids(failures)
	test_reports_missing_references(failures)
	test_enumerates_definitions_in_stable_id_order(failures)
	test_minimal_definitions_validate_successfully(failures)
	return failures

func test_registers_and_resolves_a_minimal_tile_definition(failures: Array[String]) -> void:
	var registry = ContentRegistry.new()
	var tile = TileDefinition.new("base.tile.man.5", "characters", 5)
	var registration = registry.register(tile)

	assert_true(registration.is_valid(), "a minimal TileDefinition registers successfully", failures)
	assert_true(registry.resolve("base.tile.man.5") == tile, "the registry resolves a TileDefinition by stable ID", failures)
	assert_true(registry.resolve("base.tile.man.6") == null, "an unknown stable ID does not resolve", failures)

func test_rejects_duplicate_content_ids(failures: Array[String]) -> void:
	var registry = ContentRegistry.new()
	var first = ContentDefinition.new("base.relic.quiet_table")
	var duplicate = ContentDefinition.new("base.relic.quiet_table")

	assert_true(registry.register(first).is_valid(), "the first definition with an ID registers", failures)
	var duplicate_registration = registry.register(duplicate)
	assert_true(not duplicate_registration.is_valid(), "a duplicate content ID is rejected", failures)
	assert_true(duplicate_registration.has_code("duplicate_id"), "duplicate rejection reports duplicate_id", failures)
	assert_true(registry.resolve("base.relic.quiet_table") == first, "the first definition remains authoritative after rejection", failures)

func test_reports_missing_references(failures: Array[String]) -> void:
	var registry = ContentRegistry.new()
	var dependent = ContentDefinition.new("base.character.seer", ["base.relic.missing"])
	registry.register(dependent)

	var validation = registry.validate()
	assert_true(not validation.is_valid(), "validation fails when a definition references a missing ID", failures)
	assert_true(validation.has_code("missing_reference"), "missing references are reported with missing_reference", failures)
	assert_true(validation.issues.size() == 1, "the missing-reference case reports one issue", failures)
	if validation.issues.size() == 1:
		assert_true(validation.issues[0].content_id == "base.character.seer", "missing-reference reports identify the dependent definition", failures)
		assert_true(validation.issues[0].reference_id == "base.relic.missing", "missing-reference reports identify the unresolved ID", failures)

func test_enumerates_definitions_in_stable_id_order(failures: Array[String]) -> void:
	var first_registry = ContentRegistry.new()
	first_registry.register(ContentDefinition.new("base.zeta"))
	first_registry.register(ContentDefinition.new("base.alpha"))

	var second_registry = ContentRegistry.new()
	second_registry.register(ContentDefinition.new("base.alpha"))
	second_registry.register(ContentDefinition.new("base.zeta"))

	var first_ids = _content_ids(first_registry.enumerate())
	var second_ids = _content_ids(second_registry.enumerate())
	assert_true(first_ids == ["base.alpha", "base.zeta"], "enumeration sorts definitions by stable ID", failures)
	assert_true(first_ids == second_ids, "enumeration is independent of registration order", failures)

func test_minimal_definitions_validate_successfully(failures: Array[String]) -> void:
	var registry = ContentRegistry.new()
	registry.register(ContentDefinition.new("base.content.minimal"))
	registry.register(TileDefinition.new("base.tile.man.5", "characters", 5))

	assert_true(registry.validate().is_valid(), "minimal content and tile definitions validate successfully", failures)

func _content_ids(definitions: Array) -> Array[String]:
	var ids: Array[String] = []
	for definition in definitions:
		ids.append(definition.content_id)
	return ids

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
