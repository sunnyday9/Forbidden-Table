class_name RunSummaryView
extends Control

const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

var _outcome_value: Label
var _reason_value: Label
var _summary_value: Label
var _summary_scroll: ScrollContainer
var _phase_heading: Label
var _result_heading: Label
var _review_hint: Label
var _locale := "en"
var _ui_scale := 1.0


func _init() -> void:
	# Copy is already resolved through Localization; controls must not translate
	# it a second time (which also doubles pseudo-localization expansion).
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	_build_ui()


func render(run_state, formatted_summary: String, locale: String = "en", ui_scale: float = 1.0) -> void:
	_locale = locale
	_ui_scale = ui_scale
	_build_ui()
	theme = ForbiddenThemeScript.create_theme(locale, ui_scale)
	var outcome := str(run_state.terminal_summary.outcome) if run_state != null and run_state.terminal_summary != null else ""
	var reason := str(run_state.terminal_summary.reason) if run_state != null and run_state.terminal_summary != null else ""
	_outcome_value.text = _pretty_id(outcome)
	_reason_value.text = _pretty_id(reason) if not reason.is_empty() else LocalizationCatalogScript.text("UI_RUN_SCENE_0148")
	_summary_value.text = formatted_summary if not formatted_summary.is_empty() else LocalizationCatalogScript.text("UI_RUN_SUMMARY_0001")
	_summary_scroll.scroll_vertical = 0
	_phase_heading.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0007")
	_result_heading.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0026")
	_review_hint.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0120")
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
	var columns := HBoxContainer.new()
	columns.name = "RunSummaryColumns"
	columns.add_theme_constant_override("separation", 16)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(columns)

	var chronicle := PanelContainer.new()
	chronicle.name = "BuildChroniclePanel"
	chronicle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chronicle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ForbiddenThemeScript.style_panel(chronicle, "chronicle")
	columns.add_child(chronicle)
	var chronicle_layout := VBoxContainer.new()
	chronicle_layout.add_theme_constant_override("separation", 8)
	chronicle.add_child(chronicle_layout)
	_phase_heading = Label.new()
	_phase_heading.name = "BuildStoryHeading"
	_phase_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_heading.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0007")
	ForbiddenThemeScript.title(_phase_heading, _locale)
	chronicle_layout.add_child(_phase_heading)
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

	var result_panel := PanelContainer.new()
	result_panel.name = "RunOutcomePanel"
	result_panel.custom_minimum_size.x = 260.0
	result_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ForbiddenThemeScript.style_panel(result_panel, "lacquer", true)
	columns.add_child(result_panel)
	var result_scroll := ScrollContainer.new()
	result_scroll.name = "RunOutcomeScroll"
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	result_scroll.follow_focus = true
	result_scroll.focus_mode = Control.FOCUS_ALL
	result_panel.add_child(result_scroll)
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
	_review_hint = Label.new()
	_review_hint.name = "BuildStoryHint"
	_review_hint.text = LocalizationCatalogScript.text("UI_RUN_SCENE_0120")
	_review_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_layout.add_child(_review_hint)


func _pretty_id(identifier: String) -> String:
	if identifier.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_SCENE_0148")
	if "." in identifier and str(TranslationServer.translate(identifier)) != identifier:
		return LocalizationCatalogScript.content_text(identifier)
	return LocalizationCatalogScript.word_text(identifier)
