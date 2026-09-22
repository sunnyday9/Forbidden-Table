class_name YakuProgressResult
extends RefCounted

var yaku_id: String
var stage: String
var normalized_score
var _satisfied_conditions: Array[String]
var _missing_conditions: Array[String]
var _blockers: Array[String]
var reserve_potential
var _display_tokens: Array[String]

var satisfied_conditions: Array[String]:
	get:
		return _satisfied_conditions.duplicate()

var missing_conditions: Array[String]:
	get:
		return _missing_conditions.duplicate()

var blockers: Array[String]:
	get:
		return _blockers.duplicate()

var display_tokens: Array[String]:
	get:
		return _display_tokens.duplicate()

func _init(
	result_yaku_id: String,
	result_stage: String,
	result_satisfied_conditions: Array = [],
	result_missing_conditions: Array = [],
	result_blockers: Array = [],
	result_reserve_potential = null,
	result_display_tokens: Array = [],
	result_normalized_score = null,
) -> void:
	yaku_id = result_yaku_id
	stage = result_stage
	_satisfied_conditions = _strings(result_satisfied_conditions)
	_missing_conditions = _strings(result_missing_conditions)
	_blockers = _strings(result_blockers)
	reserve_potential = result_reserve_potential.duplicate(true) if result_reserve_potential is Dictionary else result_reserve_potential
	_display_tokens = _strings(result_display_tokens)
	normalized_score = result_normalized_score

func to_dictionary() -> Dictionary:
	return {
		"yaku_id": yaku_id,
		"stage": stage,
		"normalized_score": normalized_score,
		"satisfied_conditions": satisfied_conditions,
		"missing_conditions": missing_conditions,
		"blockers": blockers,
		"reserve_potential": reserve_potential.duplicate(true) if reserve_potential is Dictionary else reserve_potential,
		"display_tokens": display_tokens,
	}

func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if value is String:
			result.append(value)
	return result
