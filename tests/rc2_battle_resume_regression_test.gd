extends RefCounted

const RunSceneScript = preload("res://scenes/run/run_scene.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const CheckpointPolicyScript = preload("res://src/domain/run/suspend_checkpoint_policy.gd")
const GuidedSampleMapCatalogScript = preload("res://src/presentation/run/guided_sample_map_catalog.gd")
const LocalizationCatalogScript = preload("res://src/presentation/localization/localization.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")

const RESUME_READY_KEY := "UI_RUN_SCENE_0157"
const UNAVAILABLE_KEY := "UI_RUN_SCENE_0054"


func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["RC2 Battle/resume regression requires a SceneTree"]

	var preferences = tree.root.get_node_or_null("PresentationPrefs")
	var prior_preferences: Dictionary = preferences.snapshot() if preferences != null else {}
	_set_test_locale(preferences, "en")
	var suffix := "%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]

	await _test_normal_run_and_resume(tree, preferences, suffix, failures)
	await _test_guided_sample_battle(tree, preferences, suffix, failures)
	await _test_battle_construction_failure(tree, suffix, failures)
	_test_checkpoint_labels(preferences, failures)

	if preferences != null and not prior_preferences.is_empty():
		preferences.call("_apply_in_memory", prior_preferences)
	else:
		TranslationServer.set_locale("en")
	print("RC2_BATTLE_RESUME_REPORT failures=%d isolated_user_paths=true" % failures.size())
	return failures


func _test_normal_run_and_resume(tree: SceneTree, preferences, suffix: String, failures: Array[String]) -> void:
	var suspend_path := "user://rc2_battle_resume_%s_normal_suspend.json" % suffix
	var profile_path := "user://rc2_battle_resume_%s_normal_profile.json" % suffix
	var source_scene = _new_run_scene(tree, suspend_path, profile_path)
	await _settle(tree)
	var reached_battle := await _advance_to_battle(source_scene, "", failures, "normal Run")
	_assert(reached_battle, "normal Run reaches its first Battle", failures)
	if reached_battle:
		_assert(source_scene._battle_view != null and source_scene._battle_view.visible, "normal Run displays the real BattleView", failures)
		_assert(not source_scene._journey_view.visible, "normal Run hides generic action lists during Battle", failures)
		var hand: Node = source_scene.find_child("BattleHandTiles", true, false)
		_assert(hand != null, "normal Run BattleView includes the packed tile-hand UI", failures)

	var saved_bytes := FileAccess.get_file_as_string(suspend_path) if FileAccess.file_exists(suspend_path) else ""
	_assert(not saved_bytes.is_empty(), "normal Run writes an isolated checkpoint before resume", failures)
	for locale in ["en", "zh_CN"]:
		_set_test_locale(preferences, locale)
		var resumed_scene = _new_run_scene(tree, suspend_path, profile_path)
		await _settle(tree)
		var expected_ready := str(TranslationServer.translate(RESUME_READY_KEY))
		var unavailable := str(TranslationServer.translate(UNAVAILABLE_KEY))
		_assert(resumed_scene.controller == null and resumed_scene._pending_resume_domain != null, "%s startup recognizes a valid saved Run while awaiting Continue" % locale, failures)
		_assert(resumed_scene._phase_value.text == expected_ready and expected_ready != RESUME_READY_KEY, "%s startup labels the valid saved Run as ready" % locale, failures)
		_assert(resumed_scene._phase_value.text != unavailable, "%s startup does not call valid progress unavailable" % locale, failures)
		_assert(resumed_scene._resume_run_button.visible and not resumed_scene._resume_run_button.disabled, "%s valid save keeps Continue available" % locale, failures)
		var details_button := resumed_scene.find_child("SuspendDetailsButton", true, false) as Button
		if details_button != null:
			details_button.emit_signal("pressed")
		await _settle(tree)
		var details := resumed_scene.find_child("SuspendDetailsValue", true, false) as Label
		var expected_boundary := ""
		if resumed_scene.has_method("_checkpoint_label"):
			expected_boundary = str(resumed_scene.call("_checkpoint_label", "BATTLE_START"))
		_assert(not expected_boundary.is_empty() and not expected_boundary.begins_with("[MISSING"), "%s saved Battle checkpoint has a localized boundary label" % locale, failures)
		_assert(details != null and details.visible and details.text.contains(expected_boundary), "%s resume details display the saved Battle checkpoint" % locale, failures)
		_assert(details != null and not details.text.contains("[MISSING"), "%s resume details contain no missing localization placeholder" % locale, failures)
		_assert(FileAccess.get_file_as_string(suspend_path) == saved_bytes, "%s valid-resume startup leaves the isolated checkpoint unchanged" % locale, failures)
		resumed_scene.queue_free()
		await _settle(tree)

	_set_test_locale(preferences, "en")
	source_scene.queue_free()
	await _settle(tree)
	_cleanup_test_paths([suspend_path, profile_path])


func _test_guided_sample_battle(tree: SceneTree, preferences, suffix: String, failures: Array[String]) -> void:
	_set_test_locale(preferences, "en")
	var suspend_path := "user://rc2_battle_resume_%s_sample_suspend.json" % suffix
	var profile_path := "user://rc2_battle_resume_%s_sample_profile.json" % suffix
	var scene = _new_run_scene(tree, suspend_path, profile_path)
	await _settle(tree)
	var entry := scene.find_child("GuidedSampleButton", true, false) as Button
	_assert(entry != null and entry.visible and not entry.disabled, "Run offers Guided Sample entry", failures)
	if entry != null:
		entry.emit_signal("pressed")
	await _settle(tree)
	_assert(scene._guided_sample_session != null and scene._guided_sample_session.is_active(), "Guided Sample starts an isolated session", failures)
	var reached_battle := false
	if scene.controller != null and scene._guided_sample_session != null:
		var character_ok := _accept_action(scene, "CHARACTER", "", failures, "Guided Sample")
		var contract_ok := character_ok and _accept_action(scene, "CONTRACT", "", failures, "Guided Sample")
		var map_ok := contract_ok and _accept_action(scene, "MAP_NODE", GuidedSampleMapCatalogScript.INTRO_NODE, failures, "Guided Sample")
		await _settle(tree)
		reached_battle = map_ok and str(scene.controller.domain.state.phase) == RunPhaseScript.BATTLE
	_assert(reached_battle, "Guided Sample enters its first Battle through the real Run scene", failures)
	if reached_battle:
		_assert(scene._battle_view != null and scene._battle_view.visible, "Guided Sample displays the real BattleView", failures)
		_assert(not scene._journey_view.visible, "Guided Sample hides generic action lists during Battle", failures)
		_assert(scene.find_child("BattleHandTiles", true, false) != null, "Guided Sample BattleView includes the packed tile-hand UI", failures)
	_assert(not FileAccess.file_exists(suspend_path), "Guided Sample does not write campaign Suspend data", failures)
	scene.queue_free()
	await _settle(tree)
	_cleanup_test_paths([suspend_path, profile_path])


func _test_battle_construction_failure(tree: SceneTree, suffix: String, failures: Array[String]) -> void:
	var suspend_path := "user://rc2_battle_resume_%s_failure_suspend.json" % suffix
	var profile_path := "user://rc2_battle_resume_%s_failure_profile.json" % suffix
	var scene = _new_run_scene(tree, suspend_path, profile_path)
	await _settle(tree)
	if scene.get("_battle_view_resource_path") == null:
		scene.queue_free()
		await _settle(tree)
		_cleanup_test_paths([suspend_path, profile_path])
		return
	scene.set("_battle_view_resource_path", "res://missing/rc2_test_battle_view.gd")
	var reached_battle := await _advance_to_battle(scene, "", failures, "failure-path Run")
	_assert(reached_battle, "failure-path fixture reaches Battle", failures)
	if reached_battle:
		var failure_panel := scene.find_child("BattleViewFailure", true, false) as Control
		var failure_message := scene.find_child("BattleViewFailureMessage", true, false) as Label
		_assert(failure_panel != null and failure_panel.visible, "Battle construction failure has a visible presentation panel", failures)
		_assert(failure_message != null and not failure_message.text.is_empty(), "Battle construction failure explains the missing presentation", failures)
		_assert(not scene._journey_view.visible, "Battle construction failure does not fall back to generic Run actions", failures)
	scene.queue_free()
	await _settle(tree)
	_cleanup_test_paths([suspend_path, profile_path])


func _test_checkpoint_labels(preferences, failures: Array[String]) -> void:
	var probe = RunSceneScript.new()
	if not probe.has_method("_checkpoint_label"):
		_assert(false, "RunScene has an explicit display mapping for stable checkpoint boundaries", failures)
		probe.free()
		return
	for locale in ["en", "zh_CN"]:
		_set_test_locale(preferences, locale)
		var unknown_label := LocalizationCatalogScript.text("UI_RUN_CHECKPOINT_UNKNOWN")
		for boundary in CheckpointPolicyScript.STABLE_BOUNDARIES:
			var label := str(probe.call("_checkpoint_label", str(boundary)))
			_assert(not label.is_empty() and label != str(boundary) and label != unknown_label and not label.begins_with("[MISSING"), "%s maps stable checkpoint %s to its own localized label" % [locale, str(boundary)], failures)
	probe.free()


func _new_run_scene(tree: SceneTree, suspend_path: String, profile_path: String):
	var scene = RunSceneScript.new()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	tree.root.add_child(scene)
	return scene


func _advance_to_battle(scene, exact_map_node_id: String, failures: Array[String], context: String) -> bool:
	for kind in ["CHARACTER", "CONTRACT"]:
		if not _accept_action(scene, kind, "", failures, context):
			return false
	var map_node_id := exact_map_node_id
	if map_node_id.is_empty():
		map_node_id = "*"
	return _accept_action(scene, "MAP_NODE", map_node_id, failures, context)


func _accept_action(scene, kind: String, target_id: String, failures: Array[String], context: String) -> bool:
	if kind == "CHARACTER" and target_id.is_empty():
		target_id = "base.character.sequence"
	if scene.controller == null:
		_assert(false, "%s exposes %s action before Battle" % [context, kind], failures)
		return false
	for action in scene.controller.action_descriptors():
		if not action is Dictionary or str(action.get("kind", "")) != kind:
			continue
		if target_id != "" and target_id != "*" and str(action.get("target_id", "")) != target_id:
			continue
		var result = scene._on_action_pressed(str(action.get("id", "")))
		var accepted := result != null and bool(result.accepted)
		_assert(accepted, "%s accepts %s action" % [context, kind], failures)
		return accepted
	_assert(false, "%s offers a %s action" % [context, kind], failures)
	return false


func _set_test_locale(preferences, locale: String) -> void:
	if preferences != null and preferences.has_method("_apply_in_memory"):
		var values: Dictionary = preferences.snapshot()
		values["locale"] = locale
		preferences.call("_apply_in_memory", values)
	else:
		TranslationServer.set_locale(locale)


func _settle(tree: SceneTree) -> void:
	for _frame in range(4):
		await tree.process_frame


func _cleanup_test_paths(paths: Array[String]) -> void:
	for path in paths:
		for suffix in ["", ".tmp", ".bak", ".rejected"]:
			var absolute_path := ProjectSettings.globalize_path(path + suffix)
			if FileAccess.file_exists(absolute_path):
				DirAccess.remove_absolute(absolute_path)


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if condition:
		print("PASS " + message)
		return
	failures.append("ASSERTION FAILED: " + message)
	push_error("ASSERTION FAILED: " + message)
