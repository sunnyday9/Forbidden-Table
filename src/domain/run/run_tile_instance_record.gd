class_name RunTileInstanceRecord
extends RefCounted

var instance_id: String
var definition_id: String
var ownership_scope: String
var lifetime_scope: String

func _init(
	initial_instance_id: String,
	initial_definition_id: String,
	initial_ownership_scope: String,
	initial_lifetime_scope: String,
) -> void:
	instance_id = initial_instance_id
	definition_id = initial_definition_id
	ownership_scope = initial_ownership_scope
	lifetime_scope = initial_lifetime_scope

func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"ownership_scope": ownership_scope,
		"lifetime_scope": lifetime_scope,
	}
