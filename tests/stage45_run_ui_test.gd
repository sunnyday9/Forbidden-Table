class_name Stage45RunUiTest
extends RefCounted

const RunScene = preload("res://scenes/run/run_scene.tscn")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const OnboardingFlowTest = preload("res://tests/stage4_onboarding_flow_test.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const RunSummaryViewScript = preload("res://src/presentation/ui/run_summary_view.gd")

class RejectingSuspendStore extends RefCounted:
	var writes := 0
	func write_snapshot(_snapshot) -> Dictionary:
		writes += 1
		return {"accepted": false, "code": "TEST_WRITE_FAILED"}
	func clear() -> Dictionary:
		return {"accepted": true}

class UnpreservedProfileStore extends MetaProgressStoreScript:
	var write_attempts := 0
	func preserve_rejected_source() -> Dictionary:
		return {"accepted": false, "code": "TEST_PRESERVATION_DENIED"}
	func save_profile(state) -> Dictionary:
		write_attempts += 1
		return super.save_profile(state)

const SelectMapNodeCommandScript = preload("res://src/domain/commands/select_map_node_command.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	test_character_contract_selection_and_map_state(failures)
	await test_shop_and_workshop_one_press(failures)
	await test_terminal_warning_and_receipt(failures)
	await test_suspend_recovery_locale_and_disclosure(failures)
	await test_profile_recovery_locale_and_disclosure(failures)
	await test_unpreserved_profile_recovery(failures)
	await test_ultrawide_content_width_caps(failures)
	return failures


func test_ultrawide_content_width_caps(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var original_window_size := tree.root.size
	tree.root.size = Vector2i(1920, 1080)
	var scene = await _new_input_scene("wide_content_caps", tree)
	for _frame in range(4):
		await tree.process_frame
	var cards: Array = scene._journey_view.find_children("CharacterCard_*", "PanelContainer", true, false)
	assert_true(cards.size() == 3, "ultrawide Character selection keeps all three authored cards", failures)
	for card in cards:
		assert_true((card as Control).size.x <= 520.0, "ultrawide Character card stays within the readable-width cap (%.0fpx)" % (card as Control).size.x, failures)

	var summary_host := Control.new()
	summary_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(summary_host)
	var summary_view = RunSummaryViewScript.new()
	summary_host.add_child(summary_view)
	summary_view.render(null, "A readable run chronicle with a recorded ending.", "en", 1.0)
	for _frame in range(4):
		await tree.process_frame
	for panel_name in ["BuildChroniclePanel", "RunOutcomePanel"]:
		var panel := summary_view.find_child(panel_name, true, false) as Control
		assert_true(panel != null and panel.size.x <= 760.0, "ultrawide %s stays within the readable-width cap (%.0fpx)" % [panel_name, panel.size.x if panel != null else -1.0], failures)

	summary_host.queue_free()
	_free_scene(scene)
	tree.root.size = original_window_size
	await tree.process_frame


func test_character_contract_selection_and_map_state(failures: Array[String]) -> void:
	var scene = _new_scene("journey_selection")
	var controller = scene.controller
	var view = scene._journey_view
	var character_action := _first_action(controller.action_descriptors(), "CHARACTER")
	var character_id := str(character_action.get("id", ""))
	var character_button: Button = view.action_button(character_id)
	assert_true(character_button != null, "each unlocked Character has a real selectable card control", failures)
	assert_true(view.find_children("CharacterCard_*", "PanelContainer", true, false).size() == 3, "the starting Character gallery is the three authored cosmetic portraits", failures)
	for card in view.find_children("CharacterCard_*", "PanelContainer", true, false):
		var portrait := card.find_child("CharacterPortrait", true, false) as TextureRect
		assert_true(portrait != null and portrait.texture is AtlasTexture, "each Character retains its distinct cropped triptych portrait", failures)
		if portrait != null and portrait.texture is AtlasTexture:
			assert_true(is_equal_approx((portrait.texture as AtlasTexture).region.size.y, 907.0 * 0.34), "portrait crop uses the face-focused source strip", failures)

	var checkpoint_before: Dictionary = controller.domain.checkpoint()
	var replay_before: String = controller.domain.replay_record.serialize()
	var command_count: int = controller._command_sequence
	view._on_choice_focused(character_id)
	assert_true(view.focused_action_id == character_id and view.selected_action_id.is_empty(), "focus reveals a Character without selecting it", failures)
	view._on_choice_hovered(character_id)
	assert_true(controller.domain.checkpoint() == checkpoint_before and controller.domain.replay_record.serialize() == replay_before and controller._command_sequence == command_count, "focus and hover inspect a Character without mutating Run state or creating a command", failures)
	character_button.emit_signal("pressed")
	assert_true(controller.domain.state.phase == RunPhaseScript.CONTRACT_SELECT, "one Character card press routes directly through RunPresentationController", failures)
	assert_true(controller._command_sequence == command_count + 1 and controller.domain.replay_record.commands.size() == 1, "one Character press produces exactly one accepted command", failures)

	var contract_action := _first_action(controller.action_descriptors(), "CONTRACT")
	var contract_id := str(contract_action.get("id", ""))
	var contract_button: Button = view.action_button(contract_id)
	assert_true(contract_button != null and not contract_button.text.is_empty(), "Contract selection displays its actual localized name and descriptor", failures)
	var before_contract: Dictionary = controller.domain.checkpoint()
	var before_contract_count: int = controller._command_sequence
	view._on_choice_focused(contract_id)
	assert_true(view.focused_action_id == contract_id and view.selected_action_id.is_empty(), "Contract keyboard focus remains independent from its selection state", failures)
	var before_contract_replay: String = controller.domain.replay_record.serialize()
	view._on_choice_hovered(contract_id)
	assert_true(controller.domain.checkpoint() == before_contract and controller.domain.replay_record.serialize() == before_contract_replay and controller._command_sequence == before_contract_count, "focused and hovered Contract inspection does not commit gameplay", failures)
	contract_button.emit_signal("pressed")
	assert_true(controller.domain.state.phase == RunPhaseScript.MAP_CHOICE, "one Contract card press opens the real map state", failures)
	assert_true(controller._command_sequence == before_contract_count + 1 and controller.domain.replay_record.commands.size() == 2, "one Contract press produces exactly one accepted command", failures)

	var map_view: Node = view.find_child("RunMapView", true, false)
	assert_true(map_view != null, "Map Choice renders the authored graph from current Run state", failures)
	if map_view != null:
		var map_action_count := 0
		for action in controller.action_descriptors():
			if str(action.get("kind", "")) != "MAP_NODE":
				continue
			map_action_count += 1
			var node_button: Button = view.action_button(str(action.get("id", "")))
			assert_true(node_button != null and node_button.has_meta("run_action_id"), "each eligible map node keeps its existing stable action ID", failures)
			var visible_label := node_button.find_child("MapNodeLabel", true, false) as Label if node_button != null else null
			assert_true(visible_label != null and not visible_label.text.is_empty(), "map node status is readable inside each graph control", failures)
			if node_button != null:
				assert_true(not node_button.accessibility_name.is_empty(), "map node controls expose a screen-reader name", failures)
		assert_true(map_action_count > 0, "actual eligible route choices populate the map", failures)

	var map_checkpoint: Dictionary = controller.domain.checkpoint()
	var map_replay: String = controller.domain.replay_record.serialize()
	var active_locale := str(scene._applied_preferences.get("locale", "en"))
	scene._apply_presentation_preferences({"locale": "zh_CN", "ui_scale": 1.25, "presentation_mode": "NORMAL", "reduced_motion": false, "ambient_glow": true}, true)
	assert_true(controller.domain.checkpoint() == map_checkpoint and controller.domain.replay_record.serialize() == map_replay, "localized refresh changes only presentation descriptors, not checkpoint or replay bytes", failures)
	scene._apply_presentation_preferences({"locale": active_locale, "ui_scale": 1.0, "presentation_mode": "NORMAL", "reduced_motion": false, "ambient_glow": true}, true)
	_free_scene(scene)


func test_shop_and_workshop_one_press(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene = await _new_input_scene("journey_service_review", tree)
	var initial_preferences: Dictionary = scene._applied_preferences.duplicate(true)
	var shop_domain = _service_fixture_domain(scene, "shop")
	scene._attach_controller(shop_domain)
	scene._render()
	var view = scene._journey_view
	var enter_shop: Button = view.action_button("run.enter.shop")
	assert_true(enter_shop != null, "the current Shop room exposes its existing Enter Shop action", failures)
	if enter_shop == null:
		_free_scene(scene)
		return
	var before_entry: Dictionary = shop_domain.checkpoint()
	var before_entry_replay: String = shop_domain.replay_record.serialize()
	var before_entry_replay_count: int = shop_domain.replay_record.commands.size()
	var command_count: int = scene.controller._command_sequence
	_assert_choice_inspection_does_not_execute(scene, "run.enter.shop", "Enter Shop", failures)
	enter_shop.grab_focus()
	await _send_run_action(scene, "ui_accept", tree)
	assert_true(shop_domain.state.phase == RunPhaseScript.SHOP, "one Enter Shop press enters the current room", failures)
	assert_true(scene.controller._command_sequence == command_count + 1 and shop_domain.replay_record.commands.size() == before_entry_replay_count + 1 and shop_domain.replay_record.serialize() != before_entry_replay, "one Enter Shop press dispatches exactly one authoritative command", failures)

	var shop_offer: Dictionary = {}
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) != "SHOP_OFFER":
			continue
		var candidate: Button = view.action_button(str(action.get("id", "")))
		if candidate != null and not candidate.disabled:
			shop_offer = action
			break
	assert_true(not shop_offer.is_empty(), "Shop UI contains an actual affordable unsold offer", failures)
	if shop_offer.is_empty():
		_free_scene(scene)
		return
	var offer_id := str(shop_offer.get("id", ""))
	var offer_details: Dictionary = shop_offer.get("details", {})
	var offer_button: Button = view.action_button(offer_id)
	var gold_before: int = shop_domain.state.gold
	var offer_checkpoint: Dictionary = shop_domain.checkpoint()
	var offer_replay: String = shop_domain.replay_record.serialize()
	var offer_replay_count: int = shop_domain.replay_record.commands.size()
	var offer_command_count: int = scene.controller._command_sequence
	_assert_choice_inspection_does_not_execute(scene, offer_id, "Shop offer", failures)
	await _audit_action_locale_switch(scene, offer_id, failures)
	offer_button = view.action_button(offer_id)
	assert_true(offer_button != null and not offer_button.disabled, "the localized Shop offer remains available at enlarged UI scale", failures)
	if offer_button == null or offer_button.disabled:
		_restore_run_scene_preferences(scene, initial_preferences)
		_free_scene(scene)
		return
	offer_button.grab_focus()
	await _send_run_action(scene, "ui_accept", tree)
	var stored_offer = shop_domain.state.shop_state.offer_by_id(str(offer_details.get("offer_id", shop_offer.get("target_id", ""))))
	assert_true(stored_offer != null and str(stored_offer.status) == "SOLD", "one Shop offer press routes the exact displayed offer", failures)
	assert_true(shop_domain.state.gold < gold_before and scene.controller._command_sequence == offer_command_count + 1 and shop_domain.replay_record.commands.size() == offer_replay_count + 1 and shop_domain.replay_record.serialize() != offer_replay, "one purchase press charges Gold and creates exactly one authoritative command", failures)
	assert_true(shop_domain.checkpoint() != offer_checkpoint and view.selected_action_id.is_empty(), "the accepted Shop action updates Run state and clears its local selection", failures)

	scene._apply_presentation_preferences({"locale": "en", "ui_scale": 1.0, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
	var workshop_domain = _service_fixture_domain(scene, "workshop")
	scene._attach_controller(workshop_domain)
	scene._render()
	var enter_workshop: Button = view.action_button("run.enter.workshop")
	assert_true(enter_workshop != null, "the current Workshop room exposes its existing Enter Workshop action", failures)
	if enter_workshop == null:
		_restore_run_scene_preferences(scene, initial_preferences)
		_free_scene(scene)
		return
	_assert_choice_inspection_does_not_execute(scene, "run.enter.workshop", "Enter Workshop", failures)
	enter_workshop.grab_focus()
	await _send_run_action(scene, "ui_accept", tree)
	assert_true(workshop_domain.state.phase == RunPhaseScript.WORKSHOP and scene.controller._command_sequence == 1, "one Enter Workshop press enters the actual active Workshop state", failures)
	var service_action := _action_with_kind(scene.controller.action_descriptors(), "WORKSHOP_SELECT_SERVICE", "service_id", "TRANSFORM")
	var service_id := str(service_action.get("id", ""))
	var service_button: Button = view.action_button(service_id)
	assert_true(service_button != null, "Workshop renders legal service choices from the controller", failures)
	if service_button == null:
		_restore_run_scene_preferences(scene, initial_preferences)
		_free_scene(scene)
		return
	var workshop_before: Dictionary = workshop_domain.checkpoint()
	var workshop_replay: String = workshop_domain.replay_record.serialize()
	var workshop_command_count: int = scene.controller._command_sequence
	_assert_choice_inspection_does_not_execute(scene, service_id, "Workshop service", failures)
	service_button.grab_focus()
	await _send_run_action(scene, "ui_accept", tree)
	assert_true(workshop_domain.checkpoint() == workshop_before and workshop_domain.replay_record.serialize() == workshop_replay and scene.controller._command_sequence == workshop_command_count, "one Workshop service press changes only the presentation selection", failures)
	var target_action := _first_action(scene.controller.action_descriptors(), "WORKSHOP_SELECT_TARGET")
	var target_button: Button = view.action_button(str(target_action.get("id", "")))
	assert_true(target_button != null, "the selected Workshop service presents its actual legal TileInstance targets", failures)
	if target_button == null:
		_restore_run_scene_preferences(scene, initial_preferences)
		_free_scene(scene)
		return
	var target_checkpoint: Dictionary = workshop_domain.checkpoint()
	var target_replay: String = workshop_domain.replay_record.serialize()
	var target_command_count: int = scene.controller._command_sequence
	_assert_choice_inspection_does_not_execute(scene, str(target_action.get("id", "")), "Workshop Tile target", failures)
	target_button.grab_focus()
	await _send_run_action(scene, "ui_accept", tree)
	assert_true(workshop_domain.checkpoint() == target_checkpoint and workshop_domain.replay_record.serialize() == target_replay and scene.controller._command_sequence == target_command_count, "one Workshop target press changes only the presentation selection", failures)
	var change_action := _first_action(scene.controller.action_descriptors(), "WORKSHOP_SERVICE")
	var change_button: Button = view.action_button(str(change_action.get("id", "")))
	assert_true(change_button != null and view.find_child("WorkshopBeforeAfter", true, false) != null, "Workshop previews the exact before / after target and cost", failures)
	if change_button == null:
		_restore_run_scene_preferences(scene, initial_preferences)
		_free_scene(scene)
		return
	assert_true(str(change_action.get("service_id", "")) == "TRANSFORM" and str(change_action.get("instance_id", "")) == str(target_action.get("instance_id", "")), "the final Workshop action keeps the chosen service and exact target", failures)
	await _audit_action_locale_switch(scene, str(change_action.get("id", "")), failures)
	change_action = _first_action(scene.controller.action_descriptors(), "WORKSHOP_SERVICE")
	change_button = view.action_button(str(change_action.get("id", "")))
	var selected_tile_id := str(change_action.get("instance_id", ""))
	var old_definition_id := str(workshop_domain.tile_pool_editor.find_instance(selected_tile_id).definition_id)
	var chosen_definition_id := str(change_action.get("value_id", ""))
	var change_checkpoint: Dictionary = workshop_domain.checkpoint()
	var change_replay: String = workshop_domain.replay_record.serialize()
	var change_replay_count: int = workshop_domain.replay_record.commands.size()
	var final_command_count: int = scene.controller._command_sequence
	_assert_choice_inspection_does_not_execute(scene, str(change_action.get("id", "")), "Workshop result", failures)
	change_button.grab_focus()
	await _send_run_action(scene, "ui_accept", tree)
	var updated_tile = workshop_domain.tile_pool_editor.find_instance(selected_tile_id)
	assert_true(updated_tile != null and str(updated_tile.definition_id) == chosen_definition_id and chosen_definition_id != old_definition_id, "one Workshop result press applies the exact chosen transform to the exact TileInstance", failures)
	assert_true(workshop_domain.checkpoint() != change_checkpoint and scene.controller._command_sequence == final_command_count + 1 and workshop_domain.replay_record.commands.size() == change_replay_count + 1 and workshop_domain.replay_record.serialize() != change_replay, "one Workshop service press creates exactly one authoritative command", failures)
	assert_true(view.selected_action_id.is_empty(), "an accepted Workshop service clears its local selection", failures)
	_restore_run_scene_preferences(scene, initial_preferences)
	_free_scene(scene)


func _assert_choice_inspection_does_not_execute(scene, action_id: String, description: String, failures: Array[String]) -> void:
	var view = scene._journey_view
	var checkpoint: Dictionary = scene.controller.domain.checkpoint()
	var replay: String = scene.controller.domain.replay_record.serialize()
	var command_count: int = scene.controller._command_sequence
	view._on_choice_focused(action_id)
	view._on_choice_hovered(action_id)
	assert_true(view.focused_action_id == action_id and scene.controller.domain.checkpoint() == checkpoint and scene.controller.domain.replay_record.serialize() == replay and scene.controller._command_sequence == command_count, "%s focus and hover inspect the choice without executing it" % description, failures)


func _audit_action_locale_switch(scene, action_id: String, failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var view = scene._journey_view
	var original_preferences: Dictionary = scene._applied_preferences.duplicate(true)
	var checkpoint: Dictionary = scene.controller.domain.checkpoint()
	var replay: String = scene.controller.domain.replay_record.serialize()
	var command_count: int = scene.controller._command_sequence
	scene._apply_presentation_preferences({"locale": "en", "ui_scale": 1.0, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
	await tree.process_frame
	await tree.process_frame
	var initial_button: Button = view.action_button(action_id)
	assert_true(initial_button != null and not initial_button.text.is_empty(), "the Shop/Workshop action has a visible localized label before refresh", failures)
	var english_label := initial_button.text if initial_button != null else ""
	var chinese_label := ""
	for locale in ["zh_CN", "en"]:
		scene._apply_presentation_preferences({"locale": locale, "ui_scale": 1.25 if locale == "zh_CN" else 1.0, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
		await tree.process_frame
		await tree.process_frame
		var refreshed_button: Button = view.action_button(action_id)
		assert_true(refreshed_button != null and not refreshed_button.text.is_empty(), "the choice remains visible after a locale and UI-scale refresh", failures)
		if refreshed_button != null:
			if locale == "zh_CN":
				chinese_label = refreshed_button.text
			else:
				assert_true(refreshed_button.text == english_label, "English action label returns after the locale refresh", failures)
		assert_true(scene.controller.domain.checkpoint() == checkpoint and scene.controller.domain.replay_record.serialize() == replay and scene.controller._command_sequence == command_count, "locale and UI-scale refresh changes no Run state or command", failures)
	assert_true(not chinese_label.is_empty() and chinese_label != english_label, "Shop/Workshop action label localizes between English and Chinese", failures)
	scene._apply_presentation_preferences(original_preferences, true)
	await tree.process_frame
	await tree.process_frame
	assert_true(scene.controller.domain.checkpoint() == checkpoint and scene.controller.domain.replay_record.serialize() == replay and scene.controller._command_sequence == command_count, "restoring the original locale and scale changes no Run state or command", failures)


func test_terminal_warning_and_receipt(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var flow := OnboardingFlowTest.new()
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage45_terminal_warning_profile_%s.json" % suffix
	var suspend_path := "user://stage45_terminal_warning_suspend_%s.json" % suffix
	var scene = flow._new_test_scene(profile_path, suspend_path)
	tree.root.add_child(scene)
	await tree.process_frame
	for kind in ["CHARACTER", "CONTRACT", "MAP_NODE"]:
		var action := _first_action(scene.controller.action_descriptors(), kind)
		var result = scene._on_action_pressed(str(action.get("id", "")))
		assert_true(result != null and result.accepted, "terminal warning fixture accepts its initial %s command" % kind, failures)
	if not flow.win_active_battle(scene, failures):
		_free_scene(scene)
		return
	flow.choose_first_reward(scene, RunPhaseScript.MAP_CHOICE, failures)
	if not flow.complete_remaining_act_path(scene, 1, failures) or not flow.complete_remaining_act_path(scene, 2, failures):
		_free_scene(scene)
		return
	assert_true(scene.controller.domain.state.phase == RunPhaseScript.RUN_SUMMARY, "terminal warning regression reaches the real two-Act summary", failures)
	var rejected_store := RejectingSuspendStore.new()
	scene.controller.suspend_store = rejected_store
	var command_count: int = scene.controller.domain.replay_record.commands.size()
	var acknowledged = scene._on_action_pressed("run.summary.acknowledge")
	assert_true(acknowledged != null and acknowledged.accepted and scene.controller.domain.state.phase == RunPhaseScript.RUN_COMPLETE, "the acknowledged Run stays complete when its save write fails", failures)
	assert_true(scene.controller.domain.replay_record.commands.size() == command_count + 1 and rejected_store.writes == 1, "terminal acknowledgment and failed write execute exactly once", failures)
	var checkpoint: Dictionary = scene.controller.domain.checkpoint()
	var replay: String = scene.controller.domain.replay_record.serialize()
	for locale in ["en", "zh_CN", "en"]:
		scene._apply_presentation_preferences({"locale": locale, "ui_scale": 1.0, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
		await tree.process_frame
		var expected_warning := LocalizationCatalogScript.format("UI_RUN_CONTROLLER_0001", ["TEST_WRITE_FAILED"])
		var expected_victory := LocalizationCatalogScript.text("UI_BATTLE_VIEW_0047")
		assert_true(scene._feedback_value.is_visible_in_tree() and scene._feedback_value.text.contains(expected_warning) and scene._feedback_value.text.contains(expected_victory), "the terminal scene preserves localized save warning and Victory receipt together", failures)
		assert_true(scene.controller.domain.checkpoint() == checkpoint and scene.controller.domain.replay_record.serialize() == replay and rejected_store.writes == 1, "terminal locale refresh changes no Run bytes and retries no save I/O", failures)
	_free_scene(scene)
	await tree.process_frame


func test_suspend_recovery_locale_and_disclosure(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var flow := OnboardingFlowTest.new()
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage45_suspend_locale_profile_%s.json" % suffix
	var suspend_path := "user://stage45_suspend_locale_suspend_%s.json" % suffix
	var scene = flow._new_test_scene(profile_path, suspend_path)
	tree.root.add_child(scene)
	await tree.process_frame
	for kind in ["CHARACTER", "CONTRACT"]:
		var action := _first_action(scene.controller.action_descriptors(), kind)
		scene._on_action_pressed(str(action.get("id", "")))
	var saved_bytes := FileAccess.get_file_as_string(suspend_path)
	scene.free()
	scene = flow._new_test_scene(profile_path, suspend_path)
	tree.root.add_child(scene)
	await tree.process_frame
	assert_true(scene.controller == null and scene._pending_resume_domain != null and scene._resume_run_button.is_visible_in_tree(), "a real saved Run opens the resume choice before a new controller is attached", failures)
	for locale in ["zh_CN", "en"]:
		scene._apply_presentation_preferences({"locale": locale, "ui_scale": 1.0, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
		await tree.process_frame
		assert_true(scene._resume_run_button.text == LocalizationCatalogScript.text("UI_RUN_SCENE_0043") and scene._new_run_from_suspend_button.text == LocalizationCatalogScript.text("UI_RUN_SCENE_0028"), "startup Resume and New Run buttons refresh in both locales", failures)
		assert_true(scene._suspend_status.text.contains(LocalizationCatalogScript.text("UI_RUN_RECOVERY_READY")), "the saved-Run banner refreshes in the applied locale", failures)
		assert_true(FileAccess.get_file_as_string(suspend_path) == saved_bytes, "resume language switching does not rerun or rewrite save I/O", failures)
	_free_scene(scene)
	var corrupt := FileAccess.open(suspend_path, FileAccess.WRITE)
	corrupt.store_string("{invalid stage45 test-only save")
	corrupt.close()
	var invalid_bytes := FileAccess.get_file_as_string(suspend_path)
	scene = flow._new_test_scene(profile_path, suspend_path)
	tree.root.add_child(scene)
	await tree.process_frame
	var details_button := scene.find_child("SuspendDetailsButton", true, false) as Button
	var details_value := scene.find_child("SuspendDetailsValue", true, false) as Label
	var rejected_path: String = scene._suspend_rejected_copy_path
	assert_true(details_button != null and details_button.is_visible_in_tree() and details_value != null and not details_value.visible, "recovery hides technical paths and errors behind a reachable Details disclosure", failures)
	assert_true(not scene._suspend_status.text.contains("PARSE_FAILED") and not scene._suspend_status.text.contains(rejected_path), "the recovery banner carries readable preservation instructions without raw codes or paths", failures)
	if details_button != null:
		details_button.grab_focus()
		details_button.pressed.emit()
		for locale in ["zh_CN", "en"]:
			scene._apply_presentation_preferences({"locale": locale, "ui_scale": 1.0, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
			await tree.process_frame
			assert_true(details_value.is_visible_in_tree() and details_value.text.contains("PARSE_FAILED") and details_value.text.contains(rejected_path), "expanded Details preserves literal recovery path and code across locale changes", failures)
			assert_true(details_button.text == LocalizationCatalogScript.text("UI_RUN_RECOVERY_DETAILS_HIDE") and scene._suspend_status.text == LocalizationCatalogScript.text("UI_RUN_RECOVERY_PRESERVED"), "recovery guidance and expanded Details heading refresh together", failures)
			assert_true(FileAccess.get_file_as_string(suspend_path) == invalid_bytes and FileAccess.get_file_as_string(rejected_path) == invalid_bytes, "locale and Details changes preserve the original and exact rejected-save copy", failures)
	_free_scene(scene)
	if not rejected_path.is_empty():
		flow._clear_test_file(rejected_path)
	await tree.process_frame


func test_profile_recovery_locale_and_disclosure(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var flow := OnboardingFlowTest.new()
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage45_profile_locale_profile_%s.json" % suffix
	var suspend_path := "user://stage45_profile_locale_suspend_%s.json" % suffix
	var corrupt := FileAccess.open(profile_path, FileAccess.WRITE)
	corrupt.store_string("{invalid stage45 test-only profile")
	corrupt.close()
	var invalid_bytes := FileAccess.get_file_as_string(profile_path)
	var scene = flow._new_test_scene(profile_path, suspend_path)
	tree.root.add_child(scene)
	await tree.process_frame
	var details_button := scene.find_child("ProfileDetailsButton", true, false) as Button
	var details_value := scene.find_child("ProfileDetailsValue", true, false) as Label
	var rejected_path: String = scene.meta_progress_coordinator.last_rejected_profile_path
	assert_true(scene.meta_progress_coordinator.recovery_required and details_button != null and details_value != null and not details_value.visible, "a corrupt progression profile exposes a collapsed Details disclosure", failures)
	assert_true(not scene._profile_status.text.contains("PARSE_FAILED") and not scene._profile_status.text.contains(rejected_path), "profile recovery guidance keeps paths and error codes out of the main banner", failures)
	if details_button == null or details_value == null:
		_free_scene(scene)
		flow._clear_test_file(rejected_path)
		return
	details_button.grab_focus()
	details_button.pressed.emit()
	for locale in ["zh_CN", "en"]:
		scene._apply_presentation_preferences({"locale": locale, "ui_scale": 1.5, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
		await tree.process_frame
		await tree.process_frame
		_assert_profile_recovery_rail_fits(scene, failures)
		assert_true(details_value.is_visible_in_tree() and details_value.text.contains("PARSE_FAILED") and details_value.text.contains(rejected_path), "profile Details retains its original code and recovery path through locale changes", failures)
		assert_true(details_button.text == LocalizationCatalogScript.text("UI_RUN_RECOVERY_DETAILS_HIDE") and scene._profile_status.text == LocalizationCatalogScript.text("UI_PROFILE_RECOVERY_PRESERVED"), "profile recovery guidance and Details refresh in both locales", failures)
		assert_true(FileAccess.get_file_as_string(profile_path) == invalid_bytes and FileAccess.get_file_as_string(rejected_path) == invalid_bytes, "profile disclosure and locale changes rewrite no original or preserved profile bytes", failures)
	scene._on_reset_profile_pressed()
	assert_true(not scene.meta_progress_coordinator.recovery_required and scene._profile_status.text == LocalizationCatalogScript.text("UI_PROFILE_RESET_PRESERVED"), "explicit profile reset presents its preserved-copy outcome", failures)
	var reset_bytes := FileAccess.get_file_as_string(profile_path)
	for locale in ["zh_CN", "en"]:
		scene._apply_presentation_preferences({"locale": locale, "ui_scale": 1.5, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
		assert_true(scene._profile_status.text == LocalizationCatalogScript.text("UI_PROFILE_RESET_PRESERVED"), "profile reset result relocalizes without reverting to its old load warning", failures)
		assert_true(FileAccess.get_file_as_string(profile_path) == reset_bytes and FileAccess.get_file_as_string(rejected_path) == invalid_bytes, "reset-result relocalization preserves fresh and rejected profile bytes", failures)
	_free_scene(scene)
	flow._clear_test_file(rejected_path)
	await tree.process_frame


func test_unpreserved_profile_recovery(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var flow := OnboardingFlowTest.new()
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage45_unpreserved_profile_%s.json" % suffix
	var suspend_path := "user://stage45_unpreserved_suspend_%s.json" % suffix
	var corrupt := FileAccess.open(profile_path, FileAccess.WRITE)
	corrupt.store_string("{invalid test-only unpreserved profile")
	corrupt.close()
	var original := FileAccess.get_file_as_string(profile_path)
	var store := UnpreservedProfileStore.new(profile_path)
	var scene = flow._new_test_scene(profile_path, suspend_path)
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(store)
	tree.root.add_child(scene)
	await tree.process_frame
	var reset := scene.find_child("ResetProfileButton", true, false) as Button
	var disclosure := scene.find_child("ProfileDetailsButton", true, false) as Button
	var details := scene.find_child("ProfileDetailsValue", true, false) as Label
	assert_true(scene.meta_progress_coordinator.recovery_required and reset != null and reset.visible and reset.disabled, "unpreserved profile recovery disables the action the coordinator cannot accept", failures)
	assert_true(disclosure != null and details != null, "unpreserved profile recovery exposes external steps through Details", failures)
	if disclosure != null and details != null:
		disclosure.pressed.emit()
		for locale in ["en", "zh_CN", "en"]:
			scene._apply_presentation_preferences({"locale": locale, "ui_scale": 1.5, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
			await tree.process_frame
			await tree.process_frame
			_assert_profile_recovery_rail_fits(scene, failures)
			assert_true(reset.disabled and scene._profile_status.text == LocalizationCatalogScript.text("UI_PROFILE_RECOVERY_UNPRESERVED"), "disabled Reset has visible localized recovery guidance", failures)
			assert_true(details.is_visible_in_tree() and details.text.contains(LocalizationCatalogScript.text("UI_PROFILE_MANUAL_RECOVERY_STEPS")) and details.text.contains("TEST_PRESERVATION_DENIED") and details.text.contains(ProjectSettings.globalize_path(profile_path)), "Details shows actionable external recovery instructions and the unchanged error code", failures)
			assert_true(store.write_attempts == 0 and FileAccess.get_file_as_string(profile_path) == original, "unpreserved recovery disclosure and locale changes never write the protected profile", failures)
	_free_scene(scene)
	await tree.process_frame


func _assert_profile_recovery_rail_fits(scene, failures: Array[String]) -> void:
	var viewport: Rect2 = scene.get_viewport_rect()
	var scroll := scene.find_child("ProfileRecoveryScroll", true, false) as ScrollContainer
	assert_true(scroll != null and scroll.size.y <= 190.0, "expanded profile recovery stays within its viewport budget at 150%", failures)
	for button in [scene._back_button]:
		assert_true(viewport.grow(1.0).encloses(button.get_global_rect()), "profile recovery leaves the pinned action rail fully inside the viewport at 150%", failures)


func _new_scene(prefix: String):
	var suffix := str(Time.get_ticks_usec())
	var scene = RunScene.instantiate()
	scene.suspend_file_path = "user://stage45_%s_%s_suspend.json" % [prefix, suffix]
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new("user://stage45_%s_%s_profile.json" % [prefix, suffix]),
	)
	scene._ready()
	return scene


func _new_input_scene(prefix: String, tree: SceneTree):
	var suffix := str(Time.get_ticks_usec())
	var scene = RunScene.instantiate()
	scene.suspend_file_path = "user://stage45_%s_%s_input_suspend.json" % [prefix, suffix]
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new("user://stage45_%s_%s_input_profile.json" % [prefix, suffix]),
	)
	tree.root.add_child(scene)
	await tree.process_frame
	return scene


func _restore_run_scene_preferences(scene, preferences: Dictionary) -> void:
	scene._apply_presentation_preferences(preferences, true)


func _send_run_action(scene, action: String, tree: SceneTree) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	scene.call("_input", event)
	await tree.process_frame
	await tree.process_frame


func _service_fixture_domain(scene, kind: String):
	var suffix := str(Time.get_ticks_usec())
	var domain = RunDomainScript.new_alpha_run("stage45.%s.%s" % [kind, suffix], int(suffix) % 2147483647, scene._content_registry)
	domain.execute(ChooseCharacterCommandScript.new("stage45.%s.character" % suffix, "base.character.sequence"))
	domain.execute(ChooseContractCommandScript.new("stage45.%s.contract" % suffix, "base.contract.pressure"))
	# Isolate the UI at a valid room boundary. Real route traversal is covered by
	# the complete Stage 4 keyboard/controller journey, not this fixture.
	domain.state.map_state.current_node_id = "base.map_node.shop" if kind == "shop" else "base.map_node.workshop"
	domain.state.phase = RunPhaseScript.MAP_CHOICE
	domain.state.gold = 100
	return domain


func _first_action(actions: Array, kind: String) -> Dictionary:
	if kind == "CHARACTER":
		for action in actions:
			if str(action.get("target_id", "")) == "base.character.sequence":
				return action
	for action in actions:
		if str(action.get("kind", "")) == kind:
			return action
	return {}


func _action_with_kind(actions: Array, kind: String, property_name: String, value: String) -> Dictionary:
	for action in actions:
		if str(action.get("kind", "")) == kind and str(action.get(property_name, "")) == value:
			return action
	return {}


func _free_scene(scene) -> void:
	var suspend_path: String = scene.suspend_file_path
	var profile_path: String = scene.meta_progress_coordinator.store.file_path
	scene.free()
	for path in [suspend_path, suspend_path + ".tmp", suspend_path + ".bak", profile_path]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
