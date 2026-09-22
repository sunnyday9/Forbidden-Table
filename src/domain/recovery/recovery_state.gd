class_name RecoveryState
extends RefCounted

var normal_hand_baseline: int
var recovery_baseline: int
var minimum_recovery_turns: int
var turns_elapsed: int
var active: bool

func _init(
	initial_normal_hand_baseline: int = 13,
	initial_recovery_baseline: int = 10,
	initial_minimum_recovery_turns: int = 1,
) -> void:
	normal_hand_baseline = maxi(0, initial_normal_hand_baseline)
	recovery_baseline = clampi(initial_recovery_baseline, 0, normal_hand_baseline)
	minimum_recovery_turns = maxi(1, initial_minimum_recovery_turns)
	turns_elapsed = 0
	active = false

func start() -> void:
	turns_elapsed = 0
	active = true

func is_recovering() -> bool:
	return active

func can_complete_hand() -> bool:
	return not active

func advance_turn(current_hand_size: int) -> bool:
	if not active:
		return false
	turns_elapsed += 1
	if turns_elapsed >= minimum_recovery_turns and current_hand_size >= normal_hand_baseline:
		active = false
		return true
	return false

func to_dictionary() -> Dictionary:
	return {
		"active": active,
		"normal_hand_baseline": normal_hand_baseline,
		"recovery_baseline": recovery_baseline,
		"minimum_recovery_turns": minimum_recovery_turns,
		"turns_elapsed": turns_elapsed,
	}
