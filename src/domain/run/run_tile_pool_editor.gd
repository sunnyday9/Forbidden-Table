class_name RunTilePoolEditor
extends RefCounted

const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")

var state

func _init(initial_state) -> void:
	state = initial_state

func bind_state(authoritative_state) -> void:
	state = authoritative_state

func find_instance(instance_id: String):
	for tile_instance in state.tile_pool.tile_instances:
		if tile_instance.instance_id == instance_id:
			return tile_instance
	return null

func instance_index(instance_id: String) -> int:
	for index in range(state.tile_pool.tile_instances.size()):
		if state.tile_pool.tile_instances[index].instance_id == instance_id:
			return index
	return -1

func contains_instance(instance_id: String) -> bool:
	return find_instance(instance_id) != null

func count_definition(definition_id: String, excluded_instance_id: String = "") -> int:
	var count := 0
	for tile_instance in state.tile_pool.tile_instances:
		if tile_instance.instance_id != excluded_instance_id and tile_instance.definition_id == definition_id:
			count += 1
	return count

func add_tile(definition_id: String, ownership_scope: String = "RUN", lifetime_scope: String = "RUN") -> Dictionary:
	var identity := next_instance_identity()
	var tile_instance := RunTileInstanceRecordScript.new(
		identity.instance_id,
		definition_id,
		ownership_scope,
		lifetime_scope,
	)
	if not state.tile_pool.add_tile_instance(tile_instance):
		return {"accepted": false, "status": "TILE_POOL_REJECTED"}
	state.tile_instance_sequence = identity.sequence
	return {"accepted": true, "instance_id": tile_instance.instance_id, "sequence": identity.sequence}

func next_instance_identity() -> Dictionary:
	var sequence: int = state.tile_instance_sequence
	var instance_id := ""
	while instance_id.is_empty() or contains_instance(instance_id):
		sequence += 1
		instance_id = "run.tile.%d" % sequence
	return {"sequence": sequence, "instance_id": instance_id}
