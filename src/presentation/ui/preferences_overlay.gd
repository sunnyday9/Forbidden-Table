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

var _preferences: Dictionary = {}
var _initial_preferences: Dictionary = {}
var _origin_focus: Control
var _tutorial_progress
var _pending_tutorial_enabled := true
var _tutorial_reset_pending := false
var _current_page := "settings"
var _built := false
var _prefs: Variant

var _backdrop: ColorRect
var _card: PanelContainer
var _outer_margin: MarginContainer
var _stack: VBoxContainer
var _header: HBoxContainer
var _tab_row: HBoxContainer
var _footer: HBoxContainer
var _brand: Label
var _title: Label
var _settings_tab: Button
var _help_tab: Button
var _settings_page: Control
var _help_page: Control
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


func _ready() -> void:
	_prefs = get_tree().root.get_node_or_null("PresentationPrefs")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
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
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_move_modal_focus(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
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

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.name = "PreferencesCard"
	_card.custom_minimum_size = Vector2(720, 0)
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

	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 8)
	_stack.add_child(_tab_row)
	_settings_tab = _make_button("UI_PREFS_TAB_SETTINGS", _on_settings_tab_pressed)
	_settings_tab.name = "SettingsTabButton"
	_settings_tab.custom_minimum_size = Vector2(130, 44)
	_tab_row.add_child(_settings_tab)
	_help_tab = _make_button("UI_PREFS_TAB_HELP", _on_help_tab_pressed)
	_help_tab.name = "HelpTabButton"
	_help_tab.custom_minimum_size = Vector2(130, 44)
	_tab_row.add_child(_help_tab)

	_settings_scroll = _make_page_scroll("SettingsPage")
	_settings_page = _build_settings_page()
	_settings_scroll.add_child(_settings_page)
	_stack.add_child(_settings_scroll)
	_help_scroll = _make_page_scroll("HelpPage")
	_help_page = _build_help_page()
	_help_scroll.add_child(_help_page)
	_stack.add_child(_help_scroll)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.visible = false
	_stack.add_child(_status_label)

	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 10)
	_stack.add_child(_footer)
	_cancel_button = _make_button("UI_PREFS_CANCEL", _on_cancel_pressed)
	_cancel_button.name = "CancelButton"
	_cancel_button.custom_minimum_size = Vector2(150, 44)
	_footer.add_child(_cancel_button)
	_apply_button = _make_button("UI_PREFS_APPLY_LANGUAGE", _on_apply_pressed, true)
	_apply_button.name = "ApplyButton"
	_apply_button.custom_minimum_size = Vector2(190, 44)
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
	var mode_row := VBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
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
	var scale_buttons_row := HBoxContainer.new()
	scale_buttons_row.add_theme_constant_override("separation", 6)
	feedback_stack.add_child(scale_buttons_row)
	for scale_value in [1.0, 1.25, 1.5]:
		var scale_button := Button.new()
		scale_button.name = "Scale_%d" % int(round(scale_value * 100.0))
		scale_button.toggle_mode = true
		scale_button.custom_minimum_size = Vector2(76, 44)
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
	language_stack.add_child(_make_label("UI_PREFS_LANGUAGE_INPUT_HINT", true))
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
	var scroll := ScrollContainer.new()
	scroll.name = node_name + "Scroll"
	scroll.custom_minimum_size.y = 0
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


func _fit_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	_card.custom_minimum_size.x = minf(720.0, maxf(320.0, viewport_size.x - 32.0))
	# Stack the settings panels when their translated controls cannot fit the
	# intended card width; the existing vertical scroll keeps every option reachable.
	var settings_grid := _settings_page as GridContainer
	if settings_grid != null:
		var panel_width := 16.0
		for child in settings_grid.get_children():
			panel_width += (child as Control).get_combined_minimum_size().x
		settings_grid.columns = 1 if panel_width > _card.custom_minimum_size.x - 72.0 else 2
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
	var panel_style := _card.get_theme_stylebox("panel")
	var frame_height := panel_style.get_minimum_size().y
	frame_height += _outer_margin.get_theme_constant("margin_top") + _outer_margin.get_theme_constant("margin_bottom")
	var vertical_safety_margin := 24.0
	var available_body_height := viewport_size.y - vertical_safety_margin - chrome_height - frame_height
	var ui_scale := float(_prefs.ui_scale) if _prefs != null else 1.0
	var body_height := maxf(0.0, minf(220.0 * ui_scale, available_body_height))
	_settings_scroll.custom_minimum_size.y = body_height
	_help_scroll.custom_minimum_size.y = body_height


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
	_settings_scroll.visible = _current_page == "settings"
	_help_scroll.visible = _current_page == "help"
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
	call_deferred("_fit_to_viewport")


func _tutorial_reset_button_visibility() -> void:
	var reset_button := find_child("TutorialResetButton", true, false) as Button
	if reset_button != null:
		reset_button.visible = _tutorial_progress != null
		reset_button.disabled = _tutorial_progress == null


func _focus_initial() -> void:
	if visible and is_instance_valid(_language_buttons.get(str(_preferences.get("locale", "en")))):
		(_language_buttons[str(_preferences.get("locale", "en"))] as Button).grab_focus()


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
	call_deferred("_fit_to_viewport")


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
		call_deferred("_fit_to_viewport")
		return
	close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built and is_instance_valid(_settings_scroll) and is_instance_valid(_help_scroll):
		_fit_to_viewport()


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
