class_name SettlementTest
extends RefCounted

const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const PartialSettlementResult = preload("res://src/domain/mahjong/settlement/partial_settlement_result.gd")
const PatternCandidate = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const PatternEvaluator = preload("res://src/domain/mahjong/pattern/pattern_evaluator.gd")
const SettlementWindow = preload("res://src/domain/mahjong/settlement/settlement_window.gd")
const SettledPattern = preload("res://src/domain/mahjong/settlement/settled_pattern.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_window_refuses_hand_without_candidate(failures)
	test_window_refuses_pair_only_hand(failures)
	test_invalid_selection_is_rejected_atomically(failures)
	test_non_id_selection_is_rejected(failures)
	test_mixed_selection_is_rejected(failures)
	test_duplicate_selection_is_rejected(failures)
	test_stale_selection_is_rejected(failures)
	test_valid_selection_settles_to_discard(failures)
	test_settlement_creates_settled_pattern_identity(failures)
	test_triplet_and_quad_are_settleable(failures)
	test_settlement_emits_auditable_event(failures)
	test_settled_tile_cannot_be_reused_in_same_window(failures)
	return failures

func test_window_refuses_hand_without_candidate(failures: Array[String]) -> void:
	var registry = _registry([
		["base.tile.characters.1", "characters", 1],
		["base.tile.characters.3", "characters", 3],
	])
	var zones = _hand_zones([
		["run.tile.no_candidate.1", "base.tile.characters.1"],
		["run.tile.no_candidate.3", "base.tile.characters.3"],
	])
	var window := SettlementWindow.new(PatternEvaluator.new(registry), zones)

	assert_true(not window.open(), "a Settlement Window does not open without a legal candidate", failures)
	assert_true(not window.is_open(), "a refused Settlement Window is not open", failures)
	assert_true(window.candidates().is_empty(), "a refused Settlement Window exposes no candidates", failures)

func test_window_refuses_pair_only_hand(failures: Array[String]) -> void:
	var definition_id := "base.tile.dots.5"
	var registry = _registry([[definition_id, "dots", 5]])
	var zones = _hand_zones([
		["run.tile.pair.1", definition_id],
		["run.tile.pair.2", definition_id],
	])
	var window := SettlementWindow.new(PatternEvaluator.new(registry), zones)

	assert_true(not window.open(), "a Pair is not sufficient to open a Settlement Window", failures)
	assert_true(window.candidates().is_empty(), "Pair candidates are filtered from settlement candidates", failures)

func test_invalid_selection_is_rejected_atomically(failures: Array[String]) -> void:
	var registry = _sequence_registry()
	var zones = _hand_zones([
		["run.tile.invalid.1", "base.tile.characters.1"],
		["run.tile.invalid.2", "base.tile.characters.2"],
		["run.tile.invalid.3", "base.tile.characters.3"],
	])
	var window = _open_window(registry, zones)

	var result = window.resolve(["run.tile.invalid.1", "run.tile.invalid.2", "run.tile.missing"])

	assert_true(result.status == PartialSettlementResult.INVALID_SELECTION, "an unknown TileInstance ID is rejected", failures)
	assert_true(result.events.is_empty(), "an invalid selection emits no event", failures)
	assert_true(zones.size(TileZone.HAND) == 3, "an invalid selection leaves Hand unchanged", failures)
	assert_true(zones.size(TileZone.DISCARD) == 0, "an invalid selection leaves Discard unchanged", failures)

func test_non_id_selection_is_rejected(failures: Array[String]) -> void:
	var registry = _sequence_registry()
	var zones = _hand_zones([
		["run.tile.non_id.1", "base.tile.characters.1"],
		["run.tile.non_id.2", "base.tile.characters.2"],
		["run.tile.non_id.3", "base.tile.characters.3"],
	])
	var window = _open_window(registry, zones)

	var result = window.resolve([TileInstance.new("run.tile.object", "base.tile.characters.1"), "run.tile.non_id.2", "run.tile.non_id.3"])

	assert_true(result.status == PartialSettlementResult.INVALID_SELECTION, "a non-ID selection entry is rejected", failures)
	assert_true(zones.size(TileZone.HAND) == 3, "a non-ID selection leaves Hand unchanged", failures)

func test_mixed_selection_is_rejected(failures: Array[String]) -> void:
	var registry = _sequence_registry()
	var registry_report = registry.register(TileDefinition.new("base.tile.dots.5", "dots", 5))
	assert_true(registry_report.is_valid(), "the mixed-selection fixture registers its tile definition", failures)
	var zones = _hand_zones([
		["run.tile.mixed.1", "base.tile.characters.1"],
		["run.tile.mixed.2", "base.tile.characters.2"],
		["run.tile.mixed.3", "base.tile.characters.3"],
		["run.tile.mixed.5", "base.tile.dots.5"],
	])
	var window = _open_window(registry, zones)

	var result = window.resolve(["run.tile.mixed.1", "run.tile.mixed.2", "run.tile.mixed.5"])

	assert_true(result.status == PartialSettlementResult.INVALID_SELECTION, "TileInstances from different candidates are rejected", failures)
	assert_true(zones.size(TileZone.HAND) == 4, "a mixed selection leaves Hand unchanged", failures)

func test_duplicate_selection_is_rejected(failures: Array[String]) -> void:
	var registry = _sequence_registry()
	var zones = _hand_zones([
		["run.tile.duplicate.1", "base.tile.characters.1"],
		["run.tile.duplicate.2", "base.tile.characters.2"],
		["run.tile.duplicate.3", "base.tile.characters.3"],
	])
	var window = _open_window(registry, zones)

	var result = window.resolve(["run.tile.duplicate.1", "run.tile.duplicate.2", "run.tile.duplicate.2"])

	assert_true(result.status == PartialSettlementResult.DUPLICATE_SELECTION, "duplicate TileInstance IDs are rejected", failures)
	assert_true(zones.size(TileZone.HAND) == 3, "a duplicate selection leaves Hand unchanged", failures)

func test_stale_selection_is_rejected(failures: Array[String]) -> void:
	var registry = _sequence_registry()
	var zones = _hand_zones([
		["run.tile.stale.1", "base.tile.characters.1"],
		["run.tile.stale.2", "base.tile.characters.2"],
		["run.tile.stale.3", "base.tile.characters.3"],
	])
	var window = _open_window(registry, zones)
	zones.transfer("run.tile.stale.1", TileZone.HAND, TileZone.DISCARD)

	var result = window.resolve(["run.tile.stale.1", "run.tile.stale.2", "run.tile.stale.3"])

	assert_true(result.status == PartialSettlementResult.STALE_SELECTION, "a selection containing a no-longer-Hand TileInstance is rejected", failures)
	assert_true(zones.size(TileZone.HAND) == 2, "a stale selection does not mutate remaining Hand tiles", failures)
	assert_true(zones.size(TileZone.DISCARD) == 1, "the pre-existing stale move is preserved", failures)

func test_valid_selection_settles_to_discard(failures: Array[String]) -> void:
	var registry = _sequence_registry()
	var first := TileInstance.new("run.tile.success.1", "base.tile.characters.1")
	var second := TileInstance.new("run.tile.success.2", "base.tile.characters.2")
	var third := TileInstance.new("run.tile.success.3", "base.tile.characters.3")
	var zones := TileZoneContainer.new()
	zones.add(first, TileZone.HAND)
	zones.add(second, TileZone.HAND)
	zones.add(third, TileZone.HAND)
	var window = _open_window(registry, zones)

	var result = window.resolve([third.instance_id, first.instance_id, second.instance_id])

	assert_true(result.is_accepted(), "a current legal Scoring Pattern is accepted", failures)
	assert_true(zones.size(TileZone.HAND) == 0, "settled tiles leave Hand", failures)
	assert_true(zones.size(TileZone.DISCARD) == 3, "settled tiles move to Discard", failures)
	assert_true(zones.contains_in_zone(first.instance_id, TileZone.DISCARD), "the first selected TileInstance is discarded", failures)
	assert_true(zones.contains_in_zone(second.instance_id, TileZone.DISCARD), "the second selected TileInstance is discarded", failures)
	assert_true(zones.contains_in_zone(third.instance_id, TileZone.DISCARD), "the third selected TileInstance is discarded", failures)

func test_settlement_creates_settled_pattern_identity(failures: Array[String]) -> void:
	var registry = _sequence_registry()
	var first := TileInstance.new("run.tile.identity.1", "base.tile.characters.1")
	var second := TileInstance.new("run.tile.identity.2", "base.tile.characters.2")
	var third := TileInstance.new("run.tile.identity.3", "base.tile.characters.3")
	var zones := TileZoneContainer.new()
	for tile_instance in [first, second, third]:
		zones.add(tile_instance, TileZone.HAND)
	var window = _open_window(registry, zones)

	var result = window.resolve([first.instance_id, second.instance_id, third.instance_id])

	assert_true(result.settled_pattern is SettledPattern, "resolution returns a SettledPattern", failures)
	if result.settled_pattern is SettledPattern:
		assert_true(result.settled_pattern.pattern_type == PatternCandidate.SEQUENCE, "the SettledPattern preserves the resolved pattern type", failures)
		assert_true(result.settled_pattern.tile_instances[0] == first, "the SettledPattern preserves TileInstance identity", failures)
		assert_true(result.settled_pattern.tile_instance_ids == [first.instance_id, second.instance_id, third.instance_id], "the SettledPattern exposes stable TileInstance IDs", failures)
		assert_true(result.settled_pattern.definition_ids == [first.definition_id, second.definition_id, third.definition_id], "the SettledPattern exposes definition IDs for later scoring", failures)

func test_triplet_and_quad_are_settleable(failures: Array[String]) -> void:
	var definition_id := "base.tile.bamboo.7"
	var registry = _registry([[definition_id, "bamboo", 7]])
	var zones := TileZoneContainer.new()
	var tiles: Array = []
	for index in range(4):
		var tile_instance := TileInstance.new("run.tile.triplet_quad.%d" % (index + 1), definition_id)
		tiles.append(tile_instance)
		zones.add(tile_instance, TileZone.HAND)
	var window = _open_window(registry, zones)

	var result = window.resolve([tiles[0].instance_id, tiles[1].instance_id, tiles[2].instance_id, tiles[3].instance_id])

	assert_true(result.is_accepted(), "a Quad is a legal Scoring Pattern", failures)
	if result.is_accepted():
		assert_true(result.settled_pattern.pattern_type == PatternCandidate.QUAD, "the four-tile selection resolves as a Quad", failures)
		assert_true(zones.size(TileZone.DISCARD) == 4, "a settled Quad moves all four TileInstances to Discard", failures)

func test_settlement_emits_auditable_event(failures: Array[String]) -> void:
	var registry = _sequence_registry()
	var zones = _hand_zones([
		["run.tile.event.1", "base.tile.characters.1"],
		["run.tile.event.2", "base.tile.characters.2"],
		["run.tile.event.3", "base.tile.characters.3"],
	])
	var window = _open_window(registry, zones)

	var result = window.resolve(["run.tile.event.1", "run.tile.event.2", "run.tile.event.3"])

	assert_true(result.events.size() == 1, "accepted settlement emits one domain event", failures)
	if result.events.size() == 1:
		assert_true(result.events[0].event_type == "PatternSettled", "the settlement event is auditable as PatternSettled", failures)
		assert_true(result.events[0].data["pattern_type"] == PatternCandidate.SEQUENCE, "the event records the settled pattern type", failures)
		assert_true(result.events[0].data["instance_ids"] == ["run.tile.event.1", "run.tile.event.2", "run.tile.event.3"], "the event records every settled TileInstance", failures)
		assert_true(result.events[0].data["definition_ids"] == ["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3"], "the event records every settled tile definition", failures)

func test_settled_tile_cannot_be_reused_in_same_window(failures: Array[String]) -> void:
	var registry = _registry([["base.tile.characters.5", "characters", 5]])
	var zones = _hand_zones([
		["run.tile.reuse.1", "base.tile.characters.5"],
		["run.tile.reuse.2", "base.tile.characters.5"],
		["run.tile.reuse.3", "base.tile.characters.5"],
		["run.tile.reuse.4", "base.tile.characters.5"],
	])
	var window = _open_window(registry, zones)
	var first_result = window.resolve(["run.tile.reuse.1", "run.tile.reuse.2", "run.tile.reuse.3"])
	var reuse_result = window.resolve(["run.tile.reuse.2", "run.tile.reuse.3", "run.tile.reuse.4"])

	assert_true(first_result.is_accepted(), "the first overlapping Triplet settlement is accepted", failures)
	assert_true(reuse_result.status == PartialSettlementResult.TILE_ALREADY_SETTLED, "a TileInstance cannot be reused in the same Settlement Window", failures)
	assert_true(zones.contains_in_zone("run.tile.reuse.4", TileZone.HAND), "the rejected reuse leaves the unselected TileInstance in Hand", failures)
	assert_true(reuse_result.events.is_empty(), "a rejected reuse emits no event", failures)

func _sequence_registry():
	return _registry([
		["base.tile.characters.1", "characters", 1],
		["base.tile.characters.2", "characters", 2],
		["base.tile.characters.3", "characters", 3],
	])

func _registry(definitions: Array):
	var registry := ContentRegistry.new()
	for definition_data in definitions:
		registry.register(TileDefinition.new(definition_data[0], definition_data[1], definition_data[2]))
	return registry

func _hand_zones(tile_data: Array):
	var zones := TileZoneContainer.new()
	for data in tile_data:
		zones.add(TileInstance.new(data[0], data[1]), TileZone.HAND)
	return zones

func _open_window(registry, zones):
	var window := SettlementWindow.new(PatternEvaluator.new(registry), zones)
	assert_true(window.open(), "the fixture opens a Settlement Window", [])
	return window

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
