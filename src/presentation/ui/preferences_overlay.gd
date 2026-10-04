class_name PreferencesOverlay
extends Control

signal closed
signal preferences_applied(preferences: Dictionary)

const Localization = preload("res://src/presentation/localization/localization.gd")
const ForbiddenTheme = preload("res://src/presentation/ui/forbidden_theme.gd")
const MODE_TEXT_KEYS := {
	"NORMAL": "UI_PREFS_MODE_NORMAL",
	"FAST": "UI_PREFS_MODE_FAST",
	"INSTANT": "UI_PREFS_MODE_INSTANT",
}
const LOCALE_TEXT_KEYS := {
	"en": "UI_PREFS_LOCALE_en",
	"zh_CN": "UI_PREFS_LOCALE_zh_CN",
}
const CARD_MAX_WIDTH := 960.0
const CARD_HORIZONTAL_MARGIN := 16.0
const CARD_VERTICAL_MARGIN := 12.0
const TWO_COLUMN_MIN_CONTENT_WIDTH := 680.0
const MAX_PAGE_BODY_HEIGHT := 220.0
const MIN_PAGE_BODY_HEIGHT := 96.0

var _preferences: Dictionary = {}
var _initial_preferences: Dictionary = {}
var _origin_focus: Control
var _tutorial_progress
var _pending_tutorial_enabled := true
var _tutorial_reset_pending := false
var _current_page := "settings"
var _built := false
var _viewport_fit_pending := false
var _prefs: Variant

var _backdrop: ColorRect
var _viewport_scroll: ScrollContainer
var _card: PanelContainer
var _outer_margin: MarginContainer
var _stack: VBoxContainer
var _header: HBoxContainer
var _tab_row: HFlowContainer
var _footer: HFlowContainer
var _brand: Label
var _title: Label
var _settings_tab: Button
var _help_tab: Button
var _settings_page: Control
var _help_page: Control
var _settings_scroll_frame: Control
var _help_scroll_frame: Control
var _mode_buttons: Dictionary = {}
var _language_buttons: Dictionary = {}
var _scale_buttons: Dictionary = {}
var _serif_labels: Array[Label] = []
var _reduced_motion_button: CheckButton
var _ambient_glow_button: CheckButton
var _tutorial_enabled_button: CheckButton
var _status_label: Label
var _apply_button: Button
var _cancel_button: Button
var _settings_scroll: ScrollContainer
var _help_scroll: ScrollContainer
var _refreshing := false
var _reveal_pending := false


func _ready() -> void:
	_prefs = get_tree().root.get_node_or_null("PresentationPrefs")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_build_ui()


func open(preferences: Dictionary, origin_focus: Control = null, tutorial_progress = null) -> void:
	if _prefs == null:
		_prefs = get_tree().root.get_node_or_null("PresentationPrefs")
	if not _built:
		_build_ui()
	_initial_preferences = _prefs.snapshot() if _prefs != null else {}
	for key in preferences:
		_initial_preferences[key] = preferences[key]
	_preferences = _initial_preferences.duplicate(true)
	_origin_focus = origin_focus
	_tutorial_progress = tutorial_progress
	_tutorial_reset_pending = false
	_pending_tutorial_enabled = bool(_tutorial_progress.enabled) if _tutorial_progress != null else true
	_current_page = "settings"
	visible = true
	_status_label.text = ""
	_status_label.visible = false
	_refresh()
	call_deferred("_focus_initial")


func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(_origin_focus) and _origin_focus.is_inside_tree() and _origin_focus.focus_mode != Control.FOCUS_NONE:
		_origin_focus.grab_focus()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_activate_focused_control()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_focus_next"):
		_move_modal_focus(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_focus_prev"):
		_move_modal_focus(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		if not _scroll_focused_page(1):
			_move_modal_focus(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		if not _scroll_focused_page(-1):
			_move_modal_focus(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_move_modal_focus(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_move_modal_focus(-1)
		get_viewport().set_input_as_handled()


func _move_modal_focus(direction: int) -> void:
	var focusables := _visible_focusables()
	if focusables.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner()
	var index := focusables.find(current)
	var next_index := 0 if index < 0 and direction > 0 else (focusables.size() - 1 if index < 0 else wrapi(index + direction, 0, focusables.size()))
	focusables[next_index].grab_focus()
	call_deferred("_reveal_focused_control_after_layout")


func _scroll_focused_page(direction: int) -> bool:
	var focused := get_viewport().gui_get_focus_owner() as Control
	if focused != _settings_scroll and focused != _help_scroll:
		return false
	var scroll := focused as ScrollContainer
	var scrollbar := scroll.get_v_scroll_bar()
	var maximum := maxi(0, roundi(scrollbar.max_value - scrollbar.page))
	var step := maxi(48, roundi(scrollbar.page * 0.75))
	scroll.scroll_vertical = clampi(scroll.scroll_vertical + direction * step, 0, maximum)
	return true


func _activate_focused_control() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if not focused is BaseButton:
		return
	var button := focused as BaseButton
	if button.disabled:
		return
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
	button.emit_signal("pressed")


func _init() -> void:
	# Copy is already resolved through Localization; controls must not translate
	# it a second time (which also doubles pseudo-localization expansion).
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _build_ui() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.015, 0.055, 0.043, 0.88)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_viewport_scroll = ScrollContainer.new()
	_viewport_scroll.name = "ViewportScroll"
	_viewport_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_viewport_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_viewport_scroll.follow_focus = true
	add_child(_viewport_scroll)
	var center := CenterContainer.new()
	center.name = "Center"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_scroll.add_child(center)

	_card = PanelContainer.new()
	_card.name = "PreferencesCard"
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(_card)
	ForbiddenTheme.style_panel(_card, "lacquer")

	_outer_margin = MarginContainer.new()
	_outer_margin.add_theme_constant_override("margin_left", 18)
	_outer_margin.add_theme_constant_override("margin_right", 18)
	_outer_margin.add_theme_constant_override("margin_top", 12)
	_outer_margin.add_theme_constant_override("margin_bottom", 12)
	_card.add_child(_outer_margin)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 8)
	_outer_margin.add_child(_stack)

	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 16)
	_stack.add_child(_header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(title_stack)
	_brand = Label.new()
	_brand.name = "BrandLabel"
	_brand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brand.set_meta("localization_key", "UI_PREFS_BRAND")
	_brand.text = Localization.text("UI_PREFS_BRAND")
	title_stack.add_child(_brand)
	_title = Label.new()
	_title.name = "TitleLabel"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_stack.add_child(_title)
	ForbiddenTheme.title(_title, "en")
	_serif_labels.append(_title)
	var close_button := _make_button("UI_PREFS_CLOSE", _on_cancel_pressed)
	close_button.name = "CloseButton"
	_header.add_child(close_button)

	_tab_row = HFlowContainer.new()
	_tab_row.add_theme_constant_override("h_separation", 8)
	_tab_row.add_theme_constant_override("v_separation", 6)
	_stack.add_child(_tab_row)
	_settings_tab = _make_button("UI_PREFS_TAB_SETTINGS", _on_settings_tab_pressed)
	_settings_tab.name = "SettingsTabButton"
	_settings_tab.custom_minimum_size = Vector2(0, 44)
	_settings_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_row.add_child(_settings_tab)
	_help_tab = _make_button("UI_PREFS_TAB_HELP", _on_help_tab_pressed)
	_help_tab.name = "HelpTabButton"
	_help_tab.custom_minimum_size = Vector2(0, 44)
	_help_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_row.add_child(_help_tab)

	_settings_scroll = _make_page_scroll("SettingsPage")
	_settings_page = _build_settings_page()
	_settings_scroll.add_child(_settings_page)
	_stack.add_child(_settings_scroll_frame)
	_help_scroll = _make_page_scroll("HelpPage")
	_help_page = _build_help_page()
	_help_scroll.add_child(_help_page)
	_stack.add_child(_help_scroll_frame)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.visible = false
	_stack.add_child(_status_label)

	_footer = HFlowContainer.new()
	_footer.add_theme_constant_override("h_separation", 10)
	_footer.add_theme_constant_override("v_separation", 8)
	_stack.add_child(_footer)
	_cancel_button = _make_button("UI_PREFS_CANCEL", _on_cancel_pressed)
	_cancel_button.name = "CancelButton"
	_cancel_button.custom_minimum_size = Vector2(0, 44)
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_cancel_button)
	_apply_button = _make_button("UI_PREFS_APPLY_LANGUAGE", _on_apply_pressed, true)
	_apply_button.name = "ApplyButton"
	_apply_button.custom_minimum_size = Vector2(0, 44)
	_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_apply_button)
	_fit_to_viewport()
	_refresh()


func _build_settings_page() -> Control:
	var columns := GridContainer.new()
	columns.name = "SettingsPage"
	columns.columns = 2
	columns.add_theme_constant_override("h_separation", 16)
	columns.add_theme_constant_override("v_separation", 16)
	var feedback_panel := _section_panel("UI_PREFS_FEEDBACK_SPEED")
	feedback_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(feedback_panel)
	var feedback_stack := feedback_panel.get_child(0).get_child(0) as VBoxContainer
	var mode_row := HFlowContainer.new()
	mode_row.add_theme_constant_override("h_separation", 6)
	mode_row.add_theme_constant_override("v_separation", 6)
	feedback_stack.add_child(mode_row)
	for mode in ["NORMAL", "FAST", "INSTANT"]:
		var mode_button := Button.new()
		mode_button.name = "Mode_%s" % mode
		mode_button.toggle_mode = true
		mode_button.custom_minimum_size.y = 44
		mode_button.pressed.connect(_on_mode_pressed.bind(mode))
		_mode_buttons[mode] = mode_button
		mode_row.add_child(mode_button)
	var mode_hint := _make_label("UI_PREFS_MODE_HINT", true)
	feedback_stack.add_child(mode_hint)
	_reduced_motion_button = CheckButton.new()
	_reduced_motion_button.name = "ReducedMotionButton"
	_reduced_motion_button.toggled.connect(_on_reduced_motion_toggled)
	feedback_stack.add_child(_reduced_motion_button)
	_ambient_glow_button = CheckButton.new()
	_ambient_glow_button.name = "AmbientGlowButton"
	_ambient_glow_button.toggled.connect(_on_ambient_glow_toggled)
	feedback_stack.add_child(_ambient_glow_button)
	var scale_label := _make_label("UI_PREFS_UI_SCALE", false)
	feedback_stack.add_child(scale_label)
	var scale_buttons_row := HFlowContainer.new()
	scale_buttons_row.add_theme_constant_override("h_separation", 6)
	scale_buttons_row.add_theme_constant_override("v_separation", 6)
	feedback_stack.add_child(scale_buttons_row)
	for scale_value in [1.0, 1.25, 1.5]:
		var scale_button := Button.new()
		scale_button.name = "Scale_%d" % int(round(scale_value * 100.0))
		scale_button.toggle_mode = true
		scale_button.custom_minimum_size = Vector2(72, 44)
		scale_button.pressed.connect(_on_scale_pressed.bind(scale_value))
		_scale_buttons[scale_value] = scale_button
		scale_buttons_row.add_child(scale_button)

	var language_panel := _section_panel("UI_PREFS_LANGUAGE")
	language_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(language_panel)
	var language_stack := language_panel.get_child(0).get_child(0) as VBoxContainer
	for locale_id in ["en", "zh_CN"]:
		var language_button := Button.new()
		language_button.name = "Language_%s" % locale_id
		language_button.toggle_mode = true
		language_button.custom_minimum_size.y = 48
		language_button.pressed.connect(_on_language_pressed.bind(locale_id))
		_language_buttons[locale_id] = language_button
		language_stack.add_child(language_button)
	language_stack.add_child(_make_label("UI_PREFS_LANGUAGE_HINT", true))
	return columns


func _build_help_page() -> Control:
	var panel := _section_panel("UI_PREFS_HELP_TITLE")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := panel.get_child(0).get_child(0) as VBoxContainer
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_make_label("UI_PREFS_HELP_INTRO", true))
	content.add_child(_make_label("UI_PREFS_HELP_BATTLE", true))
	content.add_child(_make_label("UI_PREFS_HELP_TILE_MARKS", true))
	content.add_child(_make_label("UI_PREFS_HELP_INPUT", true))
	content.add_child(_make_label("UI_PREFS_HELP_LANGUAGE", true))
	var tutorial_heading := _make_label("UI_PREFS_TUTORIAL_TITLE", false)
	content.add_child(tutorial_heading)
	_tutorial_enabled_button = CheckButton.new()
	_tutorial_enabled_button.name = "TutorialEnabledButton"
	_tutorial_enabled_button.toggled.connect(_on_tutorial_toggled)
	content.add_child(_tutorial_enabled_button)
	var reset_button := _make_button("UI_PREFS_TUTORIAL_RESET", _on_tutorial_reset_pressed)
	reset_button.name = "TutorialResetButton"
	content.add_child(reset_button)
	return panel


func _make_page_scroll(node_name: String) -> ScrollContainer:
	var frame := Control.new()
	frame.name = node_name + "FocusFrame"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = node_name + "Scroll"
	scroll.custom_minimum_size.y = 0
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	frame.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var focus_outline := Panel.new()
	focus_outline.name = "ScrollFocusOutline"
	focus_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_outline.focus_mode = Control.FOCUS_NONE
	focus_outline.visible = false
	focus_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outline_style := StyleBoxFlat.new()
	outline_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	outline_style.draw_center = false
	outline_style.border_color = ForbiddenTheme.color("focus")
	var outline_width := roundi(3.0 * (float(_prefs.ui_scale) if _prefs != null else 1.0))
	outline_style.border_width_left = outline_width
	outline_style.border_width_top = outline_width
	outline_style.border_width_right = outline_width
	outline_style.border_width_bottom = outline_width
	outline_style.expand_margin_left = outline_width
	outline_style.expand_margin_top = outline_width
	outline_style.expand_margin_right = outline_width
	outline_style.expand_margin_bottom = outline_width
	focus_outline.add_theme_stylebox_override("panel", outline_style)
	frame.add_child(focus_outline)
	scroll.focus_entered.connect(func() -> void: focus_outline.visible = true)
	scroll.focus_exited.connect(func() -> void: focus_outline.visible = false)
	if node_name == "SettingsPage":
		_settings_scroll_frame = frame
	else:
		_help_scroll_frame = frame
	return scroll


func _fit_to_viewport() -> void:
	if (
		not _built
		or not is_instance_valid(_card)
		or not is_instance_valid(_settings_scroll)
		or not is_instance_valid(_help_scroll)
	):
		return
	var viewport_size := get_viewport_rect().size
	var scrollbar_width := _viewport_scroll.get_v_scroll_bar().get_combined_minimum_size().x if _viewport_scroll != null else 0.0
	var card_width := maxf(0.0, minf(CARD_MAX_WIDTH, viewport_size.x - CARD_HORIZONTAL_MARGIN * 2.0 - scrollbar_width))
	_card.custom_minimum_size.x = card_width
	var side_margin := 12 if card_width < 720.0 else 18
	_outer_margin.add_theme_constant_override("margin_left", side_margin)
	_outer_margin.add_theme_constant_override("margin_right", side_margin)
	var panel_style := _card.get_theme_stylebox("panel")
	# Use the actual available inner width so the two-column layout only appears
	# when both settings panels have room; smaller cards keep one readable column.
	var settings_grid := _settings_page as GridContainer
	if settings_grid != null:
		var panel_insets := panel_style.get_minimum_size().x if panel_style != null else 0.0
		var inner_width := maxf(0.0, card_width - panel_insets - side_margin * 2.0)
		settings_grid.columns = 2 if inner_width >= TWO_COLUMN_MIN_CONTENT_WIDTH else 1
	var visible_children := 0
	for child in _stack.get_children():
		if (child as Control).visible:
			visible_children += 1
	var chrome_height := _header.get_combined_minimum_size().y
	chrome_height += _tab_row.get_combined_minimum_size().y
	chrome_height += _footer.get_combined_minimum_size().y
	if _status_label.visible:
		chrome_height += _status_label.get_combined_minimum_size().y
	chrome_height += _stack.get_theme_constant("separation") * maxf(0.0, float(visible_children - 1))
	var frame_height := panel_style.get_minimum_size().y if panel_style != null else 0.0
	frame_height += _outer_margin.get_theme_constant("margin_top") + _outer_margin.get_theme_constant("margin_bottom")
	var available_body_height := viewport_size.y - CARD_VERTICAL_MARGIN * 2.0 - chrome_height - frame_height
	var ui_scale := float(_prefs.ui_scale) if _prefs != null else 1.0
	var body_height := maxf(MIN_PAGE_BODY_HEIGHT * ui_scale, minf(MAX_PAGE_BODY_HEIGHT * ui_scale, maxf(0.0, available_body_height)))
	_settings_scroll.custom_minimum_size.y = body_height
	_help_scroll.custom_minimum_size.y = body_height


func _schedule_viewport_fit() -> void:
	if not _built or _viewport_fit_pending:
		return
	_viewport_fit_pending = true
	call_deferred("_fit_to_viewport_after_layout")


func _fit_to_viewport_after_layout() -> void:
	_viewport_fit_pending = false
	if not _built or not is_inside_tree():
		return
	_fit_to_viewport()


func _on_viewport_size_changed() -> void:
	_schedule_viewport_fit()


func _section_panel(heading_key: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ForbiddenTheme.style_panel(panel, "lacquer")
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var heading := Label.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.set_meta("localization_key", heading_key)
	ForbiddenTheme.title(heading, "en")
	_serif_labels.append(heading)
	stack.add_child(heading)
	return panel


func _make_button(text_key: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.set_meta("localization_key", text_key)
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	ForbiddenTheme.style_button(button, primary)
	return button


func _make_label(text_key: String, wrap: bool) -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.set_meta("localization_key", text_key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return label


func _refresh() -> void:
	if not _built:
		return
	var active_locale := str(_prefs.locale) if _prefs != null else "en"
	var ui_scale := float(_prefs.ui_scale) if _prefs != null else 1.0
	theme = ForbiddenTheme.create_theme(active_locale, ui_scale)
	ForbiddenTheme.style_panel(_card, "lacquer")
	for label in _serif_labels:
		ForbiddenTheme.title(label, active_locale)
	_title.text = Localization.text("UI_PREFS_TITLE")
	_brand.text = Localization.text("UI_PREFS_BRAND")
	for node in find_children("*", "Label", true, false):
		var label := node as Label
		if label.has_meta("localization_key"):
			label.text = Localization.text(str(label.get_meta("localization_key")))
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if button.has_meta("localization_key"):
			button.text = Localization.text(str(button.get_meta("localization_key")))
		ForbiddenTheme.style_button(button, button == _apply_button, button.toggle_mode and button.button_pressed)
	for node in find_children("*", "PanelContainer", true, false):
		ForbiddenTheme.style_panel(node as Control, "lacquer")
	_settings_tab.button_pressed = _current_page == "settings"
	_help_tab.button_pressed = _current_page == "help"
	_settings_scroll_frame.visible = _current_page == "settings"
	_help_scroll_frame.visible = _current_page == "help"
	_settings_tab.text = Localization.text("UI_PREFS_TAB_SETTINGS")
	_help_tab.text = Localization.text("UI_PREFS_TAB_HELP")
	_reduced_motion_button.text = Localization.text("UI_PREFS_REDUCED_MOTION")
	_reduced_motion_button.set_pressed_no_signal(bool(_preferences.get("reduced_motion", false)))
	_ambient_glow_button.text = Localization.text("UI_PREFS_AMBIENT_GLOW")
	_ambient_glow_button.set_pressed_no_signal(bool(_preferences.get("ambient_glow", true)))
	var selected_scale := int(round(float(_preferences.get("ui_scale", 1.0)) * 100.0))
	for scale_value in _scale_buttons.keys():
		var scale_button: Button = _scale_buttons[scale_value]
		var scale_key := "UI_PREFS_SCALE_DEFAULT" if int(round(float(scale_value) * 100.0)) == 100 else ("UI_PREFS_SCALE_125" if int(round(float(scale_value) * 100.0)) == 125 else "UI_PREFS_SCALE_150")
		scale_button.text = Localization.text(scale_key)
		scale_button.button_pressed = int(round(float(scale_value) * 100.0)) == selected_scale
		ForbiddenTheme.style_button(scale_button, false, scale_button.button_pressed)
	for mode in _mode_buttons.keys():
		var button: Button = _mode_buttons[mode]
		button.text = Localization.text(str(MODE_TEXT_KEYS[mode]))
		button.button_pressed = str(_preferences.get("presentation_mode", "NORMAL")) == str(mode)
		ForbiddenTheme.style_button(button, false, button.button_pressed)
	for locale_id in _language_buttons.keys():
		var language_button: Button = _language_buttons[locale_id]
		language_button.text = Localization.text(str(LOCALE_TEXT_KEYS[locale_id]))
		language_button.button_pressed = str(_preferences.get("locale", "en")) == str(locale_id)
		ForbiddenTheme.style_button(language_button, false, language_button.button_pressed)
	_tutorial_enabled_button.text = Localization.text("UI_PREFS_TUTORIAL_ENABLED" if _pending_tutorial_enabled else "UI_PREFS_TUTORIAL_DISABLED")
	_tutorial_enabled_button.set_pressed_no_signal(_pending_tutorial_enabled)
	_tutorial_enabled_button.visible = _tutorial_progress != null
	_tutorial_enabled_button.disabled = _tutorial_progress == null
	_tutorial_reset_button_visibility()
	_apply_button.text = Localization.text("UI_PREFS_APPLY_LANGUAGE" if str(_preferences.get("locale", "en")) != active_locale else "UI_PREFS_APPLY_SETTINGS")
	_schedule_viewport_fit()
	call_deferred("_reveal_focused_control_after_layout")


func _tutorial_reset_button_visibility() -> void:
	var reset_button := find_child("TutorialResetButton", true, false) as Button
	if reset_button != null:
		reset_button.visible = _tutorial_progress != null
		reset_button.disabled = _tutorial_progress == null


func _focus_initial() -> void:
	if visible and is_instance_valid(_language_buttons.get(str(_preferences.get("locale", "en")))):
		(_language_buttons[str(_preferences.get("locale", "en"))] as Button).grab_focus()
		call_deferred("_reveal_focused_control_after_layout")


func _reveal_focused_control_after_layout() -> void:
	if _reveal_pending or not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	_reveal_pending = true
	tree.process_frame.connect(Callable(self, "_reveal_focused_control_after_layout_after_frame"), CONNECT_ONE_SHOT)


func _reveal_focused_control_after_layout_after_frame() -> void:
	_reveal_pending = false
	if not is_inside_tree() or not visible:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var focused := viewport.gui_get_focus_owner() as Control
	if focused == null or not is_ancestor_of(focused):
		return
	var scroll := _page_scroll_containing(focused)
	var scale := float(_prefs.ui_scale) if _prefs != null else 1.0
	var ring_margin := maxf(3.0, ceilf(3.0 * scale))
	if scroll != null and focused != scroll:
		scroll.ensure_control_visible(focused)
		_keep_focus_ring_visible(scroll, focused, ring_margin)
	if _viewport_scroll != null:
		_viewport_scroll.ensure_control_visible(focused)
		_keep_focus_ring_visible(_viewport_scroll, focused, ring_margin)


func _keep_focus_ring_visible(scroll: ScrollContainer, focused: Control, ring_margin: float) -> void:
	var usable_rect := scroll.get_global_rect()
	var horizontal_bar := scroll.get_h_scroll_bar()
	if horizontal_bar.is_visible_in_tree():
		var horizontal_rect := horizontal_bar.get_global_rect()
		if horizontal_rect.position.y >= usable_rect.position.y + usable_rect.size.y * 0.5:
			usable_rect.size.y = maxf(0.0, horizontal_rect.position.y - usable_rect.position.y)
		else:
			var bottom_edge := usable_rect.end.y
			usable_rect.position.y = horizontal_rect.end.y
			usable_rect.size.y = maxf(0.0, bottom_edge - usable_rect.position.y)
	var focused_rect := focused.get_global_rect()
	if focused_rect.size.y + ring_margin * 2.0 > usable_rect.size.y:
		return
	var correction := 0
	if focused_rect.position.y < usable_rect.position.y + ring_margin:
		correction = floori(focused_rect.position.y - usable_rect.position.y - ring_margin)
	elif focused_rect.end.y > usable_rect.end.y - ring_margin:
		correction = ceili(focused_rect.end.y - usable_rect.end.y + ring_margin)
	if correction != 0:
		var scrollbar := scroll.get_v_scroll_bar()
		var maximum := maxi(0, roundi(scrollbar.max_value - scrollbar.page))
		scroll.scroll_vertical = clampi(scroll.scroll_vertical + correction, 0, maximum)


func _page_scroll_containing(control: Control) -> ScrollContainer:
	if control == _settings_scroll or (_settings_scroll != null and _settings_scroll.is_ancestor_of(control)):
		return _settings_scroll
	if control == _help_scroll or (_help_scroll != null and _help_scroll.is_ancestor_of(control)):
		return _help_scroll
	return null


func _on_settings_tab_pressed() -> void:
	_current_page = "settings"
	_refresh()


func _on_help_tab_pressed() -> void:
	_current_page = "help"
	_refresh()
	_tutorial_enabled_button.grab_focus() if _tutorial_progress != null else _help_tab.grab_focus()


func _on_mode_pressed(mode: String) -> void:
	_preferences.presentation_mode = mode
	_refresh()
	(_mode_buttons[mode] as Button).grab_focus()


func _on_language_pressed(locale_id: String) -> void:
	_preferences.locale = locale_id
	_refresh()
	(_language_buttons[locale_id] as Button).grab_focus()


func _on_reduced_motion_toggled(enabled: bool) -> void:
	_preferences.reduced_motion = enabled


func _on_ambient_glow_toggled(enabled: bool) -> void:
	_preferences.ambient_glow = enabled


func _on_scale_pressed(scale_value: float) -> void:
	_preferences.ui_scale = scale_value
	_refresh()
	(_scale_buttons[scale_value] as Button).grab_focus()


func _on_tutorial_toggled(enabled: bool) -> void:
	_pending_tutorial_enabled = enabled
	_tutorial_enabled_button.text = Localization.text("UI_PREFS_TUTORIAL_ENABLED" if enabled else "UI_PREFS_TUTORIAL_DISABLED")


func _on_tutorial_reset_pressed() -> void:
	_tutorial_reset_pending = true
	_pending_tutorial_enabled = true
	_tutorial_enabled_button.button_pressed = true
	_tutorial_enabled_button.text = Localization.text("UI_PREFS_TUTORIAL_ENABLED")
	_status_label.text = Localization.text("UI_PREFS_TUTORIAL_RESET_PENDING")
	_status_label.visible = true
	_schedule_viewport_fit()


func _on_apply_pressed() -> void:
	if _prefs == null:
		_status_label.text = Localization.format("UI_PREFS_PERSISTENCE_ERROR", ["preferences service unavailable"])
		_status_label.visible = true
		return
	var applied: Dictionary = _prefs.apply_preferences(_preferences)
	_preferences = applied.duplicate(true)
	if _tutorial_progress != null:
		if _tutorial_reset_pending:
			_tutorial_progress.reset()
		elif _pending_tutorial_enabled:
			_tutorial_progress.enable()
		else:
			_tutorial_progress.disable()
	preferences_applied.emit(applied.duplicate(true))
	_refresh()
	if not str(_prefs.last_persistence_error).is_empty():
		_status_label.text = Localization.format("UI_PREFS_PERSISTENCE_ERROR", [_prefs.last_persistence_error])
		_status_label.visible = true
		_schedule_viewport_fit()
		return
	close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built and is_instance_valid(_settings_scroll) and is_instance_valid(_help_scroll):
		_schedule_viewport_fit()
		call_deferred("_reveal_focused_control_after_layout")


func _visible_focusables() -> Array[Control]:
	var focusables: Array[Control] = []
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree():
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		focusables.append(control)
	return focusables


func _on_cancel_pressed() -> void:
	close()
