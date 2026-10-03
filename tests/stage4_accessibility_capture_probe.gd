extends SceneTree

const OnboardingFlowTest = preload("res://tests/stage4_onboarding_flow_test.gd")
const AccessibilityTest = preload("res://tests/stage4_accessibility_test.gd")

var _capture_directory := ""
var _layout_failures: Array[String] = []
var _flow_failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_capture_probe")

func _run_capture_probe() -> void:
	root.size = Vector2i(960, 540)
	_capture_directory = ProjectSettings.globalize_path("res://forbidden_table_spec/evidence/stage4_accessibility")
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
	root.add_child(scene)
	await _wait_for_rendered_frame()
	await _capture_state(accessibility_test, scene, "character_select")

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
	var overview_scroll: ScrollContainer = scene._overview_scroll
	overview_scroll.grab_focus()
	for step in 16:
		var scrollbar := overview_scroll.get_v_scroll_bar()
		if overview_scroll.scroll_vertical >= scrollbar.max_value - scrollbar.page:
			break
		flow_test._push_virtual_direction(scene, 1, false)
		await _wait_for_rendered_frame()
	var hand_heading: Label
	for candidate in scene.find_children("*", "Label", true, false):
		var candidate_label := candidate as Label
		if candidate_label != null and candidate_label.text == "Hand and Reserve":
			hand_heading = candidate_label
			break
	if hand_heading != null:
		await _wait_for_rendered_frame()
		await _wait_for_rendered_frame()
		var heading_rect: Rect2 = hand_heading.get_global_rect()
		var scroll_rect: Rect2 = overview_scroll.get_global_rect()
		var scrollbar := overview_scroll.get_v_scroll_bar()
		var aligned_scroll := overview_scroll.scroll_vertical + int(heading_rect.position.y - scroll_rect.position.y - 8.0)
		overview_scroll.scroll_vertical = clampi(aligned_scroll, 0, int(scrollbar.max_value - scrollbar.page))
		await _wait_for_rendered_frame()
		await _wait_for_rendered_frame()
	var overview_rect: Rect2 = overview_scroll.get_global_rect()
	var help_rect: Rect2 = scene._help_value.get_global_rect()
	var tutorial_rect: Rect2 = scene._tutorial_prompt.get_global_rect()
	if not overview_rect.encloses(help_rect) or not overview_rect.encloses(tutorial_rect):
		_flow_failures.append("Keyboard Down did not bring the complete Help and Tutorial labels into the Run overview viewport.")
	await _capture_state(accessibility_test, scene, "battle_overview_scrolled")
	overview_scroll.scroll_vertical = 0
	await _wait_for_rendered_frame()

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
	_finish_probe(flow_test, scene, profile_path, suspend_path)

func _capture_event_elite_boss_states(flow_test, accessibility_test) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_accessibility_event_profile_%s.json" % suffix
	var suspend_path := "user://stage4_accessibility_event_suspend_%s.json" % suffix
	var scene = flow_test._new_test_scene(profile_path, suspend_path)
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
	scene.controller.domain.state.gold = 1000
	scene._render()
	await _capture_state(accessibility_test, scene, "shop")
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
	_log_run_tile_pool_geometry(scene, state_name)
	_log_header_geometry(scene, state_name)
	var before := _layout_failures.size()
	accessibility_test._audit_text_bounds(scene, _layout_failures)
	var viewport: Viewport = scene.get_viewport()
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("No rendered viewport image is available for %s." % state_name)
		return
	if image.get_width() != 960 or image.get_height() != 540:
		push_error("Unexpected capture size for %s: %dx%d" % [state_name, image.get_width(), image.get_height()])
		return
	var path := _capture_directory.path_join("%s.png" % state_name)
	var save_result: Error = image.save_png(path)
	if save_result != OK:
		push_error("Could not save %s (%s)." % [path, error_string(save_result)])
		return
	print("STAGE4_ACCESSIBILITY_VISUAL_CAPTURE state=%s image=%s layout_failures=%d" % [state_name, path, _layout_failures.size() - before])

func _log_run_tile_pool_geometry(scene, state_name: String) -> void:
	for candidate in scene.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label == null or not label.text.begins_with("Run tile pool ("):
			continue
		var required_height: float = float(label.get_line_count() * label.get_line_height())
		print("STAGE4_ACCESSIBILITY_WRAP_GEOMETRY state=%s lines=%d line_height=%.1f allocated=%.1f required=%.1f minimum=%.1f custom_minimum=%.1f text=%s" % [
			state_name,
			label.get_line_count(),
			label.get_line_height(),
			label.size.y,
			required_height,
			label.get_minimum_size().y,
			label.custom_minimum_size.y,
			label.text.substr(0, 96).replace("\n", " "),
		])

func _log_header_geometry(scene, state_name: String) -> void:
	for candidate in scene.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label != null and label.text == "Forbidden Table — Alpha Run":
			print("STAGE4_ACCESSIBILITY_HEADER_GEOMETRY state=%s visible=%s rect=%s text=%s" % [state_name, label.is_visible_in_tree(), str(label.get_global_rect()), label.text])
	for control_name in ["TutorialControls", "TutorialToggleButton", "TutorialResetButton"]:
		var control := scene.find_child(control_name, true, false) as Control
		if control != null:
			print("STAGE4_ACCESSIBILITY_HEADER_CONTROL state=%s name=%s visible=%s rect=%s" % [state_name, control_name, control.is_visible_in_tree(), str(control.get_global_rect())])

func _finish_probe(flow_test, scene, profile_path: String, suspend_path: String) -> void:
	print("STAGE4_ACCESSIBILITY_VISUAL_PROBE directory=%s captures=%s layout_failures=%d flow_failures=%d" % [
		_capture_directory,
		"character_select,contract_select,map_choice_act_1,battle_tutorial_on,battle_overview_scrolled,battle_tutorial_disabled,battle_tutorial_reset,reward_choice,map_choice_act_2,run_summary,run_complete,event_choice,elite_reward,boss_reward,shop,workshop_service_choices,workshop_target_choice,workshop_value_choice",
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
	quit(1 if not _layout_failures.is_empty() or not _flow_failures.is_empty() else 0)
