class_name CombatConversionProfile
extends RefCounted

const DamageCurveScript = preload("res://src/domain/combat/damage_curve.gd")
const StabilityCurveScript = preload("res://src/domain/combat/stability_curve.gd")

var profile_id: String
var _damage_curve
var _stability_curve
var _config: Dictionary

var damage_curve:
	get:
		return _damage_curve

var stability_curve:
	get:
		return _stability_curve

func _init(profile_config: Dictionary = {}) -> void:
	_config = profile_config.duplicate(true)
	profile_id = str(_config.get("id", "combat_conversion.default"))
	_damage_curve = _make_curve(_config.get("damage_curve", {}), DamageCurveScript)
	_stability_curve = _make_curve(_config.get("stability_curve", {}), StabilityCurveScript)

func to_dictionary() -> Dictionary:
	var result := _config.duplicate(true)
	result["id"] = profile_id
	result["damage_curve"] = _damage_curve.to_dictionary()
	result["stability_curve"] = _stability_curve.to_dictionary()
	return result

func damage_score_share(amount: float, tags: Array, conversion_modifiers: Dictionary = {}) -> float:
	return amount * _channel_multiplier("damage", tags, conversion_modifiers)

func stability_score_share(amount: float, tags: Array, conversion_modifiers: Dictionary = {}) -> float:
	return amount * _channel_multiplier("stability", tags, conversion_modifiers)

func _channel_multiplier(channel: String, tags: Array, conversion_modifiers: Dictionary) -> float:
	var multiplier := float(conversion_modifiers.get("%s_multiplier" % channel, 1.0))
	var tag_multipliers = _config.get("%s_tag_multipliers" % channel, _config.get("%s_tag_weights" % channel, {}))
	if not tag_multipliers is Dictionary:
		tag_multipliers = {}
	for tag in tags:
		if tag_multipliers.has(tag):
			multiplier *= float(tag_multipliers[tag])
	return multiplier

func _make_curve(curve_config, curve_script):
	if curve_config is RefCounted:
		return curve_config
	if curve_config is Dictionary:
		return curve_script.new(curve_config)
	return curve_script.new()
