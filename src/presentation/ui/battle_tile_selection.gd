class_name BattleTileSelection
extends RefCounted

var _hand_instance_ids: Dictionary = {}
var _reserve_instance_ids: Dictionary = {}
var _selected_instance_ids: Array[String] = []


func reconcile(hand_instance_ids: Array, reserve_instance_ids: Array = []) -> void:
	_hand_instance_ids = _id_set(hand_instance_ids)
	_reserve_instance_ids = _id_set(reserve_instance_ids)
	for instance_id in _hand_instance_ids.keys():
		if _reserve_instance_ids.has(instance_id):
			_hand_instance_ids.erase(instance_id)
			_reserve_instance_ids.erase(instance_id)

	var available_ids: Dictionary = _hand_instance_ids.duplicate()
	for instance_id in _reserve_instance_ids:
		available_ids[instance_id] = true
	var current_selection: Array[String] = []
	for instance_id in _selected_instance_ids:
		if available_ids.has(instance_id):
			current_selection.append(instance_id)
	_selected_instance_ids = current_selection


func toggle(instance_id: String) -> void:
	if instance_id.is_empty() or not _is_available(instance_id):
		return
	var existing_index := _selected_instance_ids.find(instance_id)
	if existing_index >= 0:
		_selected_instance_ids.remove_at(existing_index)
	else:
		_selected_instance_ids.append(instance_id)


func clear() -> void:
	_selected_instance_ids.clear()


func selected_ids() -> Array[String]:
	return _selected_instance_ids.duplicate()


func matching_actions(actions: Array) -> Array[Dictionary]:
	var matching: Array[Dictionary] = []
	if _selected_instance_ids.is_empty():
		return matching

	for action in actions:
		if not action is Dictionary:
			continue
		var kind := str(action.get("kind", ""))
		var matches := false
		match kind:
			"PARTIAL_SETTLEMENT":
				var partial_details: Variant = action.get("details", {})
				if _all_selected_in_hand() and partial_details is Dictionary:
					var candidate_ids := _string_ids(partial_details.get("instance_ids", []))
					matches = _same_instance_set(candidate_ids, _selected_instance_ids) and _all_ids_in_zone(candidate_ids, _hand_instance_ids)
			"COMPLETE_HAND":
				var complete_details: Variant = action.get("details", {})
				if _all_selected_in_hand() and complete_details is Dictionary:
					var complete_hand_ids := _complete_hand_instance_ids(complete_details)
					matches = _same_instance_set(complete_hand_ids, _selected_instance_ids) and _all_ids_in_zone(complete_hand_ids, _hand_instance_ids)
			"RESERVE", "DISCARD":
				if _selected_instance_ids.size() == 1:
					var target_id := str(action.get("target_id", ""))
					matches = not target_id.is_empty() and target_id == _selected_instance_ids[0] and _hand_instance_ids.has(target_id)
			"RESERVE_SWAP":
				matches = _matches_reserve_swap(action)
		if matches:
			matching.append(action.duplicate(true))
	return matching


func _matches_reserve_swap(action: Dictionary) -> bool:
	if _selected_instance_ids.size() != 2:
		return false
	var selected_hand_id := ""
	var selected_reserve_id := ""
	for instance_id in _selected_instance_ids:
		if _hand_instance_ids.has(instance_id):
			if not selected_hand_id.is_empty():
				return false
			selected_hand_id = instance_id
		elif _reserve_instance_ids.has(instance_id):
			if not selected_reserve_id.is_empty():
				return false
			selected_reserve_id = instance_id
		else:
			return false
	return (
		not selected_hand_id.is_empty()
		and not selected_reserve_id.is_empty()
		and str(action.get("hand_instance_id", "")) == selected_hand_id
		and str(action.get("reserve_instance_id", "")) == selected_reserve_id
	)


func _complete_hand_instance_ids(details: Dictionary) -> Array[String]:
	var group_value: Variant = details.get("groups", null)
	var pair_value: Variant = details.get("pair_instance_ids", null)
	if not group_value is Array or group_value.is_empty() or not pair_value is Array:
		return []
	var ids: Array[String] = []
	for group in group_value:
		if not group is Dictionary or not group.get("instance_ids", null) is Array:
			return []
		ids.append_array(_string_ids(group.get("instance_ids", [])))
	ids.append_array(_string_ids(pair_value))
	return ids


func _id_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		if value is String or value is StringName:
			var instance_id := str(value)
			if not instance_id.is_empty():
				result[instance_id] = true
	return result


func _string_ids(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value in values:
		if not value is String and not value is StringName:
			return []
		result.append(str(value))
	return result


func _same_instance_set(first: Array, second: Array) -> bool:
	if first.is_empty() or first.size() != second.size():
		return false
	var first_ids: Dictionary = {}
	for value in first:
		var instance_id := str(value)
		if instance_id.is_empty() or first_ids.has(instance_id):
			return false
		first_ids[instance_id] = true
	for value in second:
		var instance_id := str(value)
		if not first_ids.has(instance_id):
			return false
		first_ids.erase(instance_id)
	return first_ids.is_empty()


func _all_ids_in_zone(instance_ids: Array, zone_ids: Dictionary) -> bool:
	if instance_ids.is_empty():
		return false
	for instance_id in instance_ids:
		if not zone_ids.has(str(instance_id)):
			return false
	return true


func _all_selected_in_hand() -> bool:
	if _selected_instance_ids.is_empty():
		return false
	for instance_id in _selected_instance_ids:
		if not _hand_instance_ids.has(instance_id):
			return false
	return true


func _is_available(instance_id: String) -> bool:
	return _hand_instance_ids.has(instance_id) or _reserve_instance_ids.has(instance_id)
