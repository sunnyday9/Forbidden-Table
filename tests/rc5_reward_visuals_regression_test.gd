extends RefCounted

const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const RunScenePacked = preload("res://scenes/run/run_scene.tscn")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")
const RewardOptionScript = preload("res://src/domain/run/reward_option.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const CommandResultScript = preload("res://src/domain/commands/command_result.gd")
const RunJourneyViewScript = preload("res://src/presentation/ui/run_journey_view.gd")
const TileFaceButtonScript = preload("res://src/presentation/ui/tile_face_button.gd")
const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

const TILE_ID := "base.tile.characters.1"
const MODIFIER_ID := "base.modifier.flexible_identity"
const RELIC_ID := "base.relic.open_hand"
const TECHNIQUE_ID := "base.technique.draw_surge"
const RULE_BREAKER_ID := "base.rule_breaker.open_table"

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["RC5 reward visuals require a SceneTree"]
	var original_size := tree.root.size
	tree.root.size = Vector2i(1280, 800)
	var registry = _content_registry()
	var domain = RunDomainScript.new_alpha_run("rc5.reward.visuals.%d" % Time.get_ticks_usec(), 8405, registry)
	domain.state.phase = RunPhaseScript.REWARD_CHOICE
	var controller := RunPresentationControllerScript.new(domain)
	var view := RunJourneyViewScript.new()
	view.name = "RC5RewardJourney"
	view.configure(
		func(action: Dictionary) -> String: return _action_name(action),
		func(action: Dictionary) -> String: return _action_name(action),
		func(action: Dictionary) -> String: return _action_name(action),
		func(identifier: String) -> String: return LocalizationCatalogScript.content_text(identifier),
		func(word: String) -> String: return LocalizationCatalogScript.word_text(word),
	)
	view.set_presentation_preferences("en", 1.0)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(view)
	var actions := _reward_actions()
	view.render(controller, actions, "reward:add_tile")
	for _frame in 3:
		await tree.process_frame

	var tile_card := view.find_child("RewardCard_reward_add_tile", true, false) as Control
	var tile_face := tile_card.find_child("RewardTileFace", true, false) as TileFaceButtonScript if tile_card != null else null
	var tile_effect := tile_card.find_child("RewardEffectPreview", true, false) as Label if tile_card != null else null
	_assert(tile_face != null, "a normal tile reward shows the real Mahjong tile face inside its choice card")
	_assert(tile_face != null and tile_face.tile_definition_id == TILE_ID and tile_face.face_rect.texture != null, "the tile reward face uses the selected registered TileDefinition art")
	_assert(tile_effect != null and tile_effect.text == LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_ADD_TILE"), "a tile choice states its concrete add-to-pool effect")

	var modified_card := view.find_child("RewardCard_reward_modified_tile", true, false) as Control
	var modified_face := modified_card.find_child("RewardTileFace", true, false) as TileFaceButtonScript if modified_card != null else null
	var modified_effect := modified_card.find_child("RewardEffectPreview", true, false) as Label if modified_card != null else null
	_assert(modified_face != null and modified_face.tile_definition_id == TILE_ID, "a Modified Tile reward shows the actual target tile face")
	_assert(modified_face != null and modified_face.tile_annotations.size() > 0, "the Modified Tile preview marks the exact modifier that will be attached")
	_assert(modified_effect != null and modified_effect.text.find(LocalizationCatalogScript.content_text(MODIFIER_ID)) >= 0, "a Modified Tile choice names both the target and modifier effect")

	for action_id in ["reward:relic", "reward:technique", "reward:rule_breaker", "reward:skip"]:
		var card := view.find_child("RewardCard_%s" % action_id.replace(":", "_"), true, false) as Control
		_assert(card != null, "%s has a visual choice card" % action_id)
		var category_icon := card.find_child("RewardCategoryIcon", true, false) as Control if card != null else null
		var category_label := card.find_child("RewardCategoryLabel", true, false) as Label if card != null else null
		_assert(category_icon != null, "%s has a non-text visual category mark" % action_id)
		_assert(category_label != null and not category_label.text.is_empty(), "%s has a localized visible category label" % action_id)
		var effect_preview := card.find_child("RewardEffectPreview", true, false) as Label if card != null else null
		_assert(effect_preview != null and not effect_preview.text.is_empty(), "%s exposes a readable effect or payout before selection" % action_id)
	view.set_presentation_preferences("en", 1.5)
	view.render(controller, actions, "reward:add_tile")
	for _frame in 3:
		await tree.process_frame
	var scaled_reward_card := view.find_child("RewardCard_reward_relic", true, false) as Control
	var scaled_category := scaled_reward_card.find_child("RewardCategoryLabel", true, false) as Label if scaled_reward_card != null else null
	var scaled_effect := scaled_reward_card.find_child("RewardEffectPreview", true, false) as Label if scaled_reward_card != null else null
	_assert(scaled_category != null and scaled_category.get_theme_font_size("font_size") == ForbiddenThemeScript.font_size_for("caption", 1.5), "reward category labels use the shared caption role at 150% scale")
	_assert(scaled_effect != null and scaled_effect.get_theme_font_size("font_size") == ForbiddenThemeScript.font_size_for("secondary", 1.5), "reward effect labels use the shared secondary role at 150% scale")

	var receipt_path := "res://src/presentation/ui/run_reward_receipt_view.gd"
	var receipt_script: Script = load(receipt_path) if ResourceLoader.exists(receipt_path) else null
	_assert(receipt_script != null, "the journey can present an accepted reward receipt after phase transition")
	if receipt_script != null:
		_test_receipts(tree, registry, receipt_script)
		await _test_run_scene_receipt_integration(tree, receipt_script)

	view.queue_free()
	for _frame in 2:
		await tree.process_frame
	tree.root.size = original_size
	return _failures.duplicate()


func _content_registry():
	var registry := ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	AlphaScaleCatalogScript.register_all(registry)
	AlphaActTwoCatalogScript.register_all(registry)
	return registry


func _reward_actions() -> Array[Dictionary]:
	return [
		_reward_action("add_tile", "REWARD", "ADD_TILE", TILE_ID, {"tile_id": TILE_ID}),
		_reward_action("modified_tile", "REWARD", "MODIFIED_TILE", MODIFIER_ID, {"tile_id": TILE_ID, "modifier_id": MODIFIER_ID, "target_instance_id": "rc5.target.1"}),
		_reward_action("relic", "ELITE_REWARD", "RELIC", RELIC_ID, {}),
		_reward_action("technique", "ELITE_REWARD", "RUN_TECHNIQUE", TECHNIQUE_ID, {}),
		_reward_action("rule_breaker", "BOSS_REWARD", "RULE_BREAKER", RULE_BREAKER_ID, {}),
		_reward_action("skip", "REWARD", "SKIP", "base.reward.skip", {"gold_delta": 5, "refinement_token_delta": 0}),
	]


func _reward_action(suffix: String, kind: String, reward_kind: String, content_id: String, details: Dictionary) -> Dictionary:
	var reward_details := details.duplicate(true)
	reward_details["kind"] = reward_kind
	reward_details["content_id"] = content_id
	return {
		"id": "reward:%s" % suffix,
		"kind": kind,
		"target_id": content_id,
		"content_id": content_id,
		"details": reward_details,
	}


func _action_name(action: Dictionary) -> String:
	var details: Dictionary = action.get("details", {})
	if str(details.get("kind", "")) == "SKIP":
		return LocalizationCatalogScript.word_text("SKIP")
	return LocalizationCatalogScript.content_text(str(details.get("content_id", action.get("content_id", "Reward"))))


func _test_receipts(tree: SceneTree, registry, receipt_script: Script) -> void:
	var receipt = receipt_script.new()
	receipt.name = "RC5RewardReceipt"
	receipt.set_presentation_preferences("en", 1.0)
	tree.root.add_child(receipt)
	var tile_before := {"tile_pool": {"tile_instances": []}, "build_ownership": {"persistent_tile_modifier_state": {}}}
	var tile_after := {"tile_pool": {"tile_instances": [{"instance_id": "new.tile.1", "definition_id": TILE_ID}]}, "build_ownership": {"persistent_tile_modifier_state": {}}}
	var accepted_result := {
		"accepted": true,
		"events": [{"event_type": "RewardSelected", "data": {"kind": "ADD_TILE", "tile_id": TILE_ID, "tile_instance_id": "new.tile.1"}}],
	}
	_assert(bool(receipt.show_result(accepted_result, tile_before, tile_after, registry, 1.0)), "an accepted RewardSelected event creates a persistent receipt")
	_assert(receipt.visible, "the accepted reward receipt remains visible after the Journey switches phase")
	var receipt_face := receipt.find_child("ReceiptTileFace", true, false) as TextureRect
	_assert(receipt_face != null and receipt_face.texture != null, "the accepted tile receipt shows actual tile art")
	var receipt_title := receipt.find_child("ReceiptHeading", true, false) as Label
	_assert(receipt_title != null and receipt_title.text == LocalizationCatalogScript.text("UI_RUN_RECEIPT_TILE_ADDED"), "the receipt names the accepted tile effect")
	_assert(is_equal_approx(float(receipt.get("_ui_scale")), 1.0), "the receipt begins at the requested scale")
	_assert(receipt.find_child("ReceiptExpiry", true, false) == null, "the applied-effect receipt remains until the next ordinary choice without an arbitrary timer")
	for node in receipt.find_children("*", "Control", true, false):
		_assert(node.mouse_filter == Control.MOUSE_FILTER_IGNORE and node.focus_mode == Control.FOCUS_NONE, "passive receipt child %s does not intercept input or focus" % node.name)
	var preview_result := accepted_result.duplicate(true)
	preview_result["preview"] = true
	_assert(not bool(receipt.show_result(preview_result, tile_before, tile_after, registry, 1.5)), "a preview result cannot create an accepted-effect receipt")
	_assert(receipt.visible, "a rejected preview does not replace or clear a currently visible receipt")
	var rejected_result := accepted_result.duplicate(true)
	rejected_result["accepted"] = false
	_assert(not bool(receipt.show_result(rejected_result, tile_before, tile_after, registry, 1.5)), "a rejected result cannot create an accepted-effect receipt")
	receipt.set_presentation_preferences("zh_CN", 1.5)
	_assert(receipt.visible and str(receipt.get("_locale")) == "zh_CN", "locale refresh preserves a visible receipt and updates its locale")
	_assert(is_equal_approx(float(receipt.get("_ui_scale")), 1.5), "presentation preference refresh applies the requested scale")
	var scaled_heading := receipt.find_child("ReceiptHeading", true, false) as Label
	var scaled_title := receipt.find_child("ReceiptTitle", true, false) as Label
	var scaled_effect := receipt.find_child("ReceiptEffectDetails", true, false) as Label
	_assert(scaled_heading != null and scaled_heading.get_theme_font_size("font_size") == ForbiddenThemeScript.font_size_for("caption", 1.5), "receipt headings use the shared caption role at 150% scale")
	_assert(scaled_title != null and scaled_title.get_theme_font_size("font_size") == ForbiddenThemeScript.font_size_for("body", 1.5), "receipt titles use the shared body role at 150% scale")
	_assert(scaled_effect != null and scaled_effect.get_theme_font_size("font_size") == ForbiddenThemeScript.font_size_for("secondary", 1.5), "receipt effects use the shared secondary role at 150% scale")
	receipt.set_presentation_preferences("en", 1.0)
	receipt.clear_receipt()
	_assert(not receipt.visible, "the receipt can be cleared on the next player interaction")
	var modifier_before := {
		"tile_pool": {"tile_instances": [{"instance_id": "modifier.target", "definition_id": TILE_ID}]},
		"build_ownership": {"persistent_tile_modifier_state": {}},
	}
	var modifier_after := {
		"tile_pool": {"tile_instances": [{"instance_id": "modifier.target", "definition_id": TILE_ID}]},
		"build_ownership": {"persistent_tile_modifier_state": {"modifier.target": [MODIFIER_ID]}},
	}
	var modifier_result := {
		"accepted": true,
		"events": [{"event_type": "RewardSelected", "data": {"kind": "MODIFIED_TILE", "tile_id": TILE_ID, "modifier_id": MODIFIER_ID, "target_instance_id": "modifier.target"}}],
	}
	_assert(bool(receipt.show_result(modifier_result, modifier_before, modifier_after, registry, 1.0)), "an accepted Modified Tile reward creates a receipt")
	_assert(receipt.find_child("ReceiptTileFace", true, false) is TextureRect and receipt.find_child("ReceiptTileFace_1", true, false) is TextureRect, "Modified Tile receipt shows actual before and after tile art")
	var modifier_effect: Label = receipt.find_child("ReceiptEffectDetails", true, false) as Label
	_assert(modifier_effect != null and modifier_effect.text.contains(LocalizationCatalogScript.content_text(MODIFIER_ID)), "Modified Tile receipt names the concrete modifier effect")
	var tile_transition := receipt.find_child("ReceiptTileTransition", true, false) as Label
	_assert(tile_transition != null and tile_transition.text == LocalizationCatalogScript.text("UI_RUN_TILE_TRANSITION"), "the before/after tile marker uses the localized transition label")
	receipt.set_presentation_preferences("zh_CN", 1.5)
	tile_transition = receipt.find_child("ReceiptTileTransition", true, false) as Label
	_assert(tile_transition != null and tile_transition.text == LocalizationCatalogScript.text("UI_RUN_TILE_TRANSITION"), "the before/after tile marker refreshes in Simplified Chinese")
	receipt.set_presentation_preferences("en", 1.0)
	receipt.clear_receipt()
	var shop_result := {
		"accepted": true,
		"events": [{"event_type": "ShopOfferPurchased", "data": {"offer": {"kind": "SPECIAL", "content_id": "base.special.gold_cache", "metadata": {"special_action": "GOLD_CACHE"}}, "currency_transactions": [{"currency": "GOLD", "amount": -5}, {"currency": "GOLD", "amount": 3}]}}],
	}
	_assert(bool(receipt.show_result(shop_result, {}, {}, registry, 1.0)), "an accepted special Shop purchase creates a receipt")
	var shop_icon: Control = receipt.find_child("ReceiptCategoryIcon", true, false) as Control
	var shop_category: Label = receipt.find_child("ReceiptCategoryLabel", true, false) as Label
	var shop_effect: Label = receipt.find_child("ReceiptEffectDetails", true, false) as Label
	_assert(shop_icon != null and str(shop_icon.get("kind")) == "SPECIAL" and shop_category != null and shop_category.text == LocalizationCatalogScript.text("UI_RUN_REWARD_KIND_SPECIAL"), "a non-tile Shop item has its own visible category icon and label")
	_assert(shop_effect != null and shop_effect.text.contains("−5") and shop_effect.text.count("+3") == 1, "Shop receipt shows exact cost and payout once each")
	receipt.clear_receipt()
	var remove_before := {"tile_pool": {"tile_instances": [{"instance_id": "remove.target", "definition_id": TILE_ID}]}, "build_ownership": {"persistent_tile_modifier_state": {}}}
	var remove_after := {"tile_pool": {"tile_instances": []}, "build_ownership": {"persistent_tile_modifier_state": {}}}
	var remove_result := {
		"accepted": true,
		"events": [
			{"event_type": "TileRemoved", "data": {"instance_id": "remove.target", "scope": "RUN_TILE_POOL"}},
			{"event_type": "WorkshopServiceUsed", "data": {"service_id": "REMOVE", "instance_id": "remove.target", "currency_transactions": [{"currency": "GOLD", "amount": -4}]}}],
	}
	_assert(bool(receipt.show_result(remove_result, remove_before, remove_after, registry, 1.0)), "an accepted Workshop removal creates a receipt")
	var removed_face: TextureRect = receipt.find_child("ReceiptTileFace", true, false) as TextureRect
	var remove_icon: Control = receipt.find_child("ReceiptCategoryIcon", true, false) as Control
	var remove_effect: Label = receipt.find_child("ReceiptEffectDetails", true, false) as Label
	var remove_heading: Label = receipt.find_child("ReceiptHeading", true, false) as Label
	_assert(removed_face != null and removed_face.texture != null and remove_icon != null and str(remove_icon.get("kind")) == "REMOVE", "Workshop removal shows the actual removed tile and a distinct remove mark")
	_assert(remove_heading != null and remove_heading.text == LocalizationCatalogScript.text("UI_RUN_RECEIPT_TILE_REMOVED") and remove_effect != null and remove_effect.text.contains("−4"), "Workshop removal receipt names the change and its Gold cost")
	receipt.clear_receipt()
	var non_tile_rewards := [
		{"kind": "SKIP", "content_id": "base.reward.skip", "currency_transactions": [{"currency": "GOLD", "amount": 5}]},
		{"kind": "RELIC", "content_id": RELIC_ID},
		{"kind": "RUN_TECHNIQUE", "content_id": TECHNIQUE_ID},
		{"kind": "RULE_BREAKER", "content_id": RULE_BREAKER_ID},
	]
	for reward_data in non_tile_rewards:
		var reward_result := {"accepted": true, "events": [{"event_type": "RewardSelected", "data": reward_data}]}
		_assert(bool(receipt.show_result(reward_result, {}, {}, registry, 1.0)), "the %s reward result creates an applied-effect receipt" % reward_data.kind)
		var kind_icon := receipt.find_child("ReceiptCategoryIcon", true, false) as Control
		var kind_label := receipt.find_child("ReceiptCategoryLabel", true, false) as Label
		var kind_effect := receipt.find_child("ReceiptEffectDetails", true, false) as Label
		var label_suffix := "TECHNIQUE" if reward_data.kind == "RUN_TECHNIQUE" else str(reward_data.kind)
		_assert(kind_icon != null and str(kind_icon.get("kind")) == str(reward_data.kind), "%s receipt uses its own visual category mark" % reward_data.kind)
		_assert(kind_label != null and kind_label.text == LocalizationCatalogScript.text("UI_RUN_REWARD_KIND_%s" % label_suffix), "%s receipt has a localized category label" % reward_data.kind)
		_assert(kind_effect != null and not kind_effect.text.is_empty(), "%s receipt explains its actual effect or payout" % reward_data.kind)
		receipt.clear_receipt()
	receipt.queue_free()
	for _frame in 2:
		await tree.process_frame


func _test_run_scene_receipt_integration(tree: SceneTree, receipt_script: Script) -> void:
	var suffix := str(Time.get_ticks_usec())
	var suspend_path := "user://rc5_reward_receipt_integration_%s.json" % suffix
	var profile_path := "user://rc5_reward_receipt_profile_%s.json" % suffix
	var previous_size := tree.root.size
	tree.root.size = Vector2i(960, 540)
	var scene = RunScenePacked.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	tree.root.add_child(scene)
	for _frame in 4:
		await tree.process_frame
	var receipt = scene.find_child("RunRewardReceipt", true, false)
	_assert(receipt != null and receipt.get_script() == receipt_script, "the real RunScene builds and hosts the reward receipt component")
	var registry = scene.get("_content_registry")
	if registry == null or receipt == null:
		_assert(false, "the isolated RunScene integration fixture has its registered content and hosted receipt")
		tree.root.remove_child(scene)
		scene.free()
		tree.root.size = previous_size
		return
	var domain = RunDomainScript.new_alpha_run(
		"rc5.receipt.integration.%s" % suffix,
		8407,
		registry,
		"",
		null,
		null,
		MetaProgressStateScript.all_unlocked_test_profile(),
	)
	var character_result = domain.execute(ChooseCharacterCommandScript.new("rc5.receipt.character", "base.character.sequence"))
	var contract_result = domain.execute(ChooseContractCommandScript.new("rc5.receipt.contract", "base.contract.pressure"))
	_assert(character_result.accepted and contract_result.accepted, "the isolated domain reaches a valid selected Character and Contract")
	var draft = domain.reward_draft_selector.create_normal_draft(domain.state, registry, domain.rng_streams.reward, "rc5.receipt.encounter", 1)
	_assert(draft != null, "the controller fixture uses a real typed reward draft")
	if draft == null:
		tree.root.remove_child(scene)
		scene.free()
		tree.root.size = previous_size
		return
	domain.state.reward_draft = draft
	domain.state.phase = RunPhaseScript.REWARD_CHOICE
	var controller = RunPresentationControllerScript.new(domain)
	scene.call("_set_active_controller", controller)
	for _frame in 4:
		await tree.process_frame
	var add_actions: Array = controller.action_descriptors().filter(func(action):
		return str(action.get("kind", "")) == "REWARD" and str(action.get("details", {}).get("kind", "")) == RewardOptionScript.ADD_TILE
	)
	_assert(add_actions.size() == 1, "the integrated Reward phase exposes its actual Add Tile option")
	if add_actions.is_empty():
		tree.root.remove_child(scene)
		scene.free()
		tree.root.size = previous_size
		return
	var result = controller.confirm(str(add_actions[0].get("id", "")))
	_assert(result.accepted and str(domain.state.phase) == RunPhaseScript.MAP_CHOICE, "the accepted reward command performs the real Reward-to-Map transition")
	_assert(receipt.visible, "the RunScene command_processed connection retains the accepted reward receipt after transition")
	_assert(receipt.find_child("ReceiptTileFace", true, false) is TextureRect, "the integrated receipt contains tile art from the accepted result")
	for _frame in 4:
		await tree.process_frame
	var chrome := scene.find_child("RunWindowChrome", true, false) as Control
	var receipt_rect: Rect2 = receipt.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	var receipt_content_diagnostic := receipt.find_child("ReceiptContent", true, false) as Control
	_assert(chrome != null and receipt_rect.size.y > 0.0 and receipt_rect.size.x <= viewport_rect.size.x and viewport_rect.encloses(receipt_rect), "the pinned receipt is fully enclosed by the 960x540 viewport (receipt=%s min=%s combined=%s content_min=%s content=%s viewport=%s chrome=%s)" % [receipt_rect, receipt.custom_minimum_size, receipt.get_combined_minimum_size(), receipt_content_diagnostic.get_combined_minimum_size() if receipt_content_diagnostic != null else Vector2.ZERO, receipt_content_diagnostic.size if receipt_content_diagnostic != null else Vector2.ZERO, viewport_rect, chrome.get_global_rect() if chrome != null else Rect2()])
	var focused_before := str(controller.snapshot().get("focused_action_id", ""))
	controller.focus_next()
	var focused_after := str(controller.snapshot().get("focused_action_id", ""))
	_assert(receipt.visible, "normal focus movement leaves the accepted receipt visible")
	if controller.action_descriptors().size() > 1:
		_assert(focused_after != focused_before, "the Map fixture has multiple focus targets and controller navigation advances one")
	var preview := CommandResultScript.new("rc5.preview", "ChooseRewardCommand", "", "", true, CommandResultScript.PREVIEW_ONLY, null, [], {}, {}, true)
	controller.command_processed.emit(null, preview)
	_assert(receipt.visible, "the RunScene host ignores preview command results without clearing the accepted receipt")
	var rejected := CommandResultScript.new("rc5.rejected", "ChooseRewardCommand", "", "", false, CommandResultScript.REJECTED)
	controller.command_processed.emit(null, rejected)
	_assert(receipt.visible, "the RunScene host ignores rejected command results without clearing the accepted receipt")
	scene.call("_apply_presentation_preferences", {"locale": "zh_CN", "ui_scale": 1.5, "presentation_mode": "NORMAL", "reduced_motion": false, "ambient_glow": true}, true)
	for _frame in 4:
		await tree.process_frame
	_assert(receipt.visible and str(receipt.get("_locale")) == "zh_CN" and is_equal_approx(float(receipt.get("_ui_scale")), 1.5), "RunScene locale and scale refreshes preserve and reflow the accepted receipt")
	var scaled_rect: Rect2 = receipt.get_global_rect()
	var scaled_viewport := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	_assert(scaled_viewport.encloses(scaled_rect), "the 150%% preference reflow keeps the receipt inside the 960x540 viewport (receipt=%s viewport=%s)" % [scaled_rect, scaled_viewport])
	var next_map_action_id := await _focus_and_assert_map_choice_reachable(scene, controller, "960x540 at 150%")
	tree.root.size = Vector2i(390, 844)
	for _frame in 5:
		await tree.process_frame
	var before_modified := {
		"tile_pool": {"tile_instances": [{"instance_id": "rc5.modified.target", "definition_id": TILE_ID}]},
		"build_ownership": {"persistent_tile_modifier_state": {}},
	}
	var after_modified := {
		"tile_pool": {"tile_instances": [{"instance_id": "rc5.modified.target", "definition_id": TILE_ID}]},
		"build_ownership": {"persistent_tile_modifier_state": {"rc5.modified.target": [MODIFIER_ID]}},
	}
	var modified_result := {
		"accepted": true,
		"events": [{"event_type": "RewardSelected", "data": {"kind": "MODIFIED_TILE", "tile_id": TILE_ID, "modifier_id": MODIFIER_ID, "target_instance_id": "rc5.modified.target"}}],
	}
	_assert(bool(receipt.show_result(modified_result, before_modified, after_modified, registry, 1.5)), "the pinned receipt can present a modifier result at narrow 150%% scale")
	for _frame in 4:
		await tree.process_frame
	var portrait_rect: Rect2 = receipt.get_global_rect()
	var portrait_viewport := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	var receipt_content := receipt.find_child("ReceiptContent", true, false) as BoxContainer
	var before_face := receipt.find_child("ReceiptTileFace", true, false) as TextureRect
	var after_face := receipt.find_child("ReceiptTileFace_1", true, false) as TextureRect
	var modifier_label := receipt.find_child("ReceiptTileModifier", true, false) as Label
	var effect_details := receipt.find_child("ReceiptEffectDetails", true, false) as Label
	_assert(receipt_content != null and receipt_content.vertical, "the 390px viewport switches the receipt into a vertical compact layout")
	_assert(before_face != null and before_face.texture != null and after_face != null and after_face.texture != null and modifier_label != null and modifier_label.text.contains(LocalizationCatalogScript.content_text(MODIFIER_ID)), "the narrow modifier receipt shows actual before/after tiles and the acquired modifier")
	_assert(effect_details != null and effect_details.text.contains(LocalizationCatalogScript.content_text(MODIFIER_ID)), "the narrow modifier receipt keeps its concrete effect visible")
	_assert(portrait_rect.size.x <= portrait_viewport.size.x and portrait_viewport.encloses(portrait_rect) and portrait_rect.size.y <= 360.0, "the 390x844/150%% modifier receipt remains bounded inside the portrait viewport (receipt=%s viewport=%s)" % [portrait_rect, portrait_viewport])
	var portrait_map_action_id := await _focus_and_assert_map_choice_reachable(scene, controller, "390x844 at 150%")
	for node in [receipt.find_child("ReceiptHeading", true, false), receipt.find_child("ReceiptTitle", true, false), effect_details]:
		if node is Control and node.visible:
			_assert(portrait_rect.encloses(node.get_global_rect()), "visible receipt text stays inside the portrait card: %s" % node.name)
	var map_actions: Array = controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "MAP_NODE" and bool(action.get("available", true)))
	_assert(not map_actions.is_empty(), "the transitioned Map phase exposes a real next choice")
	if not map_actions.is_empty():
		var action_to_activate := portrait_map_action_id if not portrait_map_action_id.is_empty() else next_map_action_id
		_assert(not action_to_activate.is_empty(), "the next authoritative Map choice was the same reachable control checked above")
		var next_result = scene.call("_on_action_pressed", action_to_activate)
		_assert(next_result != null and next_result.accepted, "the player can make the next authoritative Map choice")
		_assert(not receipt.visible, "the accepted reward receipt clears on the next ordinary choice")
	_assert(not FileAccess.file_exists(suspend_path) and not FileAccess.file_exists(profile_path), "the direct domain/controller integration creates no suspend or profile save files")
	tree.root.remove_child(scene)
	scene.free()
	tree.root.size = previous_size


func _focus_and_assert_map_choice_reachable(scene, controller, viewport_label: String) -> String:
	var map_action_id := ""
	for action in controller.action_descriptors():
		if str(action.get("kind", "")) == "MAP_NODE" and bool(action.get("available", true)):
			map_action_id = str(action.get("id", ""))
			break
	var button: Button = scene._journey_view.action_button(map_action_id) if scene._journey_view != null else null
	var scroll := scene.find_child("RunRootScroll", true, false) as ScrollContainer
	if button == null or scroll == null or map_action_id.is_empty():
		_assert(false, "an available Map choice button remains present after receipt reflow at %s" % viewport_label)
		return ""
	button.grab_focus()
	for _frame in 4:
		await scene.get_tree().process_frame
	var action_rect: Rect2 = button.get_global_rect()
	var scroll_rect: Rect2 = scroll.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, scene.get_viewport_rect().size)
	var visible_scroll_rect := scroll_rect.intersection(viewport_rect)
	var scroll_bar := scroll.get_v_scroll_bar()
	_assert(button.is_visible_in_tree() and not button.disabled and visible_scroll_rect.encloses(action_rect), "the actual next Map choice button is enabled and wholly reachable under the pinned receipt at %s (id=%s button=%s scroll=%s visible_scroll=%s scroll_y=%d range=%s/%s root=%s)" % [viewport_label, map_action_id, action_rect, scroll_rect, visible_scroll_rect, scroll.scroll_vertical, scroll_bar.max_value, scroll_bar.page, viewport_rect])
	_assert(scene.get_viewport().gui_get_focus_owner() == button, "the reachable next Map choice can receive focus at %s (id=%s owner=%s)" % [viewport_label, map_action_id, scene.get_viewport().gui_get_focus_owner()])
	return map_action_id


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
