class_name ShopState
extends RefCounted

const ShopOfferScript = preload("res://src/domain/run/shop_offer.gd")

var active: bool
var completed: bool
var node_id: String
var entry_id: String
var offers: Array
var base_refresh_allowance: int
var refreshes_remaining: int
var refresh_count: int
var entry_sequence: int
var shop_rng_state: Dictionary
var completed_node_ids: Array[String]

func _init() -> void:
	active = false
	completed = false
	node_id = ""
	entry_id = ""
	offers = []
	base_refresh_allowance = 0
	refreshes_remaining = 0
	refresh_count = 0
	entry_sequence = 0
	shop_rng_state = {}
	completed_node_ids = []

func begin(
	initial_node_id: String,
	initial_entry_id: String,
	initial_offers: Array,
	configured_refresh_allowance: int,
	initial_rng_state: Dictionary,
) -> void:
	active = true
	completed = false
	node_id = initial_node_id
	entry_id = initial_entry_id
	offers = initial_offers.duplicate()
	base_refresh_allowance = maxi(0, configured_refresh_allowance)
	refreshes_remaining = base_refresh_allowance
	refresh_count = 0
	shop_rng_state = initial_rng_state.duplicate(true)
	entry_sequence += 1

func offer_by_id(selected_offer_id: String):
	for offer in offers:
		if offer != null and offer.offer_id == selected_offer_id:
			return offer
	return null

func available_offers() -> Array:
	var available: Array = []
	for offer in offers:
		if offer != null and offer.status == ShopOfferScript.AVAILABLE:
			available.append(offer)
	return available

func mark_completed() -> void:
	active = false
	completed = true
	if not node_id.is_empty() and not completed_node_ids.has(node_id):
		completed_node_ids.append(node_id)

func has_completed_node(selected_node_id: String) -> bool:
	return completed_node_ids.has(selected_node_id)

func to_dictionary() -> Dictionary:
	var serialized_offers: Array = []
	for offer in offers:
		if offer != null and offer.has_method("to_dictionary"):
			serialized_offers.append(offer.to_dictionary())
	return {
		"active": active,
		"completed": completed,
		"node_id": node_id,
		"entry_id": entry_id,
		"offers": serialized_offers,
		"base_refresh_allowance": base_refresh_allowance,
		"refreshes_remaining": refreshes_remaining,
		"refresh_count": refresh_count,
		"entry_sequence": entry_sequence,
		"shop_rng_state": shop_rng_state.duplicate(true),
		"completed_node_ids": completed_node_ids.duplicate(),
	}
