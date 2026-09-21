class_name CombatConversionResult
extends RefCounted

var score_total: int
var damage: int
var stability: int
var profile_id: String
var damage_score_share: float
var stability_score_share: float
var _contributions: Array
var _profile_data: Dictionary

var contributions: Array:
	get:
		return _contributions.duplicate()

var breakdown: Array:
	get:
		return contributions

var damage_breakdown: Array:
	get:
		return _channel_breakdown("damage_score_share")

var stability_breakdown: Array:
	get:
		return _channel_breakdown("stability_score_share")

var profile_data: Dictionary:
	get:
		return _profile_data.duplicate(true)

func _init(
	result_score_total: int,
	result_damage: int,
	result_stability: int,
	result_profile_id: String,
	result_contributions: Array = [],
	result_damage_score_share: float = 0.0,
	result_stability_score_share: float = 0.0,
	result_profile_data: Dictionary = {},
) -> void:
	score_total = result_score_total
	damage = result_damage
	stability = result_stability
	profile_id = result_profile_id
	damage_score_share = result_damage_score_share
	stability_score_share = result_stability_score_share
	_contributions = result_contributions.duplicate()
	_profile_data = result_profile_data.duplicate(true)

func to_dictionary() -> Dictionary:
	var contribution_data: Array = []
	for contribution in _contributions:
		contribution_data.append(contribution.to_dictionary())
	return {
		"score_total": score_total,
		"damage": damage,
		"stability": stability,
		"profile_id": profile_id,
		"damage_score_share": damage_score_share,
		"stability_score_share": stability_score_share,
		"contributions": contribution_data,
		"breakdown": contribution_data.duplicate(true),
		"damage_breakdown": damage_breakdown,
		"stability_breakdown": stability_breakdown,
		"profile": profile_data,
	}

func _channel_breakdown(share_key: String) -> Array:
	var channel_data: Array = []
	for contribution in _contributions:
		channel_data.append({
			"source_id": contribution.source_id,
			"amount": contribution.amount,
			"tags": contribution.tags,
			"score_share": contribution.get(share_key),
			"metadata": contribution.metadata,
		})
	return channel_data
