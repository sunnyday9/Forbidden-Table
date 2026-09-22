class_name BuyShopOfferCommand
extends "res://src/domain/commands/run_command.gd"

var offer_id: String
var entry_id: String

func _init(
	identifier: String,
	selected_offer_id: String,
	selected_entry_id: String = "",
	actor_identifier: String = "",
	target_identifier: String = "",
	preview_command: bool = false,
) -> void:
	super(identifier, actor_identifier, target_identifier, preview_command)
	offer_id = selected_offer_id
	entry_id = selected_entry_id

func command_type() -> String:
	return "BuyShopOffer"

func _payload_dictionary() -> Dictionary:
	return {"entry_id": entry_id, "offer_id": offer_id}

func validate(context) -> RefCounted:
	return context.validate_buy_shop_offer(entry_id, offer_id)

func _execute_authoritatively(context) -> Dictionary:
	return context.execute_buy_shop_offer(entry_id, offer_id)
