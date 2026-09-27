class_name PatternEvaluatorTest
extends RefCounted

const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const PatternCandidate = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const PatternEvaluator = preload("res://src/domain/mahjong/pattern/pattern_evaluator.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainer = preload("res://src/domain/tiles/tile_zone_container.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_valid_sequence_returns_original_tile_instances(failures)
	test_valid_triplet_returns_original_tile_instances(failures)
	test_valid_quad_is_distinct_from_triplet(failures)
	test_valid_pair_returns_original_tile_instances(failures)
	test_invalid_sequences_are_not_candidates(failures)
	test_incomplete_identical_groups_are_not_overstated(failures)
	test_overlapping_sequences_return_all_candidates(failures)
	test_four_identical_tiles_return_all_ambiguous_candidates(failures)
	test_evaluation_does_not_mutate_hand_zone_or_tile_instances(failures)
	return failures

func test_valid_sequence_returns_original_tile_instances(failures: Array[String]) -> void:
	var registry = ContentRegistry.new()
	registry.register(TileDefinition.new("base.tile.characters.1", "characters", 1))
	registry.register(TileDefinition.new("base.tile.characters.2", "characters", 2))
	registry.register(TileDefinition.new("base.tile.characters.3", "characters", 3))
	var first = TileInstance.new("run.tile.001", "base.tile.characters.1")
	var second = TileInstance.new("run.tile.002", "base.tile.characters.2")
	var third = TileInstance.new("run.tile.003", "base.tile.characters.3")

	var candidates: Array = PatternEvaluator.new(registry).evaluate([first, second, third])

	assert_true(candidates.size() == 1, "three consecutive suited TileInstances produce one PatternCandidate", failures)
	if candidates.size() == 1:
		assert_true(candidates[0].pattern_type == PatternCandidate.SEQUENCE, "the candidate is a Sequence", failures)
		assert_true(candidates[0].tile_instances[0] == first, "the Sequence preserves the first TileInstance", failures)
		assert_true(candidates[0].tile_instances[1] == second, "the Sequence preserves the second TileInstance", failures)
		assert_true(candidates[0].tile_instances[2] == third, "the Sequence preserves the third TileInstance", failures)

func test_valid_triplet_returns_original_tile_instances(failures: Array[String]) -> void:
	var registry = ContentRegistry.new()
	registry.register(TileDefinition.new("base.tile.dots.7", "dots", 7))
	var first = TileInstance.new("run.tile.triplet.001", "base.tile.dots.7")
	var second = TileInstance.new("run.tile.triplet.002", "base.tile.dots.7")
	var third = TileInstance.new("run.tile.triplet.003", "base.tile.dots.7")

	var candidates: Array = PatternEvaluator.new(registry).evaluate([first, second, third])

	assert_true(_candidate_count(candidates, PatternCandidate.TRIPLET) == 1, "three identical TileInstances produce one Triplet candidate", failures)
	var triplet = _first_candidate(candidates, PatternCandidate.TRIPLET)
	if triplet != null:
		assert_true(triplet.tile_instances[0] == first, "the Triplet preserves the first TileInstance", failures)
		assert_true(triplet.tile_instances[1] == second, "the Triplet preserves the second TileInstance", failures)
		assert_true(triplet.tile_instances[2] == third, "the Triplet preserves the third TileInstance", failures)

func test_valid_quad_is_distinct_from_triplet(failures: Array[String]) -> void:
	var definition_id := "base.tile.bamboo.4"
	var evaluator := PatternEvaluator.new(_registry([
		[definition_id, "bamboo", 4],
	]))
	var tiles := _instances("run.tile.quad", definition_id, 4)
	var candidates: Array = evaluator.evaluate(tiles)

	assert_true(_candidate_count(candidates, PatternCandidate.QUAD) == 1, "four identical TileInstances produce one Quad candidate", failures)
	assert_true(_candidate_count(candidates, PatternCandidate.TRIPLET) == 4, "four identical TileInstances preserve every Triplet interpretation", failures)
	var quad = _first_candidate(candidates, PatternCandidate.QUAD)
	if quad != null:
		assert_true(quad.tile_instances.size() == 4, "a Quad candidate contains four TileInstances", failures)
		assert_true(quad.tile_instances[0] == tiles[0], "the Quad preserves the first TileInstance", failures)
		assert_true(quad.tile_instances[3] == tiles[3], "the Quad preserves the fourth TileInstance", failures)

func test_valid_pair_returns_original_tile_instances(failures: Array[String]) -> void:
	var definition_id := "base.tile.characters.9"
	var evaluator := PatternEvaluator.new(_registry([
		[definition_id, "characters", 9],
	]))
	var tiles := _instances("run.tile.pair", definition_id, 2)
	var candidates: Array = evaluator.evaluate(tiles)

	assert_true(candidates.size() == 1, "two identical TileInstances produce one PatternCandidate", failures)
	if candidates.size() == 1:
		assert_true(candidates[0].pattern_type == PatternCandidate.PAIR, "the candidate is a Pair", failures)
		assert_true(candidates[0].tile_instances[0] == tiles[0], "the Pair preserves the first TileInstance", failures)
		assert_true(candidates[0].tile_instances[1] == tiles[1], "the Pair preserves the second TileInstance", failures)

func test_invalid_sequences_are_not_candidates(failures: Array[String]) -> void:
	var registry = _registry([
		["base.tile.characters.0", "characters", 0],
		["base.tile.characters.1", "characters", 1],
		["base.tile.characters.2", "characters", 2],
		["base.tile.characters.4", "characters", 4],
		["base.tile.bamboo.3", "bamboo", 3],
		["base.tile.honors.east", "honors", 0],
		["base.tile.honors.south", "honors", 0],
		["base.tile.honors.west", "honors", 0],
	])
	var evaluator := PatternEvaluator.new(registry)

	assert_true(
		_candidate_count(evaluator.evaluate([
			TileInstance.new("run.tile.invalid.gap.1", "base.tile.characters.1"),
			TileInstance.new("run.tile.invalid.gap.2", "base.tile.characters.2"),
			TileInstance.new("run.tile.invalid.gap.4", "base.tile.characters.4"),
		]), PatternCandidate.SEQUENCE) == 0,
		"nonconsecutive ranks do not produce a Sequence",
		failures
	)
	assert_true(
		_candidate_count(evaluator.evaluate([
			TileInstance.new("run.tile.invalid.rank.0", "base.tile.characters.0"),
			TileInstance.new("run.tile.invalid.rank.1", "base.tile.characters.1"),
			TileInstance.new("run.tile.invalid.rank.2", "base.tile.characters.2"),
		]), PatternCandidate.SEQUENCE) == 0,
		"out-of-range suited ranks do not produce a Sequence",
		failures
	)
	assert_true(
		_candidate_count(evaluator.evaluate([
			TileInstance.new("run.tile.invalid.suit.1", "base.tile.characters.1"),
			TileInstance.new("run.tile.invalid.suit.2", "base.tile.characters.2"),
			TileInstance.new("run.tile.invalid.suit.3", "base.tile.bamboo.3"),
		]), PatternCandidate.SEQUENCE) == 0,
		"mixed suits do not produce a Sequence",
		failures
	)
	assert_true(
		_candidate_count(evaluator.evaluate([
			TileInstance.new("run.tile.invalid.honor.east", "base.tile.honors.east"),
			TileInstance.new("run.tile.invalid.honor.south", "base.tile.honors.south"),
			TileInstance.new("run.tile.invalid.honor.west", "base.tile.honors.west"),
		]), PatternCandidate.SEQUENCE) == 0,
		"honors do not produce a Sequence",
		failures
	)

func test_incomplete_identical_groups_are_not_overstated(failures: Array[String]) -> void:
	var definition_id := "base.tile.dots.6"
	var evaluator := PatternEvaluator.new(_registry([
		[definition_id, "dots", 6],
	]))
	var three_tiles := _instances("run.tile.three", definition_id, 3)
	var two_tiles := _instances("run.tile.two", definition_id, 2)
	var one_tile := _instances("run.tile.one", definition_id, 1)

	var three_candidates: Array = evaluator.evaluate(three_tiles)
	assert_true(_candidate_count(three_candidates, PatternCandidate.TRIPLET) == 1, "three identical TileInstances produce a Triplet", failures)
	assert_true(_candidate_count(three_candidates, PatternCandidate.QUAD) == 0, "three identical TileInstances do not produce a Quad", failures)
	var two_candidates: Array = evaluator.evaluate(two_tiles)
	assert_true(_candidate_count(two_candidates, PatternCandidate.PAIR) == 1, "two identical TileInstances produce a Pair", failures)
	assert_true(_candidate_count(two_candidates, PatternCandidate.TRIPLET) == 0, "two identical TileInstances do not produce a Triplet", failures)
	var one_candidates: Array = evaluator.evaluate(one_tile)
	assert_true(_candidate_count(one_candidates, PatternCandidate.PAIR) == 0, "a single TileInstance does not produce a Pair", failures)

func test_overlapping_sequences_return_all_candidates(failures: Array[String]) -> void:
	var evaluator := PatternEvaluator.new(_registry([
		["base.tile.characters.1", "characters", 1],
		["base.tile.characters.2", "characters", 2],
		["base.tile.characters.3", "characters", 3],
		["base.tile.characters.4", "characters", 4],
	]))
	var tiles: Array = [
		TileInstance.new("run.tile.overlap.1", "base.tile.characters.1"),
		TileInstance.new("run.tile.overlap.2", "base.tile.characters.2"),
		TileInstance.new("run.tile.overlap.3", "base.tile.characters.3"),
		TileInstance.new("run.tile.overlap.4", "base.tile.characters.4"),
	]
	var candidates: Array = evaluator.evaluate(tiles)

	assert_true(_candidate_count(candidates, PatternCandidate.SEQUENCE) == 2, "overlapping consecutive ranks return both Sequence candidates", failures)
	assert_true(_has_candidate_ids(candidates, PatternCandidate.SEQUENCE, ["run.tile.overlap.1", "run.tile.overlap.2", "run.tile.overlap.3"]), "the lower overlapping Sequence is returned", failures)
	assert_true(_has_candidate_ids(candidates, PatternCandidate.SEQUENCE, ["run.tile.overlap.2", "run.tile.overlap.3", "run.tile.overlap.4"]), "the upper overlapping Sequence is returned", failures)

func test_four_identical_tiles_return_all_ambiguous_candidates(failures: Array[String]) -> void:
	var definition_id := "base.tile.characters.5"
	var evaluator := PatternEvaluator.new(_registry([
		[definition_id, "characters", 5],
	]))
	var tiles := _instances("run.tile.ambiguous", definition_id, 4)
	var candidates: Array = evaluator.evaluate(tiles)

	assert_true(_candidate_count(candidates, PatternCandidate.PAIR) == 6, "four identical TileInstances return every Pair interpretation", failures)
	assert_true(_candidate_count(candidates, PatternCandidate.TRIPLET) == 4, "four identical TileInstances return every Triplet interpretation", failures)
	assert_true(_candidate_count(candidates, PatternCandidate.QUAD) == 1, "four identical TileInstances return the Quad interpretation", failures)
	assert_true(_has_candidate_ids(candidates, PatternCandidate.TRIPLET, [
		"run.tile.ambiguous.001", "run.tile.ambiguous.002", "run.tile.ambiguous.004",
	]), "ambiguous candidates preserve the selected TileInstance identities", failures)
	assert_true(_candidate_signatures(candidates) == [
		"%s:run.tile.ambiguous.001,run.tile.ambiguous.002,run.tile.ambiguous.003" % PatternCandidate.TRIPLET,
		"%s:run.tile.ambiguous.001,run.tile.ambiguous.002,run.tile.ambiguous.004" % PatternCandidate.TRIPLET,
		"%s:run.tile.ambiguous.001,run.tile.ambiguous.003,run.tile.ambiguous.004" % PatternCandidate.TRIPLET,
		"%s:run.tile.ambiguous.002,run.tile.ambiguous.003,run.tile.ambiguous.004" % PatternCandidate.TRIPLET,
		"%s:run.tile.ambiguous.001,run.tile.ambiguous.002,run.tile.ambiguous.003,run.tile.ambiguous.004" % PatternCandidate.QUAD,
		"%s:run.tile.ambiguous.001,run.tile.ambiguous.002" % PatternCandidate.PAIR,
		"%s:run.tile.ambiguous.001,run.tile.ambiguous.003" % PatternCandidate.PAIR,
		"%s:run.tile.ambiguous.001,run.tile.ambiguous.004" % PatternCandidate.PAIR,
		"%s:run.tile.ambiguous.002,run.tile.ambiguous.003" % PatternCandidate.PAIR,
		"%s:run.tile.ambiguous.002,run.tile.ambiguous.004" % PatternCandidate.PAIR,
		"%s:run.tile.ambiguous.003,run.tile.ambiguous.004" % PatternCandidate.PAIR,
	], "ambiguous identical-tile candidates keep their established type and combination order", failures)

func test_evaluation_does_not_mutate_hand_zone_or_tile_instances(failures: Array[String]) -> void:
	var registry = _registry([
		["base.tile.bamboo.1", "bamboo", 1],
		["base.tile.bamboo.2", "bamboo", 2],
		["base.tile.bamboo.3", "bamboo", 3],
	])
	var zones = TileZoneContainer.new()
	var hand: Array = [
		TileInstance.new("run.tile.unchanged.1", "base.tile.bamboo.1"),
		TileInstance.new("run.tile.unchanged.2", "base.tile.bamboo.2"),
		TileInstance.new("run.tile.unchanged.3", "base.tile.bamboo.3"),
	]
	for tile_instance in hand:
		zones.add(tile_instance, TileZone.HAND)
	var hand_ids_before: Array[String] = _tile_ids(zones.contents(TileZone.HAND))
	var definitions_before: Array[String] = _definition_ids(hand)
	var zones_before: Array[String] = _zones_for(zones, hand)

	var candidates: Array = PatternEvaluator.new(registry).evaluate(zones.contents(TileZone.HAND))

	assert_true(candidates.size() == 1, "the public Hand contents can be evaluated", failures)
	assert_true(_tile_ids(zones.contents(TileZone.HAND)) == hand_ids_before, "evaluation does not reorder or remove Hand contents", failures)
	assert_true(_definition_ids(hand) == definitions_before, "evaluation does not mutate TileInstance definition IDs", failures)
	assert_true(_zones_for(zones, hand) == zones_before, "evaluation does not move TileInstances between zones", failures)
	for index in range(hand.size()):
		assert_true(zones.contents(TileZone.HAND)[index] == hand[index], "evaluation preserves TileInstance identity in the Hand", failures)

func _registry(definitions: Array):
	var registry = ContentRegistry.new()
	for definition_data in definitions:
		registry.register(TileDefinition.new(definition_data[0], definition_data[1], definition_data[2]))
	return registry

func _instances(prefix: String, definition_id: String, count: int) -> Array:
	var tiles: Array = []
	for index in range(count):
		tiles.append(TileInstance.new("%s.%03d" % [prefix, index + 1], definition_id))
	return tiles

func _candidate_count(candidates: Array, pattern_type: String) -> int:
	var count := 0
	for candidate in candidates:
		if candidate.pattern_type == pattern_type:
			count += 1
	return count

func _first_candidate(candidates: Array, pattern_type: String):
	for candidate in candidates:
		if candidate.pattern_type == pattern_type:
			return candidate
	return null

func _has_candidate_ids(candidates: Array, pattern_type: String, expected_ids: Array[String]) -> bool:
	for candidate in candidates:
		if candidate.pattern_type == pattern_type and _tile_ids(candidate.tile_instances) == expected_ids:
			return true
	return false

func _candidate_signatures(candidates: Array) -> Array[String]:
	var signatures: Array[String] = []
	for candidate in candidates:
		signatures.append("%s:%s" % [candidate.pattern_type, ",".join(_tile_ids(candidate.tile_instances))])
	return signatures

func _tile_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile_instance in tiles:
		ids.append(tile_instance.instance_id)
	return ids

func _definition_ids(tiles: Array) -> Array[String]:
	var definition_ids: Array[String] = []
	for tile_instance in tiles:
		definition_ids.append(tile_instance.definition_id)
	return definition_ids

func _zones_for(zones, tiles: Array) -> Array[String]:
	var tile_zones: Array[String] = []
	for tile_instance in tiles:
		tile_zones.append(zones.zone_of(tile_instance.instance_id))
	return tile_zones

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
