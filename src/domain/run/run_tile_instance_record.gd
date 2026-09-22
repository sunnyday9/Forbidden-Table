class_name RunTileInstanceRecord
extends RefCounted

const TileOriginScript = preload("res://src/domain/tiles/tile_origin.gd")
const TileLifetimeScript = preload("res://src/domain/tiles/tile_lifetime.gd")

var instance_id: String
var definition_id: String
var ownership_scope: String
var lifetime_scope: String
var origin: String

func _init(
	initial_instance_id: String,
	initial_definition_id: String,
	initial_ownership_scope: String,
	initial_lifetime_scope: String,
	initial_origin: String = TileOriginScript.RUN_POOL,
	initial_lifetime: String = "",
) -> void:
	instance_id = initial_instance_id
	definition_id = initial_definition_id
	ownership_scope = initial_ownership_scope
	lifetime_scope = initial_lifetime_scope
	origin = initial_origin if TileOriginScript.is_valid(initial_origin) else TileOriginScript.UNKNOWN
	if not initial_lifetime.is_empty() and TileLifetimeScript.is_valid(initial_lifetime):
		lifetime_scope = initial_lifetime

func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"ownership_scope": ownership_scope,
		"lifetime_scope": lifetime_scope,
		"origin": origin,
		"lifetime": lifetime_scope,
	}
