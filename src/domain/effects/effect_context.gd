class_name EffectContext
extends RefCounted

var state
var zones
var draw_wall
var draw_resolver
var reserve_service

func _init(effect_state, effect_zones = null, effect_draw_wall = null, effect_reserve_service = null) -> void:
	state = effect_state
	zones = effect_zones if effect_zones != null else (effect_state.zones if effect_state != null else null)
	draw_wall = effect_draw_wall if effect_draw_wall != null else (effect_state.draw_wall if effect_state != null else null)
	reserve_service = effect_reserve_service

func resolve_draw_resolver():
	if draw_resolver == null and draw_wall != null:
		const DrawResolverScript = preload("res://src/domain/tiles/draw_resolver.gd")
		draw_resolver = DrawResolverScript.new(draw_wall, zones, state)
	return draw_resolver

func to_dictionary() -> Dictionary:
	return {
		"has_state": state != null,
		"has_zones": zones != null,
		"has_draw_wall": draw_wall != null,
		"has_draw_resolver": resolve_draw_resolver() != null,
		"has_reserve_service": reserve_service != null,
	}
