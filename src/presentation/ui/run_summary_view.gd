class_name RunSummaryView
extends Control

const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const WIDE_LAYOUT_MIN_WIDTH := 720.0
const MAX_SUMMARY_BODY_WIDTH := 1440.0

var _outcome_value: Label
var _reason_value: Label
var _summary_value: Label
var _summary_scroll: ScrollContainer
var _layout_scroll: ScrollContainer
var _content_center: CenterContainer
var _columns: GridContainer
var _chronicle_panel: PanelContainer
var _result_panel: PanelContainer
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
	var outcome := str(run_state.terminal_summary.outcome) if run_state != null and run_state.terminal_summary != null else ""
	var reason := str(run_state.terminal_summary.reason) if run_state != null and run_state.terminal_summary != null else ""
	_outcome_value.text = _pretty_id(outcome)
	_reason_value.text = _pretty_id(reason) if not reason.is_empty() else LocalizationCatalogScript.text("UI_RUN_SCENE_0148")
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
	_content_center = CenterContainer.new()
	_content_center.name = "RunSummaryCenter"
	_content_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout_scroll.add_child(_content_center)

	_columns = GridContainer.new()
	_columns.name = "RunSummaryColumns"
	_columns.columns = 2
	_columns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("h_separation", 16)
	_columns.add_theme_constant_override("v_separation", 16)
	_content_center.add_child(_columns)

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
	ForbiddenThemeScript.title(_chronicle_heading, _locale)
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
	result_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_layout.add_theme_constant_override("separation", 10)
	result_scroll.add_child(result_layout)
	_result_heading = Label.new()
	_result_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_heading.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0026")
	_result_heading.add_theme_font_size_override("font_size", roundi(18.0 * _ui_scale))
	result_layout.add_child(_result_heading)
	_outcome_value = Label.new()
	_outcome_value.name = "RunOutcomeValue"
	_outcome_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome_value.add_theme_font_size_override("font_size", roundi(24.0 * _ui_scale))
	result_layout.add_child(_outcome_value)
	_reason_value = Label.new()
	_reason_value.name = "RunReasonValue"
	_reason_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_layout.add_child(_reason_value)

	_update_responsive_layout()


func _update_responsive_layout() -> void:
	if _columns == null or _layout_scroll == null:
		return
	var compact := size.x < WIDE_LAYOUT_MIN_WIDTH * _ui_scale
	_columns.columns = 1 if compact else 2
	_layout_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if compact else ScrollContainer.SCROLL_MODE_DISABLED
	var scrollbar_width := _layout_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var available_width := maxf(0.0, size.x - 32.0 - scrollbar_width)
	_columns.custom_minimum_size.x = minf(MAX_SUMMARY_BODY_WIDTH, available_width)
	_chronicle_panel.custom_minimum_size.y = 248.0 * _ui_scale if compact else 0.0
	_result_panel.custom_minimum_size.y = 200.0 * _ui_scale if compact else 0.0


func _pretty_id(identifier: String) -> String:
	if identifier.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_SCENE_0148")
	if "." in identifier and str(TranslationServer.translate(identifier)) != identifier:
		return LocalizationCatalogScript.content_text(identifier)
	return LocalizationCatalogScript.word_text(identifier)
