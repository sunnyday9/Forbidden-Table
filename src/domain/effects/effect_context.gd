class_name EffectContext
extends RefCounted

var state
var zones
var draw_wall
var draw_resolver
var reserve_service
var contamination_service

func _init(effect_state, effect_zones = null, effect_draw_wall = null, effect_reserve_service = null, effect_contamination_service = null) -> void:
	state = effect_state
	zones = effect_zones
	draw_wall = effect_draw_wall
	if zones == null and effect_state != null:
		zones = effect_state.get("zones")
	if draw_wall == null and effect_state != null:
		draw_wall = effect_state.get("draw_wall")
	reserve_service = effect_reserve_service
	contamination_service = effect_contamination_service

func resolve_draw_resolver():
	if draw_resolver == null and draw_wall != null:
		const DrawResolverScript = preload("res://src/domain/tiles/draw_resolver.gd")
		draw_resolver = DrawResolverScript.new(draw_wall, zones, state)
	return draw_resolver

func resolve_contamination_service():
	if contamination_service == null and zones != null:
		const ContaminationServiceScript = preload("res://src/domain/tiles/contamination_service.gd")
		contamination_service = ContaminationServiceScript.new(zones, state)
	return contamination_service

func to_dictionary() -> Dictionary:
	return {
		"has_state": state != null,
		"has_zones": zones != null,
		"has_draw_wall": draw_wall != null,
		"has_draw_resolver": resolve_draw_resolver() != null,
		"has_reserve_service": reserve_service != null,
		"has_contamination_service": resolve_contamination_service() != null,
	}
