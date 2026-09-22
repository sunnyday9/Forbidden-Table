class_name RunTerminalSummary
extends RefCounted

const ONGOING := "ONGOING"

var outcome: String
var reason: String
var summary_data: Dictionary

func _init(
	initial_outcome: String = ONGOING,
	initial_reason: String = "",
	initial_summary_data: Dictionary = {},
) -> void:
	outcome = initial_outcome
	reason = initial_reason
	summary_data = initial_summary_data.duplicate(true)

func is_terminal() -> bool:
	return outcome != ONGOING

func to_dictionary() -> Dictionary:
	return {
		"outcome": outcome,
		"reason": reason,
		"summary_data": summary_data.duplicate(true),
	}
