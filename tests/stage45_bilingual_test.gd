class_name Stage45BilingualTest
extends RefCounted

class RejectingSuspendStore extends RefCounted:
	func write_snapshot(_snapshot) -> Dictionary:
		return {"accepted": false, "code": "TEST_WRITE_FAILED"}

	func clear() -> Dictionary:
		return {"accepted": true}

const Localization = preload("res://src/presentation/localization/localization.gd")
const PreferencesScript = preload("res://src/presentation/localization/presentation_preferences.gd")
const PreferencesOverlayScript = preload("res://src/presentation/ui/preferences_overlay.gd")
const TutorialProgressScript = preload("res://src/presentation/run/tutorial_progress.gd")
const ForbiddenTheme = preload("res://src/presentation/ui/forbidden_theme.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const DrawCommandScript = preload("res://src/domain/commands/draw_command.gd")
const EndTurnCommandScript = preload("res://src/domain/commands/end_turn_command.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")

var _prefs: Variant


func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	_prefs = tree.root.get_node_or_null("PresentationPrefs")
	if _prefs == null:
		return ["PresentationPrefs autoload is registered before the focused locale suite"]
	var original_preferences: Dictionary = _prefs.snapshot()
	var original_locale := TranslationServer.get_locale()
	var original_config_path: String = str(_prefs.config_path)
	var unique_id := str(Time.get_ticks_usec())
	var test_config_path := "user://stage45_test_prefs_%s.cfg" % unique_id
	var unsupported_config_path := "user://stage45_test_unsupported_%s.cfg" % unique_id
	var corrupt_config_path := "user://stage45_test_corrupt_%s.cfg" % unique_id
	var failure_config_path := "user://stage45_test_missing_%s/preferences.cfg" % unique_id
	_remove_user_file(test_config_path)
	_remove_user_file(unsupported_config_path)
	_remove_user_file(corrupt_config_path)

	_prefs.config_path = test_config_path
	_prefs.apply_preferences({
		"locale": "en",
		"presentation_mode": "NORMAL",
		"reduced_motion": false,
		"ambient_glow": true,
		"ui_scale": 1.0,
	})
	_test_locale_policy(failures)
	_test_catalog_runtime(failures)
	_test_cross_locale_content_and_resume(failures)
	_test_feedback_locale_refresh(failures)
	_test_preferences_round_trip(test_config_path, failures)
	_test_unsupported_preference(unsupported_config_path, failures)
	_test_corrupt_preferences(corrupt_config_path, failures)
	await _test_overlay_interaction(test_config_path, failures)
	_test_persistence_failure(failure_config_path, failures)
	_test_font_coverage(failures)

	_prefs.config_path = original_config_path
	_prefs.locale = str(original_preferences.get("locale", "en"))
	_prefs.presentation_mode = str(original_preferences.get("presentation_mode", "NORMAL"))
	_prefs.reduced_motion = bool(original_preferences.get("reduced_motion", false))
	_prefs.ambient_glow = bool(original_preferences.get("ambient_glow", true))
	_prefs.ui_scale = float(original_preferences.get("ui_scale", 1.0))
	TranslationServer.set_locale(original_locale)
	_prefs.preferences_changed.emit(original_preferences.duplicate(true))
	_remove_user_file(test_config_path)
	_remove_user_file(unsupported_config_path)
	_remove_user_file(corrupt_config_path)
	_remove_user_file(failure_config_path)
	return failures


func _test_locale_policy(failures: Array[String]) -> void:
	assert_true(PreferencesScript.locale_from_system_identifier("en_US") == "en", "English system variants select English", failures)
	assert_true(PreferencesScript.locale_from_system_identifier("zh_CN") == "zh_CN", "Simplified Chinese system locale selects zh_CN", failures)
	assert_true(PreferencesScript.locale_from_system_identifier("zh-SG") == "zh_CN", "Singapore Chinese maps to Simplified Chinese", failures)
	assert_true(PreferencesScript.locale_from_system_identifier("zh-Hans-CN") == "zh_CN", "explicit Hans locale maps to Simplified Chinese", failures)
	assert_true(PreferencesScript.locale_from_system_identifier("zh-Hant-TW") == "en", "explicit Traditional Chinese falls back to English", failures)
	assert_true(PreferencesScript.locale_from_system_identifier("zh-HK") == "en", "Hong Kong Chinese falls back to English", failures)
	assert_true(PreferencesScript.locale_from_system_identifier("ja_JP") == "en", "unsupported system language falls back to English", failures)


func _test_catalog_runtime(failures: Array[String]) -> void:
	_prefs.apply_preferences({"locale": "en"})
	assert_true(Localization.text("UI_PREFS_TITLE") == "Help / Settings", "English preference labels render from the keyed catalog", failures)
	assert_true(Localization.text("UI_PREFS_SCALE_125") == "125%", "escaped literal percent signs render once", failures)
	var canonical_reaction_label := Localization.canonical_text("CONTENT_TECHNIQUE_0005")
	assert_true(canonical_reaction_label == "enemy Contamination is added", "canonical content lookup reads the English source resource", failures)
	assert_true(Localization.format("UI_RUN_JOURNEY_0003", [2]) == "Act 2 · Choose your path", "English UI interpolation resolves its number", failures)
	assert_true(Localization.format("UI_RUN_JOURNEY_RESOURCES", [12, 3, "East Wind", "Act 1 map"]) == "Gold 12 · Refinement 3 · East Wind · Act 1 map", "English resource rail preserves all four typed placeholders", failures)
	_prefs.apply_preferences({"locale": "zh_CN"})
	assert_true(Localization.text("base.character.reserve") == "藏牌师", "Reserve character has a distinct Chinese name", failures)
	assert_true(Localization.text("base.character.sequence") == "顺子师", "Sequence character has a distinct Chinese name", failures)
	assert_true(Localization.text("WORD_RESERVE") == "备牌", "Reserve zone keeps its separate Chinese term", failures)
	assert_true(Localization.text("base.tile.honors.west") == "西风", "West wind uses its honor-tile name", failures)
	assert_true(Localization.text("base.tile.honors.white") == "白板", "White dragon uses its honor-tile name", failures)
	assert_true(Localization.text("base.tile.honors.green") == "发财", "Green dragon uses its honor-tile name", failures)
	for suit in ["characters", "bamboo", "dots"]:
		for rank in range(1, 10):
			var tile_key := "base.tile.%s.%d" % [suit, rank]
			var translated := Localization.text(tile_key)
			assert_true(not translated.to_lower().contains("characters") and not translated.to_lower().contains("bamboo") and not translated.to_lower().contains("dots"), "%s has a Chinese tile name" % tile_key, failures)
	_prefs.apply_preferences({"locale": "zh_CN"})
	assert_true(Localization.text("UI_PREFS_TITLE") == "帮助 / 设置", "Simplified Chinese preference screen renders its localized title", failures)
	assert_true(Localization.text("UI_PREFS_SCALE_125") == "125%", "Chinese scale labels preserve one literal percent sign", failures)
	assert_true(Localization.format("UI_RUN_JOURNEY_0003", [2]) == "第 2 幕 · 选择路线", "Chinese UI interpolation resolves its number", failures)
	assert_true(Localization.format("UI_RUN_JOURNEY_0025", [8, 3]) == "金币不足：需要 8，当前 3。", "Chinese interpolation preserves two typed values and order", failures)
	assert_true(Localization.format("UI_RUN_JOURNEY_RESOURCES", [12, 3, "东风", "第一幕地图"]) == "金币 12 · 精炼 3 · 东风 · 第一幕地图", "Chinese resource rail preserves all four typed placeholders", failures)
	assert_true(Localization.format("UI_BATTLE_VIEW_0008", [2, 5, 6, 8]) == "恢复阶段 · 回合 2 / 5 · 手牌 6 / 8", "battle copy preserves the order of four placeholders", failures)
	assert_true(Localization.format("UI_RUN_JOURNEY_MAP_NODE_LABEL", ["战斗", "当前"]) == "战斗\n当前", "localized map node template retains its newline", failures)
	assert_true(Localization.text("UI_RUN_SCENE_0038") == "禁忌牌桌", "runtime title uses the approved localized product display name", failures)
	assert_true(Localization.canonical_text("CONTENT_TECHNIQUE_0005") == canonical_reaction_label, "canonical content text stays English under Simplified Chinese", failures)
	assert_true(Localization.display_text(canonical_reaction_label) == "敌方污染已增加", "presentation lookup translates canonical English through the stable source key", failures)
	assert_true(Localization.display_text("composed runtime text") == "composed runtime text", "presentation lookup preserves unknown dynamic text", failures)


func _test_cross_locale_content_and_resume(failures: Array[String]) -> void:
	var original_locale := TranslationServer.get_locale()
	var english_run := _create_catalog_run("en", failures)
	var chinese_run := _create_catalog_run("zh_CN", failures)
	var english_domain: Variant = english_run.get("domain")
	var chinese_domain: Variant = chinese_run.get("domain")
	if english_domain == null or chinese_domain == null:
		TranslationServer.set_locale(original_locale)
		return
	assert_true(english_domain.state.content_version == chinese_domain.state.content_version, "catalog registration version is locale independent", failures)
	assert_true(english_domain.checkpoint() == chinese_domain.checkpoint(), "same fixed Run identity and seed produce equal cross-locale catalog checkpoints and hashes", failures)
	assert_true(english_domain.rng_snapshot() == chinese_domain.rng_snapshot(), "cross-locale catalog initialization preserves exact RNG state", failures)
	assert_true(english_domain.replay_record.serialize() == chinese_domain.replay_record.serialize(), "same accepted commands produce identical cross-locale replay bytes", failures)
	var english_intent: Dictionary = english_domain.state.current_battle_snapshot.to_dictionary().get("combat_state", {}).get("current_intent", {})
	var chinese_intent: Dictionary = chinese_domain.state.current_battle_snapshot.to_dictionary().get("combat_state", {}).get("current_intent", {})
	assert_true(english_intent.get("display_name", "") == chinese_intent.get("display_name", ""), "serialized enemy intent labels remain canonical across catalog locales", failures)

	var chinese_registry = chinese_domain.content_registry
	var snapshot: Dictionary = SaveMapperScript.suspend_snapshot(english_domain).to_dictionary()
	TranslationServer.set_locale("zh_CN")
	var resumed: Dictionary = SaveMapperScript.load_into_domain(snapshot, chinese_registry)
	assert_true(bool(resumed.get("accepted", false)), "English checkpoint resumes against catalogs registered under Simplified Chinese", failures)
	if resumed.get("accepted", false):
		var resumed_domain: Variant = resumed.get("domain")
		assert_true(resumed_domain.checkpoint() == english_domain.checkpoint(), "cross-locale resume restores the exact authoritative checkpoint and hash", failures)
		assert_true(resumed_domain.rng_snapshot() == english_domain.rng_snapshot(), "cross-locale resume restores the exact RNG streams", failures)
		var draw_command = DrawCommandScript.new("stage45.cross_locale.draw")
		var end_turn_command = EndTurnCommandScript.new("stage45.cross_locale.end_turn")
		var original_draw = english_domain.execute(draw_command)
		var resumed_draw = resumed_domain.execute(draw_command)
		assert_true(original_draw.accepted and resumed_draw.accepted, "the same future Draw is accepted before and after cross-locale resume", failures)
		var original_end_turn = english_domain.execute(end_turn_command)
		var resumed_end_turn = resumed_domain.execute(end_turn_command)
		assert_true(original_end_turn.accepted and resumed_end_turn.accepted, "the same future End Turn is accepted before and after cross-locale resume", failures)
		assert_true(resumed_domain.checkpoint() == english_domain.checkpoint(), "future state and hashes match after cross-locale resume", failures)
		assert_true(resumed_domain.rng_snapshot() == english_domain.rng_snapshot(), "future RNG output matches after cross-locale resume", failures)
		assert_true(english_domain.verify_replay().status == "MATCH" and resumed_domain.verify_replay().status == "MATCH", "full and resumed cross-locale replay segments both verify", failures)
	TranslationServer.set_locale(original_locale)
	if _prefs != null:
		_prefs.locale = original_locale


func _create_catalog_run(locale: String, failures: Array[String]) -> Dictionary:
	TranslationServer.set_locale(locale)
	var registry = ContentRegistryScript.new()
	var phase2_report = Phase2CatalogScript.register_all(registry)
	var act_two_report = AlphaActTwoCatalogScript.register_all(registry)
	var scale_report = AlphaScaleCatalogScript.register_all(registry)
	assert_true(phase2_report.is_valid() and act_two_report.is_valid() and scale_report.is_valid(), "%s catalog set registers successfully" % locale, failures)
	var domain = RunDomainScript.new("stage45.cross-locale.catalog", 451230, registry)
	var controller = RunPresentationControllerScript.new(domain)
	var character_result = controller.confirm("character:base.character.sequence")
	var contract_result = controller.confirm("contract:base.contract.pressure")
	var map_actions: Array = controller.action_descriptors()
	assert_true(character_result.accepted and contract_result.accepted and not map_actions.is_empty(), "%s accepts the shared character and contract commands" % locale, failures)
	if map_actions.is_empty():
		return {"domain": domain, "controller": controller}
	var map_result = controller.confirm(str(map_actions[0].get("id", "")))
	assert_true(map_result.accepted, "%s enters the shared seeded battle" % locale, failures)
	return {"domain": domain, "controller": controller}


func _test_feedback_locale_refresh(failures: Array[String]) -> void:
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var domain = RunDomainScript.new("stage45.feedback.locale", 451231)
	var controller = RunPresentationControllerScript.new(domain)
	var events: Array = [
		DomainEventScript.new(DomainEventScript.COMPLETE_HAND_SETTLED),
		DomainEventScript.new(DomainEventScript.BATTLE_WON),
	]
	var checkpoint_before: Dictionary = domain.checkpoint()
	var rng_before: Dictionary = domain.rng_snapshot()
	var replay_before: String = domain.replay_record.serialize()
	controller._refresh(events)
	var english_feedback := str(controller.state.feedback)
	assert_true(english_feedback == "Complete Hand settled. Victory!", "ordered critical feedback is cached in the current locale", failures)
	TranslationServer.set_locale("zh_CN")
	controller.refresh_localized_presentation()
	var chinese_feedback := str(controller.state.feedback)
	assert_true(chinese_feedback == "完整和牌已结算。 胜利！", "locale refresh regenerates the ordered event feedback in Simplified Chinese", failures)
	assert_true(domain.checkpoint() == checkpoint_before and domain.rng_snapshot() == rng_before and domain.replay_record.serialize() == replay_before, "event feedback refresh leaves checkpoint, RNG, and replay bytes unchanged", failures)
	TranslationServer.set_locale("en")
	controller.refresh_localized_presentation()
	assert_true(controller.state.feedback == english_feedback, "switching back restores the original event feedback language and order", failures)
	assert_true(domain.checkpoint() == checkpoint_before and domain.rng_snapshot() == rng_before and domain.replay_record.serialize() == replay_before, "round-trip feedback refresh remains presentation-only", failures)

	controller.set_mode("UNSUPPORTED")
	var english_mode_error := str(controller.state.feedback)
	TranslationServer.set_locale("zh_CN")
	controller.refresh_localized_presentation()
	assert_true(english_mode_error == "Unknown presentation mode." and controller.state.feedback == "未知的演出模式。", "exact ordinary controller feedback translates across locale changes", failures)

	var warning_run := _create_catalog_run("en", failures)
	var warning_controller: Variant = warning_run.get("controller")
	warning_controller.suspend_store = RejectingSuspendStore.new()
	var draw_result = warning_controller.submit(DrawCommandScript.new("stage45.feedback.persistence"))
	var english_persistence_warning := str(warning_controller.state.feedback)
	var warning_domain: Variant = warning_run.get("domain")
	var warning_checkpoint: Dictionary = warning_domain.checkpoint()
	var warning_rng: Dictionary = warning_domain.rng_snapshot()
	var warning_replay: String = warning_domain.replay_record.serialize()
	assert_true(draw_result.accepted and english_persistence_warning == Localization.format("UI_RUN_CONTROLLER_0001", ["TEST_WRITE_FAILED"]), "failed Suspend Save formats its keyed English persistence warning", failures)
	TranslationServer.set_locale("zh_CN")
	warning_controller.refresh_localized_presentation()
	var chinese_persistence_warning := Localization.format("UI_RUN_CONTROLLER_0001", ["TEST_WRITE_FAILED"])
	assert_true(warning_controller.state.feedback == chinese_persistence_warning and chinese_persistence_warning.contains("TEST_WRITE_FAILED") and chinese_persistence_warning.contains("未写入暂停存档"), "formatted persistence warning relocalizes while preserving its failure code", failures)
	assert_true(warning_domain.checkpoint() == warning_checkpoint and warning_domain.checkpoint().state_hash == warning_checkpoint.state_hash and warning_domain.rng_snapshot() == warning_rng and warning_domain.replay_record.serialize() == warning_replay, "Chinese warning refresh leaves checkpoint, state hash, RNG, and replay bytes unchanged", failures)
	TranslationServer.set_locale("en")
	warning_controller.refresh_localized_presentation()
	assert_true(warning_controller.state.feedback == english_persistence_warning, "formatted persistence warning returns exactly to English", failures)
	assert_true(warning_domain.checkpoint() == warning_checkpoint and warning_domain.checkpoint().state_hash == warning_checkpoint.state_hash and warning_domain.rng_snapshot() == warning_rng and warning_domain.replay_record.serialize() == warning_replay, "warning locale round trip leaves checkpoint, state hash, RNG, and replay bytes unchanged", failures)
	warning_controller._set_feedback("historic composed warning TEST_WRITE_FAILED")
	TranslationServer.set_locale("zh_CN")
	warning_controller.refresh_localized_presentation()
	assert_true(warning_controller.state.feedback == "historic composed warning TEST_WRITE_FAILED", "unknown historic warning text remains intact after locale refresh", failures)
	TranslationServer.set_locale(original_locale)
	if _prefs != null:
		_prefs.locale = original_locale


func _test_preferences_round_trip(path: String, failures: Array[String]) -> void:
	var expected: Dictionary = _prefs.apply_preferences({
		"locale": "zh_CN",
		"presentation_mode": "fast",
		"reduced_motion": true,
		"ambient_glow": false,
		"ui_scale": 1.25,
	})
	assert_true(expected.locale == "zh_CN" and expected.presentation_mode == "FAST", "preferences normalize and apply supported values", failures)
	assert_true(expected.reduced_motion and not expected.ambient_glow and is_equal_approx(float(expected.ui_scale), 1.25), "presentation toggles and 125% scale are applied", failures)
	var restored = PreferencesScript.new()
	restored.config_path = path
	var loaded: Dictionary = restored.reload_preferences()
	assert_true(loaded == expected, "saved explicit preferences override system language on reload", failures)
	assert_true(restored.locale == "zh_CN", "reloaded preference retains the selected locale", failures)
	restored.free()
	var unsupported: Dictionary = _prefs.apply_preferences({"locale": "zh_TW"})
	assert_true(unsupported.locale == "en", "unsupported explicit locale safely normalizes to English", failures)


func _test_unsupported_preference(path: String, failures: Array[String]) -> void:
	var config := ConfigFile.new()
	config.set_value("preferences", "locale", "zh_TW")
	config.set_value("preferences", "presentation_mode", "UNKNOWN")
	assert_true(config.save(path) == OK, "unsupported locale fixture saves to its isolated user path", failures)
	var preferences = PreferencesScript.new()
	preferences.config_path = path
	var loaded: Dictionary = preferences.reload_preferences()
	assert_true(loaded.locale == "en", "unsupported saved locale falls back to English", failures)
	assert_true(loaded.presentation_mode == "NORMAL", "unsupported saved mode falls back to Normal", failures)
	preferences.free()


func _test_corrupt_preferences(path: String, failures: Array[String]) -> void:
	var config := ConfigFile.new()
	config.set_value("preferences", "locale", "zh_TW")
	config.set_value("preferences", "presentation_mode", "UNKNOWN")
	config.set_value("preferences", "ui_scale", -2.0)
	assert_true(config.save(path) == OK, "corrupt preference values fixture saves to its isolated user path", failures)
	var preferences = PreferencesScript.new()
	preferences.config_path = path
	var loaded: Dictionary = preferences.reload_preferences()
	assert_true(loaded.locale == "en", "corrupt preferences recover to English defaults", failures)
	assert_true(loaded.presentation_mode == "NORMAL" and is_equal_approx(float(loaded.ui_scale), 1.0), "corrupt presentation values recover to supported defaults", failures)
	preferences.free()


func _test_overlay_interaction(path: String, failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var controller_bindings: Array[Dictionary] = [
		_bind_joypad_action("ui_focus_next", JOY_BUTTON_RIGHT_SHOULDER),
		_bind_joypad_action("ui_focus_prev", JOY_BUTTON_LEFT_SHOULDER),
		_bind_joypad_action("ui_right", JOY_BUTTON_DPAD_RIGHT),
		_bind_joypad_action("ui_accept", JOY_BUTTON_A),
		_bind_joypad_action("ui_cancel", JOY_BUTTON_B),
	]
	var host := Control.new()
	tree.root.add_child(host)
	var origin := Button.new()
	origin.name = "OriginFocus"
	host.add_child(origin)
	origin.grab_focus()
	var progress = TutorialProgressScript.new()
	progress.completed_step_ids = [TutorialProgressScript.DRAW_PATTERN_PARTIAL]
	progress.current_step_id = TutorialProgressScript.TP_CORE_TECHNIQUE
	var overlay = PreferencesOverlayScript.new()
	host.add_child(overlay)
	var applied_events: Array[Dictionary] = []
	var closed_events: Array[bool] = []
	overlay.preferences_applied.connect(func(preferences: Dictionary) -> void: applied_events.append(preferences.duplicate(true)))
	overlay.closed.connect(func() -> void: closed_events.append(true))
	var initial_preferences: Dictionary = _prefs.snapshot()
	overlay.open(initial_preferences, origin, progress)
	overlay.call("_focus_initial")
	await tree.process_frame
	await tree.process_frame
	var help_tab := overlay.find_child("HelpTabButton", true, false) as Button
	if help_tab != null:
		help_tab.emit_signal("pressed")
	await tree.process_frame
	await tree.process_frame
	_assert_help_page_fills_scroll(overlay, "English at 100%", failures)
	var settings_tab := overlay.find_child("SettingsTabButton", true, false) as Button
	if settings_tab != null:
		settings_tab.emit_signal("pressed")
	await tree.process_frame
	overlay.call("_focus_initial")
	var initial_modal_focus := tree.root.get_viewport().gui_get_focus_owner()
	overlay.call("_input", _controller_event(JOY_BUTTON_RIGHT_SHOULDER))
	var shoulder_focus := tree.root.get_viewport().gui_get_focus_owner()
	assert_true(shoulder_focus != initial_modal_focus and overlay.is_ancestor_of(shoulder_focus), "controller shoulder action moves focus within the open modal", failures)
	overlay.call("_input", _controller_event(JOY_BUTTON_DPAD_RIGHT))
	var dpad_focus := tree.root.get_viewport().gui_get_focus_owner()
	assert_true(dpad_focus != shoulder_focus and overlay.is_ancestor_of(dpad_focus), "controller D-pad action moves between modal choices", failures)
	var chinese_button := overlay.find_child("Language_zh_CN", true, false) as Button
	assert_true(chinese_button != null, "language setting exposes a Simplified Chinese choice", failures)
	if chinese_button != null:
		chinese_button.grab_focus()
		overlay.call("_input", _controller_event(JOY_BUTTON_A))
	assert_true(_prefs.locale == "en", "choosing a language remains pending until Apply", failures)
	var tutorial_toggle := overlay.find_child("TutorialEnabledButton", true, false) as CheckButton
	if tutorial_toggle != null:
		tutorial_toggle.set_pressed_no_signal(false)
		tutorial_toggle.toggled.emit(false)
	overlay.call("_input", _controller_event(JOY_BUTTON_B))
	assert_true(_prefs.locale == "en", "Cancel discards the pending language selection", failures)
	assert_true(bool(progress.enabled), "Cancel discards the pending tutorial toggle", failures)
	assert_true(tree.root.get_viewport().gui_get_focus_owner() == origin, "closing the overlay restores focus to its origin", failures)
	var config := ConfigFile.new()
	assert_true(config.load(path) == OK and config.get_value("preferences", "locale", "") == "en", "Cancel does not persist a pending locale", failures)

	overlay.open(_prefs.snapshot(), origin, progress)
	chinese_button = overlay.find_child("Language_zh_CN", true, false) as Button
	if chinese_button != null:
		chinese_button.grab_focus()
		overlay.call("_input", _controller_event(JOY_BUTTON_A))
	var large_scale_button := overlay.find_child("Scale_150", true, false) as Button
	if large_scale_button != null:
		large_scale_button.grab_focus()
		overlay.call("_input", _controller_event(JOY_BUTTON_A))
	assert_true(is_equal_approx(float(overlay._preferences.get("ui_scale", 1.0)), 1.5), "controller accept selects the supported 150% scale", failures)
	assert_true(is_equal_approx(float(_prefs.ui_scale), float(initial_preferences.get("ui_scale", 1.0))), "scale remains pending until Apply", failures)
	help_tab = overlay.find_child("HelpTabButton", true, false) as Button
	if help_tab != null:
		help_tab.emit_signal("pressed")
	await tree.process_frame
	await tree.process_frame
	_assert_help_page_fills_scroll(overlay, "Chinese at 150%", failures)
	var reset_button := overlay.find_child("TutorialResetButton", true, false) as Button
	if reset_button != null:
		reset_button.emit_signal("pressed")
	assert_true(progress.completed_step_ids.size() == 1, "tutorial reset stays pending before Apply", failures)
	var focus_before_shoulder := tree.root.get_viewport().gui_get_focus_owner()
	overlay.call("_input", _controller_event(JOY_BUTTON_RIGHT_SHOULDER))
	var focus_owner := tree.root.get_viewport().gui_get_focus_owner()
	assert_true(focus_owner != focus_before_shoulder and focus_owner != null and overlay.is_ancestor_of(focus_owner), "controller shoulder navigation remains trapped inside the open modal", failures)
	var apply_button := overlay.find_child("ApplyButton", true, false) as Button
	if apply_button != null:
		apply_button.grab_focus()
		overlay.call("_input", _controller_event(JOY_BUTTON_A))
	assert_true(_prefs.locale == "zh_CN", "Apply changes the active locale", failures)
	assert_true(is_equal_approx(float(_prefs.ui_scale), 1.5), "Apply commits the controller-selected 150% scale", failures)
	assert_true(bool(progress.enabled) and progress.completed_step_ids.is_empty(), "Apply commits the pending tutorial reset", failures)
	assert_true(not overlay.visible and applied_events.size() == 1, "Apply emits preferences_applied and closes after persistence", failures)
	assert_true(not closed_events.is_empty(), "the closed signal fires on cancel and Apply", failures)
	assert_true(tree.root.get_viewport().gui_get_focus_owner() == origin, "Apply restores focus to its origin control", failures)
	var reloaded = PreferencesScript.new()
	reloaded.config_path = path
	assert_true(reloaded.reload_preferences().locale == "zh_CN", "applied locale survives a preferences reload", failures)
	reloaded.free()

	overlay.open(_prefs.snapshot(), origin, null)
	var title := overlay.find_child("TitleLabel", true, false) as Label
	assert_true(title != null and title.text == "帮助 / 设置", "reopened settings text follows the active locale", failures)
	overlay.close()
	overlay.queue_free()
	origin.queue_free()
	host.queue_free()
	for binding in controller_bindings:
		_remove_joypad_binding(binding)


func _assert_help_page_fills_scroll(overlay: PreferencesOverlay, state: String, failures: Array[String]) -> void:
	var scroll := overlay._help_scroll as ScrollContainer
	var page := overlay._help_page as Control
	assert_true(scroll.size.x > 0.0 and page.size.x > 0.0, "%s Help body has laid out dimensions" % state, failures)
	assert_true(page.size.x >= scroll.size.x * 0.95, "%s Help page fills the available scroll width (page %.0fpx / body %.0fpx)" % [state, page.size.x, scroll.size.x], failures)
	var intro: Label
	for node in overlay.find_children("*", "Label", true, false):
		var candidate := node as Label
		if candidate.has_meta("localization_key") and str(candidate.get_meta("localization_key")) == "UI_PREFS_HELP_INTRO":
			intro = candidate
			break
	assert_true(intro != null and intro.size.x >= scroll.size.x * 0.85, "%s wrapped Help copy uses the full content width" % state, failures)


func _test_persistence_failure(path: String, failures: Array[String]) -> void:
	_prefs.config_path = path
	var applied: Dictionary = _prefs.apply_preferences({"locale": "zh_CN", "presentation_mode": "INSTANT"})
	assert_true(applied.locale == "zh_CN" and applied.presentation_mode == "INSTANT", "write failure keeps the selected settings active for this session", failures)
	assert_true(not _prefs.last_persistence_error.is_empty(), "write failure is exposed so the UI can offer retry", failures)


func _test_font_coverage(failures: Array[String]) -> void:
	for path in [
		"res://assets/ui/fonts/NotoSansSC-Regular.otf",
		"res://assets/ui/fonts/NotoSansSC-Medium.otf",
		"res://assets/ui/fonts/NotoSerifSC-Regular.otf",
	]:
		assert_true(ResourceLoader.exists(path), "%s is imported for runtime use" % path, failures)
	var theme := ForbiddenTheme.create_theme("zh_CN", 1.5)
	assert_true(theme.default_font != null and theme.default_font.has_char("禁".unicode_at(0)), "Simplified Chinese body font covers the product title glyph", failures)
	assert_true(theme.default_font != null and theme.default_font.has_char("牌".unicode_at(0)), "Simplified Chinese body font covers common tile terminology", failures)


func _remove_user_file(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _bind_joypad_action(action: String, button_index: int) -> Dictionary:
	var action_created := not InputMap.has_action(action)
	if action_created:
		InputMap.add_action(action)
	var binding := InputEventJoypadButton.new()
	binding.device = -1
	binding.button_index = button_index
	var binding_created := not InputMap.action_has_event(action, binding)
	if binding_created:
		InputMap.action_add_event(action, binding)
	return {"action": action, "event": binding, "action_created": action_created, "binding_created": binding_created}


func _remove_joypad_binding(binding: Dictionary) -> void:
	var action := str(binding.action)
	if bool(binding.binding_created):
		InputMap.action_erase_event(action, binding.event)
	if bool(binding.action_created):
		InputMap.erase_action(action)


func _controller_event(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button_index
	event.pressed = true
	return event


func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
