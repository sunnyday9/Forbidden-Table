class_name RunTilePoolState
extends RefCounted

const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")

var tile_instances: Array[RefCounted]

func _init(initial_tile_instances: Array = []) -> void:
	tile_instances = []
	for tile_instance in initial_tile_instances:
		add_tile_instance(tile_instance)

func add_tile_instance(tile_instance: RefCounted) -> bool:
	if not tile_instance is RunTileInstanceRecordScript or _contains_instance_id(tile_instance.instance_id):
		return false
	tile_instances.append(tile_instance)
	return true

func to_dictionary() -> Dictionary:
	var records_by_id: Dictionary = {}
	for tile_instance in tile_instances:
		records_by_id[tile_instance.instance_id] = tile_instance
	var sorted_ids: Array = records_by_id.keys()
	sorted_ids.sort()
	var serialized_records: Array = []
	for instance_id in sorted_ids:
		serialized_records.append(records_by_id[instance_id].to_dictionary())
	return {"tile_instances": serialized_records}

func _contains_instance_id(instance_id: String) -> bool:
	for tile_instance in tile_instances:
		if tile_instance.instance_id == instance_id:
			return true
	return false
