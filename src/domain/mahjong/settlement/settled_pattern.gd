class_name SettledPattern
extends RefCounted

var pattern_type: String
var _tile_instances: Array

var tile_instances: Array:
	get:
		return _tile_instances.duplicate()

var tile_instance_ids: Array[String]:
	get:
		var ids: Array[String] = []
		for tile_instance in _tile_instances:
			ids.append(tile_instance.instance_id)
		return ids

var definition_ids: Array[String]:
	get:
		var ids: Array[String] = []
		for tile_instance in _tile_instances:
			ids.append(tile_instance.definition_id)
		return ids

func _init(settled_pattern_type: String, settled_tile_instances: Array) -> void:
	pattern_type = settled_pattern_type
	_tile_instances = settled_tile_instances.duplicate()
