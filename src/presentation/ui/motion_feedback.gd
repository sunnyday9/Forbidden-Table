class_name MotionFeedback
extends Node

signal playback_finished

const NORMAL := "NORMAL"
const FAST := "FAST"
const INSTANT := "INSTANT"
const FAST_DURATION_SCALE := 0.4

var presentation_mode: String = NORMAL
var reduced_motion: bool = false
var _active_tween: Tween
var _active_target: WeakRef
var _active_property: NodePath
var _active_final_value: Variant
var _generation: int = 0


func configure(mode: String = NORMAL, reduced: bool = false) -> void:
	var changed := presentation_mode != _normalize_mode(mode) or reduced_motion != reduced
	presentation_mode = _normalize_mode(mode)
	reduced_motion = reduced
	if changed:
		cancel()


func set_presentation_mode(mode: String) -> void:
	var normalized := _normalize_mode(mode)
	if normalized == presentation_mode:
		return
	presentation_mode = normalized
	cancel()


func set_reduced_motion(enabled: bool) -> void:
	if reduced_motion == enabled:
		return
	reduced_motion = enabled
	cancel()


func play_property(
	target: Object,
	property: NodePath,
	from_value: Variant,
	final_value: Variant,
	duration_seconds: float,
	delay_seconds: float = 0.0,
) -> bool:
	if target == null or not is_instance_valid(target) or not _has_property(target, property):
		return false
	cancel()

	# Call after rendering the accepted final state. Restrict use to cosmetic properties; keep critical
	# result text readable throughout. This node never disables Controls, captures focus, or submits commands.
	target.set_indexed(property, final_value)
	if _animations_disabled():
		target.set_indexed(property, final_value)
		return true

	var duration := maxf(0.0, duration_seconds) * _duration_scale()
	var delay := maxf(0.0, delay_seconds) * _duration_scale()
	if duration <= 0.0:
		target.set_indexed(property, final_value)
		return true

	_active_target = weakref(target)
	_active_property = property
	_active_final_value = final_value
	_generation += 1
	var generation := _generation
	target.set_indexed(property, from_value)
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_OUT)
	if delay > 0.0:
		_active_tween.tween_interval(delay)
	_active_tween.tween_property(target, property, final_value, duration)
	_active_tween.finished.connect(_on_tween_finished.bind(generation), CONNECT_ONE_SHOT)
	return true


func cancel() -> void:
	var had_active_playback := _active_tween != null
	_generation += 1
	var active := _active_tween
	_active_tween = null
	if active != null and active.is_running():
		active.kill()
	_restore_active_final_value()
	_active_target = null
	_active_property = NodePath()
	_active_final_value = null
	if had_active_playback:
		playback_finished.emit()


func _on_tween_finished(generation: int) -> void:
	if generation != _generation:
		return
	_restore_active_final_value()
	_active_tween = null
	_active_target = null
	_active_property = NodePath()
	_active_final_value = null
	playback_finished.emit()


func _restore_active_final_value() -> void:
	if _active_target == null:
		return
	var target: Variant = _active_target.get_ref()
	if target != null and is_instance_valid(target) and _has_property(target, _active_property):
		target.set_indexed(_active_property, _active_final_value)


func _has_property(target: Object, property: NodePath) -> bool:
	if property.is_empty():
		return false
	var first_segment := str(property).get_slice(":", 0).get_slice("/", 0)
	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) == first_segment:
			return true
	return false


func _animations_disabled() -> bool:
	return reduced_motion or presentation_mode == INSTANT


func _duration_scale() -> float:
	return FAST_DURATION_SCALE if presentation_mode == FAST else 1.0


func _normalize_mode(mode: String) -> String:
	var normalized := mode.to_upper()
	return normalized if normalized in [NORMAL, FAST, INSTANT] else NORMAL
