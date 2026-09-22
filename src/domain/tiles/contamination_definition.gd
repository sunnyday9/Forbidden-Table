class_name ContaminationDefinition
extends RefCounted

const ContaminationCleanupPolicyScript = preload("res://src/domain/tiles/contamination_cleanup_policy.gd")
const TileLifetimeScript = preload("res://src/domain/tiles/tile_lifetime.gd")
const TileOriginScript = preload("res://src/domain/tiles/tile_origin.gd")

var contamination_id: String
var configured_effect
var origin: String
var lifetime: String
var can_exhaust: bool
var can_purge: bool
var cleanup_policy: String

var effect_configuration:
	get:
		return configured_effect

var battle_cleanup_policy: String:
	get:
		return cleanup_policy

func _init(
	identifier: String = "",
	effect_configuration = {},
	contamination_origin: String = TileOriginScript.ENEMY,
	contamination_lifetime: String = TileLifetimeScript.BATTLE,
	exhaust_allowed: bool = true,
	purge_allowed: bool = true,
	cleanup: String = ContaminationCleanupPolicyScript.REMOVE_TILE,
) -> void:
	contamination_id = identifier
	configured_effect = _copy_value(effect_configuration)
	origin = contamination_origin
	lifetime = contamination_lifetime
	can_exhaust = exhaust_allowed
	can_purge = purge_allowed
	cleanup_policy = cleanup

func is_valid() -> bool:
	return (
		not contamination_id.is_empty()
		and TileOriginScript.is_valid(origin)
		and TileLifetimeScript.is_valid(lifetime)
		and ContaminationCleanupPolicyScript.is_valid(cleanup_policy)
	)

func is_battle_only() -> bool:
	return TileLifetimeScript.is_battle_only(lifetime)

func to_dictionary() -> Dictionary:
	return {
		"contamination_id": contamination_id,
		"configured_effect": _copy_value(configured_effect),
		"origin": origin,
		"lifetime": lifetime,
		"can_exhaust": can_exhaust,
		"can_purge": can_purge,
		"cleanup_policy": cleanup_policy,
	}

static func from_dictionary(data: Dictionary):
	if data.is_empty():
		return null
	var definition_script = load("res://src/domain/tiles/contamination_definition.gd")
	return definition_script.new(
		str(data.get("contamination_id", data.get("id", ""))),
		data.get("configured_effect", {}),
		str(data.get("origin", TileOriginScript.ENEMY)),
		str(data.get("lifetime", TileLifetimeScript.BATTLE)),
		bool(data.get("can_exhaust", true)),
		bool(data.get("can_purge", true)),
		str(data.get("cleanup_policy", ContaminationCleanupPolicyScript.REMOVE_TILE)),
	)

static func _copy_value(value):
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	if value is Object and value.has_method("to_dictionary"):
		return value.to_dictionary()
	return value
