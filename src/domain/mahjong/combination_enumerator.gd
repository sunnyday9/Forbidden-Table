class_name CombinationEnumerator
extends RefCounted

static func combinations(values: Array, required_count: int) -> Array:
	return _combinations_from(values, required_count, 0, [])

static func _combinations_from(values: Array, required_count: int, start_index: int, selected: Array) -> Array:
	if selected.size() == required_count:
		return [selected.duplicate()]

	var combinations: Array = []
	var remaining_count := required_count - selected.size()
	for index in range(start_index, values.size() - remaining_count + 1):
		selected.append(values[index])
		combinations.append_array(_combinations_from(values, required_count, index + 1, selected))
		selected.pop_back()
	return combinations
