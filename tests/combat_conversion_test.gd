class_name CombatConversionTest
extends RefCounted

const CombatConversionProfile = preload("res://src/domain/combat/combat_conversion_profile.gd")
const CombatConversionResolver = preload("res://src/domain/combat/combat_conversion_resolver.gd")
const MahjongScoreResult = preload("res://src/domain/mahjong/scoring/mahjong_score_result.gd")
const ScoreContribution = preload("res://src/domain/mahjong/scoring/score_contribution.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_damage_and_stability_are_separate_channels(failures)
	test_repeating_conversion_with_same_state_is_deterministic(failures)
	test_profile_curve_data_changes_each_channel_independently(failures)
	test_conversion_has_no_implicit_variance_or_critical_hit(failures)
	test_result_preserves_breakdown_without_mutating_inputs(failures)
	return failures

func test_damage_and_stability_are_separate_channels(failures: Array[String]) -> void:
	var score := MahjongScoreResult.new([
		ScoreContribution.new("test.score", 10, ["TRIPLET"]),
	], [], [], [], 10, 10, [])
	var profile := CombatConversionProfile.new({
		"id": "test.profile",
		"damage_curve": {"mode": "linear", "multiplier": 2.0},
		"stability_curve": {"mode": "linear", "multiplier": 0.5},
	})

	var resolver = CombatConversionResolver.new()
	var result = resolver.resolve(score, profile, {})

	assert_true(result.damage == 20, "Damage uses its configured curve", failures)
	assert_true(result.stability == 5, "Stability uses its configured curve", failures)
	assert_true(result.damage != result.stability, "Damage and Stability remain separate outputs", failures)

func test_repeating_conversion_with_same_state_is_deterministic(failures: Array[String]) -> void:
	var score = _score_with_contributions()
	var profile := CombatConversionProfile.new({
		"id": "test.deterministic.profile",
		"damage_curve": {"mode": "diminishing", "multiplier": 30.0, "half_saturation": 10.0},
		"stability_curve": {"mode": "square_root", "multiplier": 2.0},
	})
	var state := {"turn": 4, "pressure": 3}
	var resolver = CombatConversionResolver.new()

	var first_result = resolver.resolve(score, profile, state)
	var second_result = resolver.resolve(score, profile, state)

	assert_true(first_result.to_dictionary() == second_result.to_dictionary(), "same score, profile, and state repeat identically", failures)

func test_profile_curve_data_changes_each_channel_independently(failures: Array[String]) -> void:
	var score = _score_with_contributions()
	var prototype_profile := CombatConversionProfile.new({
		"id": "test.prototype.profile",
		"damage_curve": {"mode": "linear", "multiplier": 1.0},
		"stability_curve": {"mode": "linear", "multiplier": 1.0},
	})
	var tuned_profile := CombatConversionProfile.new({
		"id": "test.tuned.profile",
		"damage_curve": {"mode": "linear", "multiplier": 3.0},
		"stability_curve": {"mode": "linear", "multiplier": 0.5},
	})
	var resolver = CombatConversionResolver.new()

	var prototype_result = resolver.resolve(score, prototype_profile, {})
	var tuned_result = resolver.resolve(score, tuned_profile, {})

	assert_true(prototype_result.damage == 18, "prototype Damage follows its profile data", failures)
	assert_true(prototype_result.stability == 18, "prototype Stability follows its profile data", failures)
	assert_true(tuned_result.damage == 54, "tuning Damage changes only the Damage curve", failures)
	assert_true(tuned_result.stability == 9, "tuning Stability changes only the Stability curve", failures)

func test_conversion_has_no_implicit_variance_or_critical_hit(failures: Array[String]) -> void:
	var score = _score_with_contributions()
	var profile := CombatConversionProfile.new({
		"id": "test.no-randomness.profile",
		"damage_curve": {"mode": "linear", "multiplier": 2.0},
		"stability_curve": {"mode": "linear", "multiplier": 0.5},
		"variance": 1.0,
		"critical_chance": 1.0,
	})
	var resolver = CombatConversionResolver.new()

	var result = resolver.resolve(score, profile, {"seed": 987654})

	assert_true(result.damage == 36, "Damage has no implicit variance or critical-hit roll", failures)
	assert_true(result.stability == 9, "Stability has no implicit variance or critical-hit roll", failures)

func test_result_preserves_breakdown_without_mutating_inputs(failures: Array[String]) -> void:
	var score = _score_with_contributions()
	var profile := CombatConversionProfile.new({
		"id": "test.breakdown.profile",
		"damage_curve": {"mode": "linear", "multiplier": 2.0},
		"stability_curve": {"mode": "linear", "multiplier": 0.5},
	})
	var score_before: Dictionary = score.to_dictionary()
	var profile_before: Dictionary = profile.to_dictionary()
	var resolver = CombatConversionResolver.new()

	var result = resolver.resolve(score, profile, {})
	var result_data: Dictionary = result.to_dictionary()

	assert_true(result.score_total == 18, "the result preserves the input Mahjong Score", failures)
	assert_true(result.damage_score_share == 18.0, "the result preserves the Damage score share", failures)
	assert_true(result.stability_score_share == 18.0, "the result preserves the Stability score share", failures)
	assert_true(result.contributions.size() == 2, "the result preserves each ScoreContribution", failures)
	if result.contributions.size() == 2:
		assert_true(result.contributions[0].source_id == "test.score.base", "breakdown preserves the first source ID", failures)
		assert_true(result.contributions[0].tags == ["TRIPLET"], "breakdown preserves contribution tags", failures)
		assert_true(result.contributions[0].damage_score_share == 12.0, "breakdown records the Damage share per contribution", failures)
		assert_true(result.contributions[1].stability_score_share == 6.0, "breakdown records the Stability share per contribution", failures)
	assert_true(result.damage_breakdown.size() == 2, "the result exposes a presentation-ready Damage breakdown", failures)
	assert_true(result.stability_breakdown.size() == 2, "the result exposes a presentation-ready Stability breakdown", failures)
	assert_true(result_data.has("damage_breakdown") and result_data.has("stability_breakdown"), "serialized output includes both channel breakdowns", failures)
	assert_true(score.to_dictionary() == score_before, "conversion does not mutate the Mahjong Score result", failures)
	assert_true(profile.to_dictionary() == profile_before, "conversion does not mutate the conversion profile", failures)

func _score_with_contributions():
	return MahjongScoreResult.new([
		ScoreContribution.new("test.score.base", 12, ["TRIPLET"], {"display_name": "Triplet"}),
		ScoreContribution.new("test.score.bonus", 6, ["BONUS"], {"display_name": "Bonus"}),
	], [], [], [], 18, 18, [])

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
