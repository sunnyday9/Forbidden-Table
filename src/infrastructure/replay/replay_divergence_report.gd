class_name ReplayDivergenceReport
extends RefCounted

const MATCH := "MATCH"
const DIVERGED := "DIVERGED"

var status: String
var reason: String
var checkpoint_index: int
var command_index: int
var expected
var actual
var terminal_outcome: String

func _init(
	report_status: String,
	report_reason: String = "",
	report_checkpoint_index: int = -1,
	report_command_index: int = -1,
	report_expected = null,
	report_actual = null,
	report_terminal_outcome: String = "",
) -> void:
	status = report_status
	reason = report_reason
	checkpoint_index = report_checkpoint_index
	command_index = report_command_index
	expected = report_expected
	actual = report_actual
	terminal_outcome = report_terminal_outcome

func is_match() -> bool:
	return status == MATCH

func is_diverged() -> bool:
	return status == DIVERGED

func to_dictionary() -> Dictionary:
	return {
		"status": status,
		"reason": reason,
		"checkpoint_index": checkpoint_index,
		"command_index": command_index,
		"expected": expected,
		"actual": actual,
		"terminal_outcome": terminal_outcome,
	}
