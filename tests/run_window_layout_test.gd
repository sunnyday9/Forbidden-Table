extends RefCounted

const RunSceneScript = preload("res://scenes/run/run_scene.tscn")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")

var _failures: Array[String] = []
var _run_scene
var _suspend_path := ""
var _profile_path := ""


func run() -> Array[String]:
	_failures.clear()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["RunScene responsive window layout requires an active SceneTree"]
	var original_window_size: Vector2i = tree.root.size
	var suffix := str(Time.get_ticks_usec())
	_suspend_path = "user://run_window_layout_%s_suspend.json" % suffix
	_profile_path = "user://run_window_layout_%s_profile.json" % suffix

	tree.root.size = Vector2i(960, 900)
	_run_scene = RunSceneScript.instantiate()
	_run_scene.suspend_file_path = _suspend_path
	_run_scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new(_profile_path)
	)
	tree.root.add_child(_run_scene)
	await tree.process_frame
	await tree.process_frame

	var sizes: Array[Dictionary] = [
		{"name": "360x900", "size": Vector2i(360, 900), "wide": false, "short": false},
		{"name": "600x900", "size": Vector2i(600, 900), "wide": false, "short": false},
		{"name": "960x540", "size": Vector2i(960, 540), "wide": true, "short": false},
		{"name": "960x900", "size": Vector2i(960, 900), "wide": true, "short": false},
		{"name": "1440x960", "size": Vector2i(1440, 960), "wide": true, "short": false},
		{"name": "1920x1080", "size": Vector2i(1920, 1080), "wide": true, "short": false},
		{"name": "2560x1440", "size": Vector2i(2560, 1440), "wide": true, "short": false},
		{"name": "360x240", "size": Vector2i(360, 240), "wide": false, "short": true},
	]
	for size_case in sizes:
		var viewport_size: Vector2i = size_case["size"]
		tree.root.size = viewport_size
		await tree.process_frame
		await tree.process_frame
		_assert_layout_case(
			str(size_case["name"]),
			viewport_size,
			bool(size_case["wide"]),
			bool(size_case["short"])
		)

	if is_instance_valid(_run_scene):
		await _assert_non_character_wide_layout(tree)
		_run_scene.queue_free()
		await tree.process_frame
	tree.root.size = original_window_size
	_remove_user_file(_suspend_path)
	_remove_user_file(_profile_path)
	return _failures


func _assert_non_character_wide_layout(tree: SceneTree) -> void:
	if _run_scene == null or _run_scene.controller == null:
		_failures.append("non-Character wide layout fixture has an active Run controller")
		return
	var character_action_id := ""
	for action in _run_scene.controller.action_descriptors():
		var action_id := str(action.get("id", ""))
		if action_id == "character:base.character.sequence":
			character_action_id = action_id
			break
	_assert(not character_action_id.is_empty(), "non-Character wide layout fixture starts with a real Character action")
	if character_action_id.is_empty():
		return
	_run_scene._on_action_pressed(character_action_id)
	for _frame in 4:
		await tree.process_frame
	var phase := str(_run_scene.controller.domain.state.phase)
	_assert(phase == RunPhaseScript.CONTRACT_SELECT, "wide layout fixture transitions through Character into Contract")
	if phase != RunPhaseScript.CONTRACT_SELECT:
		return
	tree.root.size = Vector2i(1920, 1080)
	for _frame in 4:
		await tree.process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var stage: Control = _run_scene.find_child("RunJourneyStage", true, false) as Control
	var root_scroll: ScrollContainer = _run_scene.find_child("RunRootScroll", true, false) as ScrollContainer
	_assert(stage != null and root_scroll != null, "Contract wide layout retains the Run stage and page scroll")
	if stage == null or root_scroll == null:
		return
	var stage_rect := stage.get_global_rect()
	var root_scroll_rect := root_scroll.get_global_rect()
	_assert(
		stage_rect.size.x >= viewport_rect.size.x - 80.0,
		"Contract phase returns to full-width stage layout (stage=%s, viewport=%s)" % [str(stage_rect), str(viewport_rect)]
	)
	_assert(
		stage_rect.end.y >= root_scroll_rect.end.y - 20.0,
		"Contract phase stage fills the wide page to its bottom inset (stage=%s, scroll=%s)" % [str(stage_rect), str(root_scroll_rect)]
	)


func _assert_layout_case(case_name: String, viewport_size: Vector2i, expect_wide_fill: bool, expect_vertical_scroll: bool) -> void:
	var viewport_rect: Rect2 = _run_scene.get_global_rect()
	_assert(
		absf(viewport_rect.size.x - float(viewport_size.x)) <= 1.0
			and absf(viewport_rect.size.y - float(viewport_size.y)) <= 1.0,
			"%s: RunScene fills the resized Window" % case_name
	)

	var root_scroll: ScrollContainer = _run_scene.find_child("RunRootScroll", true, false) as ScrollContainer
	_assert(root_scroll != null, "%s: page content has an outer RunRootScroll" % case_name)
	if root_scroll != null:
		_assert_inside_horizontal_bounds(root_scroll, viewport_rect, "%s RunRootScroll" % case_name)
		_assert(root_scroll.follow_focus, "%s: outer page scroll follows focused controls" % case_name)
		_assert(
			root_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
			"%s: outer page scroll enables vertical scrolling when content is taller than the Window" % case_name
		)
		_assert(
			root_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
			"%s: outer page scroll does not introduce horizontal scrolling" % case_name
		)
		_assert(
			root_scroll.get_global_rect().size.x >= float(viewport_size.x) - 2.0,
			"%s: outer page scroll fills the allocated Window width" % case_name
		)
		_assert(
			_run_scene.find_child("RunJourneyPage", true, false) != null
				and root_scroll.is_ancestor_of(_run_scene.find_child("RunJourneyPage", true, false)),
			"%s: the existing RunJourneyPage remains inside the outer scroll" % case_name
		)
		if expect_vertical_scroll:
			var vertical_bar: VScrollBar = root_scroll.get_v_scroll_bar()
			_assert(
				vertical_bar != null and vertical_bar.max_value > vertical_bar.page,
				"%s: short windows can scroll through the complete Run page" % case_name
			)

	var header: Control = _run_scene.find_child("RunHeader", true, false) as Control
	var footer: Control = _run_scene.find_child("RunActionRail", true, false) as Control
	var feedback_scroll: ScrollContainer = _run_scene.find_child("RunFeedbackScroll", true, false) as ScrollContainer
	_assert(header != null, "%s: RunHeader remains available by its existing name" % case_name)
	_assert(footer != null, "%s: RunActionRail remains available by its existing name" % case_name)
	if header != null:
		_assert_inside_horizontal_bounds(header, viewport_rect, "%s RunHeader" % case_name)
		if expect_wide_fill:
			_assert(
				header.size.y < viewport_size.y * 0.35,
				"%s: wide header stays compact instead of one character per line" % case_name
			)
	if footer != null:
		_assert_inside_horizontal_bounds(footer, viewport_rect, "%s RunActionRail" % case_name)
		_assert_inside_vertical_bounds(footer, viewport_rect, "%s RunActionRail" % case_name)
		_assert(
			footer is BoxContainer and (footer as BoxContainer).vertical == (viewport_size.x < 720),
			"%s: footer stacks narrowly and uses a horizontal rail when wide" % case_name
		)
		if root_scroll != null:
			_assert(
				not root_scroll.is_ancestor_of(footer),
				"%s: RunActionRail stays outside the scrolling page" % case_name
			)
	if feedback_scroll != null:
		_assert(
			feedback_scroll.custom_minimum_size.y == 44.0 and feedback_scroll.size.y <= 45.0,
			"%s: receipt scrolling stays in a bounded 44-pixel viewport (actual height %.1f)" % [case_name, feedback_scroll.size.y]
		)
	if footer is BoxContainer and not (footer as BoxContainer).vertical:
		var back_action: Control = _run_scene.find_child("BackButton", true, false) as Control
		var finish_action: Control = _run_scene._summary_acknowledge_button as Control
		if back_action != null and finish_action != null and back_action.visible and finish_action.visible:
			_assert(
				absf(back_action.get_global_rect().position.y - finish_action.get_global_rect().position.y) <= 1.0,
				"%s: wide action buttons stay on one row instead of growing the pinned rail" % case_name
			)

	for control_name in ["GameTitle", "RunPhaseLabel", "SettingsButton", "NewRunButton", "BackButton", "FinishRunButton"]:
		var control: Control
		if control_name == "FinishRunButton":
			control = _run_scene._summary_acknowledge_button as Control
		else:
			control = _run_scene.find_child(control_name, true, false) as Control
		_assert(control != null, "%s: %s keeps its public control name" % [case_name, control_name])
		if control == null:
			continue
		if control.is_visible_in_tree():
			_assert_inside_horizontal_bounds(control, viewport_rect, "%s %s" % [case_name, control_name])
		if control.is_visible_in_tree() and control_name in ["BackButton", "FinishRunButton"]:
			_assert_inside_vertical_bounds(control, viewport_rect, "%s %s" % [case_name, control_name])
		if control is Button and control.is_visible_in_tree() and not expect_vertical_scroll:
			_assert(
				control.size.y >= 44.0,
				"%s: %s retains a 44-pixel minimum touch target" % [case_name, control_name]
			)

	var title: Label = _run_scene.find_child("GameTitle", true, false) as Label
	var phase: Label = _run_scene.find_child("RunPhaseLabel", true, false) as Label
	if title != null:
		_assert(
			title.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"%s: title can wrap within the responsive header" % case_name
		)
		if expect_wide_fill:
			_assert(
				title.size.x >= 100.0,
				"%s: wide title receives a readable natural width" % case_name
			)
	if phase != null:
		_assert(
			phase.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"%s: phase text can wrap within the responsive header" % case_name
		)
	var settings: Button = _run_scene.find_child("SettingsButton", true, false) as Button
	if settings != null and expect_wide_fill:
		_assert(settings.size.y < 120.0, "%s: Settings stays at button height rather than growing with the header" % case_name)

	var stage: Control = _run_scene.find_child("RunJourneyStage", true, false) as Control
	_assert(stage != null, "%s: RunJourneyStage remains available by its existing name" % case_name)
	var is_character_selection := _run_scene.controller != null and str(_run_scene.controller.domain.state.phase) == RunPhaseScript.CHARACTER_SELECT
	var stage_rect := stage.get_global_rect() if stage != null else Rect2()
	if stage != null and expect_wide_fill:
		if is_character_selection:
			var width_limit := 1500.0 * float(_run_scene._applied_preferences.get("ui_scale", 1.0))
			_assert(stage_rect.size.x <= width_limit + 4.0, "%s: Character stage remains within the centered composition width %.1fpx" % [case_name, width_limit])
			_assert(absf(stage_rect.get_center().x - viewport_rect.get_center().x) <= 8.0, "%s: Character stage centers in the wide Window" % case_name)
		else:
			_assert(
				stage.size.x >= viewport_rect.size.x - 80.0,
				"%s: non-Character stage uses the wide Window instead of a fixed-width letterbox" % case_name
			)
		if not is_character_selection and case_name in ["1440x960", "1920x1080"] and root_scroll != null:
			var root_scroll_rect := root_scroll.get_global_rect()
			_assert(
				stage_rect.end.y >= root_scroll_rect.end.y - 20.0,
				"%s: stage reaches the scroll viewport bottom within the body inset (stage=%s, scroll=%s)" % [case_name, str(stage_rect), str(root_scroll_rect)]
			)
	if stage != null and expect_vertical_scroll:
		_assert(
			stage.size.y >= 128.0,
			"%s: the stage keeps a usable minimum height inside a short-window scroll page" % case_name
		)

	_assert_root_anchored_overlay("PreferencesOverlay", case_name, viewport_rect)
	_assert(_run_scene.find_child("NewRunConfirmation", true, false) == null, "%s: New Run has no extra confirmation overlay" % case_name)


func _assert_root_anchored_overlay(overlay_name: String, case_name: String, expected_rect: Rect2) -> void:
	var overlay: Control = _run_scene.find_child(overlay_name, true, false) as Control
	_assert(overlay != null, "%s: %s remains present" % [case_name, overlay_name])
	if overlay == null:
		return
	_assert(overlay.get_parent() == _run_scene, "%s: %s stays anchored directly to RunScene" % [case_name, overlay_name])
	var actual_rect: Rect2 = overlay.get_global_rect()
	_assert(
		absf(actual_rect.position.x - expected_rect.position.x) <= 1.0
			and absf(actual_rect.position.y - expected_rect.position.y) <= 1.0
			and absf(actual_rect.size.x - expected_rect.size.x) <= 1.0
			and absf(actual_rect.size.y - expected_rect.size.y) <= 1.0,
		"%s: %s continues to cover the root viewport" % [case_name, overlay_name]
	)


func _assert_inside_horizontal_bounds(control: Control, bounds: Rect2, label: String) -> void:
	var actual_rect: Rect2 = control.get_global_rect()
	_assert(
		actual_rect.position.x >= bounds.position.x - 1.0
			and actual_rect.end.x <= bounds.end.x + 1.0,
		"%s stays inside the resized Window without horizontal clipping (actual=%s bounds=%s)" % [label, str(actual_rect), str(bounds)]
	)


func _assert_inside_vertical_bounds(control: Control, bounds: Rect2, label: String) -> void:
	var actual_rect: Rect2 = control.get_global_rect()
	_assert(
		actual_rect.position.y >= bounds.position.y - 1.0
			and actual_rect.end.y <= bounds.end.y + 1.0,
		"%s stays inside the resized Window with the action rail pinned" % label
	)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _remove_user_file(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
