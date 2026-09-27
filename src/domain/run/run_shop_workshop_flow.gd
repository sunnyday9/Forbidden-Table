class_name RunShopWorkshopFlow
extends RefCounted

const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const CommandValidationScript = preload("res://src/domain/commands/command_validation.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const AlphaContractEffectsScript = preload("res://src/domain/run/alpha_contract_effects.gd")
const RunEconomyScript = preload("res://src/domain/run/run_economy.gd")
const RunModifierEffectResolverScript = preload("res://src/domain/run/run_modifier_effect_resolver.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunTileInstanceRecordScript = preload("res://src/domain/run/run_tile_instance_record.gd")
const ShopOfferScript = preload("res://src/domain/run/shop_offer.gd")
const ShopStateScript = preload("res://src/domain/run/shop_state.gd")
const TileDefinitionScript = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinitionScript = preload("res://src/content/definitions/tile_modifier_definition.gd")
const RelicDefinitionScript = preload("res://src/content/definitions/relic_definition.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const WorkshopStateScript = preload("res://src/domain/run/workshop_state.gd")

const ENTER_SHOP := "ENTER_SHOP"
const BUY_SHOP_OFFER := "BUY_SHOP_OFFER"
const REFRESH_SHOP := "REFRESH_SHOP"
const EXIT_SHOP := "EXIT_SHOP"
const ENTER_WORKSHOP := "ENTER_WORKSHOP"
const USE_WORKSHOP_SERVICE := "USE_WORKSHOP_SERVICE"
const EXIT_WORKSHOP := "EXIT_WORKSHOP"

var state
var content_registry
var rng_streams
var economy
var shop_offer_selector

func _init(initial_state, initial_content_registry, initial_rng_streams, initial_economy, initial_shop_offer_selector) -> void:
	state = initial_state
	content_registry = initial_content_registry
	rng_streams = initial_rng_streams
	economy = initial_economy
	shop_offer_selector = initial_shop_offer_selector

func bind_state(authoritative_state) -> void:
	state = authoritative_state

func validate(command_type: String, arguments: Dictionary = {}) -> RefCounted:
	match command_type:
		ENTER_SHOP:
			return _validate_enter_shop(arguments.get("map_definition"))
		BUY_SHOP_OFFER:
			return _validate_buy_shop_offer(str(arguments.get("entry_id", "")), str(arguments.get("offer_id", "")))
		REFRESH_SHOP:
			return _validate_refresh_shop(str(arguments.get("entry_id", "")))
		EXIT_SHOP:
			return _validate_exit_shop()
		ENTER_WORKSHOP:
			return _validate_enter_workshop(arguments.get("map_definition"))
		USE_WORKSHOP_SERVICE:
			return _validate_use_workshop_service(
				str(arguments.get("service_id", "")),
				str(arguments.get("instance_id", "")),
				str(arguments.get("value_id", "")),
				str(arguments.get("modifier_id", "")),
				bool(arguments.get("replace_existing", false)),
			)
		EXIT_WORKSHOP:
			return _validate_exit_workshop()
	return CommandValidationScript.new(false, "UNKNOWN_SERVICE_COMMAND", "Unsupported Shop or Workshop command.")

func execute(command_type: String, arguments: Dictionary = {}) -> Dictionary:
	match command_type:
		ENTER_SHOP:
			return _execute_enter_shop()
		BUY_SHOP_OFFER:
			return _execute_buy_shop_offer(str(arguments.get("entry_id", "")), str(arguments.get("offer_id", "")))
		REFRESH_SHOP:
			return _execute_refresh_shop(str(arguments.get("entry_id", "")))
		EXIT_SHOP:
			return _execute_exit_shop()
		ENTER_WORKSHOP:
			return _execute_enter_workshop()
		USE_WORKSHOP_SERVICE:
			return _execute_use_workshop_service(
				str(arguments.get("service_id", "")),
				str(arguments.get("instance_id", "")),
				str(arguments.get("value_id", "")),
				str(arguments.get("modifier_id", "")),
				bool(arguments.get("replace_existing", false)),
			)
		EXIT_WORKSHOP:
			return _execute_exit_workshop()
	return {"accepted": false, "status": "UNKNOWN_SERVICE_COMMAND", "message": "Unsupported Shop or Workshop command."}

func workshop_price(service_key: String) -> int:
	return _workshop_price(service_key)

func _invalid_phase(expected_phase: String) -> RefCounted:
	return CommandValidationScript.new(
		false,
		"INVALID_PHASE",
		"The command is only legal during %s." % expected_phase,
		{"expected_phase": expected_phase, "actual_phase": state.phase},
	)

func _run_phase_event(previous_phase: String, next_phase: String):
	return DomainEventScript.new(DomainEventScript.RUN_PHASE_CHANGED, {
		"run_id": state.run_id,
		"from_phase": previous_phase,
		"to_phase": next_phase,
	})

func _validate_enter_shop(map_definition) -> RefCounted:
	var phase_validation := _validate_service_entry_phase(RunPhaseScript.SHOP)
	if not phase_validation.is_valid():
		return phase_validation
	var node_id: String = state.map_state.current_node_id
	var node = map_definition.node_definition(node_id)
	if node == null or node.node_kind != "SHOP":
		return CommandValidationScript.new(false, "INVALID_SERVICE_NODE", "Shop entry requires the current Map Node to be a Shop.")
	if state.shop_state.active:
		return CommandValidationScript.new(false, "SERVICE_ALREADY_ACTIVE", "The Shop is already active.")
	if state.shop_state.has_completed_node(node_id):
		return CommandValidationScript.new(false, "SERVICE_COMPLETED", "This Shop node has already been completed.")
	return CommandValidationScript.new(true)

func _execute_enter_shop() -> Dictionary:
	var node_id: String = state.map_state.current_node_id
	var entry_id := "shop.%s.%d" % [state.run_id, state.shop_state.entry_sequence + 1]
	var slots: Array = []
	for slot_index in range(economy.shop_offer_count):
		slots.append(slot_index)
	var shop_rng_before: Dictionary = rng_streams.shop.snapshot()
	var offers: Array = shop_offer_selector.create_offers(
		state,
		content_registry,
		rng_streams.shop,
		entry_id,
		0,
		slots,
		{},
		economy,
	)
	if offers.size() != slots.size():
		rng_streams.shop.restore(shop_rng_before)
		return {"accepted": false, "status": "SHOP_OFFERS_UNAVAILABLE", "message": "The Shop could not create its configured offers."}
	state.shop_state.begin(node_id, entry_id, offers, economy.shop_base_refresh_allowance, rng_streams.shop.snapshot())
	var previous_phase: String = state.phase
	state.phase = RunPhaseScript.SHOP
	var events: Array = [
		DomainEventScript.new(DomainEventScript.SHOP_ENTERED, {
			"run_id": state.run_id,
			"node_id": node_id,
			"entry_id": entry_id,
			"offers": _serialized_shop_offers(),
		}),
		_run_phase_event(previous_phase, state.phase),
	]
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": {
			"node_id": node_id,
			"entry_id": entry_id,
			"offers": _serialized_shop_offers(),
			"phase": state.phase,
		},
	}

func _validate_buy_shop_offer(selected_entry_id: String, selected_offer_id: String) -> RefCounted:
	if state.phase != RunPhaseScript.SHOP or not state.shop_state.active:
		return _invalid_phase(RunPhaseScript.SHOP)
	if not selected_entry_id.is_empty() and selected_entry_id != state.shop_state.entry_id:
		return CommandValidationScript.new(false, "INVALID_SHOP_ENTRY", "The selected Shop entry is not active.")
	var offer = state.shop_state.offer_by_id(selected_offer_id)
	if offer == null:
		return CommandValidationScript.new(false, "INVALID_SHOP_OFFER", "The selected Shop offer is not active.")
	if offer.status != ShopOfferScript.AVAILABLE:
		return CommandValidationScript.new(false, "OFFER_SOLD", "The selected Shop offer is already SOLD.")
	if state.gold < offer.price:
		return CommandValidationScript.new(false, "INSUFFICIENT_GOLD", "The run does not have enough Gold for this Shop offer.")
	if offer.kind == ShopOfferScript.RELIC:
		if not content_registry.resolve(offer.content_id) is RelicDefinitionScript:
			return CommandValidationScript.new(false, "INVALID_SHOP_CONTENT", "The Shop Relic content ID is not registered.")
		if state.build_ownership.owned_relic_ids.has(offer.content_id):
			return CommandValidationScript.new(false, "OFFER_ALREADY_OWNED", "The run already owns this Relic.")
	elif offer.kind == ShopOfferScript.TECHNIQUE:
		var technique = content_registry.resolve(offer.content_id)
		if not technique is TechniqueDefinitionScript or technique.technique_kind == TechniqueDefinitionScript.CORE:
			return CommandValidationScript.new(false, "INVALID_SHOP_CONTENT", "The Shop Technique content ID is not an obtainable Run Technique.")
		if state.build_ownership.run_technique_ids.has(offer.content_id):
			return CommandValidationScript.new(false, "OFFER_ALREADY_OWNED", "The run already owns this Run Technique.")
	elif offer.kind == ShopOfferScript.SPECIAL:
		if state.build_ownership.owned_special_offer_ids.has(offer.content_id):
			return CommandValidationScript.new(false, "OFFER_ALREADY_OWNED", "The run already owns this special offer.")
	else:
		return CommandValidationScript.new(false, "INVALID_SHOP_OFFER", "The Shop offer has an unsupported kind.")
	return CommandValidationScript.new(true, CommandValidationScript.VALID, "", {"offer_id": selected_offer_id})

func _execute_buy_shop_offer(selected_entry_id: String, selected_offer_id: String) -> Dictionary:
	var offer = state.shop_state.offer_by_id(selected_offer_id)
	var transaction: Dictionary = economy.apply_sink(state, RunEconomyScript.GOLD, offer.price, RunEconomyScript.SINK_SHOP_PURCHASE)
	if transaction.is_empty():
		return {"accepted": false, "status": "INSUFFICIENT_GOLD", "message": "The run does not have enough Gold for this Shop offer."}
	offer.status = ShopOfferScript.SOLD
	if offer.kind == ShopOfferScript.RELIC:
		state.build_ownership.owned_relic_ids.append(offer.content_id)
	elif offer.kind == ShopOfferScript.TECHNIQUE:
		state.build_ownership.run_technique_ids.append(offer.content_id)
	else:
		state.build_ownership.owned_special_offer_ids.append(offer.content_id)
	var events: Array = []
	_events_for_currency_transaction(events, transaction)
	var special_transaction := _apply_shop_special_offer(offer)
	if not special_transaction.is_empty():
		_events_for_currency_transaction(events, special_transaction)
	var data: Dictionary = {
		"entry_id": state.shop_state.entry_id if selected_entry_id.is_empty() else selected_entry_id,
		"offer": offer.to_dictionary(),
		"currency_transactions": [transaction],
		"phase": state.phase,
	}
	if not special_transaction.is_empty():
		data["currency_transactions"].append(special_transaction)
	events.append(DomainEventScript.new(DomainEventScript.SHOP_OFFER_PURCHASED, data.duplicate(true)))
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": data,
	}

func _validate_refresh_shop(selected_entry_id: String) -> RefCounted:
	if state.phase != RunPhaseScript.SHOP or not state.shop_state.active:
		return _invalid_phase(RunPhaseScript.SHOP)
	if not selected_entry_id.is_empty() and selected_entry_id != state.shop_state.entry_id:
		return CommandValidationScript.new(false, "INVALID_SHOP_ENTRY", "The selected Shop entry is not active.")
	if state.shop_state.refreshes_remaining <= 0:
		return CommandValidationScript.new(false, "NO_REFRESHES_REMAINING", "The Shop has no refresh allowance remaining.")
	if state.shop_state.available_offers().is_empty():
		return CommandValidationScript.new(false, "NO_ELIGIBLE_OFFERS", "All Shop slots are SOLD and cannot be refreshed.")
	return CommandValidationScript.new(true)

func _execute_refresh_shop(selected_entry_id: String) -> Dictionary:
	var shop_rng_before: Dictionary = rng_streams.shop.snapshot()
	var sold_content_ids: Dictionary = {}
	var available_slots: Array = []
	for offer in state.shop_state.offers:
		if offer.status == ShopOfferScript.SOLD:
			sold_content_ids[offer.content_id] = true
		else:
			available_slots.append(offer.slot_index)
	var next_generation: int = state.shop_state.refresh_count + 1
	var refreshed: Array = shop_offer_selector.create_offers(
		state,
		content_registry,
		rng_streams.shop,
		state.shop_state.entry_id,
		next_generation,
		available_slots,
		sold_content_ids,
		economy,
	)
	if refreshed.size() != available_slots.size():
		rng_streams.shop.restore(shop_rng_before)
		return {"accepted": false, "status": "SHOP_OFFERS_UNAVAILABLE", "message": "The Shop could not refresh every eligible offer."}
	var refreshed_by_slot: Dictionary = {}
	for offer in refreshed:
		refreshed_by_slot[offer.slot_index] = offer
	var next_offers: Array = []
	for offer in state.shop_state.offers:
		if offer.status == ShopOfferScript.SOLD:
			next_offers.append(offer)
		else:
			next_offers.append(refreshed_by_slot[offer.slot_index])
	state.shop_state.offers = next_offers
	state.shop_state.refresh_count = next_generation
	state.shop_state.refreshes_remaining -= 1
	state.shop_state.shop_rng_state = rng_streams.shop.snapshot()
	var event := DomainEventScript.new(DomainEventScript.SHOP_REFRESHED, {
		"run_id": state.run_id,
		"entry_id": state.shop_state.entry_id,
		"refresh_count": state.shop_state.refresh_count,
		"refreshes_remaining": state.shop_state.refreshes_remaining,
		"offers": _serialized_shop_offers(),
	})
	state.map_state.last_events = [event]
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": [event],
		"data": {
			"entry_id": state.shop_state.entry_id if selected_entry_id.is_empty() else selected_entry_id,
			"offers": _serialized_shop_offers(),
			"refreshes_remaining": state.shop_state.refreshes_remaining,
			"phase": state.phase,
		},
	}

func _validate_exit_shop() -> RefCounted:
	if state.phase != RunPhaseScript.SHOP or not state.shop_state.active:
		return _invalid_phase(RunPhaseScript.SHOP)
	return CommandValidationScript.new(true)

func _execute_exit_shop() -> Dictionary:
	state.shop_state.mark_completed()
	var previous_phase: String = state.phase
	state.phase = RunPhaseScript.MAP_CHOICE
	var events: Array = [
		DomainEventScript.new(DomainEventScript.SHOP_EXITED, {
			"run_id": state.run_id,
			"entry_id": state.shop_state.entry_id,
			"node_id": state.shop_state.node_id,
		}),
		_run_phase_event(previous_phase, state.phase),
	]
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": {"entry_id": state.shop_state.entry_id, "phase": state.phase},
	}

func _validate_enter_workshop(map_definition) -> RefCounted:
	var phase_validation := _validate_service_entry_phase(RunPhaseScript.WORKSHOP)
	if not phase_validation.is_valid():
		return phase_validation
	var node_id: String = state.map_state.current_node_id
	var node = map_definition.node_definition(node_id)
	if node == null or node.node_kind != "WORKSHOP":
		return CommandValidationScript.new(false, "INVALID_SERVICE_NODE", "Workshop entry requires the current Map Node to be a Workshop.")
	if state.workshop_state.active:
		return CommandValidationScript.new(false, "SERVICE_ALREADY_ACTIVE", "The Workshop is already active.")
	if state.workshop_state.has_completed_node(node_id):
		return CommandValidationScript.new(false, "SERVICE_COMPLETED", "This Workshop node has already been completed.")
	return CommandValidationScript.new(true)

func _execute_enter_workshop() -> Dictionary:
	var node_id: String = state.map_state.current_node_id
	var entry_id := "workshop.%s.%d" % [state.run_id, state.workshop_state.entry_sequence + 1]
	state.workshop_state.begin(node_id, entry_id)
	var previous_phase: String = state.phase
	state.phase = RunPhaseScript.WORKSHOP
	var events: Array = [
		DomainEventScript.new(DomainEventScript.WORKSHOP_ENTERED, {
			"run_id": state.run_id,
			"node_id": node_id,
			"entry_id": entry_id,
			"service_ids": state.workshop_state.available_service_ids.duplicate(),
		}),
		_run_phase_event(previous_phase, state.phase),
	]
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": {
			"node_id": node_id,
			"entry_id": entry_id,
			"service_ids": state.workshop_state.available_service_ids.duplicate(),
			"phase": state.phase,
		},
	}

func _validate_use_workshop_service(
	service_id: String,
	instance_id: String,
	value_id: String = "",
	modifier_id: String = "",
	replace_existing: bool = false,
) -> RefCounted:
	if state.phase != RunPhaseScript.WORKSHOP or not state.workshop_state.active:
		return _invalid_phase(RunPhaseScript.WORKSHOP)
	var service_key: String = state.workshop_state.service_key(service_id)
	if not [WorkshopStateScript.REMOVE, WorkshopStateScript.TRANSFORM, WorkshopStateScript.MODIFIER, WorkshopStateScript.DUPLICATE, WorkshopStateScript.REFINEMENT_TOKEN].has(service_key):
		return CommandValidationScript.new(false, "INVALID_WORKSHOP_SERVICE", "The Workshop service ID is not supported.")
	if not state.workshop_state.is_service_available(service_id):
		return CommandValidationScript.new(false, "SERVICE_UNAVAILABLE", "The selected Workshop service is no longer available.")
	var tile_instance = _run_tile_instance(instance_id)
	if tile_instance == null:
		return CommandValidationScript.new(false, "INVALID_TILE_INSTANCE", "The selected TileInstance is not in the Run Tile Pool.")
	if tile_instance.ownership_scope != "RUN" or tile_instance.lifetime_scope != "RUN":
		return CommandValidationScript.new(false, "INVALID_TILE_OWNERSHIP", "Workshop services require a Run-owned persistent TileInstance.")
	var price_data: Dictionary = _workshop_price_details(service_key)
	var price := int(price_data.get("price", 0))
	if state.gold < price:
		return CommandValidationScript.new(false, "INSUFFICIENT_GOLD", "The run does not have enough Gold for this Workshop service.")
	match service_key:
		WorkshopStateScript.REMOVE:
			if state.tile_pool.tile_instances.size() <= economy.workshop_minimum_pool_size:
				return CommandValidationScript.new(false, "POOL_MINIMUM", "Remove cannot reduce the Tile Pool below its configured minimum.")
		WorkshopStateScript.TRANSFORM:
			var transform_definition_id := value_id if not value_id.is_empty() else modifier_id
			var transform_definition = content_registry.resolve(transform_definition_id)
			if not transform_definition is TileDefinitionScript:
				return CommandValidationScript.new(false, "INVALID_TILE_DEFINITION", "Transform requires a registered TileDefinition.")
			if transform_definition_id == tile_instance.definition_id:
				return CommandValidationScript.new(false, "NO_OP_TRANSFORM", "Transform must change the TileDefinition.")
			if _tile_definition_count(transform_definition_id, instance_id) >= economy.tile_copy_limit:
				return CommandValidationScript.new(false, "COPY_LIMIT", "Transform would exceed the TileDefinition copy limit.")
		WorkshopStateScript.MODIFIER:
			var selected_modifier_id := modifier_id if not modifier_id.is_empty() else value_id
			var modifier = content_registry.resolve(selected_modifier_id)
			if not modifier is TileModifierDefinitionScript:
				return CommandValidationScript.new(false, "INVALID_TILE_MODIFIER", "Modifier service requires a registered Tile Modifier.")
			var current_modifiers: Array = state.build_ownership.persistent_tile_modifier_state.get(instance_id, []).duplicate()
			var should_replace := replace_existing or service_id == WorkshopStateScript.REPLACE_MODIFIER
			if should_replace:
				if current_modifiers.is_empty():
					return CommandValidationScript.new(false, "NO_MODIFIER_TO_REPLACE", "Replace Modifier requires an existing Tile Modifier.")
				if current_modifiers.size() == 1 and current_modifiers[0] == selected_modifier_id:
					return CommandValidationScript.new(false, "MODIFIER_LIMIT", "Replace Modifier must change the Tile Modifier.")
			elif current_modifiers.size() >= 1:
				return CommandValidationScript.new(false, "MODIFIER_LIMIT", "The TileInstance already has its configured permanent Modifier.")
			if current_modifiers.count(selected_modifier_id) >= modifier.max_per_tile:
				return CommandValidationScript.new(false, "MODIFIER_LIMIT", "The TileInstance has reached this Modifier's copy limit.")
		WorkshopStateScript.DUPLICATE:
			if _tile_definition_count(tile_instance.definition_id) >= economy.tile_copy_limit:
				return CommandValidationScript.new(false, "COPY_LIMIT", "Duplicate would exceed the TileDefinition copy limit.")
		WorkshopStateScript.REFINEMENT_TOKEN:
			if state.refinement_tokens < 1:
				return CommandValidationScript.new(false, "INSUFFICIENT_REFINEMENT_TOKENS", "The Refinement Token service requires one Refinement Token.")
	return CommandValidationScript.new(true, CommandValidationScript.VALID, "", {
		"service_id": service_id,
		"price": price,
		"base_price": int(price_data.get("base_price", price)),
		"price_adjustments": price_data.get("adjustments", []).duplicate(true),
	})

func _execute_use_workshop_service(
	service_id: String,
	instance_id: String,
	value_id: String = "",
	modifier_id: String = "",
	replace_existing: bool = false,
) -> Dictionary:
	var service_key: String = state.workshop_state.service_key(service_id)
	var price_data: Dictionary = _workshop_price_details(service_key)
	var price := int(price_data.get("price", 0))
	var gold_transaction: Dictionary = economy.apply_sink(state, RunEconomyScript.GOLD, price, RunEconomyScript.SINK_WORKSHOP_SERVICE)
	if gold_transaction.is_empty():
		return {"accepted": false, "status": "INSUFFICIENT_GOLD", "message": "The run does not have enough Gold for this Workshop service."}
	var token_transaction: Dictionary = {}
	var data: Dictionary = {
		"service_id": service_id,
		"base_price": int(price_data.get("base_price", price)),
		"price": price,
		"price_adjustments": price_data.get("adjustments", []).duplicate(true),
		"instance_id": instance_id,
		"value_id": value_id,
		"modifier_id": modifier_id,
		"currency_transactions": [gold_transaction],
	}
	var tile_instance = _run_tile_instance(instance_id)
	if service_key == WorkshopStateScript.REMOVE:
		var remove_index := _tile_instance_index(instance_id)
		state.tile_pool.tile_instances.remove_at(remove_index)
		state.build_ownership.persistent_tile_modifier_state.erase(instance_id)
	elif service_key == WorkshopStateScript.TRANSFORM:
		var transform_definition_id := value_id if not value_id.is_empty() else modifier_id
		tile_instance.definition_id = transform_definition_id
		data["definition_id"] = transform_definition_id
	elif service_key == WorkshopStateScript.MODIFIER:
		var selected_modifier_id := modifier_id if not modifier_id.is_empty() else value_id
		var current_modifiers: Array = state.build_ownership.persistent_tile_modifier_state.get(instance_id, []).duplicate()
		var should_replace := replace_existing or service_id == WorkshopStateScript.REPLACE_MODIFIER
		if should_replace:
			current_modifiers = [selected_modifier_id]
		else:
			current_modifiers.append(selected_modifier_id)
		state.build_ownership.persistent_tile_modifier_state[instance_id] = current_modifiers
		data["modifier_id"] = selected_modifier_id
	elif service_key == WorkshopStateScript.DUPLICATE:
		var duplicate_result := _duplicate_run_tile(tile_instance)
		data["tile_instance_id"] = duplicate_result["instance_id"]
	elif service_key == WorkshopStateScript.REFINEMENT_TOKEN:
		token_transaction = economy.apply_sink(state, RunEconomyScript.REFINEMENT_TOKENS, 1, RunEconomyScript.SINK_RULE_BREAKER_REFINEMENT)
		if token_transaction.is_empty():
			state.gold += price
			return {"accepted": false, "status": "INSUFFICIENT_REFINEMENT_TOKENS", "message": "The Refinement Token service requires one Refinement Token."}
		var refinement_result := _duplicate_run_tile(tile_instance)
		data["tile_instance_id"] = refinement_result["instance_id"]
		data["refinement"] = "COPY_LIMIT_BREAK"
	if not token_transaction.is_empty():
		data["currency_transactions"].append(token_transaction)
	state.workshop_state.mark_service_used(service_id)
	var events: Array = []
	_events_for_currency_transaction(events, gold_transaction)
	if not token_transaction.is_empty():
		_events_for_currency_transaction(events, token_transaction)
	if service_key == WorkshopStateScript.REMOVE:
		events.append(DomainEventScript.new(DomainEventScript.TILE_REMOVED, {
			"instance_id": instance_id,
			"scope": "RUN_TILE_POOL",
			"permanent": true,
		}))
	data["phase"] = state.phase
	events.append(DomainEventScript.new(DomainEventScript.WORKSHOP_SERVICE_USED, data.duplicate(true)))
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": data,
	}

func _validate_exit_workshop() -> RefCounted:
	if state.phase != RunPhaseScript.WORKSHOP or not state.workshop_state.active:
		return _invalid_phase(RunPhaseScript.WORKSHOP)
	return CommandValidationScript.new(true)

func _execute_exit_workshop() -> Dictionary:
	state.workshop_state.mark_completed()
	var previous_phase: String = state.phase
	state.phase = RunPhaseScript.MAP_CHOICE
	var events: Array = [
		DomainEventScript.new(DomainEventScript.WORKSHOP_EXITED, {
			"run_id": state.run_id,
			"entry_id": state.workshop_state.entry_id,
			"node_id": state.workshop_state.node_id,
		}),
		_run_phase_event(previous_phase, state.phase),
	]
	state.map_state.last_events = events
	return {
		"accepted": true,
		"status": CommandResultScript.ACCEPTED,
		"events": events,
		"data": {"entry_id": state.workshop_state.entry_id, "phase": state.phase},
	}

func _validate_service_entry_phase(service_phase: String) -> RefCounted:
	if state.phase != RunPhaseScript.MAP_CHOICE:
		return _invalid_phase(RunPhaseScript.MAP_CHOICE)
	if service_phase not in [RunPhaseScript.SHOP, RunPhaseScript.WORKSHOP]:
		return CommandValidationScript.new(false, "INVALID_SERVICE_PHASE", "The requested service phase is not supported.")
	return CommandValidationScript.new(true)

func _serialized_shop_offers() -> Array:
	var serialized: Array = []
	for offer in state.shop_state.offers:
		if offer != null and offer.has_method("to_dictionary"):
			serialized.append(offer.to_dictionary())
	return serialized

func _apply_shop_special_offer(offer) -> Dictionary:
	var action: String = str(offer.metadata.get("special_action", ""))
	if action == "REFINEMENT_TOKEN":
		return economy.apply_source(state, RunEconomyScript.REFINEMENT_TOKENS, 1, RunEconomyScript.SOURCE_SHOP_SPECIAL)
	if action == "GOLD_CACHE":
		return economy.apply_source(state, RunEconomyScript.GOLD, 3, RunEconomyScript.SOURCE_SHOP_SPECIAL)
	return {}

func _workshop_price(service_key: String) -> int:
	return int(_workshop_price_details(service_key).get("price", 0))

func _workshop_price_details(service_key: String) -> Dictionary:
	var base_price := 0
	match service_key:
		WorkshopStateScript.REMOVE:
			base_price = economy.workshop_remove_price
		WorkshopStateScript.TRANSFORM:
			base_price = economy.workshop_transform_price
		WorkshopStateScript.MODIFIER:
			base_price = economy.workshop_modifier_price
		WorkshopStateScript.DUPLICATE:
			base_price = economy.workshop_duplicate_price
		WorkshopStateScript.REFINEMENT_TOKEN:
			base_price = economy.workshop_refinement_price + AlphaContractEffectsScript.workshop_refinement_gold_surcharge(content_registry, state.contract_id)
	return RunModifierEffectResolverScript.new().workshop_price(state, base_price)

func _run_tile_instance(instance_id: String):
	for tile_instance in state.tile_pool.tile_instances:
		if tile_instance.instance_id == instance_id:
			return tile_instance
	return null

func _tile_instance_index(instance_id: String) -> int:
	for index in range(state.tile_pool.tile_instances.size()):
		if state.tile_pool.tile_instances[index].instance_id == instance_id:
			return index
	return -1

func _tile_definition_count(definition_id: String, excluded_instance_id: String = "") -> int:
	var count := 0
	for tile_instance in state.tile_pool.tile_instances:
		if tile_instance.instance_id != excluded_instance_id and tile_instance.definition_id == definition_id:
			count += 1
	return count

func _duplicate_run_tile(source_tile) -> Dictionary:
	var tile_instance_result := _next_tile_instance_id()
	var duplicate := RunTileInstanceRecordScript.new(
		tile_instance_result["instance_id"],
		source_tile.definition_id,
		"RUN",
		"RUN",
	)
	state.tile_pool.add_tile_instance(duplicate)
	state.tile_instance_sequence = tile_instance_result["sequence"]
	var source_modifiers: Array = state.build_ownership.persistent_tile_modifier_state.get(source_tile.instance_id, []).duplicate()
	if not source_modifiers.is_empty():
		state.build_ownership.persistent_tile_modifier_state[duplicate.instance_id] = source_modifiers
	return {"accepted": true, "instance_id": duplicate.instance_id}

func _next_tile_instance_id() -> Dictionary:
	var sequence: int = state.tile_instance_sequence
	var instance_id := ""
	while instance_id.is_empty() or _tile_instance_exists(instance_id):
		sequence += 1
		instance_id = "run.tile.%d" % sequence
	return {"sequence": sequence, "instance_id": instance_id}

func _tile_instance_exists(instance_id: String) -> bool:
	for tile_instance in state.tile_pool.tile_instances:
		if tile_instance.instance_id == instance_id:
			return true
	return false

func _events_for_currency_transaction(events: Array, transaction: Dictionary) -> void:
	var event_type := DomainEventScript.GOLD_CHANGED if transaction.currency == RunEconomyScript.GOLD else DomainEventScript.REFINEMENT_TOKENS_CHANGED
	events.append(DomainEventScript.new(event_type, transaction))
