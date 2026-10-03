class_name PresentationPreferences
extends Node

signal preferences_changed(preferences: Dictionary)

const DEFAULT_CONFIG_PATH := "user://presentation_preferences.cfg"
const SUPPORTED_LOCALES := ["en", "zh_CN"]
const PRESENTATION_MODES := ["NORMAL", "FAST", "INSTANT"]
const DEFAULT_VALUES := {
	"locale": "en",
	"presentation_mode": "NORMAL",
	"reduced_motion": false,
	"ambient_glow": true,
	"ui_scale": 1.0,
}

var locale := "en"
var presentation_mode := "NORMAL"
var reduced_motion := false
var ambient_glow := true
var ui_scale := 1.0

# This remains profile/presentation configuration. It is never included in a Run snapshot.
var config_path := DEFAULT_CONFIG_PATH
var last_persistence_error := ""


func _ready() -> void:
	reload_preferences()


func reload_preferences() -> Dictionary:
	var values: Dictionary = DEFAULT_VALUES.duplicate(true)
	var config := ConfigFile.new()
	var load_error: Error = config.load(config_path)
	if load_error == OK:
		if config.has_section_key("preferences", "locale"):
			var saved_locale := str(config.get_value("preferences", "locale", ""))
			values.locale = _normalize_locale(saved_locale, true)
		else:
			values.locale = _system_locale()
		values.presentation_mode = config.get_value("preferences", "presentation_mode", values.presentation_mode)
		values.reduced_motion = config.get_value("preferences", "reduced_motion", values.reduced_motion)
		values.ambient_glow = config.get_value("preferences", "ambient_glow", values.ambient_glow)
		values.ui_scale = config.get_value("preferences", "ui_scale", values.ui_scale)
	elif load_error == ERR_FILE_NOT_FOUND:
		values.locale = _system_locale()
	else:
		# A corrupt file must not prevent startup or retain an unsupported selection.
		last_persistence_error = error_string(load_error)
		values = DEFAULT_VALUES.duplicate(true)
	_apply_in_memory(values)
	return snapshot()


func apply_preferences(values: Dictionary) -> Dictionary:
	var normalized := _normalized_dictionary(values)
	var previous := snapshot()
	_apply_in_memory(normalized)
	last_persistence_error = ""
	var save_error := _save_preferences()
	if save_error != OK:
		last_persistence_error = error_string(save_error)
	if previous != snapshot():
		preferences_changed.emit(snapshot())
	return snapshot()


func snapshot() -> Dictionary:
	return {
		"locale": locale,
		"presentation_mode": presentation_mode,
		"reduced_motion": reduced_motion,
		"ambient_glow": ambient_glow,
		"ui_scale": ui_scale,
	}


func to_dictionary() -> Dictionary:
	return snapshot()


static func locale_from_system_identifier(identifier: String) -> String:
	var normalized := identifier.strip_edges().replace("-", "_").to_lower()
	if normalized.is_empty():
		return "en"
	var parts := normalized.split("_", false)
	if parts.is_empty():
		return "en"
	if parts[0] == "en":
		return "en"
	if parts[0] != "zh":
		return "en"
	# Generic Chinese and explicit Simplified variants use zh_CN. Explicit Traditional
	# identifiers remain unsupported and safely fall back to English.
	if normalized in ["zh_hant", "zh_hant_tw", "zh_tw", "zh_hk", "zh_mo"]:
		return "en"
	if normalized in ["zh", "zh_cn", "zh_sg", "zh_hans", "zh_hans_cn", "zh_hans_sg"]:
		return "zh_CN"
	return "en"


func _system_locale() -> String:
	return locale_from_system_identifier(OS.get_locale())


func _normalize_locale(value: String, unsupported_to_english: bool = true) -> String:
	var normalized := value.strip_edges().replace("-", "_")
	if normalized in SUPPORTED_LOCALES:
		return normalized
	if not unsupported_to_english:
		return _system_locale()
	return "en"


func _normalized_dictionary(values: Dictionary) -> Dictionary:
	var normalized := snapshot()
	if values.has("locale"):
		normalized.locale = _normalize_locale(str(values.locale))
	if values.has("presentation_mode"):
		var requested_mode := str(values.presentation_mode).to_upper()
		normalized.presentation_mode = requested_mode if requested_mode in PRESENTATION_MODES else "NORMAL"
	if values.has("reduced_motion"):
		normalized.reduced_motion = bool(values.reduced_motion)
	if values.has("ambient_glow"):
		normalized.ambient_glow = bool(values.ambient_glow)
	if values.has("ui_scale"):
		var requested_scale := clampf(float(values.ui_scale), 1.0, 1.5)
		normalized.ui_scale = 1.0 if requested_scale < 1.125 else (1.25 if requested_scale < 1.375 else 1.5)
	return normalized


func _apply_in_memory(values: Dictionary) -> void:
	var normalized := _normalized_dictionary(values)
	locale = str(normalized.locale)
	presentation_mode = str(normalized.presentation_mode)
	reduced_motion = bool(normalized.reduced_motion)
	ambient_glow = bool(normalized.ambient_glow)
	ui_scale = float(normalized.ui_scale)
	TranslationServer.set_locale(locale)


func _save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("preferences", "locale", locale)
	config.set_value("preferences", "presentation_mode", presentation_mode)
	config.set_value("preferences", "reduced_motion", reduced_motion)
	config.set_value("preferences", "ambient_glow", ambient_glow)
	config.set_value("preferences", "ui_scale", ui_scale)
	return config.save(config_path)
