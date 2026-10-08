class_name RunSummaryView
extends Control

const PlayerActionTextScript = preload("res://src/presentation/ui/player_action_text.gd")
const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const WIDE_LAYOUT_MIN_WIDTH := 720.0
const MAX_SUMMARY_BODY_WIDTH := 1440.0

var _outcome_value: Label
var _lesson_value: Label
var _defeat_stats_value: Label
var _reason_value: Label
var _summary_value: Label
var _summary_scroll: ScrollContainer
var _layout_scroll: ScrollContainer
var _content_margin: MarginContainer
var _content_center: HBoxContainer
var _columns: GridContainer
var _chronicle_panel: PanelContainer
var _result_panel: PanelContainer
var _result_content: VBoxContainer
var _chronicle_heading: Label
var _result_heading: Label
var _locale := "en"
var _ui_scale := 1.0


func _init() -> void:
	# Copy is already resolved through Localization; controls must not translate
	# it a second time (which also doubles pseudo-localization expansion).
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	_build_ui()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()


func render(run_state, formatted_summary: String, locale: String = "en", ui_scale: float = 1.0) -> void:
	_locale = locale
	_ui_scale = ui_scale
	_build_ui()
	_update_responsive_layout()
	theme = ForbiddenThemeScript.create_theme(locale, ui_scale)
	ForbiddenThemeScript.heading(_chronicle_heading, locale)
	ForbiddenThemeScript.heading(_result_heading, locale)
	ForbiddenThemeScript.title(_outcome_value, locale)
	var outcome := str(run_state.terminal_summary.outcome) if run_state != null and run_state.terminal_summary != null else ""
	var reason := str(run_state.terminal_summary.reason) if run_state != null and run_state.terminal_summary != null else ""
	_outcome_value.text = _pretty_id(outcome)
	_reason_value.text = _pretty_id(reason) if not reason.is_empty() else LocalizationCatalogScript.text("UI_RUN_SCENE_0148")
	var defeat_lesson := PlayerActionTextScript.defeat_text(run_state.terminal_summary.summary_data) if run_state != null and run_state.terminal_summary != null else ""
	if not defeat_lesson.is_empty():
		_reason_value.text = LocalizationCatalogScript.text("UI_PLAYER_DEFEAT_GENERIC")
	_defeat_stats_value.visible = not defeat_lesson.is_empty() and run_state.terminal_summary.summary_data.has("defeat_context")
	_defeat_stats_value.text = PlayerActionTextScript.defeat_cause_text(run_state.terminal_summary.summary_data) if _defeat_stats_value.visible else ""
	_lesson_value.visible = not defeat_lesson.is_empty()
	_lesson_value.text = LocalizationCatalogScript.text("UI_PLAYER_DEFEAT_LESSON") if _lesson_value.visible else ""
	for detail_label in [_defeat_stats_value, _lesson_value]:
		detail_label.add_theme_font_size_override("font_size", ForbiddenThemeScript.font_size_for("secondary", ui_scale))
	_summary_value.text = formatted_summary if not formatted_summary.is_empty() else LocalizationCatalogScript.text("UI_RUN_SUMMARY_0001")
	_summary_scroll.scroll_vertical = 0
	_chronicle_heading.text = LocalizationCatalogScript.text("UI_RUN_SUMMARY_0006")
	_result_heading.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0026")
	var successful := outcome == "VICTORY"
	_outcome_value.add_theme_color_override("font_color", ForbiddenThemeScript.color("success") if successful else ForbiddenThemeScript.color("error"))


func summary_label() -> Label:
	return _summary_value


func summary_scroll() -> ScrollContainer:
	return _summary_scroll


func _build_ui() -> void:
	if _outcome_value != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout_scroll = ScrollContainer.new()
	_layout_scroll.name = "RunSummaryLayoutScroll"
	_layout_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_layout_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_layout_scroll.follow_focus = true
	_layout_scroll.focus_mode = Control.FOCUS_ALL
	add_child(_layout_scroll)
	_content_margin = MarginContainer.new()
	_content_margin.name = "RunSummaryContentMargin"
	_content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_margin.add_theme_constant_override("margin_left", 8)
	_content_margin.add_theme_constant_override("margin_top", 8)
	_content_margin.add_theme_constant_override("margin_right", 8)
	_content_margin.add_theme_constant_override("margin_bottom", 8)
	_layout_scroll.add_child(_content_margin)
	_content_center = HBoxContainer.new()
	_content_center.name = "RunSummaryCenter"
	_content_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_center.add_theme_constant_override("separation", 0)
	_content_margin.add_child(_content_center)
	var left_width_spacer := Control.new()
	left_width_spacer.name = "RunSummaryLeftWidthSpacer"
	left_width_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_width_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_center.add_child(left_width_spacer)

	_columns = GridContainer.new()
	_columns.name = "RunSummaryColumns"
	_columns.columns = 2
	_columns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("h_separation", 16)
	_columns.add_theme_constant_override("v_separation", 16)
	_content_center.add_child(_columns)
	var right_width_spacer := Control.new()
	right_width_spacer.name = "RunSummaryRightWidthSpacer"
	right_width_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_width_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_center.add_child(right_width_spacer)

	_chronicle_panel = PanelContainer.new()
	_chronicle_panel.name = "BuildChroniclePanel"
	_chronicle_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chronicle_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ForbiddenThemeScript.style_panel(_chronicle_panel, "chronicle")
	_columns.add_child(_chronicle_panel)
	var chronicle_layout := VBoxContainer.new()
	chronicle_layout.add_theme_constant_override("separation", 8)
	_chronicle_panel.add_child(chronicle_layout)
	_chronicle_heading = Label.new()
	_chronicle_heading.name = "BuildChronicleHeading"
	_chronicle_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chronicle_heading.text = LocalizationCatalogScript.text("UI_RUN_SUMMARY_0006")
	ForbiddenThemeScript.heading(_chronicle_heading, _locale)
	chronicle_layout.add_child(_chronicle_heading)
	_summary_scroll = ScrollContainer.new()
	_summary_scroll.name = "RunSummaryScroll"
	_summary_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_summary_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_summary_scroll.follow_focus = true
	_summary_scroll.focus_mode = Control.FOCUS_ALL
	chronicle_layout.add_child(_summary_scroll)
	_summary_value = Label.new()
	_summary_value.name = "RunSummaryText"
	_summary_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_scroll.add_child(_summary_value)

	_result_panel = PanelContainer.new()
	_result_panel.name = "RunOutcomePanel"
	_result_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ForbiddenThemeScript.style_panel(_result_panel, "lacquer", true)
	_columns.add_child(_result_panel)
	var result_scroll := ScrollContainer.new()
	result_scroll.name = "RunOutcomeScroll"
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	result_scroll.follow_focus = true
	result_scroll.focus_mode = Control.FOCUS_ALL
	_result_panel.add_child(result_scroll)
	var result_layout := VBoxContainer.new()
	_result_content = result_layout
	result_layout.minimum_size_changed.connect(_update_responsive_layout)
	result_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_layout.add_theme_constant_override("separation", 10)
	result_scroll.add_child(result_layout)
	_result_heading = Label.new()
	_result_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_heading.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0026")
	ForbiddenThemeScript.heading(_result_heading, _locale)
	result_layout.add_child(_result_heading)
	_outcome_value = Label.new()
	_outcome_value.name = "RunOutcomeValue"
	_outcome_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ForbiddenThemeScript.title(_outcome_value, _locale)
	result_layout.add_child(_outcome_value)
	_reason_value = Label.new()
	_reason_value.name = "RunReasonValue"
	_reason_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_layout.add_child(_reason_value)
	_defeat_stats_value = Label.new()
	_defeat_stats_value.name = "DefeatStats"
	_defeat_stats_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_defeat_stats_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_layout.add_child(_defeat_stats_value)
	_lesson_value = Label.new()
	_lesson_value.name = "DefeatLesson"
	_lesson_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lesson_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lesson_value.add_theme_font_size_override("font_size", ForbiddenThemeScript.font_size_for("secondary", _ui_scale))
	_lesson_value.add_theme_color_override("font_color", ForbiddenThemeScript.color("muted"))
	result_layout.add_child(_lesson_value)

	_update_responsive_layout()


func _update_responsive_layout() -> void:
	if _columns == null or _layout_scroll == null:
		return
	var compact := size.x < WIDE_LAYOUT_MIN_WIDTH * _ui_scale
	_columns.columns = 1 if compact else 2
	# A wide viewport can still be short at large UI scales. Let the inner page
	# scroll only when its measured content exceeds the available body height.
	_layout_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var scrollbar_width := _layout_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var available_width := maxf(0.0, size.x - 32.0 - scrollbar_width)
	_columns.custom_minimum_size.x = minf(MAX_SUMMARY_BODY_WIDTH * _ui_scale, available_width)
	_chronicle_panel.custom_minimum_size.y = 280.0 * _ui_scale
	var result_content_height := _result_content.get_combined_minimum_size().y if _result_content != null else 0.0
	var result_style := _result_panel.get_theme_stylebox("panel")
	var result_insets := result_style.get_minimum_size().y if result_style != null else 0.0
	_result_panel.custom_minimum_size.y = maxf(220.0 * _ui_scale, result_content_height + result_insets)


func _pretty_id(identifier: String) -> String:
	if identifier.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_SCENE_0148")
	if "." in identifier and str(TranslationServer.translate(identifier)) != identifier:
		return LocalizationCatalogScript.content_text(identifier)
	return LocalizationCatalogScript.word_text(identifier)
