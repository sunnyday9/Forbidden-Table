class_name Rc3LossSummaryRegressionTest
extends RefCounted

const RunScene = preload("res://scenes/run/run_scene.tscn")
const MetaProgressCoordinator = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStore = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const Localization = preload("res://src/presentation/localization/localization.gd")
const ForbiddenTheme = preload("res://src/presentation/ui/forbidden_theme.gd")

const VIEWPORT_CASES := [
	{"name": "fullscreen", "size": Vector2i(2520, 1434)},
	{"name": "desktop", "size": Vector2i(1280, 720)},
	{"name": "compact", "size": Vector2i(960, 540)},
	{"name": "portrait", "size": Vector2i(720, 1280)},
	{"name": "tiny", "size": Vector2i(360, 240)},
]
const LOCALES := ["en", "zh_CN"]
const SCALES := [1.0, 1.25, 1.5]


func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		failures.append("ASSERTION FAILED: loss summary fixture requires the SceneTree main loop")
		return failures
	var original_size := tree.root.size
	await _check_terminal_layout("DEFEAT", "BATTLE_DEFEAT", failures)
	await _check_terminal_layout("VICTORY", "BOSS_DEFEATED", failures, [
		{"name": "fullscreen", "size": Vector2i(2520, 1434)},
		{"name": "portrait", "size": Vector2i(720, 1280)},
		{"name": "tiny", "size": Vector2i(360, 240)},
	])
	await _check_terminal_layout("DEFEAT", "BATTLE_DEFEAT", failures, VIEWPORT_CASES, {"defeat_context": {"pressure": 30, "pressure_limit": 30, "enemy_hp": 24}})
	tree.root.size = original_size
	TranslationServer.set_locale("en")
	await tree.process_frame
	return failures


func _check_terminal_layout(outcome: String, reason: String, failures: Array[String], viewport_cases: Array = VIEWPORT_CASES, summary_details: Dictionary = {}) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var suffix := "%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	var suspend_path := "user://rc3_loss_summary_%s_suspend.json" % suffix
	var profile_path := "user://rc3_loss_summary_%s_profile.json" % suffix
	var scene = RunScene.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinator.new(MetaProgressStore.new(profile_path))
	tree.root.add_child(scene)
	await _settle(tree, 5)
	if scene.controller == null:
		_assert_true(false, "%s fixture starts through the real RunScene controller" % outcome, failures)
		await _dispose_scene(scene, tree, suspend_path, profile_path)
		return
	var domain = scene.controller.domain
	var character_action := _first_action(scene.controller.action_descriptors(), "CHARACTER")
	var character_result = scene._on_action_pressed(str(character_action.get("id", "")))
	_assert_true(character_result != null and character_result.accepted, "%s fixture commits a real Character choice" % outcome, failures)
	var contract_action := _first_action(scene.controller.action_descriptors(), "CONTRACT")
	var contract_result = scene._on_action_pressed(str(contract_action.get("id", "")))
	_assert_true(contract_result != null and contract_result.accepted, "%s fixture commits a real Contract choice" % outcome, failures)
	domain.enter_run_summary(outcome, reason, summary_details)
	scene._render()
	await _settle(tree, 5)
	_assert_true(str(domain.state.phase) == RunPhase.RUN_SUMMARY, "%s fixture reaches the actual terminal summary phase" % outcome, failures)

	var summary_view: Control = scene.find_child("RunSummaryView", true, false) as Control
	var layout_scroll := scene.find_child("RunSummaryLayoutScroll", true, false) as ScrollContainer
	var columns := scene.find_child("RunSummaryColumns", true, false) as GridContainer
	var chronicle_panel := scene.find_child("BuildChroniclePanel", true, false) as Control
	var summary_scroll := scene.find_child("RunSummaryScroll", true, false) as ScrollContainer
	var result_panel := scene.find_child("RunOutcomePanel", true, false) as Control
	var result_scroll := scene.find_child("RunOutcomeScroll", true, false) as ScrollContainer
	var outcome_label := scene.find_child("RunOutcomeValue", true, false) as Label
	var reason_label := scene.find_child("RunReasonValue", true, false) as Label
	var chronicle_text := scene.find_child("RunSummaryText", true, false) as Label
	var section_heading := (summary_view.get("_result_heading") as Label) if summary_view != null else null
	var commit_button := scene.find_child("FinishRunButton", true, false) as Button

	for viewport_case in viewport_cases:
		for locale in LOCALES:
			for scale in SCALES:
				tree.root.size = viewport_case.size
				scene._apply_presentation_preferences({
					"locale": locale,
					"ui_scale": scale,
					"presentation_mode": "INSTANT",
					"reduced_motion": true,
					"ambient_glow": false,
				}, true)
				await _settle(tree, 4)
				var case_name := "%s/%s/%s%%" % [viewport_case.name, locale, roundi(scale * 100.0)]
				_assert_true(summary_view != null and summary_view.is_visible_in_tree(), "%s keeps the terminal summary visible" % case_name, failures)
				_assert_true(summary_view != null and columns != null and columns.columns == (1 if summary_view.size.x < 720.0 * scale else 2), "%s reflows summary columns at the available-width responsive breakpoint" % case_name, failures)
				_assert_true(layout_scroll != null and layout_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "%s preserves natural vertical scrolling when the measured summary exceeds its stage" % case_name, failures)
				_assert_true(outcome_label != null and outcome_label.text == Localization.word_text(outcome) and outcome_label.is_visible_in_tree(), "%s retains the correct localized terminal outcome in the real view" % case_name, failures)
				_assert_true(section_heading != null and section_heading.text == Localization.text("UI_RUN_JOURNEY_0026") and section_heading.is_visible_in_tree(), "%s retains the journey summary heading" % case_name, failures)
				_assert_true(reason_label != null and not reason_label.text.is_empty() and reason_label.is_visible_in_tree(), "%s retains the localized terminal cause in the real terminal view" % case_name, failures)
				if result_scroll != null:
					var outcome_bar := result_scroll.get_v_scroll_bar()
					_assert_true(outcome_bar.max_value <= outcome_bar.page + 1.0, "%s does not hide outcome or cause behind an inner scroll (range %.1f)" % [case_name, outcome_bar.max_value - outcome_bar.page], failures)
					_assert_true(_contains_rect(result_scroll.get_global_rect(), section_heading.get_global_rect()), "%s fully contains the section heading in its result panel" % case_name, failures)
					_assert_true(_contains_rect(result_scroll.get_global_rect(), outcome_label.get_global_rect()), "%s fully contains the outcome label in its result panel" % case_name, failures)
					_assert_true(_contains_rect(result_scroll.get_global_rect(), reason_label.get_global_rect()), "%s fully contains the cause label in its result panel" % case_name, failures)
				_assert_true(outcome_label != null and is_equal_approx(outcome_label.get_theme_font_size("font_size"), ForbiddenTheme.font_size_for("title", scale)), "%s scales the outcome font with the applied preference" % case_name, failures)
				_assert_true(section_heading != null and is_equal_approx(section_heading.get_theme_font_size("font_size"), ForbiddenTheme.font_size_for("heading", scale)), "%s scales the result heading with the applied preference" % case_name, failures)
				if viewport_case.name == "fullscreen":
					_assert_true(chronicle_panel != null and chronicle_panel.size.y >= summary_view.size.y * 0.6, "%s uses the available fullscreen body height instead of centering a collapsed strip (%.0f / %.0f)" % [case_name, chronicle_panel.size.y if chronicle_panel != null else -1.0, summary_view.size.y if summary_view != null else -1.0], failures)
					if summary_scroll != null:
						var chronicle_bar := summary_scroll.get_v_scroll_bar()
						_assert_true(chronicle_bar.max_value <= chronicle_bar.page + 1.0, "%s shows the representative build chronicle without an inner scroll when it fits" % case_name, failures)
					var viewport_rect := Rect2(Vector2.ZERO, tree.root.get_visible_rect().size)
					_assert_true(_contains_rect(viewport_rect, section_heading.get_global_rect()) and _contains_rect(viewport_rect, outcome_label.get_global_rect()) and _contains_rect(viewport_rect, reason_label.get_global_rect()), "%s keeps the summary heading, outcome, and cause fully on-screen at the reported fullscreen size" % case_name, failures)
				if viewport_case.name in ["compact", "portrait", "tiny"]:
					_assert_true(layout_scroll != null, "%s retains an outer page scroll for compact layouts" % case_name, failures)
					_assert_true(chronicle_panel != null and result_panel != null and chronicle_panel.size.y >= 200.0 * scale and result_panel.size.y >= 180.0 * scale, "%s gives both stacked summary sections useful height rather than a collapsed strip" % case_name, failures)
					if viewport_case.name == "tiny" and layout_scroll != null:
						layout_scroll.scroll_vertical = layout_scroll.get_v_scroll_bar().max_value
						await _settle(tree, 2)
						var body_rect: Rect2 = scene._run_root_scroll.get_global_rect()
						var cause_rect: Rect2 = reason_label.get_global_rect()
						var outer_bar: VScrollBar = scene._run_root_scroll.get_v_scroll_bar()
						var outer_range := maxf(0.0, outer_bar.max_value - outer_bar.page)
						var target_scroll: float = scene._run_root_scroll.scroll_vertical
						if cause_rect.position.y < body_rect.position.y:
							target_scroll -= body_rect.position.y - cause_rect.position.y + 1.0
						elif cause_rect.end.y > body_rect.end.y:
							target_scroll += cause_rect.end.y - body_rect.end.y + 1.0
						scene._run_root_scroll.scroll_vertical = clampf(target_scroll, 0.0, outer_range)
						await _settle(tree, 2)
						_assert_true(_contains_rect(scene._run_root_scroll.get_global_rect(), reason_label.get_global_rect()), "%s outer scrolling can bring the terminal cause fully into the body viewport" % case_name, failures)
				if commit_button != null:
					_assert_true(commit_button.is_visible_in_tree() and not commit_button.disabled and commit_button.focus_mode != Control.FOCUS_NONE, "%s keeps the terminal action keyboard/controller reachable" % case_name, failures)
					_assert_true(commit_button.get_theme_font_size("font_size") == ForbiddenTheme.font_size_for("button", scale), "%s uses the scaled button typography role on Finish Run" % case_name, failures)
					_assert_true(commit_button.custom_minimum_size.y >= 44.0 * scale - 1.0 and commit_button.size.y >= 44.0 * scale - 1.0, "%s keeps the scaled 44px Finish Run target readable at this scale (%.1f / %.1f)" % [case_name, commit_button.size.y, 44.0 * scale], failures)
					_assert_true(_contains_rect(Rect2(Vector2.ZERO, tree.root.get_visible_rect().size), commit_button.get_global_rect()), "%s keeps the Finish Run action fully on-screen after resize" % case_name, failures)
					commit_button.grab_focus()
					_assert_true(tree.root.gui_get_focus_owner() == commit_button, "%s can focus the terminal action after resize" % case_name, failures)

			_assert_true(chronicle_text != null and chronicle_text.text.contains(Localization.word_text(reason)), "%s retains the localized terminal cause in the build chronicle text" % outcome, failures)
	await _dispose_scene(scene, tree, suspend_path, profile_path)


func _first_action(actions: Array, kind: String) -> Dictionary:
	if kind == "CHARACTER":
		for action in actions:
			if str(action.get("target_id", "")) == "base.character.sequence":
				return action
	for action in actions:
		if str(action.get("kind", "")) == kind:
			return action
	return {}


func _contains_rect(container: Rect2, content: Rect2) -> bool:
	return container.grow(1.0).encloses(content)


func _settle(tree: SceneTree, frames: int) -> void:
	for _frame in range(frames):
		await tree.process_frame


func _dispose_scene(scene, tree: SceneTree, suspend_path: String, profile_path: String) -> void:
	tree.root.remove_child(scene)
	scene.free()
	for path in [suspend_path, suspend_path + ".tmp", suspend_path + ".bak", profile_path]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	await tree.process_frame


func _assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
