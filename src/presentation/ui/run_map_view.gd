class_name RunMapView
extends Control

signal action_selected(action_id: String)
signal action_focused(action_id: String)

const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")

const NODE_HEIGHT := 68.0
const MIN_MAP_SIZE := Vector2(560.0, 300.0)

var _definition
var _map_state
var _action_label: Callable
var _pretty_id: Callable
var _pretty_words: Callable
var _locale := "en"
var _ui_scale := 1.0
var _actions_by_node: Dictionary = {}
var _node_controls: Dictionary = {}
var _node_centers: Dictionary = {}
var _selected_action_id := ""
var _focused_action_id := ""


func _init() -> void:
	# Copy is already resolved through Localization; controls must not translate
	# it a second time (which also doubles pseudo-localization expansion).
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	custom_minimum_size = MIN_MAP_SIZE
	resized.connect(_layout_nodes)


func configure(action_label: Callable, pretty_id: Callable, pretty_words: Callable) -> void:
	_action_label = action_label
	_pretty_id = pretty_id
	_pretty_words = pretty_words


func set_presentation_preferences(locale: String, ui_scale: float) -> void:
	_locale = "zh_CN" if locale.to_lower().begins_with("zh") else "en"
	_ui_scale = clampf(ui_scale, 1.0, 1.5)
	custom_minimum_size = Vector2(MIN_MAP_SIZE.x, maxf(MIN_MAP_SIZE.y, NODE_HEIGHT * _ui_scale * 3.0 + 32.0))
	theme = ForbiddenThemeScript.create_theme(_locale, _ui_scale)


func render(map_definition, map_state, actions: Array, selected_action_id: String = "", focused_action_id: String = "") -> void:
	_definition = map_definition
	_map_state = map_state
	_selected_action_id = selected_action_id
	_focused_action_id = focused_action_id
	_actions_by_node.clear()
	for action in actions:
		if action is Dictionary and str(action.get("kind", "")) == "MAP_NODE":
			_actions_by_node[str(action.get("target_id", ""))] = action
	_clear_nodes()
	if _definition == null or _map_state == null:
		queue_redraw()
		return
	for node_id in _definition.node_ids:
		_add_map_node(str(node_id))
	_layout_nodes()
	queue_redraw()


func choice_button(action_id: String) -> Button:
	for node_id in _actions_by_node:
		var action: Dictionary = _actions_by_node[node_id]
		if str(action.get("id", "")) == action_id:
			return _node_controls.get(str(node_id)) as Button
	return null


func _draw() -> void:
	if _definition == null:
		return
	var visited: Array = _map_state.visited_node_ids if _map_state != null else []
	var completed_edges: Array = _map_state.path_edge_ids if _map_state != null else []
	for source_id in _definition.node_ids:
		var source := str(source_id)
		if not _node_centers.has(source):
			continue
		for edge in _definition.outgoing_edges(source):
			var destination := str(edge.get("to_node_id", ""))
			if not _node_centers.has(destination):
				continue
			var edge_id := str(edge.get("edge_id", ""))
			var is_travelled := completed_edges.has(edge_id) or (visited.has(source) and visited.has(destination))
			var line_color := ForbiddenThemeScript.color("brass") if is_travelled else ForbiddenThemeScript.color("edge").lightened(0.12)
			line_color.a = 0.84 if is_travelled else 0.52
			if is_travelled:
				draw_line(_node_centers[source], _node_centers[destination], line_color, 2.2, true)
			else:
				draw_dashed_line(_node_centers[source], _node_centers[destination], line_color, 1.2, 5.0, true)


func _add_map_node(node_id: String) -> void:
	var definition = _definition.node_definition(node_id)
	if definition == null:
		return
	var action: Dictionary = _actions_by_node.get(node_id, {})
	var button := Button.new()
	button.name = "MapNode_%s" % node_id.to_pascal_case()
	button.custom_minimum_size = Vector2(0.0, NODE_HEIGHT * _ui_scale)
	button.set_meta("map_node_id", node_id)
	var state: String = str(_map_state.knowledge_state.get(node_id, "PARTIAL"))
	var visible_payload: String = _map_state.visible_payload_id(node_id)
	var primary := str(_pretty_words.call(str(definition.node_kind))) if _pretty_words.is_valid() else str(definition.node_kind)
	if not visible_payload.is_empty() and _pretty_id.is_valid():
		primary = str(_pretty_id.call(visible_payload))
	var status := _node_status(node_id, action)
	var status_for_tooltip := _node_status_for_tooltip(node_id, action)
	button.text = ""
	button.tooltip_text = str(_action_label.call(action)) if not action.is_empty() and _action_label.is_valid() else "%s · %s" % [primary, status_for_tooltip]
	button.focus_mode = Control.FOCUS_ALL if not action.is_empty() else Control.FOCUS_NONE
	button.disabled = action.is_empty()
	if not action.is_empty():
		var action_id := str(action.get("id", ""))
		button.set_meta("run_action_id", action_id)
		button.pressed.connect(_on_choice_pressed.bind(action_id))
		button.focus_entered.connect(_on_choice_focused.bind(action_id))
	ForbiddenThemeScript.style_button(button, false, not action.is_empty() and str(action.get("id", "")) == _selected_action_id)
	var map_label := Label.new()
	map_label.name = "MapNodeLabel"
	map_label.text = LocalizationCatalogScript.format("UI_RUN_JOURNEY_MAP_NODE_LABEL", [primary, status])
	map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_label.add_theme_font_size_override("font_size", roundi(14.0 * _ui_scale))
	button.add_child(map_label)
	button.accessibility_name = "%s, %s" % [primary, status_for_tooltip]
	_node_controls[node_id] = button
	add_child(button)


func _node_status(node_id: String, action: Dictionary) -> String:
	if node_id == str(_map_state.current_node_id):
		return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0010")
	if _map_state.visited_node_ids.has(node_id):
		return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0011")
	if not action.is_empty():
		return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0009")
	if str(_map_state.knowledge_state.get(node_id, "PARTIAL")) != "EXACT":
		return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0012")
	return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0022")


func _node_status_for_tooltip(node_id: String, action: Dictionary) -> String:
	if node_id == str(_map_state.current_node_id) or _map_state.visited_node_ids.has(node_id) or not action.is_empty():
		return _node_status(node_id, action)
	if str(_map_state.knowledge_state.get(node_id, "PARTIAL")) != "EXACT":
		return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0012")
	return LocalizationCatalogScript.text("UI_RUN_JOURNEY_0031")


func _layout_nodes() -> void:
	if _definition == null or _map_state == null:
		return
	var layers: Dictionary = _node_layers()
	if layers.is_empty():
		return
	var max_depth := 0
	for depth in layers:
		max_depth = maxi(max_depth, int(depth))
	var inner_width := maxf(1.0, size.x - 24.0)
	var column_step := inner_width / float(max_depth + 1)
	var button_width := maxf(60.0, column_step - 8.0)
	var node_heights: Dictionary = {}
	var required_height := 16.0
	for depth in layers:
		var node_ids: Array = layers[depth]
		var row_height := NODE_HEIGHT * _ui_scale
		for node_id_value in node_ids:
			var node_id := str(node_id_value)
			var node_button := _node_controls.get(node_id) as Button
			if node_button == null:
				continue
			var node_height := _required_node_height(node_button, button_width)
			node_heights[node_id] = node_height
			row_height = maxf(row_height, node_height)
		required_height = maxf(required_height, row_height * float(node_ids.size()) + 16.0)
	var preferred_height := maxf(MIN_MAP_SIZE.y, required_height)
	if not is_equal_approx(custom_minimum_size.y, preferred_height):
		custom_minimum_size.y = preferred_height
	var inner := Rect2(Vector2(12.0, 8.0), Vector2(inner_width, maxf(size.y, preferred_height) - 16.0))
	for depth in layers:
		var node_ids: Array = layers[depth]
		node_ids.sort()
		var row_step := inner.size.y / float(maxi(1, node_ids.size()))
		for index in node_ids.size():
			var node_id := str(node_ids[index])
			var button := _node_controls.get(node_id) as Button
			if button == null:
				continue
			var button_height := float(node_heights.get(node_id, NODE_HEIGHT * _ui_scale))
			var button_size := Vector2(button_width, button_height)
			button.custom_minimum_size.y = button_height
			button.size = button_size
			button.position = Vector2(
				inner.position.x + column_step * float(int(depth)) + (column_step - button_size.x) * 0.5,
				inner.position.y + row_step * (float(index) + 0.5) - button_size.y * 0.5,
			)
			_node_centers[node_id] = button.position + button_size * 0.5
	queue_redraw()
	if not _focused_action_id.is_empty():
		var focused := choice_button(_focused_action_id)
		if focused != null and focused.is_visible_in_tree():
			focused.grab_focus()


func _required_node_height(button: Button, button_width: float) -> float:
	var label := button.find_child("MapNodeLabel", true, false) as Label
	if label == null:
		return NODE_HEIGHT * _ui_scale
	# Size from the label's actual word-smart wrap behavior. The font multiline
	# estimate does not split overlong words the way Label does, so measure the
	# same words and split only words wider than the node itself.
	button.custom_minimum_size.x = button_width
	button.size.x = button_width
	var font := label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := label.get_theme_font_size("font_size")
	var content_width := maxf(1.0, button_width)
	var line_count := _word_smart_line_count(label.text, font, font_size, content_width)
	var rendered_text_height := float(line_count) * label.get_line_height()
	var wrapped_minimum := label.get_minimum_size().y
	return maxf(NODE_HEIGHT * _ui_scale, ceil(maxf(rendered_text_height, wrapped_minimum) + 8.0 * _ui_scale))


func _word_smart_line_count(text: String, font: Font, font_size: int, width: float) -> int:
	var total_lines := 0
	for explicit_line in text.split("\n", true):
		var current_line := ""
		for word in str(explicit_line).split(" ", false):
			var chunks := _word_chunks(str(word), font, font_size, width)
			if current_line.is_empty():
				if chunks.size() > 1:
					total_lines += chunks.size() - 1
				current_line = chunks[chunks.size() - 1]
				continue
			var combined := "%s %s" % [current_line, word]
			if float(font.get_string_size(combined, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x) <= width:
				current_line = combined
				continue
			total_lines += 1
			if chunks.size() > 1:
				total_lines += chunks.size() - 1
			current_line = chunks[chunks.size() - 1]
		total_lines += 1
	return maxi(1, total_lines)


func _word_chunks(word: String, font: Font, font_size: int, width: float) -> Array[String]:
	var chunks: Array[String] = []
	if float(font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x) <= width:
		chunks.append(word)
		return chunks
	var current := ""
	for character in word:
		var candidate := current + character
		if not current.is_empty() and float(font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x) > width:
			chunks.append(current)
			current = character
		else:
			current = candidate
	if not current.is_empty():
		chunks.append(current)
	return chunks


func _node_layers() -> Dictionary:
	var distances := {_definition.start_node_id: 0}
	var queue: Array[String] = [str(_definition.start_node_id)]
	while not queue.is_empty():
		var source: String = queue.pop_front()
		var node = _definition.node_definition(source)
		if node == null:
			continue
		for destination in node.next_node_ids:
			var key := str(destination)
			if not distances.has(key):
				distances[key] = int(distances[source]) + 1
				queue.append(key)
	var layers: Dictionary = {}
	for node_id in _definition.node_ids:
		var key := str(node_id)
		var depth := int(distances.get(key, 0))
		if not layers.has(depth):
			layers[depth] = []
		layers[depth].append(key)
	return layers


func _clear_nodes() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_node_controls.clear()
	_node_centers.clear()


func _on_choice_pressed(action_id: String) -> void:
	_focused_action_id = action_id
	action_selected.emit(action_id)


func _on_choice_focused(action_id: String) -> void:
	_focused_action_id = action_id
	action_focused.emit(action_id)
