class_name RunSceneTest
extends RefCounted

const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunScene = preload("res://scenes/run/run_scene.tscn")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_launch_scene_uses_the_two_act_presentation_flow(failures)
	test_pre_mvp_scene_has_no_device_capture_ui(failures)
	test_rejected_profile_is_explained_and_can_be_reset(failures)
	return failures

func test_launch_scene_uses_the_two_act_presentation_flow(failures: Array[String]) -> void:
	var scene = RunScene.instantiate()
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new("user://run_scene_test_profile.json"),
	)
	scene._ready()
	assert_true(scene.controller != null, "launch scene creates a RunPresentationController", failures)
	assert_true(scene.controller.domain.state.act_count == 2, "launch scene creates one continuous two-Act Run", failures)
	assert_true(scene.controller.action_descriptors().any(func(action): return action.get("kind") == "CHARACTER"), "launch screen presents real Character choices", failures)
	assert_true(scene.controller.action_descriptors().filter(func(action): return action.get("kind") == "CHARACTER").size() == 2, "a fresh launch profile shows its two unlocked Characters", failures)
	assert_true(scene.controller.domain.content_registry.resolve("alpha.character.harbor_reader") != null, "the new Character is registered even while its Run-start unlock is pending", failures)

	var character_action: Dictionary = scene.controller.action_descriptors().filter(func(action): return action.get("kind") == "CHARACTER")[0]
	scene._on_action_pressed(str(character_action.id))
	assert_true(scene.controller.domain.state.tile_pool.tile_instances.size() == 14, "the Character command initializes its starting Tile Pool inside RunDomain", failures)
	var contract_action: Dictionary = scene.controller.action_descriptors().filter(func(action): return action.get("kind") == "CONTRACT")[0]
	assert_true(scene.controller.action_descriptors().filter(func(action): return action.get("kind") == "CONTRACT").size() == 3, "a fresh launch profile shows its three unlocked Contracts", failures)
	scene._on_action_pressed(str(contract_action.id))
	var map_action: Dictionary = scene.controller.action_descriptors().filter(func(action): return action.get("kind") == "MAP_NODE")[0]
	scene._on_action_pressed(str(map_action.id))
	assert_true(scene.controller.domain.state.phase == RunPhaseScript.BATTLE, "choosing a map node starts the real Run battle", failures)
	assert_true(scene.controller.domain.current_battle != null, "the Run scene uses the RunDomain BattleDomain", failures)

	var draw_result = scene._on_action_pressed("battle.draw")
	assert_true(draw_result.accepted, "Draw is accepted in the Run battle", failures)
	var battle_actions: Array = scene.controller.action_descriptors()
	assert_true(battle_actions.any(func(action): return action.get("kind") == "RESERVE"), "battle actions expose Store Tile options for tiles in hand", failures)
	for action in battle_actions:
		assert_true(not scene._action_label(action).is_empty(), "every action has a readable on-screen label", failures)

	var project_config := FileAccess.get_file_as_string("res://project.godot")
	assert_true(project_config.contains("res://scenes/run/run_scene.tscn"), "project main scene points to the playable Run scene", failures)
	var replay_report = scene.controller.domain.verify_replay()
	assert_true(replay_report.status == "MATCH", "the candidate starting profile remains inside accepted-command replay", failures)
	scene.free()

func test_pre_mvp_scene_has_no_device_capture_ui(failures: Array[String]) -> void:
	var scene = RunScene.instantiate()
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new("user://run_scene_device_scope_test.json"),
	)
	scene._ready()
	assert_true(scene.find_child("DeviceEvidenceCapture", true, false) == null, "the pre-MVP Run scene does not create a device evidence capture node", failures)
	assert_true(not scene._profile_status.text.contains("device"), "profile messaging does not imply device checks", failures)
	scene.free()

func test_rejected_profile_is_explained_and_can_be_reset(failures: Array[String]) -> void:
	var path := "user://run_scene_rejected_profile_%d.json" % Time.get_ticks_usec()
	var source := "{ unsupported profile bytes"
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "the isolated rejected-profile fixture can be written", failures)
	if file == null:
		return
	file.store_string(source)
	file.close()
	var scene = RunScene.instantiate()
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(path))
	scene._ready()
	assert_true(scene.meta_progress_coordinator.recovery_required, "a rejected profile keeps progression writes blocked in the Run scene", failures)
	assert_true(scene._profile_status.visible and scene._profile_status.text.contains("could not be loaded"), "the Run scene keeps a player-facing rejected-profile explanation visible", failures)
	assert_true(scene._reset_profile_button.visible, "the Run scene offers an explicit progression profile reset", failures)
	var preserved_path: String = scene.meta_progress_coordinator.last_rejected_profile_path
	scene._on_reset_profile_pressed()
	assert_true(not scene.meta_progress_coordinator.recovery_required, "explicit reset re-enables progression after writing a valid default profile", failures)
	assert_true(FileAccess.get_file_as_string(preserved_path) == source, "explicit reset leaves the rejected save recoverable", failures)
	scene.free()
	for suffix in ["", ".rejected"]:
		var candidate: String = ProjectSettings.globalize_path(path) + suffix
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
