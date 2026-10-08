class_name RunJourneyView
extends Control

signal selection_changed(action_id: String)
signal action_activated(action_id: String)
signal focus_changed(action_id: String)
signal content_minimum_changed

const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const MotionFeedbackScript = preload("res://src/presentation/ui/motion_feedback.gd")
const PlayerActionTextScript = preload("res://src/presentation/ui/player_action_text.gd")
const RunMapViewScript = preload("res://src/presentation/ui/run_map_view.gd")
const TileFaceButtonScript = preload("res://src/presentation/ui/tile_face_button.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const CharacterDefinitionScript = preload("res://src/content/definitions/character_definition.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")

class RewardKindIcon extends Control:
	var kind := ""
	var accent := Color.WHITE
	var secondary := Color.WHITE

	func configure(initial_kind: String, primary_color: Color, secondary_color: Color, ui_scale: float) -> void:
		kind = initial_kind
		accent = primary_color
		secondary = secondary_color
		custom_minimum_size = Vector2(44.0, 44.0) * ui_scale
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.34
		match kind:
			"RELIC":
				var diamond := PackedVector2Array([center + Vector2(0.0, -radius), center + Vector2(radius * 0.72, 0.0), center + Vector2(0.0, radius), center + Vector2(-radius * 0.72, 0.0)])
				draw_colored_polygon(diamond, accent)
				draw_circle(center, radius * 0.16, secondary)
			"RUN_TECHNIQUE":
				var bolt := PackedVector2Array([center + Vector2(radius * 0.1, -radius), center + Vector2(-radius * 0.52, radius * 0.05), center + Vector2(-radius * 0.08, radius * 0.05), center + Vector2(-radius * 0.24, radius), center + Vector2(radius * 0.56, -radius * 0.08), center + Vector2(radius * 0.12, -radius * 0.08)])
				draw_colored_polygon(bolt, accent)
			"RULE_BREAKER":
				draw_arc(center, radius, 0.28, TAU - 0.28, 32, accent, maxf(2.0, size.x * 0.055), true)
				draw_line(center + Vector2(-radius * 0.64, radius * 0.55), center + Vector2(radius * 0.65, -radius * 0.58), secondary, maxf(2.0, size.x * 0.07), true)
			"SKIP":
				draw_circle(center, radius, accent)
				draw_arc(center, radius * 0.62, 0.0, TAU, 32, secondary, maxf(1.5, size.x * 0.045), true)
			_:
				draw_rect(Rect2(center - Vector2(radius * 0.62, radius * 0.82), Vector2(radius * 1.24, radius * 1.64)), accent, false, maxf(2.0, size.x * 0.05), true)
				draw_circle(center, radius * 0.2, secondary)

const PORTRAIT_TEXTURE_PATH := "res://assets/ui/art/character-triptych.png"
const COMPACT_LAYOUT_BREAKPOINT := 840.0
const CHARACTER_PORTRAITS := {
	"base.character.reserve": 0,
	"base.character.sequence": 1,
	"alpha.character.harbor_reader": 2,
}
const ACT_ONE_EVENT_CHOICE_LABEL_KEYS := [
	{"trade_gold": "CONTENT_SCALE_0003", "leave": "CONTENT_SCALE_0004"},
	{"take_advance": "CONTENT_SCALE_0005", "leave": "CONTENT_SCALE_0006"},
	{"exchange": "CONTENT_SCALE_0007", "leave": "CONTENT_SCALE_0008"},
	{"reveal_route": "CONTENT_SCALE_0009", "leave": "CONTENT_SCALE_0010"},
	{"carry_clause": "CONTENT_SCALE_0011", "leave": "CONTENT_SCALE_0012"},
	{"remember_rule": "CONTENT_SCALE_0013", "leave": "CONTENT_SCALE_0014"},
]
const ACT_TWO_EVENT_CHOICE_LABEL_KEYS := [
	{"repair_with_token": "CONTENT_ACT_TWO_0016", "leave": "CONTENT_ACT_TWO_0017"},
	{"take_wager": "CONTENT_ACT_TWO_0018", "leave": "CONTENT_ACT_TWO_0019"},
	{"trade_gold": "CONTENT_ACT_TWO_0020", "leave": "CONTENT_ACT_TWO_0021"},
	{"reveal_route": "CONTENT_ACT_TWO_0022", "leave": "CONTENT_ACT_TWO_0023"},
	{"carry_clause": "CONTENT_ACT_TWO_0024", "leave": "CONTENT_ACT_TWO_0025"},
	{"study_yaku": "CONTENT_ACT_TWO_0026", "leave": "CONTENT_ACT_TWO_0027"},
]
const ACT_TWO_ADDITIONAL_EVENT_CHOICE_LABEL_KEYS := [
	{"repair_with_token": "CONTENT_ACT_TWO_0028", "leave": "CONTENT_ACT_TWO_0029"},
	{"stake_hidden_account": "CONTENT_ACT_TWO_0030", "leave": "CONTENT_ACT_TWO_0031"},
	{"trade_margin": "CONTENT_ACT_TWO_0032", "leave": "CONTENT_ACT_TWO_0033"},
	{"reveal_route": "CONTENT_ACT_TWO_0034", "leave": "CONTENT_ACT_TWO_0035"},
	{"carry_clause": "CONTENT_ACT_TWO_0036", "leave": "CONTENT_ACT_TWO_0037"},
	{"cross_reference": "CONTENT_ACT_TWO_0038", "leave": "CONTENT_ACT_TWO_0039"},
]

var selected_action_id := ""
var focused_action_id := ""
var _controller
var _state
var _actions: Array = []
var _actions_by_id: Dictionary = {}
var _action_label: Callable
var _action_tooltip: Callable
var _action_details: Callable
var _pretty_id: Callable
var _pretty_words_callable: Callable
var _locale := "en"
var _ui_scale := 1.0
var _presentation_mode := "NORMAL"
var _reduced_motion := false
var _last_phase := ""
var _last_reward_ids: Array[String] = []
var _content_scroll: ScrollContainer
var _content_root: VBoxContainer
var _responsive_layouts: Array[BoxContainer] = []
var _responsive_grids: Array[Dictionary] = []
var _content_width_limit := 0.0
var _is_compact_layout := false
var _map_travel_button: Button
var _details_value: Label
var _event_choice_details: Label
var _last_preview_animation_id := ""
var _motion_feedback: MotionFeedback


func _init() -> void:
	# Copy is already resolved through Localization; controls must not translate
	# it a second time (which also doubles pseudo-localization expansion).
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_layout_resized)
	_build_shell()


func configure(action_label: Callable, action_tooltip: Callable, action_details: Callable, pretty_id: Callable, pretty_words: Callable) -> void:
	_action_label = action_label
	_action_tooltip = action_tooltip
	_action_details = action_details
	_pretty_id = pretty_id
	_pretty_words_callable = pretty_words
	_build_shell()


func set_presentation_preferences(locale: String = "en", ui_scale: float = 1.0, presentation_mode: String = "NORMAL", reduced_motion: bool = false) -> void:
	_locale = "zh_CN" if locale.to_lower().begins_with("zh") else "en"
	_ui_scale = clampf(ui_scale, 1.0, 1.5)
	_presentation_mode = presentation_mode.to_upper()
	_reduced_motion = reduced_motion
	theme = ForbiddenThemeScript.create_theme(_locale, _ui_scale)
	_update_responsive_layouts()
	if _motion_feedback != null:
		_motion_feedback.configure(_presentation_mode, _reduced_motion)


func render(controller, descriptors: Array = [], preferred_focus_id: String = "") -> void:
	_build_shell()
	var prior_phase := _last_phase
	_controller = controller
	if _controller == null:
		_state = null
		_actions = []
		_actions_by_id.clear()
		selected_action_id = ""
		focused_action_id = ""
		_last_phase = ""
		_clear_content()
		return
	_state = _controller.domain.state
	_actions = descriptors.duplicate(true) if not descriptors.is_empty() else _controller.action_descriptors()
	_actions_by_id.clear()
	for action in _actions:
		if action is Dictionary:
			_actions_by_id[str(action.get("id", ""))] = action
	var phase := str(_state.phase)
	if prior_phase != phase:
		selected_action_id = ""
		_last_reward_ids.clear()
		_last_preview_animation_id = ""
		if _motion_feedback != null:
			_motion_feedback.cancel()
	_last_phase = phase
	if not _actions_by_id.has(selected_action_id):
		selected_action_id = ""
	if not preferred_focus_id.is_empty() and _actions_by_id.has(preferred_focus_id):
		focused_action_id = preferred_focus_id
	if not _actions_by_id.has(focused_action_id):
		focused_action_id = str(_controller.snapshot().get("focused_action_id", ""))
	if phase == RunPhaseScript.MAP_CHOICE:
		for entry_action in _actions:
			if str(entry_action.get("kind", "")) in ["ENTER_EVENT", "ENTER_SHOP", "ENTER_WORKSHOP"]:
				focused_action_id = str(entry_action.id)
				break
	if not _actions_by_id.has(focused_action_id) and not _actions.is_empty():
		focused_action_id = str(_actions[0].get("id", ""))
	_update_details(_preview_action())
	_build_phase_content()
	_update_choice_styles()
	if phase == RunPhaseScript.WORKSHOP:
		var preview := _preview_action()
		var preview_id := str(preview.get("id", ""))
		if preview_id != _last_preview_animation_id and str(preview.get("kind", "")) == "WORKSHOP_SERVICE":
			_last_preview_animation_id = preview_id
			call_deferred("_play_workshop_preview")


func selected_action() -> Dictionary:
	return _actions_by_id.get(selected_action_id, {}).duplicate(true)


func focused_action() -> Dictionary:
	return _actions_by_id.get(focused_action_id, {}).duplicate(true)


func clear_selection() -> void:
	_clear_selection()
	_update_map_travel_button()


func cancel_local_state() -> bool:
	if not selected_action_id.is_empty():
		var previous := selected_action_id
		selected_action_id = ""
		_update_choice_styles()
		_update_details(_preview_action())
		selection_changed.emit("")
		_update_map_travel_button()
		var previous_button := action_button(previous)
		if previous_button != null and previous_button.is_inside_tree():
			previous_button.grab_focus()
		return true
	return false


func action_button(action_id: String) -> Button:
	for button in find_children("*", "Button", true, false):
		var candidate := button as Button
		if str(candidate.get_meta("run_action_id", "")) == action_id:
			return candidate
	return null


func main_scroll() -> ScrollContainer:
	return _content_scroll


func set_content_width_limit(width: float) -> void:
	var normalized := maxf(0.0, width)
	if is_equal_approx(_content_width_limit, normalized):
		return
	_content_width_limit = normalized
	_update_responsive_layouts()
	_update_character_choice_labels()
	call_deferred("_update_responsive_layouts")


func character_content_minimum_height() -> float:
	if _content_root == null:
		return 0.0
	return _content_root.get_combined_minimum_size().y


func details_label() -> Label:
	return _details_value


func _build_shell() -> void:
	if _content_scroll != null:
		return
	_motion_feedback = MotionFeedbackScript.new()
	_motion_feedback.name = "MotionFeedback"
	add_child(_motion_feedback)
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "RunJourneyScroll"
	_content_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_content_scroll.follow_focus = true
	_content_scroll.focus_mode = Control.FOCUS_ALL
	add_child(_content_scroll)
	_content_root = VBoxContainer.new()
	_content_root.name = "RunJourneyContent"
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 8)
	_content_scroll.add_child(_content_root)


func _clear_content() -> void:
	if _content_root == null:
		return
	for child in _content_root.get_children():
		_content_root.remove_child(child)
		child.queue_free()


func _build_phase_content() -> void:
	_clear_content()
	_responsive_layouts.clear()
	_responsive_grids.clear()
	if _controller == null or _state == null:
		return
	var phase := str(_state.phase)
	match phase:
		RunPhaseScript.CHARACTER_SELECT:
			_build_character_choices()
		RunPhaseScript.CONTRACT_SELECT:
			_build_action_browser(_actions, LocalizationCatalogScript.text("UI_RUN_JOURNEY_0002"), true)
		RunPhaseScript.MAP_CHOICE:
			_build_map()
		RunPhaseScript.REWARD_CHOICE, RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD:
			var picking_target := not _actions.is_empty() and str(_actions[0].get("kind", "")) == "REWARD_TARGET"
			_build_action_browser(_actions, LocalizationCatalogScript.text("UI_RC7_REWARD_TARGET_PROMPT") if picking_target else _title_for_phase(phase), false, true)
		RunPhaseScript.EVENT:
			_build_event()
		RunPhaseScript.SHOP:
			_build_shop()
		RunPhaseScript.WORKSHOP:
			_build_workshop()
		_:
			_build_action_browser(_actions, LocalizationCatalogScript.text("UI_RUN_SCENE_0045"), false)
	_apply_theme_to_content()
	_update_responsive_layouts()
	call_deferred("_update_responsive_layouts")
	call_deferred("_emit_content_minimum_changed")


func _build_character_choices() -> void:
	if _actions.any(func(action): return str(action.get("kind", "")) == "CHARACTER_SUIT"):
		_build_character_suit_choices()
		return
	var roster: Array = []
	for definition in _controller.domain.content_registry.enumerate():
		if definition != null and definition.get_script() == CharacterDefinitionScript:
			roster.append(definition)
	roster.sort_custom(func(left, right): return str(left.content_id) < str(right.content_id))
	var cards_center := CenterContainer.new()
	cards_center.name = "CharacterCardsCenter"
	cards_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content_root.add_child(cards_center)
	var grid := GridContainer.new()
	grid.name = "CharacterCards"
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	_register_responsive_grid(grid, 224.0, 3, 1.0, 480.0)
	cards_center.add_child(grid)
	for definition in roster:
		var action_id := "character:%s" % str(definition.content_id)
		var action: Dictionary = _actions_by_id.get(action_id, {})
		var is_available := not action.is_empty()
		var card := PanelContainer.new()
		card.name = "CharacterCard_%s" % str(definition.content_id).get_slice(".", str(definition.content_id).get_slice_count(".") - 1).to_pascal_case()
		card.custom_minimum_size = Vector2(0.0, 320.0 * _ui_scale)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ForbiddenThemeScript.style_panel(card, "lacquer", action_id == selected_action_id)
		grid.add_child(card)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 6)
		card.add_child(stack)
		var portrait := TextureRect.new()
		portrait.name = "CharacterPortrait"
		portrait.custom_minimum_size = Vector2(0.0, 136.0 * _ui_scale)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		portrait.texture = _portrait_texture(str(definition.content_id))
		stack.add_child(portrait)
		var name := Label.new()
		name.text = _pretty_id_value(str(definition.content_id))
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(name, "heading")
		stack.add_child(name)
		var traits := Label.new()
		traits.name = "CharacterFacts"
		traits.text = _character_facts(definition)
		traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		traits.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_style_label(traits, "secondary")
		stack.add_child(traits)
		var choose := Button.new()
		choose.name = "InspectCharacterButton"
		choose.text = _character_action_button_label(action) if is_available else LocalizationCatalogScript.text("UI_RUN_JOURNEY_0022")
		choose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choose.disabled = not is_available
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_available:
			_configure_action_button(choose, action, true)
		else:
			ForbiddenThemeScript.style_button(choose)
		stack.add_child(choose)
		var state_label := Label.new()
		state_label.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0009") if is_available else _character_lock_reason()
		state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(state_label, "caption")
		state_label.modulate = ForbiddenThemeScript.color("muted")
		stack.add_child(state_label)


func _build_character_suit_choices() -> void:
	var panel := _new_surface("CharacterSuitChoicePanel", "raised")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content_root.add_child(panel)
	var stack := VBoxContainer.new()
	stack.name = "CharacterSuitChoiceContent"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	var heading := Label.new()
	heading.name = "CharacterSuitChoiceHeading"
	heading.text = LocalizationCatalogScript.text("UI_RUN_CHARACTER_SUIT_PROMPT")
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(heading, "heading")
	stack.add_child(heading)
	var guidance := Label.new()
	guidance.name = "CharacterSuitChoiceGuidance"
	guidance.text = LocalizationCatalogScript.text("UI_RUN_CHARACTER_SUIT_GUIDANCE")
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(guidance, "secondary")
	stack.add_child(guidance)
	var choices := GridContainer.new()
	choices.name = "CharacterSuitChoices"
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("h_separation", 8)
	choices.add_theme_constant_override("v_separation", 8)
	_register_responsive_grid(choices, 184.0, 3, 1.0)
	stack.add_child(choices)
	for action in _actions:
		if str(action.get("kind", "")) == "CHARACTER_SUIT":
			_add_choice_button(choices, action, "suit")
	for action in _actions:
		if str(action.get("kind", "")) == "CHARACTER_SUIT_BACK":
			_add_choice_button(stack, action)


func _portrait_texture(character_id: String) -> Texture2D:
	var portrait_index := int(CHARACTER_PORTRAITS.get(character_id, -1))
	if portrait_index < 0 or not ResourceLoader.exists(PORTRAIT_TEXTURE_PATH):
		return null
	var source := load(PORTRAIT_TEXTURE_PATH) as Texture2D
	if source == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	var image_size := source.get_size()
	var slice_width := image_size.x / 3.0
	atlas.region = Rect2(slice_width * portrait_index, 0.0, slice_width, image_size.y * 0.34)
	return atlas


func _character_facts(definition) -> String:
	var lines: Array[String] = []
	var character_id := str(definition.content_id)
	if character_id == "base.character.reserve":
		lines.append(LocalizationCatalogScript.text("UI_RUN_CHARACTER_POOL_RESERVE"))
	elif character_id == "base.character.sequence":
		lines.append(LocalizationCatalogScript.text("UI_RUN_CHARACTER_POOL_SEQUENCE"))
	else:
		var bias: Array = definition.starting_tile_pool_bias
		var bias_labels: Array[String] = []
		for tile_id in bias:
			bias_labels.append(_pretty_id_value(str(tile_id)))
		if not bias_labels.is_empty():
			lines.append(LocalizationCatalogScript.format("UI_RUN_CHARACTER_FACT_TILE_BIAS", [", ".join(bias_labels)]))
	var relic_id := str(definition.starting_relic_id)
	if not relic_id.is_empty():
		lines.append(LocalizationCatalogScript.format("UI_RUN_CHARACTER_FACT_RELIC", [_pretty_id_value(relic_id)]))
	var technique_id := str(definition.core_technique_id)
	if not technique_id.is_empty():
		lines.append(LocalizationCatalogScript.format("UI_RUN_CHARACTER_FACT_TECHNIQUE", [_pretty_id_value(technique_id)]))
	var passive_id := str(definition.signature_passive_id)
	if not passive_id.is_empty():
		lines.append(LocalizationCatalogScript.format("UI_RUN_CHARACTER_FACT_PASSIVE", [_pretty_id_value(passive_id)]))
	return "\n".join(lines)


func _character_lock_reason() -> String:
	if _controller.meta_progress_coordinator != null and int(_controller.meta_progress_coordinator.state.progress_count()) == 0:
		return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0021")
	return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0022")


func _build_map() -> void:
	var layout := _new_responsive_layout("RunMapDecision", 16)
	_content_root.add_child(layout)
	var map := RunMapViewScript.new()
	map.name = "RunMapView"
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.configure(_action_label, _pretty_id, _pretty_words_callable)
	map.set_presentation_preferences(_locale, _ui_scale)
	map.action_selected.connect(_on_choice_selected)
	map.action_focused.connect(_on_choice_focused)
	map.render(_controller.domain.map_definition, _state.map_state, _actions, selected_action_id, focused_action_id)
	ForbiddenThemeScript.style_panel(map, "table")
	layout.add_child(map)
	var detail_panel := _new_detail_panel("MapNodeDetails")
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(detail_panel)
	_details_value = detail_panel.find_child("SelectedActionDetails", true, false) as Label
	_map_travel_button = Button.new()
	_map_travel_button.name = "MapTravelButton"
	_map_travel_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_travel_button.custom_minimum_size.y = 48.0 * _ui_scale
	ForbiddenThemeScript.style_button(_map_travel_button, true)
	_map_travel_button.pressed.connect(func():
		if not selected_action_id.is_empty():
			action_activated.emit(selected_action_id)
	)
	detail_panel.get_child(0).add_child(_map_travel_button)
	_update_map_travel_button()
	var state_facts := Label.new()
	state_facts.name = "RunMapFacts"
	state_facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_facts.text = _map_run_facts()
	detail_panel.get_child(0).add_child(state_facts)
	for action in _actions:
		if str(action.get("kind", "")) in ["ENTER_EVENT", "ENTER_SHOP", "ENTER_WORKSHOP"]:
			_add_choice_button(detail_panel.get_child(0) as Control, action)
	_update_details(_preview_action())


func _map_run_facts() -> String:
	var map_state = _state.map_state
	var path_labels: Array[String] = []
	for node_id in map_state.ordered_path:
		var visible_payload: String = map_state.visible_payload_id(str(node_id))
		path_labels.append(_pretty_id_value(visible_payload) if not visible_payload.is_empty() else _pretty_id_value(str(map_state.node_kinds.get(node_id, "MAP"))))
	var lines := [LocalizationCatalogScript.format("UI_PLAYER_MAP_FACTS", [_state.gold, _state.refinement_tokens, _state.tile_pool.tile_instances.size()])]
	if not path_labels.is_empty():
		lines.append(" → ".join(path_labels))
	return "\n\n".join(lines)


func _tile_pool_names() -> String:
	var counts: Dictionary = {}
	for tile_instance in _state.tile_pool.tile_instances:
		var key := str(tile_instance.definition_id)
		counts[key] = int(counts.get(key, 0)) + 1
	var labels: Array[String] = []
	for key in counts:
		labels.append("%s ×%d" % [_pretty_id_value(str(key)), int(counts[key])])
	return ", ".join(labels)


func _build_event() -> void:
	var event_state = _state.event_state
	var layout := _new_responsive_layout("EventDecision", 16)
	_content_root.add_child(layout)
	var choice_panel := _choice_list_panel("EventChoices", _actions, false)
	choice_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(choice_panel)
	var detail_panel := _new_detail_panel("EventDetails")
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(detail_panel)
	_details_value = detail_panel.find_child("SelectedActionDetails", true, false) as Label
	var event_title := Label.new()
	event_title.name = "EventName"
	event_title.text = _pretty_id_value(str(event_state.event_id))
	event_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(event_title, "title")
	detail_panel.get_child(0).add_child(event_title)
	_event_choice_details = Label.new()
	_event_choice_details.name = "EventRiskRewardDetails"
	_event_choice_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_choice_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_choice_details.text = _event_detail_for_action(_preview_action())
	detail_panel.get_child(0).add_child(_event_choice_details)
	_update_details(_preview_action())


func _event_detail_for_action(action: Dictionary) -> String:
	if action.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0013")
	var choice = _state.event_state.choice_by_id(str(action.get("target_id", "")))
	if choice == null or not choice is Dictionary:
		return _action_detail_text(action)
	var parts: Array[String] = []
	var label := _event_choice_label(action, choice)
	if not label.is_empty():
		parts.append(label)
	for key in ["risk", "reward", "description", "details"]:
		var value: Variant = choice.get(key, "")
		if value is String and not str(value).is_empty():
			parts.append(LocalizationCatalogScript.display_text(str(value)))
		elif value is Array:
			for item in value:
				if item is String and not str(item).is_empty():
					parts.append(LocalizationCatalogScript.display_text(str(item)))
	return "\n\n".join(parts) if not parts.is_empty() else _action_detail_text(action)


func _build_shop() -> void:
	var layout := _new_responsive_layout("ShopDecision", 16)
	_content_root.add_child(layout)
	var offers := _new_surface("ShopOffersPanel", "raised")
	offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(offers)
	var offer_stack := VBoxContainer.new()
	offer_stack.add_theme_constant_override("separation", 8)
	offers.add_child(offer_stack)
	var offer_grid := GridContainer.new()
	offer_grid.name = "ShopOfferGrid"
	offer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_grid.add_theme_constant_override("h_separation", 8)
	offer_grid.add_theme_constant_override("v_separation", 8)
	_register_responsive_grid(offer_grid, 250.0, 2, 0.62)
	offer_stack.add_child(offer_grid)
	for action in _actions:
		if str(action.get("kind", "")) == "SHOP_OFFER":
			var available := _shop_offer_available(action)
			var offer_card := _new_surface("ShopOfferCard_%s" % str(action.get("target_id", "")).to_pascal_case(), "lacquer")
			offer_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			offer_grid.add_child(offer_card)
			var offer_card_stack := VBoxContainer.new()
			offer_card_stack.add_theme_constant_override("separation", 4)
			offer_card.add_child(offer_card_stack)
			var offer_button := _add_choice_button(offer_card_stack, action, "", not available)
			var effect_label := Label.new()
			effect_label.name = "ShopOfferEffect"
			effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var effect_summary := "\n".join(PackedStringArray(PlayerActionTextScript.shop_offer_effect_lines(_controller.domain.content_registry, action.get("details", {}))))
			effect_label.text = effect_summary
			_style_label(effect_label, "secondary")
			offer_card_stack.add_child(effect_label)
			if not available:
				var status_label := Label.new()
				status_label.name = "ShopOfferStatus"
				status_label.text = _shop_offer_status_text(action)
				status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				status_label.add_theme_color_override("font_color", ForbiddenThemeScript.color("muted"))
				offer_card_stack.add_child(status_label)
				offer_button.tooltip_text += " · " + status_label.text
	var shop_state = _state.shop_state
	var shop_summary := Label.new()
	shop_summary.name = "ShopAvailabilitySummary"
	shop_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_summary.text = LocalizationCatalogScript.format("UI_PLAYER_MAP_FACTS", [_state.gold, _state.refinement_tokens, _state.tile_pool.tile_instances.size()])
	offer_stack.add_child(shop_summary)
	for action in _actions:
		if str(action.get("kind", "")) in ["SHOP_REFRESH", "SHOP_EXIT"]:
			_add_choice_button(offer_stack, action)
	var detail_panel := _new_detail_panel("ShopOfferDetails")
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(detail_panel)
	_details_value = detail_panel.find_child("SelectedActionDetails", true, false) as Label
	var refresh_status := Label.new()
	refresh_status.name = "ShopRefreshStatus"
	refresh_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refresh_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_status.text = LocalizationCatalogScript.template("UI_RUN_JOURNEY_0032") % int(shop_state.refreshes_remaining)
	detail_panel.get_child(0).add_child(refresh_status)
	_update_details(_preview_action())


func _shop_offer_available(action: Dictionary) -> bool:
	var details: Dictionary = action.get("details", {})
	if not PlayerActionTextScript.shop_offer_has_effect(details):
		return false
	if str(details.get("status", "AVAILABLE")) != "AVAILABLE":
		return false
	var validation = _controller.domain.validate_buy_shop_offer(str(action.get("entry_id", "")), str(action.get("target_id", "")))
	return validation != null and validation.is_valid()


func _shop_offer_status_text(action: Dictionary) -> String:
	var details: Dictionary = action.get("details", {})
	if str(details.get("status", "AVAILABLE")) == "SOLD":
		return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0024")
	if not PlayerActionTextScript.shop_offer_has_effect(details):
		return LocalizationCatalogScript.text("UI_PLAYER_SHOP_UNAVAILABLE")
	var price := int(details.get("price", 0))
	if int(_state.gold) < price:
		return LocalizationCatalogScript.format("UI_RUN_JOURNEY_0025", [price, int(_state.gold)])
	return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0022")


func _build_workshop() -> void:
	var layout := _new_responsive_layout("WorkshopDecision", 16)
	_content_root.add_child(layout)
	var action_panel := _new_surface("WorkshopActionsPanel", "raised")
	action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(action_panel)
	var action_stack := VBoxContainer.new()
	action_stack.name = "WorkshopChoiceList"
	action_stack.add_theme_constant_override("separation", 8)
	action_panel.add_child(action_stack)
	var pair_grid: GridContainer = null
	if not _actions.is_empty() and str(_actions[0].get("service_id", "")) == "REMOVE_PAIR" and str(_actions[0].get("kind", "")) == "WORKSHOP_SERVICE":
		pair_grid = GridContainer.new()
		pair_grid.name = "WorkshopRemovalTypes"
		pair_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pair_grid.add_theme_constant_override("h_separation", 8)
		pair_grid.add_theme_constant_override("v_separation", 8)
		_register_responsive_grid(pair_grid, 224.0, 3, 0.58)
		action_stack.add_child(pair_grid)
	var service_id := ""
	for action in _actions:
		if str(action.get("kind", "")) in ["WORKSHOP_SELECT_SERVICE", "WORKSHOP_SELECT_TARGET", "WORKSHOP_SERVICE"]:
			service_id = str(action.get("service_id", service_id))
			if str(action.get("kind", "")) == "WORKSHOP_SERVICE" and service_id == "REMOVE_PAIR":
				_build_pair_removal_card(pair_grid if pair_grid != null else action_stack, action)
				continue
			var is_target := str(action.get("kind", "")) == "WORKSHOP_SELECT_TARGET"
			_add_choice_button(action_stack, action, "tile" if is_target else "", false)
	for action in _actions:
		if str(action.get("kind", "")) in ["WORKSHOP_BACK", "WORKSHOP_EXIT"]:
			_add_choice_button(action_stack, action)
	var detail_panel := _new_detail_panel("WorkshopDetails")
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(detail_panel)
	_details_value = detail_panel.find_child("SelectedActionDetails", true, false) as Label
	var workshop_step := Label.new()
	workshop_step.name = "WorkshopStep"
	workshop_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workshop_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop_step.text = _workshop_step_details(service_id)
	detail_panel.get_child(0).add_child(workshop_step)
	if _workshop_has_result_action():
		var before_after := Label.new()
		before_after.name = "WorkshopBeforeAfter"
		before_after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		before_after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		before_after.text = _workshop_before_after(_preview_action())
		detail_panel.get_child(0).add_child(before_after)
	_update_details(_preview_action())


func _workshop_step_details(service_id: String) -> String:
	if service_id.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0013")
	var action := {"kind": "WORKSHOP_SELECT_SERVICE", "service_id": service_id, "target_id": service_id}
	var label := _action_label_text(action)
	return "%s\n\n%s" % [label, LocalizationCatalogScript.text("UI_RUN_JOURNEY_0033")]


func _build_pair_removal_card(parent: Control, action: Dictionary) -> void:
	var card := _new_surface("WorkshopPair_%s" % str(action.id).replace(":", "_").replace(".", "_"), "lacquer")
	parent.add_child(card)
	var stack := VBoxContainer.new()
	card.add_child(stack)
	var faces := HBoxContainer.new()
	faces.name = "WorkshopRemovalCopies"
	stack.add_child(faces)
	var details: Dictionary = action.get("details", {})
	for tile in details.get("affected_tiles", []):
		var annotations: Array[String] = []
		for modifier_id in tile.get("modifier_ids", []):
			annotations.append(_pretty_id_value(str(modifier_id)))
		var face := _add_reward_tile_face(faces, action, str(tile.tile_id), annotations)
		face.tile_copy_label = str(tile.get("copy_label", ""))
		face.accessibility_name = "%s · %s" % [face.tile_copy_label, _workshop_before_after(action)]
		face.tooltip_text = face.accessibility_name
	var preview := Label.new()
	preview.name = "WorkshopRemovalPreview"
	preview.text = _workshop_before_after(action)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(preview, "secondary")
	stack.add_child(preview)
	_add_choice_button(stack, action)


func _workshop_has_result_action() -> bool:
	for action in _actions:
		if str(action.get("kind", "")) == "WORKSHOP_SERVICE":
			return true
	return false


func _workshop_before_after(action: Dictionary) -> String:
	if action.is_empty() or str(action.get("kind", "")) != "WORKSHOP_SERVICE":
		return ""
	var details: Dictionary = action.get("details", {})
	var before := _pretty_id_value(str(details.get("tile_definition_id", "")))
	var price := int(details.get("price", 0))
	var is_refinement_token := str(action.get("service_id", "")) == "REFINEMENT_TOKEN"
	var result := ""
	if str(action.get("service_id", "")) == "REMOVE_PAIR":
		return LocalizationCatalogScript.format("UI_RC7_REMOVE_PAIR_PREVIEW", [before, int(details.get("pool_size_before", 0)), int(details.get("pool_size_after", 0)), price])
	if is_refinement_token:
		result = LocalizationCatalogScript.format("UI_RUN_SCENE_0156", [before])
	else:
		var after := _pretty_id_value(str(action.get("value_id", action.get("modifier_id", details.get("modifier_id", "")))))
		result = "%s → %s" % [before, after]
	var lines := [result, LocalizationCatalogScript.template("UI_RUN_SCENE_0137") % price]
	if is_refinement_token:
		lines.append(LocalizationCatalogScript.text("UI_RUN_SCENE_0138"))
	return "\n".join(lines)


func _build_action_browser(actions: Array, title: String, include_back: bool, as_reward: bool = false) -> void:
	var layout := _new_responsive_layout("DecisionBrowser", 16)
	_content_root.add_child(layout)
	var card_grid := GridContainer.new() if as_reward else null
	var actions_panel := _new_surface("DecisionChoicesPanel", "raised")
	actions_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(actions_panel)
	var choice_stack := VBoxContainer.new()
	choice_stack.add_theme_constant_override("separation", 8)
	actions_panel.add_child(choice_stack)
	if as_reward:
		card_grid.name = "RewardChoices"
		card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_grid.add_theme_constant_override("h_separation", 8)
		card_grid.add_theme_constant_override("v_separation", 8)
		_register_responsive_grid(card_grid, 224.0, 3, 0.58)
		choice_stack.add_child(card_grid)
	for action in actions:
		var kind := str(action.get("kind", ""))
		if kind == "REWARD_TARGET_BACK":
			_add_choice_button(choice_stack, action)
			continue
		if include_back and kind in ["WORKSHOP_BACK", "SHOP_EXIT"]:
			continue
		if kind == "WORKSHOP_BACK" or kind == "SHOP_EXIT":
			continue
		if as_reward:
			_build_reward_card(card_grid, action)
			continue
		var target_panel: Control = card_grid if as_reward else choice_stack
		_add_choice_button(target_panel, action)
	if actions.is_empty():
		var empty := Label.new()
		empty.text = LocalizationCatalogScript.text("UI_RUN_JOURNEY_0027")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_stack.add_child(empty)
	var detail_panel := _new_detail_panel("DecisionDetails")
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(detail_panel)
	_details_value = detail_panel.find_child("SelectedActionDetails", true, false) as Label
	var heading := Label.new()
	heading.name = "DecisionHeading"
	heading.text = title
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(heading, "title")
	detail_panel.get_child(0).add_child(heading)
	_update_details(_preview_action())
	if as_reward:
		var identities: Array[String] = []
		for action in actions:
			var details: Dictionary = action.get("details", {})
			identities.append(str(details.get("content_id", action.get("content_id", ""))))
		if identities != _last_reward_ids:
			_last_reward_ids = identities
			call_deferred("_play_reward_reveal")


func _build_reward_card(parent: Control, action: Dictionary) -> void:
	var details: Dictionary = action.get("details", {}) if action.get("details", {}) is Dictionary else {}
	var reward_kind := str(details.get("kind", ""))
	var action_id := str(action.get("id", ""))
	var safe_action_id := action_id.replace(":", "_").replace(".", "_")
	var card := _new_surface("RewardCard_%s" % safe_action_id, "lacquer")
	card.custom_minimum_size = Vector2(0.0, 176.0 * _ui_scale)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ForbiddenThemeScript.style_panel(card, "lacquer", action_id == selected_action_id)
	parent.add_child(card)
	var stack := VBoxContainer.new()
	stack.name = "RewardCardContent"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 6)
	card.add_child(stack)

	var header := HBoxContainer.new()
	header.name = "RewardCardHeader"
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	var icon := RewardKindIcon.new()
	icon.name = "RewardCategoryIcon"
	icon.configure(reward_kind, ForbiddenThemeScript.color("brass"), ForbiddenThemeScript.color("focus"), _ui_scale)
	header.add_child(icon)
	var heading_stack := VBoxContainer.new()
	heading_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_stack.add_theme_constant_override("separation", 2)
	header.add_child(heading_stack)
	var category := Label.new()
	category.name = "RewardCategoryLabel"
	var metadata: Dictionary = details.get("metadata", {})
	category.text = LocalizationCatalogScript.text("UI_RC7_SPECIAL_PIVOT") if bool(metadata.get("special_pivot", false)) else _reward_kind_label(reward_kind)
	category.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(category, "caption")
	category.add_theme_color_override("font_color", ForbiddenThemeScript.color("brass"))
	heading_stack.add_child(category)
	var title := Label.new()
	title.name = "RewardTitle"
	title.text = _reward_title(action, details)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(title, "heading")
	heading_stack.add_child(title)

	if reward_kind in ["ADD_TILE", "MODIFIED_TILE"] and not str(details.get("tile_id", details.get("content_id", ""))).is_empty() and not (str(metadata.get("target_mode", "")) == "CHOOSE_TYPE" and str(details.get("tile_id", "")).is_empty()):
		var visual_row := HBoxContainer.new()
		visual_row.name = "RewardTileVisualRow"
		visual_row.alignment = BoxContainer.ALIGNMENT_CENTER
		visual_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(visual_row)
		var tile_id := str(details.get("tile_id", details.get("content_id", "")))
		var annotations: Array[String] = []
		if reward_kind == "MODIFIED_TILE":
			var modifier_id := str(details.get("modifier_id", ""))
			if not modifier_id.is_empty():
				annotations.append(LocalizationCatalogScript.content_text(modifier_id))
		var face := _add_reward_tile_face(visual_row, action, tile_id, annotations)
		if reward_kind == "MODIFIED_TILE":
			var arrow := Label.new()
			arrow.name = "RewardModifierBadge"
			arrow.text = _pretty_id_value(str(details.get("modifier_id", "")))
			arrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			arrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_label(arrow, "secondary")
			visual_row.add_child(arrow)
			arrow.mouse_filter = Control.MOUSE_FILTER_STOP
			arrow.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_on_choice_selected(str(action.get("id", "")))
					arrow.accept_event()
			)
		face.tooltip_text = _reward_effect_preview(action, details)
	else:
		var choose_button := _add_choice_button(stack, action)
		choose_button.name = "RewardChoiceButton"
		choose_button.custom_minimum_size.y = maxf(52.0, 52.0 * _ui_scale)

	var effect := Label.new()
	effect.name = "RewardEffectPreview"
	effect.text = _reward_effect_preview(action, details)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(effect, "secondary")
	stack.add_child(effect)


func _add_reward_tile_face(parent: Control, action: Dictionary, tile_id: String, annotations: Array[String]) -> TileFaceButton:
	var action_id := str(action.get("id", ""))
	var face := TileFaceButtonScript.new()
	face.name = "RewardTileFace"
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.focus_mode = Control.FOCUS_ALL
	var tile_name := _pretty_id_value(tile_id)
	var effect_hint := _reward_effect_preview(action, action.get("details", {}))
	face.configure({
		"definition_id": tile_id,
		"instance_id": "",
		"copy_label": "%s · %s" % [tile_name, effect_hint],
		"annotations": annotations,
		"status_marker": "+" if not annotations.is_empty() else "",
	}, action_id == selected_action_id, true)
	face.name = "RewardTileFace"
	face.custom_minimum_size = Vector2(72.0, 96.0) * _ui_scale
	face.set_meta("run_action_id", action_id)
	face.tooltip_text = effect_hint
	face.accessibility_name = "%s · %s" % [tile_name, effect_hint]
	ForbiddenThemeScript.style_button(face, false, action_id == selected_action_id)
	parent.add_child(face)
	face.pressed.connect(_on_choice_selected.bind(action_id))
	face.focus_entered.connect(_on_choice_focused.bind(action_id))
	face.mouse_entered.connect(_on_choice_hovered.bind(action_id))
	face.button_down.connect(_on_button_down.bind(face))
	face.button_up.connect(_on_button_up.bind(face))
	return face


func _reward_kind_label(reward_kind: String) -> String:
	var key := "UI_RUN_REWARD_KIND_TILE"
	match reward_kind:
		"MODIFIED_TILE": key = "UI_RUN_REWARD_KIND_MODIFIED_TILE"
		"SKIP": key = "UI_RUN_REWARD_KIND_SKIP"
		"RELIC": key = "UI_RUN_REWARD_KIND_RELIC"
		"RUN_TECHNIQUE": key = "UI_RUN_REWARD_KIND_TECHNIQUE"
		"RULE_BREAKER": key = "UI_RUN_REWARD_KIND_RULE_BREAKER"
	return LocalizationCatalogScript.text(key)


func _reward_title(action: Dictionary, details: Dictionary) -> String:
	var reward_kind := str(details.get("kind", ""))
	if reward_kind == "SKIP":
		return LocalizationCatalogScript.text("UI_RUN_REWARD_KIND_SKIP")
	var content_id := str(details.get("content_id", action.get("content_id", "")))
	if reward_kind == "MODIFIED_TILE":
		var metadata: Dictionary = details.get("metadata", {})
		if str(metadata.get("target_mode", "")) == "CHOOSE_TYPE" and str(details.get("tile_id", "")).is_empty():
			return _pretty_id_value(str(details.get("modifier_id", content_id)))
		content_id = str(details.get("tile_id", content_id))
	if content_id.is_empty():
		return _action_label_text(action)
	return _pretty_id_value(content_id)


func _reward_effect_preview(action: Dictionary, details: Dictionary) -> String:
	if str(action.get("service_id", "")) == "REMOVE_PAIR":
		return _workshop_before_after(action)
	var reward_kind := str(details.get("kind", ""))
	if reward_kind == "MODIFIED_TILE" and not bool(details.get("effect_summary_rendering", false)):
		var nested := details.duplicate(true)
		nested["effect_summary_rendering"] = true
		var description := _reward_effect_preview(action, nested)
		var effects := _definition_effect_lines(str(details.get("modifier_id", "")))
		return description + ("\n" + "\n".join(PackedStringArray(effects)) if not effects.is_empty() else "")
	match reward_kind:
		"ADD_TILE":
			var metadata: Dictionary = details.get("metadata", {})
			if bool(metadata.get("special_pivot", false)):
				return LocalizationCatalogScript.text("UI_RC7_PIVOT_EFFECT")
			return LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_ADD_TILE")
		"MODIFIED_TILE":
			var metadata: Dictionary = details.get("metadata", {})
			if str(metadata.get("target_mode", "")) == "CHOOSE_TYPE":
				if str(details.get("tile_id", "")).is_empty():
					return LocalizationCatalogScript.format("UI_RC7_REWARD_UPGRADE_PROMPT", [int(metadata.get("target_limit", 2))])
				return LocalizationCatalogScript.format("UI_RC7_REWARD_TARGET_EFFECT", [_pretty_id_value(str(details.get("tile_id", ""))), int(details.get("target_count", 1)), _pretty_id_value(str(details.get("modifier_id", "")))])
			return LocalizationCatalogScript.format("UI_RUN_REWARD_EFFECT_MODIFIER_TO_TILE", [
				_pretty_id_value(str(details.get("tile_id", ""))),
				_pretty_id_value(str(details.get("modifier_id", ""))),
			])
		"SKIP":
			return _currency_change_preview(int(details.get("gold_delta", 0)), int(details.get("refinement_token_delta", 0)))
		"RELIC", "RUN_TECHNIQUE", "RULE_BREAKER":
			var lines: Array[String] = [LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_ACQUIRE")]
			lines.append_array(_definition_effect_lines(str(details.get("content_id", action.get("content_id", "")))))
			return "\n".join(lines)
	return _action_tooltip_text(action)


func _currency_change_preview(gold_delta: int, token_delta: int) -> String:
	var lines: Array[String] = []
	if gold_delta != 0:
		lines.append(_amount_change(LocalizationCatalogScript.word_text("GOLD"), gold_delta))
	if token_delta != 0:
		lines.append(_amount_change(LocalizationCatalogScript.word_text("REFINEMENT_TOKENS"), token_delta))
	return "\n".join(lines) if not lines.is_empty() else LocalizationCatalogScript.text("UI_RUN_REWARD_EFFECT_ACQUIRE")


func _definition_effect_lines(content_id: String) -> Array[String]:
	return PlayerActionTextScript.definition_effect_lines(_controller.domain.content_registry, content_id) if _controller != null else []

func _amount_change(label: String, amount: int) -> String:
	return PlayerActionTextScript._amount_change(label, amount)


func _build_event_action_list() -> void:
	pass


func _title_for_phase(phase: String) -> String:
	match phase:
		RunPhaseScript.ELITE_REWARD, RunPhaseScript.BOSS_REWARD:
			return LocalizationCatalogScript.text("UI_RUN_SCENE_0112")
		_:
			return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0004")


func _choice_list_panel(panel_name: String, actions: Array, _unused: bool) -> PanelContainer:
	var panel := _new_surface(panel_name, "raised")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = "%sScroll" % panel_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "%sChoices" % panel_name
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for action in actions:
		_add_choice_button(list, action)
	return panel


func _new_detail_panel(panel_name: String) -> PanelContainer:
	var panel := _new_surface(panel_name, "paper")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var layout := VBoxContainer.new()
	layout.name = "%sLayout" % panel_name
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)
	var detail := Label.new()
	detail.name = "SelectedActionDetails"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	layout.add_child(detail)
	return panel


func _new_responsive_layout(layout_name: String, separation: int) -> BoxContainer:
	var layout := BoxContainer.new()
	layout.name = layout_name
	layout.vertical = _is_compact_width(size.x)
	layout.add_theme_constant_override("separation", separation)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_responsive_layouts.append(layout)
	return layout


func _register_responsive_grid(grid: GridContainer, minimum_cell_width: float, maximum_columns: int, fallback_width_fraction: float = 1.0, maximum_cell_width: float = 0.0) -> void:
	var entry := {
		"grid": grid,
		"minimum_cell_width": minimum_cell_width,
		"maximum_columns": maximum_columns,
		"fallback_width_fraction": fallback_width_fraction,
		"maximum_cell_width": maximum_cell_width,
	}
	_responsive_grids.append(entry)
	grid.resized.connect(_update_responsive_grid.bind(grid))
	_update_responsive_grid(grid)


func _is_compact_width(width: float) -> bool:
	return width > 0.0 and width < COMPACT_LAYOUT_BREAKPOINT * _ui_scale


func _on_layout_resized() -> void:
	_update_responsive_layouts()
	call_deferred("_update_responsive_layouts")


func _update_responsive_layouts() -> void:
	_is_compact_layout = _is_compact_width(size.x)
	for layout in _responsive_layouts:
		if is_instance_valid(layout):
			layout.vertical = _is_compact_layout
	for entry in _responsive_grids:
		var grid := entry.get("grid") as GridContainer
		if grid != null and is_instance_valid(grid):
			_update_responsive_grid(grid)


func _update_responsive_grid(grid: GridContainer) -> void:
	if grid == null or not is_instance_valid(grid):
		return
	for entry in _responsive_grids:
		if entry.get("grid") != grid:
			continue
		var available_width := grid.size.x
		var centering_parent := grid.get_parent() as CenterContainer
		if centering_parent != null and centering_parent.size.x > 0.0:
			available_width = centering_parent.size.x
		if available_width <= 0.0:
			var fallback_fraction := 1.0 if _is_compact_width(size.x) else float(entry.get("fallback_width_fraction", 1.0))
			available_width = size.x * fallback_fraction
		if _content_width_limit > 0.0:
			available_width = minf(available_width, _content_width_limit)
		var gap := float(grid.get_theme_constant("h_separation")) if grid.has_theme_constant("h_separation") else 8.0
		var cell_width := maxf(1.0, float(entry.get("minimum_cell_width", 220.0)) * _ui_scale)
		var columns := clampi(floori((available_width + gap) / (cell_width + gap)), 1, int(entry.get("maximum_columns", 1)))
		grid.columns = columns
		var maximum_cell_width := float(entry.get("maximum_cell_width", 0.0)) * _ui_scale
		var fitted_cell_width := minf(maximum_cell_width, maxf(1.0, (available_width - gap * float(columns - 1)) / float(columns))) if maximum_cell_width > 0.0 else 0.0
		grid.custom_minimum_size.x = fitted_cell_width * float(columns) + gap * float(columns - 1) if fitted_cell_width > 0.0 else 0.0
		for child in grid.get_children():
			if child is Control:
				(child as Control).custom_minimum_size.x = fitted_cell_width
		grid.queue_sort()
		call_deferred("_emit_content_minimum_changed")
		return


func _emit_content_minimum_changed() -> void:
	content_minimum_changed.emit()


func _new_surface(panel_name: String, surface: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ForbiddenThemeScript.style_panel(panel, surface)
	return panel


func _add_choice_button(parent: Control, action: Dictionary, presentation: String = "", disabled: bool = false) -> Button:
	var action_id := str(action.get("id", ""))
	var button: Button
	if presentation == "tile":
		button = TileFaceButtonScript.new()
		var details: Dictionary = action.get("details", {})
		var tile_id := str(details.get("tile_definition_id", ""))
		var instance_id := str(action.get("instance_id", details.get("tile_instance_id", "")))
		var tile_name := _pretty_id_value(tile_id)
		button.configure({"definition_id": tile_id, "instance_id": instance_id, "copy_label": "%s · %s" % [tile_name, instance_id]}, action_id == selected_action_id, false)
	else:
		button = Button.new()
		button.text = _action_label_text(action)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = (76.0 if presentation == "reward" else (68.0 if presentation == "suit" else 52.0)) * _ui_scale
	button.name = "RunAction_%s" % action_id.replace(":", "_").replace(".", "_")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.set_meta("run_action_id", action_id)
	button.tooltip_text = _action_tooltip_text(action)
	if button is TileFaceButtonScript:
		button.custom_minimum_size.y = 64.0 * _ui_scale
	ForbiddenThemeScript.style_button(button, false, action_id == selected_action_id)
	parent.add_child(button)
	button.pressed.connect(_on_choice_selected.bind(action_id))
	button.focus_entered.connect(_on_choice_focused.bind(action_id))
	button.mouse_entered.connect(_on_choice_hovered.bind(action_id))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))
	return button


func _configure_action_button(button: Button, action: Dictionary, choose_button: bool = false) -> void:
	var action_id := str(action.get("id", ""))
	button.set_meta("run_action_id", action_id)
	button.set_meta("run_choice_button", true)
	button.tooltip_text = _action_tooltip_text(action)
	ForbiddenThemeScript.style_button(button, false, action_id == selected_action_id)
	button.pressed.connect(_on_choice_selected.bind(action_id))
	button.focus_entered.connect(_on_choice_focused.bind(action_id))
	button.mouse_entered.connect(_on_choice_hovered.bind(action_id))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func _update_choice_styles() -> void:
	for button in find_children("*", "Button", true, false):
		var action_id := str(button.get_meta("run_action_id", ""))
		if action_id.is_empty() or not _actions_by_id.has(action_id):
			continue
		if button is TileFaceButtonScript:
			(button as TileFaceButton).set_selected(action_id == selected_action_id)
		else:
			ForbiddenThemeScript.style_button(button as Button, false, action_id == selected_action_id)
	for panel in find_children("CharacterCard_*", "PanelContainer", true, false):
		var card_id := str(panel.name).trim_prefix("CharacterCard_").to_snake_case()
		for candidate in _actions:
			if str(candidate.get("target_id", "")).get_slice(".", str(candidate.get("target_id", "")).get_slice_count(".") - 1) == card_id:
				ForbiddenThemeScript.style_panel(panel as Control, "lacquer", str(candidate.get("id", "")) == selected_action_id)


func _preview_action() -> Dictionary:
	if _state != null and str(_state.phase) == RunPhaseScript.MAP_CHOICE and _actions_by_id.has(selected_action_id):
		return _actions_by_id[selected_action_id]
	if _actions_by_id.has(focused_action_id):
		return _actions_by_id[focused_action_id]
	if _actions_by_id.has(selected_action_id):
		return _actions_by_id[selected_action_id]
	return {}


func _update_details(action: Dictionary) -> void:
	if _details_value != null:
		var detail := _action_detail_text(action)
		_details_value.text = detail if not detail.is_empty() else LocalizationCatalogScript.text("UI_RUN_JOURNEY_0013")
	if _event_choice_details != null:
		_event_choice_details.text = _event_detail_for_action(action)


func _action_detail_text(action: Dictionary) -> String:
	if action.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0013")
	if str(action.get("kind", "")) in ["CHARACTER_SUIT", "CHARACTER_SUIT_BACK"]:
		return _action_label_text(action)
	if str(action.get("kind", "")) == "EVENT_OPTION":
		return _event_detail_for_action(action)
	if _action_details.is_valid():
		var detailed := str(_action_details.call(action))
		if not detailed.is_empty():
			return detailed
	return _action_tooltip_text(action)


func _action_label_text(action: Dictionary) -> String:
	if str(action.get("kind", "")) == "CHARACTER_SUIT":
		return _character_suit_label(str(action.get("excluded_suit", "")))
	if str(action.get("kind", "")) == "CHARACTER_SUIT_BACK":
		return LocalizationCatalogScript.text("UI_RUN_CHARACTER_SUIT_BACK")
	if str(action.get("kind", "")) == "EVENT_OPTION":
		var choice = _state.event_state.choice_by_id(str(action.get("target_id", ""))) if _state != null and _state.event_state != null else null
		if choice is Dictionary:
			return _event_choice_label(action, choice)
	return str(_action_label.call(action)) if _action_label.is_valid() else str(action.get("id", ""))


func _character_suit_label(excluded_suit: String) -> String:
	match excluded_suit:
		"characters": return LocalizationCatalogScript.text("UI_RUN_CHARACTER_SUIT_LABEL_CHARACTERS")
		"dots": return LocalizationCatalogScript.text("UI_RUN_CHARACTER_SUIT_LABEL_DOTS")
		"bamboo": return LocalizationCatalogScript.text("UI_RUN_CHARACTER_SUIT_LABEL_BAMBOO")
		_: return LocalizationCatalogScript.word_text("UNAVAILABLE")


func _character_action_button_label(action: Dictionary) -> String:
	var label := _action_label_text(action)
	if _content_width_limit <= 0.0 or _content_width_limit >= 520.0 * _ui_scale:
		return label
	var separator := label.find("—")
	return label.substr(0, separator).strip_edges() if separator >= 0 else label


func _update_character_choice_labels() -> void:
	if _state == null or str(_state.phase) != RunPhaseScript.CHARACTER_SELECT:
		return
	for node in find_children("InspectCharacterButton", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		var action: Dictionary = _actions_by_id.get(str(button.get_meta("run_action_id", "")), {})
		button.text = _character_action_button_label(action)


func _event_choice_label(action: Dictionary, choice: Dictionary) -> String:
	var event_id := str(action.get("event_id", _state.event_state.event_id if _state != null and _state.event_state != null else ""))
	var choice_id := str(action.get("target_id", choice.get("choice_id", "")))
	var key := ""
	var event_index := AlphaScaleCatalogScript.ACT_ONE_EVENT_IDS.find(event_id)
	if event_index >= 0:
		key = str(ACT_ONE_EVENT_CHOICE_LABEL_KEYS[event_index].get(choice_id, ""))
	else:
		event_index = AlphaActTwoCatalogScript.ACT_TWO_EVENT_IDS.find(event_id)
		if event_index >= 0:
			key = str(ACT_TWO_EVENT_CHOICE_LABEL_KEYS[event_index].get(choice_id, ""))
		else:
			event_index = AlphaActTwoCatalogScript.ACT_TWO_ADDITIONAL_EVENT_IDS.find(event_id)
			if event_index >= 0:
				key = str(ACT_TWO_ADDITIONAL_EVENT_CHOICE_LABEL_KEYS[event_index].get(choice_id, ""))
	return LocalizationCatalogScript.text(key) if not key.is_empty() else LocalizationCatalogScript.display_text(str(choice.get("label", "")))


func _action_tooltip_text(action: Dictionary) -> String:
	if str(action.get("kind", "")) in ["CHARACTER_SUIT", "CHARACTER_SUIT_BACK"]:
		return _action_label_text(action)
	return str(_action_tooltip.call(action)) if _action_tooltip.is_valid() else _action_label_text(action)


func _pretty_id_value(identifier: String) -> String:
	return str(_pretty_id.call(identifier)) if _pretty_id.is_valid() else LocalizationCatalogScript.content_text(identifier)


func _pretty_words(value: String) -> String:
	return str(_pretty_words_callable.call(value)) if _pretty_words_callable.is_valid() else LocalizationCatalogScript.word_text(value)


func _on_choice_selected(action_id: String) -> void:
	if not _actions_by_id.has(action_id):
		return
	var button := action_button(action_id)
	if button != null and button.disabled:
		return
	focused_action_id = action_id
	selected_action_id = action_id
	_update_choice_styles()
	_update_details(_actions_by_id[action_id])
	selection_changed.emit(action_id)
	if str(_actions_by_id[action_id].get("kind", "")) == "MAP_NODE":
		_update_map_travel_button()
		if _map_travel_button != null:
			_map_travel_button.grab_focus()
		return
	# Journey tile faces represent one Workshop target choice. Battle hand tiles use
	# BattleView's separate multiselect path; every Journey choice activates here.
	action_activated.emit(action_id)


func _update_map_travel_button() -> void:
	if _map_travel_button == null or not is_instance_valid(_map_travel_button):
		return
	var action: Dictionary = _actions_by_id.get(selected_action_id, {})
	_map_travel_button.disabled = str(action.get("kind", "")) != "MAP_NODE"
	_map_travel_button.text = LocalizationCatalogScript.text("UI_PLAYER_MAP_CHOOSE") if _map_travel_button.disabled else LocalizationCatalogScript.format("UI_PLAYER_MAP_TRAVEL", [_action_label_text(action)])

func _on_choice_focused(action_id: String) -> void:
	focused_action_id = action_id
	_update_details(_preview_action())
	focus_changed.emit(action_id)


func _on_choice_hovered(action_id: String) -> void:
	if _state != null and str(_state.phase) == RunPhaseScript.MAP_CHOICE and not selected_action_id.is_empty():
		return
	_update_details(_actions_by_id.get(action_id, {}))


func _on_button_down(button: Button) -> void:
	if _motion_feedback != null:
		_motion_feedback.play_property(button, ^"scale", button.scale, Vector2(0.98, 0.98), 0.12)


func _on_button_up(button: Button) -> void:
	if _motion_feedback != null:
		_motion_feedback.play_property(button, ^"scale", button.scale, Vector2.ONE, 0.12)


func _clear_selection() -> void:
	selected_action_id = ""
	_update_choice_styles()
	selection_changed.emit("")


func _play_reward_reveal() -> void:
	if _motion_feedback == null or _actions.is_empty():
		return
	var first_choice := action_button(str(_actions[0].get("id", "")))
	if first_choice == null or not first_choice.is_inside_tree():
		return
	# The offer and its readable rules already exist at their final state; only the card surface settles.
	_motion_feedback.play_property(first_choice, ^"scale", Vector2(0.92, 0.92), Vector2.ONE, 0.42)


func _play_workshop_preview() -> void:
	if _motion_feedback == null or not _workshop_has_result_action():
		return
	var detail := find_child("WorkshopBeforeAfter", true, false) as Label
	if detail == null:
		return
	# Preview copy is final before this short emphasis; no Domain command is connected to the tween.
	_motion_feedback.play_property(detail, ^"scale", Vector2(0.94, 0.94), Vector2.ONE, 0.24)


func _apply_theme_to_content() -> void:
	if _content_root == null:
		return
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		var action_id := str(button.get_meta("run_action_id", ""))
		if action_id.is_empty():
			ForbiddenThemeScript.style_button(button)
	for panel in find_children("*", "PanelContainer", true, false):
		var surface := "lacquer"
		if str(panel.name).contains("Details") or str(panel.name).contains("Outcome"):
			surface = "paper"
		ForbiddenThemeScript.style_panel(panel as Control, surface)


func _style_label(label: Label, role: String) -> void:
	ForbiddenThemeScript.style_label(label, role, _locale)
	# Many journey labels are styled before they are parented, so ForbiddenTheme
	# cannot discover this view's scale metadata yet. Apply the configured role size
	# explicitly so they match labels created after the responsive theme is attached.
	label.add_theme_font_size_override("font_size", ForbiddenThemeScript.font_size_for(role, _ui_scale))
