extends "res://tests/stage4_onboarding_flow_test.gd"

const PresentationState = preload("res://src/presentation/run/run_presentation_state.gd")
const Localization = preload("res://src/presentation/localization/localization.gd")
const REQUIRED_PHASES := [
	"CHARACTER_SELECT",
	"CONTRACT_SELECT",
	"MAP_CHOICE",
	"BATTLE",
	"REWARD_CHOICE",
	"ELITE_REWARD",
	"BOSS_REWARD",
	"SHOP",
	"WORKSHOP",
	"EVENT",
	"RUN_SUMMARY",
	"RUN_COMPLETE",
]
const REQUIRED_BATTLE_ACTION_KINDS := [
	"DRAW",
	"PARTIAL_SETTLEMENT",
	"TECHNIQUE",
	"END_TURN",
	"RESERVE",
	"DISCARD",
	"RESERVE_SWAP",
	"COMPLETE_HAND",
]
const REQUIRED_BATTLE_CUES := [
	"Enemy HP:",
	"Enemy intent:",
	"Pressure:",
	"TP:",
	"Stability:",
	"Patterns available:",
	"Hand (",
	"Reserve (",
]

var _observed_phases: Dictionary = {}
var _observed_action_kinds: Dictionary = {}
var _observed_tutorial_labels: Dictionary = {}
var _audited_screen_states: Dictionary = {}
var _checked_mode_cue_states := 0
var _build_version := "unknown"
var _content_version := "unknown"
var _engine_version := "unknown"

func run() -> Array[String]:
	var failures: Array[String] = []
	await test_pseudo_localized_layout(failures)
	await test_virtual_overview_scroll_reachable(failures)
	await test_virtual_action_details_track_control_focus(failures)
	failures.append_array(await super.run())
	for phase in REQUIRED_PHASES:
		assert_true(_observed_phases.has(phase), "the scripted screen matrix records %s" % phase, failures)
	for action_kind in REQUIRED_BATTLE_ACTION_KINDS:
		assert_true(_observed_action_kinds.has(action_kind), "the Battle accessibility matrix records %s" % action_kind, failures)
	assert_true(_observed_tutorial_labels.has("Disable tutorial") and _observed_tutorial_labels.has("Enable tutorial"), "the scripted matrix records tutorial disable and reenable states", failures)
	assert_true(_checked_mode_cue_states > 0, "critical screen cues are compared in Normal, Fast, and Instant presentation modes", failures)
	var status := "PASS" if failures.is_empty() else "FAIL"
	print("STAGE4_ACCESSIBILITY_REPORT engine=%s build_version=%s content_version=%s viewport=960x540 ui_scale_control=none screen_phases=%s screen_states=%s battle_actions=%s modes=Normal/Fast/Instant(%d cue states) keyboard_accepts=%d controller_accepts=%d layout=post_frame_battle_scroll_check physical_device=NOT_PERFORMED participant_testing=NOT_PERFORMED conformance_claim=NONE final=%s" % [
		_engine_version,
		_build_version,
		_content_version,
		_join_sorted_keys(_observed_phases),
		_join_sorted_keys(_audited_screen_states),
		_join_sorted_keys(_observed_action_kinds),
		_checked_mode_cue_states,
		_virtual_keyboard_accepts,
		_virtual_controller_accepts,
		status,
	])
	return failures

func test_pseudo_localized_layout(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_pseudolocalization := TranslationServer.pseudolocalization_enabled
	var expansion_ratio := float(ProjectSettings.get_setting("internationalization/pseudolocalization/expansion_ratio", 0.0))
	assert_true(expansion_ratio >= 0.3, "the pseudo-localization pass uses the supported 30% expansion setting", failures)
	TranslationServer.pseudolocalization_enabled = false
	var english_template := Localization.template("UI_RUN_SCENE_0012")
	var english_save_warning_template := Localization.template("UI_RUN_CONTROLLER_0001")
	var english_title := Localization.text("UI_RUN_SCENE_0038")
	TranslationServer.pseudolocalization_enabled = true
	var pseudo_message := Localization.format("UI_RUN_SCENE_0012", ["BATTLE_DEFEAT", "user://stage4/recovery-copy.json"])
	var pseudo_save_warning := Localization.format("UI_RUN_CONTROLLER_0001", ["user://stage4/suspend.json"])
	var pseudo_title := Localization.text("UI_RUN_SCENE_0038")
	assert_true(pseudo_message.length() > english_template.length(), "the longest recovery message expands under pseudo-localization", failures)
	assert_true(pseudo_save_warning.length() > english_save_warning_template.length(), "the second-longest player-facing recovery message expands under pseudo-localization", failures)
	assert_true(pseudo_title.length() > english_title.length(), "the critical Run title expands under pseudo-localization", failures)
	assert_true(not pseudo_message.contains("%s") and not pseudo_message.contains("[MISSING") and not pseudo_save_warning.contains("%s") and not pseudo_save_warning.contains("[MISSING"), "the pseudo-localized recovery messages have resolved interpolation and keys", failures)

	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_pseudo_profile_%s.json" % suffix
	var suspend_path := "user://stage4_pseudo_suspend_%s.json" % suffix
	var scene = _new_test_scene(profile_path, suspend_path)
	tree.root.size = Vector2i(960, 540)
	tree.root.add_child(scene)
	await tree.process_frame
	if scene.controller == null:
		assert_true(false, "pseudo-localized Stage 4 scene starts a Run", failures)
	else:
		var character_action := str(scene.controller.action_descriptors()[0].get("id", ""))
		scene._on_action_pressed(character_action)
		var contract_action := str(scene.controller.action_descriptors()[0].get("id", ""))
		scene._on_action_pressed(contract_action)
		var start_node := str(scene.controller.domain.map_definition.start_node_id)
		scene._on_action_pressed("map:%s" % start_node)
		await tree.process_frame
		var title_found := false
		for candidate in scene.find_children("*", "Label", true, false):
			if candidate is Label and candidate.text == pseudo_title:
				title_found = true
				break
		assert_true(title_found, "the critical Run title resolves through pseudo-localization", failures)
		scene._set_wrapped_label_text(scene._profile_status, pseudo_message)
		scene._profile_status.visible = true
		await tree.process_frame
		_audit_text_bounds(scene, failures)
		scene._set_wrapped_label_text(scene._profile_status, pseudo_save_warning)
		await tree.process_frame
		_audit_text_bounds(scene, failures)
		var phase_label: Label = find_named_node(scene, "RunPhaseLabel") as Label
		var tutorial_toggle: Button = find_named_node(scene, "TutorialToggleButton") as Button
		assert_true(phase_label != null and phase_label.is_visible_in_tree() and not phase_label.text.contains("[MISSING"), "the pseudo-localized supported viewport retains its critical phase label", failures)
		assert_true(tutorial_toggle != null and tutorial_toggle.is_visible_in_tree() and not tutorial_toggle.text.contains("[MISSING"), "the pseudo-localized supported viewport retains its critical tutorial control", failures)
		print("STAGE4_LOCALIZATION_PSEUDO_REPORT viewport=960x540 expansion_ratio=%.2f representative_keys=UI_RUN_SCENE_0012,UI_RUN_CONTROLLER_0001 english_chars=%d/%d pseudo_chars=%d/%d critical_layout=CHECKED" % [expansion_ratio, english_template.length(), english_save_warning_template.length(), pseudo_message.length(), pseudo_save_warning.length()])
	tree.root.remove_child(scene)
	scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)
	TranslationServer.pseudolocalization_enabled = previous_pseudolocalization
	TranslationServer.reload_pseudolocalization()

func test_virtual_overview_scroll_reachable(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_accessibility_scroll_profile_%s.json" % suffix
	var suspend_path := "user://stage4_accessibility_scroll_suspend_%s.json" % suffix
	var scene = _new_test_scene(profile_path, suspend_path)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(960, 540)
	tree.root.add_child(scene)
	await tree.process_frame
	if scene.controller == null:
		assert_true(false, "overview scroll regression starts a Run", failures)
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	var character_id := str(scene.controller.action_descriptors()[0].get("id", ""))
	scene._on_action_pressed(character_id)
	var contract_id := str(scene.controller.action_descriptors()[0].get("id", ""))
	scene._on_action_pressed(contract_id)
	var start_node := str(scene.controller.domain.map_definition.start_node_id)
	scene._on_action_pressed("map:%s" % start_node)
	await tree.process_frame
	var scroll: ScrollContainer = find_named_node(scene, "RunOverviewScroll") as ScrollContainer
	assert_true(scroll != null and scroll.is_visible_in_tree() and scroll.focus_mode != Control.FOCUS_NONE, "Battle overview scroll has a visible keyboard/controller focus target", failures)
	var help_label: Label = find_named_node(scene, "RunHelpPrompt") as Label
	assert_true(help_label != null and help_label.text.contains("Tab or L/R shoulder moves focus") and help_label.text.contains("Focus Run state, then press Up/Down to scroll") and help_label.text.contains("focus Scroll up/down and press Enter/A"), "Battle help explains keyboard and controller focus entry and scrolling", failures)
	if scroll != null:
		_audit_text_bounds(scene, failures)
		var scroll_bar := scroll.get_v_scroll_bar()
		assert_true(scroll_bar.max_value > scroll_bar.page, "Battle overview exposes scrollable Hand and tutorial guidance at 960x540", failures)
		var action_button: Button = find_action_button(scene, str(scene.controller.snapshot().get("focused_action_id", "")))
		for use_controller in [false, true]:
			if action_button != null:
				action_button.grab_focus()
			for step in 24:
				if scene.get_viewport().gui_get_focus_owner() == scroll:
					break
				_push_virtual_focus(scene, 1, use_controller)
			assert_true(scene.get_viewport().gui_get_focus_owner() == scroll, "%s can Tab/shoulder to the Run overview scroll" % ("controller" if use_controller else "keyboard"), failures)
			if scene.get_viewport().gui_get_focus_owner() == scroll:
				var before_down := scroll.scroll_vertical
				_push_virtual_direction(scene, 1, use_controller)
				assert_true(scroll.scroll_vertical > before_down, "%s Down moves the focused Run overview" % ("controller" if use_controller else "keyboard"), failures)
				var before_up := scroll.scroll_vertical
				_push_virtual_direction(scene, -1, use_controller)
				assert_true(scroll.scroll_vertical < before_up, "%s Up moves the focused Run overview" % ("controller" if use_controller else "keyboard"), failures)
				_push_virtual_focus(scene, 1, use_controller)
				assert_true(scene.get_viewport().gui_get_focus_owner() != scroll, "%s can leave the Run overview with Tab/shoulder" % ("controller" if use_controller else "keyboard"), failures)
		for control_name in ["OverviewScrollUpButton", "OverviewScrollDownButton"]:
			var button: Button = find_named_node(scene, control_name) as Button
			assert_true(button != null and button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE and not button.text.strip_edges().is_empty(), "%s is a visible labeled keyboard/controller scroll control" % control_name, failures)
	tree.root.remove_child(scene)
	scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)

func test_virtual_action_details_track_control_focus(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_accessibility_details_profile_%s.json" % suffix
	var suspend_path := "user://stage4_accessibility_details_suspend_%s.json" % suffix
	var scene = _new_test_scene(profile_path, suspend_path)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(960, 540)
	tree.root.add_child(scene)
	await tree.process_frame
	if scene.controller == null:
		assert_true(false, "selected-action detail regression starts a Run", failures)
		tree.root.remove_child(scene)
		scene.free()
		_clear_test_file(profile_path)
		_clear_test_file(suspend_path)
		return
	var character_id := str(scene.controller.action_descriptors()[0].get("id", ""))
	scene._on_action_pressed(character_id)
	await tree.process_frame
	var descriptors: Array = scene.controller.action_descriptors()
	assert_true(descriptors.size() > 1, "Contract Select offers multiple focusable detailed choices", failures)
	if descriptors.size() > 1:
		var target_action: Dictionary = descriptors[1]
		var target_button: Button = find_action_button(scene, str(target_action.get("id", "")))
		for use_controller in [false, true]:
			var first_button: Button = find_action_button(scene, str(descriptors[0].get("id", "")))
			if first_button != null:
				first_button.grab_focus()
			for step in 24:
				if target_button != null and scene.get_viewport().gui_get_focus_owner() == target_button:
					break
			_push_virtual_focus(scene, 1, use_controller)
			assert_true(target_button != null and scene.get_viewport().gui_get_focus_owner() == target_button, "%s Tab/shoulder can focus another Contract action" % ("controller" if use_controller else "keyboard"), failures)
			var detail: Label = find_named_node(scene, "SelectedActionDetails") as Label
			assert_true(detail != null and detail.visible and detail.text == scene._action_details_text(target_action), "%s action focus updates the visible wrapped Contract details" % ("controller" if use_controller else "keyboard"), failures)
	tree.root.remove_child(scene)
	scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)

func assert_actions_visible_and_enabled(scene, kind: String, expected_ids: Array, failures: Array[String]) -> void:
	super.assert_actions_visible_and_enabled(scene, kind, expected_ids, failures)
	_audit_screen(scene, failures)

func assert_phase(scene, expected_phase: String, message: String, failures: Array[String]) -> void:
	super.assert_phase(scene, expected_phase, message, failures)
	_audit_screen(scene, failures)

func press_battle_action(scene, action_id: String, failures: Array[String]) -> void:
	_audit_screen(scene, failures)
	super.press_battle_action(scene, action_id, failures)
	_audit_screen(scene, failures)

func _activate_button(scene, button: Button, label: String, failures: Array[String]) -> void:
	_audit_screen(scene, failures)
	super._activate_button(scene, button, label, failures)
	_audit_screen(scene, failures)

func _audit_screen(scene, failures: Array[String]) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var viewport: Viewport = scene.get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	assert_true(viewport_size == Vector2(960, 540), "the tested supported viewport is 960x540", failures)
	if scene.controller == null:
		_audit_suspend_choice(scene, failures)
		return

	var state = scene.controller.domain.state
	var phase := str(state.phase)
	_observed_phases[phase] = true
	if _engine_version == "unknown":
		_engine_version = str(Engine.get_version_info().get("string", "unknown"))
		_build_version = str(ProjectSettings.get_setting("application/config/version", "unknown"))
		_content_version = str(state.content_version)

	var descriptors: Array = scene.controller.action_descriptors()
	var action_kinds: Dictionary = {}
	for action in descriptors:
		var kind := str(action.get("kind", ""))
		if kind.is_empty():
			continue
		action_kinds[kind] = true
		_observed_action_kinds[kind] = true
		var action_id := str(action.get("id", ""))
		var button: Button = find_action_button(scene, action_id)
		if phase == "RUN_SUMMARY" and action_id == "run.summary.acknowledge":
			button = find_named_node(scene, "FinishRunButton") as Button
		assert_true(button != null and button.is_visible_in_tree() and not button.disabled, "%s action %s has a visible enabled control" % [phase, action_id], failures)
		if button != null:
			assert_true(button.focus_mode != Control.FOCUS_NONE and not button.text.strip_edges().is_empty(), "%s action %s has keyboard/controller focus and a text label" % [phase, action_id], failures)

	var phase_label = find_named_node(scene, "RunPhaseLabel")
	assert_true(phase_label is Label and phase_label.is_visible_in_tree() and not phase_label.text.strip_edges().is_empty(), "%s has a visible textual phase label" % phase, failures)
	var visible_text_lines := _visible_text(scene)
	var visible_text := "\n".join(visible_text_lines)
	_audit_selected_action_details(scene, phase, descriptors, failures)
	if phase == "BATTLE":
		for cue in REQUIRED_BATTLE_CUES:
			assert_true(visible_text.contains(cue), "Battle presents the critical cue '%s' as text rather than color alone" % cue, failures)

	var tutorial_toggle: Button = find_named_node(scene, "TutorialToggleButton")
	var tutorial_prompt: Label = find_named_node(scene, "TutorialPrompt")
	if tutorial_toggle != null and tutorial_toggle.is_visible_in_tree():
		_observed_tutorial_labels[tutorial_toggle.text] = true
		if tutorial_prompt != null and tutorial_prompt.visible:
			assert_true(tutorial_prompt.text.begins_with("Tutorial:"), "visible tutorial guidance includes an explicit text cue", failures)

	_audit_focus(scene, phase, failures)
	var bucket := _capture_bucket(scene, phase, action_kinds)
	if not _audited_screen_states.has(bucket):
		_audited_screen_states[bucket] = true
		_audit_presentation_modes(scene, visible_text_lines, phase, failures)

func _audit_suspend_choice(scene, failures: Array[String]) -> void:
	var panel = find_named_node(scene, "SuspendChoicePanel")
	if panel == null or not panel.visible:
		return
	var status = find_named_node(scene, "SuspendStatus")
	assert_true(status is Label and not status.text.strip_edges().is_empty(), "Suspend/Resume choice explains its current state in text", failures)
	for control_name in ["ResumeRunButton", "NewRunFromSuspendButton"]:
		var button: Button = find_named_node(scene, control_name)
		if button != null and button.visible and not button.disabled:
			assert_true(button.focus_mode != Control.FOCUS_NONE and not button.text.strip_edges().is_empty(), "%s choice is keyboard/controller focusable and text-labeled" % control_name, failures)
	var focus_owner := scene.get_viewport().gui_get_focus_owner() as Control
	assert_true(focus_owner != null and focus_owner.is_visible_in_tree(), "Suspend/Resume choice has a visible focus owner", failures)

func _audit_focus(scene, phase: String, failures: Array[String]) -> void:
	if phase == "RUN_SUMMARY":
		var finish_button: Button = find_named_node(scene, "FinishRunButton")
		assert_true(finish_button != null and finish_button.visible and not finish_button.disabled and finish_button.has_focus(), "Run Summary presents visible focus on Finish Run", failures)
		return
	var focus_owner := scene.get_viewport().gui_get_focus_owner() as Control
	assert_true(focus_owner != null and focus_owner.is_visible_in_tree() and focus_owner.focus_mode != Control.FOCUS_NONE, "%s has a visible keyboard/controller focus target" % phase, failures)
	if not scene.controller.snapshot().get("focused_action_id", "").is_empty():
		var action_button: Button = find_action_button(scene, str(scene.controller.snapshot().get("focused_action_id", "")))
		assert_true(action_button != null and action_button.is_visible_in_tree() and action_button.has_focus(), "%s presentation action focus matches the visible GUI focus owner" % phase, failures)
	if phase == "RUN_COMPLETE":
		var new_run_button: Button = find_named_node(scene, "NewRunButton")
		assert_true(new_run_button != null and new_run_button.visible and not new_run_button.disabled, "Run Complete exposes an enabled New Run action", failures)
		assert_true(new_run_button != null and new_run_button.has_focus(), "Run Complete places keyboard/controller focus on New Run", failures)

func _audit_text_bounds(scene, failures: Array[String]) -> void:
	var viewport_size: Vector2 = scene.get_viewport().get_visible_rect().size
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var controls: Array[Node] = []
	controls.append_array(scene.find_children("*", "Label", true, false))
	controls.append_array(scene.find_children("*", "Button", true, false))
	for node in controls:
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		var allocated_size: Vector2 = control.size
		assert_true(rect.size.x > 0.0 and rect.size.y > 0.0, "%s has laid out visible text/control bounds" % control.name, failures)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if not _has_scroll_container_parent(control):
			assert_true(viewport_rect.encloses(rect), "%s text/control stays within the supported viewport (path=%s rect=%s text=%s parent=%s)" % [control.name, str(control.get_path()), str(rect), _text_snippet(control), _parent_layout_context(control)], failures)
		var minimum := control.get_minimum_size()
		if control is Button:
			assert_true(minimum.x <= allocated_size.x + 2.0 and minimum.y <= allocated_size.y + 2.0, "%s button has enough bounds for its label at 960x540" % control.name, failures)
		elif control is Label:
			if control.autowrap_mode == TextServer.AUTOWRAP_OFF:
				assert_true(minimum.x <= rect.size.x + 2.0, "%s single-line label fits its available width" % control.name, failures)
			else:
				var rendered_text_height: float = float(control.get_line_count()) * float(control.get_line_height())
				assert_true(rendered_text_height <= allocated_size.y + 2.0, "%s wrapped label fits its allocated height (path=%s text=%s rect=%s allocated_size=%s minimum=%s custom_minimum=%s lines=%d line_height=%.1f rendered_height=%.1f parent=%s)" % [control.name, str(control.get_path()), _text_snippet(control), str(rect), str(allocated_size), str(minimum), str(control.custom_minimum_size), control.get_line_count(), control.get_line_height(), rendered_text_height, _parent_layout_context(control)], failures)
	for container_name in ["RunOverviewScroll", "AvailableActionsScroll"]:
		var scroll := find_named_node(scene, container_name) as ScrollContainer
		if scroll == null or not scroll.is_visible_in_tree():
			continue
		var horizontal_bar := scroll.get_h_scroll_bar()
		assert_true(horizontal_bar.max_value <= horizontal_bar.page + 1.0, "%s has no horizontal overflow that could clip action or overview text" % container_name, failures)

func _audit_selected_action_details(scene, phase: String, descriptors: Array, failures: Array[String]) -> void:
	if phase in ["RUN_SUMMARY", "RUN_COMPLETE"]:
		return
	var detail: Label = find_named_node(scene, "SelectedActionDetails") as Label
	if descriptors.is_empty():
		assert_true(detail == null or not detail.visible, "%s has no stale action details when it has no action" % phase, failures)
		return
	if detail == null:
		assert_true(false, "%s provides a selected-action detail control" % phase, failures)
		return
	var focused_id := str(scene.controller.snapshot().get("focused_action_id", ""))
	var focus_owner := scene.get_viewport().gui_get_focus_owner() as Control
	if focus_owner != null and focus_owner.has_meta("run_action_id"):
		focused_id = str(focus_owner.get_meta("run_action_id"))
	var expected_action: Dictionary = {}
	for action in descriptors:
		if str(action.get("id", "")) == focused_id:
			expected_action = action
			break
	if expected_action.is_empty() and not descriptors.is_empty():
		expected_action = descriptors[0]
	var expected_detail: String = str(scene._action_details_text(expected_action))
	var selected_button: Button = find_action_button(scene, focused_id)
	var should_show_detail: bool = not expected_detail.is_empty() and selected_button != null and expected_detail != selected_button.text
	assert_true(detail.visible == should_show_detail, "%s selected-action details appear when they add text beyond the action name" % phase, failures)
	if should_show_detail:
		assert_true(detail.is_visible_in_tree() and detail.text == expected_detail, "%s action detail text follows its keyboard/controller-focused action" % phase, failures)
	if phase == "CONTRACT_SELECT":
		assert_true(detail.text.contains("Risk:") and detail.text.contains("Reward:") and detail.text.contains("Build bias:") and detail.text.contains("Yaku signal:"), "Contract Select visibly wraps the full Risk, Reward, Build bias, and Yaku signal details", failures)

func _audit_presentation_modes(scene, baseline_text: Array[String], phase: String, failures: Array[String]) -> void:
	var original_mode := str(scene.controller.snapshot().get("presentation_mode", PresentationState.NORMAL))
	for mode in PresentationState.MODES:
		assert_true(scene.controller.set_mode(str(mode)), "%s accepts %s presentation mode" % [phase, str(mode)], failures)
		var mode_text := _visible_text(scene)
		assert_true(mode_text == baseline_text, "%s retains the same visible critical cues in %s mode" % [phase, str(mode)], failures)
		_checked_mode_cue_states += 1
	scene.controller.set_mode(original_mode)

func _capture_bucket(scene, phase: String, action_kinds: Dictionary) -> String:
	var bucket := phase.to_lower()
	if phase == "BATTLE":
		if action_kinds.has("COMPLETE_HAND"):
			bucket = "battle_complete_hand"
		elif action_kinds.has("PARTIAL_SETTLEMENT"):
			bucket = "battle_partial_settlement"
		elif action_kinds.has("TECHNIQUE"):
			bucket = "battle_technique"
		else:
			bucket = "battle_draw_end_turn"
		var tutorial_prompt: Label = find_named_node(scene, "TutorialPrompt")
		if tutorial_prompt != null and tutorial_prompt.visible:
			bucket += "_tutorial_on"
		elif tutorial_prompt != null:
			bucket += "_tutorial_off"
	elif phase == "MAP_CHOICE":
		bucket += "_act_%d" % int(scene.controller.domain.state.act_index)
	elif phase == "WORKSHOP":
		if action_kinds.has("WORKSHOP_SELECT_TARGET"):
			bucket = "workshop_target_choice"
		elif action_kinds.has("WORKSHOP_SERVICE"):
			bucket = "workshop_value_choice"
		else:
			bucket = "workshop_service_choices"
	return bucket


func _visible_text(scene) -> Array[String]:
	var lines: Array[String] = []
	for node in scene.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.is_visible_in_tree() and not label.text.strip_edges().is_empty():
			lines.append(label.text)
	for node in scene.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.is_visible_in_tree() and not button.text.strip_edges().is_empty():
			lines.append(button.text)
	lines.sort()
	return lines

func _has_scroll_container_parent(control: Control) -> bool:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false

func _text_snippet(control: Control) -> String:
	var text: String = ""
	if control is Label or control is Button:
		text = control.text
	text = text.replace("\n", " ").strip_edges()
	return text.left(100)

func _parent_layout_context(control: Control) -> String:
	var segments: Array[String] = []
	var parent := control.get_parent()
	while parent != null:
		var context := "%s:%s" % [parent.get_class(), parent.name]
		if parent is Control:
			context += " rect=%s clip=%s" % [str(parent.get_global_rect()), str(parent.clip_contents)]
		segments.append(context)
		parent = parent.get_parent()
	return " <- ".join(segments)

func _join_sorted_keys(values: Dictionary) -> String:
	var keys: Array[String] = []
	for key in values.keys():
		keys.append(str(key))
	keys.sort()
	return ",".join(keys)
