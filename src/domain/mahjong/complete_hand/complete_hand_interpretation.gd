class_name CompleteHandInterpretation
extends RefCounted

const STANDARD := "Standard"
const SEVEN_PAIRS := "Seven Pairs"

var hand_type: String
var _groups: Array
var _pair
var _tile_instances: Array
var interpretation_id: String

var groups: Array:
	get:
		return _groups.duplicate()

var pair:
	get:
		return _pair

var tile_instances: Array:
	get:
		return _tile_instances.duplicate()

func _init(
	interpretation_hand_type: String,
	interpretation_groups: Array,
	interpretation_pair,
	interpretation_tile_instances: Array,
) -> void:
	hand_type = interpretation_hand_type
	_groups = interpretation_groups.duplicate()
	_pair = interpretation_pair
	_tile_instances = interpretation_tile_instances.duplicate()
	interpretation_id = _make_interpretation_id()

func to_dictionary() -> Dictionary:
	var group_data: Array = []
	for group in _groups:
		group_data.append({
			"pattern_type": group.pattern_type,
			"instance_ids": _instance_ids(group.tile_instances),
		})
	return {
		"interpretation_id": interpretation_id,
		"hand_type": hand_type,
		"groups": group_data,
		"pair_instance_ids": _instance_ids(_pair.tile_instances) if _pair != null else [],
		"tile_instance_ids": _instance_ids(_tile_instances),
	}

func _make_interpretation_id() -> String:
	var group_parts: Array[String] = []
	for group in _groups:
		var group_ids := _instance_ids(group.tile_instances)
		group_ids.sort()
		group_parts.append("%s:%s" % [group.pattern_type, ",".join(group_ids)])
	group_parts.sort()
	var parts: Array[String] = [hand_type]
	parts.append_array(group_parts)
	if _pair != null:
		var pair_ids := _instance_ids(_pair.tile_instances)
		pair_ids.sort()
		parts.append("PAIR:%s" % ",".join(pair_ids))
	return "complete_hand.%s" % "|".join(parts)

func _instance_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile_instance in tiles:
		ids.append(tile_instance.instance_id)
	return ids
