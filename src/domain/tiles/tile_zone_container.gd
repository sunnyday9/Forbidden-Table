class_name TileZoneContainer
extends RefCounted

const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const TileInstanceScript = preload("res://src/domain/tiles/tile_instance.gd")

const MAX_HAND_SIZE := 14

var _contents: Dictionary = {}
var _locations: Dictionary = {}
var reserve_capacity: int

func _init(initial_reserve_capacity: int = 3) -> void:
	reserve_capacity = maxi(0, initial_reserve_capacity)
	clear()

func clear() -> void:
	_contents = {}
	_locations = {}
	for zone in TileZoneScript.all():
		_contents[zone] = []
	_contents[TileZoneScript.PURGED] = []

func add(tile_instance, zone: String) -> bool:
	if tile_instance == null or not (tile_instance is TileInstanceScript) or not tile_instance.is_valid():
		return false
	if not TileZoneScript.is_valid(zone):
		return false
	if _locations.has(tile_instance.instance_id):
		return false
	if zone == TileZoneScript.HAND and _contents[zone].size() >= MAX_HAND_SIZE:
		return false
	if zone == TileZoneScript.RESERVE and _contents[zone].size() >= reserve_capacity:
		return false

	_contents[zone].append(tile_instance)
	_locations[tile_instance.instance_id] = zone
	if zone == TileZoneScript.RESERVE:
		tile_instance.initialize_integrity()
	return true

func transfer(instance_id: String, source_zone: String, target_zone: String) -> bool:
	if not TileZoneScript.is_valid(source_zone) or not TileZoneScript.is_valid(target_zone):
		return false
	if source_zone == target_zone:
		return false
	if not TileZoneScript.is_active(source_zone):
		return false
	if not _locations.has(instance_id) or _locations[instance_id] != source_zone:
		return false
	if target_zone == TileZoneScript.HAND and _contents[target_zone].size() >= MAX_HAND_SIZE:
		return false
	if target_zone == TileZoneScript.RESERVE and _contents[target_zone].size() >= reserve_capacity:
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
	if target_zone == TileZoneScript.RESERVE:
		tile_instance.initialize_integrity()
	return true

func purge(instance_id: String) -> bool:
	if not _locations.has(instance_id):
		return false
	var source_zone: String = _locations[instance_id]
	return TileZoneScript.is_active(source_zone) and transfer(instance_id, source_zone, TileZoneScript.PURGED)

func swap(hand_instance_id: String, reserve_instance_id: String) -> bool:
	if not _locations.has(hand_instance_id) or not _locations.has(reserve_instance_id):
		return false
	if _locations[hand_instance_id] != TileZoneScript.HAND or _locations[reserve_instance_id] != TileZoneScript.RESERVE:
		return false
	if hand_instance_id == reserve_instance_id:
		return false

	var hand_contents: Array = _contents[TileZoneScript.HAND]
	var reserve_contents: Array = _contents[TileZoneScript.RESERVE]
	var hand_index := _find_instance_index(hand_contents, hand_instance_id)
	var reserve_index := _find_instance_index(reserve_contents, reserve_instance_id)
	if hand_index < 0 or reserve_index < 0:
		return false

	var hand_tile = hand_contents[hand_index]
	var reserve_tile = reserve_contents[reserve_index]
	hand_contents[hand_index] = reserve_tile
	reserve_contents[reserve_index] = hand_tile
	_locations[hand_instance_id] = TileZoneScript.RESERVE
	_locations[reserve_instance_id] = TileZoneScript.HAND
	hand_tile.initialize_integrity()
	return true

func set_reserve_capacity(new_capacity: int) -> bool:
	var bounded_capacity := maxi(0, new_capacity)
	if bounded_capacity < _contents[TileZoneScript.RESERVE].size():
		return false
	reserve_capacity = bounded_capacity
	return true

func reorder(zone: String, ordered_instance_ids: Array[String]) -> bool:
	if not TileZoneScript.is_valid(zone):
		return false
	if ordered_instance_ids.size() != _contents[zone].size():
		return false

	var existing_ids := _instance_ids(_contents[zone])
	var requested_ids: Array[String] = ordered_instance_ids.duplicate()
	existing_ids.sort()
	requested_ids.sort()
	if existing_ids != requested_ids:
		return false

	var reordered: Array = []
	for instance_id in ordered_instance_ids:
		reordered.append(_find_instance(_contents[zone], instance_id))
	_contents[zone] = reordered
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

func remaining_hand_capacity() -> int:
	return maxi(0, MAX_HAND_SIZE - size(TileZoneScript.HAND))

func _find_instance_index(zone_contents: Array, instance_id: String) -> int:
	for index in range(zone_contents.size()):
		if zone_contents[index].instance_id == instance_id:
			return index
	return -1

func _find_instance(zone_contents: Array, instance_id: String):
	for tile_instance in zone_contents:
		if tile_instance.instance_id == instance_id:
			return tile_instance
	return null

func _instance_ids(zone_contents: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile_instance in zone_contents:
		ids.append(tile_instance.instance_id)
	return ids
