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
const BATTLE_CONTEXT_ACTION_KINDS := [
	"PARTIAL_SETTLEMENT",
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
	await test_map_labels_fit_at_supported_scales(failures)
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
	print("STAGE4_ACCESSIBILITY_REPORT engine=%s build_version=%s content_version=%s viewport=960x540 ui_scale_control=100/125/150 screen_phases=%s screen_states=%s battle_actions=%s modes=Normal/Fast/Instant(%d cue states) keyboard_accepts=%d controller_accepts=%d layout=post_frame_controls_and_scroll physical_device=NOT_PERFORMED participant_testing=NOT_PERFORMED conformance_claim=NONE final=%s" % [
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


func test_map_labels_fit_at_supported_scales(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var suffix := str(Time.get_ticks_usec())
	var profile_path := "user://stage4_map_scale_profile_%s.json" % suffix
	var suspend_path := "user://stage4_map_scale_suspend_%s.json" % suffix
	var scene = _new_test_scene(profile_path, suspend_path)
	tree.root.size = Vector2i(960, 540)
	tree.root.add_child(scene)
	await tree.process_frame
	if scene.controller == null:
		assert_true(false, "map scale geometry regression starts a Run", failures)
	else:
		_choose_sequence_and_contract(scene, failures)
		await tree.process_frame
		assert_true(str(scene.controller.domain.state.phase) == "MAP_CHOICE", "map scale geometry regression remains on the live map", failures)
		for locale in ["en", "zh_CN"]:
			for scale in [1.25, 1.5]:
				scene._apply_presentation_preferences({"locale": locale, "ui_scale": scale, "presentation_mode": "NORMAL", "reduced_motion": false, "ambient_glow": true}, true)
				await tree.process_frame
				await tree.process_frame
				_audit_map_label_enclosure(scene, "%s %.2f" % [locale, scale], failures)
		var previous_pseudo := TranslationServer.pseudolocalization_enabled
		TranslationServer.pseudolocalization_enabled = true
		TranslationServer.reload_pseudolocalization()
		scene._apply_presentation_preferences({"locale": "en", "ui_scale": 1.5, "presentation_mode": "NORMAL", "reduced_motion": false, "ambient_glow": true}, true)
		await tree.process_frame
		await tree.process_frame
		_audit_map_label_enclosure(scene, "pseudo 1.50", failures)
		TranslationServer.pseudolocalization_enabled = previous_pseudo
		TranslationServer.reload_pseudolocalization()
	tree.root.remove_child(scene)
	scene.free()
	_clear_test_file(profile_path)
	_clear_test_file(suspend_path)
	await tree.process_frame


func _audit_map_label_enclosure(scene, scale_label: String, failures: Array[String]) -> void:
	var checked := 0
	for node in scene.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.has_meta("map_node_id") or not button.is_visible_in_tree():
			continue
		var label := button.find_child("MapNodeLabel", true, false) as Label
		if label == null:
			assert_true(false, "map node %s keeps its accessible label (%s)" % [button.name, scale_label], failures)
			continue
		checked += 1
		var button_rect := button.get_global_rect()
		var label_rect := label.get_global_rect()
		assert_true(button_rect.grow(1.0).encloses(label_rect), "map node label remains inside its choice control at %s (button=%s label=%s min=%s button_min=%s lines=%d line_height=%.1f text=%s)" % [scale_label, str(button_rect), str(label_rect), str(label.get_minimum_size()), str(button.get_minimum_size()), label.get_line_count(), label.get_line_height(), _text_snippet(label)], failures)
		var rendered_height := float(label.get_line_count()) * float(label.get_line_height())
		assert_true(rendered_height <= label.size.y + 2.0, "map node label line height fits its allocated control at %s (text=%s lines=%d line_height=%.1f allocated=%s)" % [scale_label, _text_snippet(label), label.get_line_count(), label.get_line_height(), str(label.size)], failures)
	assert_true(checked > 0, "map scale regression finds visible map nodes at %s" % scale_label, failures)

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
		_choose_sequence_and_contract(scene, failures)
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
		var tutorial_toggle: Button = find_named_node(scene, "SettingsButton") as Button
		assert_true(phase_label != null and phase_label.is_visible_in_tree() and not phase_label.text.contains("[MISSING"), "the pseudo-localized supported viewport retains its critical phase label", failures)
		assert_true(tutorial_toggle != null and tutorial_toggle.is_visible_in_tree() and not tutorial_toggle.text.contains("[MISSING"), "the pseudo-localized supported viewport retains its Help / Settings control", failures)
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
	if scene.controller != null:
		_choose_sequence_and_contract(scene, failures)
		scene._on_action_pressed("map:%s" % str(scene.controller.domain.map_definition.start_node_id))
		await tree.process_frame
		var scroll := find_named_node(scene, "PlayerGuidanceScroll") as ScrollContainer
		assert_true(scroll != null and scroll.is_visible_in_tree() and scroll.focus_mode != Control.FOCUS_NONE, "Run guidance scroll has a visible keyboard/controller focus target", failures)
		var battle_scroll := find_named_node(scene, "BattleViewportScroll") as ScrollContainer
		assert_true(battle_scroll != null and battle_scroll.is_visible_in_tree() and battle_scroll.follow_focus, "Battle table and action choices share a visible focus-following viewport scroll", failures)
		assert_true(battle_scroll != null and battle_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Battle viewport scroll disables horizontal overflow", failures)
		if scroll != null:
			_audit_text_bounds(scene, failures)
			var guidance_bar := scroll.get_v_scroll_bar()
			assert_true(guidance_bar.max_value <= guidance_bar.page + 1.0, "measured Run guidance fits its inner viewport at 960x540", failures)
			assert_true(scene._tutorial_prompt != null and scene._tutorial_prompt.visible and not scene._tutorial_prompt.text.is_empty(), "the short-window scroll fixture uses visible, localized tutorial guidance", failures)
			var root_scroll := find_named_node(scene, "RunRootScroll") as ScrollContainer
			tree.root.size = Vector2i(960, 240)
			await tree.process_frame
			await tree.process_frame
			var root_bar: VScrollBar = root_scroll.get_v_scroll_bar() if root_scroll != null else null
			assert_true(root_bar != null and root_bar.max_value > root_bar.page, "short Run window has real page overflow for mapped scrolling", failures)
			guidance_bar = scroll.get_v_scroll_bar()
			assert_true(guidance_bar.max_value <= guidance_bar.page + 1.0, "measured Run guidance remains within its own viewport in a short window", failures)
			if root_scroll != null:
				root_scroll.scroll_vertical = 0
			for use_controller in [false, true]:
				for step in scene.find_children("*", "Control", true, false).size() + 1:
					if scene.get_viewport().gui_get_focus_owner() == scroll:
						break
					_push_virtual_focus(scene, 1, use_controller)
				assert_true(scene.get_viewport().gui_get_focus_owner() == scroll, "Tab/shoulder reaches Run guidance scroll", failures)
				if root_scroll != null:
					root_scroll.scroll_vertical = 0
				_push_virtual_direction(scene, 1, use_controller)
				assert_true(root_scroll != null and root_scroll.scroll_vertical > 0, "mapped Down scrolls the overflowing Run page while guidance fits", failures)
				_push_virtual_direction(scene, -1, use_controller)
				assert_true(root_scroll != null and root_scroll.scroll_vertical == 0, "mapped Up returns the overflowing Run page to its beginning", failures)
				_push_virtual_focus(scene, 1, use_controller)
				assert_true(scene.get_viewport().gui_get_focus_owner() != scroll, "Tab/shoulder leaves Run guidance scroll", failures)
			tree.root.size = Vector2i(360, 240)
			for layout_frame in 8:
				await tree.process_frame
			guidance_bar = scroll.get_v_scroll_bar()
			assert_true(scroll.size.y <= tree.root.size.y * 0.45 + 1.0, "narrow guidance keeps a bounded readable viewport", failures)
			# Normal guidance now grows with measured content and uses the outer
			# page scroll. Independently create a genuinely clipped inner viewport
			# to retain the keyboard/controller routing regression for that case.
			# This is a test-only allocation fixture, not normal game geometry.
			var clipped_fixture := ScrollContainer.new()
			clipped_fixture.name = "OverflowGuidanceInputFixture"
			clipped_fixture.position = Vector2(8, 8)
			clipped_fixture.size = Vector2(200, 96)
			clipped_fixture.focus_mode = Control.FOCUS_ALL
			clipped_fixture.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			var fixture_content := Control.new()
			fixture_content.custom_minimum_size = Vector2(180, 600)
			clipped_fixture.add_child(fixture_content)
			scene.add_child(clipped_fixture)
			scene._guidance_scroll = clipped_fixture
			scroll = clipped_fixture
			await tree.process_frame
			await tree.process_frame
			guidance_bar = scroll.get_v_scroll_bar()
			assert_true(guidance_bar.max_value > guidance_bar.page, "clipped guidance fixture provides a real inner-scroll range (viewport=%s minimum=%s content=%s range=%s/%s)" % [scroll.size, scroll.custom_minimum_size, scene._overview_content.get_combined_minimum_size(), guidance_bar.max_value, guidance_bar.page], failures)
			for use_controller in [false, true]:
				for step in scene.find_children("*", "Control", true, false).size() + 1:
					if scene.get_viewport().gui_get_focus_owner() == scroll:
						break
					_push_virtual_focus(scene, 1, use_controller)
				assert_true(scene.get_viewport().gui_get_focus_owner() == scroll, "Tab/shoulder reaches narrow Run guidance scroll", failures)
				if root_scroll != null:
					root_scroll.scroll_vertical = 0
				scroll.scroll_vertical = 0
				_push_virtual_direction(scene, 1, use_controller)
				assert_true(scroll.scroll_vertical > 0, "mapped Down uses the inner guidance range when it overflows", failures)
				_push_virtual_direction(scene, -1, use_controller)
				assert_true(scroll.scroll_vertical == 0, "mapped Up returns overflowing inner guidance to its beginning", failures)
				_push_virtual_focus(scene, 1, use_controller)
				assert_true(scene.get_viewport().gui_get_focus_owner() != scroll, "Tab/shoulder leaves narrow Run guidance scroll", failures)
	else:
		assert_true(false, "scroll regression starts a Run", failures)
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
	_choose_sequence(scene, failures)
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


func _choose_sequence(scene, failures: Array[String]) -> void:
	press_action(scene, "character:base.character.sequence", RunPhase.CONTRACT_SELECT, failures)

func _choose_sequence_and_contract(scene, failures: Array[String]) -> void:
	_choose_sequence(scene, failures)
	var contract_actions: Array = scene.controller.action_descriptors().filter(func(action): return str(action.get("kind", "")) == "CONTRACT")
	assert_true(not contract_actions.is_empty(), "Sequence leaves a real Contract action for the fixture", failures)
	if contract_actions.is_empty():
		return
	press_action(scene, str(contract_actions[0].get("id", "")), RunPhase.MAP_CHOICE, failures)

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
	var descriptors_by_id: Dictionary = {}
	for action in descriptors:
		var kind := str(action.get("kind", ""))
		if kind.is_empty():
			continue
		action_kinds[kind] = true
		_observed_action_kinds[kind] = true
		var action_id := str(action.get("id", ""))
		descriptors_by_id[action_id] = action
		var button: Button = find_action_button(scene, action_id)
		if phase == "RUN_SUMMARY" and action_id == "run.summary.acknowledge":
			button = find_named_node(scene, "FinishRunButton") as Button
		var unavailable_offer := false
		if kind == "SHOP_OFFER":
			var offer_validation = scene.controller.domain.validate_buy_shop_offer(str(action.get("entry_id", "")), str(action.get("target_id", "")))
			unavailable_offer = offer_validation == null or not offer_validation.is_valid()
		var contextual_battle_action := phase == "BATTLE" and kind in BATTLE_CONTEXT_ACTION_KINDS
		if button == null and contextual_battle_action:
			continue
		var expected_disabled := unavailable_offer or not bool(action.get("enabled", true)) or bool(action.get("disabled", false))
		assert_true(button != null and button.is_visible_in_tree() and button.disabled == expected_disabled, "%s visible action %s displays the authoritative availability" % [phase, action_id], failures)
		if button != null:
			assert_true(button.focus_mode != Control.FOCUS_NONE and (not button.text.strip_edges().is_empty() or button.find_child("MapNodeLabel", true, false) is Label or (button.has_meta("tile_instance_id") and not button.accessibility_name.is_empty())), "%s action %s has keyboard/controller focus and a text label" % [phase, action_id], failures)
			if unavailable_offer:
				assert_true(not button.tooltip_text.is_empty() and button.get_parent().find_child("ShopOfferStatus", true, false) is Label, "unavailable Shop offers visibly explain their disabled state", failures)
	if phase == "BATTLE":
		for node in scene.find_children("*", "Button", true, false):
			var action_button := node as Button
			if not action_button.is_visible_in_tree() or not action_button.has_meta("run_action_id"):
				continue
			var action_id := str(action_button.get_meta("run_action_id", ""))
			var live_action: Dictionary = descriptors_by_id.get(action_id, {})
			if action_id == "battle.play_selection":
				live_action = scene.controller.hand_play_action_descriptor(scene._battle_view.selected_tile_ids())
			assert_true(not action_id.is_empty() and not live_action.is_empty(), "visible Battle action button %s projects a current authoritative descriptor" % action_id, failures)
			if live_action.is_empty():
				continue
			var projected_action_disabled := not bool(live_action.get("enabled", true)) or bool(live_action.get("disabled", false))
			assert_true(action_button.disabled == projected_action_disabled, "visible Battle action %s matches its current enabled state" % action_id, failures)
			assert_true(action_button.focus_mode != Control.FOCUS_NONE and not action_button.text.strip_edges().is_empty(), "visible Battle action %s has keyboard/controller focus and a player-facing label" % action_id, failures)
		for node in scene.find_children("*", "TileFaceButton", true, false):
			var tile_button := node as Button
			if not tile_button.is_visible_in_tree() or not tile_button.has_meta("battle_hand_tile"):
				continue
			assert_true(tile_button.focus_mode != Control.FOCUS_NONE and not tile_button.accessibility_name.strip_edges().is_empty(), "physical Battle hand tile has keyboard/controller focus and an accessible player-facing name", failures)

	var phase_label = find_named_node(scene, "RunPhaseLabel")
	assert_true(phase_label is Label and phase_label.is_visible_in_tree() and not phase_label.text.strip_edges().is_empty(), "%s has a visible textual phase label" % phase, failures)
	var visible_text_lines := _visible_text(scene)
	var visible_text := "\n".join(visible_text_lines)
	_audit_selected_action_details(scene, phase, descriptors, failures)
	if phase == "BATTLE":
		for cue_node in ["BattleEnemyHP", "BattleIntentType", "BattleResourceValues", "BattleHandHeading", "BattleZone_Reserve"]:
			var cue_control := find_named_node(scene, cue_node) as Control
			assert_true(cue_control != null and cue_control.is_visible_in_tree(), "Battle presents critical HUD/zone/receipt %s" % cue_node, failures)
		var receipt := find_named_node(scene, "BattleCriticalReceipt") as Label
		assert_true(receipt != null and (receipt.text.is_empty() or receipt.is_visible_in_tree()), "Battle displays each nonempty critical receipt", failures)
		if str(scene.controller.domain.current_battle.combat_state.current_intent.action_type) == "PRESSURE":
			var intent_detail := find_named_node(scene, "BattleIntentDetail") as Label
			assert_true(intent_detail != null and intent_detail.is_visible_in_tree() and not intent_detail.text.is_empty(), "Pressure Intent explains its amount in text", failures)
		for cue in ["Pressure", "TP", "Stability", "Intent", "Hand", "Reserve"]:
			assert_true(visible_text.contains(cue), "Battle retains critical text cue %s independent of color" % cue, failures)

	_observed_tutorial_labels["Disable tutorial" if scene.controller.tutorial_progress.enabled else "Enable tutorial"] = true
	var tutorial_toggle: Button = find_named_node(scene, "TutorialToggleButton")
	var tutorial_prompt: Label = find_named_node(scene, "TutorialPrompt")
	if tutorial_toggle != null and tutorial_toggle.is_visible_in_tree():
		_observed_tutorial_labels[tutorial_toggle.text] = true
		if tutorial_prompt != null and tutorial_prompt.visible:
			assert_true(tutorial_prompt.text.begins_with("Tutorial:"), "visible tutorial guidance includes an explicit text cue", failures)

	_audit_focus(scene, phase, failures)
	visible_text_lines = _visible_text(scene)
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
		assert_true(finish_button != null and finish_button.is_visible_in_tree() and not finish_button.disabled and finish_button.has_focus(), "Run Summary presents visible focus on Finish Run", failures)
		return
	var focus_owner := scene.get_viewport().gui_get_focus_owner() as Control
	assert_true(focus_owner != null and focus_owner.is_visible_in_tree() and focus_owner.focus_mode != Control.FOCUS_NONE, "%s has a visible keyboard/controller focus target" % phase, failures)
	if focus_owner != null and focus_owner.has_meta("run_action_id") and not str(focus_owner.get_meta("run_action_id", "")).is_empty():
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
		if control is Button and control.has_meta("run_action_id") and not control.has_meta("tile_instance_id") and _has_named_ancestor(control, "BattleViewportScroll"):
			assert_true(allocated_size.x >= 120.0, "%s Battle action retains a readable minimum width" % control.name, failures)
		if control.name == "SelectedActionDetails" and not (control as Label).text.is_empty():
			assert_true(allocated_size.x >= 140.0, "Context details retain a readable column width", failures)
		if control.name == "MapNodeLabel" and control.get_parent() is Button:
			var map_button := control.get_parent() as Button
			var node_rect: Rect2 = map_button.get_global_rect()
			assert_true(node_rect.grow(1.0).encloses(rect), "Map node name and status stay inside their choice control (locale=%s scale=%.2f node_rect=%s label_rect=%s button_size=%s label_size=%s button_min=%s label_min=%s custom_button=%s custom_label=%s text=%s)" % [str(scene._applied_preferences.get("locale", "en")), float(scene._applied_preferences.get("ui_scale", 1.0)), str(node_rect), str(rect), str(map_button.size), str(control.size), str(map_button.get_minimum_size()), str(control.get_minimum_size()), str(map_button.custom_minimum_size), str(control.custom_minimum_size), _text_snippet(control)], failures)
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
	for container_name in ["RunOverviewScroll", "RunJourneyScroll", "BattleViewportScroll", "BattleInspectionScroll"]:
		var scroll := find_named_node(scene, container_name) as ScrollContainer
		if scroll == null or not scroll.is_visible_in_tree():
			continue
		var horizontal_bar := scroll.get_h_scroll_bar()
		assert_true(horizontal_bar.max_value <= horizontal_bar.page + 1.0, "%s has no horizontal overflow that could clip action or overview text" % container_name, failures)

func _audit_selected_action_details(scene, phase: String, descriptors: Array, failures: Array[String]) -> void:
	if phase in ["RUN_SUMMARY", "RUN_COMPLETE", "CHARACTER_SELECT", "MAP_CHOICE", "EVENT"]:
		return
	var detail: Label = find_named_node(scene, "BattleInspectionValue" if phase == "BATTLE" else "SelectedActionDetails") as Label
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
	if phase == "BATTLE":
		assert_true(detail.is_visible_in_tree() and not detail.text.is_empty() and not detail.text.contains("[MISSING"), "Battle inspector provides resolved action or exact-tile details", failures)
		if focus_owner != null and focus_owner.has_meta("run_action_id"):
			assert_true(detail.text == scene._action_details_text(expected_action), "Battle action focus updates the inspector", failures)
		return
	var expected_detail: String = str(scene._action_details_text(expected_action))
	var selected_button: Button = find_action_button(scene, focused_id)
	var should_show_detail: bool = not expected_detail.is_empty() and selected_button != null
	assert_true(detail.visible == should_show_detail, "%s selected-action details appear when they add text beyond the action name" % phase, failures)
	if should_show_detail:
		assert_true(detail.is_visible_in_tree() and detail.text == expected_detail, "%s action detail text follows its keyboard/controller-focused action" % phase, failures)
	if phase == "CONTRACT_SELECT":
		var contract_details: Dictionary = expected_action.get("details", {}) if expected_action.get("details", {}) is Dictionary else {}
		var required_fields := ["risk_summary", "reward_summary", "build_bias_summary", "yaku_signal_summary"]
		var has_all_contract_fields := true
		for field in required_fields:
			has_all_contract_fields = has_all_contract_fields and contract_details.has(field) and not str(contract_details.get(field, "")).is_empty()
		assert_true(has_all_contract_fields and detail.text.split("\n", false).size() >= 5, "Contract Select visibly wraps the full Risk, Reward, Build bias, and Yaku signal details in the active locale", failures)

func _audit_presentation_modes(scene, baseline_text: Array[String], phase: String, failures: Array[String]) -> void:
	if phase == "RUN_SUMMARY":
		# Cross a displayed-second boundary so this assertion catches summaries that recompute elapsed wall time on preference rerender.
		OS.delay_msec(1100)
	var original_mode := str(scene.controller.snapshot().get("presentation_mode", PresentationState.NORMAL))
	for mode in PresentationState.MODES:
		assert_true(scene.controller.set_mode(str(mode)), "%s accepts %s presentation mode" % [phase, str(mode)], failures)
		var mode_text := _visible_text(scene)
		if mode_text != baseline_text:
			print("STAGE4_MODE_CUE_DIFF " + JSON.stringify({"phase": phase, "mode": str(mode), "removed": baseline_text.filter(func(value): return not mode_text.has(value)), "added": mode_text.filter(func(value): return not baseline_text.has(value))}))
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

func _has_named_ancestor(control: Control, ancestor_name: String) -> bool:
	var parent := control.get_parent()
	while parent != null:
		if parent.name == ancestor_name:
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
