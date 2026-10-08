class_name BattleView
extends Control

signal action_requested(action_id: String)
signal focus_requested(action_id: String)
signal hand_play_requested(instance_ids: Array)

const PlayerActionTextScript = preload("res://src/presentation/ui/player_action_text.gd")
const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const TileFaceButtonScript = preload("res://src/presentation/ui/tile_face_button.gd")
const TableBackdropScript = preload("res://src/presentation/ui/table_backdrop.gd")
const MotionFeedbackScript = preload("res://src/presentation/ui/motion_feedback.gd")
const EnemyArenaScript = preload("res://src/presentation/ui/enemy_arena.gd")
const BattleFeedbackLayerScript = preload("res://src/presentation/ui/battle_feedback_layer.gd")
const BattleCueProjectionScript = preload("res://src/presentation/ui/battle_cue_projection.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const TileSelectionScript = preload("res://src/presentation/ui/battle_tile_selection.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const TileZoneContainerScript = preload("res://src/domain/tiles/tile_zone_container.gd")
const DiscardScorerScript = preload("res://src/domain/tiles/discard_tile_scorer.gd")
const DISCARD_RATIONALE_KEYS := {
	"unmatched": "UI_RC7_DISCARD_HINT_ISOLATED",
	"unknown_definition": "UI_RC7_DISCARD_HINT_ISOLATED",
	"ready_group": "UI_RC7_DISCARD_HINT_READY",
	"honor_pair": "UI_RC7_DISCARD_HINT_PAIR",
	"reserve_pair": "UI_RC7_DISCARD_HINT_PAIR",
	"matching_group": "UI_RC7_DISCARD_HINT_GROUP",
	"sequence_connector": "UI_RC7_DISCARD_HINT_CONNECTOR",
}

var _show_discard_hint := false
var _hand_order: Array[String] = []
var _hand_order_battle_key := ""

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
var _tile_selection = TileSelectionScript.new()
var _visible_action_ids: Dictionary = {}
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

var _enemy_arena: EnemyArenaScript
var _resource_rail: PanelContainer
var _battle_feedback: BattleFeedbackLayerScript
var _battle_event_revision := -1
var _last_battle_events: Array = []
var _pending_battle_cues: Array = []
var _feedback_layout_pending := false
var _feedback_host_external := false
var _terminal_feedback_active := false
var _last_feedback_anchors: Dictionary = {}
var _departing_tile_rects: Dictionary = {}
var _feedback_layout_generation := 0

var _backdrop: TableBackdrop
var _motion_feedback: MotionFeedback
var _shell: Control
var _top_scroll: ScrollContainer
var _top_strip: VBoxContainer
var _decision_row: BoxContainer
var _board_surface: VBoxContainer
var _board_scroll: ScrollContainer
var _board_body: VBoxContainer
var _hand_surface: VBoxContainer
var _hand_scroll: ScrollContainer
var _actions_body: VBoxContainer
var _action_panel: PanelContainer
var _action_scroll: ScrollContainer
var _action_scroll_list: VBoxContainer
var _context_choices: HFlowContainer
var _selection_hint: Label
var _commit_row: BoxContainer
var _commit_panel: PanelContainer
var _receipt_scroll: ScrollContainer
var _layout_pending := false
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
	if _controller != controller:
		_cancel_motion()
		_battle_event_revision = -1
		_last_battle_events.clear()
		_last_encounter_id = ""
		_tile_selection.clear()
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
	var locale_changed := normalized_locale != _locale
	var mode_changed := _presentation_mode != normalized_mode or _reduced_motion != reduced_motion
	_locale = normalized_locale
	_ui_scale = normalized_scale
	_presentation_mode = normalized_mode
	_reduced_motion = reduced_motion
	_ambient_glow = ambient_glow
	_apply_theme()
	if locale_changed:
		# Cue strings are localized when projected. Drop active and deferred
		# cosmetics so a preference refresh never replays an accepted event.
		_cancel_motion()
	if _motion_feedback != null:
		_motion_feedback.configure(_presentation_mode, _reduced_motion)
		if mode_changed:
			_has_cosmetic_motion = false
	if is_instance_valid(_battle_feedback):
		_battle_feedback.configure(_presentation_mode, _reduced_motion)
	_refresh_backdrop()
	return true


func render() -> void:
	_render_generation += 1
	_build_shell()
	if _controller == null or not is_instance_valid(_controller) or not _controller.has_method("action_descriptors"):
		_actions = []
		_actions_by_id.clear()
		_visible_action_ids.clear()
		_tile_selection.clear()
		selected_action_id = ""
		focused_action_id = ""
		_cancel_motion()
		_enemy_arena.visible = false
		_clear_children(_board_body)
		_clear_children(_hand_surface)
		_clear_children(_action_scroll_list)
		_clear_resource_rail()
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
		_tile_selection.clear()
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

	var event_revision := int(_controller.snapshot().get("battle_event_revision", -1))
	if _battle_event_revision >= 0 and event_revision != _battle_event_revision:
		_tile_selection.clear()
		selected_action_id = ""
	if battle != null and battle.zones != null:
		_tile_selection.reconcile(_instance_ids(battle.zones.contents(TileZoneScript.HAND)), _instance_ids(battle.zones.contents(TileZoneScript.RESERVE)))
	else:
		_tile_selection.clear()
	_departing_tile_rects = _tile_rects()
	_rebuild_board(battle)
	_rebuild_action_panel(battle)
	if battle != null:
		_feedback_anchors()
	_update_receipt(battle)
	_update_commit_rail()
	_update_inspection()
	_refresh_battle_feedback(battle)
	var restored_focus := _restore_action_focus(old_focus_id, old_focus_tile_id, had_focus)
	if restored_focus != null:
		_queue_current_focus_visibility()


func cancel() -> bool:
	_focus_revision += 1
	var handled: bool = not selected_action_id.is_empty() or not selected_tile_ids().is_empty() or _has_cosmetic_motion or (is_instance_valid(_battle_feedback) and _battle_feedback.is_playing()) or not _pending_battle_cues.is_empty()
	_cancel_motion()
	_on_clear_tiles()
	return handled


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


func battle_feedback() -> BattleFeedbackLayerScript:
	return _battle_feedback


func set_feedback_host(host: Control) -> void:
	_build_shell()
	if host == null or _battle_feedback.get_parent() == host:
		return
	_battle_feedback.reparent(host, false)
	_battle_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback_host_external = host != self


func last_action_text() -> String:
	var texts := PackedStringArray()
	for cue in BattleCueProjectionScript.project(_last_battle_events):
		texts.append(str(cue.get("text", "")))
	return " · ".join(texts)


func sync_persistent_receipt() -> String:
	_update_receipt(_current_battle())
	if _current_battle() == null:
		_consume_terminal_feedback()
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
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 8)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 4)
	add_child(margin)
	_shell = Control.new()
	_shell.name = "BattleViewShell"
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(_shell)
	_top_scroll = ScrollContainer.new()
	_top_scroll.name = "BattleCriticalScroll"
	_top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_top_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_top_scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shell.add_child(_top_scroll)
	_top_strip = VBoxContainer.new()
	_top_strip.name = "BattleCriticalStrip"
	_top_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_strip.add_theme_constant_override("separation", 4)
	_top_scroll.add_child(_top_strip)
	_receipt_scroll = ScrollContainer.new()
	_receipt_scroll.name = "BattleCriticalReceiptScroll"
	_receipt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_receipt_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_receipt_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_receipt_scroll.visible = false
	_top_strip.add_child(_receipt_scroll)
	_receipt_value = Label.new()
	_receipt_value.name = "BattleCriticalReceipt"
	_receipt_value.visible = false
	_receipt_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_receipt_value.add_theme_color_override("font_color", ForbiddenThemeScript.color("success"))
	_apply_secondary_label(_receipt_value, true)
	_receipt_scroll.add_child(_receipt_value)
	_enemy_arena = EnemyArenaScript.new()
	_enemy_arena.name = "BattleEnemyIntentBanner"
	_enemy_arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_strip.add_child(_enemy_arena)
	_enemy_arena.minimum_size_changed.connect(_queue_table_layout)
	_enemy_arena.resized.connect(_queue_table_layout)
	_top_strip.minimum_size_changed.connect(_queue_table_layout)
	_top_strip.resized.connect(_queue_table_layout)
	_battle_feedback = BattleFeedbackLayerScript.new()
	_battle_feedback.name = "BattleFeedbackLayer"
	_battle_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_feedback.z_index = 20
	add_child(_battle_feedback)
	_decision_row = BoxContainer.new()
	_decision_row.name = "BattleDecisionSurface"
	_decision_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_decision_row.add_theme_constant_override("separation", 5)
	_shell.add_child(_decision_row)
	_board_surface = VBoxContainer.new()
	_board_surface.name = "BattleBoardSurface"
	_board_surface.add_theme_constant_override("separation", 5)
	_board_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_decision_row.add_child(_board_surface)
	_decision_row.vertical = true
	_board_scroll = ScrollContainer.new()
	_board_scroll.name = "BattleViewportScroll"
	_board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_board_scroll.follow_focus = true
	_board_scroll.custom_minimum_size = Vector2.ZERO
	_board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_surface.add_child(_board_scroll)
	_board_body = VBoxContainer.new()
	_board_body.name = "BattleTableContent"
	_board_body.add_theme_constant_override("separation", 6)
	_board_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_scroll.add_child(_board_body)
	_hand_surface = VBoxContainer.new()
	_hand_surface.name = "BattleHandSurface"
	_hand_surface.add_theme_constant_override("separation", 0)
	_hand_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_surface.size_flags_vertical = Control.SIZE_FILL
	_board_surface.resized.connect(_queue_table_layout)
	_hand_surface.resized.connect(_queue_table_layout)
	_hand_surface.minimum_size_changed.connect(_queue_table_layout)
	_action_panel = PanelContainer.new()
	_action_panel.name = "BattleActions"
	_action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_panel.size_flags_vertical = Control.SIZE_FILL
	_style_compact_panel(_action_panel, "lacquer")
	_decision_row.add_child(_action_panel)
	_decision_row.add_child(_hand_surface)
	_actions_body = VBoxContainer.new()
	_actions_body.name = "BattleActionsContent"
	_actions_body.add_theme_constant_override("separation", 4)
	_actions_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_panel.add_child(_actions_body)
	_action_scroll = ScrollContainer.new()
	_action_scroll.name = "BattleChoiceScroll"
	_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_action_scroll.follow_focus = true
	_action_scroll.custom_minimum_size.y = 0.0
	_action_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_actions_body.add_child(_action_scroll)
	_action_scroll_list = VBoxContainer.new()
	_action_scroll_list.name = "BattleChoices"
	_action_scroll_list.add_theme_constant_override("separation", 4)
	_action_scroll_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_scroll.add_child(_action_scroll_list)
	var inspection_scroll := ScrollContainer.new()
	inspection_scroll.name = "BattleInspectionScroll"
	inspection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inspection_scroll.custom_minimum_size.y = 28.0
	inspection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_body.add_child(inspection_scroll)
	_inspection_value = Label.new()
	_inspection_value.name = "BattleInspectionValue"
	_inspection_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspection_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_secondary_label(_inspection_value)
	inspection_scroll.add_child(_inspection_value)
	_commit_panel = PanelContainer.new()
	_commit_panel.name = "BattleCommitRail"
	_style_compact_panel(_commit_panel, "lacquer", true)
	_commit_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_shell.add_child(_commit_panel)
	_commit_row = BoxContainer.new()
	_commit_row.name = "BattleCommitRow"
	_commit_row.add_theme_constant_override("separation", 6)
	_commit_panel.add_child(_commit_row)
	_commit_summary = Label.new()
	_commit_summary.name = "BattleCommitSummary"
	_commit_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_commit_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_secondary_label(_commit_summary)
	_commit_row.add_child(_commit_summary)
	_commit_button = Button.new()
	_commit_button.name = "CommitSelectedButton"
	_commit_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_commit_button.disabled = true
	_commit_button.set_meta("run_commit_action_id", "")
	_commit_button.set_meta("run_choice_button", false)
	_commit_button.visible = false
	ForbiddenThemeScript.style_button(_commit_button, true)
	_compact_commit_button()
	_commit_button.pressed.connect(_on_commit_pressed)
	_commit_row.add_child(_commit_button)
	_commit_panel.visible = false
	resized.connect(_queue_table_layout)
	_queue_table_layout()
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
	if _commit_button != null:
		ForbiddenThemeScript.style_button(_commit_button, true, not selected_action_id.is_empty())
		_compact_commit_button()
		_commit_button.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0023")
	_queue_table_layout()


func _refresh_backdrop() -> void:
	if _backdrop != null:
		_backdrop.configure(_presentation_mode, _reduced_motion, _ambient_glow)


func _rebuild_board(battle) -> void:
	_clear_children(_board_body)
	_clear_children(_hand_surface)
	_clear_resource_rail()
	_tiles_by_id.clear()
	if battle == null or battle.combat_state == null or battle.zones == null:
		_add_empty_message(_board_body, LocalizationCatalogScript.text("UI_BATTLE_VIEW_0022"))
		_last_hand_ids.clear()
		_enemy_arena.visible = false
		return
	var combat = battle.combat_state
	var state = _controller.domain.state

	_add_enemy_banner(_board_body, battle, combat)
	_add_resource_rail(_top_strip, battle, combat, state)
	var table := PanelContainer.new()
	table.name = "BattleTable"
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.custom_minimum_size.y = 110.0
	_style_compact_panel(table, "table")
	_board_body.add_child(table)
	var felt := VBoxContainer.new()
	felt.name = "BattleFelt"
	felt.add_theme_constant_override("separation", 8)
	table.add_child(felt)
	_add_known_zones(felt, battle)
	var wall := Label.new()
	wall.name = "BattleWallGuide"
	wall.text = LocalizationCatalogScript.format("UI_BATTLE_TABLE_WALL", [battle.draw_wall.size()])
	wall.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wall.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wall.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wall.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wall.add_theme_font_size_override("font_size", ForbiddenThemeScript.font_size_for("body", _ui_scale))
	wall.add_theme_color_override("font_color", ForbiddenThemeScript.color("muted"))
	felt.add_child(wall)
	_add_hand_tray(_hand_surface, battle)
	_queue_table_layout()


func _rebuild_action_panel(_battle) -> void:
	_clear_children(_action_scroll_list)
	_visible_action_ids.clear()
	var controls := HFlowContainer.new()
	controls.name = "BattleTurnActions"
	controls.add_theme_constant_override("h_separation", 6)
	controls.add_theme_constant_override("v_separation", 4)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for action in _actions:
		if str(action.get("kind", "")) in ["DRAW", "END_TURN", "TECHNIQUE"]:
			_visible_action_ids[str(action.id)] = true
			_add_action_button(controls, action)
	var matches: Array = _tile_selection.matching_actions(_actions)
	var play_action: Dictionary = _controller.hand_play_action_descriptor(selected_tile_ids())
	if not play_action.is_empty():
		matches.append(play_action)
		_actions_by_id[str(play_action.id)] = play_action
	_selection_hint = Label.new()
	_selection_hint.name = "BattleSelectionHint"
	_selection_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_secondary_label(_selection_hint, true)
	_action_scroll_list.add_child(_selection_hint)
	var count := selected_tile_ids().size()
	_selection_hint.text = LocalizationCatalogScript.text("UI_BATTLE_TABLE_SELECT") if count == 0 else LocalizationCatalogScript.format("UI_BATTLE_TABLE_SELECTED", [count])
	var selected_settlement_candidate = _matching_settlement_candidate(_battle, selected_tile_ids())
	if selected_settlement_candidate != null and _battle.settlement_window.is_open():
		var capacity = _battle.settlement_window.settlement_capacity()
		_selection_hint.text += " · " + LocalizationCatalogScript.format("UI_BATTLE_TABLE_SETTLEMENT_CAPACITY_REMAINING", [capacity.remaining, capacity.maximum])
	var blocked_settlement_action := _blocked_settlement_action(_battle, selected_tile_ids())
	if count > 0 and not blocked_settlement_action.is_empty():
		_selection_hint.text += " · " + str(blocked_settlement_action.get("disabled_reason", ""))
	elif count > 0 and _selection_is_pair(_battle, selected_tile_ids()):
		_selection_hint.text += " · " + LocalizationCatalogScript.text("UI_BATTLE_TABLE_PAIR_INCOMPLETE")
	elif count > 0 and matches.is_empty():
		_selection_hint.text += " · " + LocalizationCatalogScript.text("UI_BATTLE_TABLE_NO_MATCH")
	_context_choices = HFlowContainer.new()
	_context_choices.name = "BattleSelectionActions"
	_context_choices.add_theme_constant_override("h_separation", 6)
	_context_choices.add_theme_constant_override("v_separation", 4)
	_context_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_scroll_list.add_child(_context_choices)
	for action in matches:
		_visible_action_ids[str(action.id)] = true
		_add_action_button(_context_choices, action)
	if not blocked_settlement_action.is_empty():
		var blocked_action_id := str(blocked_settlement_action.get("id", ""))
		_visible_action_ids[blocked_action_id] = true
		_actions_by_id[blocked_action_id] = blocked_settlement_action
		_add_action_button(_context_choices, blocked_settlement_action)
	_action_scroll_list.add_child(controls)
	var advice := Button.new()
	advice.name = "DiscardAdviceButton"
	advice.text = LocalizationCatalogScript.text("UI_RC7_DISCARD_ADVICE_HIDE" if _show_discard_hint else "UI_RC7_DISCARD_ADVICE_SHOW")
	advice.tooltip_text = LocalizationCatalogScript.text("UI_RC8_PLAY_RULE" if _battle != null and _battle.combat_state.turn_play_enabled else "UI_RC7_DISCARD_RULE")
	advice.custom_minimum_size = Vector2(120.0, 44.0)
	ForbiddenThemeScript.style_button(advice)
	advice.pressed.connect(func():
		_show_discard_hint = not _show_discard_hint
		_rebuild_action_panel(_current_battle())
		_queue_table_layout()
	)
	controls.add_child(advice)
	if _show_discard_hint:
		_add_discard_hint(_battle)
	var select_hand := Button.new()
	select_hand.name = "SelectHandButton"
	select_hand.text = LocalizationCatalogScript.text("UI_BATTLE_TABLE_ALL")
	select_hand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	select_hand.custom_minimum_size = Vector2(120.0, 44.0)
	ForbiddenThemeScript.style_button(select_hand)
	select_hand.pressed.connect(_on_select_hand)
	controls.add_child(select_hand)
	var clear_selection := Button.new()
	clear_selection.name = "ClearTilesButton"
	clear_selection.text = LocalizationCatalogScript.text("UI_BATTLE_TABLE_CLEAR")
	clear_selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clear_selection.custom_minimum_size = Vector2(120.0, 44.0)
	clear_selection.disabled = count == 0
	ForbiddenThemeScript.style_button(clear_selection)
	clear_selection.pressed.connect(_on_clear_tiles)
	controls.add_child(clear_selection)
	for control_spec in [{"name": "SortHandButton", "key": "UI_RC8_SORT_HAND", "callback": _sort_hand}, {"name": "MoveHandLeftButton", "key": "UI_RC8_MOVE_LEFT", "callback": _move_focused_hand_tile.bind(-1)}, {"name": "MoveHandRightButton", "key": "UI_RC8_MOVE_RIGHT", "callback": _move_focused_hand_tile.bind(1)}]:
		var order_button := Button.new()
		order_button.name = str(control_spec.name)
		order_button.text = LocalizationCatalogScript.text(str(control_spec.key))
		order_button.tooltip_text = LocalizationCatalogScript.text("UI_RC8_HAND_ORDER_HINT")
		order_button.custom_minimum_size.y = 44.0 * _ui_scale
		ForbiddenThemeScript.style_button(order_button)
		order_button.pressed.connect(control_spec.callback)
		controls.add_child(order_button)
	if _battle != null and _battle.combat_state.turn_play_enabled:
		var play_progress := Label.new()
		play_progress.name = "TurnPlayProgress"
		play_progress.text = LocalizationCatalogScript.format("UI_RC8_PLAY_PROGRESS", [_battle.combat_state.played_tile_ids_this_turn.size()])
		play_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		play_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_secondary_label(play_progress)
		_action_scroll_list.add_child(play_progress)
	_add_unavailable_technique_inspections(_action_scroll_list)
	if not _visible_action_ids.has(selected_action_id):
		selected_action_id = ""
	_update_action_styles()
	_queue_table_layout()


func _add_discard_hint(battle) -> void:
	if battle == null or battle.zones == null or _controller == null:
		return
	var ready: Array = battle.settlement_window.candidates() if battle.settlement_window != null else []
	var ranked := DiscardScorerScript.ranked_candidates(battle.zones.contents(TileZoneScript.HAND), str(_controller.domain.state.character_id), _controller.domain.content_registry, ready)
	for candidate in ranked:
		var instance_id := str(candidate.get("instance_id", ""))
		if not battle.validate_discard_tile(instance_id).is_valid():
			continue
		var hint := Label.new()
		hint.name = "BattleDiscardAdvice"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rationale_key := str(DISCARD_RATIONALE_KEYS.get(str(candidate.get("rationale_key", "")), "UI_RC7_DISCARD_HINT_ISOLATED"))
		hint.text = LocalizationCatalogScript.format("UI_RC7_DISCARD_HINT", [_controller.battle_tile_copy_label(instance_id), LocalizationCatalogScript.text(rationale_key)])
		hint.tooltip_text = LocalizationCatalogScript.text("UI_RC8_PLAY_RULE" if battle.combat_state.turn_play_enabled else "UI_RC7_DISCARD_RULE")
		_apply_secondary_label(hint, true)
		_action_scroll_list.add_child(hint)
		return
func _blocked_settlement_action(battle, selected_ids: Array[String]) -> Dictionary:
	if battle == null or battle.settlement_window == null or selected_ids.is_empty():
		return {}
	var window = battle.settlement_window
	var candidate = _matching_settlement_candidate(battle, selected_ids)
	if candidate == null:
		return {}
	var reason := ""
	if not window.is_open():
		reason = LocalizationCatalogScript.text("UI_BATTLE_TABLE_WINDOW_CLOSED")
	elif not window.has_capacity():
		var capacity = window.settlement_capacity()
		reason = LocalizationCatalogScript.format("UI_BATTLE_TABLE_SETTLEMENT_CAPACITY_EXHAUSTED", [capacity.spent, capacity.maximum])
	else:
		return {}
	var candidate_ids := _instance_ids(candidate.tile_instances)
	var candidate_id := str(candidate.candidate_id)
	return {
		"id": "battle.settle:" + candidate_id,
		"kind": "PARTIAL_SETTLEMENT",
		"target_id": candidate_id,
		"details": {
			"candidate_id": candidate_id,
			"pattern_type": str(candidate.pattern_type),
			"instance_ids": candidate_ids,
		},
		"enabled": false,
		"disabled": true,
		"disabled_reason": reason,
		"reason": reason,
	}


func _matching_settlement_candidate(battle, selected_ids: Array[String]):
	if battle == null or battle.zones == null or battle.settlement_window == null or selected_ids.is_empty():
		return null
	var hand_ids := _instance_ids(battle.zones.contents(TileZoneScript.HAND))
	if not _same_instance_set(selected_ids, _intersection(selected_ids, hand_ids)):
		return null
	for candidate in battle.settlement_window.candidates():
		if _same_instance_set(_instance_ids(candidate.tile_instances), selected_ids):
			return candidate
	return null


func _selection_is_pair(battle, selected_ids: Array[String]) -> bool:
	if battle == null or battle.zones == null or selected_ids.size() != 2:
		return false
	var definition_ids: Array[String] = []
	for tile in battle.zones.contents(TileZoneScript.HAND):
		if selected_ids.has(str(tile.instance_id)):
			definition_ids.append(str(tile.definition_id))
	return definition_ids.size() == 2 and definition_ids[0] == definition_ids[1]


func _same_instance_set(first: Array, second: Array) -> bool:
	if first.is_empty() or first.size() != second.size():
		return false
	var first_ids: Dictionary = {}
	for value in first:
		var instance_id := str(value)
		if instance_id.is_empty() or first_ids.has(instance_id):
			return false
		first_ids[instance_id] = true
	for value in second:
		var instance_id := str(value)
		if not first_ids.has(instance_id):
			return false
		first_ids.erase(instance_id)
	return first_ids.is_empty()


func _intersection(first: Array, second: Array) -> Array[String]:
	var second_ids: Dictionary = {}
	for value in second:
		second_ids[str(value)] = true
	var result: Array[String] = []
	for value in first:
		if second_ids.has(str(value)):
			result.append(str(value))
	return result


func _on_select_hand() -> void:
	var battle = _current_battle()
	if battle == null or battle.zones == null:
		return
	_tile_selection.clear()
	for tile in battle.zones.contents(TileZoneScript.HAND):
		_tile_selection.toggle(str(tile.instance_id))
	_selection_changed()


func _on_clear_tiles() -> void:
	_tile_selection.clear()
	_selection_changed()


func _selection_changed() -> void:
	var old_focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var old_name := str(old_focus.name) if old_focus != null else ""
	selected_action_id = ""
	_rebuild_action_panel(_current_battle())
	_refresh_tile_selection()
	_update_commit_rail()
	_update_inspection()
	if old_focus != null and (not old_focus.is_inside_tree() or old_focus is BaseButton and old_focus.disabled):
		var target := find_child("SelectHandButton", true, false) as Button if old_name == "SelectHandButton" else tile_button(_focused_tile_instance_id)
		if target == null:
			var hand := find_child("BattleHandTiles", true, false)
			if hand != null and hand.get_child_count() > 0:
				target = hand.get_child(0) as Button
		if target != null:
			target.grab_focus()


func _add_unavailable_technique_inspections(parent: Control) -> void:
	if _controller == null or not _controller.has_method("technique_inspection_descriptors"):
		return
	var unavailable: Array[Dictionary] = []
	for descriptor in _controller.technique_inspection_descriptors():
		if descriptor is Dictionary and not bool(descriptor.get("available", false)):
			unavailable.append(descriptor)
	if unavailable.is_empty():
		return
	var heading := Label.new()
	heading.name = "BattleUnavailableTechniquesHeading"
	heading.text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0065")
	_apply_secondary_label(heading, true)
	parent.add_child(heading)
	for descriptor in unavailable:
		var technique_id := str(descriptor.get("id", ""))
		var safe_id := technique_id.replace(".", "_")
		var card := PanelContainer.new()
		card.name = "BattleUnavailableTechnique_" + safe_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_compact_panel(card, "table")
		parent.add_child(card)
		var detail := VBoxContainer.new()
		detail.add_theme_constant_override("separation", 1)
		card.add_child(detail)
		var title := Label.new()
		title.name = "BattleTechniqueTitle_" + safe_id
		var technique_kind := str(descriptor.get("kind", "TECHNIQUE"))
		var technique_source := str(descriptor.get("source", "RUN"))
		var technique_timing := LocalizationCatalogScript.word_text(technique_kind)
		var source_label := LocalizationCatalogScript.word_text("CHARACTER" if technique_source == "CORE" else technique_source)
		var technique_summary := "%s · %s · %d %s" % [
			technique_timing,
			source_label,
			int(descriptor.get("tp_cost", 0)),
			LocalizationCatalogScript.word_text("TP"),
		]
		title.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0064", [
			LocalizationCatalogScript.content_text(technique_id),
			technique_summary,
		])
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_secondary_label(title, true)
		detail.add_child(title)
		var reason := Label.new()
		reason.name = "BattleTechniqueReason_" + safe_id
		reason.text = _technique_unavailable_reason(descriptor)
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_secondary_label(reason)
		detail.add_child(reason)


func _technique_unavailable_reason(descriptor: Dictionary) -> String:
	var reason_code := str(descriptor.get("reason_code", ""))
	var kind := str(descriptor.get("kind", ""))
	match reason_code:
		"TECHNIQUE_TIMING_UNAVAILABLE":
			match kind:
				"SETTLEMENT":
					return LocalizationCatalogScript.text("UI_BATTLE_VIEW_0057")
				"REACTION":
					var trigger_label := LocalizationCatalogScript.display_text(str(descriptor.get("reaction_trigger_label", "")))
					return LocalizationCatalogScript.format("UI_BATTLE_VIEW_0058", [trigger_label])
				"PASSIVE":
					return LocalizationCatalogScript.text("UI_BATTLE_VIEW_0059")
		"INSUFFICIENT_TP":
			return LocalizationCatalogScript.format("UI_BATTLE_VIEW_0060", [int(descriptor.get("tp_cost", 0)), int(descriptor.get("current_tp", 0))])
		"CORE_TECHNIQUE_ALREADY_USED":
			return LocalizationCatalogScript.text("UI_BATTLE_VIEW_0061")
		"TECHNIQUE_EFFECT_TIMING_UNAVAILABLE":
			return LocalizationCatalogScript.text("UI_BATTLE_VIEW_0062")
	return LocalizationCatalogScript.text("UI_BATTLE_VIEW_0063")


func selected_tile_ids() -> Array[String]:
	return _tile_selection.selected_ids()


func tile_button(instance_id: String) -> TileFaceButton:
	return _tile_button(instance_id)


func _refresh_tile_selection() -> void:
	var selected := _tile_selection.selected_ids()
	for node in find_children("*", "TileFaceButton", true, false):
		node.set_selected(selected.has(node.tile_instance_id))


func _add_enemy_banner(_parent: Control, battle, combat) -> void:
	_enemy_arena.visible = true
	var enemy_id := str(battle.enemy_definition.content_id) if battle.enemy_definition != null else ""
	if enemy_id.is_empty() and not battle.enemy_definition_ids().is_empty():
		enemy_id = str(battle.enemy_definition_ids()[0])
	var enemy_name := LocalizationCatalogScript.content_text(enemy_id) if not enemy_id.is_empty() else LocalizationCatalogScript.text("WORD_BATTLE")
	var intent_display_name := LocalizationCatalogScript.display_text(str(combat.current_intent.display_name)) if combat.current_intent != null else LocalizationCatalogScript.word_text("UNAVAILABLE")
	var intent_detail := LocalizationCatalogScript.word_text("UNAVAILABLE")
	var action_type := str(combat.current_intent.action_type).to_upper() if combat.current_intent != null else ""
	if combat.current_intent != null:
		if action_type == "PRESSURE":
			intent_detail = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0005", [combat.current_intent.pressure_amount])
		else:
			var effect_key := str(INTENT_EFFECT_KEYS.get(action_type, ""))
			if not effect_key.is_empty():
				intent_detail = LocalizationCatalogScript.format(effect_key, [combat.current_intent.pressure_amount])
	_enemy_arena.configure({
		"enemy_id": enemy_id, "enemy_name": enemy_name,
		"hp": combat.enemy_hp, "max_hp": combat.enemy_max_hp,
		"hp_text": LocalizationCatalogScript.format("UI_BATTLE_VIEW_0003", [enemy_name, combat.enemy_hp, combat.enemy_max_hp]),
		"intent_name": LocalizationCatalogScript.format("UI_BATTLE_VIEW_0048", [intent_display_name, _intent_label(combat.current_intent)]),
		"intent_detail": intent_detail, "intent_type": action_type,
		"pressure": combat.pressure, "pressure_limit": combat.pressure_limit,
		"stability": combat.stability, "wall_count": battle.draw_wall.size(),
		"locale": _locale, "ui_scale": _ui_scale,
	})


func _add_resource_rail(parent: Control, battle, combat, run_state) -> void:
	var panel := PanelContainer.new()
	panel.name = "BattleResources"
	_style_compact_panel(panel, "lacquer")
	parent.add_child(panel)
	_resource_rail = panel
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
	_add_metric(rail, LocalizationCatalogScript.word_text("TP"), combat.tp)
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


func _clear_resource_rail() -> void:
	if _resource_rail == null or not is_instance_valid(_resource_rail):
		_resource_rail = null
		return
	if _resource_rail.get_parent() != null:
		_resource_rail.get_parent().remove_child(_resource_rail)
	_resource_rail.queue_free()
	_resource_rail = null


func _add_known_zones(parent: Control, battle) -> void:
	var zones := BoxContainer.new()
	zones.name = "BattleZones"
	zones.add_theme_constant_override("separation", 8)
	zones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if zone == TileZoneScript.DISCARD:
		return
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
	tray.size_flags_vertical = Control.SIZE_FILL
	tray.custom_minimum_size.y = 96.0
	_style_compact_panel(tray, "table")
	parent.add_child(tray)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	tray.add_child(stack)
	var hand: Array = battle.zones.contents(TileZoneScript.HAND)
	var battle_key := str(_controller.domain.state.run_id) + "|" + str(battle.encounter_id)
	if battle_key != _hand_order_battle_key:
		_hand_order.clear()
		_hand_order_battle_key = battle_key
	var hand_ids := _instance_ids(hand)
	_hand_order = _hand_order.filter(func(instance_id): return hand_ids.has(instance_id))
	for instance_id in hand_ids:
		if not _hand_order.has(instance_id):
			_hand_order.append(instance_id)
	hand.sort_custom(func(left, right): return _hand_order.find(str(left.instance_id)) < _hand_order.find(str(right.instance_id)))
	var heading := Label.new()
	heading.name = "BattleHandHeading"
	heading.text = LocalizationCatalogScript.format("UI_BATTLE_HAND_CAP", [hand.size()])
	heading.tooltip_text = LocalizationCatalogScript.text("UI_BATTLE_HAND_LIMIT_HINT")
	_apply_secondary_label(heading, true)
	stack.add_child(heading)
	_hand_scroll = ScrollContainer.new()
	_hand_scroll.name = "BattleHandScroll"
	_hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hand_scroll.follow_focus = true
	_hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_scroll.size_flags_vertical = Control.SIZE_FILL
	stack.add_child(_hand_scroll)
	var hand_row := HBoxContainer.new()
	hand_row.name = "BattleHandTiles"
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.add_theme_constant_override("separation", roundi(3.0 * _ui_scale))
	hand_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_row.resized.connect(_queue_table_layout)
	for tile in hand:
		var button := _add_tile_face(hand_row, tile)
		button.set_meta("battle_hand_tile", true)
		button.hand_order_owner_id = get_instance_id()
		button.hand_reorder_requested.connect(_reorder_hand_tile)
		button.selection_lift = true
		button.set_selected(button.selected)
	_hand_scroll.add_child(hand_row)
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
	_receipt_scroll.visible = _receipt_value.visible
	_queue_table_layout()
	if changed and not feedback.is_empty() and is_visible_in_tree():
		_play_cosmetic(_receipt_value, ^"modulate:a", 0.78, 1.0, 0.36)


func _record_receipt_cues(battle) -> void:
	if _controller == null or not _controller.has_method("snapshot"):
		return
	var snapshot: Dictionary = _controller.snapshot()
	var event_types: Array = snapshot.get("last_domain_event_types", [])
	var relevant_events: Array[String] = []
	for event_type in event_types:
		if str(event_type) in ["CompleteHandSettled", "BossPhaseChanged", "BattleWon", "GoldChanged"]:
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
			"GoldChanged":
				for raw_event in snapshot.get("battle_events", []):
					var data: Dictionary = raw_event.get("data", {})
					if str(raw_event.get("event_type", "")) == "GoldChanged" and str(data.get("source_id", "")) == "HAND_PLAY_COMBO":
						_receipt_cues.append({"key": "UI_RC8_COMBO_RECEIPT", "values": [int(data.get("amount", 0))]})
			"CompleteHandSettled":
				_receipt_cues.append({"key": "UI_BATTLE_VIEW_0046", "values": []})
				var has_score := false
				var score := 0
				var damage := 0
				for raw_event in snapshot.get("battle_events", []):
					var data: Dictionary = raw_event.get("data", {})
					if str(raw_event.get("event_type", "")) == "CompleteHandSettled":
						score = int(data.get("score", 0))
						has_score = data.has("score")
					if str(raw_event.get("event_type", "")) == "EnemyHPChanged":
						damage += int(data.get("amount", 0))
				if has_score:
					_receipt_cues.append({"key": "UI_PLAYER_WIN_RECEIPT", "values": [score, damage]})
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


func _add_action_button(parent: Control, action: Dictionary) -> Button:
	var action_id := str(action.get("id", ""))
	var button := Button.new()
	button.name = "BattleAction_%s" % action_id.replace(":", "_").replace(".", "_")
	button.text = _action_label_text(action)
	var kind := str(action.get("kind", ""))
	var battle = _controller.domain.current_battle if _controller != null else null
	if kind in ["PARTIAL_SETTLEMENT", "COMPLETE_HAND"] and battle != null:
		var preview: Dictionary = battle.preview_settlement(str(action.get("target_id", "")), kind == "COMPLETE_HAND")
		if not preview.is_empty():
			button.text += "\n" + LocalizationCatalogScript.format("UI_PLAYER_COMMIT_PREVIEW", [preview.damage, preview.replacement_draws])
	if kind == "TECHNIQUE":
		var effects := PlayerActionTextScript.definition_effect_lines(_controller.domain.content_registry, str(action.get("target_id", "")))
		if not effects.is_empty():
			button.text += "\n" + " · ".join(PackedStringArray(effects))
	var lethal_amount := PlayerActionTextScript.lethal_intent_amount(battle) if kind == "END_TURN" else 0
	if kind in ["PLAY_HAND", "DISCARD"] and battle != null and battle.combat_state.turn_play_enabled:
		var play_ids: Array = action.get("details", {}).get("instance_ids", []) if kind == "PLAY_HAND" else [str(action.get("target_id", ""))]
		if not battle.play_combo_type(play_ids).is_empty():
			button.text += "\n" + LocalizationCatalogScript.text("UI_RC8_COMBO_PREVIEW")
	if lethal_amount > 0:
		button.text += "\n" + LocalizationCatalogScript.format("UI_PLAYER_LETHAL_INTENT", [lethal_amount])
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(200.0, 44.0 * _ui_scale)
	button.set_meta("run_action_id", action_id)
	button.set_meta("run_choice_button", true)
	button.tooltip_text = _action_details_text(action)
	var enabled := bool(action.get("enabled", true)) and not bool(action.get("disabled", false))
	button.disabled = not enabled
	if not enabled:
		var reason := str(action.get("disabled_reason", action.get("reason", LocalizationCatalogScript.word_text("UNAVAILABLE"))))
		if reason == "HAND_CAPACITY_REACHED":
			var hand_count: int = battle.zones.size(TileZoneScript.HAND) if battle != null and battle.zones != null else TileZoneContainerScript.MAX_HAND_SIZE
			reason = LocalizationCatalogScript.format("UI_BATTLE_HAND_CAP_REACHED", [hand_count])
		button.tooltip_text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0028", [button.text, reason])
	ForbiddenThemeScript.style_button(button, false, action_id == selected_action_id)
	if lethal_amount > 0:
		for color_role in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color_role, ForbiddenThemeScript.color("error"))
	parent.add_child(button)
	button.focus_entered.connect(_on_action_focused.bind(action_id))
	button.pressed.connect(_on_action_activated.bind(action_id))
	button.mouse_entered.connect(_on_action_hovered.bind(action_id))
	return button


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
	var copy_label := _tile_copy_label(tile)
	button.configure({
		"definition_id": definition_id,
		"instance_id": instance_id,
		"copy_label": copy_label,
		"annotations": _tile_annotations(tile),
		"status_marker": _tile_status_marker(tile),
	}, _tile_selection.selected_ids().has(instance_id), false)
	button.custom_minimum_size = Vector2(44.0, maxf(64.0, button.custom_minimum_size.y))
	button.focus_entered.connect(_on_tile_focused.bind(instance_id))
	button.pressed.connect(_on_tile_pressed.bind(instance_id))
	button.tooltip_text = _tile_inspection_text(tile)
	button.accessibility_name = button.tooltip_text
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


func _on_action_activated(action_id: String) -> void:
	if not _visible_action_ids.has(action_id) or not _actions_by_id.has(action_id):
		return
	var action: Dictionary = _actions_by_id[action_id]
	if bool(action.get("disabled", false)) or not bool(action.get("enabled", true)):
		return
	_focus_revision += 1
	focused_action_id = action_id
	_focused_tile_instance_id = ""
	selected_action_id = ""
	_update_action_styles()
	_update_commit_rail()
	_update_inspection()
	if str(action.get("kind", "")) == "PLAY_HAND":
		hand_play_requested.emit(action.get("details", {}).get("instance_ids", []))
	else:
		action_requested.emit(action_id)

func _sort_hand() -> void:
	var battle = _current_battle()
	if battle == null:
		return
	var hand: Array = battle.zones.contents(TileZoneScript.HAND)
	var suit_order := {"characters": 0, "dots": 1, "bamboo": 2, "honors": 3}
	var honor_order := {"east": 0, "south": 1, "west": 2, "north": 3, "red": 4, "green": 5, "white": 6}
	hand.sort_custom(func(left, right):
		var a = _controller.domain.content_registry.resolve(str(left.definition_id))
		var b = _controller.domain.content_registry.resolve(str(right.definition_id))
		var a_suit: int = suit_order.get(str(a.suit), 4)
		var b_suit: int = suit_order.get(str(b.suit), 4)
		if a_suit != b_suit: return a_suit < b_suit
		if int(a.rank) != int(b.rank): return int(a.rank) < int(b.rank)
		if a_suit == 3 and str(left.definition_id) != str(right.definition_id):
			var a_honor: int = honor_order.get(str(left.definition_id).get_slice(".", 3), 7)
			var b_honor: int = honor_order.get(str(right.definition_id).get_slice(".", 3), 7)
			if a_honor != b_honor: return a_honor < b_honor
			return str(left.definition_id) < str(right.definition_id)
		return str(left.instance_id) < str(right.instance_id)
	)
	_hand_order = _instance_ids(hand)
	_apply_hand_order()

func _reorder_hand_tile(source_id: String, target_id: String, after: bool = false) -> void:
	if source_id == target_id or not _hand_order.has(source_id) or not _hand_order.has(target_id):
		return
	_hand_order.erase(source_id)
	_hand_order.insert(_hand_order.find(target_id) + (1 if after else 0), source_id)
	_apply_hand_order()

func _move_focused_hand_tile(direction: int) -> void:
	var source_id := _focused_tile_instance_id
	if not _hand_order.has(source_id) and not selected_tile_ids().is_empty():
		source_id = selected_tile_ids()[0]
	var index := _hand_order.find(source_id)
	if index < 0 or index + direction < 0 or index + direction >= _hand_order.size():
		return
	_reorder_hand_tile(source_id, _hand_order[index + direction], direction > 0)

func _apply_hand_order() -> void:
	var row = find_child("BattleHandTiles", true, false)
	if row == null:
		return
	for index in _hand_order.size():
		var button := _tile_button(_hand_order[index])
		if button != null and button.get_parent() == row:
			row.move_child(button, index)
	_queue_table_layout()


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
	_tile_selection.toggle(instance_id)
	_selection_changed()


func _update_inspection_for(action_id: String) -> void:
	if _inspection_value == null:
		return
	var action: Dictionary = _actions_by_id.get(action_id, {})
	_inspection_value.text = _action_details_text(action) if not action.is_empty() else LocalizationCatalogScript.text("UI_BATTLE_VIEW_0024")


func _on_commit_pressed() -> void:
	var action_id := str(_commit_button.get_meta("run_commit_action_id", ""))
	if _commit_button.disabled or action_id.is_empty() or not _visible_action_ids.has(action_id):
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
			var scroll := ancestor as ScrollContainer
			if focus_target.size.y > scroll.get_global_rect().size.y:
				_reveal_oversized_focus_in_scroll(scroll, focus_target)
			else:
				scroll.ensure_control_visible(focus_target)
		ancestor = ancestor.get_parent()


func _reveal_oversized_focus_in_scroll(scroll: ScrollContainer, focus_target: Control) -> void:
	if scroll == null or focus_target == null:
		return
	var scrollbar := scroll.get_v_scroll_bar()
	var maximum := maxf(0.0, scrollbar.max_value - scrollbar.page)
	if maximum <= 1.0:
		return
	var viewport_rect := scroll.get_global_rect()
	var viewport := get_viewport()
	if viewport != null:
		viewport_rect = viewport_rect.intersection(Rect2(Vector2.ZERO, viewport.get_visible_rect().size))
	var center_delta := focus_target.get_global_rect().get_center().y - viewport_rect.get_center().y
	if not is_zero_approx(center_delta):
		scroll.scroll_vertical = roundi(clampf(float(scroll.scroll_vertical) + center_delta, 0.0, maximum))


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


func _tile_copy_label(tile) -> String:
	if tile == null:
		return LocalizationCatalogScript.text("WORD_NONE")
	var instance_id := str(tile.instance_id)
	if _controller != null and _controller.has_method("battle_tile_copy_label"):
		return str(_controller.call("battle_tile_copy_label", instance_id))
	return _tile_name(str(tile.definition_id))


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
	var lines: Array[String] = [_tile_copy_label(tile)]
	var battle = _current_battle()
	if battle != null and battle.zones != null:
		var zone := str(battle.zones.zone_of(str(tile.instance_id)))
		var zone_word := zone.to_upper().replace(" ", "_")
		var localized_zone := LocalizationCatalogScript.word_text(zone_word)
		if not localized_zone.is_empty() and not localized_zone.begins_with("[MISSING"):
			lines.append(localized_zone)
	lines.append_array(_tile_interpretation_context(str(tile.instance_id)))
	lines.append_array(_tile_annotations(tile))
	return "\n".join(lines)


func _tile_interpretation_context(instance_id: String) -> Array[String]:
	var contexts: Array[String] = []
	for action in _actions:
		var kind := str(action.get("kind", ""))
		var details: Dictionary = action.get("details", {}) if action.get("details", {}) is Dictionary else {}
		if kind == "PARTIAL_SETTLEMENT":
			if _contains_instance(details.get("instance_ids", []), instance_id):
				_append_unique_context(contexts, LocalizationCatalogScript.word_text(str(details.get("pattern_type", "PATTERN"))))
		elif kind == "COMPLETE_HAND":
			var hand_label := LocalizationCatalogScript.word_text(str(details.get("hand_type", "HAND")).to_upper().replace(" ", "_"))
			if _contains_instance(details.get("pair_instance_ids", []), instance_id):
				_append_unique_context(contexts, "%s · %s" % [hand_label, LocalizationCatalogScript.word_text("PAIR")])
				continue
			for group in details.get("groups", []):
				if not group is Dictionary or not _contains_instance(group.get("instance_ids", []), instance_id):
					continue
				var pattern_label := LocalizationCatalogScript.word_text(str(group.get("pattern_type", "PATTERN")))
				_append_unique_context(contexts, "%s · %s" % [hand_label, pattern_label])
	return contexts


func _contains_instance(raw_instance_ids: Variant, instance_id: String) -> bool:
	if not raw_instance_ids is Array:
		return false
	for candidate_id in raw_instance_ids:
		if str(candidate_id) == instance_id:
			return true
	return false


func _append_unique_context(contexts: Array[String], context: String) -> void:
	if not context.is_empty() and not contexts.has(context):
		contexts.append(context)


func _action_details_text(action: Dictionary) -> String:
	if str(action.get("kind", "")) == "PLAY_HAND":
		return LocalizationCatalogScript.text("UI_RC8_PLAY_RULE")
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
	if str(action.get("kind", "")) == "PLAY_HAND":
		return LocalizationCatalogScript.format("UI_RC8_PLAY_SELECTED", [action.get("details", {}).get("instance_ids", []).size()])
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
	label.add_theme_font_size_override("font_size", ForbiddenThemeScript.font_size_for("heading" if emphasis else "body", _ui_scale))
	label.add_theme_color_override("font_color", ForbiddenThemeScript.color("text"))


func _apply_secondary_label(label: Label, emphasis: bool = false) -> void:
	label.add_theme_font_size_override("font_size", ForbiddenThemeScript.font_size_for("body" if emphasis else "secondary", _ui_scale))
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
	_commit_button.custom_minimum_size = Vector2(160.0, 44.0)
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


func _tile_rects() -> Dictionary:
	var rects: Dictionary = {}
	for node in find_children("*", "Button", true, false):
		if not node is TileFaceButton or not node.is_inside_tree():
			continue
		# Action previews can repeat a physical tile. Only the Hand and known
		# zone controls own its spatial destination; previews never overwrite it.
		var ancestor := node.get_parent()
		var physical_zone := false
		while ancestor != null and ancestor != self:
			if str(ancestor.name) == "BattleHandTiles" or str(ancestor.name).begins_with("BattleZone_"):
				physical_zone = true
				break
			ancestor = ancestor.get_parent()
		if not physical_zone:
			continue
		var rect: Rect2 = node.get_global_rect()
		var visible_rect := _visible_motion_rect(node)
		if visible_rect.size.is_equal_approx(rect.size):
			rects[str(node.tile_instance_id)] = rect
	return rects


func _visible_motion_rect(node: Control) -> Rect2:
	if node == null or not node.is_inside_tree() or not node.is_visible_in_tree():
		return Rect2()
	var rect := node.get_global_rect().intersection(get_global_rect())
	var ancestor := node.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor is ScrollContainer:
			var clip: Rect2 = ancestor.get_global_rect()
			var horizontal: ScrollBar = ancestor.get_h_scroll_bar()
			var vertical: ScrollBar = ancestor.get_v_scroll_bar()
			if horizontal.is_visible_in_tree():
				clip.size.y = maxf(0.0, clip.size.y - horizontal.size.y)
			if vertical.is_visible_in_tree():
				clip.size.x = maxf(0.0, clip.size.x - vertical.size.x)
			rect = rect.intersection(clip)
		ancestor = ancestor.get_parent()
	return rect


func _reveal_latest_draw() -> bool:
	for index in range(_pending_battle_cues.size() - 1, -1, -1):
		var cue: Dictionary = _pending_battle_cues[index]
		if str(cue.get("kind", "")) != "DRAW":
			continue
		var tile := _tile_button(str(cue.get("instance_id", "")))
		if tile == null:
			return false
		if _visible_motion_rect(tile).size.is_equal_approx(tile.get_global_rect().size):
			return false
		var ancestor := tile.get_parent()
		while ancestor != null and ancestor != self:
			if ancestor is ScrollContainer:
				ancestor.ensure_control_visible(tile)
			ancestor = ancestor.get_parent()
		return true
	return false


func _tile_definitions() -> Dictionary:
	var definitions: Dictionary = {}
	var battle = _current_battle()
	if battle != null and battle.zones != null:
		for zone in TileZoneScript.all():
			for tile in battle.zones.contents(zone):
				definitions[str(tile.instance_id)] = str(tile.definition_id)
	return definitions


func _refresh_battle_feedback(battle) -> void:
	if not _controller.has_method("snapshot"):
		return
	if battle == null:
		_consume_terminal_feedback()
		return
	_terminal_feedback_active = false
	var snapshot: Dictionary = _controller.snapshot()
	var revision := int(snapshot.get("battle_event_revision", -1))
	if _suppress_hand_feedback:
		_cancel_motion()
		_last_battle_events.clear()
		_battle_event_revision = revision
	elif revision != _battle_event_revision:
		_battle_event_revision = revision
		_last_battle_events = snapshot.get("battle_events", []).duplicate(true)
		_pending_battle_cues = BattleCueProjectionScript.project(_last_battle_events)
		# Supersede cosmetic playback immediately; accepted authority is already
		# rendered, and focus/locale refreshes never create another event batch.
		_battle_feedback.cancel()
	_enemy_arena.recent_action(last_action_text())
	if not is_visible_in_tree():
		# Hidden ordinary batches retain their receipt but are not replayed late.
		_pending_battle_cues.clear()
		return
	_queue_battle_feedback()


func _consume_terminal_feedback() -> void:
	if _controller == null or not _controller.has_method("snapshot"):
		return
	var snapshot: Dictionary = _controller.snapshot()
	var revision := int(snapshot.get("battle_event_revision", -1))
	if revision == _battle_event_revision:
		return
	var events: Array = snapshot.get("battle_events", [])
	var terminal := events.any(func(event): return event is Dictionary and str(event.get("event_type", "")) in ["BattleWon", "BattleLost"])
	if not terminal:
		return
	_cancel_motion()
	_battle_event_revision = revision
	_last_battle_events = events.duplicate(true)
	_terminal_feedback_active = true
	_pending_battle_cues = BattleCueProjectionScript.project(events).filter(func(cue): return str(cue.get("kind", "")) in ["ATTACK", "RELIEF", "PRESSURE", "ENEMY_EFFECT", "STRESS", "PHASE", "VICTORY", "DEFEAT"])
	_queue_battle_feedback()


func _queue_battle_feedback() -> void:
	if not _pending_battle_cues.is_empty() and not _feedback_layout_pending and is_inside_tree():
		_feedback_layout_pending = true
		_feedback_layout_generation += 1
		_play_pending_battle_feedback.call_deferred(_feedback_layout_generation)


func _play_pending_battle_feedback(generation: int) -> void:
	if generation != _feedback_layout_generation or not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	# Containers finish laying out the committed hand before its ghost flies.
	await tree.process_frame
	# EXIT_TREE cancels and advances the generation. A callback from the old
	# parent must not consume cues queued after this view is attached elsewhere.
	if not is_instance_valid(self) or generation != _feedback_layout_generation:
		return
	if not is_inside_tree() or get_tree() != tree:
		return
	if not _terminal_feedback_active and not _pending_battle_cues.is_empty() and _reveal_latest_draw():
		# Revealing a new tile changes container transforms, never input focus.
		await tree.process_frame
		if not is_instance_valid(self) or generation != _feedback_layout_generation or not is_inside_tree() or get_tree() != tree:
			return
	_feedback_layout_pending = false
	var can_show := is_visible_in_tree() or (_terminal_feedback_active and _feedback_host_external and _battle_feedback.is_visible_in_tree())
	if not can_show or _pending_battle_cues.is_empty():
		_pending_battle_cues.clear()
		return
	var cues := _pending_battle_cues.duplicate(true)
	_pending_battle_cues.clear()
	var anchors := _last_feedback_anchors.duplicate(true) if _terminal_feedback_active else _feedback_anchors()
	_battle_feedback.configure(_presentation_mode, _reduced_motion)
	_battle_feedback.play(cues, anchors)


func _feedback_anchors() -> Dictionary:
	var hand := find_child("BattleHandTiles", true, false) as Control
	var visible_hand := _visible_motion_rect(hand)
	var hand_center: Vector2 = visible_hand.get_center() if visible_hand.has_area() else _enemy_arena.player_anchor()
	var anchors := {
		"enemy": _enemy_arena.enemy_anchor(), "player": _enemy_arena.player_anchor(),
		"wall": _enemy_arena.wall_anchor(), "hand": hand_center,
		"reserve": _zone_anchor("BattleZone_Reserve", _enemy_arena.player_anchor()),
		"discard": _zone_anchor("BattleZone_Discard", hand_center + Vector2(80.0, 0.0)),
		"exhaust": _zone_anchor("BattleZone_Exhaust", hand_center + Vector2(100.0, 20.0)),
		"tiles": _tile_rects(), "departing_tiles": _departing_tile_rects.duplicate(true), "tile_definitions": _tile_definitions(),
	}
	_last_feedback_anchors = anchors.duplicate(true)
	return anchors


func _zone_anchor(node_name: String, fallback: Vector2) -> Vector2:
	var zone := find_child(node_name, true, false) as Control
	if zone == null or not zone.is_visible_in_tree():
		return fallback
	var rect := _visible_motion_rect(zone)
	return rect.get_center() if rect.has_area() else fallback


func _play_cosmetic(target: Object, property: NodePath, from_value: Variant, to_value: Variant, duration: float) -> void:
	if _motion_feedback == null or target == null or not is_instance_valid(target):
		return
	var playing := _motion_feedback.play_property(target, property, from_value, to_value, duration)
	_has_cosmetic_motion = playing and _presentation_mode != "INSTANT" and not _reduced_motion


func _cancel_motion() -> void:
	_feedback_layout_generation += 1
	_feedback_layout_pending = false
	_pending_battle_cues.clear()
	if is_instance_valid(_battle_feedback):
		_battle_feedback.cancel()
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
		if what == NOTIFICATION_PREDELETE and _feedback_host_external and is_instance_valid(_battle_feedback):
			_battle_feedback.queue_free()
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
		# Selection controls may rebuild their own row during pressed delivery.
		child.queue_free()


func _queue_table_layout() -> void:
	if _layout_pending or not is_inside_tree():
		return
	_layout_pending = true
	call_deferred("_apply_table_layout")


func _apply_table_layout() -> void:
	_layout_pending = false
	if not is_inside_tree() or _decision_row == null:
		return
	var available_width := maxf(180.0, size.x - 16.0 * _ui_scale)
	var receipt_height := 26.0 * _ui_scale if _receipt_scroll.visible else 0.0
	_receipt_scroll.custom_minimum_size.y = receipt_height
	var commit_height := 0.0
	var shell_height := _shell.size.y
	var action_bar_height := clampf(shell_height * 0.23, 112.0 * _ui_scale, 190.0 * _ui_scale)
	var hand_minimum_height := maxf(_hand_surface.custom_minimum_size.y, _hand_surface.get_combined_minimum_size().y)
	var board_minimum_height := maxf(64.0 * _ui_scale, minf(110.0 * _ui_scale, shell_height * 0.16))
	var bottom_reserve := action_bar_height + hand_minimum_height + board_minimum_height + 20.0 * _ui_scale
	var available_top_height := maxf(48.0 * _ui_scale, shell_height - bottom_reserve)
	var top_content_height := maxf(_top_strip.custom_minimum_size.y, _top_strip.get_combined_minimum_size().y)
	var top_height := minf(top_content_height, available_top_height)
	_top_scroll.offset_left = 0.0
	_top_scroll.offset_top = 0.0
	_top_scroll.offset_right = 0.0
	_top_scroll.offset_bottom = top_height
	_decision_row.offset_left = 0.0
	_decision_row.offset_top = top_height + 5.0 * _ui_scale
	_decision_row.offset_right = 0.0
	_decision_row.offset_bottom = -4.0 * _ui_scale
	_commit_panel.offset_left = 0.0
	_commit_panel.offset_right = 0.0
	_commit_panel.offset_top = -commit_height
	_commit_panel.offset_bottom = 0.0
	_decision_row.vertical = true
	_action_panel.custom_minimum_size = Vector2(0.0, action_bar_height)
	_action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_panel.size_flags_vertical = Control.SIZE_FILL
	_hand_surface.size_flags_vertical = Control.SIZE_FILL
	_board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_scroll.custom_minimum_size.y = 0.0
	var inspection_scroll := find_child("BattleInspectionScroll", true, false) as ScrollContainer
	if inspection_scroll != null:
		inspection_scroll.custom_minimum_size.y = 30.0 * _ui_scale
	var board_width := _board_surface.size.x if _board_surface.size.x > 0.0 else available_width
	var hand := find_child("BattleHandTiles", true, false) as HBoxContainer
	if hand != null:
		var count := maxi(1, hand.get_child_count())
		var tile_cap := clampf(size.y * 0.12, 52.0 * _ui_scale, 96.0 * _ui_scale)
		var hand_width := _hand_scroll.size.x if _hand_scroll.size.x > 0.0 else board_width
		var hand_separation := float(hand.get_theme_constant("separation"))
		var tile_width := clampf((hand_width - (count - 1) * hand_separation) / count, 44.0 * _ui_scale, tile_cap)
		for tile in hand.get_children():
			if tile is TileFaceButton:
				var tile_size := Vector2(tile_width, tile_width * 1.5 + (18.0 if tile.status_badge.visible else 0.0))
				if not tile.custom_minimum_size.is_equal_approx(tile_size):
					tile.custom_minimum_size = tile_size
	var table := find_child("BattleTable", true, false) as Control
	if table != null:
		table.custom_minimum_size.y = clampf(size.y * 0.12, 48.0, 110.0)
	var zones := find_child("BattleZones", true, false) as BoxContainer
	if zones != null:
		zones.vertical = board_width < 650.0 * _ui_scale
	_commit_row.vertical = available_width < 520.0 * _ui_scale
	_commit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _commit_row.vertical else Control.SIZE_FILL
	for node in find_children("*", "Button", true, false):
		if node.has_meta("run_action_id"):
			node.custom_minimum_size.x = minf(200.0 * _ui_scale, maxf(148.0 * _ui_scale, available_width * 0.34))
