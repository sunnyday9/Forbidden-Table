extends RefCounted

const ForbiddenTheme = preload("res://src/presentation/ui/forbidden_theme.gd")
const PreferencesOverlay = preload("res://src/presentation/ui/preferences_overlay.gd")
const RunSummaryView = preload("res://src/presentation/ui/run_summary_view.gd")
const BattleFeedbackLayer = preload("res://src/presentation/ui/battle_feedback_layer.gd")
const TileFaceButton = preload("res://src/presentation/ui/tile_face_button.gd")
const RunMapView = preload("res://src/presentation/ui/run_map_view.gd")
const MiniActMapCatalog = preload("res://src/content/catalogs/mini_act_map_catalog.gd")
const RunMapState = preload("res://src/domain/run/run_map_state.gd")
const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const Localization = preload("res://src/presentation/localization/localization.gd")
const RunScenePacked = preload("res://scenes/run/run_scene.tscn")
const MetaProgressCoordinator = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStore = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")

const LOCALES := ["en", "zh_CN"]
const UI_SCALES := [1.0, 1.25, 1.5]
const VIEWPORTS := [Vector2i(960, 540), Vector2i(2560, 1440), Vector2i(390, 844)]

class MemoryPreferences:
	extends RefCounted
	var values := {
		"locale": "en",
		"ui_scale": 1.0,
		"presentation_mode": "NORMAL",
		"reduced_motion": false,
		"ambient_glow": true,
	}

	var locale: String:
		get:
			return str(values.get("locale", "en"))
	var ui_scale: float:
		get:
			return float(values.get("ui_scale", 1.0))

	func snapshot() -> Dictionary:
		return values.duplicate(true)

	func apply_preferences(next_values: Dictionary) -> Dictionary:
		values = next_values.duplicate(true)
		return snapshot()


class MemoryTutorialProgress:
	extends RefCounted
	var enabled := true

	func reset() -> void:
		enabled = true

	func enable() -> void:
		enabled = true

	func disable() -> void:
		enabled = false


var _tree: SceneTree
var _failures: Array[String] = []


func _settle(frame_count: int = 4) -> void:
	for _index in range(frame_count):
		await _tree.process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL " + message)
		_failures.append(message)


func run() -> Array[String]:
	_failures.clear()
	_tree = Engine.get_main_loop() as SceneTree
	if _tree == null:
		return ["RC5 typography regression requires an active SceneTree"]
	var original_locale := TranslationServer.get_locale()
	var original_size: Vector2i = _tree.root.size
	var original_scale_mode: int = _tree.root.content_scale_mode
	_tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_check_font_role_theme()
	await _check_preferences_layout()
	await _check_run_scene_button_roles()
	await _check_summary_layout()
	await _check_map_labels()
	await _check_feedback_and_tile_roles()
	TranslationServer.set_locale(original_locale)
	_tree.root.size = original_size
	_tree.root.content_scale_mode = original_scale_mode
	return _failures.duplicate()


func _check_font_role_theme() -> void:
	for locale_id in LOCALES:
		for ui_scale in UI_SCALES:
			var scale := float(ui_scale)
			var theme: Theme = ForbiddenTheme.create_theme(str(locale_id), scale)
			var context := "%s at %d%%" % [locale_id, roundi(scale * 100.0)]
			_check(theme.default_font_size == ForbiddenTheme.font_size_for("body", scale), "%s uses the body role as its default font size" % context)
			_check(theme.get_font_size("font_size", "Label") == roundi(20.0 * scale), "%s renders default labels at the enlarged 20px body size" % context)
			_check(theme.get_font_size("font_size", "Button") == roundi(20.0 * scale), "%s renders buttons at the enlarged 20px size" % context)
			_check(theme.get_font_size("normal_font_size", "RichTextLabel") == roundi(20.0 * scale), "%s renders rich text at the enlarged body size" % context)
			_check(ForbiddenTheme.font_size_for("secondary", scale) == roundi(18.0 * scale), "%s scales secondary copy from 18px" % context)
			_check(ForbiddenTheme.font_size_for("caption", scale) == roundi(16.0 * scale), "%s scales captions from the 16px readability floor" % context)
			_check(ForbiddenTheme.font_size_for("heading", scale) == roundi(26.0 * scale), "%s preserves the intermediate heading role" % context)
			_check(ForbiddenTheme.font_size_for("title", scale) == roundi(36.0 * scale), "%s scales titles from 36px" % context)
			_check(ForbiddenTheme.font_size_for("unmapped-role", scale) == roundi(20.0 * scale), "%s falls back to a readable body size" % context)


func _check_preferences_layout() -> void:
	var preferences := MemoryPreferences.new()
	var overlay := PreferencesOverlay.new()
	_tree.root.add_child(overlay)
	await _settle(4)
	overlay._prefs = preferences
	var tutorial := MemoryTutorialProgress.new()
	for locale_id in LOCALES:
		TranslationServer.set_locale(str(locale_id))
		for ui_scale in UI_SCALES:
			for viewport_size in VIEWPORTS:
				_tree.root.size = viewport_size
				preferences.values = {
					"locale": str(locale_id),
					"ui_scale": float(ui_scale),
					"presentation_mode": "NORMAL",
					"reduced_motion": false,
					"ambient_glow": true,
				}
				var original_preferences := preferences.snapshot()
				overlay.open(original_preferences, null, tutorial)
				await _settle(5)
				var context := "Settings %s %d%% at %s" % [locale_id, roundi(float(ui_scale) * 100.0), viewport_size]
				var scale := float(ui_scale)
				_check(overlay._title.get_theme_font_size("font_size") == roundi(36.0 * scale), "%s uses the title role" % context)
				_check(overlay._brand.get_theme_font_size("font_size") == roundi(18.0 * scale), "%s uses secondary-sized brand copy" % context)
				_check(overlay._apply_button.get_theme_font_size("font_size") == roundi(20.0 * scale), "%s keeps Apply text at body size" % context)
				_check(overlay._apply_button.size.y >= overlay._apply_button.get_theme_font_size("font_size") + 4.0, "%s gives Apply enough height for its rendered text" % context)
				var card_rect := overlay._card.get_global_rect()
				_check(card_rect.encloses(overlay._apply_button.get_global_rect()), "%s keeps Apply inside the settings card" % context)
				_check(card_rect.encloses(overlay._cancel_button.get_global_rect()), "%s keeps Cancel inside the settings card" % context)
				_check(preferences.snapshot() == original_preferences, "%s leaves persisted preferences unchanged while previewing typography" % context)
				overlay._on_help_tab_pressed()
				await _settle(3)
				var reset_button := overlay.find_child("TutorialResetButton", true, false) as Button
				_check(reset_button != null and overlay._page_scroll_containing(reset_button) == overlay._help_scroll, "%s keeps the Help action in its scrollable page" % context)
				if reset_button != null:
					_check(reset_button.get_theme_font_size("font_size") == roundi(20.0 * scale), "%s renders Help actions at body size" % context)
					reset_button.grab_focus()
					overlay._reveal_focused_control_after_layout_after_frame()
					await _settle(2)
					_check(overlay._viewport_scroll.get_global_rect().encloses(reset_button.get_global_rect()), "%s scrolls the final Help action into view" % context)
				overlay._on_settings_tab_pressed()
				await _settle(2)
				overlay.close()
	await _settle(2)
	overlay.queue_free()
	await _settle(2)


func _check_run_scene_button_roles() -> void:
	var previous_size: Vector2i = _tree.root.size
	_tree.root.size = Vector2i(960, 540)
	var continue_fixture := await _create_run_scene_fixture("continue")
	var continue_scene = continue_fixture.get("scene")
	if continue_scene == null or continue_scene.controller == null:
		_check(false, "the real RunScene provides a controller for static button typography")
		await _dispose_run_scene_fixture(continue_fixture)
		_tree.root.size = previous_size
		return
	var settings_button := continue_scene.find_child("SettingsButton", true, false) as Button
	var guided_button := continue_scene.find_child("GuidedSampleButton", true, false) as Button
	var resume_button := continue_scene.find_child("ResumeRunButton", true, false) as Button
	continue_scene._pending_resume_domain = continue_scene.controller.domain
	for locale_id in LOCALES:
		for ui_scale in UI_SCALES:
			var scale := float(ui_scale)
			var context := "RunScene buttons %s %d%% at 960x540" % [locale_id, roundi(scale * 100.0)]
			continue_scene._apply_presentation_preferences({
				"locale": str(locale_id),
				"ui_scale": scale,
				"presentation_mode": "NORMAL",
				"reduced_motion": false,
				"ambient_glow": true,
			}, true)
			await _settle(4)
			await _check_scene_button(continue_scene, settings_button, context + " Settings", scale)
			await _check_scene_button(continue_scene, guided_button, context + " Guided", scale)
			var no_messages: Array[Dictionary] = []
			continue_scene._show_suspend_choice_parts(no_messages, true, "UI_RUN_SCENE_0044", true)
			await _settle(4)
			await _check_scene_button(continue_scene, resume_button, context + " Continue", scale)
	await _dispose_run_scene_fixture(continue_fixture)

	var finish_fixture := await _create_run_scene_fixture("finish")
	var finish_scene = finish_fixture.get("scene")
	if finish_scene == null or finish_scene.controller == null:
		_check(false, "the real RunScene provides a controller for the Finish button typography")
		await _dispose_run_scene_fixture(finish_fixture)
		_tree.root.size = previous_size
		return
	var character_action := _first_run_action(finish_scene.controller.action_descriptors(), "CHARACTER")
	var character_result = finish_scene._on_action_pressed(str(character_action.get("id", ""))) if not character_action.is_empty() else null
	var contract_action := _first_run_action(finish_scene.controller.action_descriptors(), "CONTRACT")
	var contract_result = finish_scene._on_action_pressed(str(contract_action.get("id", ""))) if not contract_action.is_empty() else null
	_check(character_result != null and character_result.accepted, "the Finish fixture selects a real Character through RunScene")
	_check(contract_result != null and contract_result.accepted, "the Finish fixture selects a real Contract through RunScene")
	finish_scene.controller.domain.enter_run_summary("DEFEAT", "BATTLE_DEFEAT")
	finish_scene._render()
	await _settle(5)
	var finish_settings := finish_scene.find_child("SettingsButton", true, false) as Button
	var finish_guided := finish_scene.find_child("GuidedSampleButton", true, false) as Button
	var finish_button := finish_scene.find_child("FinishRunButton", true, false) as Button
	for locale_id in LOCALES:
		for ui_scale in UI_SCALES:
			var scale := float(ui_scale)
			var context := "RunScene summary buttons %s %d%% at 960x540" % [locale_id, roundi(scale * 100.0)]
			finish_scene._apply_presentation_preferences({
				"locale": str(locale_id),
				"ui_scale": scale,
				"presentation_mode": "NORMAL",
				"reduced_motion": false,
				"ambient_glow": true,
			}, true)
			await _settle(4)
			await _check_scene_button(finish_scene, finish_settings, context + " Settings", scale)
			await _check_scene_button(finish_scene, finish_guided, context + " Guided", scale)
			await _check_scene_button(finish_scene, finish_button, context + " Finish", scale)
			_check(not finish_button.disabled, "%s keeps Finish enabled for the actual loss summary action" % context)
	await _dispose_run_scene_fixture(finish_fixture)
	_tree.root.size = previous_size


func _create_run_scene_fixture(label: String) -> Dictionary:
	var suffix := "%s_%s_%s" % [label, OS.get_process_id(), Time.get_ticks_usec()]
	var suspend_path := "user://rc5_run_scene_typography_%s_suspend.json" % suffix
	var profile_path := "user://rc5_run_scene_typography_%s_profile.json" % suffix
	var scene = RunScenePacked.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinator.new(MetaProgressStore.new(profile_path))
	_tree.root.add_child(scene)
	await _settle(5)
	return {"scene": scene, "suspend_path": suspend_path, "profile_path": profile_path}


func _dispose_run_scene_fixture(fixture: Dictionary) -> void:
	var scene = fixture.get("scene")
	if scene != null and is_instance_valid(scene):
		if scene.get_parent() != null:
			scene.get_parent().remove_child(scene)
		scene.free()
	for path in [
		str(fixture.get("suspend_path", "")),
		str(fixture.get("suspend_path", "")) + ".tmp",
		str(fixture.get("suspend_path", "")) + ".bak",
		str(fixture.get("profile_path", "")),
	]:
		if path.is_empty():
			continue
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	await _settle(2)


func _first_run_action(actions: Array, kind: String) -> Dictionary:
	if kind == "CHARACTER":
		for action in actions:
			if str(action.get("target_id", "")) == "base.character.sequence":
				return action
	for action in actions:
		if str(action.get("kind", "")) == kind:
			return action
	return {}


func _check_scene_button(scene, button: Button, context: String, scale: float) -> void:
	_check(button != null, "%s exists in the real RunScene" % context)
	if button == null:
		return
	_check(button.is_visible_in_tree() and not button.disabled, "%s is visible and enabled" % context)
	_check(button.get_theme_font_size("font_size") == ForbiddenTheme.font_size_for("button", scale), "%s uses the scaled 20px button role" % context)
	_check(button.custom_minimum_size.y >= 44.0 * scale - 1.0 and button.size.y >= 44.0 * scale - 1.0, "%s has the scaled full-size button target" % context)
	_check(button.focus_mode != Control.FOCUS_NONE, "%s remains keyboard/controller reachable" % context)
	button.grab_focus()
	scene._schedule_focused_control_reveal()
	await _settle(4)
	var viewport_rect := Rect2(Vector2.ZERO, _tree.root.get_visible_rect().size)
	_check(viewport_rect.encloses(button.get_global_rect()), "%s stays fully inside the viewport (button %s, viewport %s)" % [context, button.get_global_rect(), viewport_rect])


func _check_summary_layout() -> void:
	var summary := RunSummaryView.new()
	_tree.root.add_child(summary)
	await _settle(2)
	var english_lines: Array[String] = []
	var chinese_lines: Array[String] = []
	for line_index in range(48):
		english_lines.append("Run chronicle entry %02d records the player's choice, resource change, and encounter outcome." % line_index)
		chinese_lines.append("第%02d回合记录了玩家选择、资源变化和遭遇结果。" % line_index)
	for locale_id in LOCALES:
		TranslationServer.set_locale(str(locale_id))
		for ui_scale in UI_SCALES:
			for viewport_size in VIEWPORTS:
				_tree.root.size = viewport_size
				summary.render(null, "\n".join(chinese_lines if str(locale_id) == "zh_CN" else english_lines), str(locale_id), float(ui_scale))
				await _settle(5)
				var context := "Summary %s %d%% at %s" % [locale_id, roundi(float(ui_scale) * 100.0), viewport_size]
				var scale := float(ui_scale)
				_check(summary._chronicle_heading.get_theme_font_size("font_size") == roundi(26.0 * scale), "%s renders the chronicle heading at the heading role" % context)
				_check(summary._result_heading.get_theme_font_size("font_size") == roundi(26.0 * scale), "%s renders the outcome heading at the heading role" % context)
				_check(summary._outcome_value.get_theme_font_size("font_size") == roundi(36.0 * scale), "%s renders the result at the title role" % context)
				_check(summary.summary_label().get_theme_font_size("font_size") == roundi(20.0 * scale), "%s uses body-sized chronicle copy" % context)
				var viewport_rect := summary._layout_scroll.get_global_rect()
				_check(viewport_rect.position.x <= summary._chronicle_panel.get_global_rect().position.x + 1.0 and viewport_rect.end.x + 1.0 >= summary._chronicle_panel.get_global_rect().end.x, "%s keeps the chronicle panel within the available width" % context)
				_check(viewport_rect.position.x <= summary._result_panel.get_global_rect().position.x + 1.0 and viewport_rect.end.x + 1.0 >= summary._result_panel.get_global_rect().end.x, "%s keeps the outcome panel within the available width" % context)
				_check(summary._layout_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s avoids a clipped horizontal summary surface" % context)
				if viewport_size.x < 720.0 * scale:
					_check(summary._columns.columns == 1, "%s stacks summary panels in a narrow viewport" % context)
				if viewport_size.y <= 844:
					var summary_scrollbar := summary._summary_scroll.get_v_scroll_bar()
					_check(summary_scrollbar.max_value > summary_scrollbar.page, "%s keeps the long chronicle readable through vertical scrolling" % context)
	await _settle(2)
	summary.queue_free()
	await _settle(2)


func _check_feedback_and_tile_roles() -> void:
	for locale_id in LOCALES:
		TranslationServer.set_locale(str(locale_id))
		for ui_scale in UI_SCALES:
			for viewport_size in [Vector2i(960, 540), Vector2i(390, 844)]:
				_tree.root.size = viewport_size
				var feedback := BattleFeedbackLayer.new()
				feedback.size = Vector2(viewport_size)
				feedback.theme = ForbiddenTheme.create_theme(str(locale_id), float(ui_scale))
				_tree.root.add_child(feedback)
				await _settle(2)
				var tween := feedback.create_tween()
				feedback._add_caption_track(tween, "VICTORY", Vector2.ZERO, ForbiddenTheme.color("brass"), "title", Vector2(-80.0, -80.0))
				await _settle(1)
				var caption := feedback.get_child(feedback.get_child_count() - 1) as Label
				var expected_title_size := ForbiddenTheme.font_size_for("title", float(ui_scale))
				var context := "Battle cue %s %d%% at %s" % [locale_id, roundi(float(ui_scale) * 100.0), viewport_size]
				_check(caption != null and caption.get_theme_font_size("font_size") == expected_title_size, "%s applies the scaled title role to a temporary cue" % context)
				if caption != null:
					_check(feedback.get_global_rect().encloses(caption.get_global_rect()), "%s keeps the enlarged cue inside the battle viewport" % context)
				tween.kill()
				feedback.queue_free()
				await _settle(1)

				var host := Control.new()
				host.size = Vector2(viewport_size)
				host.theme = ForbiddenTheme.create_theme(str(locale_id), float(ui_scale))
				_tree.root.add_child(host)
				var tile := TileFaceButton.new()
				host.add_child(tile)
				tile.configure({"definition_id": "", "instance_id": "typography", "status_marker": "!"})
				await _settle(2)
				var expected_caption_size := ForbiddenTheme.font_size_for("caption", float(ui_scale))
				var tile_context := "Tile mark %s %d%% at %s" % [locale_id, roundi(float(ui_scale) * 100.0), viewport_size]
				_check(tile.status_badge.get_theme_font_size("font_size") == expected_caption_size, "%s applies the scaled caption role" % tile_context)
				var expected_badge_height := float(expected_caption_size) + 6.0 * float(ui_scale)
				_check(is_equal_approx(tile.custom_minimum_size.y, 64.0 + expected_badge_height), "%s reserves enough tile height for the larger mark" % tile_context)
				_check(tile.face_rect.offset_bottom <= -expected_badge_height, "%s preserves an unobstructed tile face under the status strip" % tile_context)
				host.queue_free()
				await _settle(1)


func _check_map_labels() -> void:
	var definition = MiniActMapCatalog.definition()
	var map_state = RunMapState.new()
	map_state.initialize(definition, DomainRngStreams.new(1462017).map)
	var actions: Array[Dictionary] = []
	for node_id in definition.node_ids:
		actions.append({"kind": "MAP_NODE", "id": "map:%s" % node_id, "target_id": node_id})
	for locale_id in LOCALES:
		TranslationServer.set_locale(str(locale_id))
		for ui_scale in UI_SCALES:
			for viewport_size in VIEWPORTS:
				_tree.root.size = viewport_size
				var map_width := minf(980.0, maxf(358.0, float(viewport_size.x) * 0.55))
				var map_view := RunMapView.new()
				map_view.name = "TypographyRunMap"
				map_view.position = Vector2((float(viewport_size.x) - map_width) * 0.5, 24.0)
				map_view.size = Vector2(map_width, maxf(1400.0, float(viewport_size.y)))
				map_view.configure(Callable(self, "_map_action_label"), Callable(self, "_map_pretty_id"), Callable(self, "_map_pretty_words"))
				map_view.set_presentation_preferences(str(locale_id), float(ui_scale))
				map_view.render(definition, map_state, actions)
				_tree.root.add_child(map_view)
				await _settle(5)
				var context := "Map %s %d%% at %s" % [locale_id, roundi(float(ui_scale) * 100.0), viewport_size]
				var expected_body_size := ForbiddenTheme.font_size_for("body", float(ui_scale))
				var checked := 0
				for node_id in definition.node_ids:
					var button := map_view._node_controls.get(str(node_id)) as Button
					var label := button.find_child("MapNodeLabel", true, false) as Label if button != null else null
					_check(button != null and label != null, "%s creates a labeled control for map node %s" % [context, node_id])
					if button == null or label == null:
						continue
					checked += 1
					_check(label.get_theme_font_size("font_size") == expected_body_size, "%s enlarges map node text to the body role" % context)
					_check(button.get_global_rect().grow(1.0).encloses(label.get_global_rect()), "%s contains the text inside map node %s" % [context, node_id])
					var rendered_height := float(label.get_line_count()) * float(label.get_line_height())
					_check(rendered_height <= label.size.y + 2.0, "%s allocates enough height for map node %s text" % [context, node_id])
				_check(checked == definition.node_ids.size(), "%s verifies every authored map node" % context)
				map_view.queue_free()
				await _settle(2)


func _map_action_label(action: Dictionary) -> String:
	return "Travel to %s" % str(action.get("target_id", ""))


func _map_pretty_id(identifier: String) -> String:
	var parts := identifier.split(".")
	return str(parts[parts.size() - 1]).replace("_", " ").capitalize()


func _map_pretty_words(value: String) -> String:
	return Localization.word_text(value)
