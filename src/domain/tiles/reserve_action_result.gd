class_name ReserveActionResult
extends RefCounted

const ACCEPTED := "ACCEPTED"
const INVALID_TILE := "INVALID_TILE"
const RESERVE_CAPACITY_REACHED := "RESERVE_CAPACITY_REACHED"
const INVALID_RESERVE_TILE := "INVALID_RESERVE_TILE"
const INVALID_INTEGRITY_LOSS := "INVALID_INTEGRITY_LOSS"
const INTEGRITY_NOT_AVAILABLE := "INTEGRITY_NOT_AVAILABLE"
const TRANSFER_FAILED := "TRANSFER_FAILED"

var status: String
var tile_instance
var secondary_tile_instance
var events: Array

func _init(result_status: String, result_tile = null, result_secondary_tile = null, domain_events: Array = []) -> void:
	status = result_status
	tile_instance = result_tile
	secondary_tile_instance = result_secondary_tile
	events = domain_events.duplicate()

func is_accepted() -> bool:
	return status == ACCEPTED
