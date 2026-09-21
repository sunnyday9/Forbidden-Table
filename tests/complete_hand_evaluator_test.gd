class_name CompleteHandEvaluatorTest
extends RefCounted

const CompleteHandEvaluator = preload("res://src/domain/mahjong/complete_hand/complete_hand_evaluator.gd")
const CompleteHandInterpretation = preload("res://src/domain/mahjong/complete_hand/complete_hand_interpretation.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const PatternCandidate = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_valid_standard_complete_hand_returns_interpretation(failures)
	test_invalid_standard_hand_is_rejected(failures)
	test_quad_standard_hand_is_structural_not_physical_size_limited(failures)
	test_valid_seven_pairs_returns_interpretation(failures)
	test_invalid_seven_pairs_is_rejected(failures)
	test_four_identical_tiles_count_as_one_seven_pairs_pair(failures)
	test_multiple_complete_hand_interpretations_are_returned(failures)
	test_evaluation_does_not_mutate_public_hand_inputs(failures)
	return failures

func test_valid_standard_complete_hand_returns_interpretation(failures: Array[String]) -> void:
	var evaluator := CompleteHandEvaluator.new(_registry([
		["base.tile.characters.1", "characters", 1],
		["base.tile.characters.2", "characters", 2],
		["base.tile.characters.3", "characters", 3],
		["base.tile.characters.4", "characters", 4],
		["base.tile.characters.5", "characters", 5],
		["base.tile.characters.6", "characters", 6],
		["base.tile.characters.7", "characters", 7],
		["base.tile.characters.8", "characters", 8],
		["base.tile.characters.9", "characters", 9],
		["base.tile.dots.5", "dots", 5],
		["base.tile.dots.6", "dots", 6],
	]))
	var hand: Array = [
		TileInstance.new("run.tile.standard.01", "base.tile.characters.1"),
		TileInstance.new("run.tile.standard.02", "base.tile.characters.2"),
		TileInstance.new("run.tile.standard.03", "base.tile.characters.3"),
		TileInstance.new("run.tile.standard.04", "base.tile.characters.4"),
		TileInstance.new("run.tile.standard.05", "base.tile.characters.5"),
		TileInstance.new("run.tile.standard.06", "base.tile.characters.6"),
		TileInstance.new("run.tile.standard.07", "base.tile.characters.7"),
		TileInstance.new("run.tile.standard.08", "base.tile.characters.8"),
		TileInstance.new("run.tile.standard.09", "base.tile.characters.9"),
		TileInstance.new("run.tile.standard.10", "base.tile.dots.5"),
		TileInstance.new("run.tile.standard.11", "base.tile.dots.5"),
		TileInstance.new("run.tile.standard.12", "base.tile.dots.5"),
		TileInstance.new("run.tile.standard.13", "base.tile.dots.6"),
		TileInstance.new("run.tile.standard.14", "base.tile.dots.6"),
	]

	var interpretations: Array = evaluator.evaluate(hand)

	assert_true(interpretations.size() > 0, "a valid 4 Groups + 1 Pair hand is recognized", failures)
	var standard = _first_type(interpretations, CompleteHandInterpretation.STANDARD)
	assert_true(standard != null, "the valid hand returns a Standard interpretation", failures)
	if standard != null:
		assert_true(standard.groups.size() == 4, "Standard exposes four groups", failures)
		assert_true(standard.pair != null, "Standard exposes one pair", failures)
		assert_true(standard.groups[0].pattern_type == PatternCandidate.SEQUENCE, "the first group is a Sequence", failures)
		assert_true(standard.groups[3].pattern_type == PatternCandidate.QUAD or standard.groups[3].pattern_type == PatternCandidate.TRIPLET, "the fourth group is an identical group", failures)

func test_invalid_standard_hand_is_rejected(failures: Array[String]) -> void:
	var evaluator := CompleteHandEvaluator.new(_registry([
		["base.tile.characters.1", "characters", 1],
		["base.tile.characters.2", "characters", 2],
		["base.tile.characters.3", "characters", 3],
		["base.tile.characters.4", "characters", 4],
		["base.tile.characters.5", "characters", 5],
		["base.tile.characters.6", "characters", 6],
		["base.tile.characters.7", "characters", 7],
		["base.tile.characters.8", "characters", 8],
		["base.tile.characters.9", "characters", 9],
		["base.tile.dots.5", "dots", 5],
		["base.tile.dots.6", "dots", 6],
		["base.tile.honors.east", "honors", 0],
		["base.tile.honors.south", "honors", 0],
	]))
	var hand: Array = []
	hand.append_array(_instances("run.tile.invalid.sequence.1", "base.tile.characters.1", 1))
	hand.append_array(_instances("run.tile.invalid.sequence.2", "base.tile.characters.2", 1))
	hand.append_array(_instances("run.tile.invalid.sequence.3", "base.tile.characters.3", 1))
	hand.append_array(_instances("run.tile.invalid.sequence.4", "base.tile.characters.4", 1))
	hand.append_array(_instances("run.tile.invalid.sequence.5", "base.tile.characters.5", 1))
	hand.append_array(_instances("run.tile.invalid.sequence.6", "base.tile.characters.6", 1))
	hand.append_array(_instances("run.tile.invalid.sequence.7", "base.tile.characters.7", 1))
	hand.append_array(_instances("run.tile.invalid.sequence.8", "base.tile.characters.8", 1))
	hand.append_array(_instances("run.tile.invalid.sequence.9", "base.tile.characters.9", 1))
	hand.append_array(_instances("run.tile.invalid.triplet", "base.tile.dots.5", 3))
	hand.append_array(_instances("run.tile.invalid.single.east", "base.tile.honors.east", 1))
	hand.append_array(_instances("run.tile.invalid.single.south", "base.tile.honors.south", 1))

	assert_true(evaluator.evaluate(hand).is_empty(), "an incomplete final group is not a Standard complete hand", failures)

func test_quad_standard_hand_is_structural_not_physical_size_limited(failures: Array[String]) -> void:
	var evaluator := CompleteHandEvaluator.new(_registry([
		["base.tile.characters.1", "characters", 1],
		["base.tile.characters.2", "characters", 2],
		["base.tile.characters.3", "characters", 3],
		["base.tile.characters.4", "characters", 4],
		["base.tile.characters.5", "characters", 5],
		["base.tile.characters.6", "characters", 6],
		["base.tile.characters.7", "characters", 7],
		["base.tile.characters.8", "characters", 8],
		["base.tile.characters.9", "characters", 9],
		["base.tile.dots.5", "dots", 5],
		["base.tile.honors.east", "honors", 0],
	]))
	var hand: Array = []
	hand.append_array(_instances("run.tile.quad.sequence.1", "base.tile.characters.1", 1))
	hand.append_array(_instances("run.tile.quad.sequence.2", "base.tile.characters.2", 1))
	hand.append_array(_instances("run.tile.quad.sequence.3", "base.tile.characters.3", 1))
	hand.append_array(_instances("run.tile.quad.sequence.4", "base.tile.characters.4", 1))
	hand.append_array(_instances("run.tile.quad.sequence.5", "base.tile.characters.5", 1))
	hand.append_array(_instances("run.tile.quad.sequence.6", "base.tile.characters.6", 1))
	hand.append_array(_instances("run.tile.quad.sequence.7", "base.tile.characters.7", 1))
	hand.append_array(_instances("run.tile.quad.sequence.8", "base.tile.characters.8", 1))
	hand.append_array(_instances("run.tile.quad.sequence.9", "base.tile.characters.9", 1))
	hand.append_array(_instances("run.tile.quad.group", "base.tile.dots.5", 4))
	hand.append_array(_instances("run.tile.quad.pair", "base.tile.honors.east", 2))

	var interpretations: Array = evaluator.evaluate(hand)
	var standard = _first_type(interpretations, CompleteHandInterpretation.STANDARD)
	assert_true(hand.size() == 15, "the Quad hand has more than fourteen physical tiles", failures)
	assert_true(standard != null, "a Quad-containing Standard hand is recognized structurally", failures)
	if standard != null:
		assert_true(_candidate_count(standard.groups, PatternCandidate.QUAD) == 1, "the Standard interpretation contains one Quad group", failures)
		assert_true(standard.pair.tile_instances.size() == 2, "the Quad Standard interpretation retains its Pair", failures)

func test_valid_seven_pairs_returns_interpretation(failures: Array[String]) -> void:
	var definition_rows: Array = []
	var hand: Array = []
	for rank in range(1, 8):
		var definition_id := "base.tile.bamboo.%d" % rank
		definition_rows.append([definition_id, "bamboo", rank])
		hand.append(TileInstance.new("run.tile.seven.%02d.a" % rank, definition_id))
		hand.append(TileInstance.new("run.tile.seven.%02d.b" % rank, definition_id))
	var interpretations: Array = CompleteHandEvaluator.new(_registry(definition_rows)).evaluate(hand)
	var seven_pairs = _first_type(interpretations, CompleteHandInterpretation.SEVEN_PAIRS)

	assert_true(seven_pairs != null, "seven distinct pairs are recognized", failures)
	if seven_pairs != null:
		assert_true(seven_pairs.groups.size() == 7, "Seven Pairs exposes seven pair groups", failures)
		assert_true(seven_pairs.pair == null, "Seven Pairs does not expose a Standard pair", failures)

func test_invalid_seven_pairs_is_rejected(failures: Array[String]) -> void:
	var definition_rows: Array = []
	var hand: Array = []
	for rank in range(1, 8):
		var definition_id := "base.tile.dots.%d" % rank
		definition_rows.append([definition_id, "dots", rank])
		var count := 3 if rank == 7 else 2
		for copy in range(count):
			hand.append(TileInstance.new("run.tile.invalid.seven.%02d.%d" % [rank, copy], definition_id))
	var interpretations: Array = CompleteHandEvaluator.new(_registry(definition_rows)).evaluate(hand)

	assert_true(_first_type(interpretations, CompleteHandInterpretation.SEVEN_PAIRS) == null, "a three-copy definition is not a Seven Pairs pair", failures)

func test_four_identical_tiles_count_as_one_seven_pairs_pair(failures: Array) -> void:
	var definition_rows: Array = []
	var hand: Array = []
	for rank in range(1, 8):
		var definition_id := "base.tile.characters.%d" % rank
		definition_rows.append([definition_id, "characters", rank])
		var count := 4 if rank == 1 else 2
		for copy in range(count):
			hand.append(TileInstance.new("run.tile.quad.seven.%02d.%d" % [rank, copy], definition_id))
	var interpretations: Array = CompleteHandEvaluator.new(_registry(definition_rows)).evaluate(hand)
	var seven_pairs = _first_type(interpretations, CompleteHandInterpretation.SEVEN_PAIRS)

	assert_true(seven_pairs != null, "a four-copy definition can participate as one Seven Pairs pair", failures)
	if seven_pairs != null:
		assert_true(seven_pairs.groups.size() == 7, "four identical tiles do not create an eighth Seven Pairs pair", failures)
		assert_true(seven_pairs.groups[0].tile_instances.size() == 4, "the one four-copy pair retains all four TileInstances", failures)

func test_multiple_complete_hand_interpretations_are_returned(failures: Array[String]) -> void:
	var definition_rows: Array = []
	var hand: Array = []
	for rank in range(1, 8):
		var definition_id := "base.tile.dots.%d" % rank
		definition_rows.append([definition_id, "dots", rank])
		hand.append(TileInstance.new("run.tile.ambiguous.%02d.a" % rank, definition_id))
		hand.append(TileInstance.new("run.tile.ambiguous.%02d.b" % rank, definition_id))
	var interpretations: Array = CompleteHandEvaluator.new(_registry(definition_rows)).evaluate(hand)

	assert_true(_first_type(interpretations, CompleteHandInterpretation.STANDARD) != null, "an ambiguous hand returns its Standard interpretation", failures)
	assert_true(_first_type(interpretations, CompleteHandInterpretation.SEVEN_PAIRS) != null, "an ambiguous hand returns its Seven Pairs interpretation", failures)

func test_evaluation_does_not_mutate_public_hand_inputs(failures: Array[String]) -> void:
	var registry = _registry([
		["base.tile.characters.1", "characters", 1],
		["base.tile.characters.2", "characters", 2],
		["base.tile.characters.3", "characters", 3],
		["base.tile.characters.4", "characters", 4],
		["base.tile.characters.5", "characters", 5],
		["base.tile.characters.6", "characters", 6],
		["base.tile.characters.7", "characters", 7],
		["base.tile.characters.8", "characters", 8],
		["base.tile.characters.9", "characters", 9],
		["base.tile.dots.5", "dots", 5],
	])
	var hand: Array = []
	hand.append_array(_instances("run.tile.unchanged.sequence.1", "base.tile.characters.1", 1))
	hand.append_array(_instances("run.tile.unchanged.sequence.2", "base.tile.characters.2", 1))
	hand.append_array(_instances("run.tile.unchanged.sequence.3", "base.tile.characters.3", 1))
	hand.append_array(_instances("run.tile.unchanged.sequence.4", "base.tile.characters.4", 1))
	hand.append_array(_instances("run.tile.unchanged.sequence.5", "base.tile.characters.5", 1))
	hand.append_array(_instances("run.tile.unchanged.sequence.6", "base.tile.characters.6", 1))
	hand.append_array(_instances("run.tile.unchanged.sequence.7", "base.tile.characters.7", 1))
	hand.append_array(_instances("run.tile.unchanged.sequence.8", "base.tile.characters.8", 1))
	hand.append_array(_instances("run.tile.unchanged.sequence.9", "base.tile.characters.9", 1))
	hand.append_array(_instances("run.tile.unchanged.group", "base.tile.dots.5", 3))
	hand.append_array(_instances("run.tile.unchanged.pair", "base.tile.dots.6", 2))
	var ids_before: Array[String] = _tile_ids(hand)
	var definitions_before: Array[String] = _definition_ids(hand)

	CompleteHandEvaluator.new(registry).evaluate(hand)

	assert_true(_tile_ids(hand) == ids_before, "evaluation preserves input TileInstance order", failures)
	assert_true(_definition_ids(hand) == definitions_before, "evaluation preserves input TileInstance definitions", failures)

func _registry(definitions: Array):
	var registry = ContentRegistry.new()
	for definition_data in definitions:
		registry.register(TileDefinition.new(definition_data[0], definition_data[1], definition_data[2]))
	return registry

func _first_type(interpretations: Array, hand_type: String):
	for interpretation in interpretations:
		if interpretation.hand_type == hand_type:
			return interpretation
	return null

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

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
