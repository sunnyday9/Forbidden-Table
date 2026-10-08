extends RefCounted

const PreferencesOverlay = preload("res://src/presentation/ui/preferences_overlay.gd")
const VIEWPORTS := [Vector2i(960, 540), Vector2i(1226, 660), Vector2i(2560, 1440)]
const LOCALES := ["en", "zh_CN"]
const UI_SCALES := [1.0, 1.25, 1.5]
const MIN_TWO_COLUMN_WIDTH := 680.0

class MemoryPreferences:
	extends RefCounted
	var values := {
		"locale": "en",
		"ui_scale": 1.0,
		"presentation_mode": "NORMAL",
		"reduced_motion": false,
		"ambient_glow": false,
	}
	var apply_count := 0
	var last_persistence_error := ""
	var locale: String:
		get:
			return str(values.get("locale", "en"))
	var ui_scale: float:
		get:
			return float(values.get("ui_scale", 1.0))

	func snapshot() -> Dictionary:
		return values.duplicate(true)

	func apply_preferences(next_values: Dictionary) -> Dictionary:
		apply_count += 1
		values = next_values.duplicate(true)
		return snapshot()


class MemoryTutorialProgress:
	extends RefCounted
	var enabled := true
	var reset_count := 0

	func reset() -> void:
		reset_count += 1
		enabled = true

	func enable() -> void:
		enabled = true

	func disable() -> void:
		enabled = false


var _failures: Array[String] = []
var _overlay: Control
var _preferences: MemoryPreferences
var _tutorial_progress: MemoryTutorialProgress
var _applied_events: Array[Dictionary] = []
var _tree: SceneTree


func _settle(frame_count: int = 4) -> void:
	for _index in range(frame_count):
		await _tree.process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL " + message)
		_failures.append(message)


func run() -> Array[String]:
	_failures.clear()
	_applied_events.clear()
	_tree = Engine.get_main_loop() as SceneTree
	if _tree == null:
		return ["RC2 Preferences regression test requires an active SceneTree"]
	var previous_locale := TranslationServer.get_locale()
	var previous_window_size: Vector2i = _tree.root.size
	var previous_content_scale_mode: int = _tree.root.content_scale_mode
	_tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_preferences = MemoryPreferences.new()
	_tutorial_progress = MemoryTutorialProgress.new()
	_overlay = PreferencesOverlay.new()
	_tree.root.add_child(_overlay)
	await _settle(8)
	_overlay._prefs = _preferences
	_overlay.preferences_applied.connect(func(values: Dictionary) -> void: _applied_events.append(values))

	for locale_id in LOCALES:
		TranslationServer.set_locale(locale_id)
		for ui_scale in UI_SCALES:
			_preferences.values = {
				"locale": locale_id,
				"ui_scale": ui_scale,
				"presentation_mode": "NORMAL",
				"reduced_motion": false,
				"ambient_glow": false,
			}
			for viewport_size in VIEWPORTS:
				_tree.root.size = viewport_size
				await _settle(4)
				_overlay.open(_preferences.snapshot(), null, _tutorial_progress)
				await _settle(3)
				_overlay._fit_to_viewport()
				await _settle(3)
				_check_page_layout("Settings", viewport_size, locale_id, ui_scale)
				_check_settings_width(viewport_size, locale_id, ui_scale)
				_overlay._on_help_tab_pressed()
				await _settle(3)
				_check_page_layout("Help", viewport_size, locale_id, ui_scale)
				await _check_help_focus(viewport_size, locale_id, ui_scale)
				_overlay._on_settings_tab_pressed()
				await _settle(2)
				_overlay.close()

	await _check_apply_cancel_semantics()
	TranslationServer.set_locale(previous_locale)
	_overlay.queue_free()
	await _settle(2)
	_tree.root.size = previous_window_size
	_tree.root.content_scale_mode = previous_content_scale_mode
	return _failures


func _check_page_layout(page_name: String, viewport_size: Vector2i, locale_id: String, ui_scale: float) -> void:
	var body: ScrollContainer = _overlay._settings_scroll if page_name == "Settings" else _overlay._help_scroll
	var card_rect: Rect2 = _overlay._card.get_global_rect()
	var body_rect: Rect2 = body.get_global_rect()
	var footer_rect: Rect2 = _overlay._footer.get_global_rect()
	var context := "%s %s %s%% at %s" % [page_name, locale_id, roundi(ui_scale * 100.0), viewport_size]
	var inside_card: bool = (
		body_rect.position.x >= card_rect.position.x - 1.0
		and body_rect.position.y >= card_rect.position.y - 1.0
		and body_rect.end.x <= card_rect.end.x + 1.0
		and body_rect.end.y <= card_rect.end.y + 1.0
	)
	_check(inside_card, "%s body is fully enclosed by the card" % context)
	_check(footer_rect.position.y >= body_rect.end.y - 1.0, "%s footer starts below the body" % context)
	_check(
		_overlay._cancel_button.get_global_rect().intersects(footer_rect)
		and _overlay._apply_button.get_global_rect().intersects(footer_rect)
		and card_rect.encloses(_overlay._cancel_button.get_global_rect())
		and card_rect.encloses(_overlay._apply_button.get_global_rect()),
		"%s Apply and Cancel remain inside the card footer" % context
	)


func _check_settings_width(viewport_size: Vector2i, locale_id: String, ui_scale: float) -> void:
	var grid: GridContainer = _overlay._settings_page
	var allocated_width := grid.get_global_rect().size.x
	var scroll_width: float = _overlay._settings_scroll.get_global_rect().size.x
	var context := "Settings %s %s%% at %s" % [locale_id, roundi(ui_scale * 100.0), viewport_size]
	_check(
		allocated_width >= scroll_width * 0.85,
		"%s grid fills the available scroll width (grid %.1f / viewport %.1f)" % [context, allocated_width, scroll_width]
	)
	var expected_columns := 2 if allocated_width >= MIN_TWO_COLUMN_WIDTH * ui_scale else 1
	_check(
		grid.columns == expected_columns,
		"%s uses %d readable columns for its actual %.1fpx allocation (has %d)" % [context, expected_columns, allocated_width, grid.columns]
	)
	var panel_width := (allocated_width - 16.0) / float(grid.columns)
	_check(
		grid.columns == 1 or panel_width >= MIN_TWO_COLUMN_WIDTH * ui_scale * 0.48,
		"%s gives each Settings panel a readable minimum width" % context
	)


func _check_help_focus(viewport_size: Vector2i, locale_id: String, ui_scale: float) -> void:
	var reset_button := _overlay.find_child("TutorialResetButton", true, false) as Button
	var context := "Help %s %s%% at %s" % [locale_id, roundi(ui_scale * 100.0), viewport_size]
	_check(_overlay._help_scroll.get_v_scroll_bar().max_value > _overlay._help_scroll.get_v_scroll_bar().page, "%s content remains vertically scrollable" % context)
	_check(_overlay._page_scroll_containing(reset_button) == _overlay._help_scroll, "%s tutorial control belongs to the Help scroll page" % context)
	_overlay._help_scroll.scroll_vertical = 0
	_overlay._help_scroll.grab_focus()
	var scrolled: bool = _overlay._scroll_focused_page(1)
	_check(scrolled and _overlay._help_scroll.scroll_vertical > 0, "%s focused Help surface scrolls down by keyboard action" % context)
	await _settle(2)
	reset_button.grab_focus()
	await _settle(4)
	_check(_tree.root.get_viewport().gui_get_focus_owner() == reset_button, "%s keyboard focus reaches the last Help action" % context)
	var focused_control_visible: bool = _overlay._help_scroll.get_global_rect().encloses(reset_button.get_global_rect())
	_check(
		focused_control_visible,
		"%s focused Help action scrolls into the readable viewport" % context
	)
	await _check_footer_focus(_overlay._cancel_button, "Cancel", context)
	await _check_footer_focus(_overlay._apply_button, "Apply", context)


func _check_footer_focus(button: Button, action_name: String, context: String) -> void:
	button.grab_focus()
	_overlay._reveal_focused_control_after_layout_after_frame()
	await _settle(2)
	var focused := _tree.root.get_viewport().gui_get_focus_owner() == button
	var ring_margin := ceilf(3.0 * float(_preferences.ui_scale))
	var viewport_rect: Rect2 = _overlay._viewport_scroll.get_global_rect()
	var button_rect: Rect2 = button.get_global_rect().grow(ring_margin)
	_check(focused, "%s %s is reachable by keyboard focus" % [context, action_name])
	_check(viewport_rect.encloses(button_rect), "%s brings %s and its focus ring into view" % [context, action_name])


func _check_apply_cancel_semantics() -> void:
	TranslationServer.set_locale("en")
	_tree.root.size = Vector2i(960, 540)
	_preferences.values = {
		"locale": "en",
		"ui_scale": 1.0,
		"presentation_mode": "NORMAL",
		"reduced_motion": false,
		"ambient_glow": false,
	}
	var original := _preferences.snapshot()
	var starting_apply_count := _preferences.apply_count
	_overlay.open(_preferences.snapshot(), null, _tutorial_progress)
	await _settle(4)
	_overlay._on_reduced_motion_toggled(true)
	_overlay._on_cancel_pressed()
	_check(not _overlay.visible, "Cancel closes the preferences modal")
	_check(_preferences.snapshot() == original, "Cancel discards pending preferences without persisting")
	_check(_preferences.apply_count == starting_apply_count, "Cancel never calls preference persistence")

	_overlay.open(_preferences.snapshot(), null, _tutorial_progress)
	await _settle(3)
	_overlay._on_reduced_motion_toggled(true)
	_overlay._on_apply_pressed()
	_check(not _overlay.visible, "Apply closes after successfully applying preferences")
	_check(_preferences.apply_count == starting_apply_count + 1, "Apply persists pending preferences exactly once")
	_check(bool(_preferences.values.get("reduced_motion", false)), "Apply commits the pending preference value")
	_check(_applied_events.size() == 1 and bool(_applied_events[0].get("reduced_motion", false)), "Apply emits the committed preference snapshot")
