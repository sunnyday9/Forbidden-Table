extends RefCounted

const FlowTest = preload("res://tests/stage4_onboarding_flow_test.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	var flow := FlowTest.new()
	var suffix := str(Time.get_ticks_usec())
	var profile := "user://stage45_mouse_%s_profile.json" % suffix
	var suspend := "user://stage45_mouse_%s_suspend.json" % suffix
	var scene = flow._new_test_scene(profile, suspend)
	tree.root.add_child(scene)
	scene._apply_presentation_preferences({"locale": "en", "ui_scale": 1.0, "presentation_mode": "NORMAL", "reduced_motion": false, "ambient_glow": false}, true)
	await _settle(tree)
	for kind in ["CHARACTER", "CONTRACT", "MAP_NODE"]:
		var action_id := _first_id(scene, kind)
		var button: Button = flow.find_action_button(scene, action_id)
		var before: int = scene.controller.domain.replay_record.commands.size()
		await _click(button, tree, failures)
		if kind == "MAP_NODE":
			_check(scene.controller.domain.replay_record.commands.size() == before, "Map click previews without committing", failures)
			var travel := scene.find_child("MapTravelButton", true, false) as Button
			await _click(travel, tree, failures)
		_check(scene.controller.domain.replay_record.commands.size() == before + 1, "One mouse activation of %s dispatches exactly once" % kind, failures)
	_check(str(scene.controller.domain.state.phase) == "BATTLE", "Mouse choices reach the authoritative Battle", failures)
	if str(scene.controller.domain.state.phase) == "BATTLE":
		_print_battle_page_geometry(scene)
		_assert_battle_status_rail_minimum(scene, failures)
		var battle_scroll := scene.find_child("BattleViewportScroll", true, false) as ScrollContainer
		_check(battle_scroll != null and battle_scroll.is_visible_in_tree() and battle_scroll.follow_focus, "Battle viewport follows focus across the table and action rail", failures)
		_check(battle_scroll != null and battle_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Battle viewport disables horizontal scrolling", failures)
		var draw: Button = flow.find_action_button(scene, "battle.draw")
		var hand_before: int = scene.controller.domain.current_battle.zones.size("Hand")
		var command_before: int = scene.controller.domain.replay_record.commands.size()
		await _click(draw, tree, failures)
		_check(scene.controller.domain.current_battle.zones.size("Hand") == hand_before + 1, "One mouse activation immediately draws the authoritative tile", failures)
		_check(scene.controller.domain.replay_record.commands.size() == command_before + 1, "Mouse Draw produces one command", failures)
		var feedback = scene._battle_view.get("_motion_feedback")
		_check(feedback != null and feedback.get("_active_tween") != null and feedback.get("_active_tween").is_running(), "Root Normal Draw retains its cosmetic tween after accepted render (mode=%s reduced=%s hand=%s generation=%s)" % [scene._battle_view.get("_presentation_mode"), scene._battle_view.get("_reduced_motion"), scene._battle_view.get("_last_hand_ids"), feedback.get("_generation")], failures)
		if feedback != null:
			var reference = feedback.get("_active_target")
			_check(reference != null and reference.get_ref() != null and is_instance_valid(reference.get_ref()), "Draw tween targets the surviving rendered tile", failures)
		await _settle(tree)
		var checkpoint: Dictionary = scene.controller.domain.checkpoint()
		var commands: int = scene.controller.domain.replay_record.commands.size()
		scene._apply_presentation_preferences({"locale": "en", "ui_scale": 1.0, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
		_check(scene.controller.domain.checkpoint() == checkpoint and scene.controller.domain.replay_record.commands.size() == commands, "Motion cancellation never changes authority or submits a command", failures)
		_check(feedback.get("_active_tween") == null, "Instant cancels active cosmetic playback", failures)
		var discard_action: Dictionary = {}
		for action in scene.controller.action_descriptors():
			if str(action.get("kind", "")) == "DISCARD":
				discard_action = action
				break
		var tile_id := str(discard_action.get("target_id", ""))
		var physical_tile: Button = scene._battle_view.tile_button(tile_id) if not tile_id.is_empty() else null
		_check(physical_tile != null and physical_tile.is_visible_in_tree() and physical_tile.focus_mode != Control.FOCUS_NONE and not physical_tile.accessibility_name.strip_edges().is_empty(), "Mouse can reach an accessible physical hand tile for a legal context action after Draw", failures)
		if physical_tile != null and not discard_action.is_empty():
			var context_commands_before: int = scene.controller.domain.replay_record.commands.size()
			await _click(physical_tile, tree, failures)
			_check(scene._battle_view.selected_tile_ids().has(tile_id), "Mouse selects the physical tile named by a live Discard descriptor", failures)
			_check(scene.controller.domain.replay_record.commands.size() == context_commands_before, "Physical tile selection is presentation only", failures)
			var contextual_button: Button = flow.find_action_button(scene, str(discard_action.get("id", "")))
			var context_enabled := bool(discard_action.get("enabled", true)) and not bool(discard_action.get("disabled", false))
			_check(contextual_button != null and contextual_button.is_visible_in_tree() and contextual_button.disabled == (not context_enabled) and not contextual_button.text.strip_edges().is_empty(), "Physical tile selection exposes its current authoritative Discard action", failures)
			await _click(physical_tile, tree, failures)
			_check(not scene._battle_view.selected_tile_ids().has(tile_id), "Mouse can clear a physical hand tile selection", failures)
			_check(scene.controller.domain.replay_record.commands.size() == context_commands_before, "Clearing tile selection submits no command", failures)
	await _click(scene.find_child("SettingsButton", true, false) as Button, tree, failures)
	_check(scene._preferences_overlay.visible, "Mouse opens the settings modal", failures)
	var cancel := scene._preferences_overlay.find_child("OverlayCancelButton", true, false) as Button
	if cancel == null:
		cancel = scene._preferences_overlay.find_child("CancelButton", true, false) as Button
	_check(cancel != null, "Settings exposes a labeled mouse cancel control", failures)
	if cancel != null:
		await _click(cancel, tree, failures)
		_check(not scene._preferences_overlay.visible, "Mouse Cancel closes settings", failures)
		var owner := tree.root.gui_get_focus_owner()
		_check(owner != null and owner.name == "SettingsButton", "Modal returns visible focus to its mouse opener", failures)
	tree.root.remove_child(scene)
	scene.free()
	flow._clear_test_file(profile)
	flow._clear_test_file(suspend)
	await tree.process_frame
	return failures

func _first_id(scene, kind: String) -> String:
	if kind == "CHARACTER":
		return "character:base.character.sequence"
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) == kind:
			return str(action.get("id", ""))
	return ""

func _settle(tree: SceneTree) -> void:
	await tree.process_frame
	await tree.process_frame

func _click(button: Button, tree: SceneTree, failures: Array[String], settle_after: bool = true) -> void:
	if button == null:
		_check(false, "Pointer target exists before mouse dispatch", failures)
		return
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await _settle(tree)
	var visible_rect := _visible_rect_through_clips(button, tree.root.get_visible_rect())
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		_check(false, "Pointer target has a visible hit area through every ancestor clip before dispatch (%s; %s)" % [str(button.get_meta("run_action_id", button.name)), _pointer_clip_context(button, tree.root.get_visible_rect())], failures)
		return
	var point := visible_rect.get_center()
	var point_visible := _point_visible_through_clips(button, point, tree.root.get_visible_rect())
	var center_visible := _center_visible_through_clips(button, tree.root.get_visible_rect())
	print("MOUSE_POINTER_TARGET id=%s target_center_visible=%s hit_point=%s visible_hit_rect=%s context=%s" % [str(button.get_meta("run_action_id", button.name)), str(center_visible), str(point), str(visible_rect), _pointer_clip_context(button, tree.root.get_visible_rect())])
	_check(point_visible, "Pointer hit point stays inside the actual button and every viewport/ancestor clip before dispatch (%s; %s)" % [str(button.get_meta("run_action_id", button.name)), _pointer_clip_context(button, tree.root.get_visible_rect())], failures)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	if settle_after:
		await _settle(tree)
func _center_visible_through_clips(control: Control, viewport_rect: Rect2) -> bool:
	return _point_visible_through_clips(control, control.get_global_rect().get_center() if control != null else Vector2.INF, viewport_rect)


func _point_visible_through_clips(control: Control, point: Vector2, viewport_rect: Rect2) -> bool:
	if control == null or not control.is_visible_in_tree() or not control.get_global_rect().has_point(point) or not viewport_rect.has_point(point):
		return false
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var parent := ancestor as Control
			if not parent.is_visible_in_tree() or parent.clip_contents and not parent.get_global_rect().has_point(point):
				return false
		ancestor = ancestor.get_parent()
	return true


func _visible_rect_through_clips(control: Control, viewport_rect: Rect2) -> Rect2:
	if control == null or not control.is_visible_in_tree():
		return Rect2()
	var visible_rect := control.get_global_rect().intersection(viewport_rect)
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var parent := ancestor as Control
			if not parent.is_visible_in_tree():
				return Rect2()
			if parent.clip_contents:
				visible_rect = visible_rect.intersection(parent.get_global_rect())
		ancestor = ancestor.get_parent()
	return visible_rect


func _pointer_clip_context(control: Control, viewport_rect: Rect2) -> String:
	if control == null:
		return "null target"
	var center := control.get_global_rect().get_center()
	var entries: Array[String] = ["viewport=%s center=%s rect=%s disabled=%s queued=%s" % [str(viewport_rect), str(center), str(control.get_global_rect()), str(control.disabled if control is BaseButton else false), str(control.is_queued_for_deletion())]]
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			var parent := ancestor as Control
			var details := "%s:%s visible=%s clip=%s rect=%s contains=%s" % [parent.name, parent.get_class(), str(parent.is_visible_in_tree()), str(parent.clip_contents), str(parent.get_global_rect()), str(parent.get_global_rect().has_point(center))]
			if parent is ScrollContainer:
				var scroll := parent as ScrollContainer
				details += " scroll=%s/%s" % [str(scroll.scroll_vertical), str(maxf(0.0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page))]
			entries.append(details)
		ancestor = ancestor.get_parent()
	return " | ".join(entries)


func _print_battle_page_geometry(scene: Node) -> void:
	var page := scene.get("_page") as Control
	var tutorial := scene.get("_tutorial_prompt") as Label
	var status_rail := scene.get("_run_status_panel") as Control
	var overview_scroll := scene.get("_overview_scroll") as ScrollContainer
	var overview_content := scene.get("_overview_content") as Control
	if page != null:
		print("MOUSE_BATTLE_PAGE page_rect=%s page_combined=%s page_custom=%s" % [str(page.get_global_rect()), str(page.get_combined_minimum_size()), str(page.custom_minimum_size)])
		for child in page.get_children():
			if child is Control:
				var control := child as Control
				print("MOUSE_BATTLE_PAGE_CHILD name=%s visible=%s rect=%s combined=%s custom=%s" % [str(control.name), str(control.visible), str(control.get_global_rect()), str(control.get_combined_minimum_size()), str(control.custom_minimum_size)])
	if tutorial != null:
		print("MOUSE_BATTLE_TUTORIAL visible=%s text=%s rect=%s width=%.1f line_count=%d combined=%s custom=%s" % [str(tutorial.is_visible_in_tree()), tutorial.text, str(tutorial.get_global_rect()), tutorial.size.x, tutorial.get_line_count(), str(tutorial.get_combined_minimum_size()), str(tutorial.custom_minimum_size)])
	if status_rail != null and overview_scroll != null and overview_content != null:
		var style := status_rail.get_theme_stylebox("panel")
		var insets := style.get_minimum_size().y if style != null else 0.0
		print("MOUSE_BATTLE_STATUS rail_min=%.1f rail_rect=%s overview_min=%.1f overview_rect=%s overview_content_min=%.1f overview_content_rect=%s panel_insets=%.1f" % [status_rail.custom_minimum_size.y, str(status_rail.get_global_rect()), overview_scroll.custom_minimum_size.y, str(overview_scroll.get_global_rect()), overview_content.get_combined_minimum_size().y, str(overview_content.get_global_rect()), insets])
		for child in overview_content.get_children():
			if child is Control:
				var control := child as Control
				var detail := ""
				if control is Label:
					var label := control as Label
					detail = " text=%s lines=%d" % [label.text, label.get_line_count()]
				print("MOUSE_BATTLE_OVERVIEW_CHILD name=%s visible=%s rect=%s combined=%s custom=%s%s" % [str(control.name), str(control.visible), str(control.get_global_rect()), str(control.get_combined_minimum_size()), str(control.custom_minimum_size), detail])


func _assert_battle_status_rail_minimum(scene: Node, failures: Array[String]) -> void:
	var status_rail := scene.get("_run_status_panel") as Control
	var overview_scroll := scene.get("_overview_scroll") as ScrollContainer
	var overview_content := scene.get("_overview_content") as Control
	var tutorial := scene.get("_tutorial_prompt") as Label
	if status_rail == null or overview_scroll == null or overview_content == null:
		_check(false, "Battle status rail exposes its overview sizing controls", failures)
		return
	var preferences: Dictionary = scene.get("_applied_preferences")
	var ui_scale := float(preferences.get("ui_scale", 1.0))
	var overview_base := 24.0 * ui_scale
	var panel_base := 34.0 * ui_scale if tutorial != null and tutorial.visible else 0.0
	var overview_expected := maxf(overview_base, overview_content.get_combined_minimum_size().y)
	var style := status_rail.get_theme_stylebox("panel")
	var panel_insets := style.get_minimum_size().y if style != null else 0.0
	var panel_expected := maxf(panel_base, overview_expected + panel_insets)
	_check(absf(overview_scroll.custom_minimum_size.y - overview_expected) <= 0.5, "Battle overview scroll minimum tracks its settled visible content height (actual=%.1f expected=%.1f content=%.1f)" % [overview_scroll.custom_minimum_size.y, overview_expected, overview_content.get_combined_minimum_size().y], failures)
	_check(absf(status_rail.custom_minimum_size.y - panel_expected) <= 0.5, "Battle status rail minimum does not retain hidden-page height (actual=%.1f expected=%.1f)" % [status_rail.custom_minimum_size.y, panel_expected], failures)
	_check(status_rail.custom_minimum_size.y <= 200.0 * ui_scale, "Battle status rail leaves no stale multi-screen blank area (height=%.1f scale=%.2f)" % [status_rail.custom_minimum_size.y, ui_scale], failures)

func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
