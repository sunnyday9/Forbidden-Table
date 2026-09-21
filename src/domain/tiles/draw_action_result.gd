class_name DrawActionResult
extends RefCounted

const ACCEPTED := "ACCEPTED"
const INSUFFICIENT_TILES := "INSUFFICIENT_TILES"
const INVALID_SOURCE := "INVALID_SOURCE"
const DRAW_WALL_NOT_READY := "DRAW_WALL_NOT_READY"
const TRANSFER_FAILED := "TRANSFER_FAILED"

var status: String
var requested: int
var drawn: int
var shortfall: int
var tile_instance
var events: Array

func _init(
	result_status: String,
	requested_count: int,
	drawn_count: int,
	shortfall_count: int,
	drawn_tile = null,
	domain_events: Array = []
) -> void:
	status = result_status
	requested = requested_count
	drawn = drawn_count
	shortfall = shortfall_count
	tile_instance = drawn_tile
	events = domain_events.duplicate()

func is_accepted() -> bool:
	return status == ACCEPTED
