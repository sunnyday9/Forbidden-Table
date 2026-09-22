class_name TileInstance
extends RefCounted

const ContaminationDefinitionScript = preload("res://src/domain/tiles/contamination_definition.gd")
const TileLifetimeScript = preload("res://src/domain/tiles/tile_lifetime.gd")
const TileOriginScript = preload("res://src/domain/tiles/tile_origin.gd")

const DEFAULT_RESERVE_INTEGRITY := 3

var _instance_id: String
var _definition_id: String
var _base_origin: String
var _base_lifetime: String
var _contamination
var _integrity := -1
var _max_integrity := DEFAULT_RESERVE_INTEGRITY

var instance_id: String:
	get:
		return _instance_id

var definition_id: String:
	get:
		return _definition_id

var base_origin: String:
	get:
		return _base_origin

var base_lifetime: String:
	get:
		return _base_lifetime

var origin: String:
	get:
		return _contamination.origin if is_contaminated() else _base_origin

var lifetime: String:
	get:
		return _contamination.lifetime if is_contaminated() else _base_lifetime

var contamination:
	get:
		return _contamination

var contamination_id: String:
	get:
		return _contamination.contamination_id if is_contaminated() else ""

var contamination_effect:
	get:
		return _contamination.configured_effect if is_contaminated() else null

var configured_effect:
	get:
		return contamination_effect

var can_exhaust_contamination: bool:
	get:
		return is_contaminated() and _contamination.can_exhaust

var can_purge_contamination: bool:
	get:
		return is_contaminated() and _contamination.can_purge

var can_exhaust: bool:
	get:
		return can_exhaust_contamination

var can_purge: bool:
	get:
		return can_purge_contamination

var cleanup_policy: String:
	get:
		return _contamination.cleanup_policy if is_contaminated() else ""

var battle_cleanup_policy: String:
	get:
		return cleanup_policy

var integrity: int:
	get:
		return _integrity

var max_integrity: int:
	get:
		return _max_integrity

func _init(
	stable_instance_id: String,
	tile_definition_id: String,
	initial_origin: String = TileOriginScript.RUN_POOL,
	initial_lifetime: String = TileLifetimeScript.RUN,
) -> void:
	_instance_id = stable_instance_id
	_definition_id = tile_definition_id
	_base_origin = initial_origin if TileOriginScript.is_valid(initial_origin) else TileOriginScript.UNKNOWN
	_base_lifetime = initial_lifetime if TileLifetimeScript.is_valid(initial_lifetime) else TileLifetimeScript.UNKNOWN
	_contamination = null

func is_valid() -> bool:
	return not _instance_id.is_empty() and not _definition_id.is_empty()

func is_contaminated() -> bool:
	return _contamination is ContaminationDefinitionScript and _contamination.is_valid()

func apply_contamination(contamination_definition) -> bool:
	var definition = contamination_definition
	if definition is Dictionary:
		definition = ContaminationDefinitionScript.from_dictionary(definition)
	if not definition is ContaminationDefinitionScript or not definition.is_valid() or is_contaminated():
		return false
	_contamination = definition
	return true

func contaminate(contamination_definition) -> bool:
	return apply_contamination(contamination_definition)

func clear_contamination() -> bool:
	if not is_contaminated():
		return false
	_contamination = null
	return true

func remove_contamination() -> bool:
	return clear_contamination()

static func from_dictionary(data: Dictionary):
	if data.is_empty():
		return null
	var tile_script = load("res://src/domain/tiles/tile_instance.gd")
	var tile = tile_script.new(
		str(data.get("instance_id", "")),
		str(data.get("definition_id", "")),
		str(data.get("base_origin", data.get("origin", TileOriginScript.RUN_POOL))),
		str(data.get("base_lifetime", data.get("lifetime", TileLifetimeScript.RUN))),
	)
	var integrity := int(data.get("integrity", -1))
	if integrity >= 0:
		tile.initialize_integrity(integrity, int(data.get("max_integrity", DEFAULT_RESERVE_INTEGRITY)))
	var contamination_data = data.get("contamination", {})
	if contamination_data is Dictionary and not contamination_data.is_empty():
		tile.apply_contamination(ContaminationDefinitionScript.from_dictionary(contamination_data))
	return tile

static func from_checkpoint(data: Dictionary):
	return from_dictionary(data)

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

func to_dictionary() -> Dictionary:
	return {
		"instance_id": _instance_id,
		"definition_id": _definition_id,
		"origin": origin,
		"lifetime": lifetime,
		"base_origin": _base_origin,
		"base_lifetime": _base_lifetime,
		"contamination": _contamination.to_dictionary() if is_contaminated() else {},
		"integrity": _integrity,
		"max_integrity": _max_integrity,
	}
