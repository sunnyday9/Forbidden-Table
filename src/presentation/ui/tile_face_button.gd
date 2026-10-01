class_name TileFaceButton
extends Button

const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")

const MIN_HIT_WIDTH := 44.0
const SMALL_HEIGHT := 64.0
const LARGE_WIDTH := 63.0
const LARGE_HEIGHT := 96.0
const TILE_INSET := 3.0
const FOCUS_GUTTER := 3.0

var tile_definition_id: String = ""
var tile_instance_id: String = ""
var tile_annotations: Array = []
var tile_copy_label: String = ""
var selected: bool = false
var face_rect: TextureRect
var selected_outline: Panel
var focus_outline: Panel
var status_marker: String = ""
var status_badge: Label
static var _outline_cache: Dictionary = {}


func _init() -> void:
	flat = true
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	text = ""
	custom_minimum_size = Vector2(MIN_HIT_WIDTH, SMALL_HEIGHT)
	_ensure_visual_children()


func _ready() -> void:
	_ensure_visual_children()
	if not focus_entered.is_connected(_on_focus_entered):
		focus_entered.connect(_on_focus_entered)
	if not focus_exited.is_connected(_on_focus_exited):
		focus_exited.connect(_on_focus_exited)
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	_refresh_visual_state()


func configure(tile: Dictionary, is_selected: bool = false, large: bool = false) -> void:
	_ensure_visual_children()
	tile_definition_id = str(tile.get("definition_id", ""))
	tile_instance_id = str(tile.get("instance_id", ""))
	tile_copy_label = str(tile.get("copy_label", ""))
	tile_annotations = _normalize_annotations(tile.get("annotations", []))
	status_marker = str(tile.get("status_marker", "!" if not tile_annotations.is_empty() else ""))
	selected = is_selected
	set_pressed_no_signal(is_selected)
	custom_minimum_size = Vector2(
		maxf(MIN_HIT_WIDTH, LARGE_WIDTH if large else MIN_HIT_WIDTH),
		LARGE_HEIGHT if large else SMALL_HEIGHT,
	)
	name = "TileFaceButton" if tile_instance_id.is_empty() else "Tile_%s" % tile_instance_id
	set_meta("tile_definition_id", tile_definition_id)
	set_meta("tile_instance_id", tile_instance_id)
	set_meta("tile_annotations", tile_annotations.duplicate(true))
	tooltip_text = _accessible_description()
	accessibility_name = tooltip_text
	face_rect.texture = ForbiddenThemeScript.tile_texture(tile_definition_id)
	status_badge.text = status_marker
	status_badge.visible = not status_marker.is_empty()
	status_badge.tooltip_text = tooltip_text
	# Reserve a separate strip for marks; never paint over the Mahjong face.
	if status_badge.visible:
		custom_minimum_size.y += 18.0
	face_rect.offset_bottom = -21.0 if status_badge.visible else -TILE_INSET
	_refresh_visual_state()


func set_selected(value: bool) -> void:
	selected = value
	set_pressed_no_signal(value)
	_refresh_visual_state()


func _ensure_visual_children() -> void:
	if face_rect == null:
		face_rect = TextureRect.new()
		face_rect.name = "TileFace"
		face_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		face_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face_rect.offset_left = TILE_INSET
		face_rect.offset_top = TILE_INSET
		face_rect.offset_right = -TILE_INSET
		face_rect.offset_bottom = -TILE_INSET
		add_child(face_rect)

	if selected_outline == null:
		selected_outline = Panel.new()
		selected_outline.name = "SelectionOutline"
		selected_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selected_outline.focus_mode = Control.FOCUS_NONE
		selected_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		selected_outline.offset_left = 1.0
		selected_outline.offset_top = 1.0
		selected_outline.offset_right = -1.0
		selected_outline.offset_bottom = -1.0
		selected_outline.add_theme_stylebox_override("panel", _outline_style("brass", 2.0, 4.0))
		add_child(selected_outline)
		selected_outline.z_index = 1

	if focus_outline == null:
		focus_outline = Panel.new()
		focus_outline.name = "FocusOutline"
		focus_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_outline.focus_mode = Control.FOCUS_NONE
		focus_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		focus_outline.offset_left = -FOCUS_GUTTER
		focus_outline.offset_top = -FOCUS_GUTTER
		focus_outline.offset_right = FOCUS_GUTTER
		focus_outline.offset_bottom = FOCUS_GUTTER
		focus_outline.add_theme_stylebox_override("panel", _outline_style("focus", 3.0, 7.0))
		add_child(focus_outline)
		focus_outline.z_index = 2

	if status_badge == null:
		status_badge = Label.new()
		status_badge.name = "TileStatusBadge"
		status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		status_badge.offset_left = TILE_INSET
		status_badge.offset_right = -TILE_INSET
		status_badge.offset_top = -21.0
		status_badge.offset_bottom = -TILE_INSET
		# This mark scales with the fixed tile art; the full inspector uses UI scale.
		status_badge.add_theme_font_size_override("font_size", 12)
		status_badge.add_theme_color_override("font_color", ForbiddenThemeScript.color("text"))
		status_badge.visible = false
		add_child(status_badge)


func _refresh_visual_state() -> void:
	if selected_outline != null:
		selected_outline.visible = selected
	if focus_outline != null:
		focus_outline.visible = has_focus()


func _on_focus_entered() -> void:
	_refresh_visual_state()


func _on_focus_exited() -> void:
	_refresh_visual_state()


func _on_toggled(value: bool) -> void:
	selected = value
	_refresh_visual_state()


func _accessible_description() -> String:
	var description := tile_copy_label
	if description.is_empty():
		var translated_name := str(TranslationServer.translate(tile_definition_id))
		if not tile_definition_id.is_empty() and translated_name != tile_definition_id:
			description = translated_name
	for annotation in tile_annotations:
		var annotation_text := str(annotation).strip_edges()
		if not annotation_text.is_empty():
			description += " · " + annotation_text
	return description


func _normalize_annotations(raw_annotations: Variant) -> Array:
	if raw_annotations is Array:
		return raw_annotations.duplicate(true)
	if raw_annotations is String and not str(raw_annotations).is_empty():
		return [str(raw_annotations)]
	if raw_annotations is Dictionary:
		var labels: Array = []
		for key in raw_annotations:
			labels.append(str(raw_annotations[key]))
		return labels
	return []


static func _outline_style(token: String, line_width: float, radius: float) -> StyleBoxFlat:
	var cache_key := "%s:%.1f:%.1f" % [token, line_width, radius]
	if _outline_cache.has(cache_key):
		return _outline_cache[cache_key]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.draw_center = false
	style.border_color = ForbiddenThemeScript.color(token)
	var width := roundi(line_width)
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	var corner_radius := roundi(radius)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	_outline_cache[cache_key] = style
	return style
