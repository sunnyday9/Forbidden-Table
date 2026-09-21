class_name MahjongScoreResolver
extends RefCounted

const SettledPatternScript = preload("res://src/domain/mahjong/settlement/settled_pattern.gd")
const ScoreContributionScript = preload("res://src/domain/mahjong/scoring/score_contribution.gd")
const MahjongScoreResultScript = preload("res://src/domain/mahjong/scoring/mahjong_score_result.gd")

var _pattern_rules: Dictionary

func _init(pattern_rules: Dictionary = {}) -> void:
	_pattern_rules = pattern_rules.duplicate(true)

func resolve(settled_pattern):
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

	var total := 0
	for contribution in contributions:
		total += contribution.amount
	return MahjongScoreResultScript.new(contributions, [], [], [], total, total, [])

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
