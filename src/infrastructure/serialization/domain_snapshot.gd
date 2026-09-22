class_name DomainSnapshot
extends RefCounted

const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")

var data: Dictionary
var state_hash: String

func _init(snapshot_data: Dictionary = {}) -> void:
	data = snapshot_data.duplicate(true)
	state_hash = DeterministicSerializerScript.hash(data)

func to_dictionary() -> Dictionary:
	return {
		"data": data.duplicate(true),
		"state_hash": state_hash,
	}

func serialize() -> String:
	return DeterministicSerializerScript.serialize(to_dictionary())
