class_name PatternCandidate
extends RefCounted

const SEQUENCE := "Sequence"
const TRIPLET := "Triplet"
const QUAD := "Quad"
const PAIR := "Pair"

var pattern_type: String
var _tile_instances: Array

var candidate_id: String:
	get:
		var instance_ids: Array[String] = []
		for tile_instance in _tile_instances:
			instance_ids.append(tile_instance.instance_id)
		instance_ids.sort()
		return "%s:%s" % [pattern_type, ",".join(instance_ids)]

var tile_instances: Array:
	get:
		return _tile_instances.duplicate()

func _init(candidate_pattern_type: String, candidate_tile_instances: Array) -> void:
	pattern_type = candidate_pattern_type
	_tile_instances = candidate_tile_instances.duplicate()
