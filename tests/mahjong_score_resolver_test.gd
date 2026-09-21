class_name MahjongScoreResolverTest
extends RefCounted

const MahjongScoreResolver = preload("res://src/domain/mahjong/scoring/mahjong_score_resolver.gd")
const PatternCandidate = preload("res://src/domain/mahjong/pattern/pattern_candidate.gd")
const SettledPattern = preload("res://src/domain/mahjong/settlement/settled_pattern.gd")
const TileInstance = preload("res://src/domain/tiles/tile_instance.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_settled_pattern_produces_score_and_breakdown(failures)
	test_rule_contributions_are_ordered_deterministically(failures)
	test_repeating_the_same_settlement_is_deterministic(failures)
	test_changing_explicit_pattern_rules_changes_score(failures)
	test_score_resolution_stays_in_headless_domain_data(failures)
	return failures

func test_settled_pattern_produces_score_and_breakdown(failures: Array[String]) -> void:
	var pattern := SettledPattern.new(PatternCandidate.SEQUENCE, [
		TileInstance.new("run.tile.score.001", "base.tile.characters.1"),
		TileInstance.new("run.tile.score.002", "base.tile.characters.2"),
		TileInstance.new("run.tile.score.003", "base.tile.characters.3"),
	])
	var resolver := MahjongScoreResolver.new({
		PatternCandidate.SEQUENCE: {
			"source_id": "prototype.pattern.sequence",
			"amount": 10,
			"tags": ["SEQUENCE"],
		},
	})

	var result = resolver.resolve(pattern)

	assert_true(result.total == 10, "a settled Sequence produces its configured total", failures)
	assert_true(result.contributions.size() == 1, "the score result preserves one base contribution", failures)
	if result.contributions.size() == 1:
		assert_true(result.contributions[0].source_id == "prototype.pattern.sequence", "the contribution preserves its stable source ID", failures)
		assert_true(result.contributions[0].amount == 10, "the contribution preserves its configured amount", failures)
		assert_true(result.contributions[0].tags == ["SEQUENCE"], "the contribution preserves its stable tags", failures)

func test_rule_contributions_are_ordered_deterministically(failures: Array[String]) -> void:
	var pattern := SettledPattern.new(PatternCandidate.TRIPLET, [
		TileInstance.new("run.tile.score.triplet.001", "base.tile.dots.7"),
		TileInstance.new("run.tile.score.triplet.002", "base.tile.dots.7"),
		TileInstance.new("run.tile.score.triplet.003", "base.tile.dots.7"),
	])
	var instance_ids_before: Array[String] = pattern.tile_instance_ids
	var resolver := MahjongScoreResolver.new({
		PatternCandidate.TRIPLET: {
			"contributions": [
				{
					"source_id": "prototype.pattern.triplet.bonus",
					"amount": 2,
					"tags": ["TRIPLET", "BONUS"],
					"order": 20,
				},
				{
					"source_id": "prototype.pattern.triplet.base",
					"amount": 8,
					"tags": ["TRIPLET"],
					"order": 10,
				},
			],
		},
	})

	var result = resolver.resolve(pattern)

	assert_true(result.total == 10, "multiple configured contributions are summed", failures)
	assert_true(result.contributions.size() == 2, "the result preserves every configured contribution", failures)
	if result.contributions.size() == 2:
		assert_true(result.contributions[0].source_id == "prototype.pattern.triplet.base", "contributions use their configured stable order", failures)
		assert_true(result.contributions[1].source_id == "prototype.pattern.triplet.bonus", "later contributions retain deterministic order", failures)
		assert_true(result.contributions[1].tags == ["TRIPLET", "BONUS"], "ordered contributions preserve their tags", failures)
	assert_true(pattern.tile_instance_ids == instance_ids_before, "score calculation does not mutate the SettledPattern", failures)

func test_repeating_the_same_settlement_is_deterministic(failures: Array[String]) -> void:
	var pattern = _pattern(PatternCandidate.QUAD, "run.tile.score.deterministic", 4)
	var resolver := MahjongScoreResolver.new({
		PatternCandidate.QUAD: {
			"source_id": "prototype.pattern.quad",
			"amount": 40,
			"tags": ["QUAD"],
		},
	})

	var first_result = resolver.resolve(pattern)
	var second_result = resolver.resolve(pattern)

	assert_true(first_result.to_dictionary() == second_result.to_dictionary(), "repeating one settlement produces the same score breakdown", failures)

func test_changing_explicit_pattern_rules_changes_score(failures: Array[String]) -> void:
	var pattern = _pattern(PatternCandidate.TRIPLET, "run.tile.score.data", 3)
	var prototype_rules := {
		PatternCandidate.TRIPLET: {
			"source_id": "prototype.pattern.triplet",
			"amount": 20,
			"tags": ["TRIPLET"],
		},
	}
	var tuned_rules := prototype_rules.duplicate(true)
	tuned_rules[PatternCandidate.TRIPLET]["amount"] = 35

	var prototype_result = MahjongScoreResolver.new(prototype_rules).resolve(pattern)
	var tuned_result = MahjongScoreResolver.new(tuned_rules).resolve(pattern)

	assert_true(prototype_result.total == 20, "the explicit prototype data table controls the initial value", failures)
	assert_true(tuned_result.total == 35, "changing only the explicit data table changes the score", failures)
	assert_true(tuned_result.contributions[0].source_id == prototype_result.contributions[0].source_id, "data tuning preserves the stable source ID", failures)
	assert_true(tuned_result.contributions[0].tags == prototype_result.contributions[0].tags, "data tuning preserves the stable tags", failures)

func test_score_resolution_stays_in_headless_domain_data(failures: Array[String]) -> void:
	var pattern = _pattern(PatternCandidate.SEQUENCE, "run.tile.score.headless", 3)
	var instance_ids_before: Array[String] = pattern.tile_instance_ids
	var definition_ids_before: Array[String] = pattern.definition_ids
	var result = MahjongScoreResolver.new({
		PatternCandidate.SEQUENCE: {
			"source_id": "prototype.pattern.sequence.headless",
			"amount": 10,
			"tags": ["SEQUENCE"],
		},
	}).resolve(pattern)

	assert_true(result is RefCounted, "the score result is headless domain data", failures)
	assert_true(pattern is RefCounted, "the settled Pattern is headless domain data", failures)
	assert_true(pattern.tile_instance_ids == instance_ids_before, "score resolution preserves settled TileInstance IDs", failures)
	assert_true(pattern.definition_ids == definition_ids_before, "score resolution preserves settled definition IDs", failures)

func _pattern(pattern_type: String, prefix: String, tile_count: int):
	var tiles: Array = []
	for index in range(tile_count):
		tiles.append(TileInstance.new("%s.%03d" % [prefix, index + 1], "base.tile.score.%d" % (index + 1)))
	return SettledPattern.new(pattern_type, tiles)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
