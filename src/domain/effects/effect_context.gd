class_name EffectContext
extends RefCounted

var state
var zones
var draw_wall
var reserve_service

func _init(effect_state, effect_zones = null, effect_draw_wall = null, effect_reserve_service = null) -> void:
	state = effect_state
	zones = effect_zones if effect_zones != null else (effect_state.zones if effect_state != null else null)
	draw_wall = effect_draw_wall if effect_draw_wall != null else (effect_state.draw_wall if effect_state != null else null)
	reserve_service = effect_reserve_service

func to_dictionary() -> Dictionary:
	return {
		"has_state": state != null,
		"has_zones": zones != null,
		"has_draw_wall": draw_wall != null,
		"has_reserve_service": reserve_service != null,
	}
