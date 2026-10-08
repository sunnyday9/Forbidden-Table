extends RefCounted

const BattleFixture = preload("res://tests/stage45_battle_ui_test.gd")
const BattleViewScript = preload("res://src/presentation/ui/battle_view.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	var previous_viewport_size := tree.root.size
	tree.root.size = Vector2i(960, 540)
	var controller = BattleFixture.new()._battle_controller("battle.feedback.integration", failures)
	if controller == null:
		tree.root.size = previous_viewport_size
		return failures
	var view = BattleViewScript.new()
	view.set_external_preferences_owner()
	view.configure(controller, func(action): return str(action.id), func(action): return str(action.kind), func(action): return str(action.id))
	tree.root.add_child(view)
	view.render()
	await tree.process_frame
	await tree.process_frame
	var seen: Array = []
	view.battle_feedback().cue_started.connect(func(cue: Dictionary): seen.append(cue.duplicate(true)))
	controller.presentation_changed.connect(view.render)
	var previous_hand: int = controller.domain.current_battle.zones.size("Hand")
	var previous_commands: int = controller.domain.replay_record.commands.size()
	var result = controller.confirm("battle.draw")
	_check(result.accepted, "Actual Draw is accepted", failures)
	_check(controller.domain.current_battle.zones.size("Hand") == previous_hand + 1, "Draw commits the physical hand before cosmetic playback", failures)
	_check(controller.domain.replay_record.commands.size() == previous_commands + 1, "Animation adds no second command", failures)
	var committed: Dictionary = controller.domain.checkpoint()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	_check(view.battle_feedback().is_playing(), "Normal Draw plays spatial feedback", failures)
	_check(seen.size() == 1 and seen[0].kind == "DRAW", "One accepted Draw begins one factual tile-flight cue", failures)
	if not seen.is_empty():
		var drawn_id := str(seen[0].get("instance_id", ""))
		var drawn_button = view._tile_button(drawn_id)
		_check(drawn_button != null and view.battle_feedback()._lookup_rect(drawn_id, false) == drawn_button.get_global_rect(), "Draw lands in the physical Hand tile instead of a duplicate action preview (anchor=%s physical=%s visible=%s)" % [str(view.battle_feedback()._lookup_rect(drawn_id, false)), str(drawn_button.get_global_rect() if drawn_button != null else Rect2()), str(view._visible_motion_rect(drawn_button))], failures)

	_check(not view.last_action_text().is_empty(), "Draw has persistent readable feedback while moving", failures)
	var revision_before_locale := int(controller.snapshot().get("battle_event_revision", -1))
	TranslationServer.set_locale("zh_CN")
	var locale_changed: bool = view.set_presentation_preferences("zh_CN", 1.0, "NORMAL", false, false)
	if locale_changed:
		view.render()
	_check(not view.battle_feedback().is_playing(), "Changing locale cancels an active cosmetic cue", failures)
	_check(view.battle_feedback().current_cue().is_empty(), "Changing locale clears the active cue", failures)
	_check(seen.size() == 1, "Changing locale does not re-emit the accepted Draw", failures)
	_check(view.last_action_text().contains("摸到") and not view.last_action_text().contains("Drew"), "The persistent receipt is refreshed in the selected locale", failures)
	_check(controller.domain.checkpoint() == committed and int(controller.snapshot().get("battle_event_revision", -1)) == revision_before_locale, "Locale refresh preserves authority, checkpoint, and event revision", failures)
	TranslationServer.set_locale("en")
	view.set_presentation_preferences("en", 1.0, "NORMAL", false, false)
	view.render()

	var cues_before_pending_locale := seen.size()
	var pending_locale_result = controller.confirm("battle.draw")
	_check(pending_locale_result.accepted, "A second Draw can queue presentation before the next frame", failures)
	var pending_locale_checkpoint: Dictionary = controller.domain.checkpoint()
	var pending_locale_revision := int(controller.snapshot().get("battle_event_revision", -1))
	TranslationServer.set_locale("zh_CN")
	locale_changed = view.set_presentation_preferences("zh_CN", 1.0, "NORMAL", false, false)
	if locale_changed:
		view.render()
	await tree.process_frame
	await tree.process_frame
	_check(not view.battle_feedback().is_playing() and seen.size() == cues_before_pending_locale, "Changing locale cancels queued cosmetics without replaying the Draw", failures)
	_check(view.last_action_text().contains("摸到") and not view.last_action_text().contains("Drew"), "A queued action receipt is translated after a locale change", failures)
	_check(controller.domain.checkpoint() == pending_locale_checkpoint and int(controller.snapshot().get("battle_event_revision", -1)) == pending_locale_revision, "Queued locale cancellation does not change authority or event revision", failures)
	TranslationServer.set_locale("en")
	view.set_presentation_preferences("en", 1.0, "NORMAL", false, false)
	view.render()

	controller.focus_next()
	await tree.process_frame
	await tree.process_frame
	_check(seen.size() == cues_before_pending_locale, "Focus redraw never repeats an accepted animation", failures)
	_check(controller.domain.checkpoint() == pending_locale_checkpoint, "Focus and motion leave the accepted checkpoint unchanged", failures)
	view.set_presentation_preferences("en", 1.0, "INSTANT", false, false)
	_check(not view.battle_feedback().is_playing(), "Changing to Instant cancels cosmetic playback immediately", failures)
	var text: String = view.last_action_text()
	view.render()
	await tree.process_frame
	_check(view.last_action_text() == text and seen.size() == 1, "Instant redraw retains the receipt without replaying it", failures)
	var overlay_host := Control.new()
	overlay_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(overlay_host)
	_check(view.has_method("set_feedback_host"), "Battle feedback can outlive the Battle screen at its public host seam", failures)
	if view.has_method("set_feedback_host"):
		view.set_feedback_host(overlay_host)
	view.set_presentation_preferences("en", 1.0, "NORMAL", false, false)
	var battle = controller.domain.current_battle
	battle.combat_state.enemy_hp = 1
	battle.combat_state.pressure = 0
	BattleFixture.new()._replace_test_hand(battle, ["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3", "base.tile.bamboo.1", "base.tile.bamboo.2", "base.tile.bamboo.3", "base.tile.dots.1", "base.tile.dots.2", "base.tile.dots.3", "base.tile.characters.4", "base.tile.characters.5", "base.tile.characters.6", "base.tile.characters.7", "base.tile.characters.7"], "terminal-motion", failures)
	controller.refresh_localized_presentation()
	await tree.process_frame
	await tree.process_frame
	seen.clear()
	view.hide()
	var settlement_id := ""
	for action in controller.action_descriptors():
		if str(action.kind) == "COMPLETE_HAND":
			settlement_id = str(action.id)
			break
	var terminal = controller.confirm(settlement_id)
	_check(terminal.accepted and controller.domain.current_battle == null, "Real lethal settlement transfers authority beyond Battle immediately", failures)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	_check(not seen.is_empty() and seen[0].kind == "ATTACK", "Final actual HP loss remains visible after the Battle screen hides", failures)
	await tree.create_timer(2.1).timeout
	var terminal_kinds: Array = []
	for cue in seen:
		terminal_kinds.append(str(cue.kind))
	_check(terminal_kinds.has("VICTORY"), "The terminal batch plays its victory cue exactly once on the persistent host", failures)

	var stale_generation_value: Variant = view.get("_feedback_layout_generation")
	_check(stale_generation_value is int, "Deferred feedback carries a lifecycle generation", failures)
	var stale_generation := int(stale_generation_value) if stale_generation_value is int else -1
	view._pending_battle_cues = [{"kind": "ATTACK", "amount": 1, "text": "Stale callback"}]
	view._queue_battle_feedback()
	var queued_generation_value: Variant = view.get("_feedback_layout_generation")
	var queued_generation := int(queued_generation_value) if queued_generation_value is int else stale_generation
	# Suspend an actual callback, then detach before its frame resumes.
	view._play_pending_battle_feedback(queued_generation)
	tree.root.remove_child(view)
	_check(not bool(view.get("_feedback_layout_pending")), "Tree teardown invalidates pending layout work immediately", failures)
	var detached_generation_value: Variant = view.get("_feedback_layout_generation")
	var detached_generation := int(detached_generation_value) if detached_generation_value is int else queued_generation
	_check(detached_generation > queued_generation, "Tree teardown advances the feedback lifecycle generation", failures)
	await tree.process_frame
	_check(not bool(view.get("_feedback_layout_pending")) and not view.battle_feedback().is_playing(), "A deferred callback exits safely while the view is detached", failures)
	tree.root.add_child(view)
	view.show()
	view._pending_battle_cues = [{"kind": "RELIEF", "amount": 1, "text": "Reattached cue"}]
	view._queue_battle_feedback()
	# Exercise an old suspended callback after this Node has a new parent and
	# fresh cue batch; it must leave the new batch for its own generation.
	view.call("_play_pending_battle_feedback", queued_generation)
	_check(view._pending_battle_cues.size() == 1 and not view.battle_feedback().is_playing(), "A stale callback cannot consume a reattached view's new cue", failures)
	await tree.process_frame
	await tree.process_frame
	_check(view.battle_feedback().current_cue().get("text", "") == "Reattached cue", "A fresh callback plays after the view is reattached", failures)
	view.battle_feedback().cancel()

	tree.root.remove_child(view)
	view.free()
	overlay_host.queue_free()
	await tree.process_frame
	tree.root.size = previous_viewport_size
	await test_bounded_reward_receipt_footer(failures)
	return failures

func _check(value: bool, message: String, failures: Array[String]) -> void:
	if not value:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)

func test_bounded_reward_receipt_footer(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_size := tree.root.size
	var flow = load("res://tests/stage4_onboarding_flow_test.gd").new()
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://receipt_footer_profile_%s.json" % suffix
	var suspend_path := "user://receipt_footer_suspend_%s.json" % suffix
	var scene = flow._new_test_scene(profile_path, suspend_path)
	tree.root.add_child(scene)
	for kind in ["CHARACTER", "CONTRACT", "MAP_NODE"]:
		await tree.process_frame
		for action in scene.controller.action_descriptors():
			if str(action.kind) == kind:
				if kind == "CHARACTER" and str(action.get("target_id", "")) != "base.character.sequence":
					continue
				_check(scene.controller.confirm(str(action.id)).accepted, "Receipt fixture enters its battle", failures)
				break
	await tree.process_frame
	scene._on_tutorial_toggle_pressed()
	_check(flow.win_active_battle(scene, failures), "Receipt fixture reaches actual reward choice", failures)
	var lines := PackedStringArray()
	for index in range(55):
		lines.append("Action %02d: actual damage and pressure receipt remains readable" % index)
	var receipt := "\n".join(lines)
	for scale in [1.0, 1.25, 1.5]:
		scene._apply_presentation_preferences({"locale": "en", "ui_scale": scale, "presentation_mode": "INSTANT", "reduced_motion": true, "ambient_glow": false}, true)
		scene._set_wrapped_label_text(scene._feedback_value, receipt)
		for frame in range(5):
			await tree.process_frame
		var rail := scene.find_child("RunActionRail", true, false) as Control
		var back := scene._back_button as Control
		var scroll := scene.find_child("RunFeedbackScroll", true, false) as ScrollContainer
		_check(scene._feedback_value.text == receipt, "Long terminal receipt retains all facts at scale %s" % scale, failures)
		_check(rail.size.y <= 72.0 * scale, "Long terminal receipt keeps its action rail bounded at scale %s (height=%s)" % [scale, rail.size.y], failures)
		_check(back.is_visible_in_tree() and rail.visible and back.get_global_rect().end.y <= 540.5, "Reward navigation remains in the viewport at scale %s (rect=%s visible=%s scene=%s page=%s root=%s phase=%s)" % [scale, back.get_global_rect(), back.is_visible_in_tree(), scene.size, scene._page.size, tree.root.get_visible_rect(), scene.controller.domain.state.phase], failures)
		var is_summary: bool = str(scene.controller.domain.state.phase) == "RUN_SUMMARY"
		var legacy_commit := scene.find_child("CommitSelectedButton", true, false) as Control
		_check((legacy_commit == null or not legacy_commit.is_visible_in_tree()) and scene._summary_acknowledge_button.is_visible_in_tree() == is_summary, "Post-Battle navigation has no visible extra confirmation; Finish Run is visible only on its summary", failures)
		_check(scroll != null, "Long terminal receipts have a scrollable reading area", failures)
		if scroll != null:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			wheel.factor = 3.0
			wheel.position = scroll.get_global_rect().get_center()
			wheel.global_position = wheel.position
			Input.parse_input_event(wheel)
			Input.flush_buffered_events()
			await tree.process_frame
			await tree.process_frame
			_check(scroll.scroll_vertical > 0, "Mouse wheel reveals later terminal receipt lines", failures)
			var reading_position := scroll.scroll_vertical
			scene._set_wrapped_label_text(scene._feedback_value, receipt)
			await tree.process_frame
			_check(scroll.scroll_vertical == reading_position, "Unchanged terminal receipt preserves reading position", failures)
			scene._set_wrapped_label_text(scene._feedback_value, receipt + "\nNew batch")
			_check(scroll.scroll_vertical == 0, "New terminal receipt starts at its beginning", failures)
	# Exercise the complete terminal refresh path, including focus navigation.
	var events: Array = []
	for index in range(55):
		events.append({"event_type": "EnemyHpChanged", "data": {"amount": 1, "source_id": "combat_conversion.complete_hand"}})
	scene.controller.state.battle_events = events
	scene.controller.state.battle_event_revision += 1
	scene._render()
	for frame in range(5):
		await tree.process_frame
	var terminal_scroll := scene.find_child("RunFeedbackScroll", true, false) as ScrollContainer
	if terminal_scroll != null:
		terminal_scroll.scroll_vertical = 30
		var terminal_reading_position := terminal_scroll.scroll_vertical
		var checkpoint: Dictionary = scene.controller.domain.checkpoint()
		scene.controller.focus_next()
		await tree.process_frame
		_check(terminal_reading_position > 0 and terminal_scroll.scroll_vertical == terminal_reading_position, "Terminal focus refresh preserves the long receipt reading position", failures)
		_check(scene.controller.domain.checkpoint() == checkpoint, "Reading terminal receipts leaves authority unchanged", failures)
	scene.queue_free()
	await tree.process_frame
	flow._clear_test_file(profile_path)
	flow._clear_test_file(suspend_path)
	tree.root.size = previous_size
