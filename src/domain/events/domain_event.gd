class_name DomainEvent
extends RefCounted

const TILE_DRAWN := "TileDrawn"
const TILE_DISCARDED := "TileDiscarded"

var event_type: String
var data: Dictionary

func _init(type: String, event_data: Dictionary = {}) -> void:
	event_type = type
	data = event_data.duplicate(true)
