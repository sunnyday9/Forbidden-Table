class_name ContaminationResult
extends RefCounted

const ACCEPTED := "ACCEPTED"
const INVALID_TILE := "INVALID_TILE"
const INVALID_CONTAMINATION := "INVALID_CONTAMINATION"
const ALREADY_CONTAMINATED := "ALREADY_CONTAMINATED"
const NOT_CONTAMINATED := "NOT_CONTAMINATED"
const CANNOT_EXHAUST := "CANNOT_EXHAUST"
const CANNOT_PURGE := "CANNOT_PURGE"
const INVALID_ZONE := "INVALID_ZONE"
const TRANSFER_FAILED := "TRANSFER_FAILED"

var status: String
var tile_instance
var events: Array
var reason: String

func _init(result_status: String, result_tile = null, domain_events: Array = [], result_reason: String = "") -> void:
	status = result_status
	tile_instance = result_tile
	events = domain_events.duplicate()
	reason = result_reason

func is_accepted() -> bool:
	return status == ACCEPTED

func to_dictionary() -> Dictionary:
	return {
		"status": status,
		"instance_id": tile_instance.instance_id if tile_instance != null else "",
		"reason": reason,
		"events": events.map(func(event): return event.to_dictionary() if event != null and event.has_method("to_dictionary") else event),
	}
