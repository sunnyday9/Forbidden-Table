class_name ShopWorkshopTest
extends RefCounted

const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const RelicDefinition = preload("res://src/content/definitions/relic_definition.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunPresentationController = preload("res://src/presentation/run/run_presentation_controller.gd")
const RunScene = preload("res://scenes/run/run_scene.tscn")
const RunStartingPoolContentFixture = preload("res://tests/fixtures/run_starting_pool_content_fixture.gd")
const RunTileInstanceRecord = preload("res://src/domain/run/run_tile_instance_record.gd")
const ShopOffer = preload("res://src/domain/run/shop_offer.gd")
const ShopState = preload("res://src/domain/run/shop_state.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const TileModifierDefinition = preload("res://src/content/definitions/tile_modifier_definition.gd")
const BuyShopOfferCommand = preload("res://src/domain/commands/buy_shop_offer_command.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const EnterShopCommand = preload("res://src/domain/commands/enter_shop_command.gd")
const EnterWorkshopCommand = preload("res://src/domain/commands/enter_workshop_command.gd")
const ExitShopCommand = preload("res://src/domain/commands/exit_shop_command.gd")
const ExitWorkshopCommand = preload("res://src/domain/commands/exit_workshop_command.gd")
const RefreshShopCommand = preload("res://src/domain/commands/refresh_shop_command.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const UseWorkshopServiceCommand = preload("res://src/domain/commands/use_workshop_service_command.gd")
const WorkshopState = preload("res://src/domain/run/workshop_state.gd")

const LEFT := "base.map_node.normal.left"
const RIGHT := "base.map_node.normal.right"
const INTRO := "base.map_node.intro"
const SHOP := "base.map_node.shop"
const WORKSHOP := "base.map_node.workshop"

func run() -> Array[String]:
	var failures: Array[String] = []
	test_shop_entry_is_deterministic_and_checkpointable(failures)
	test_shop_purchase_marks_sold_and_consumes_shared_gold(failures)
	test_shop_refresh_replaces_only_unpurchased_slots(failures)
	test_workshop_services_preserve_tile_identity_and_ownership(failures)
	test_workshop_add_and_replace_modifier_services_are_available(failures)
	test_workshop_presentation_actions_include_legal_inputs(failures)
	test_workshop_selection_resets_when_exiting(failures)
	test_workshop_copy_limits_and_service_availability(failures)
	test_rejected_shop_and_workshop_actions_are_atomic(failures)
	test_service_commands_serialize_stable_ids(failures)
	return failures

func test_shop_entry_is_deterministic_and_checkpointable(failures: Array[String]) -> void:
	var first := _shop_domain("shop.deterministic", 1201)
	var second := _shop_domain("shop.deterministic", 1201)
	var first_result = first.execute(EnterShopCommand.new("shop.deterministic.enter"))
	var second_result = second.execute(EnterShopCommand.new("shop.deterministic.enter"))

	assert_true(first_result.accepted and second_result.accepted, "Shop entry is accepted at an authored Shop node", failures)
	assert_true(first.state.phase == RunPhase.SHOP, "Shop entry advances the RunPhase to SHOP", failures)
	assert_true(first.state.shop_state is ShopState, "RunState owns typed Shop state", failures)
	assert_true(first.state.shop_state.offers.size() == 5, "Shop exposes approximately five offers", failures)
	assert_true(_has_offer_kind(first.state.shop_state.offers, ShopOffer.RELIC), "Shop exposes a Relic offer", failures)
	assert_true(_has_offer_kind(first.state.shop_state.offers, ShopOffer.TECHNIQUE), "Shop exposes a Run Technique offer", failures)
	assert_true(_has_offer_kind(first.state.shop_state.offers, ShopOffer.SPECIAL), "Shop exposes a special offer", failures)
	assert_true(first.state.shop_state.refreshes_remaining == first.economy.shop_base_refresh_allowance, "Shop uses its configured base refresh allowance", failures)
	assert_true(first.state.shop_state.to_dictionary() == second.state.shop_state.to_dictionary(), "same seed and accepted entry reproduce Shop offers", failures)
	assert_true(first.rng_snapshot()["streams"]["shop"] == second.rng_snapshot()["streams"]["shop"], "same seed and accepted entry reproduce the Shop RNG checkpoint", failures)
	assert_true(first.checkpoint()["run_state"].has("shop_state"), "Shop state is included in the RunState checkpoint", failures)
	var first_relic = _offer_of_kind(first.state.shop_state.offers, ShopOffer.RELIC)
	var second_relic = _offer_of_kind(second.state.shop_state.offers, ShopOffer.RELIC)
	if first_relic == null or second_relic == null:
		return
	first.state.gold = first_relic.price
	second.state.gold = second_relic.price
	var first_purchase = first.execute(BuyShopOfferCommand.new("shop.deterministic.buy", first_relic.offer_id, first.state.shop_state.entry_id))
	var second_purchase = second.execute(BuyShopOfferCommand.new("shop.deterministic.buy", second_relic.offer_id, second.state.shop_state.entry_id))
	var first_refresh = first.execute(RefreshShopCommand.new("shop.deterministic.refresh", first.state.shop_state.entry_id))
	var second_refresh = second.execute(RefreshShopCommand.new("shop.deterministic.refresh", second.state.shop_state.entry_id))
	assert_true(first_purchase.accepted and second_purchase.accepted and first_refresh.accepted and second_refresh.accepted, "stable Shop Commands accept the same deterministic sequence", failures)
	assert_true(first.checkpoint() == second.checkpoint(), "the same stable Shop Commands reproduce the complete checkpoint", failures)

func test_shop_purchase_marks_sold_and_consumes_shared_gold(failures: Array[String]) -> void:
	var domain := _shop_domain("shop.purchase", 1202)
	domain.execute(EnterShopCommand.new("shop.purchase.enter"))
	var offer = _offer_of_kind(domain.state.shop_state.offers, ShopOffer.RELIC)
	assert_true(offer != null, "Shop purchase fixture has a Relic offer", failures)
	if offer == null:
		return
	domain.state.gold = offer.price + 3
	var result = domain.execute(BuyShopOfferCommand.new("shop.purchase.buy", offer.offer_id, domain.state.shop_state.entry_id))

	assert_true(result.accepted, "a purchasable Shop offer is accepted", failures)
	assert_true(domain.state.gold == 3, "Shop purchase consumes the shared Gold currency", failures)
	assert_true(domain.state.shop_state.offer_by_id(offer.offer_id).status == ShopOffer.SOLD, "a purchased Shop slot remains SOLD", failures)
	assert_true(domain.state.build_ownership.owned_relic_ids.has(offer.content_id), "purchasing a Relic updates RunState build ownership", failures)
	assert_true(result.replayable, "accepted Shop purchases are replayable Commands", failures)

	var before_repeat := domain.checkpoint()
	var rng_before_repeat := domain.rng_snapshot()
	var repeat = domain.execute(BuyShopOfferCommand.new("shop.purchase.buy-again", offer.offer_id, domain.state.shop_state.entry_id))
	assert_true(not repeat.accepted and repeat.validation.code == "OFFER_SOLD", "a SOLD Shop offer cannot be purchased again", failures)
	assert_true(domain.checkpoint() == before_repeat, "a repeated Shop purchase leaves RunState unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before_repeat, "a repeated Shop purchase leaves every RNG stream unchanged", failures)

func test_shop_refresh_replaces_only_unpurchased_slots(failures: Array[String]) -> void:
	var domain := _shop_domain("shop.refresh", 1203)
	domain.execute(EnterShopCommand.new("shop.refresh.enter"))
	var purchased = _offer_of_kind(domain.state.shop_state.offers, ShopOffer.RELIC)
	assert_true(purchased != null, "Shop refresh fixture has a purchasable Relic", failures)
	if purchased == null:
		return
	domain.state.gold = purchased.price
	domain.execute(BuyShopOfferCommand.new("shop.refresh.buy", purchased.offer_id, domain.state.shop_state.entry_id))
	var sold_snapshot: Dictionary = domain.state.shop_state.offer_by_id(purchased.offer_id).to_dictionary()
	var available_before: Dictionary = {}
	for offer in domain.state.shop_state.offers:
		if offer.status == ShopOffer.AVAILABLE:
			available_before[offer.slot_index] = offer.offer_id

	var result = domain.execute(RefreshShopCommand.new("shop.refresh.refresh", domain.state.shop_state.entry_id))
	assert_true(result.accepted, "Shop refresh is accepted while allowance remains", failures)
	assert_true(domain.state.shop_state.refreshes_remaining == 0, "Shop refresh consumes one configured allowance", failures)
	assert_true(domain.state.shop_state.offer_by_id(purchased.offer_id).to_dictionary() == sold_snapshot, "refresh leaves the purchased SOLD slot unchanged", failures)
	for offer in domain.state.shop_state.offers:
		if offer.status == ShopOffer.AVAILABLE:
			assert_true(offer.offer_id != available_before.get(offer.slot_index, ""), "refresh replaces an unpurchased offer slot", failures)

	var before_repeat := domain.checkpoint()
	var rng_before_repeat := domain.rng_snapshot()
	var repeat = domain.execute(RefreshShopCommand.new("shop.refresh.refresh-again", domain.state.shop_state.entry_id))
	assert_true(not repeat.accepted and repeat.validation.code == "NO_REFRESHES_REMAINING", "Shop refresh rejects after the allowance is exhausted", failures)
	assert_true(domain.checkpoint() == before_repeat, "an exhausted Shop refresh leaves RunState unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before_repeat, "an exhausted Shop refresh leaves every RNG stream unchanged", failures)

func test_workshop_services_preserve_tile_identity_and_ownership(failures: Array[String]) -> void:
	var domain := _workshop_domain("workshop.services", 1204, 4)
	var first_tile_id: String = domain.state.tile_pool.tile_instances[0].instance_id
	var second_tile_id: String = domain.state.tile_pool.tile_instances[1].instance_id
	var third_tile_id: String = domain.state.tile_pool.tile_instances[2].instance_id
	var fourth_tile_id: String = domain.state.tile_pool.tile_instances[3].instance_id
	domain.state.gold = 200
	domain.state.refinement_tokens = 1
	var enter = domain.execute(EnterWorkshopCommand.new("workshop.services.enter"))

	assert_true(enter.accepted and domain.state.phase == RunPhase.WORKSHOP, "Workshop entry advances the RunPhase to WORKSHOP", failures)
	var transform = domain.execute(UseWorkshopServiceCommand.new(
		"workshop.services.transform",
		UseWorkshopServiceCommand.TRANSFORM,
		first_tile_id,
		"base.tile.bamboo.1",
	))
	assert_true(transform.accepted, "Workshop Transform accepts a valid TileInstance", failures)
	assert_true(_tile_by_id(domain, first_tile_id).definition_id == "base.tile.bamboo.1", "Transform preserves TileInstance identity", failures)
	assert_true(_tile_by_id(domain, first_tile_id).ownership_scope == "RUN" and _tile_by_id(domain, first_tile_id).lifetime_scope == "RUN", "Transform preserves TileInstance ownership and lifetime", failures)

	var duplicate = domain.execute(UseWorkshopServiceCommand.new(
		"workshop.services.duplicate",
		UseWorkshopServiceCommand.DUPLICATE,
		third_tile_id,
	))
	assert_true(duplicate.accepted, "Workshop Duplicate accepts a valid TileInstance", failures)
	assert_true(domain.state.tile_pool.tile_instances.size() == 5, "Duplicate adds one TileInstance to the Run Tile Pool", failures)
	assert_true(domain.state.tile_pool.tile_instances.has(_tile_by_id(domain, third_tile_id)), "Duplicate leaves the source TileInstance present", failures)
	assert_true(str(duplicate.data.get("tile_instance_id", "")).begins_with("run.tile."), "Duplicate creates a stable Run TileInstance ID", failures)

	var refinement = domain.execute(UseWorkshopServiceCommand.new(
		"workshop.services.refinement-token",
		UseWorkshopServiceCommand.REFINEMENT_TOKEN,
		fourth_tile_id,
	))
	assert_true(refinement.accepted, "the high-tier Refinement Token service is available", failures)
	assert_true(domain.state.refinement_tokens == 0, "the Refinement Token service consumes one Refinement Token", failures)
	assert_true(domain.state.tile_pool.tile_instances.size() == 6, "the Refinement Token service performs its high-tier refinement", failures)

	var remove = domain.execute(UseWorkshopServiceCommand.new(
		"workshop.services.remove",
		UseWorkshopServiceCommand.REMOVE,
		second_tile_id,
	))
	assert_true(remove.accepted, "Workshop Remove accepts a valid TileInstance above the pool minimum", failures)
	assert_true(_tile_by_id(domain, second_tile_id) == null, "Remove deletes only the selected TileInstance from the Run Tile Pool", failures)
	assert_true(domain.state.tile_pool.tile_instances.size() == 5, "Remove preserves the remaining Tile Pool records", failures)

	var exit = domain.execute(ExitWorkshopCommand.new("workshop.services.exit"))
	assert_true(exit.accepted and domain.state.phase == RunPhase.MAP_CHOICE, "Workshop exit returns to Map Choice", failures)
	assert_true(not domain.state.workshop_state.active and domain.state.workshop_state.completed, "Workshop exit checkpoint state is stable and completed", failures)

func test_workshop_add_and_replace_modifier_services_are_available(failures: Array[String]) -> void:
	var add_domain := _workshop_domain("workshop.modifier.add", 1205, 2)
	add_domain.state.gold = 100
	add_domain.execute(EnterWorkshopCommand.new("workshop.modifier.add.enter"))
	var target_id: String = add_domain.state.tile_pool.tile_instances[0].instance_id
	var add = add_domain.execute(UseWorkshopServiceCommand.new(
		"workshop.modifier.add.use",
		UseWorkshopServiceCommand.ADD_MODIFIER,
		target_id,
		"",
		"base.modifier.flexible_identity",
	))
	assert_true(add.accepted, "Workshop Add Modifier accepts an available modifier slot", failures)
	assert_true(add_domain.state.build_ownership.persistent_tile_modifier_state[target_id] == ["base.modifier.flexible_identity"], "Add Modifier records a stable modifier ID on the same TileInstance", failures)

	var replace_domain := _workshop_domain("workshop.modifier.replace", 1206, 2)
	replace_domain.state.gold = 100
	replace_domain.execute(EnterWorkshopCommand.new("workshop.modifier.replace.enter"))
	var replace_target_id: String = replace_domain.state.tile_pool.tile_instances[0].instance_id
	replace_domain.state.build_ownership.persistent_tile_modifier_state[replace_target_id] = ["base.modifier.flexible_identity"]
	var replace = replace_domain.execute(UseWorkshopServiceCommand.new(
		"workshop.modifier.replace.use",
		UseWorkshopServiceCommand.REPLACE_MODIFIER,
		replace_target_id,
		"",
		"base.modifier.recycling",
	))
	assert_true(replace.accepted, "Workshop Replace Modifier accepts an existing modifier slot", failures)
	assert_true(replace_domain.state.build_ownership.persistent_tile_modifier_state[replace_target_id] == ["base.modifier.recycling"], "Replace Modifier updates only the selected TileInstance modifier state", failures)

func test_workshop_presentation_actions_include_legal_inputs(failures: Array[String]) -> void:
	var transform_domain := _workshop_domain("workshop.presentation.transform", 1212, 14)
	transform_domain.state.gold = 100
	transform_domain.execute(EnterWorkshopCommand.new("workshop.presentation.transform.enter"))
	var transform_controller := RunPresentationController.new(transform_domain)
	var scene = RunScene.instantiate()
	var transform_target_id: String = transform_domain.state.tile_pool.tile_instances[1].instance_id
	var transform_state_before_selection := transform_domain.checkpoint()
	var transform_rng_before_selection := transform_domain.rng_snapshot()
	var transform_service_action := _find_workshop_service_action(transform_controller.action_descriptors(), UseWorkshopServiceCommand.TRANSFORM)
	assert_true(not transform_service_action.is_empty(), "Workshop exposes Transform as a selectable service", failures)
	assert_true(transform_controller.action_descriptors().size() <= 7, "the Workshop service menu remains bounded with a 14-tile pool", failures)
	if transform_service_action.is_empty():
		scene.free()
		return
	var service_selection = transform_controller.confirm(str(transform_service_action.get("id", "")))
	assert_true(service_selection.accepted, "choosing Transform advances the presentation selection", failures)
	var target_actions: Array = transform_controller.action_descriptors()
	assert_true(target_actions.size() <= 15, "Transform target selection lists at most the 14 owned tiles and Back", failures)
	var target_action := _find_workshop_target_action(target_actions, UseWorkshopServiceCommand.TRANSFORM, transform_target_id)
	assert_true(not target_action.is_empty(), "Transform target selection includes the requested non-first TileInstance", failures)
	if target_action.is_empty():
		scene.free()
		return
	var target_selection = transform_controller.confirm(str(target_action.get("id", "")))
	assert_true(target_selection.accepted, "choosing a Transform target advances to legal destination choices", failures)
	assert_true(transform_domain.checkpoint() == transform_state_before_selection and transform_domain.rng_snapshot() == transform_rng_before_selection, "service and target selections do not mutate Domain state or RNG", failures)
	var transform_action := _find_workshop_action(
		transform_controller.action_descriptors(),
		UseWorkshopServiceCommand.TRANSFORM,
		transform_target_id,
		"base.tile.bamboo.1",
		"",
	)
	assert_true(not transform_action.is_empty(), "Transform exposes a concrete non-first TileInstance and destination TileDefinition", failures)
	if transform_action.is_empty():
		scene.free()
		return
	assert_true(_find_workshop_action(transform_controller.action_descriptors(), UseWorkshopServiceCommand.TRANSFORM, transform_target_id, "base.tile.characters.2", "").is_empty(), "Transform hides a no-op destination for the selected TileInstance", failures)
	assert_true(transform_controller.action_descriptors().size() <= 40, "Transform value selection stays bounded by registered TileDefinitions", failures)
	assert_true(str(transform_action.get("id", "")).contains(transform_target_id) and str(transform_action.get("id", "")).contains("base.tile.bamboo.1"), "Transform action ID is built from stable TileInstance and content IDs", failures)
	var repeated_transform_action := _find_workshop_action(transform_controller.action_descriptors(), UseWorkshopServiceCommand.TRANSFORM, transform_target_id, "base.tile.bamboo.1", "")
	assert_true(repeated_transform_action.get("id", "") == transform_action.get("id", ""), "Workshop action IDs remain stable across descriptor refreshes", failures)
	var transform_label: String = scene._action_label(transform_action)
	var transform_tooltip: String = scene._action_tooltip(transform_action)
	assert_true(transform_label.contains("Bamboo 1") and transform_label.contains("10 Gold"), "Transform button names its destination TileDefinition and price", failures)
	assert_true(transform_tooltip.contains(transform_target_id) and transform_tooltip.contains("base.tile.bamboo.1"), "Transform details identify the selected TileInstance and destination", failures)
	var transform_result = transform_controller.confirm(str(transform_action.get("id", "")))
	assert_true(transform_result.accepted, "the selected Transform action submits a valid Domain command", failures)
	assert_true(_tile_by_id(transform_domain, transform_target_id).definition_id == "base.tile.bamboo.1", "Transform submission changes the exact selected TileInstance", failures)
	assert_true(_tile_by_id(transform_domain, "workshop.presentation.transform.tile.1").definition_id == "base.tile.characters.1", "Transform submission leaves the unselected first TileInstance alone", failures)
	var replayed_transform_command = transform_domain.replay_record.commands.back()
	assert_true(replayed_transform_command.payload.get("instance_id", "") == transform_target_id and replayed_transform_command.payload.get("value_id", "") == "base.tile.bamboo.1", "accepted replay records preserve the selected Transform IDs", failures)

	var add_domain := _workshop_domain("workshop.presentation.add", 1213, 2)
	add_domain.state.gold = 100
	add_domain.execute(EnterWorkshopCommand.new("workshop.presentation.add.enter"))
	var add_controller := RunPresentationController.new(add_domain)
	var add_target_id: String = add_domain.state.tile_pool.tile_instances[1].instance_id
	var add_service_action := _find_workshop_service_action(add_controller.action_descriptors(), UseWorkshopServiceCommand.ADD_MODIFIER)
	assert_true(not add_service_action.is_empty(), "Workshop exposes Add Modifier as a selectable service", failures)
	if add_service_action.is_empty():
		scene.free()
		return
	add_controller.confirm(str(add_service_action.get("id", "")))
	var add_target_action := _find_workshop_target_action(add_controller.action_descriptors(), UseWorkshopServiceCommand.ADD_MODIFIER, add_target_id)
	assert_true(not add_target_action.is_empty(), "Add Modifier allows choosing a specific TileInstance", failures)
	if add_target_action.is_empty():
		scene.free()
		return
	add_controller.confirm(str(add_target_action.get("id", "")))
	var add_action := _find_workshop_action(add_controller.action_descriptors(), UseWorkshopServiceCommand.ADD_MODIFIER, add_target_id, "", "base.modifier.flexible_identity")
	assert_true(not add_action.is_empty(), "Add Modifier exposes a concrete TileInstance and registered Modifier", failures)
	if add_action.is_empty():
		scene.free()
		return
	var add_label: String = scene._action_label(add_action)
	assert_true(add_label.contains("Flexible Identity") and add_label.contains("7 Gold"), "Add Modifier label names the selected Modifier and price", failures)
	var add_result = add_controller.confirm(str(add_action.get("id", "")))
	assert_true(add_result.accepted, "the selected Add Modifier action submits a valid Domain command", failures)
	assert_true(add_domain.state.build_ownership.persistent_tile_modifier_state.get(add_target_id, []) == ["base.modifier.flexible_identity"], "Add Modifier applies to the exact selected TileInstance", failures)

	var replace_domain := _workshop_domain("workshop.presentation.replace", 1214, 2)
	replace_domain.state.gold = 100
	replace_domain.execute(EnterWorkshopCommand.new("workshop.presentation.replace.enter"))
	var replace_target_id: String = replace_domain.state.tile_pool.tile_instances[1].instance_id
	replace_domain.state.build_ownership.persistent_tile_modifier_state[replace_target_id] = ["base.modifier.flexible_identity"]
	var replace_controller := RunPresentationController.new(replace_domain)
	var replace_service_action := _find_workshop_service_action(replace_controller.action_descriptors(), UseWorkshopServiceCommand.REPLACE_MODIFIER)
	assert_true(not replace_service_action.is_empty(), "Workshop exposes Replace Modifier when a TileInstance has a modifier", failures)
	if replace_service_action.is_empty():
		scene.free()
		return
	replace_controller.confirm(str(replace_service_action.get("id", "")))
	var replace_target_action := _find_workshop_target_action(replace_controller.action_descriptors(), UseWorkshopServiceCommand.REPLACE_MODIFIER, replace_target_id)
	assert_true(not replace_target_action.is_empty(), "Replace Modifier allows choosing a specific TileInstance", failures)
	if replace_target_action.is_empty():
		scene.free()
		return
	replace_controller.confirm(str(replace_target_action.get("id", "")))
	var replace_action := _find_workshop_action(replace_controller.action_descriptors(), UseWorkshopServiceCommand.REPLACE_MODIFIER, replace_target_id, "", "base.modifier.recycling")
	assert_true(not replace_action.is_empty(), "Replace Modifier exposes a concrete target and replacement Modifier", failures)
	if replace_action.is_empty():
		scene.free()
		return
	var replace_label: String = scene._action_label(replace_action)
	assert_true(replace_label.contains("Recycling") and replace_label.contains("Replace"), "Replace Modifier label explains the selected replacement", failures)
	var replace_result = replace_controller.confirm(str(replace_action.get("id", "")))
	assert_true(replace_result.accepted, "the selected Replace Modifier action submits a valid Domain command", failures)
	assert_true(replace_domain.state.build_ownership.persistent_tile_modifier_state[replace_target_id] == ["base.modifier.recycling"], "Replace Modifier applies to the exact selected TileInstance", failures)
	scene.free()

	for service_id in [UseWorkshopServiceCommand.REMOVE, UseWorkshopServiceCommand.DUPLICATE, UseWorkshopServiceCommand.REFINEMENT_TOKEN]:
		var service_domain := _workshop_domain("workshop.presentation.%s" % service_id.to_lower(), 1215, 2)
		service_domain.state.gold = 100
		service_domain.state.refinement_tokens = 1
		service_domain.execute(EnterWorkshopCommand.new("workshop.presentation.%s.enter" % service_id.to_lower()))
		var service_controller := RunPresentationController.new(service_domain)
		var service_target_id: String = service_domain.state.tile_pool.tile_instances[1].instance_id
		var service_choice := _find_workshop_service_action(service_controller.action_descriptors(), service_id)
		assert_true(not service_choice.is_empty(), "%s remains an explicitly selectable service" % service_id, failures)
		if service_choice.is_empty():
			continue
		service_controller.confirm(str(service_choice.get("id", "")))
		var service_action := _find_workshop_action(service_controller.action_descriptors(), service_id, service_target_id, "", "")
		assert_true(not service_action.is_empty(), "%s remains available with a concrete TileInstance target" % service_id, failures)
		if service_action.is_empty():
			continue
		var service_result = service_controller.confirm(str(service_action.get("id", "")))
		assert_true(service_result.accepted, "%s action submits a valid Domain command" % service_id, failures)

func _find_workshop_service_action(actions: Array, service_id: String) -> Dictionary:
	for action in actions:
		if action.get("kind") == "WORKSHOP_SELECT_SERVICE" and action.get("service_id", "") == service_id:
			return action
	return {}

func _find_workshop_target_action(actions: Array, service_id: String, instance_id: String) -> Dictionary:
	for action in actions:
		if action.get("kind") == "WORKSHOP_SELECT_TARGET" and action.get("service_id", "") == service_id and action.get("instance_id", "") == instance_id:
			return action
	return {}

func _find_workshop_action(actions: Array, service_id: String, instance_id: String, value_id: String, modifier_id: String) -> Dictionary:
	for action in actions:
		if action.get("kind") != "WORKSHOP_SERVICE":
			continue
		if action.get("service_id", "") != service_id:
			continue
		if action.get("instance_id", "") != instance_id:
			continue
		if action.get("value_id", "") != value_id:
			continue
		if action.get("modifier_id", "") != modifier_id:
			continue
		return action
	return {}

func test_workshop_selection_resets_when_exiting(failures: Array[String]) -> void:
	var domain := _workshop_domain("workshop.presentation.exit", 1216, 2)
	domain.state.gold = 100
	domain.execute(EnterWorkshopCommand.new("workshop.presentation.exit.enter"))
	var controller := RunPresentationController.new(domain)
	var service_action := _find_workshop_service_action(controller.action_descriptors(), UseWorkshopServiceCommand.TRANSFORM)
	assert_true(not service_action.is_empty(), "the first Workshop visit offers Transform", failures)
	if service_action.is_empty():
		return
	controller.confirm(str(service_action.get("id", "")))
	var target_instance_id: String = domain.state.tile_pool.tile_instances[1].instance_id
	var target_action := _find_workshop_target_action(controller.action_descriptors(), UseWorkshopServiceCommand.TRANSFORM, target_instance_id)
	assert_true(not target_action.is_empty(), "the first Workshop visit can select a Transform target", failures)
	if target_action.is_empty():
		return
	controller.confirm(str(target_action.get("id", "")))
	var exit_result = controller.submit(ExitWorkshopCommand.new("workshop.presentation.exit.leave"))
	assert_true(exit_result.accepted and domain.state.phase == RunPhase.MAP_CHOICE, "accepted Workshop exit returns to the map", failures)

	# Model the next authored Workshop boundary on the same long-lived controller.
	domain.state.workshop_state.begin("base.map_node.next_act.workshop", "workshop.second_entry")
	domain.state.phase = RunPhase.WORKSHOP
	var next_entry_actions := controller.action_descriptors()
	assert_true(next_entry_actions.any(func(action): return action.get("kind") == "WORKSHOP_SELECT_SERVICE"), "a later Workshop entry starts at its service menu", failures)
	assert_true(not next_entry_actions.any(func(action): return action.get("kind") == "WORKSHOP_SERVICE"), "the prior visit's selected target and value do not leak into a later entry", failures)

func test_workshop_copy_limits_and_service_availability(failures: Array[String]) -> void:
	var availability_domain := _workshop_domain("workshop.availability", 1210, 2)
	availability_domain.state.gold = 100
	availability_domain.execute(EnterWorkshopCommand.new("workshop.availability.enter"))
	var first_tile_id: String = availability_domain.state.tile_pool.tile_instances[0].instance_id
	var second_tile_id: String = availability_domain.state.tile_pool.tile_instances[1].instance_id
	var first_duplicate = availability_domain.execute(UseWorkshopServiceCommand.new(
		"workshop.availability.duplicate",
		UseWorkshopServiceCommand.DUPLICATE,
		first_tile_id,
	))
	assert_true(first_duplicate.accepted, "Workshop accepts the first use of a stable service", failures)
	var before_unavailable := availability_domain.checkpoint()
	var rng_before_unavailable := availability_domain.rng_snapshot()
	var unavailable = availability_domain.execute(UseWorkshopServiceCommand.new(
		"workshop.availability.duplicate-again",
		UseWorkshopServiceCommand.DUPLICATE,
		second_tile_id,
	))
	assert_true(not unavailable.accepted and unavailable.validation.code == "SERVICE_UNAVAILABLE", "Workshop rejects a service after it has been used", failures)
	assert_true(availability_domain.checkpoint() == before_unavailable, "an unavailable Workshop service leaves RunState unchanged", failures)
	assert_true(availability_domain.rng_snapshot() == rng_before_unavailable, "an unavailable Workshop service leaves every RNG stream unchanged", failures)

	var copy_limit_domain := _workshop_domain("workshop.copy-limit", 1211, 1)
	copy_limit_domain.state.gold = 100
	for index in range(3):
		copy_limit_domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
			"workshop.copy-limit.extra.%d" % index,
			"base.tile.characters.1",
			"RUN",
			"RUN",
		))
	copy_limit_domain.execute(EnterWorkshopCommand.new("workshop.copy-limit.enter"))
	var copy_limit_tile_id: String = copy_limit_domain.state.tile_pool.tile_instances[0].instance_id
	var before_copy_limit := copy_limit_domain.checkpoint()
	var rng_before_copy_limit := copy_limit_domain.rng_snapshot()
	var copy_limited = copy_limit_domain.execute(UseWorkshopServiceCommand.new(
		"workshop.copy-limit.duplicate",
		UseWorkshopServiceCommand.DUPLICATE,
		copy_limit_tile_id,
	))
	assert_true(not copy_limited.accepted and copy_limited.validation.code == "COPY_LIMIT", "Workshop rejects Duplicate at the configured TileDefinition copy limit", failures)
	assert_true(copy_limit_domain.checkpoint() == before_copy_limit, "a copy-limit rejection leaves RunState unchanged", failures)
	assert_true(copy_limit_domain.rng_snapshot() == rng_before_copy_limit, "a copy-limit rejection leaves every RNG stream unchanged", failures)

	var copy_break_domain := _workshop_domain("workshop.copy-limit-break", 1212, 1)
	for index in range(3):
		copy_break_domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
			"workshop.copy-limit-break.extra.%d" % index,
			"base.tile.characters.1",
			"RUN",
			"RUN",
		))
	copy_break_domain.state.gold = 100
	copy_break_domain.state.refinement_tokens = 1
	copy_break_domain.execute(EnterWorkshopCommand.new("workshop.copy-limit-break.enter"))
	var capped_tile_id: String = copy_break_domain.state.tile_pool.tile_instances[0].instance_id
	var copy_limit_break = copy_break_domain.execute(UseWorkshopServiceCommand.new(
		"workshop.copy-limit-break.refinement",
		UseWorkshopServiceCommand.REFINEMENT_TOKEN,
		capped_tile_id,
	))
	assert_true(copy_limit_break.accepted, "explicit Refinement Token copy-limit break accepts a fifth TileInstance", failures)
	assert_true(copy_break_domain.state.tile_pool.tile_instances.size() == 5, "explicit copy-limit break adds one TileInstance beyond the default cap", failures)
	assert_true(copy_limit_break.data.get("refinement", "") == "COPY_LIMIT_BREAK", "the over-cap refinement is identified as an explicit copy-limit break", failures)

func test_rejected_shop_and_workshop_actions_are_atomic(failures: Array[String]) -> void:
	var shop_domain := _shop_domain("service.atomic.shop", 1207)
	shop_domain.execute(EnterShopCommand.new("service.atomic.shop.enter"))
	var shop_offer = _offer_of_kind(shop_domain.state.shop_state.offers, ShopOffer.RELIC)
	if shop_offer == null:
		assert_true(false, "atomicity fixture has a Shop offer", failures)
		return
	var shop_before := shop_domain.checkpoint()
	var shop_rng_before := shop_domain.rng_snapshot()
	var insufficient = shop_domain.execute(BuyShopOfferCommand.new("service.atomic.shop.buy", shop_offer.offer_id, shop_domain.state.shop_state.entry_id))
	assert_true(not insufficient.accepted and insufficient.validation.code == "INSUFFICIENT_GOLD", "Shop rejects a purchase without enough Gold", failures)
	assert_true(shop_domain.checkpoint() == shop_before and shop_domain.rng_snapshot() == shop_rng_before, "an unaffordable Shop purchase is atomic", failures)

	var workshop_domain := _workshop_domain("service.atomic.workshop", 1208, 1)
	workshop_domain.state.gold = workshop_domain.economy.workshop_remove_price
	workshop_domain.execute(EnterWorkshopCommand.new("service.atomic.workshop.enter"))
	var tile_id: String = workshop_domain.state.tile_pool.tile_instances[0].instance_id
	var workshop_before := workshop_domain.checkpoint()
	var workshop_rng_before := workshop_domain.rng_snapshot()
	var remove = workshop_domain.execute(UseWorkshopServiceCommand.new(
		"service.atomic.workshop.remove",
		UseWorkshopServiceCommand.REMOVE,
		tile_id,
	))
	assert_true(not remove.accepted and remove.validation.code == "POOL_MINIMUM", "Workshop rejects Remove at the configured pool minimum", failures)
	assert_true(workshop_domain.checkpoint() == workshop_before and workshop_domain.rng_snapshot() == workshop_rng_before, "a rejected Workshop service is atomic", failures)

	var shared_gold := _shop_domain("service.shared.gold", 1209)
	shared_gold.execute(EnterShopCommand.new("service.shared.gold.enter"))
	var shared_offer = _offer_of_kind(shared_gold.state.shop_state.offers, ShopOffer.RELIC)
	shared_gold.state.gold = shared_offer.price
	assert_true(shared_gold.execute(BuyShopOfferCommand.new("service.shared.gold.buy", shared_offer.offer_id, shared_gold.state.shop_state.entry_id)).accepted, "shared-Gold setup purchases the Shop offer", failures)
	shared_gold.execute(ExitShopCommand.new("service.shared.gold.exit"))
	shared_gold.execute(SelectMapNodeCommand.new("service.shared.gold.workshop-node", WORKSHOP))
	shared_gold.execute(EnterWorkshopCommand.new("service.shared.gold.workshop-enter"))
	shared_gold.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new("service.shared.gold.tile", "base.tile.characters.1", "RUN", "RUN"))
	var shared_before := shared_gold.checkpoint()
	var shared_remove = shared_gold.execute(UseWorkshopServiceCommand.new(
		"service.shared.gold.workshop-remove",
		UseWorkshopServiceCommand.REMOVE,
		"service.shared.gold.tile",
	))
	assert_true(not shared_remove.accepted and shared_remove.validation.code == "INSUFFICIENT_GOLD", "Shop and Workshop compete for the same Gold balance", failures)
	assert_true(shared_gold.checkpoint() == shared_before, "the shared-Gold rejection leaves both services unchanged", failures)

func test_service_commands_serialize_stable_ids(failures: Array[String]) -> void:
	var buy := BuyShopOfferCommand.new("ids.shop.buy", "shop.entry.1.offer.2", "shop.entry.1", "player.1")
	assert_true(buy.to_dictionary()["command_type"] == "BuyShopOffer", "Shop purchase command has a stable type", failures)
	assert_true(buy.to_dictionary()["offer_id"] == "shop.entry.1.offer.2", "Shop purchase command serializes the stable offer ID", failures)
	assert_true(not buy.to_dictionary().has("offer_index"), "Shop purchase command does not serialize a UI index", failures)

	var use := UseWorkshopServiceCommand.new("ids.workshop.use", UseWorkshopServiceCommand.TRANSFORM, "run.tile.7", "base.tile.bamboo.1", "", false, "player.1")
	assert_true(use.to_dictionary()["command_type"] == "UseWorkshopService", "Workshop command has a stable type", failures)
	assert_true(use.to_dictionary()["service_id"] == UseWorkshopServiceCommand.TRANSFORM, "Workshop command serializes the stable service ID", failures)
	assert_true(use.to_dictionary()["instance_id"] == "run.tile.7" and use.to_dictionary()["value_id"] == "base.tile.bamboo.1", "Workshop command serializes stable Tile and content IDs", failures)

func _shop_domain(run_id: String, seed: int) -> RunDomain:
	var domain := RunDomain.new(run_id, seed, _registry())
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	domain.execute(SelectMapNodeCommand.new("%s.intro" % run_id, INTRO))
	domain.execute(SelectMapNodeCommand.new("%s.left" % run_id, LEFT))
	domain.execute(SelectMapNodeCommand.new("%s.shop" % run_id, SHOP))
	return domain

func _workshop_domain(run_id: String, seed: int, tile_count: int) -> RunDomain:
	var domain := RunDomain.new(run_id, seed, _registry())
	domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
	domain.execute(SelectMapNodeCommand.new("%s.intro" % run_id, INTRO))
	domain.execute(SelectMapNodeCommand.new("%s.right" % run_id, RIGHT))
	domain.execute(SelectMapNodeCommand.new("%s.workshop" % run_id, WORKSHOP))
	domain.state.tile_pool.tile_instances.clear()
	for index in tile_count:
		domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
			"%s.tile.%d" % [run_id, index + 1],
			["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3", "base.tile.dots.1"][index % 4],
			"RUN",
			"RUN",
		))
	return domain

func _registry() -> ContentRegistry:
	var registry := ContentRegistry.new()
	RunStartingPoolContentFixture.register_character_starting_pool_tiles(registry)
	registry.register(TileDefinition.new("base.tile.bamboo.1", "bamboo", 1))
	registry.register(TileDefinition.new("base.tile.dots.1", "dots", 1))
	for relic_id in ["base.relic.open_hand", "base.relic.sequence_lens"]:
		registry.register(RelicDefinition.new(relic_id))
	registry.register(TechniqueDefinition.new("base.technique.draw_surge", TechniqueDefinition.ACTIVE, 1))
	registry.register(TechniqueDefinition.new("base.technique.reserve_exchange", TechniqueDefinition.REACTION, 1))
	registry.register(TechniqueDefinition.new("base.technique.core.sequence_line", TechniqueDefinition.CORE, 1))
	registry.register(TileModifierDefinition.new("base.modifier.flexible_identity", "FLEXIBLE_IDENTITY", 1))
	registry.register(TileModifierDefinition.new("base.modifier.recycling", "RECYCLING", 1))
	registry.register(ContentDefinition.new("base.passive.sequence"))
	registry.register(CharacterDefinition.new(
		"base.character.sequence",
		RunStartingPoolContentFixture.character_tile_pool_bias(),
		"base.relic.open_hand",
		"base.technique.core.sequence_line",
		"base.passive.sequence",
	))
	registry.register(ContractDefinition.new("base.contract.pressure", ContractDefinition.PRESSURE, {"pressure": 1}, {"draw_actions": 1}))
	return registry

func _offer_of_kind(offers: Array, kind: String):
	for offer in offers:
		if offer.kind == kind and offer.status == ShopOffer.AVAILABLE:
			return offer
	return null

func _has_offer_kind(offers: Array, kind: String) -> bool:
	return _offer_of_kind(offers, kind) != null

func _tile_by_id(domain: RunDomain, instance_id: String):
	for tile in domain.state.tile_pool.tile_instances:
		if tile.instance_id == instance_id:
			return tile
	return null

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
