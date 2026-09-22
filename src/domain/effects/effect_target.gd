class_name EffectTarget
extends RefCounted

const SELF := "SELF"
const ENEMY := "ENEMY"
const TILE := "TILE"

var key: String
var kind: String
var identifier: String

func _init(target_key: String, target_kind: String, target_identifier: String = "") -> void:
	key = target_key
	kind = target_kind
	identifier = target_identifier

func resolve(context) -> Dictionary:
	if context == null or context.state == null:
		return {"valid": false, "reason": "NO_STATE"}
	if kind == SELF:
		return {"valid": true, "key": key, "kind": kind, "value": context.state}
	if kind == ENEMY:
		return {"valid": true, "key": key, "kind": kind, "value": context.state}
	if kind == TILE:
		if context.zones == null or identifier.is_empty() or not context.zones.contains(identifier):
			return {"valid": false, "reason": "INVALID_TILE_TARGET", "key": key, "identifier": identifier}
		return {"valid": true, "key": key, "kind": kind, "identifier": identifier}
	return {"valid": false, "reason": "UNKNOWN_TARGET_KIND", "key": key, "kind": kind}

func to_dictionary() -> Dictionary:
	return {"key": key, "kind": kind, "identifier": identifier}
