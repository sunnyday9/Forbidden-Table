extends SceneTree

const OnboardingFlowTest = preload("res://tests/stage4_onboarding_flow_test.gd")
const AccessibilityTest = preload("res://tests/stage4_accessibility_test.gd")
const RunUiTest = preload("res://tests/stage45_run_ui_test.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")

var _capture_directory := ""
var _locale := "en"
var _pseudo := false
var _capture_tag := ""
var _previous_pseudo := false
var _ui_scale := 1.0
var _capture_size := Vector2i(960, 540)
var _prefs
var _previous_preferences: Dictionary = {}
var _previous_config_path := ""
var _previous_locale := "en"
var _captures: Array[Dictionary] = []
var _layout_failures: Array[String] = []
var _flow_failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_capture_probe")

func _run_capture_probe() -> void:
	_configure_capture_preferences()
	# Window managers may constrain a 1080p window to the desktop work area.
	# Audit/render the exact requested logical viewport independently of that
	# physical window size; this does not make a native-device measurement.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = _capture_size
	root.size = _capture_size
	_capture_directory = ProjectSettings.globalize_path("res://forbidden_table_spec/evidence/stage4_5/%s-scale-%03d-%dx%d" % [_locale + ("-pseudo" if _pseudo else "") + _capture_tag, roundi(_ui_scale * 100), _capture_size.x, _capture_size.y])
	var create_result := DirAccess.make_dir_recursive_absolute(_capture_directory)
	if create_result != OK and create_result != ERR_ALREADY_EXISTS:
		push_error("Could not create accessibility capture folder: %s" % _capture_directory)
		quit(1)
		return

	var flow_test := OnboardingFlowTest.new()
	var accessibility_test := AccessibilityTest.new()
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_accessibility_capture_profile_%s.json" % suffix
	var suspend_path := "user://stage4_accessibility_capture_suspend_%s.json" % suffix
	var scene = flow_test._new_test_scene(profile_path, suspend_path)
	root.size = _capture_size
	root.add_child(scene)
	await _wait_for_rendered_frame()
	await _capture_state(accessibility_test, scene, "character_select")
	await _capture_local_choice(accessibility_test, scene, _action_id(scene, "CHARACTER"), "character_selected")

	var character_action := _action_id(scene, "CHARACTER")
	if not await _confirm_and_wait(scene, character_action):
		_finish_probe(flow_test, scene, profile_path, suspend_path)
		return
	await _capture_state(accessibility_test, scene, "contract_select")
	var contract_action := _action_id(scene, "CONTRACT")
	if not await _confirm_and_wait(scene, contract_action):
		_finish_probe(flow_test, scene, profile_path, suspend_path)
		return
	await _capture_state(accessibility_test, scene, "map_choice_act_1")
	var start_node := str(scene.controller.domain.map_definition.start_node_id)
	var start_action := _action_id(scene, "MAP_NODE", start_node)
	if not await _confirm_and_wait(scene, start_action):
		_finish_probe(flow_test, scene, profile_path, suspend_path)
		return
	await _capture_state(accessibility_test, scene, "battle_tutorial_on")
	await _capture_settings(scene)

	scene._on_tutorial_toggle_pressed()
	await _wait_for_rendered_frame()
	await _capture_state(accessibility_test, scene, "battle_tutorial_disabled")
	scene._on_tutorial_reset_pressed()
	await _wait_for_rendered_frame()
	await _capture_state(accessibility_test, scene, "battle_tutorial_reset")

	if not flow_test.win_active_battle(scene, _flow_failures):
		push_error("Capture probe failed to finish its initial encounter.")
		_finish_probe(flow_test, scene, profile_path, suspend_path)
		return
	await _wait_for_rendered_frame()
	await _capture_state(accessibility_test, scene, "reward_choice")
	flow_test.choose_first_reward(scene, "MAP_CHOICE", _flow_failures)
	await _wait_for_rendered_frame()
	if not flow_test.complete_remaining_act_path(scene, 1, _flow_failures):
		push_error("Capture probe failed to finish Act 1.")
		_finish_probe(flow_test, scene, profile_path, suspend_path)
		return
	await _wait_for_rendered_frame()
	await _capture_state(accessibility_test, scene, "map_choice_act_2")
	if not flow_test.complete_remaining_act_path(scene, 2, _flow_failures):
		push_error("Capture probe failed to finish Act 2.")
		_finish_probe(flow_test, scene, profile_path, suspend_path)
		return
	await _wait_for_rendered_frame()
	await _capture_state(accessibility_test, scene, "run_summary")
	if not await _confirm_and_wait(scene, "run.summary.acknowledge"):
		_finish_probe(flow_test, scene, profile_path, suspend_path)
		return
	await _capture_state(accessibility_test, scene, "run_complete")
	scene.visible = false
	await _wait_for_rendered_frame()
	await _capture_event_elite_boss_states(flow_test, accessibility_test)
	await _capture_shop_workshop_states(flow_test, accessibility_test)
	await _capture_battle_interaction_states(flow_test, accessibility_test)
	await _capture_resume_recovery_states(flow_test, accessibility_test)
	await _capture_profile_recovery_states(flow_test, accessibility_test)
	_finish_probe(flow_test, scene, profile_path, suspend_path)

func _capture_battle_interaction_states(flow_test, audit) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage45_battle_capture_profile_%s.json" % suffix
	var suspend_path := "user://stage45_battle_capture_suspend_%s.json" % suffix
	var scene = flow_test._new_test_scene(profile_path, suspend_path)
	root.size = _capture_size
	root.add_child(scene)
	await _wait_for_rendered_frame()
	if not await _confirm_and_wait(scene, _action_id(scene, "CHARACTER")) or not await _confirm_and_wait(scene, _action_id(scene, "CONTRACT")) or not await _confirm_and_wait(scene, _action_id(scene, "MAP_NODE")):
		_flow_failures.append("Could not enter interaction-state Battle fixture.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	var battle = scene.controller.domain.current_battle
	# Test-only hands expose Pattern and Complete Hand choices deterministically.
	# Commands still use the existing Run controller; production content is untouched.
	battle.combat_state.enemy_hp = 1000
	battle.combat_state.enemy_max_hp = 1000
	flow_test._prepare_mapped_battle_hand(battle, [
		"base.tile.characters.1", "base.tile.characters.1", "base.tile.characters.1",
		"base.tile.characters.2", "base.tile.characters.3", "base.tile.characters.4",
		"base.tile.characters.5", "base.tile.characters.6", "base.tile.characters.7",
		"base.tile.characters.2", "base.tile.characters.3", "base.tile.characters.8", "base.tile.characters.9",
	], "capture_partial", _flow_failures)
	scene._render()
	if await _confirm_and_wait(scene, "battle.draw"):
		await _capture_state(audit, scene, "battle_drawn_hand")
		await _capture_local_choice(audit, scene, _action_id(scene, "PARTIAL_SETTLEMENT"), "battle_pattern_selected")
		var tile_button := scene._battle_view.find_child("TileFace_*", true, false) as Button
		if tile_button == null:
			for candidate in scene._battle_view.find_children("*", "Button", true, false):
				if candidate.has_meta("tile_instance_id"):
					tile_button = candidate
					break
		if tile_button != null:
			tile_button.grab_focus()
			await _capture_state(audit, scene, "battle_tile_detail")
	flow_test._prepare_mapped_battle_hand(battle, [
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3",
		"base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3",
		"base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3",
		"base.tile.characters.4", "base.tile.characters.5", "base.tile.characters.6",
		"base.tile.characters.7", "base.tile.characters.7",
	], "capture_complete", _flow_failures)
	flow_test._sync_test_fixture_focus(scene)
	scene._render()
	var complete_id := _action_id(scene, "COMPLETE_HAND")
	await _capture_local_choice(audit, scene, complete_id, "battle_complete_hand_selected")
	if await _confirm_and_wait(scene, complete_id):
		await _capture_state(audit, scene, "battle_recovery")
		battle.combat_state.pressure = 0
		battle.combat_state.pressure_limit = 1
		# Test-only Intent amount/type guarantees this end-state fixture loses;
		# the randomly selected encounter may otherwise have a zero-Pressure turn.
		battle.combat_state.current_intent.action_type = "PRESSURE"
		battle.combat_state.current_intent.pressure_amount = 1
		if await _confirm_and_wait(scene, "battle.end_turn") and str(scene.controller.domain.state.phase) == "RUN_SUMMARY":
			await _capture_state(audit, scene, "run_summary_defeat")
		else:
			_flow_failures.append("The deterministic defeat fixture did not reach Run Summary.")
	_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)

func _capture_resume_recovery_states(flow_test, audit) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage45_resume_capture_profile_%s.json" % suffix
	var suspend_path := "user://stage45_resume_capture_suspend_%s.json" % suffix
	var scene = flow_test._new_test_scene(profile_path, suspend_path)
	root.size = _capture_size
	root.add_child(scene)
	await _wait_for_rendered_frame()
	await _confirm_and_wait(scene, _action_id(scene, "CHARACTER"))
	await _confirm_and_wait(scene, _action_id(scene, "CONTRACT"))
	root.remove_child(scene)
	scene.free()
	scene = flow_test._new_test_scene(profile_path, suspend_path)
	root.size = _capture_size
	root.add_child(scene)
	await _capture_state(audit, scene, "suspend_resume_choice")
	scene._on_new_run_from_suspend_pressed()
	await _capture_state(audit, scene, "new_run_confirmation")
	scene._close_new_run_confirmation(true)
	scene._on_resume_run_pressed()
	await _capture_state(audit, scene, "resumed_map")
	_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
	var corrupt := FileAccess.open(suspend_path, FileAccess.WRITE)
	corrupt.store_string("{invalid test-only save")
	corrupt.close()
	scene = flow_test._new_test_scene(profile_path, suspend_path)
	root.size = _capture_size
	root.add_child(scene)
	await _capture_state(audit, scene, "save_recovery_error")
	var details_button := scene.find_child("SuspendDetailsButton", true, false) as Button
	if details_button != null:
		details_button.grab_focus()
		details_button.pressed.emit()
		await _capture_state(audit, scene, "save_recovery_details")
	else:
		_flow_failures.append("Recovery has no reachable technical Details disclosure.")
	var rejected_path: String = scene._suspend_rejected_copy_path
	_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
	if not rejected_path.is_empty():
		flow_test._clear_test_file(rejected_path)

func _capture_profile_recovery_states(flow_test, audit) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage45_profile_capture_profile_%s.json" % suffix
	var suspend_path := "user://stage45_profile_capture_suspend_%s.json" % suffix
	var corrupt := FileAccess.open(profile_path, FileAccess.WRITE)
	corrupt.store_string("{invalid test-only progression profile")
	corrupt.close()
	var scene = flow_test._new_test_scene(profile_path, suspend_path)
	root.size = _capture_size
	root.add_child(scene)
	await _capture_state(audit, scene, "profile_recovery")
	var details_button := scene.find_child("ProfileDetailsButton", true, false) as Button
	if details_button != null:
		details_button.grab_focus()
		details_button.pressed.emit()
		await _capture_state(audit, scene, "profile_recovery_details")
	else:
		_flow_failures.append("Profile recovery has no reachable technical Details disclosure.")
	var rejected_path: String = scene.meta_progress_coordinator.last_rejected_profile_path
	var reset_button := scene.find_child("ResetProfileButton", true, false) as Button
	if reset_button != null and not reset_button.disabled:
		reset_button.grab_focus()
		reset_button.pressed.emit()
		await _capture_state(audit, scene, "profile_reset_result")
	else:
		_flow_failures.append("Profile recovery has no enabled preserved-profile reset action.")
	_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
	if not rejected_path.is_empty():
		flow_test._clear_test_file(rejected_path)

	corrupt = FileAccess.open(profile_path, FileAccess.WRITE)
	corrupt.store_string("{invalid test-only profile with failed preservation")
	corrupt.close()
	scene = flow_test._new_test_scene(profile_path, suspend_path)
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(RunUiTest.UnpreservedProfileStore.new(profile_path))
	root.size = _capture_size
	root.add_child(scene)
	details_button = scene.find_child("ProfileDetailsButton", true, false) as Button
	if details_button != null:
		details_button.grab_focus()
		details_button.pressed.emit()
	reset_button = scene.find_child("ResetProfileButton", true, false) as Button
	if reset_button == null or not reset_button.disabled:
		_flow_failures.append("Unpreserved profile exposes a reset that cannot succeed.")
	await _capture_state(audit, scene, "profile_manual_recovery")
	_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)

func _capture_event_elite_boss_states(flow_test, accessibility_test) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_accessibility_event_profile_%s.json" % suffix
	var suspend_path := "user://stage4_accessibility_event_suspend_%s.json" % suffix
	var scene = flow_test._new_test_scene(profile_path, suspend_path)
	root.size = _capture_size
	root.add_child(scene)
	await _wait_for_rendered_frame()
	var character_id := _action_id(scene, "CHARACTER")
	if not await _confirm_and_wait(scene, character_id):
		_flow_failures.append("Could not reach Act 1 for Event/Elite/Boss accessibility captures.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	var contract_id := _action_id(scene, "CONTRACT")
	var start_node := str(scene.controller.domain.map_definition.start_node_id)
	if not await _confirm_and_wait(scene, contract_id) or not await _confirm_and_wait(scene, _action_id(scene, "MAP_NODE", start_node)):
		_flow_failures.append("Could not reach Act 1 for Event/Elite/Boss accessibility captures.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	if not flow_test.win_active_battle(scene, _flow_failures):
		_flow_failures.append("Could not win the introductory encounter for Event/Elite/Boss captures.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	await _wait_for_rendered_frame()
	flow_test.choose_first_reward(scene, "MAP_CHOICE", _flow_failures)
	await _wait_for_rendered_frame()
	if not await _confirm_and_wait(scene, _action_id(scene, "MAP_NODE", "base.map_node.normal.left")) or not flow_test.win_active_battle(scene, _flow_failures):
		_flow_failures.append("Could not reach the Act 1 branch for Event/Elite/Boss captures.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	await _wait_for_rendered_frame()
	flow_test.choose_first_reward(scene, "MAP_CHOICE", _flow_failures)
	await _wait_for_rendered_frame()
	var event_action := _action_id(scene, "MAP_NODE", "")
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) == "MAP_NODE" and str(action.get("node_kind", "")) == "EVENT":
			event_action = str(action.get("id", ""))
			break
	if not await _confirm_and_wait(scene, event_action) or not await _confirm_and_wait(scene, _action_id(scene, "ENTER_EVENT")):
		_flow_failures.append("Could not enter Event for its accessibility capture.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	await _capture_state(accessibility_test, scene, "event_choice")
	if not await _confirm_and_wait(scene, _action_id(scene, "EVENT_OPTION", "leave")):
		_flow_failures.append("Could not leave Event for Elite/Boss accessibility captures.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	if not await _confirm_and_wait(scene, _action_id(scene, "MAP_NODE", "base.map_node.normal.mid")) or not flow_test.win_active_battle(scene, _flow_failures):
		_flow_failures.append("Could not reach the Act 1 Elite route for accessibility captures.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	await _wait_for_rendered_frame()
	flow_test.choose_first_reward(scene, "MAP_CHOICE", _flow_failures)
	await _wait_for_rendered_frame()
	var elite_id := ""
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) == "MAP_NODE" and str(action.get("node_kind", "")) == "ELITE":
			elite_id = str(action.get("id", ""))
			break
	if elite_id.is_empty() or not await _confirm_and_wait(scene, elite_id) or not flow_test.win_active_battle(scene, _flow_failures):
		_flow_failures.append("Could not reach Act 1 Elite reward for its accessibility capture.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	await _capture_state(accessibility_test, scene, "elite_reward")
	flow_test.choose_first_reward(scene, "MAP_CHOICE", _flow_failures)
	await _wait_for_rendered_frame()
	var boss_id := ""
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) == "MAP_NODE" and str(action.get("node_kind", "")) == "BOSS":
			boss_id = str(action.get("id", ""))
			break
	if boss_id.is_empty() or not await _confirm_and_wait(scene, boss_id) or not flow_test.win_active_battle(scene, _flow_failures):
		_flow_failures.append("Could not reach Act 1 Boss reward for its accessibility capture.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	await _capture_state(accessibility_test, scene, "boss_reward")
	_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)

func _capture_shop_workshop_states(flow_test, accessibility_test) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_accessibility_shop_profile_%s.json" % suffix
	var suspend_path := "user://stage4_accessibility_shop_suspend_%s.json" % suffix
	var scene = flow_test._new_test_scene(profile_path, suspend_path)
	root.size = _capture_size
	root.add_child(scene)
	await _wait_for_rendered_frame()
	var character_id := _action_id(scene, "CHARACTER")
	if not await _confirm_and_wait(scene, character_id):
		_flow_failures.append("Could not reach Act 1 for Shop/Workshop accessibility captures.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	var contract_id := _action_id(scene, "CONTRACT")
	var start_node := str(scene.controller.domain.map_definition.start_node_id)
	if not await _confirm_and_wait(scene, contract_id) or not await _confirm_and_wait(scene, _action_id(scene, "MAP_NODE", start_node)):
		_flow_failures.append("Could not reach Act 1 for Shop/Workshop accessibility captures.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	if not flow_test.win_active_battle(scene, _flow_failures):
		_flow_failures.append("Could not win the introductory encounter for Shop/Workshop captures.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	flow_test.choose_first_reward(scene, "MAP_CHOICE", _flow_failures)
	if not await _confirm_and_wait(scene, _action_id(scene, "MAP_NODE", "base.map_node.normal.left")) or not flow_test.win_active_battle(scene, _flow_failures):
		_flow_failures.append("Could not reach the Act 1 branch for Shop/Workshop captures.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	flow_test.choose_first_reward(scene, "MAP_CHOICE", _flow_failures)
	if not await _confirm_and_wait(scene, _action_id(scene, "MAP_NODE", "base.map_node.shop")) or not await _confirm_and_wait(scene, _action_id(scene, "ENTER_SHOP")):
		_flow_failures.append("Could not enter Shop for its accessibility capture.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	scene.controller.domain.state.gold = 0
	scene._render()
	await _capture_state(accessibility_test, scene, "shop_unaffordable")
	scene.controller.domain.state.gold = 1000
	scene._render()
	await _capture_state(accessibility_test, scene, "shop")
	await _capture_local_choice(accessibility_test, scene, _action_id(scene, "SHOP_OFFER"), "shop_confirmation", true)
	if not await _confirm_and_wait(scene, _action_id(scene, "SHOP_EXIT")) or not await _confirm_and_wait(scene, _action_id(scene, "MAP_NODE", "base.map_node.workshop")) or not await _confirm_and_wait(scene, _action_id(scene, "ENTER_WORKSHOP")):
		_flow_failures.append("Could not enter Workshop for its accessibility capture.")
		_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)
		return
	await _capture_state(accessibility_test, scene, "workshop_service_choices")
	var service_id := ""
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) == "WORKSHOP_SELECT_SERVICE" and str(action.get("service_id", "")) in ["TRANSFORM", "ADD_MODIFIER"]:
			service_id = str(action.get("id", ""))
			break
	if not service_id.is_empty() and await _confirm_and_wait(scene, service_id):
		await _capture_state(accessibility_test, scene, "workshop_target_choice")
		var target_id := _action_id(scene, "WORKSHOP_SELECT_TARGET")
		if not target_id.is_empty() and await _confirm_and_wait(scene, target_id):
			await _capture_state(accessibility_test, scene, "workshop_value_choice")
			await _capture_local_choice(accessibility_test, scene, _action_id(scene, "WORKSHOP_SERVICE"), "workshop_confirmation", true)
	else:
		_flow_failures.append("Workshop did not expose a selectable service for its accessibility capture.")
	_cleanup_probe_scene(flow_test, scene, profile_path, suspend_path)

func _cleanup_probe_scene(flow_test, scene, profile_path: String, suspend_path: String) -> void:
	if scene != null and is_instance_valid(scene):
		if scene.get_parent() == root:
			root.remove_child(scene)
		scene.free()
	flow_test._clear_test_file(profile_path)
	flow_test._clear_test_file(suspend_path)

func _action_id(scene, kind: String, target_id := "") -> String:
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) == kind and (target_id.is_empty() or str(action.get("target_id", "")) == target_id):
			return str(action.get("id", ""))
	push_error("No %s action found for capture target '%s'." % [kind, target_id])
	return ""

func _confirm_and_wait(scene, action_id: String) -> bool:
	if action_id.is_empty():
		return false
	var result = scene._on_action_pressed(action_id)
	if result == null or not result.accepted:
		push_error("Capture probe action was rejected: %s" % action_id)
		return false
	await _wait_for_rendered_frame()
	return true

func _wait_for_rendered_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func _capture_state(accessibility_test, scene, state_name: String) -> void:
	await _wait_for_rendered_frame()
	await _wait_for_rendered_frame()
	var before := _layout_failures.size()
	accessibility_test._audit_text_bounds(scene, _layout_failures)
	var viewport: Viewport = scene.get_viewport()
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("No rendered viewport image is available for %s." % state_name)
		return
	if image.get_width() != _capture_size.x or image.get_height() != _capture_size.y:
		push_error("Unexpected capture size for %s: %dx%d" % [state_name, image.get_width(), image.get_height()])
		return
	var path := _capture_directory.path_join("%s.png" % state_name)
	var save_result: Error = image.save_png(path)
	if save_result != OK:
		push_error("Could not save %s (%s)." % [path, error_string(save_result)])
		return
	var phase := str(scene.controller.domain.state.phase) if scene.controller != null else "STARTUP_RECOVERY"
	_captures.append({"state": state_name, "path": path.get_file(), "phase": phase, "build_version": str(ProjectSettings.get_setting("application/config/version", "unknown")), "content_version": str(scene.controller.domain.state.content_version) if scene.controller != null else "none", "seed": int(scene.controller.domain.state.seed) if scene.controller != null else -1, "locale": _locale, "ui_scale": _ui_scale, "viewport": [_capture_size.x, _capture_size.y], "fixture": "Stage4OnboardingContentRegistry; deterministic Hand/HP/pressure/Intent and invalid-save/profile fixtures for interaction/end/recovery states", "layout_failures": _layout_failures.size() - before})
	print("STAGE45_VISUAL_CAPTURE state=%s image=%s layout_failures=%d" % [state_name, path, _layout_failures.size() - before])

func _finish_probe(flow_test, scene, profile_path: String, suspend_path: String) -> void:
	print("STAGE45_VISUAL_PROBE directory=%s captures=%s layout_failures=%d flow_failures=%d" % [
		_capture_directory,
		_captures.size(),
		_layout_failures.size(),
		_flow_failures.size(),
	])
	if not _layout_failures.is_empty():
		push_error("The rendered-frame geometry audit found %d violations." % _layout_failures.size())
	if not _flow_failures.is_empty():
		for failure in _flow_failures:
			push_error(failure)
	if scene != null and is_instance_valid(scene):
		if scene.get_parent() == root:
			root.remove_child(scene)
		scene.free()
	flow_test._clear_test_file(profile_path)
	flow_test._clear_test_file(suspend_path)
	var manifest := FileAccess.open(_capture_directory.path_join("manifest.json"), FileAccess.WRITE)
	if manifest != null:
		manifest.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "os": OS.get_name(), "video_adapter": RenderingServer.get_video_adapter_name(), "captures": _captures, "flow_failures": _flow_failures, "layout_failures": _layout_failures, "physical_device": "NOT_PERFORMED", "participant_testing": "NOT_PERFORMED"}, "	"))
		manifest.close()
	_restore_capture_preferences()
	quit(1 if not _layout_failures.is_empty() or not _flow_failures.is_empty() else 0)

func _configure_capture_preferences() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--pseudo":
			_pseudo = true
		elif argument == "--tag=native-windows":
			_capture_tag = "-native-windows"
		elif argument.begins_with("--locale="):
			_locale = argument.trim_prefix("--locale=")
		elif argument.begins_with("--scale="):
			_ui_scale = argument.trim_prefix("--scale=").to_float()
		elif argument.begins_with("--viewport="):
			var parts := argument.trim_prefix("--viewport=").split("x")
			if parts.size() == 2:
				_capture_size = Vector2i(parts[0].to_int(), parts[1].to_int())
	_previous_pseudo = TranslationServer.pseudolocalization_enabled
	_previous_locale = TranslationServer.get_locale()
	_prefs = root.get_node_or_null("PresentationPrefs")
	if _prefs != null:
		_previous_preferences = _prefs.snapshot()
		_previous_config_path = _prefs.config_path
		_prefs.config_path = "user://stage45_capture_preferences.cfg"
		_prefs.apply_preferences({"locale": _locale, "ui_scale": _ui_scale, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false})
	TranslationServer.set_locale(_locale)
	TranslationServer.pseudolocalization_enabled = _pseudo
	TranslationServer.reload_pseudolocalization()

func _restore_capture_preferences() -> void:
	if _prefs != null:
		_prefs.apply_preferences(_previous_preferences)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_prefs.config_path))
		_prefs.config_path = _previous_config_path
	TranslationServer.set_locale(_previous_locale)
	TranslationServer.pseudolocalization_enabled = _previous_pseudo
	TranslationServer.reload_pseudolocalization()

func _capture_settings(scene) -> void:
	var opener := scene.find_child("SettingsButton", true, false) as Button
	if opener == null:
		_flow_failures.append("The game has no visible SettingsButton for the bilingual capture.")
		return
	opener.grab_focus()
	opener.pressed.emit()
	await _wait_for_rendered_frame()
	await _capture_state(AccessibilityTest.new(), scene, "language_settings")
	var help_tab := scene.find_child("HelpTabButton", true, false) as Button
	if help_tab != null:
		help_tab.pressed.emit()
		await _capture_state(AccessibilityTest.new(), scene, "tutorial_help")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	scene._input(event)
	await _wait_for_rendered_frame()

func _capture_local_choice(audit, scene, action_id: String, state_name: String, confirmation := false) -> void:
	var button := OnboardingFlowTest.new().find_action_button(scene, action_id)
	if button == null:
		_flow_failures.append("No choice control for state " + state_name)
		return
	var before: int = scene.controller.domain.replay_record.commands.size()
	button.grab_focus()
	button.pressed.emit()
	if confirmation:
		scene._commit_selected_button.pressed.emit()
	await _capture_state(audit, scene, state_name)
	if not confirmation:
		var focused := scene.get_viewport().gui_get_focus_owner() as Control
		if focused != null and str(scene.controller.domain.state.phase) == "BATTLE":
			var focus_scroll := scene._battle_view.find_child("BattleChoiceScroll", true, false) as ScrollContainer
			if focus_scroll == null or not focus_scroll.get_global_rect().intersects(focused.get_global_rect()):
				_flow_failures.append("Focused Battle choice is outside its visible scroll area: " + state_name)
		if focused == null or str(focused.get_meta("run_action_id", "")) != action_id:
			_flow_failures.append("A newer selected choice lost its visible focus: " + state_name)
	if scene.controller.domain.replay_record.commands.size() != before:
		_flow_failures.append("Preview/confirmation submitted a command: " + state_name)
	scene._on_back_pressed()
	if confirmation:
		scene._on_back_pressed()
	await _wait_for_rendered_frame()
