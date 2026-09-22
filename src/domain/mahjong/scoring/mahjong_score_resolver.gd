class_name MahjongScoreResolver
extends RefCounted

const SettledPatternScript = preload("res://src/domain/mahjong/settlement/settled_pattern.gd")
const CompleteHandInterpretationScript = preload("res://src/domain/mahjong/complete_hand/complete_hand_interpretation.gd")
const ScoreContributionScript = preload("res://src/domain/mahjong/scoring/score_contribution.gd")
const MahjongScoreResultScript = preload("res://src/domain/mahjong/scoring/mahjong_score_result.gd")

var _pattern_rules: Dictionary

func _init(pattern_rules: Dictionary = {}) -> void:
	_pattern_rules = pattern_rules.duplicate(true)

func resolve(settled_pattern, local_yaku_resolver = null, state = {}) -> MahjongScoreResultScript:
	if settled_pattern is CompleteHandInterpretationScript:
		return resolve_complete_hand(settled_pattern, local_yaku_resolver, state)
	var contributions: Array = []
	if settled_pattern is SettledPatternScript:
		var rule = _pattern_rules.get(settled_pattern.pattern_type)
		if rule is Dictionary:
			for contribution_spec in _ordered_contribution_specs(rule):
				var source_id := str(contribution_spec.get("source_id", ""))
				if source_id.is_empty():
					continue
				contributions.append(ScoreContributionScript.new(
					source_id,
					int(contribution_spec.get("amount", 0)),
					contribution_spec.get("tags", []),
					contribution_spec.get("metadata", {}),
					contribution_spec.get("conversion_modifiers", {}),
				))
	if local_yaku_resolver != null:
		var local_yaku_contributions = _hook_contributions(local_yaku_resolver, "resolve_local", settled_pattern, state)
		contributions.append_array(local_yaku_contributions)

	var total := 0
	for contribution in contributions:
		total += contribution.amount
	return MahjongScoreResultScript.new(contributions, [], [], [], total, total, [])

func resolve_complete_hand(interpretation, hand_yaku_resolver = null, state = {}) -> MahjongScoreResultScript:
	if not interpretation is CompleteHandInterpretationScript:
		return MahjongScoreResultScript.new()
	var base_amount := 120 if interpretation.hand_type == CompleteHandInterpretationScript.SEVEN_PAIRS else 100
	var contributions: Array = [ScoreContributionScript.new(
		"complete_hand.%s" % interpretation.hand_type.to_lower().replace(" ", "_"),
		base_amount,
		["COMPLETE_HAND"],
		{"interpretation_id": interpretation.interpretation_id, "hand_type": interpretation.hand_type},
	)]
	if hand_yaku_resolver != null:
		var hand_yaku_contributions = _hook_contributions(hand_yaku_resolver, "resolve_complete", interpretation, state)
		if hand_yaku_contributions.is_empty() and hand_yaku_resolver.has_method("resolve"):
			hand_yaku_contributions = _normalize_contributions(hand_yaku_resolver.resolve(interpretation))
		for contribution in hand_yaku_contributions:
			var normalized = _normalize_contribution(contribution)
			if normalized != null:
				contributions.append(normalized)
	var total := 0
	for contribution in contributions:
		total += contribution.amount
	return MahjongScoreResultScript.new(contributions, [], [], [], total, total, ["COMPLETE_HAND"])

func _hook_contributions(resolver, method_name: String, subject, state) -> Array:
	if not resolver.has_method(method_name):
		return []
	var contributions = resolver.call(method_name, subject, state)
	return _normalize_contributions(contributions)

func _normalize_contributions(contributions) -> Array:
	var normalized: Array = []
	if not contributions is Array:
		return normalized
	for contribution in contributions:
		var normalized_contribution = _normalize_contribution(contribution)
		if normalized_contribution != null:
			normalized.append(normalized_contribution)
	return normalized

func _normalize_contribution(contribution):
	if contribution is ScoreContributionScript:
		return contribution
	if contribution is Dictionary:
		var source_id := str(contribution.get("source_id", ""))
		if source_id.is_empty():
			return null
		return ScoreContributionScript.new(
			source_id,
			int(contribution.get("amount", 0)),
			contribution.get("tags", ["HAND_YAKU"]),
			contribution.get("metadata", {}),
			contribution.get("conversion_modifiers", {}),
		)
	return null

func _ordered_contribution_specs(rule: Dictionary) -> Array:
	var raw_specs: Array = []
	if rule.get("contributions") is Array:
		raw_specs = rule["contributions"].duplicate(true)
	elif rule.has("source_id"):
		raw_specs = [rule.duplicate(true)]

	var indexed_specs: Array = []
	for index in range(raw_specs.size()):
		if raw_specs[index] is Dictionary:
			indexed_specs.append({"spec": raw_specs[index], "index": index})
	indexed_specs.sort_custom(_compare_indexed_specs)

	var ordered_specs: Array = []
	for indexed_spec in indexed_specs:
		ordered_specs.append(indexed_spec["spec"])
	return ordered_specs

func _compare_indexed_specs(first: Dictionary, second: Dictionary) -> bool:
	var first_spec: Dictionary = first["spec"]
	var second_spec: Dictionary = second["spec"]
	var first_order := int(first_spec.get("order", 0))
	var second_order := int(second_spec.get("order", 0))
	if first_order != second_order:
		return first_order < second_order
	var first_source_id := str(first_spec.get("source_id", ""))
	var second_source_id := str(second_spec.get("source_id", ""))
	if first_source_id != second_source_id:
		return first_source_id < second_source_id
	return int(first["index"]) < int(second["index"])
