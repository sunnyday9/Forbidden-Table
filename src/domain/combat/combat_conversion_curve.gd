class_name CombatConversionCurve
extends RefCounted

var _config: Dictionary

func _init(curve_config: Dictionary = {}) -> void:
	_config = curve_config.duplicate(true)

func resolve(score_share: float, _state: Dictionary = {}) -> int:
	var non_negative_share := maxf(score_share, 0.0)
	var mode := str(_config.get("mode", "linear"))
	var value := 0.0
	match mode:
		"linear":
			value = non_negative_share * float(_config.get("multiplier", 1.0))
			value += float(_config.get("offset", 0.0))
		"square_root":
			value = sqrt(non_negative_share) * float(_config.get("multiplier", 1.0))
			value += float(_config.get("offset", 0.0))
		"diminishing":
			var half_saturation := maxf(float(_config.get("half_saturation", 1.0)), 0.000001)
			value = non_negative_share / (non_negative_share + half_saturation)
			value *= float(_config.get("multiplier", 1.0))
			value += float(_config.get("offset", 0.0))
		_:
			value = non_negative_share * float(_config.get("multiplier", 1.0))

	if _config.has("cap"):
		value = minf(value, float(_config["cap"]))
	return maxi(0, floori(value))

func to_dictionary() -> Dictionary:
	return _config.duplicate(true)
