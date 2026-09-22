class_name SettlementCapacity
extends RefCounted

const DEFAULT_BASELINE := 2

var baseline: int
var modifiers: Array[int]
var _remaining: int

var maximum: int:
	get:
		var total := baseline
		for modifier in modifiers:
			total += modifier
		return maxi(0, total)

var remaining: int:
	get:
		return _remaining

var spent: int:
	get:
		return maximum - _remaining

func _init(capacity_data = DEFAULT_BASELINE) -> void:
	baseline = DEFAULT_BASELINE
	modifiers = []
	if capacity_data is Dictionary:
		baseline = maxi(0, int(capacity_data.get("baseline", DEFAULT_BASELINE)))
		for modifier in capacity_data.get("modifiers", []):
			if modifier is int or modifier is float:
				modifiers.append(int(modifier))
	else:
		baseline = maxi(0, int(capacity_data))
	reset()

func reset() -> void:
	_remaining = maximum

func can_spend() -> bool:
	return _remaining > 0

func consume() -> bool:
	if not can_spend():
		return false
	_remaining -= 1
	return true

func to_dictionary() -> Dictionary:
	return {
		"baseline": baseline,
		"modifiers": modifiers.duplicate(),
		"maximum": maximum,
		"remaining": remaining,
		"spent": spent,
	}
