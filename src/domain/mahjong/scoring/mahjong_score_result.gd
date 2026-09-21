class_name MahjongScoreResult
extends RefCounted

var total: int
var _contributions: Array
var _flat_bonuses: Array
var _additive_modifiers: Array
var _multiplicative_modifiers: Array
var pre_cap_value: int
var final_value: int
var _applied_special_rules: Array[String]

var contributions: Array:
	get:
		return _contributions.duplicate()

var breakdown: Array:
	get:
		return contributions

var flat_bonuses: Array:
	get:
		return _flat_bonuses.duplicate()

var additive_modifiers: Array:
	get:
		return _additive_modifiers.duplicate()

var multiplicative_modifiers: Array:
	get:
		return _multiplicative_modifiers.duplicate()

var applied_special_rules: Array[String]:
	get:
		return _applied_special_rules.duplicate()

func _init(
	result_contributions: Array = [],
	result_flat_bonuses: Array = [],
	result_additive_modifiers: Array = [],
	result_multiplicative_modifiers: Array = [],
	result_pre_cap_value: int = 0,
	result_final_value: int = 0,
	result_special_rules: Array = [],
) -> void:
	_contributions = result_contributions.duplicate()
	_flat_bonuses = result_flat_bonuses.duplicate()
	_additive_modifiers = result_additive_modifiers.duplicate()
	_multiplicative_modifiers = result_multiplicative_modifiers.duplicate()
	pre_cap_value = result_pre_cap_value
	final_value = result_final_value
	total = result_final_value
	_applied_special_rules = []
	for rule_id in result_special_rules:
		if rule_id is String:
			_applied_special_rules.append(rule_id)

func to_dictionary() -> Dictionary:
	var contribution_data: Array = []
	for contribution in _contributions:
		contribution_data.append(contribution.to_dictionary())
	return {
		"total": total,
		"contributions": contribution_data,
		"flat_bonuses": _flat_bonuses.duplicate(true),
		"additive_modifiers": _additive_modifiers.duplicate(true),
		"multiplicative_modifiers": _multiplicative_modifiers.duplicate(true),
		"pre_cap_value": pre_cap_value,
		"final_value": final_value,
		"applied_special_rules": applied_special_rules,
	}
