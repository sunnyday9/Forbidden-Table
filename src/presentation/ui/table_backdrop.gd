class_name TableBackdrop
extends Control

const ForbiddenThemeScript = preload("res://src/presentation/ui/forbidden_theme.gd")
const SALON_TEXTURE_PATH := "res://assets/ui/art/haunted-salon.png"
const AMBIENT_GLOW_SHADER := """
shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(0.93, 0.62, 0.24, 0.11);
uniform float pulse = 0.0;

void fragment() {
	vec2 offset = UV - vec2(0.84, 0.19);
	offset.x *= 1.45;
	float light = exp(-dot(offset, offset) * 42.0);
	COLOR = vec4(glow_color.rgb, glow_color.a * light * pulse);
}
"""

var ambient_glow_requested: bool = false
var presentation_mode: String = "NORMAL"
var reduced_motion: bool = false
var background_rect: TextureRect
var scrim: ColorRect
var glow_layer: ColorRect
var _glow_material: ShaderMaterial
var _glow_tween: Tween


func _ready() -> void:
	_build_layers()
	_sync_ambient_glow()


func configure(mode: String = "NORMAL", reduced: bool = false, ambient_glow: bool = false) -> void:
	set_motion_preferences(mode, reduced)
	set_ambient_glow(ambient_glow)


func set_motion_preferences(mode: String, reduced: bool = false) -> void:
	presentation_mode = _normalize_mode(mode)
	reduced_motion = reduced
	_sync_ambient_glow()


func set_ambient_glow(enabled: bool) -> void:
	ambient_glow_requested = enabled
	_sync_ambient_glow()


func is_ambient_glow_active() -> bool:
	return _glow_tween != null and _glow_tween.is_running()


func _build_layers() -> void:
	if background_rect == null:
		background_rect = TextureRect.new()
		background_rect.name = "SalonArtwork"
		background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_rect.focus_mode = Control.FOCUS_NONE
		background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		background_rect.texture = load(SALON_TEXTURE_PATH) as Texture2D
		background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(background_rect)

	if scrim == null:
		scrim = ColorRect.new()
		scrim.name = "ReadabilityScrim"
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scrim.focus_mode = Control.FOCUS_NONE
		var table_color: Color = ForbiddenThemeScript.color("table")
		scrim.color = Color(table_color.r, table_color.g, table_color.b, 0.48)
		scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(scrim)

	if glow_layer == null:
		glow_layer = ColorRect.new()
		glow_layer.name = "LanternGlow"
		glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow_layer.focus_mode = Control.FOCUS_NONE
		glow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var glow_shader := Shader.new()
		glow_shader.code = AMBIENT_GLOW_SHADER
		_glow_material = ShaderMaterial.new()
		_glow_material.shader = glow_shader
		_glow_material.set_shader_parameter("pulse", 0.0)
		glow_layer.material = _glow_material
		glow_layer.visible = false
		add_child(glow_layer)


func _sync_ambient_glow() -> void:
	if not is_inside_tree():
		return
	_build_layers()
	if not ambient_glow_requested or reduced_motion or presentation_mode == "INSTANT":
		_stop_glow()
		return
	if is_ambient_glow_active():
		return
	glow_layer.visible = true
	_glow_material.set_shader_parameter("pulse", 0.46)
	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.set_trans(Tween.TRANS_SINE)
	_glow_tween.set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(_glow_material, "shader_parameter/pulse", 0.78, 2.5)
	_glow_tween.tween_property(_glow_material, "shader_parameter/pulse", 0.46, 2.5)


func _stop_glow() -> void:
	if _glow_tween != null and _glow_tween.is_running():
		_glow_tween.kill()
	_glow_tween = null
	if _glow_material != null:
		_glow_material.set_shader_parameter("pulse", 0.0)
	if glow_layer != null:
		glow_layer.visible = false


func _normalize_mode(mode: String) -> String:
	var normalized := mode.to_upper()
	return normalized if normalized in ["NORMAL", "FAST", "INSTANT"] else "NORMAL"
