class_name DrawResult
extends RefCounted

const ACCEPTED := "ACCEPTED"
const STARVATION := "STARVATION"
const INSUFFICIENT_TILES := STARVATION
const INVALID_SOURCE := "INVALID_SOURCE"
const DRAW_WALL_NOT_READY := "DRAW_WALL_NOT_READY"
const TRANSFER_FAILED := "TRANSFER_FAILED"
const HAND_CAPACITY_REACHED := "HAND_CAPACITY_REACHED"

var status: String
var requested: int
var drawn: int
var shortfall: int
var tile_instance
var tile_instances: Array
var source: String
var events: Array

func _init(
	result_status: String,
	requested_count: int,
	drawn_count: int,
	shortfall_count: int,
	drawn_tile = null,
	domain_events: Array = [],
	draw_source: String = "",
) -> void:
	status = result_status
	requested = requested_count
	drawn = drawn_count
	shortfall = shortfall_count
	tile_instance = drawn_tile
	tile_instances = [] if drawn_tile == null else [drawn_tile]
	source = draw_source
	events = domain_events.duplicate()

func is_accepted() -> bool:
	return status == ACCEPTED or status == STARVATION

func is_starved() -> bool:
	return status == STARVATION

func to_dictionary() -> Dictionary:
	return {
		"status": status,
		"requested": requested,
		"drawn": drawn,
		"shortfall": shortfall,
		"instance_ids": _tile_ids(),
		"source": source,
		"events": events.map(func(event): return event.to_dictionary()),
	}

func _tile_ids() -> Array[String]:
	var ids: Array[String] = []
	for tile in tile_instances:
		ids.append(tile.instance_id)
	return ids
