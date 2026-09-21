class_name TileZoneContainer
extends RefCounted

const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")

var _contents: Dictionary = {}
var _locations: Dictionary = {}

func _init() -> void:
	for zone in TileZoneScript.all():
		_contents[zone] = []

func add(tile_instance, zone: String) -> bool:
	if tile_instance == null or not (tile_instance is TileInstanceScript) or not tile_instance.is_valid():
		return false
	if not TileZoneScript.is_valid(zone):
		return false
	if _locations.has(tile_instance.instance_id):
		return false

	_contents[zone].append(tile_instance)
	_locations[tile_instance.instance_id] = zone
	return true

func transfer(instance_id: String, source_zone: String, target_zone: String) -> bool:
	if not TileZoneScript.is_valid(source_zone) or not TileZoneScript.is_valid(target_zone):
		return false
	if source_zone == target_zone:
		return false
	if not _locations.has(instance_id) or _locations[instance_id] != source_zone:
		return false

	var source_contents: Array = _contents[source_zone]
	var source_index := _find_instance_index(source_contents, instance_id)
	if source_index < 0:
		return false

	var tile_instance = source_contents[source_index]
	if _find_instance_index(_contents[target_zone], instance_id) >= 0:
		return false

	source_contents.remove_at(source_index)
	_contents[target_zone].append(tile_instance)
	_locations[instance_id] = target_zone
	return true

func contents(zone: String) -> Array:
	if not TileZoneScript.is_valid(zone):
		return []
	return _contents[zone].duplicate()

func contains(instance_id: String) -> bool:
	return _locations.has(instance_id)

func contains_in_zone(instance_id: String, zone: String) -> bool:
	return TileZoneScript.is_valid(zone) and _locations.get(instance_id, "") == zone

func zone_of(instance_id: String) -> String:
	return _locations.get(instance_id, "")

func size(zone: String) -> int:
	if not TileZoneScript.is_valid(zone):
		return 0
	return _contents[zone].size()

func _find_instance_index(zone_contents: Array, instance_id: String) -> int:
	for index in range(zone_contents.size()):
		if zone_contents[index].instance_id == instance_id:
			return index
	return -1
