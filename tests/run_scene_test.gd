class_name RunSceneTest
extends RefCounted

const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunScene = preload("res://scenes/run/run_scene.tscn")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_launch_scene_uses_the_two_act_presentation_flow(failures)
	test_contract_choices_explain_alpha_tradeoffs(failures)
	test_invalid_catalogs_block_run_start(failures)
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

func test_contract_choices_explain_alpha_tradeoffs(failures: Array[String]) -> void:
	var registry = ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	AlphaScaleCatalogScript.register_all(registry)
	var domain = RunDomainScript.new("run.scene.contract_details", 601, registry)
	domain.unlock_policy = MetaProgressStateScript.all_unlocked_test_profile()
	var controller = RunPresentationControllerScript.new(domain)
	var scene = RunScene.instantiate()
	var character_result = controller.confirm("character:base.character.sequence")
	assert_true(character_result.accepted, "Contract detail fixture reaches Contract selection", failures)
	var contract_actions: Array = controller.action_descriptors()
	var expected_names := {
		"alpha.contract.quiet_current": "Quiet Current",
		"alpha.contract.open_ledger": "Open Ledger",
		"alpha.contract.brittle_compass": "Brittle Compass",
	}
	for contract_id in expected_names:
		var matching_actions: Array = contract_actions.filter(func(action): return action.get("id", "") == "contract:%s" % contract_id)
		assert_true(matching_actions.size() == 1, "%s remains one stable selectable Contract action" % contract_id, failures)
		if matching_actions.is_empty():
			continue
		var action: Dictionary = matching_actions[0]
		var details: Dictionary = action.get("details", {})
		assert_true(details.get("name", "") == expected_names[contract_id], "%s presents its readable name" % contract_id, failures)
		assert_true(not str(details.get("risk_summary", "")).is_empty(), "%s explains its risk before selection" % contract_id, failures)
		assert_true(not str(details.get("reward_summary", "")).is_empty(), "%s explains its reward before selection" % contract_id, failures)
		assert_true(not str(details.get("build_bias_summary", "")).is_empty(), "%s explains its build bias before selection" % contract_id, failures)
		assert_true(details.has("yaku_signal_summary"), "%s declares its Yaku signal or its absence" % contract_id, failures)
		var label: String = scene._action_label(action)
		assert_true(label.contains(expected_names[contract_id]), "%s name is visible on its selection button" % contract_id, failures)
		assert_true(label.contains(str(details.get("risk_summary", ""))) and label.contains(str(details.get("reward_summary", ""))), "%s button includes readable risk and reward summaries" % contract_id, failures)
		var tooltip: String = scene._action_tooltip(action)
		assert_true(tooltip.contains("Build bias:") and tooltip.contains(str(details.get("build_bias_summary", ""))), "%s details show its build bias" % contract_id, failures)
		assert_true(tooltip.contains("Yaku signal:") and tooltip.contains(str(details.get("yaku_signal_summary", ""))), "%s details show its Yaku signal" % contract_id, failures)

	var open_ledger_actions: Array = contract_actions.filter(func(action): return action.get("id", "") == "contract:alpha.contract.open_ledger")
	if not open_ledger_actions.is_empty():
		var open_ledger_details: Dictionary = open_ledger_actions[0].details
		assert_true(open_ledger_details.get("yaku_signal", "") == "Sequence", "Open Ledger preserves its typed Sequence Yaku signal", failures)
		assert_true(str(open_ledger_details.get("build_bias_summary", "")).contains("Characters 4") and str(open_ledger_details.get("build_bias_summary", "")).contains("Characters 6"), "Open Ledger explains its preferred Characters 4–6 build", failures)
	var phase_two_action = contract_actions.filter(func(action): return action.get("id", "") == "contract:base.contract.pressure")[0]
	assert_true(not str(phase_two_action.get("details", {}).get("risk_summary", "")).is_empty(), "Phase 2 Contracts receive the same readable detail format", failures)
	var selected = controller.confirm("contract:alpha.contract.open_ledger")
	assert_true(selected.accepted and domain.state.contract_id == "alpha.contract.open_ledger", "a detailed Contract remains selectable through its stable action ID", failures)
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

func test_invalid_catalogs_block_run_start(failures: Array[String]) -> void:
	var duplicate_registration_scene = RunScene.instantiate()
	duplicate_registration_scene.content_registry_factory = func():
		var registry = ContentRegistryScript.new()
		registry.register(Phase2CatalogScript.definitions()[0])
		return registry
	duplicate_registration_scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new("user://run_scene_invalid_registration_test.json"),
	)
	duplicate_registration_scene._ready()
	assert_true(duplicate_registration_scene.controller == null, "the launch scene does not create a RunDomain after catalog registration fails", failures)
	assert_true(duplicate_registration_scene._feedback_value.visible, "catalog registration failure is visible to the player", failures)
	assert_true(duplicate_registration_scene._feedback_value.text.contains("duplicate_id"), "catalog registration failure identifies the duplicate content ID", failures)
	duplicate_registration_scene.free()

	var missing_reference_scene = RunScene.instantiate()
	missing_reference_scene.content_registry_factory = func():
		var registry = ContentRegistryScript.new()
		registry.register(EncounterDefinitionScript.new(
			"alpha.encounter.invalid_launch_fixture",
			["alpha.enemy.missing_launch_fixture"],
		))
		return registry
	missing_reference_scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new("user://run_scene_missing_reference_test.json"),
	)
	missing_reference_scene._ready()
	assert_true(missing_reference_scene.controller == null, "the launch scene does not create a RunDomain with an unresolved content reference", failures)
	assert_true(missing_reference_scene._feedback_value.visible, "cross-reference validation failure is visible to the player", failures)
	assert_true(missing_reference_scene._feedback_value.text.contains("missing_reference"), "cross-reference validation reports the issue code", failures)
	assert_true(missing_reference_scene._feedback_value.text.contains("alpha.enemy.missing_launch_fixture"), "cross-reference validation reports the missing target ID", failures)
	missing_reference_scene.free()

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
