class_name SettlementTurnResult
extends RefCounted

const SETTLEMENT_REJECTED := "SETTLEMENT_REJECTED"
const SETTLEMENT_ALREADY_RESOLVED := "SETTLEMENT_ALREADY_RESOLVED"
const COMPLETED := "COMPLETED"
const DRAW_EXHAUSTED := "DRAW_EXHAUSTED"
const END_TURN := "END_TURN"
const TURN_ENDED := "TURN_ENDED"

var status: String
var settlement_result
var _replacement_draws: Array
var replacement_requested: int
var replacement_drawn: int
var replacement_shortfall: int
var _candidates: Array
var _settled_instance_ids: Array[String]
var combat_output
var stable: bool

var replacement_draws: Array:
	get:
		return _replacement_draws.duplicate()

var candidates: Array:
	get:
		return _candidates.duplicate()

var settled_instance_ids: Array[String]:
	get:
		return _settled_instance_ids.duplicate()

func _init(
	result_status: String,
	result_settlement = null,
	result_replacement_draws: Array = [],
	result_replacement_requested: int = 0,
	result_replacement_drawn: int = 0,
	result_replacement_shortfall: int = 0,
	result_candidates: Array = [],
	result_settled_instance_ids: Array[String] = [],
	result_combat_output = null,
	result_stable: bool = true,
) -> void:
	status = result_status
	settlement_result = result_settlement
	_replacement_draws = result_replacement_draws.duplicate()
	replacement_requested = result_replacement_requested
	replacement_drawn = result_replacement_drawn
	replacement_shortfall = result_replacement_shortfall
	_candidates = result_candidates.duplicate()
	_settled_instance_ids = result_settled_instance_ids.duplicate()
	combat_output = result_combat_output
	stable = result_stable

func is_completed() -> bool:
	return status == COMPLETED

func is_exhausted() -> bool:
	return status == DRAW_EXHAUSTED

func is_stable() -> bool:
	return stable

func to_dictionary() -> Dictionary:
	var combat_output_data = null
	if combat_output != null:
		if combat_output is Dictionary:
			combat_output_data = combat_output.duplicate(true)
		elif combat_output.has_method("to_dictionary"):
			combat_output_data = combat_output.to_dictionary()
	return {
		"status": status,
		"replacement_requested": replacement_requested,
		"replacement_drawn": replacement_drawn,
		"replacement_shortfall": replacement_shortfall,
		"settled_instance_ids": settled_instance_ids,
		"candidate_count": candidates.size(),
		"combat_output": combat_output_data,
		"stable": stable,
	}
