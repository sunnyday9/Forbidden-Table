class_name PartialSettlementResult
extends RefCounted

const ACCEPTED := "ACCEPTED"
const WINDOW_CLOSED := "WINDOW_CLOSED"
const INVALID_SELECTION := "INVALID_SELECTION"
const DUPLICATE_SELECTION := "DUPLICATE_SELECTION"
const STALE_SELECTION := "STALE_SELECTION"
const TILE_ALREADY_SETTLED := "TILE_ALREADY_SETTLED"
const TRANSFER_FAILED := "TRANSFER_FAILED"

var status: String
var settled_pattern
var events: Array

func _init(
	result_status: String,
	result_settled_pattern = null,
	domain_events: Array = [],
) -> void:
	status = result_status
	settled_pattern = result_settled_pattern
	events = domain_events.duplicate()

func is_accepted() -> bool:
	return status == ACCEPTED
