class_name DrawTileOperation
extends "res://src/domain/effects/effect_operation.gd"

const DrawSourceScript = preload("res://src/domain/tiles/draw_source.gd")

var source: String

func _init(draw_source: String = DrawSourceScript.EFFECT) -> void:
	super("DrawTile")
	source = draw_source

func validate(context, _targets: Dictionary) -> String:
	if context == null or context.draw_wall == null:
		return "DRAW_WALL_NOT_READY"
	if not context.draw_wall.is_initialized() or context.draw_wall.size() == 0:
		return "INSUFFICIENT_TILES"
	return "" if DrawSourceScript.is_valid(source) else "INVALID_SOURCE"

func apply(context, _targets: Dictionary, sequence_index: int, effect_id: String) -> Array:
	var tile_instance = context.draw_wall.draw_one()
	if tile_instance == null:
		return []
	return [_event("TileDrawn", {"effect_id": effect_id, "instance_id": tile_instance.instance_id, "definition_id": tile_instance.definition_id, "source": source, "sequence_index": sequence_index})]

func to_dictionary() -> Dictionary:
	return {"operation_id": operation_id, "source": source}
