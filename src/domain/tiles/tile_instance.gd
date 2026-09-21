class_name TileInstance
extends RefCounted

var _instance_id: String
var _definition_id: String

var instance_id: String:
	get:
		return _instance_id

var definition_id: String:
	get:
		return _definition_id

func _init(stable_instance_id: String, tile_definition_id: String) -> void:
	_instance_id = stable_instance_id
	_definition_id = tile_definition_id

func is_valid() -> bool:
	return not _instance_id.is_empty() and not _definition_id.is_empty()
