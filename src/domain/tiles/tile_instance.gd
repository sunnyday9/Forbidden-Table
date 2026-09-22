class_name TileInstance
extends RefCounted

const DEFAULT_RESERVE_INTEGRITY := 3

var _instance_id: String
var _definition_id: String
var _integrity := -1
var _max_integrity := DEFAULT_RESERVE_INTEGRITY

var instance_id: String:
	get:
		return _instance_id

var definition_id: String:
	get:
		return _definition_id

var integrity: int:
	get:
		return _integrity

var max_integrity: int:
	get:
		return _max_integrity

func _init(stable_instance_id: String, tile_definition_id: String) -> void:
	_instance_id = stable_instance_id
	_definition_id = tile_definition_id

func is_valid() -> bool:
	return not _instance_id.is_empty() and not _definition_id.is_empty()

func integrity_initialized() -> bool:
	return _integrity >= 0

func initialize_integrity(initial_value: int = DEFAULT_RESERVE_INTEGRITY, maximum_value: int = DEFAULT_RESERVE_INTEGRITY) -> bool:
	if integrity_initialized():
		return false
	_max_integrity = maxi(0, maximum_value)
	_integrity = clampi(initial_value, 0, _max_integrity)
	return true

func apply_integrity_loss(amount: int) -> int:
	if not integrity_initialized():
		return -1
	var previous := _integrity
	_integrity = maxi(0, _integrity - maxi(0, amount))
	return previous - _integrity

func repair_integrity(amount: int) -> int:
	if not integrity_initialized():
		return -1
	var previous := _integrity
	_integrity = mini(_max_integrity, _integrity + maxi(0, amount))
	return _integrity - previous

func reset_battle_runtime_integrity() -> void:
	_integrity = -1
	_max_integrity = DEFAULT_RESERVE_INTEGRITY
