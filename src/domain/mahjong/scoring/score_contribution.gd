class_name ScoreContribution
extends RefCounted

var source_id: String
var amount: int
var _tags: Array[String]
var _metadata: Dictionary
var _conversion_modifiers: Dictionary

var tags: Array[String]:
	get:
		return _tags.duplicate()

var metadata: Dictionary:
	get:
		return _metadata.duplicate(true)

var conversion_modifiers: Dictionary:
	get:
		return _conversion_modifiers.duplicate(true)

func _init(
	contribution_source_id: String,
	contribution_amount: int,
	contribution_tags: Array = [],
	contribution_metadata: Dictionary = {},
	contribution_conversion_modifiers: Dictionary = {},
) -> void:
	source_id = contribution_source_id
	amount = contribution_amount
	_tags = []
	for tag in contribution_tags:
		if tag is String:
			_tags.append(tag)
	_metadata = contribution_metadata.duplicate(true)
	_conversion_modifiers = contribution_conversion_modifiers.duplicate(true)

func to_dictionary() -> Dictionary:
	return {
		"source_id": source_id,
		"amount": amount,
		"tags": tags,
		"metadata": metadata,
		"conversion_modifiers": conversion_modifiers,
	}
