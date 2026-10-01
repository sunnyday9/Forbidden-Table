class_name BattleView
extends Control

signal action_requested(action_id: String)
signal focus_requested(action_id: String)

const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const TileFaceButtonScript = preload("res://src/presentation/ui/tile_face_button.gd")
const TableBackdropScript = preload("res://src/presentation/ui/table_backdrop.gd")
const MotionFeedbackScript = preload("res://src/presentation/ui/motion_feedback.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")

const INTENT_LABEL_KEYS := {
	"PRESSURE": "WORD_PRESSURE",
	"WALL_TAX": "UI_BATTLE_VIEW_0036",
	"INTEGRITY": "UI_BATTLE_VIEW_0037",
	"CONTAMINATION": "UI_BATTLE_VIEW_0038",
	"TABLE_INTERFERENCE": "UI_BATTLE_VIEW_0039",
	"RULE_BREAKER": "UI_BATTLE_VIEW_0040",
	"AUDIT": "UI_BATTLE_VIEW_0041",
	"HUNT": "UI_BATTLE_VIEW_0042",
	"REWARD_TAX": "UI_BATTLE_VIEW_0043",
}
const INTENT_EFFECT_KEYS := {
	"WALL_TAX": "UI_BATTLE_VIEW_0049",
	"INTEGRITY": "UI_BATTLE_VIEW_0050",
	"HUNT": "UI_BATTLE_VIEW_0051",
	"CONTAMINATION": "UI_BATTLE_VIEW_0052",
	"TABLE_INTERFERENCE": "UI_BATTLE_VIEW_0053",
	"RULE_BREAKER": "UI_BATTLE_VIEW_0054",
	"AUDIT": "UI_BATTLE_VIEW_0055",
	"REWARD_TAX": "UI_BATTLE_VIEW_0056",
}

var selected_action_id := ""
var focused_action_id := ""

var _controller
var _action_label: Callable
var _action_tooltip: Callable
var _action_details: Callable
var _actions: Array = []
var _actions_by_id: Dictionary = {}
var _tiles_by_id: Dictionary = {}
var _locale := "en"
var _ui_scale := 1.0
var _presentation_mode := "NORMAL"
var _reduced_motion := false
var _ambient_glow := false
var _external_preferences_owner := false
var _last_encounter_id := ""
var _last_receipt_text := ""
var _receipt_cues: Array[Dictionary] = []
var _last_receipt_fingerprint := ""
var _last_boss_phase_index := -1
var _last_boss_phase_count := 0
var _last_hand_ids: Array[String] = []
var _suppress_hand_feedback := false
var _focused_tile_instance_id := ""
var _has_cosmetic_motion := false
var _focus_revision := 0
var _render_generation := 0

var _backdrop: TableBackdrop
var _motion_feedback: MotionFeedback
var _shell: VBoxContainer
var _decision_row: HBoxContainer
var _board_scroll: ScrollContainer
var _board_body: VBoxContainer
var _actions_body: VBoxContainer
var _action_panel: PanelContainer
var _action_scroll_list: VBoxContainer
var _inspection_value: Label
var _receipt_value: Label
var _commit_button: Button
var _commit_summary: Label


func _init() -> void:
	# Copy is already resolved through Localization; controls must not translate
	# it a second time (which also doubles pseudo-localization expansion).
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	_build_shell()
	_connect_preferences()
	_apply_theme()
	_refresh_backdrop()
	if _controller != null and not _external_preferences_owner:
		render()


func configure(controller, action_label: Callable, tooltip: Callable, details: Callable) -> void:
	_controller = controller
	_action_label = action_label
	_action_tooltip = tooltip
	_action_details = details
	_build_shell()


func set_presentation_preferences(
	locale: String = "en",
	ui_scale: float = 1.0,
	presentation_mode: String = "NORMAL",
	reduced_motion: bool = false,
	ambient_glow: bool = false,
) -> bool:
	var normalized_locale := "zh_CN" if locale.to_lower().begins_with("zh") else "en"
	var normalized_scale := clampf(ui_scale, 1.0, 1.5)
	var normalized_mode := presentation_mode.to_upper()
	if normalized_mode not in ["NORMAL", "FAST", "INSTANT"]:
		normalized_mode = "NORMAL"
	var changed := (
		normalized_locale != _locale
		or not is_equal_approx(normalized_scale, _ui_scale)
		or normalized_mode != _presentation_mode
		or reduced_motion != _reduced_motion
		or ambient_glow != _ambient_glow
	)
	if not changed:
		return false
	var mode_changed := _presentation_mode != normalized_mode or _reduced_motion != reduced_motion
	_locale = normalized_locale
	_ui_scale = normalized_scale
	_presentation_mode = normalized_mode
	_reduced_motion = reduced_motion
	_ambient_glow = ambient_glow
	_apply_theme()
	if _motion_feedback != null:
		_motion_feedback.configure(_presentation_mode, _reduced_motion)
		if mode_changed:
			_has_cosmetic_motion = false
	_refresh_backdrop()
	return true


func render() -> void:
	_render_generation += 1
	_build_shell()
	if _controller == null or not is_instance_valid(_controller) or not _controller.has_method("action_descriptors"):
		_actions = []
		_actions_by_id.clear()
		selected_action_id = ""
		focused_action_id = ""
		_clear_children(_board_body)
		_clear_children(_action_scroll_list)
		_commit_summary.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0022")
		_commit_button.disabled = true
		return

	var had_focus := false
	var focus_owner := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	var old_focus_id := str(focus_owner.get_meta("run_action_id", "")) if focus_owner is Control else ""
	var old_focus_tile_id := str(focus_owner.get_meta("tile_instance_id", "")) if focus_owner is Control else ""
	if focus_owner is Control:
		had_focus = is_ancestor_of(focus_owner)

	var prior_encounter := _last_encounter_id
	var battle = _current_battle()
	var encounter_id := str(battle.encounter_id) if battle != null else ""
	_suppress_hand_feedback = not encounter_id.is_empty() and encounter_id != prior_encounter
	if _suppress_hand_feedback and not prior_encounter.is_empty():
		_cancel_motion()
		selected_action_id = ""
		_focused_tile_instance_id = ""
		_receipt_cues.clear()
		_last_receipt_fingerprint = ""
		_last_receipt_text = ""
		_last_boss_phase_index = -1
		_last_boss_phase_count = 0
	if not encounter_id.is_empty():
		_last_encounter_id = encounter_id

	_actions = _controller.action_descriptors()
	_actions_by_id.clear()
	for action in _actions:
		if action is Dictionary:
			var action_id := str(action.get("id", ""))
			if not action_id.is_empty():
				_actions_by_id[action_id] = action
	if not _actions_by_id.has(selected_action_id):
		selected_action_id = ""
	if _actions_by_id.has(old_focus_id):
		focused_action_id = old_focus_id
	if not _actions_by_id.has(focused_action_id):
		var snapshot: Dictionary = _controller.snapshot() if _controller.has_method("snapshot") else {}
		focused_action_id = str(snapshot.get("focused_action_id", ""))
	if not _actions_by_id.has(focused_action_id) and not _actions.is_empty():
		focused_action_id = str(_actions[0].get("id", ""))

	_rebuild_board(battle)
	_rebuild_action_panel(battle)
	_update_receipt(battle)
	_update_commit_rail()
	_update_inspection()
	var restored_focus := _restore_action_focus(old_focus_id, old_focus_tile_id, had_focus)
	if restored_focus != null:
		_queue_current_focus_visibility()


func cancel() -> bool:
	_focus_revision += 1
	_cancel_motion()
	if not selected_action_id.is_empty():
		var previous := selected_action_id
		selected_action_id = ""
		_focused_tile_instance_id = ""
		_update_action_styles()
		_update_commit_rail()
		_update_inspection()
		var previous_button := action_button(previous)
		if previous_button != null and previous_button.is_inside_tree():
			previous_button.grab_focus()
		return true
	if _has_cosmetic_motion:
		return true
	return false


func action_button(action_id: String) -> Button:
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if str(button.get_meta("run_action_id", "")) == action_id:
			return button
	return null


func commit_button() -> Button:
	return _commit_button


func inspection_label() -> Label:
	return _inspection_value


func motion_feedback() -> MotionFeedback:
	return _motion_feedback


func sync_persistent_receipt() -> String:
	_update_receipt(_current_battle())
	return _last_receipt_text


func persistent_receipt_text() -> String:
	return _localized_receipt_text()


func set_external_preferences_owner(external_owner: bool = true) -> void:
	_external_preferences_owner = external_owner


func _build_shell() -> void:
	if _shell != null:
		return
	_motion_feedback = MotionFeedbackScript.new()
	_motion_feedback.name = "MotionFeedback"
	_motion_feedback.playback_finished.connect(_on_motion_finished)
	add_child(_motion_feedback)

	_backdrop = TableBackdropScript.new()
	_backdrop.name = "TableBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	move_child(_backdrop, 0)

	var margin := MarginContainer.new()
	margin.name = "BattleViewMargins"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)

	_shell = VBoxContainer.new()
	_shell.name = "BattleViewShell"
	_shell.add_theme_constant_override("separation", 2)
	_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_shell)

	_receipt_value = Label.new()
	_receipt_value.name = "BattleCriticalReceipt"
	_receipt_value.visible = false
	_receipt_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_receipt_value.add_theme_color_override("font_color", ForbiddenThemeScript.color("success"))
	_apply_secondary_label(_receipt_value, true)
	_shell.add_child(_receipt_value)

	_decision_row = HBoxContainer.new()
	_decision_row.name = "BattleDecisionSurface"
	_decision_row.add_theme_constant_override("separation", 6)
	_decision_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decision_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.add_child(_decision_row)

	var board_panel := PanelContainer.new()
	board_panel.name = "BattleTable"
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.custom_minimum_size.x = 500.0
	_style_compact_panel(board_panel, "table")
	_decision_row.add_child(board_panel)
	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 0)
	board_margin.add_theme_constant_override("margin_top", 0)
	board_margin.add_theme_constant_override("margin_right", 0)
	board_margin.add_theme_constant_override("margin_bottom", 0)
	board_panel.add_child(board_margin)
	_board_scroll = ScrollContainer.new()
	_board_scroll.name = "BattleTableScroll"
	_board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_board_scroll.follow_focus = true
	_board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_scroll.custom_minimum_size.y = 0.0
	board_margin.add_child(_board_scroll)
	_board_body = VBoxContainer.new()
	_board_body.name = "BattleTableContent"
	_board_body.add_theme_constant_override("separation", 4)
	_board_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_body.custom_minimum_size.y = 0.0
	_board_scroll.add_child(_board_body)

	_action_panel = PanelContainer.new()
	_action_panel.name = "BattleActions"
	_action_panel.custom_minimum_size.x = 280.0
	_action_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_action_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_compact_panel(_action_panel, "lacquer")
	_decision_row.add_child(_action_panel)
	var action_margin := MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 0)
	action_margin.add_theme_constant_override("margin_top", 0)
	action_margin.add_theme_constant_override("margin_right", 0)
	action_margin.add_theme_constant_override("margin_bottom", 0)
	action_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_panel.add_child(action_margin)
	_actions_body = VBoxContainer.new()
	_actions_body.name = "BattleActionsContent"
	_actions_body.add_theme_constant_override("separation", 6)
	_actions_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_margin.add_child(_actions_body)

	var action_heading := Label.new()
	action_heading.name = "BattleActionsHeading"
	action_heading.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0012")
	_apply_body_label(action_heading, true)
	_actions_body.add_child(action_heading)

	var choice_scroll := ScrollContainer.new()
	choice_scroll.name = "BattleChoiceScroll"
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	choice_scroll.follow_focus = true
	choice_scroll.focus_mode = Control.FOCUS_ALL
	choice_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_actions_body.add_child(choice_scroll)
	_action_scroll_list = VBoxContainer.new()
	_action_scroll_list.name = "BattleChoices"
	_action_scroll_list.add_theme_constant_override("separation", 6)
	_action_scroll_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_scroll_list.custom_minimum_size.x = 0.0
	choice_scroll.add_child(_action_scroll_list)

	var inspector_panel := PanelContainer.new()
	inspector_panel.name = "BattleInspection"
	_style_compact_panel(inspector_panel, "paper")
	_actions_body.add_child(inspector_panel)
	var inspector_margin := MarginContainer.new()
	inspector_margin.add_theme_constant_override("margin_left", 4)
	inspector_margin.add_theme_constant_override("margin_top", 3)
	inspector_margin.add_theme_constant_override("margin_right", 4)
	inspector_margin.add_theme_constant_override("margin_bottom", 3)
	inspector_panel.add_child(inspector_margin)
	var inspector_stack := VBoxContainer.new()
	inspector_stack.add_theme_constant_override("separation", 3)
	inspector_margin.add_child(inspector_stack)
	var inspector_heading := Label.new()
	inspector_heading.name = "BattleInspectionHeading"
	inspector_heading.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0017")
	_apply_secondary_label(inspector_heading)
	inspector_stack.add_child(inspector_heading)
	_inspection_value = Label.new()
	_inspection_value.name = "BattleInspectionValue"
	_inspection_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspection_value.clip_text = false
	_inspection_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inspection_scroll := ScrollContainer.new()
	inspection_scroll.name = "BattleInspectionScroll"
	inspection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inspection_scroll.custom_minimum_size.y = 32.0 * _ui_scale
	inspection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspection_scroll.add_child(_inspection_value)
	inspector_stack.add_child(inspection_scroll)

	var commit_panel := PanelContainer.new()
	commit_panel.name = "BattleCommitRail"
	commit_panel.custom_minimum_size.y = 48.0
	_style_compact_panel(commit_panel, "lacquer", true)
	_shell.add_child(commit_panel)
	var commit_margin := MarginContainer.new()
	commit_margin.add_theme_constant_override("margin_left", 6)
	commit_margin.add_theme_constant_override("margin_top", 0)
	commit_margin.add_theme_constant_override("margin_right", 6)
	commit_margin.add_theme_constant_override("margin_bottom", 0)
	commit_panel.add_child(commit_margin)
	var commit_row := HBoxContainer.new()
	commit_row.add_theme_constant_override("separation", 10)
	commit_margin.add_child(commit_row)
	_commit_summary = Label.new()
	_commit_summary.name = "BattleCommitSummary"
	_commit_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_commit_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commit_row.add_child(_commit_summary)
	_commit_button = Button.new()
	_commit_button.name = "CommitSelectedButton"
	_commit_button.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0023")
	_commit_button.custom_minimum_size = Vector2(190.0, 44.0)
	_commit_button.disabled = true
	_commit_button.set_meta("run_commit_action_id", "")
	_commit_button.set_meta("run_choice_button", false)
	ForbiddenThemeScript.style_button(_commit_button, true)
	_compact_commit_button()
	_commit_button.pressed.connect(_on_commit_pressed)
	commit_row.add_child(_commit_button)

	_commit_button.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0023")
	_update_inspection()
	_update_commit_rail()


func _connect_preferences() -> void:
	if _external_preferences_owner:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var preferences := tree.root.get_node_or_null("PresentationPrefs")
	if preferences == null:
		return
	if not preferences.preferences_changed.is_connected(_on_preferences_changed):
		preferences.preferences_changed.connect(_on_preferences_changed)
	var values: Dictionary = preferences.snapshot() if preferences.has_method("snapshot") else {}
	if not values.is_empty():
		set_presentation_preferences(
			str(values.get("locale", "en")),
			float(values.get("ui_scale", 1.0)),
			str(values.get("presentation_mode", "NORMAL")),
			bool(values.get("reduced_motion", false)),
			bool(values.get("ambient_glow", false)),
		)


func _apply_theme() -> void:
	theme = ForbiddenThemeScript.create_theme(_locale, _ui_scale)
	if _action_panel != null:
		_action_panel.custom_minimum_size.x = 280.0
	if _commit_button != null:
		ForbiddenThemeScript.style_button(_commit_button, true, not selected_action_id.is_empty())
		_compact_commit_button()
		_commit_button.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0023")


func _refresh_backdrop() -> void:
	if _backdrop != null:
		_backdrop.configure(_presentation_mode, _reduced_motion, _ambient_glow)


func _rebuild_board(battle) -> void:
	_clear_children(_board_body)
	_tiles_by_id.clear()
	if battle == null or battle.combat_state == null or battle.zones == null:
		_add_empty_message(_board_body, LocalizationCatalogScript.text("UI_BATTLE_VIEW_0022"))
		_last_hand_ids.clear()
		return
	var combat = battle.combat_state
	var state = _controller.domain.state

	_add_enemy_banner(_board_body, battle, combat)
	_add_resource_rail(_board_body, battle, combat, state)
	_add_hand_tray(_board_body, battle)


func _rebuild_action_panel(battle) -> void:
	_clear_children(_action_scroll_list)
	var draw_actions: Array = _actions.filter(func(action): return str(action.get("kind", "")) == "DRAW")
	var end_turn_actions: Array = _actions.filter(func(action): return str(action.get("kind", "")) == "END_TURN")
	_add_section(_action_scroll_list, "WORD_DRAW", draw_actions, "UI_BATTLE_VIEW_0022", "plain")
	_add_section(_action_scroll_list, "WORD_END_TURN", end_turn_actions, "UI_BATTLE_VIEW_0022", "plain")

	var settlement_actions := _actions_for_kind("PARTIAL_SETTLEMENT")
	_add_section(_action_scroll_list, "UI_BATTLE_VIEW_0013", settlement_actions, "UI_BATTLE_VIEW_0018", "patterns")
	var complete_actions := _actions_for_kind("COMPLETE_HAND")
	_add_section(_action_scroll_list, "UI_BATTLE_VIEW_0014", complete_actions, "UI_BATTLE_VIEW_0019", "complete")
	var reserve_actions := _actions_for_kind("RESERVE")
	var discard_actions := _actions_for_kind("DISCARD")
	var swap_actions := _actions_for_kind("RESERVE_SWAP")
	var tile_actions := VBoxContainer.new()
	tile_actions.name = "BattleTileActions"
	tile_actions.add_theme_constant_override("separation", 4)
	_action_scroll_list.add_child(tile_actions)
	var tile_heading := Label.new()
	tile_heading.name = "TileActionsHeading"
	tile_heading.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0015")
	_apply_body_label(tile_heading, true)
	tile_actions.add_child(tile_heading)
	_add_section(tile_actions, "WORD_RESERVE", reserve_actions, "UI_BATTLE_VIEW_0020", "tile")
	_add_section(tile_actions, "WORD_DISCARD", discard_actions, "UI_BATTLE_VIEW_0020", "tile")
	_add_section(tile_actions, "WORD_RESERVE_SWAP", swap_actions, "UI_BATTLE_VIEW_0020", "swap")
	var technique_actions := _actions_for_kind("TECHNIQUE")
	_add_section(_action_scroll_list, "UI_BATTLE_VIEW_0016", technique_actions, "UI_BATTLE_VIEW_0021", "plain")
	if battle != null and battle.zones != null:
		_add_known_zones(_action_scroll_list, battle)
	if settlement_actions.is_empty() and complete_actions.is_empty() and reserve_actions.is_empty() and discard_actions.is_empty() and swap_actions.is_empty() and technique_actions.is_empty():
		_add_empty_message(_action_scroll_list, LocalizationCatalogScript.text("UI_BATTLE_VIEW_0022"))

	_update_action_styles()


func _add_enemy_banner(parent: Control, battle, combat) -> void:
	var banner := PanelContainer.new()
	banner.name = "BattleEnemyIntentBanner"
	_style_compact_panel(banner, "enemy")
	parent.add_child(banner)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	banner.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(identity)
	var enemy_id := str(battle.enemy_definition.content_id) if battle.enemy_definition != null else ""
	if enemy_id.is_empty() and not battle.enemy_definition_ids().is_empty():
		enemy_id = str(battle.enemy_definition_ids()[0])
	var enemy_name := LocalizationCatalogScript.content_text(enemy_id) if not enemy_id.is_empty() else LocalizationCatalogScript.text("WORD_BATTLE")
	var hp_label := Label.new()
	hp_label.name = "BattleEnemyHP"
	hp_label.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0003", [enemy_name, combat.enemy_hp, combat.enemy_max_hp])
	hp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_secondary_label(hp_label, true)
	identity.add_child(hp_label)
	var intent_column := VBoxContainer.new()
	intent_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(intent_column)
	var intent_name := _intent_label(combat.current_intent)
	var intent_label := Label.new()
	intent_label.name = "BattleIntentType"
	var intent_display_name := LocalizationCatalogScript.display_text(str(combat.current_intent.display_name)) if combat.current_intent != null else ""
	if intent_display_name.is_empty():
		intent_display_name = LocalizationCatalogScript.word_text("UNAVAILABLE")
	intent_label.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0048", [intent_display_name, intent_name])
	intent_label.add_theme_color_override("font_color", ForbiddenThemeScript.color("brass"))
	_apply_secondary_label(intent_label)
	intent_column.add_child(intent_label)
	if combat.current_intent != null:
		var intent_detail := Label.new()
		intent_detail.name = "BattleIntentDetail"
		intent_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var action_type := str(combat.current_intent.action_type).to_upper()
		if action_type == "PRESSURE":
			intent_detail.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0005", [combat.current_intent.pressure_amount])
		else:
			var effect_key := str(INTENT_EFFECT_KEYS.get(action_type, ""))
			intent_detail.text = LocalizationCatalogScript.format(effect_key, [combat.current_intent.pressure_amount]) if not effect_key.is_empty() else LocalizationCatalogScript.word_text("UNAVAILABLE")
		intent_detail.add_theme_font_size_override("font_size", roundi(13.0 * _ui_scale))
		intent_detail.add_theme_color_override("font_color", ForbiddenThemeScript.color("muted"))
		intent_column.add_child(intent_detail)


func _add_resource_rail(parent: Control, battle, combat, run_state) -> void:
	var panel := PanelContainer.new()
	panel.name = "BattleResources"
	_style_compact_panel(panel, "lacquer")
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	panel.add_child(stack)
	var rail := HFlowContainer.new()
	rail.name = "BattleResourceValues"
	rail.add_theme_constant_override("h_separation", 8)
	rail.add_theme_constant_override("v_separation", 3)
	stack.add_child(rail)
	var turn_status := Label.new()
	turn_status.name = "BattleTurnStatus"
	turn_status.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0001")
	turn_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_apply_secondary_label(turn_status, true)
	rail.add_child(turn_status)
	_add_metric(rail, LocalizationCatalogScript.word_text("PRESSURE"), combat.pressure, combat.pressure_limit, true)
	_add_metric(rail, LocalizationCatalogScript.word_text("TP"), combat.tp)
	_add_metric(rail, LocalizationCatalogScript.text("UI_BATTLE_VIEW_0032"), combat.stability)
	_add_metric(rail, LocalizationCatalogScript.text("UI_BATTLE_VIEW_0030"), battle.draw_wall.size())
	_add_metric(rail, LocalizationCatalogScript.word_text("RESERVE"), battle.zones.size(TileZoneScript.RESERVE), combat.reserve_capacity, true)
	_add_metric_text(rail, LocalizationCatalogScript.format("UI_BATTLE_VIEW_0006", [LocalizationCatalogScript.word_text("YAKU"), _total_yaku_count(run_state)]))
	if combat.boss_phase_index >= 0 and combat.boss_phase_count > 0:
		_add_metric_text(rail, LocalizationCatalogScript.format("UI_BATTLE_VIEW_0007", [LocalizationCatalogScript.text("UI_BATTLE_VIEW_0035"), combat.boss_phase_index + 1, combat.boss_phase_count]))
	var recovery: Dictionary = battle.recovery_state.to_dictionary() if battle.recovery_state != null else {}
	var hand_count: int = battle.zones.size(TileZoneScript.HAND)
	var recovery_text := LocalizationCatalogScript.format("UI_BATTLE_VIEW_0008", [
		int(recovery.get("turns_elapsed", 0)) + 1,
		int(recovery.get("minimum_recovery_turns", 0)),
		hand_count,
		int(recovery.get("normal_hand_baseline", hand_count)),
	]) if bool(recovery.get("active", false)) else LocalizationCatalogScript.text("UI_BATTLE_VIEW_0009")
	var recovery_label := Label.new()
	recovery_label.name = "BattleRecoveryStatus"
	recovery_label.text = recovery_text
	recovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_secondary_label(recovery_label)
	recovery_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(recovery_label)


func _add_known_zones(parent: Control, battle) -> void:
	var zones := VBoxContainer.new()
	zones.name = "BattleZones"
	zones.add_theme_constant_override("separation", 4)
	parent.add_child(zones)
	_add_zone_inspection(zones, battle, TileZoneScript.RESERVE, "WORD_RESERVE")
	_add_zone_inspection(zones, battle, TileZoneScript.DISCARD, "WORD_DISCARD")
	_add_zone_inspection(zones, battle, TileZoneScript.EXHAUST, "UI_BATTLE_VIEW_0044")


func _add_zone_inspection(parent: Control, battle, zone: String, heading_key: String) -> void:
	var panel := PanelContainer.new()
	panel.name = "BattleZone_%s" % zone.replace(" ", "")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_compact_panel(panel, "raised")
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	panel.add_child(stack)
	var tiles: Array = battle.zones.contents(zone)
	var heading := Label.new()
	heading.name = "ZoneHeading"
	var zone_label := LocalizationCatalogScript.text(heading_key)
	if zone == TileZoneScript.RESERVE:
		heading.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0007", [zone_label, tiles.size(), battle.combat_state.reserve_capacity])
	else:
		heading.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0006", [zone_label, tiles.size()])
	_apply_secondary_label(heading, true)
	stack.add_child(heading)
	if tiles.is_empty():
		var empty := Label.new()
		empty.name = "EmptyZone"
		empty.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0025")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_secondary_label(empty)
		stack.add_child(empty)
	else:
		var contents := HFlowContainer.new()
		contents.name = "ZoneTiles"
		contents.add_theme_constant_override("h_separation", 2)
		contents.add_theme_constant_override("v_separation", 2)
		contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(contents)
		for tile in tiles:
			_add_tile_face(contents, tile)


func _add_hand_tray(parent: Control, battle) -> void:
	var tray := PanelContainer.new()
	tray.name = "BattleHandTray"
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray.custom_minimum_size.y = 96.0
	_style_compact_panel(tray, "table")
	parent.add_child(tray)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	tray.add_child(stack)
	var hand: Array = battle.zones.contents(TileZoneScript.HAND)
	var heading := Label.new()
	heading.name = "BattleHandHeading"
	heading.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0006", [LocalizationCatalogScript.word_text("HAND"), hand.size()])
	_apply_secondary_label(heading, true)
	stack.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.name = "BattleHandScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var hand_row := HBoxContainer.new()
	hand_row.name = "BattleHandTiles"
	hand_row.add_theme_constant_override("separation", 2)
	for tile in hand:
		_add_tile_face(hand_row, tile)
	scroll.add_child(hand_row)
	if hand.is_empty():
		_add_empty_message(stack, LocalizationCatalogScript.text("UI_BATTLE_VIEW_0029"))
	var next_hand_ids := _instance_ids(hand)
	if _motion_feedback != null and not _suppress_hand_feedback and next_hand_ids.size() > _last_hand_ids.size():
		for instance_id in next_hand_ids:
			if _last_hand_ids.has(instance_id):
				continue
			var added_button := _tile_button(instance_id)
			if added_button != null:
				_play_cosmetic(added_button, ^"modulate:a", 0.78, 1.0, 0.6)
			break
	_last_hand_ids = next_hand_ids


func _update_receipt(battle) -> void:
	if _receipt_value == null:
		return
	_record_receipt_cues(battle)
	var feedback := _localized_receipt_text()
	var changed := feedback != _last_receipt_text
	_last_receipt_text = feedback
	_receipt_value.text = feedback
	_receipt_value.visible = not feedback.is_empty()
	if changed and not feedback.is_empty() and is_visible_in_tree():
		_play_cosmetic(_receipt_value, ^"modulate:a", 0.78, 1.0, 0.36)


func _record_receipt_cues(battle) -> void:
	if _controller == null or not _controller.has_method("snapshot"):
		return
	var snapshot: Dictionary = _controller.snapshot()
	var event_types: Array = snapshot.get("last_domain_event_types", [])
	var relevant_events: Array[String] = []
	for event_type in event_types:
		if str(event_type) in ["CompleteHandSettled", "BossPhaseChanged", "BattleWon"]:
			relevant_events.append(str(event_type))
	if relevant_events.is_empty():
		return
	var event_fingerprint := "%s|%d|%s" % [
		_last_encounter_id,
		hash(str(snapshot.get("authoritative_snapshot", {}))),
	",".join(PackedStringArray(relevant_events)),
	]
	if event_fingerprint == _last_receipt_fingerprint:
		return
	_last_receipt_fingerprint = event_fingerprint
	if battle != null and battle.combat_state != null:
		_last_boss_phase_index = int(battle.combat_state.boss_phase_index)
		_last_boss_phase_count = int(battle.combat_state.boss_phase_count)
	for event_type in event_types:
		match str(event_type):
			"CompleteHandSettled":
				_receipt_cues.append({"key": "UI_BATTLE_VIEW_0046", "values": []})
			"BossPhaseChanged":
				var phase_index := _last_boss_phase_index
				var phase_count := _last_boss_phase_count
				if battle != null and battle.combat_state != null:
					phase_index = int(battle.combat_state.boss_phase_index)
					phase_count = int(battle.combat_state.boss_phase_count)
				if phase_index >= 0 and phase_count > 0:
					_receipt_cues.append({
						"key": "UI_BATTLE_VIEW_0007",
						"label_key": "UI_BATTLE_VIEW_0035",
						"values": [phase_index + 1, phase_count],
					})
			"BattleWon":
				_receipt_cues.append({"key": "UI_BATTLE_VIEW_0047", "values": []})


func _localized_receipt_text() -> String:
	var cues: Array[String] = []
	for cue in _receipt_cues:
		var key := str(cue.get("key", ""))
		var values: Array = cue.get("values", []).duplicate()
		var label_key := str(cue.get("label_key", ""))
		if not label_key.is_empty():
			values.push_front(LocalizationCatalogScript.text(label_key))
		cues.append(LocalizationCatalogScript.format(key, values) if not values.is_empty() else LocalizationCatalogScript.text(key))
	return "  →  ".join(PackedStringArray(cues))


func _add_section(parent: Control, heading_key: String, actions: Array, empty_key: String, presentation: String) -> void:
	var section := VBoxContainer.new()
	section.name = "BattleSection_%s" % heading_key.replace(".", "_")
	section.add_theme_constant_override("separation", 4)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	var heading := Label.new()
	heading.name = "SectionHeading"
	heading.text = LocalizationCatalogScript.text(heading_key)
	_apply_body_label(heading, true)
	section.add_child(heading)
	if actions.is_empty():
		_add_empty_message(section, LocalizationCatalogScript.text(empty_key))
		return
	for action in actions:
		match presentation:
			"patterns": _add_pattern_choice(section, action)
			"complete": _add_complete_choice(section, action)
			"tile": _add_tile_action_choice(section, action)
			"swap": _add_swap_choice(section, action)
			_: _add_action_button(section, action, false)


func _add_pattern_choice(parent: Control, action: Dictionary) -> void:
	var card := _new_choice_card(parent, str(action.get("id", "")))
	var details: Dictionary = action.get("details", {})
	var pattern_name := _word_text_or_fallback(str(details.get("pattern_type", "PATTERN")))
	var heading := Label.new()
	heading.text = pattern_name
	_apply_secondary_label(heading, true)
	card.add_child(heading)
	_add_action_tiles(card, details.get("instance_ids", []))
	_add_action_button(card, action, false)


func _add_complete_choice(parent: Control, action: Dictionary) -> void:
	var card := _new_choice_card(parent, str(action.get("id", "")))
	var details: Dictionary = action.get("details", {})
	var hand_type := _word_text_or_fallback(str(details.get("hand_type", "COMPLETE_HAND")))
	var heading := Label.new()
	heading.text = hand_type
	_apply_secondary_label(heading, true)
	card.add_child(heading)
	for group in details.get("groups", []):
		if not group is Dictionary:
			continue
		var group_row := HBoxContainer.new()
		group_row.add_theme_constant_override("separation", 4)
		var group_label := Label.new()
		group_label.text = _word_text_or_fallback(str(group.get("pattern_type", "PATTERN")))
		_apply_secondary_label(group_label)
		group_row.add_child(group_label)
		_add_action_tiles(group_row, group.get("instance_ids", []))
		card.add_child(group_row)
	var pair_ids: Array = details.get("pair_instance_ids", [])
	if not pair_ids.is_empty():
		var pair_row := HBoxContainer.new()
		pair_row.add_theme_constant_override("separation", 4)
		var pair_label := Label.new()
		pair_label.text = LocalizationCatalogScript.word_text("PAIR")
		_apply_secondary_label(pair_label)
		pair_row.add_child(pair_label)
		_add_action_tiles(pair_row, pair_ids)
		card.add_child(pair_row)
	_add_action_button(card, action, false)


func _add_tile_action_choice(parent: Control, action: Dictionary) -> void:
	var card := _new_choice_card(parent, str(action.get("id", "")))
	var details: Dictionary = action.get("details", {})
	var instance_id := str(action.get("target_id", ""))
	var tile = _tiles_by_id.get(instance_id)
	if tile == null:
		tile = _find_tile(instance_id)
	if tile != null:
		var tile_row := HBoxContainer.new()
		tile_row.add_theme_constant_override("separation", 4)
		_add_tile_face(tile_row, tile)
		var identity := Label.new()
		identity.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0026", [_tile_name(str(details.get("tile_id", ""))), instance_id])
		identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_secondary_label(identity)
		tile_row.add_child(identity)
		card.add_child(tile_row)
	_add_action_button(card, action, false)


func _add_swap_choice(parent: Control, action: Dictionary) -> void:
	var card := _new_choice_card(parent, str(action.get("id", "")))
	var hand_id := str(action.get("hand_instance_id", ""))
	var reserve_id := str(action.get("reserve_instance_id", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_add_tile_face(row, _find_tile(hand_id))
	_add_tile_face(row, _find_tile(reserve_id))
	var summary := Label.new()
	summary.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0045", [hand_id, reserve_id])
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_secondary_label(summary)
	row.add_child(summary)
	card.add_child(row)
	_add_action_button(card, action, false)


func _new_choice_card(parent: Control, action_id: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "BattleChoiceCard_%s" % action_id.replace(":", "_").replace(".", "_")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("run_action_id", action_id)
	_style_compact_panel(panel, "raised", action_id == selected_action_id)
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(stack)
	return stack


func _add_action_tiles(parent: Control, instance_ids: Variant) -> void:
	var ids: Array = instance_ids if instance_ids is Array else []
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 1)
	row.add_theme_constant_override("v_separation", 2)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	for instance_id in ids:
		_add_tile_face(row, _find_tile(str(instance_id)))


func _add_action_button(parent: Control, action: Dictionary, core: bool) -> Button:
	var action_id := str(action.get("id", ""))
	var button := Button.new()
	button.name = "BattleAction_%s" % action_id.replace(":", "_").replace(".", "_")
	button.text = _action_label_text(action)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = maxf(44.0, (48.0 if core else 44.0) * _ui_scale)
	button.set_meta("run_action_id", action_id)
	button.set_meta("run_choice_button", true)
	button.tooltip_text = _action_tooltip_text(action)
	var enabled := bool(action.get("enabled", true)) and not bool(action.get("disabled", false))
	button.disabled = not enabled
	if not enabled:
		var reason := str(action.get("disabled_reason", action.get("reason", LocalizationCatalogScript.word_text("UNAVAILABLE"))))
		button.tooltip_text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0028", [button.text, reason])
	ForbiddenThemeScript.style_button(button, false, action_id == selected_action_id)
	parent.add_child(button)
	button.focus_entered.connect(_on_action_focused.bind(action_id))
	button.pressed.connect(_on_action_selected.bind(action_id))
	button.mouse_entered.connect(_on_action_hovered.bind(action_id))
	return button


func _add_disabled_choice(parent: Control, text: String) -> void:
	var button := Button.new()
	button.name = "UnavailableBattleAction"
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 44.0 * _ui_scale
	button.disabled = true
	ForbiddenThemeScript.style_button(button)
	parent.add_child(button)


func _add_empty_message(parent: Control, message: String) -> void:
	var label := Label.new()
	label.name = "BattleEmptyState"
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", ForbiddenThemeScript.color("muted"))
	_apply_secondary_label(label)
	parent.add_child(label)


func _add_tile_face(parent: Control, tile) -> TileFaceButton:
	if tile == null:
		return null
	var definition_id := str(tile.definition_id)
	var instance_id := str(tile.instance_id)
	var button := TileFaceButtonScript.new()
	var copy_label := LocalizationCatalogScript.format("UI_BATTLE_VIEW_0026", [_tile_name(definition_id), instance_id])
	button.configure({
		"definition_id": definition_id,
		"instance_id": instance_id,
		"copy_label": copy_label,
		"annotations": _tile_annotations(tile),
		"status_marker": _tile_status_marker(tile),
	}, false, false)
	button.custom_minimum_size = Vector2(44.0, maxf(64.0, button.custom_minimum_size.y))
	button.focus_entered.connect(_on_tile_focused.bind(instance_id))
	button.pressed.connect(_on_tile_pressed.bind(instance_id))
	button.tooltip_text = _tile_inspection_text(tile)
	parent.add_child(button)
	_tiles_by_id[instance_id] = tile
	return button


func _tile_button(instance_id: String) -> TileFaceButton:
	for node in find_children("*", "TileFaceButton", true, false):
		var candidate := node as TileFaceButton
		if candidate != null and candidate.tile_instance_id == instance_id:
			return candidate
	return null


func _add_metric(parent: Control, label: String, value: int = 0, maximum: int = -1, ratio: bool = false) -> void:
	var chip := Label.new()
	chip.name = "BattleMetric"
	chip.autowrap_mode = TextServer.AUTOWRAP_OFF
	if ratio:
		chip.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0007", [label, value, maximum])
	else:
		chip.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0006", [label, value])
	chip.add_theme_color_override("font_color", ForbiddenThemeScript.color("muted"))
	_apply_secondary_label(chip)
	parent.add_child(chip)


func _add_metric_text(parent: Control, text: String) -> void:
	var chip := Label.new()
	chip.name = "BattleMetricText"
	chip.text = text
	chip.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_theme_color_override("font_color", ForbiddenThemeScript.color("muted"))
	_apply_secondary_label(chip)
	parent.add_child(chip)


func _update_action_styles() -> void:
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		var action_id := str(button.get_meta("run_action_id", ""))
		if action_id.is_empty() or not _actions_by_id.has(action_id):
			continue
		ForbiddenThemeScript.style_button(button, false, action_id == selected_action_id)
	for node in find_children("BattleChoiceCard_*", "PanelContainer", true, false):
		var card := node as PanelContainer
		var action_id := str(card.get_meta("run_action_id", ""))
		# Styling the choice itself is carried by the button and tile selection states.
		_style_compact_panel(card, "raised", action_id == selected_action_id)
	if _commit_button != null:
		ForbiddenThemeScript.style_button(_commit_button, true, not selected_action_id.is_empty())
		_compact_commit_button()


func _update_commit_rail() -> void:
	if _commit_button == null or _commit_summary == null:
		return
	_commit_button.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0023")
	var action: Dictionary = _actions_by_id.get(selected_action_id, {})
	var is_enabled := not action.is_empty() and bool(action.get("enabled", true)) and not bool(action.get("disabled", false))
	_commit_button.disabled = not is_enabled
	_commit_button.set_meta("run_commit_action_id", str(action.get("id", "")) if is_enabled else "")
	if is_enabled:
		_commit_summary.text = _action_label_text(action)
	else:
		_commit_summary.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0024")


func _update_inspection() -> void:
	if _inspection_value == null:
		return
	var tile = _find_tile(_focused_tile_instance_id)
	if tile != null:
		_inspection_value.text = _tile_inspection_text(tile)
		return
	var action: Dictionary = _actions_by_id.get(focused_action_id, {})
	if action.is_empty():
		action = _actions_by_id.get(selected_action_id, {})
	_inspection_value.text = _action_details_text(action) if not action.is_empty() else LocalizationCatalogScript.text("UI_BATTLE_VIEW_0024")


func _on_action_selected(action_id: String) -> void:
	if not _actions_by_id.has(action_id):
		return
	var action: Dictionary = _actions_by_id[action_id]
	if bool(action.get("disabled", false)) or not bool(action.get("enabled", true)):
		return
	_focus_revision += 1
	focused_action_id = action_id
	_focused_tile_instance_id = ""
	selected_action_id = action_id
	_update_action_styles()
	_update_commit_rail()
	_update_inspection()
	_queue_current_focus_visibility()


func _on_action_focused(action_id: String) -> void:
	_focus_revision += 1
	focused_action_id = action_id
	_focused_tile_instance_id = ""
	_update_inspection()
	focus_requested.emit(action_id)
	_queue_current_focus_visibility()


func _on_action_hovered(action_id: String) -> void:
	if _actions_by_id.has(action_id):
		_focus_revision += 1
		_focused_tile_instance_id = ""
		_update_inspection_for(action_id)


func _on_tile_focused(instance_id: String) -> void:
	_focus_revision += 1
	_focused_tile_instance_id = instance_id
	_update_inspection()
	_queue_current_focus_visibility()


func _on_tile_pressed(instance_id: String) -> void:
	_focus_revision += 1
	_focused_tile_instance_id = instance_id
	var button := _tile_button(instance_id)
	if button != null:
		button.set_selected(false)
	_update_inspection()


func _update_inspection_for(action_id: String) -> void:
	if _inspection_value == null:
		return
	var action: Dictionary = _actions_by_id.get(action_id, {})
	_inspection_value.text = _action_details_text(action) if not action.is_empty() else LocalizationCatalogScript.text("UI_BATTLE_VIEW_0024")


func _on_commit_pressed() -> void:
	var action_id := str(_commit_button.get_meta("run_commit_action_id", ""))
	if action_id.is_empty() or not _actions_by_id.has(action_id):
		return
	action_requested.emit(action_id)


func _restore_action_focus(action_id: String, tile_instance_id: String, should_restore: bool) -> Control:
	if not should_restore or not is_inside_tree():
		return null
	var focus_target: BaseButton = action_button(action_id) if _actions_by_id.has(action_id) else null
	if focus_target == null and not tile_instance_id.is_empty():
		focus_target = _tile_button(tile_instance_id)
	if focus_target == null and _actions_by_id.has(focused_action_id):
		focus_target = action_button(focused_action_id)
	if focus_target == null:
		for action in _actions:
			focus_target = action_button(str(action.get("id", "")))
			if focus_target != null and not focus_target.disabled:
				break
	if focus_target == null or not focus_target.is_visible_in_tree() or focus_target.disabled:
		return null
	focus_target.grab_focus()
	var viewport := get_viewport()
	return focus_target if viewport != null and viewport.gui_get_focus_owner() == focus_target else null


func _queue_current_focus_visibility() -> void:
	if is_inside_tree():
		call_deferred("_schedule_focus_visibility")


func _schedule_focus_visibility() -> void:
	if not is_inside_tree():
		return
	# Coalesce redraw, focus and selection requests into one layout-frame check.
	# A Node-bound one-shot automatically disconnects if the view is freed.
	var frame_signal := get_tree().process_frame
	if not frame_signal.is_connected(_scroll_current_focus_visible):
		frame_signal.connect(_scroll_current_focus_visible, CONNECT_ONE_SHOT)


func _scroll_current_focus_visible() -> void:
	if not is_visible_in_tree():
		return
	var viewport := get_viewport()
	var focus_target := viewport.gui_get_focus_owner() if viewport != null else null
	# Read current focus after layout; no cached control can override newer input.
	# This callback only scrolls and never grabs focus or updates inspection.
	if focus_target == null or not focus_target.is_inside_tree() or not is_ancestor_of(focus_target):
		return
	var ancestor := focus_target.get_parent()
	while ancestor != null and is_ancestor_of(ancestor):
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(focus_target)
		ancestor = ancestor.get_parent()


func _current_battle():
	if _controller == null:
		return null
	var domain = _controller.get("domain")
	return domain.current_battle if domain != null else null


func _find_tile(instance_id: String):
	if instance_id.is_empty():
		return null
	if _tiles_by_id.has(instance_id):
		return _tiles_by_id[instance_id]
	var battle = _current_battle()
	if battle == null or battle.zones == null:
		return null
	for zone in TileZoneScript.all():
		for tile in battle.zones.contents(zone):
			if str(tile.instance_id) == instance_id:
				_tiles_by_id[instance_id] = tile
				return tile
	return null


func _tile_name(definition_id: String) -> String:
	if definition_id.is_empty():
		return LocalizationCatalogScript.text("WORD_NONE")
	return LocalizationCatalogScript.content_text(definition_id)


func _tile_annotations(tile) -> Array[String]:
	var annotations: Array[String] = []
	if tile.integrity_initialized():
		annotations.append(LocalizationCatalogScript.format("UI_BATTLE_VIEW_0027", [tile.integrity, tile.max_integrity]))
	if tile.is_contaminated():
		annotations.append(LocalizationCatalogScript.content_text(str(tile.contamination_id)))
	var battle = _current_battle()
	if battle != null and battle.context != null:
		var modifier_state: Dictionary = battle.context.persistent_state
		for modifier_id in modifier_state.get(str(tile.instance_id), []):
			var modifier_label := LocalizationCatalogScript.content_text(str(modifier_id))
			if not annotations.has(modifier_label):
				annotations.append(modifier_label)
	return annotations


func _tile_status_marker(tile) -> String:
	if tile == null:
		return ""
	var marker := str(tile.integrity) if tile.integrity_initialized() else ""
	if tile.is_contaminated():
		marker += "!"
	var battle = _current_battle()
	if battle != null and battle.context != null:
		var modifier_state: Dictionary = battle.context.persistent_state
		if not modifier_state.get(str(tile.instance_id), []).is_empty():
			marker += "+"
	return marker.left(4)


func _tile_inspection_text(tile) -> String:
	if tile == null:
		return ""
	var lines: Array[String] = [
		_tile_name(str(tile.definition_id)),
		LocalizationCatalogScript.format("UI_BATTLE_VIEW_0026", [_tile_name(str(tile.definition_id)), str(tile.instance_id)]),
	]
	lines.append_array(_tile_annotations(tile))
	return "\n".join(lines)


func _action_details_text(action: Dictionary) -> String:
	if _action_details.is_valid():
		var result: Variant = _action_details.call(action)
		if result is Dictionary:
			var lines: Array[String] = []
			for key in result:
				lines.append("%s: %s" % [str(key), str(result[key])])
			return "\n".join(lines)
		var detail := str(result)
		if not detail.is_empty():
			return detail
	return _action_tooltip_text(action)


func _action_label_text(action: Dictionary) -> String:
	if _action_label.is_valid():
		var label := str(_action_label.call(action))
		if not label.is_empty():
			return label
	return _word_text_or_fallback(str(action.get("kind", "ACTION")))


func _action_tooltip_text(action: Dictionary) -> String:
	if _action_tooltip.is_valid():
		var tooltip := str(_action_tooltip.call(action))
		if not tooltip.is_empty():
			return tooltip
	return _action_label_text(action)


func _actions_for_kind(kind: String) -> Array:
	return _actions.filter(func(action): return str(action.get("kind", "")) == kind)


func _instance_ids(tiles: Array) -> Array[String]:
	var ids: Array[String] = []
	for tile in tiles:
		if tile != null:
			ids.append(str(tile.instance_id))
	return ids


func _intent_label(intent) -> String:
	if intent == null:
		return LocalizationCatalogScript.word_text("UNAVAILABLE")
	var stable_key := str(INTENT_LABEL_KEYS.get(str(intent.action_type), ""))
	if stable_key.begins_with("WORD_"):
		return LocalizationCatalogScript.text(stable_key)
	if not stable_key.is_empty():
		return LocalizationCatalogScript.text(stable_key)
	return LocalizationCatalogScript.word_text("UNAVAILABLE")


func _total_yaku_count(run_state) -> int:
	if run_state == null or not run_state.yaku_counts is Dictionary:
		return 0
	var total := 0
	for count in run_state.yaku_counts.values():
		total += maxi(0, int(count))
	return total


func _word_text_or_fallback(value: String) -> String:
	var normalized := value.strip_edges().to_upper().replace(" ", "_").replace("-", "_")
	var key := "WORD_" + normalized
	var translated := str(TranslationServer.translate(key))
	if translated != key:
		return translated
	return value.replace("_", " ").capitalize()


func _apply_body_label(label: Label, emphasis: bool = false) -> void:
	label.add_theme_font_size_override("font_size", roundi((18.0 if emphasis else 16.0) * _ui_scale))
	label.add_theme_color_override("font_color", ForbiddenThemeScript.color("text"))


func _apply_secondary_label(label: Label, emphasis: bool = false) -> void:
	label.add_theme_font_size_override("font_size", roundi((16.0 if emphasis else 14.0) * _ui_scale))
	label.add_theme_color_override("font_color", ForbiddenThemeScript.color("muted"))


func _style_compact_panel(panel: Control, surface: String, selected: bool = false) -> void:
	ForbiddenThemeScript.style_panel(panel, surface, selected)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	# ForbiddenTheme returns cached StyleBox resources; override a copy so other panels keep
	# their shared insets unchanged while the battle's dense fixed surface stays within view.
	var compact := style.duplicate() as StyleBoxFlat
	compact.content_margin_left = 4.0
	compact.content_margin_top = 4.0
	compact.content_margin_right = 4.0
	compact.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", compact)


func _compact_commit_button() -> void:
	if _commit_button == null:
		return
	_commit_button.custom_minimum_size = Vector2(190.0, 44.0)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := _commit_button.get_theme_stylebox(state) as StyleBoxFlat
		if style == null:
			continue
		var compact := style.duplicate() as StyleBoxFlat
		compact.content_margin_left = 8.0
		compact.content_margin_top = 4.0
		compact.content_margin_right = 8.0
		compact.content_margin_bottom = 4.0
		_commit_button.add_theme_stylebox_override(state, compact)


func _play_cosmetic(target: Object, property: NodePath, from_value: Variant, to_value: Variant, duration: float) -> void:
	if _motion_feedback == null or target == null or not is_instance_valid(target):
		return
	var playing := _motion_feedback.play_property(target, property, from_value, to_value, duration)
	_has_cosmetic_motion = playing and _presentation_mode != "INSTANT" and not _reduced_motion


func _cancel_motion() -> void:
	if _motion_feedback != null:
		_motion_feedback.cancel()
	_has_cosmetic_motion = false


func _on_motion_finished() -> void:
	_has_cosmetic_motion = false


func _on_preferences_changed(values: Dictionary) -> void:
	if set_presentation_preferences(
		str(values.get("locale", _locale)),
		float(values.get("ui_scale", _ui_scale)),
		str(values.get("presentation_mode", _presentation_mode)),
		bool(values.get("reduced_motion", _reduced_motion)),
		bool(values.get("ambient_glow", _ambient_glow)),
	) and _controller != null:
		render()


func _on_screen_changed() -> void:
	_cancel_motion()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_focus_revision += 1
		_cancel_motion()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		_cancel_motion()
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			var preferences := tree.root.get_node_or_null("PresentationPrefs")
			if preferences != null and preferences.preferences_changed.is_connected(_on_preferences_changed):
				preferences.preferences_changed.disconnect(_on_preferences_changed)


func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.free()
