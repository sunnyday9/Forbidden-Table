class_name ForbiddenTheme
extends RefCounted

const EN_SANS_REGULAR := "res://assets/ui/fonts/NotoSans-Regular.ttf"
const EN_SANS_MEDIUM := "res://assets/ui/fonts/NotoSans-SemiBold.ttf"
const EN_SERIF_REGULAR := "res://assets/ui/fonts/NotoSerif-Regular.ttf"
const SC_SANS_REGULAR := "res://assets/ui/fonts/NotoSansSC-Regular.otf"
const SC_SANS_MEDIUM := "res://assets/ui/fonts/NotoSansSC-Medium.otf"
const SC_SERIF_REGULAR := "res://assets/ui/fonts/NotoSerifSC-Regular.otf"
const TILE_DIR := "res://assets/ui/tiles/chinese-tiles/"

const PALETTE := {
	"table": Color("#0E1916"),
	"lacquer": Color("#112820"),
	"raised": Color("#243B30"),
	"text": Color("#FFF1D5"),
	"muted": Color("#D3D4B9"),
	"brass": Color("#E7B65A"),
	"focus": Color("#97EEDF"),
	"error": Color("#FFB09B"),
	"success": Color("#ADE1BC"),
	"edge": Color("#9E865A"),
	"ink": Color("#192218"),
	"paper": Color("#292218"),
	"vermilion": Color("#A84431"),
}

const HONOR_FACE_FILES := {
	"east": "z1.png",
	"south": "z2.png",
	"west": "z3.png",
	"north": "z4.png",
	"red": "z5.png",
	"green": "z6.png",
	"white": "z7.png",
}

static var _theme_cache: Dictionary = {}
static var _font_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _stylebox_cache: Dictionary = {}


static func create_theme(locale: String = "en", ui_scale: float = 1.0) -> Theme:
	var normalized_locale := _normalize_locale(locale)
	var scale := _normalize_scale(ui_scale)
	var cache_key := "%s:%.2f" % [normalized_locale, scale]
	if _theme_cache.has(cache_key):
		return _theme_cache[cache_key]

	var theme := Theme.new()
	theme.default_font = _font_for(normalized_locale, "sans_regular")
	theme.default_font_size = roundi(16.0 * scale)
	theme.set_meta("forbidden_table_locale", normalized_locale)
	theme.set_meta("forbidden_table_ui_scale", scale)

	var regular_font: Font = _font_for(normalized_locale, "sans_regular")
	var medium_font: Font = _font_for(normalized_locale, "sans_medium")
	theme.set_font("font", "Label", regular_font)
	theme.set_font_size("font_size", "Label", roundi(16.0 * scale))
	theme.set_color("font_color", "Label", color("text"))
	theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.55))

	theme.set_font("font", "Button", medium_font)
	theme.set_font_size("font_size", "Button", roundi(16.0 * scale))
	theme.set_color("font_color", "Button", color("text"))
	theme.set_color("font_hover_color", "Button", color("text"))
	theme.set_color("font_pressed_color", "Button", color("text"))
	theme.set_color("font_disabled_color", "Button", color("muted"))
	theme.set_stylebox("normal", "Button", _button_stylebox(false, false, "normal", scale))
	theme.set_stylebox("hover", "Button", _button_stylebox(false, false, "hover", scale))
	theme.set_stylebox("pressed", "Button", _button_stylebox(false, false, "pressed", scale))
	theme.set_stylebox("disabled", "Button", _button_stylebox(false, false, "disabled", scale))
	theme.set_stylebox("focus", "Button", _focus_stylebox(scale))

	theme.set_stylebox("panel", "PanelContainer", _panel_stylebox("lacquer", false, scale))
	theme.set_stylebox("panel", "Panel", _panel_stylebox("lacquer", false, scale))
	theme.set_color("default_color", "RichTextLabel", color("text"))
	theme.set_font("normal_font", "RichTextLabel", regular_font)
	theme.set_font_size("normal_font_size", "RichTextLabel", roundi(16.0 * scale))

	_theme_cache[cache_key] = theme
	return theme


static func style_panel(panel: Control, surface: String = "lacquer", selected: bool = false) -> void:
	if panel == null:
		return
	var scale := _scale_for(panel)
	panel.add_theme_stylebox_override("panel", _panel_stylebox(surface, selected, scale))


static func style_button(button: Button, primary: bool = false, selected: bool = false) -> void:
	if button == null:
		return
	var scale := _scale_for(button)
	var locale := _locale_for(button)
	var minimum := button.custom_minimum_size
	minimum.y = maxf(minimum.y, 44.0 * scale)
	button.custom_minimum_size = minimum
	button.add_theme_stylebox_override("normal", _button_stylebox(primary, selected, "normal", scale))
	button.add_theme_stylebox_override("hover", _button_stylebox(primary, selected, "hover", scale))
	button.add_theme_stylebox_override("pressed", _button_stylebox(primary, selected, "pressed", scale))
	button.add_theme_stylebox_override("disabled", _button_stylebox(primary, selected, "disabled", scale))
	button.add_theme_stylebox_override("focus", _focus_stylebox(scale))
	button.add_theme_font_override("font", _font_for(locale, "sans_medium"))
	button.add_theme_font_size_override("font_size", roundi(16.0 * scale))
	button.add_theme_color_override("font_color", color("ink") if primary else color("text"))
	button.add_theme_color_override("font_hover_color", color("ink") if primary else color("text"))
	button.add_theme_color_override("font_pressed_color", color("ink") if primary else color("text"))
	button.add_theme_color_override("font_disabled_color", color("muted"))


static func title(label: Label, locale: String = "en") -> void:
	if label == null:
		return
	var normalized_locale := _normalize_locale(locale)
	var scale := _scale_for(label)
	label.add_theme_font_override("font", _font_for(normalized_locale, "serif_regular"))
	label.add_theme_font_size_override("font_size", roundi(32.0 * scale))
	label.add_theme_color_override("font_color", color("text"))


static func tile_texture(definition_id: String) -> Texture2D:
	if _texture_cache.has(definition_id):
		return _texture_cache[definition_id]
	var face_file := _tile_face_file(definition_id)
	if face_file.is_empty():
		return null
	var path := TILE_DIR + face_file
	if not FileAccess.file_exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture != null:
		_texture_cache[definition_id] = texture
	return texture


static func color(token: String) -> Color:
	return PALETTE.get(token.to_lower(), PALETTE.text)


static func _tile_face_file(definition_id: String) -> String:
	var parts := definition_id.split(".")
	if parts.size() != 4 or parts[0] != "base" or parts[1] != "tile":
		return ""
	var group := str(parts[2])
	var identity := str(parts[3])
	if group in ["characters", "dots", "bamboo"]:
		if identity not in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
			return ""
		var suit_file: String = str({"characters": "m", "dots": "p", "bamboo": "s"}[group])
		return "%s%s.png" % [identity, suit_file]
	if group == "honors":
		return str(HONOR_FACE_FILES.get(identity, ""))
	return ""


static func _normalize_locale(locale: String) -> String:
	return "zh_CN" if locale.to_lower().begins_with("zh") else "en"


static func _normalize_scale(ui_scale: float) -> float:
	return clampf(ui_scale, 0.75, 2.0)


static func _scale_for(control: Control) -> float:
	var themed_scale: Variant = _nearest_theme_metadata(control, "forbidden_table_ui_scale")
	if themed_scale != null:
		return _normalize_scale(float(themed_scale))
	return 1.0


static func _locale_for(control: Control) -> String:
	var themed_locale: Variant = _nearest_theme_metadata(control, "forbidden_table_locale")
	if themed_locale != null:
		return _normalize_locale(str(themed_locale))
	return _normalize_locale(TranslationServer.get_locale())


static func _nearest_theme_metadata(control: Control, key: String) -> Variant:
	var ancestor: Node = control
	while ancestor != null:
		if ancestor is Control:
			var local_theme: Theme = (ancestor as Control).theme
			if local_theme != null and local_theme.has_meta(key):
				return local_theme.get_meta(key)
		ancestor = ancestor.get_parent()
	return null


static func _font_for(locale: String, role: String) -> Font:
	var normalized_locale := _normalize_locale(locale)
	var cache_key := "%s:%s" % [normalized_locale, role]
	if _font_cache.has(cache_key):
		return _font_cache[cache_key]

	var path := EN_SANS_REGULAR
	if normalized_locale == "zh_CN":
		match role:
			"sans_medium": path = SC_SANS_MEDIUM
			"serif_regular": path = SC_SERIF_REGULAR
			_: path = SC_SANS_REGULAR
	else:
		match role:
			"sans_medium": path = EN_SANS_MEDIUM
			"serif_regular": path = EN_SERIF_REGULAR
			_: path = EN_SANS_REGULAR

	var font := load(path) as Font if ResourceLoader.exists(path) else null
	if font == null and normalized_locale != "en":
		font = _font_for("en", role)
	if font != null:
		if normalized_locale == "en":
			_add_cjk_fallback(font, role)
		_font_cache[cache_key] = font
	return font


static func _add_cjk_fallback(font: Font, role: String) -> void:
	var fallback_path := SC_SANS_REGULAR
	match role:
		"sans_medium": fallback_path = SC_SANS_MEDIUM
		"serif_regular": fallback_path = SC_SERIF_REGULAR
	if not ResourceLoader.exists(fallback_path):
		return
	var fallback := load(fallback_path) as Font
	if fallback == null or fallback == font:
		return
	var existing_fallbacks := font.get_fallbacks()
	if fallback not in existing_fallbacks:
		existing_fallbacks.append(fallback)
		font.set_fallbacks(existing_fallbacks)


static func _panel_stylebox(surface: String, selected: bool, scale: float) -> StyleBoxFlat:
	var normalized_surface := surface.to_lower()
	if normalized_surface not in ["lacquer", "raised", "table", "paper", "enemy", "chronicle", "reward"]:
		normalized_surface = "lacquer"
	var normalized_scale := _normalize_scale(scale)
	var cache_key := "panel:%s:%s:%.2f" % [normalized_surface, selected, normalized_scale]
	if _stylebox_cache.has(cache_key):
		return _stylebox_cache[cache_key]

	var style := StyleBoxFlat.new()
	style.bg_color = _panel_color(normalized_surface)
	style.border_color = color("brass") if selected else _panel_edge_color(normalized_surface)
	var border_width := (2 if selected else 1) * normalized_scale
	style.border_width_left = roundi(border_width)
	style.border_width_top = roundi(border_width)
	style.border_width_right = roundi(border_width)
	style.border_width_bottom = roundi(border_width)
	var radius := roundi(3.0 * normalized_scale)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = roundi(12.0 * normalized_scale)
	style.content_margin_top = roundi(12.0 * normalized_scale)
	style.content_margin_right = roundi(12.0 * normalized_scale)
	style.content_margin_bottom = roundi(12.0 * normalized_scale)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = roundi(4.0 * normalized_scale)
	style.shadow_offset = Vector2(0.0, 3.0 * normalized_scale)
	_stylebox_cache[cache_key] = style
	return style


static func _button_stylebox(primary: bool, selected: bool, state: String, scale: float) -> StyleBoxFlat:
	var normalized_scale := _normalize_scale(scale)
	var cache_key := "button:%s:%s:%s:%.2f" % [primary, selected, state, normalized_scale]
	if _stylebox_cache.has(cache_key):
		return _stylebox_cache[cache_key]

	var base := color("brass") if primary else color("raised")
	var style := StyleBoxFlat.new()
	match state:
		"hover": style.bg_color = base.lightened(0.08)
		"pressed": style.bg_color = base.darkened(0.12)
		"disabled": style.bg_color = color("raised").darkened(0.12)
		_: style.bg_color = base
	style.border_color = color("brass") if selected or primary else color("edge")
	if state == "disabled":
		style.border_color = color("muted").darkened(0.38)
	style.border_width_left = roundi((2.0 if selected else 1.0) * normalized_scale)
	style.border_width_top = roundi((2.0 if selected else 1.0) * normalized_scale)
	style.border_width_right = roundi((2.0 if selected else 1.0) * normalized_scale)
	style.border_width_bottom = roundi((2.0 if selected else 1.0) * normalized_scale)
	var radius := roundi(3.0 * normalized_scale)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = roundi(12.0 * normalized_scale)
	style.content_margin_top = roundi(8.0 * normalized_scale)
	style.content_margin_right = roundi(12.0 * normalized_scale)
	style.content_margin_bottom = roundi(8.0 * normalized_scale)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = roundi(4.0 * normalized_scale)
	style.shadow_offset = Vector2(0.0, 3.0 * normalized_scale)
	_stylebox_cache[cache_key] = style
	return style


static func _focus_stylebox(scale: float) -> StyleBoxFlat:
	var normalized_scale := _normalize_scale(scale)
	var cache_key := "focus:%.2f" % normalized_scale
	if _stylebox_cache.has(cache_key):
		return _stylebox_cache[cache_key]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.draw_center = false
	style.border_color = color("focus")
	var width := roundi(3.0 * normalized_scale)
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	var radius := roundi(5.0 * normalized_scale)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.expand_margin_left = width
	style.expand_margin_top = width
	style.expand_margin_right = width
	style.expand_margin_bottom = width
	_stylebox_cache[cache_key] = style
	return style


static func _panel_color(surface: String) -> Color:
	match surface:
		"raised": return color("raised")
		"table": return Color(0.055, 0.098, 0.086, 0.94)
		"paper", "chronicle": return color("paper")
		"enemy": return Color(0.16, 0.075, 0.06, 0.97)
		"reward": return Color(0.09, 0.16, 0.12, 0.97)
		_: return color("lacquer")


static func _panel_edge_color(surface: String) -> Color:
	if surface == "enemy":
		return color("vermilion")
	if surface in ["paper", "chronicle", "reward"]:
		return color("brass")
	return color("edge")
