class_name DiscardActionResult
extends RefCounted

const ACCEPTED := "ACCEPTED"
const INVALID_TILE := "INVALID_TILE"
const TRANSFER_FAILED := "TRANSFER_FAILED"

var status: String
var tile_instance
var events: Array

func _init(result_status: String, discarded_tile = null, domain_events: Array = []) -> void:
	status = result_status
	tile_instance = discarded_tile
	events = domain_events.duplicate()

func is_accepted() -> bool:
	return status == ACCEPTED
