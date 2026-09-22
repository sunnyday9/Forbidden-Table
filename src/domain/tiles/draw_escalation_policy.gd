class_name DrawEscalationPolicy
extends RefCounted

var fatigue_pressure_by_level: Array[int]
var starvation_pressure_by_count: Array[int]
var reshuffle_sources: Array[String]

func _init(
	fatigue_pressure: Array[int] = [0, 1, 2, 3],
	starvation_pressure: Array[int] = [1, 2, 4, 8],
	allowed_reshuffle_sources: Array[String] = [
		"NORMAL_ACTION",
		"SETTLEMENT_REPLACEMENT",
		"COMPLETE_HAND_REBUILD",
		"TECHNIQUE",
		"EFFECT",
	],
) -> void:
	fatigue_pressure_by_level = fatigue_pressure.duplicate()
	starvation_pressure_by_count = starvation_pressure.duplicate()
	reshuffle_sources = allowed_reshuffle_sources.duplicate()

func can_reshuffle(source: String) -> bool:
	return reshuffle_sources.has(source)

func pressure_for_fatigue(fatigue: int) -> int:
	return _lookup(fatigue_pressure_by_level, fatigue)

func pressure_for_starvation(starvation_count: int) -> int:
	return _lookup(starvation_pressure_by_count, starvation_count - 1)

func to_dictionary() -> Dictionary:
	return {
		"fatigue_pressure_by_level": fatigue_pressure_by_level.duplicate(),
		"starvation_pressure_by_count": starvation_pressure_by_count.duplicate(),
		"reshuffle_sources": reshuffle_sources.duplicate(),
	}

func _lookup(values: Array[int], index: int) -> int:
	if values.is_empty():
		return 0
	return values[clampi(index, 0, values.size() - 1)]
