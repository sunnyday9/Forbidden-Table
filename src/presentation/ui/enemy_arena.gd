class_name EnemyArena
extends PanelContainer

const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

const INTENT_TIMING_KEY := "UI_ENEMY_ARENA_0001"

var _ui_scale := 1.0
var _locale := "en"
var _enemy_name := ""
var _hp_label: Label
var _enemy_name_label: Label
var _intent_label: Label
var _intent_detail: Label
var _intent_timing: Label
var _enemy_health_bar: ProgressBar
var _pressure_label: Label
var _pressure_bar: ProgressBar
var _stability_value: Label
var _wall_count: Label
var _recent_action_label: Label
var _recent_action_scroll: ScrollContainer
var _enemy_avatar: EnemySigil
var _player_anchor_mark: PlayerSeatMark
var _wall_stack_mark: WallStackMark


func _init() -> void:
	name = "EnemyArena"
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_build_shell()
	configure({})


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _enemy_avatar != null:
		_apply_responsive_dimensions()
		_update_label_theme()


func configure(model: Dictionary) -> void:
	_locale = _normalize_locale(str(model.get("locale", _locale)))
	_ui_scale = clampf(float(model.get("ui_scale", _ui_scale)), 0.75, 2.0)
	theme = ForbiddenThemeScript.create_theme(_locale, _ui_scale)
	_apply_outer_style()
	_apply_scaled_layout()

	_enemy_name = str(model.get("enemy_name", ""))
	_enemy_name_label.text = _enemy_name
	_enemy_avatar.enemy_id = str(model.get("enemy_id", ""))
	_enemy_avatar.tooltip_text = _enemy_name

	var hp := int(model.get("hp", 0))
	var maximum_hp := maxi(1, int(model.get("max_hp", 1)))
	_enemy_health_bar.max_value = maximum_hp
	_enemy_health_bar.value = hp
	_hp_label.text = str(model.get("hp_text", ""))
	if _hp_label.text.is_empty() and not _enemy_name.is_empty():
		_hp_label.text = LocalizationCatalogScript.format("UI_BATTLE_VIEW_0003", [_enemy_name, hp, maximum_hp])

	var intent_name := str(model.get("intent_name", ""))
	_intent_label.text = intent_name if not intent_name.is_empty() else LocalizationCatalogScript.word_text("UNAVAILABLE")
	_intent_detail.text = str(model.get("intent_detail", ""))
	_intent_detail.visible = not _intent_detail.text.is_empty()
	_intent_timing.text = LocalizationCatalogScript.text(INTENT_TIMING_KEY)
	_intent_timing.visible = not intent_name.is_empty()

	var pressure_limit := maxi(1, int(model.get("pressure_limit", 1)))
	var pressure := int(model.get("pressure", 0))
	_pressure_bar.max_value = pressure_limit
	_pressure_bar.value = pressure
	_pressure_label.text = LocalizationCatalogScript.format("UI_ENEMY_ARENA_0002", [pressure, pressure_limit])
	_stability_value.text = LocalizationCatalogScript.format("UI_ENEMY_ARENA_0003", [int(model.get("stability", 0))])
	_wall_count.text = LocalizationCatalogScript.format("UI_ENEMY_ARENA_0004", [int(model.get("wall_count", 0))])
	_wall_count.tooltip_text = _wall_count.text
	_update_label_theme()
	_update_arena_accessibility()


func recent_action(text: String) -> void:
	var changed := _recent_action_label.text != text
	_recent_action_label.text = text
	_recent_action_label.visible = not text.is_empty()
	_recent_action_scroll.visible = not text.is_empty()
	if changed:
		_recent_action_scroll.scroll_vertical = 0


func enemy_anchor() -> Vector2:
	return _global_center(_enemy_avatar)


func player_anchor() -> Vector2:
	return _global_center(_player_anchor_mark)


func wall_anchor() -> Vector2:
	return _global_center(_wall_stack_mark)


func _build_shell() -> void:
	var content := VBoxContainer.new()
	content.name = "EnemyArenaContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	var confrontation := BoxContainer.new()
	confrontation.name = "ConfrontationRow"
	confrontation.vertical = false
	confrontation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confrontation.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confrontation.add_theme_constant_override("separation", 8)
	confrontation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(confrontation)
	var opponent_strip := BoxContainer.new()
	opponent_strip.name = "OpponentStrip"
	opponent_strip.vertical = false
	opponent_strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	opponent_strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	opponent_strip.add_theme_constant_override("separation", 8)
	opponent_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confrontation.add_child(opponent_strip)

	_enemy_avatar = EnemySigil.new()
	_enemy_avatar.name = "EnemyAvatar"
	_enemy_avatar.custom_minimum_size = Vector2(84.0, 68.0)
	_enemy_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_enemy_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opponent_strip.add_child(_enemy_avatar)

	var identity := VBoxContainer.new()
	identity.name = "EnemyIdentity"
	identity.custom_minimum_size.x = 156.0
	identity.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 1)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opponent_strip.add_child(identity)

	_enemy_name_label = Label.new()
	_enemy_name_label.name = "EnemyName"
	_enemy_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enemy_name_label.clip_text = false
	identity.add_child(_enemy_name_label)

	_hp_label = Label.new()
	_hp_label.name = "BattleEnemyHP"
	_hp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hp_label.clip_text = false
	identity.add_child(_hp_label)

	_enemy_health_bar = ProgressBar.new()
	_enemy_health_bar.name = "EnemyHealthBar"
	_enemy_health_bar.show_percentage = false
	_enemy_health_bar.custom_minimum_size.y = 5.0
	_enemy_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(_enemy_health_bar)

	var intent_panel := PanelContainer.new()
	intent_panel.name = "EnemyIntentCard"
	intent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intent_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	intent_panel.custom_minimum_size.x = 205.0
	intent_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confrontation.add_child(intent_panel)
	_apply_panel_surface(intent_panel, "table", 5.0, 3.0)

	var intent_content := VBoxContainer.new()
	intent_content.name = "EnemyIntentContent"
	intent_content.add_theme_constant_override("separation", 1)
	intent_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intent_panel.add_child(intent_content)

	_intent_label = Label.new()
	_intent_label.name = "BattleIntentType"
	_intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intent_label.clip_text = false
	intent_content.add_child(_intent_label)

	_intent_detail = Label.new()
	_intent_detail.name = "BattleIntentDetail"
	_intent_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intent_detail.clip_text = false
	intent_content.add_child(_intent_detail)

	_intent_timing = Label.new()
	_intent_timing.name = "IntentTiming"
	_intent_timing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intent_timing.clip_text = false
	intent_content.add_child(_intent_timing)

	var status_rail := BoxContainer.new()
	status_rail.name = "PlayerBattleStatus"
	status_rail.vertical = false
	status_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_rail.add_theme_constant_override("separation", 6)
	status_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(status_rail)

	var player_panel := PanelContainer.new()
	player_panel.name = "PlayerStateCue"
	player_panel.custom_minimum_size.x = 126.0
	player_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_rail.add_child(player_panel)
	_apply_panel_surface(player_panel, "raised", 5.0, 2.0)
	var player_row := HBoxContainer.new()
	player_row.name = "PlayerStateContent"
	player_row.add_theme_constant_override("separation", 5)
	player_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_panel.add_child(player_row)
	_player_anchor_mark = PlayerSeatMark.new()
	_player_anchor_mark.name = "PlayerAnchorMark"
	_player_anchor_mark.custom_minimum_size = Vector2(22.0, 20.0)
	_player_anchor_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_row.add_child(_player_anchor_mark)
	_stability_value = Label.new()
	_stability_value.name = "PlayerStabilityValue"
	_stability_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stability_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stability_value.clip_text = false
	player_row.add_child(_stability_value)

	var pressure_panel := PanelContainer.new()
	pressure_panel.name = "PlayerPressureCue"
	pressure_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pressure_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pressure_panel.custom_minimum_size.x = 220.0
	pressure_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_rail.add_child(pressure_panel)
	_apply_panel_surface(pressure_panel, "lacquer", 6.0, 2.0)
	var pressure_content := VBoxContainer.new()
	pressure_content.name = "PlayerPressureContent"
	pressure_content.add_theme_constant_override("separation", 1)
	pressure_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pressure_panel.add_child(pressure_content)
	_pressure_label = Label.new()
	_pressure_label.name = "PlayerPressureValue"
	_pressure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pressure_label.clip_text = false
	pressure_content.add_child(_pressure_label)
	_pressure_bar = ProgressBar.new()
	_pressure_bar.name = "PlayerPressureBar"
	_pressure_bar.show_percentage = false
	_pressure_bar.custom_minimum_size.y = 5.0
	_pressure_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pressure_content.add_child(_pressure_bar)

	var wall_panel := PanelContainer.new()
	wall_panel.name = "DrawWallSource"
	wall_panel.custom_minimum_size.x = 122.0
	wall_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wall_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_rail.add_child(wall_panel)
	_apply_panel_surface(wall_panel, "paper", 5.0, 2.0)
	var wall_row := HBoxContainer.new()
	wall_row.name = "DrawWallContent"
	wall_row.add_theme_constant_override("separation", 5)
	wall_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall_panel.add_child(wall_row)
	_wall_stack_mark = WallStackMark.new()
	_wall_stack_mark.name = "WallStackMark"
	_wall_stack_mark.custom_minimum_size = Vector2(26.0, 22.0)
	_wall_stack_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall_row.add_child(_wall_stack_mark)
	_wall_count = Label.new()
	_wall_count.name = "DrawWallCount"
	_wall_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wall_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wall_count.clip_text = false
	wall_row.add_child(_wall_count)

	_recent_action_scroll = ScrollContainer.new()
	_recent_action_scroll.name = "RecentActionScroll"
	_recent_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recent_action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_recent_action_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recent_action_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_recent_action_scroll.custom_minimum_size.y = 28.0
	_recent_action_scroll.visible = false
	_recent_action_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_recent_action_scroll)
	_recent_action_label = Label.new()
	_recent_action_label.name = "RecentAction"
	_recent_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recent_action_label.clip_text = false
	_recent_action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recent_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recent_action_scroll.add_child(_recent_action_label)


func _apply_scaled_layout() -> void:
	var scaled_separation := roundi(4.0 * _ui_scale)
	var content := get_node_or_null("EnemyArenaContent") as VBoxContainer
	if content != null:
		content.add_theme_constant_override("separation", scaled_separation)
		content.add_theme_constant_override("h_separation", scaled_separation)
	var confrontation := get_node_or_null("EnemyArenaContent/ConfrontationRow") as BoxContainer
	if confrontation != null:
		confrontation.add_theme_constant_override("separation", roundi(8.0 * _ui_scale))
	var opponent_strip := get_node_or_null("EnemyArenaContent/ConfrontationRow/OpponentStrip") as BoxContainer
	if opponent_strip != null:
		opponent_strip.add_theme_constant_override("separation", roundi(8.0 * _ui_scale))
	var status_rail := get_node_or_null("EnemyArenaContent/PlayerBattleStatus") as BoxContainer
	if status_rail != null:
		status_rail.add_theme_constant_override("separation", roundi(6.0 * _ui_scale))
	var identity := get_node_or_null("EnemyArenaContent/ConfrontationRow/OpponentStrip/EnemyIdentity") as Control
	if identity != null:
		identity.custom_minimum_size.x = 156.0 * _ui_scale
	var intent_panel := get_node_or_null("EnemyArenaContent/ConfrontationRow/EnemyIntentCard") as Control
	if intent_panel != null:
		intent_panel.custom_minimum_size.x = 205.0 * _ui_scale
		_apply_panel_surface(intent_panel as PanelContainer, "table", 5.0, 3.0)
	var player_panel := get_node_or_null("EnemyArenaContent/PlayerBattleStatus/PlayerStateCue") as PanelContainer
	if player_panel != null:
		player_panel.custom_minimum_size.x = 126.0 * _ui_scale
		_apply_panel_surface(player_panel, "raised", 5.0, 2.0)
	var pressure_panel := get_node_or_null("EnemyArenaContent/PlayerBattleStatus/PlayerPressureCue") as PanelContainer
	if pressure_panel != null:
		pressure_panel.custom_minimum_size.x = 220.0 * _ui_scale
		_apply_panel_surface(pressure_panel, "lacquer", 6.0, 2.0)
	var wall_panel := get_node_or_null("EnemyArenaContent/PlayerBattleStatus/DrawWallSource") as PanelContainer
	if wall_panel != null:
		wall_panel.custom_minimum_size.x = 122.0 * _ui_scale
		_apply_panel_surface(wall_panel, "paper", 5.0, 2.0)
	if _player_anchor_mark != null:
		_player_anchor_mark.custom_minimum_size = Vector2(22.0, 20.0) * _ui_scale
	if _wall_stack_mark != null:
		_wall_stack_mark.custom_minimum_size = Vector2(26.0, 22.0) * _ui_scale
	if _recent_action_scroll != null:
		_recent_action_scroll.custom_minimum_size.y = 28.0 * _ui_scale
	custom_minimum_size = Vector2(0.0, 146.0 * _ui_scale)
	_apply_responsive_dimensions()


func _apply_outer_style() -> void:
	ForbiddenThemeScript.style_panel(self, "enemy")
	_apply_panel_surface(self, "enemy", 10.0, 5.0)


func _apply_panel_surface(panel: PanelContainer, surface: String, horizontal_pad: float, vertical_pad: float) -> void:
	ForbiddenThemeScript.style_panel(panel, surface)
	var themed_style := panel.get_theme_stylebox("panel")
	if themed_style is StyleBoxFlat:
		var local_style := (themed_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		local_style.content_margin_left = roundi(horizontal_pad * _ui_scale)
		local_style.content_margin_right = roundi(horizontal_pad * _ui_scale)
		local_style.content_margin_top = roundi(vertical_pad * _ui_scale)
		local_style.content_margin_bottom = roundi(vertical_pad * _ui_scale)
		panel.add_theme_stylebox_override("panel", local_style)


func _update_label_theme() -> void:
	_style_label(_enemy_name_label, "heading", "text", true)
	_style_label(_hp_label, "caption", "muted")
	_style_label(_intent_label, "body", "brass", true)
	_style_label(_intent_detail, "secondary", "text")
	_style_label(_intent_timing, "caption", "focus", true)
	_style_label(_pressure_label, "secondary", "text", true)
	_style_label(_stability_value, "secondary", "focus", true)
	_style_label(_wall_count, "secondary", "text", true)
	_style_label(_recent_action_label, "secondary", "success")

	_apply_bar_style(_enemy_health_bar, "error", 4.0)
	_apply_bar_style(_pressure_bar, "brass", 4.0)
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# The receipt is informational, but its scrollbar must receive pointer
	# input so longer resolved batches remain readable.
	_recent_action_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_recent_action_scroll.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_STOP


func _style_label(label: Label, role: String, color_token: String, medium: bool = false) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", ForbiddenThemeScript.font_size_for(role, _ui_scale))
	label.add_theme_color_override("font_color", ForbiddenThemeScript.color(color_token))
	var font: Font = theme.get_font("font", "Button" if medium else "Label")
	if font != null:
		label.add_theme_font_override("font", font)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE


func _apply_bar_style(bar: ProgressBar, fill_token: String, base_height: float) -> void:
	if bar == null:
		return
	bar.custom_minimum_size.y = base_height * _ui_scale
	bar.add_theme_stylebox_override("background", _flat_style(Color("#192218"), ForbiddenThemeScript.color("edge"), 1.0 * _ui_scale))
	bar.add_theme_stylebox_override("fill", _flat_style(ForbiddenThemeScript.color(fill_token), ForbiddenThemeScript.color(fill_token), 0.0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.focus_mode = Control.FOCUS_NONE


func _flat_style(fill: Color, edge: Color, border: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.border_width_left = roundi(border)
	style.border_width_top = roundi(border)
	style.border_width_right = roundi(border)
	style.border_width_bottom = roundi(border)
	style.corner_radius_top_left = roundi(2.0 * _ui_scale)
	style.corner_radius_top_right = roundi(2.0 * _ui_scale)
	style.corner_radius_bottom_left = roundi(2.0 * _ui_scale)
	style.corner_radius_bottom_right = roundi(2.0 * _ui_scale)
	return style


func _apply_responsive_dimensions() -> void:
	var available_width := _available_layout_width()
	var is_wide := available_width >= 1200.0
	var is_stacked := available_width < 900.0
	var opponent_stacked := available_width < 360.0 * _ui_scale
	var status_stacked := available_width < 520.0 * _ui_scale
	var avatar_size := Vector2(88.0, 64.0) if is_wide else Vector2(74.0, 56.0)
	_enemy_avatar.custom_minimum_size = avatar_size * _ui_scale
	var intent_panel := get_node_or_null("EnemyArenaContent/ConfrontationRow/EnemyIntentCard") as Control
	if intent_panel != null:
		intent_panel.custom_minimum_size.x = (0.0 if opponent_stacked else (180.0 if is_stacked else 205.0)) * _ui_scale
	var identity := get_node_or_null("EnemyArenaContent/ConfrontationRow/OpponentStrip/EnemyIdentity") as Control
	if identity != null:
		identity.custom_minimum_size.x = (0.0 if opponent_stacked else (180.0 if is_wide else (112.0 if is_stacked else 156.0))) * _ui_scale
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_stacked or opponent_stacked else Control.SIZE_SHRINK_BEGIN
	var confrontation := get_node_or_null("EnemyArenaContent/ConfrontationRow") as BoxContainer
	if confrontation != null:
		confrontation.vertical = is_stacked
	var opponent_strip := get_node_or_null("EnemyArenaContent/ConfrontationRow/OpponentStrip") as BoxContainer
	if opponent_strip != null:
		opponent_strip.vertical = opponent_stacked
		opponent_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_stacked or opponent_stacked else Control.SIZE_SHRINK_BEGIN
	var status_rail := get_node_or_null("EnemyArenaContent/PlayerBattleStatus") as BoxContainer
	if status_rail != null:
		status_rail.vertical = status_stacked
		status_rail.custom_minimum_size.y = 0.0 if status_stacked else 36.0 * _ui_scale
	var player_panel := get_node_or_null("EnemyArenaContent/PlayerBattleStatus/PlayerStateCue") as PanelContainer
	var pressure_panel := get_node_or_null("EnemyArenaContent/PlayerBattleStatus/PlayerPressureCue") as PanelContainer
	var wall_panel := get_node_or_null("EnemyArenaContent/PlayerBattleStatus/DrawWallSource") as PanelContainer
	var compact_status := available_width < 900.0
	if player_panel != null:
		player_panel.custom_minimum_size.x = 0.0 if status_stacked else (118.0 if compact_status else 126.0) * _ui_scale
		player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if status_stacked else Control.SIZE_FILL
	if pressure_panel != null:
		pressure_panel.custom_minimum_size.x = 0.0 if status_stacked else (205.0 if compact_status else 220.0) * _ui_scale
		pressure_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if wall_panel != null:
		wall_panel.custom_minimum_size.x = 0.0 if status_stacked else (116.0 if compact_status else 122.0) * _ui_scale
		wall_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if status_stacked else Control.SIZE_FILL
	var minimum_height := 125.0 if is_wide else 110.0
	custom_minimum_size = Vector2(0.0, 0.0 if is_stacked else minimum_height * _ui_scale)
	queue_sort()


func _available_layout_width() -> float:
	var available_width := size.x
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Control:
			var ancestor_control := ancestor as Control
			if ancestor_control.size.x > 0.0:
				available_width = ancestor_control.size.x if available_width <= 0.0 else minf(available_width, ancestor_control.size.x)
		ancestor = ancestor.get_parent()
	return available_width


func _global_center(control: Control) -> Vector2:
	if control == null or not is_instance_valid(control):
		return get_global_rect().get_center()
	return control.get_global_rect().get_center()


func _update_arena_accessibility() -> void:
	_enemy_avatar.tooltip_text = _enemy_name
	_enemy_health_bar.tooltip_text = _hp_label.text
	_pressure_bar.tooltip_text = _pressure_label.text
	_player_anchor_mark.tooltip_text = LocalizationCatalogScript.text("UI_BATTLE_VIEW_0032")
	_wall_stack_mark.tooltip_text = _wall_count.text


func _normalize_locale(locale: String) -> String:
	return "zh_CN" if locale.to_lower().begins_with("zh") else "en"


class EnemySigil extends Control:
	var enemy_id := ""

	func _draw() -> void:
		var scale_factor := minf(size.x / 116.0, size.y / 92.0)
		if scale_factor <= 0.0:
			return
		var offset := (size - Vector2(116.0, 92.0) * scale_factor) * 0.5
		draw_set_transform(offset, 0.0, Vector2.ONE * scale_factor)
		_draw_sigil()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_sigil() -> void:
		var brass := ForbiddenThemeScript.color("brass")
		var red := ForbiddenThemeScript.color("vermilion")
		var cloak := ForbiddenThemeScript.color("ink")
		var edge := ForbiddenThemeScript.color("edge")
		var center := Vector2(58.0, 43.0)
		var variant := posmod(enemy_id.hash(), 3)
		draw_arc(center, 39.0, -2.92, 2.77, 40, brass * Color(1.0, 1.0, 1.0, 0.68), 1.2, true)
		draw_arc(center, 34.0, -0.42, 2.52, 30, red * Color(1.0, 1.0, 1.0, 0.72), 1.0, true)
		draw_line(Vector2(14.0, 84.0), Vector2(101.0, 84.0), edge * Color(1.0, 1.0, 1.0, 0.75), 1.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(38.0, 48.0), Vector2(21.0, 62.0), Vector2(10.0, 84.0),
			Vector2(34.0, 77.0), Vector2(45.0, 88.0), Vector2(58.0, 82.0),
			Vector2(73.0, 89.0), Vector2(83.0, 77.0), Vector2(106.0, 83.0),
			Vector2(94.0, 60.0), Vector2(77.0, 47.0),
		]), cloak)
		# The high, broken crown and narrow shoulder line give the opponent a
		# distinct masked-spirit silhouette without relying on a stock glyph.
		draw_colored_polygon(PackedVector2Array([
			Vector2(35.0, 43.0), Vector2(26.0, 20.0), Vector2(42.0, 27.0),
			Vector2(45.0, 8.0), Vector2(57.0, 22.0), Vector2(69.0, 5.0),
			Vector2(72.0, 25.0), Vector2(88.0, 15.0), Vector2(80.0, 42.0),
			Vector2(74.0, 59.0), Vector2(43.0, 60.0),
		]), cloak.lightened(0.08))
		draw_polyline(PackedVector2Array([
			Vector2(26.0, 20.0), Vector2(42.0, 27.0), Vector2(45.0, 8.0),
			Vector2(57.0, 22.0), Vector2(69.0, 5.0), Vector2(72.0, 25.0),
			Vector2(88.0, 15.0), Vector2(80.0, 42.0),
		]), brass * Color(1.0, 1.0, 1.0, 0.9), 1.2, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(39.0, 31.0), Vector2(48.0, 25.0), Vector2(64.0, 25.0),
			Vector2(76.0, 33.0), Vector2(72.0, 51.0), Vector2(59.0, 60.0),
			Vector2(44.0, 52.0),
		]), ForbiddenThemeScript.color("muted"))
		var left_eye := Vector2(49.0, 40.0)
		var right_eye := Vector2(66.0, 40.0)
		if variant == 1:
			left_eye.y += 1.0
		elif variant == 2:
			right_eye.y -= 1.0
		draw_line(left_eye + Vector2(-4.0, 0.0), left_eye + Vector2(4.0, 1.0), cloak, 2.0, true)
		draw_line(right_eye + Vector2(-4.0, 1.0), right_eye + Vector2(4.0, 0.0), cloak, 2.0, true)
		draw_line(Vector2(58.0, 40.0), Vector2(55.0, 50.0), red, 1.7, true)
		draw_line(Vector2(54.0, 54.0), Vector2(62.0, 54.0), cloak, 1.3, true)
		_draw_forehead_seal(brass, red)

	func _draw_forehead_seal(brass: Color, red: Color) -> void:
		var seal_center := Vector2(58.0, 31.0)
		draw_colored_polygon(PackedVector2Array([
			seal_center + Vector2(0.0, -4.0), seal_center + Vector2(4.0, 0.0),
			seal_center + Vector2(0.0, 4.0), seal_center + Vector2(-4.0, 0.0),
		]), red)
		draw_line(seal_center + Vector2(-1.5, -1.5), seal_center + Vector2(1.5, 1.5), brass, 1.0, true)


class PlayerSeatMark extends Control:
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.36
		var focus := ForbiddenThemeScript.color("focus")
		var brass := ForbiddenThemeScript.color("brass")
		draw_arc(center, radius, -PI * 0.78, PI * 0.78, 24, focus * Color(1.0, 1.0, 1.0, 0.9), 1.4, true)
		draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), brass, 1.2, true)
		draw_line(center + Vector2(-radius, radius * 0.45), center + Vector2(radius, radius * 0.45), focus, 1.2, true)
		draw_circle(center, 2.0, brass)


class WallStackMark extends Control:
	func _draw() -> void:
		var glyph_scale := minf(size.x / 26.0, size.y / 22.0)
		var width := minf(size.x * 0.62, 17.0 * glyph_scale)
		var height := minf(size.y * 0.78, 18.0 * glyph_scale)
		var base := Vector2((size.x - width) * 0.5 - 2.0, (size.y - height) * 0.5 + 2.0)
		var tile_side := ForbiddenThemeScript.color("paper")
		var tile_face := ForbiddenThemeScript.color("muted")
		var tile_edge := ForbiddenThemeScript.color("brass")
		for offset_index in range(3):
			var offset := Vector2(float(offset_index) * 3.0, -float(offset_index) * 2.0) * glyph_scale
			var rect := Rect2(base + offset, Vector2(width, height))
			draw_rect(Rect2(rect.position + Vector2(2.0, 2.0) * glyph_scale, rect.size), tile_side)
			draw_rect(rect, tile_face)
			draw_rect(rect, tile_edge, false, glyph_scale)
			draw_line(rect.position + Vector2(3.0, 4.0) * glyph_scale, rect.position + Vector2(width - 3.0, 4.0) * glyph_scale, tile_edge * Color(1.0, 1.0, 1.0, 0.85), glyph_scale, true)
