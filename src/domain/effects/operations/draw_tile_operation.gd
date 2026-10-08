class_name DrawTileOperation
extends "res://src/domain/effects/effect_operation.gd"

const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")

var source: String

func _init(draw_source: String = DrawSourceScript.EFFECT) -> void:
	super("DrawTile")
	source = draw_source

func validate(context, _targets: Dictionary) -> String:
	if context == null or context.draw_wall == null or not context.draw_wall.is_initialized() or context.resolve_draw_resolver() == null:
		return "DRAW_WALL_NOT_READY"
	return "" if DrawSourceScript.is_valid(source) else "INVALID_SOURCE"

func hand_addition_demand(_context, _targets: Dictionary) -> int:
	return 1

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	var result = context.resolve_draw_resolver().draw(1, source, sequence_index)
	var events: Array = []
	for event in result.events:
		var data: Dictionary = event.data.duplicate(true)
		data["effect_id"] = effect_id
		events.append(_event(event.event_type, data))
	return events

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "source": source}
