class_name CompleteHandSettlementResult
extends RefCounted

const COMPLETED := "COMPLETED"
const REBUILD_SHORTFALL := "COMPLETED_WITH_REBUILD_SHORTFALL"
const RECOVERY_LOCKED := "RECOVERY_LOCKED"
const INVALID_INTERPRETATION := "INVALID_INTERPRETATION"
const TRANSFER_FAILED := "TRANSFER_FAILED"

var status: String
var interpretation
var score_result
var combat_output
var _settled_instance_ids: Array[String]
var _rebuild_draws: Array
var _events: Array
var recovery_state: Dictionary

var settled_instance_ids: Array[String]:
	get:
		return _settled_instance_ids.duplicate()

var rebuild_draws: Array:
	get:
		return _rebuild_draws.duplicate()

var events: Array:
	get:
		return _events.duplicate()

func _init(
	result_status: String,
	result_interpretation = null,
	result_score = null,
	result_combat_output = null,
	result_settled_instance_ids: Array = [],
	result_rebuild_draws: Array = [],
	result_events: Array = [],
	result_recovery_state: Dictionary = {},
) -> void:
	status = result_status
	interpretation = result_interpretation
	score_result = result_score
	combat_output = result_combat_output
	_settled_instance_ids = result_settled_instance_ids.duplicate()
	_rebuild_draws = result_rebuild_draws.duplicate()
	_events = result_events.duplicate()
	recovery_state = result_recovery_state.duplicate(true)

func is_accepted() -> bool:
	return status == COMPLETED or status == REBUILD_SHORTFALL

func is_rebuild_shortfall() -> bool:
	return status == REBUILD_SHORTFALL

func to_dictionary() -> Dictionary:
	return {
		"status": status,
		"interpretation": interpretation.to_dictionary() if interpretation != null else {},
		"score": score_result.to_dictionary() if score_result != null else {},
		"combat_output": combat_output.to_dictionary() if combat_output != null else {},
		"settled_instance_ids": settled_instance_ids,
		"rebuild_draw_count": rebuild_draws.size(),
		"rebuild_shortfall": _rebuild_shortfall(),
		"event_count": events.size(),
		"recovery": recovery_state.duplicate(true),
	}

func _rebuild_shortfall() -> int:
	var shortfall := 0
	for draw_result in _rebuild_draws:
		shortfall += draw_result.shortfall
	return shortfall
