class_name DiscardTileOperation
extends "res://src/domain/effects/operations/move_tile_operation.gd"

func _init(tile_instance_id: String) -> void:
	super(tile_instance_id, TileZoneScript.HAND, TileZoneScript.DISCARD)
	operation_id = "DiscardTile"
