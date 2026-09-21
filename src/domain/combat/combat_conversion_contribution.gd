class_name CombatConversionContribution
extends RefCounted

var source_id: String
var amount: int
var _tags: Array[String]
var _metadata: Dictionary
var _conversion_modifiers: Dictionary
var damage_score_share: float
var stability_score_share: float

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
	conversion_source_id: String,
	conversion_amount: int,
	conversion_tags: Array,
	conversion_metadata: Dictionary,
	conversion_modifiers_data: Dictionary,
	conversion_damage_score_share: float,
	conversion_stability_score_share: float,
) -> void:
	source_id = conversion_source_id
	amount = conversion_amount
	_tags = []
	for tag in conversion_tags:
		if tag is String:
			_tags.append(tag)
	_metadata = conversion_metadata.duplicate(true)
	_conversion_modifiers = conversion_modifiers_data.duplicate(true)
	damage_score_share = conversion_damage_score_share
	stability_score_share = conversion_stability_score_share

func to_dictionary() -> Dictionary:
	return {
		"source_id": source_id,
		"amount": amount,
		"tags": tags,
		"metadata": metadata,
		"conversion_modifiers": conversion_modifiers,
		"damage_score_share": damage_score_share,
		"stability_score_share": stability_score_share,
	}
