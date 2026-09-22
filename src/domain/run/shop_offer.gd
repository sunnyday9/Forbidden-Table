class_name ShopOffer
extends RefCounted

const RELIC := "RELIC"
const TECHNIQUE := "TECHNIQUE"
const SPECIAL := "SPECIAL"
const AVAILABLE := "AVAILABLE"
const SOLD := "SOLD"

var offer_id: String
var slot_index: int
var kind: String
var content_id: String
var price: int
var status: String
var metadata: Dictionary

func _init(
	initial_offer_id: String,
	initial_slot_index: int,
	initial_kind: String,
	initial_content_id: String,
	initial_price: int,
	initial_metadata: Dictionary = {},
) -> void:
	offer_id = initial_offer_id
	slot_index = initial_slot_index
	kind = initial_kind
	content_id = initial_content_id
	price = maxi(0, initial_price)
	status = AVAILABLE
	metadata = initial_metadata.duplicate(true)

func is_available() -> bool:
	return status == AVAILABLE

func is_sold() -> bool:
	return status == SOLD

func to_dictionary() -> Dictionary:
	return {
		"offer_id": offer_id,
		"slot_index": slot_index,
		"kind": kind,
		"content_id": content_id,
		"price": price,
		"status": status,
		"metadata": metadata.duplicate(true),
	}
