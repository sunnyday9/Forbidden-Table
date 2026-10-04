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
		await _click(button, tree)
		_check(scene.controller.domain.replay_record.commands.size() == before, "Mouse preview of %s creates no Domain command" % kind, failures)
		_check(str(scene._commit_selected_button.get_meta("run_commit_action_id", "")) == action_id, "Mouse selects the exact %s action" % kind, failures)
		await _click(scene._commit_selected_button, tree)
		_check(scene.controller.domain.replay_record.commands.size() == before + 1, "Mouse commit of %s dispatches exactly once" % kind, failures)
	_check(str(scene.controller.domain.state.phase) == "BATTLE", "Mouse choices reach the authoritative Battle", failures)
	if str(scene.controller.domain.state.phase) == "BATTLE":
		var battle_scroll := scene.find_child("BattleViewportScroll", true, false) as ScrollContainer
		_check(battle_scroll != null and battle_scroll.is_visible_in_tree() and battle_scroll.follow_focus, "Battle viewport follows focus across the table and action rail", failures)
		_check(battle_scroll != null and battle_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Battle viewport disables horizontal scrolling", failures)
		var draw: Button = flow.find_action_button(scene, "battle.draw")
		var hand_before: int = scene.controller.domain.current_battle.zones.size("Hand")
		var command_before: int = scene.controller.domain.replay_record.commands.size()
		await _click(draw, tree)
		_check(scene.controller.domain.replay_record.commands.size() == command_before, "Mouse Draw selection is presentation only", failures)
		await _click(scene._battle_view.commit_button(), tree, false)
		_check(scene.controller.domain.current_battle.zones.size("Hand") == hand_before + 1, "Mouse Draw commits the authoritative tile immediately", failures)
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
			await _click(physical_tile, tree)
			_check(scene._battle_view.selected_tile_ids().has(tile_id), "Mouse selects the physical tile named by a live Discard descriptor", failures)
			_check(scene.controller.domain.replay_record.commands.size() == context_commands_before, "Physical tile selection is presentation only", failures)
			var contextual_button: Button = flow.find_action_button(scene, str(discard_action.get("id", "")))
			var context_enabled := bool(discard_action.get("enabled", true)) and not bool(discard_action.get("disabled", false))
			_check(contextual_button != null and contextual_button.is_visible_in_tree() and contextual_button.disabled == (not context_enabled) and not contextual_button.text.strip_edges().is_empty(), "Physical tile selection exposes its current authoritative Discard action", failures)
			await _click(physical_tile, tree)
			_check(not scene._battle_view.selected_tile_ids().has(tile_id), "Mouse can clear a physical hand tile selection", failures)
			_check(scene.controller.domain.replay_record.commands.size() == context_commands_before, "Clearing tile selection submits no command", failures)
	await _click(scene.find_child("SettingsButton", true, false) as Button, tree)
	_check(scene._preferences_overlay.visible, "Mouse opens the settings modal", failures)
	var cancel := scene._preferences_overlay.find_child("OverlayCancelButton", true, false) as Button
	if cancel == null:
		cancel = scene._preferences_overlay.find_child("CancelButton", true, false) as Button
	_check(cancel != null, "Settings exposes a labeled mouse cancel control", failures)
	if cancel != null:
		await _click(cancel, tree)
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
	for action in scene.controller.action_descriptors():
		if str(action.get("kind", "")) == kind:
			return str(action.get("id", ""))
	return ""

func _settle(tree: SceneTree) -> void:
	await tree.process_frame
	await tree.process_frame

func _click(button: Button, tree: SceneTree, settle_after: bool = true) -> void:
	if button == null:
		return
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await _settle(tree)
	var point := button.get_global_rect().get_center()
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

func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
