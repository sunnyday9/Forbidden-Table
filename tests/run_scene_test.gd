class_name RunSceneTest
extends RefCounted

const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const DomainEventScript = preload("res://src/domain/events/domain_event.gd")
const TileZoneScript = preload("res://src/domain/tiles/tile_zone.gd")
const RunScene = preload("res://scenes/run/run_scene.tscn")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const EncounterDefinitionScript = preload("res://src/content/definitions/encounter_definition.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const StoreTileCommandScript = preload("res://src/domain/commands/store_tile_command.gd")
const SwapReserveTileCommandScript = preload("res://src/domain/commands/swap_reserve_tile_command.gd")
const UseTechniqueCommandScript = preload("res://src/domain/commands/use_technique_command.gd")
const TechniqueDefinitionScript = preload("res://src/content/definitions/technique_definition.gd")
const EffectScript = preload("res://src/domain/effects/effect.gd")
const EffectTriggerScript = preload("res://src/domain/effects/effect_trigger.gd")
const StateEffectConditionScript = preload("res://src/domain/effects/conditions/state_condition.gd")
const GainStabilityOperationScript = preload("res://src/domain/effects/operations/gain_stability_operation.gd")
const GainTPOperationScript = preload("res://src/domain/effects/operations/gain_tp_operation.gd")
const RunBattleSnapshotScript = preload("res://src/domain/run/run_battle_snapshot.gd")
const SaveCoordinatorScript = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const SuspendSaveStoreScript = preload("res://src/infrastructure/persistence/suspend_save_store.gd")
const SuspendSnapshotScript = preload("res://src/infrastructure/persistence/suspend_snapshot.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")
const Phase2V1SuspendSnapshotFixtureScript = preload("res://tests/fixtures/phase2_v1_suspend_snapshot.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_launch_scene_uses_the_two_act_presentation_flow(failures)
	test_contract_choices_explain_alpha_tradeoffs(failures)
	test_run_scene_persists_and_resumes_suspend_save(failures)
	test_rejected_suspend_save_is_preserved_for_explicit_recovery(failures)
	test_interrupted_suspend_sources_are_not_rolled_back(failures)
	test_suspend_writer_preserves_unresolved_sidecars(failures)
	test_suspend_write_failure_is_visible(failures)
	test_terminal_new_run_retires_old_suspend_slot(failures)
	test_player_can_discard_a_hand_tile(failures)
	test_reserve_swap_is_atomic_and_limited_per_draw(failures)
	test_battle_action_descriptors_only_offer_legal_manipulations(failures)
	test_owned_active_technique_is_available(failures)
	test_late_technique_effect_rejection_rolls_back(failures)
	test_invalid_catalogs_block_run_start(failures)
	test_pre_mvp_scene_has_no_device_capture_ui(failures)
	test_rejected_profile_is_explained_and_can_be_reset(failures)
	return failures

func test_launch_scene_uses_the_two_act_presentation_flow(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var suspend_path := "user://run_scene_launch_%s.json" % suffix
	var profile_path := "user://run_scene_test_profile_%s.json" % suffix
	var scene = RunScene.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
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
	_clear_test_file(suspend_path)
	_clear_test_file(profile_path)

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

func test_run_scene_persists_and_resumes_suspend_save(failures: Array[String]) -> void:
	var suspend_path := "user://run_scene_suspend_%d.json" % Time.get_ticks_usec()
	var profile_path := "user://run_scene_suspend_profile_%d.json" % Time.get_ticks_usec()
	_clear_test_file(suspend_path)
	_clear_test_file(profile_path)
	var first = _new_isolated_run_scene(suspend_path, profile_path)
	first._ready()
	assert_true(first.controller != null, "a new Run starts when no Suspend Save exists", failures)
	if first.controller == null:
		first.free()
		return
	var run_id := str(first.controller.domain.state.run_id)
	first._on_action_pressed("character:base.character.sequence")
	first._on_action_pressed("contract:base.contract.pressure")
	assert_true(FileAccess.file_exists(suspend_path), "the accepted Contract choice saves the first stable map boundary", failures)
	var stable_contract_save := FileAccess.get_file_as_string(suspend_path)
	var rejected = first._on_action_pressed("not-an-available-action")
	assert_true(not rejected.accepted and FileAccess.get_file_as_string(suspend_path) == stable_contract_save, "rejected presentation input does not change the accepted-only Suspend Save", failures)
	var map_actions: Array = first.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "MAP_NODE")
	assert_true(not map_actions.is_empty(), "the fixture reaches a legal map choice", failures)
	if map_actions.is_empty():
		first.free()
		return
	var accepted_map = first._on_action_pressed(str(map_actions[0].get("id", "")))
	assert_true(accepted_map.accepted, "the stable map choice is accepted", failures)
	assert_true(FileAccess.file_exists(suspend_path), "an accepted stable-boundary command writes the real Suspend Save", failures)
	var draw = first.controller.confirm("battle.draw")
	assert_true(draw.accepted, "a Draw from the active battle is accepted before the persistence comparison", failures)
	var saved_bytes := FileAccess.get_file_as_string(suspend_path)
	var loaded_save: Dictionary = SaveMapperScript.load_into_domain(saved_bytes, first.controller.domain.content_registry)
	assert_true(loaded_save.get("accepted", false), "the persisted Suspend Save reloads through SaveMapper", failures)
	if loaded_save.get("accepted", false):
		assert_true(loaded_save.snapshot.checkpoint_metadata.get("stable_boundary", "") == "DRAW_ACTION", "Draw checkpoints carry the accepted Draw boundary instead of a generic Battle start", failures)
		assert_true(loaded_save.domain.state.run_id == run_id, "the disk snapshot identifies the active Run", failures)
		assert_true(loaded_save.domain.checkpoint() == first.controller.domain.checkpoint(), "the disk snapshot preserves the exact stable RunState and checkpoint", failures)
		assert_true(loaded_save.domain.rng_snapshot() == first.controller.domain.rng_snapshot(), "the disk snapshot preserves every RNG stream", failures)

	var resumed = _new_isolated_run_scene(suspend_path, profile_path)
	resumed._ready()
	assert_true(resumed.controller == null, "launch waits for an explicit Resume or New Run choice", failures)
	assert_true(resumed.find_child("ResumeRunButton", true, false) is Button, "an existing Suspend Save offers a Resume action", failures)
	assert_true(resumed.find_child("NewRunFromSuspendButton", true, false) is Button, "an existing Suspend Save offers a New Run action", failures)
	assert_true(FileAccess.get_file_as_string(suspend_path) == saved_bytes, "launching the scene does not overwrite the Suspend Save", failures)
	var resume_button = resumed.find_child("ResumeRunButton", true, false)
	if resume_button is Button:
		resume_button.emit_signal("pressed")
	assert_true(resumed.controller != null and resumed.controller.domain.state.run_id == run_id, "choosing Resume restores the saved Run instead of starting a new one", failures)
	if resumed.controller != null and first.controller != null:
		assert_true(resumed.controller.domain.checkpoint() == first.controller.domain.checkpoint(), "the player-facing Resume choice restores the exact state", failures)
		assert_true(resumed.controller.domain.rng_snapshot() == first.controller.domain.rng_snapshot(), "the player-facing Resume choice restores exact RNG state", failures)
		var uninterrupted_draw = first.controller.confirm("battle.draw")
		var resumed_draw = resumed.controller.confirm("battle.draw")
		assert_true(uninterrupted_draw.accepted and resumed_draw.accepted, "the same future Draw remains legal on both paths", failures)
		if uninterrupted_draw.accepted and resumed_draw.accepted and first.controller.domain.current_battle != null and resumed.controller.domain.current_battle != null:
			assert_true(first.controller.domain.current_battle.checkpoint() == resumed.controller.domain.current_battle.checkpoint(), "future Draw outputs match after disk Resume", failures)
			assert_true(first.controller.domain.rng_snapshot() == resumed.controller.domain.rng_snapshot(), "future RNG state matches after the same resumed command", failures)
		var uninterrupted_end_turn = first.controller.confirm("battle.end_turn")
		var resumed_end_turn = resumed.controller.confirm("battle.end_turn")
		assert_true(uninterrupted_end_turn.accepted and resumed_end_turn.accepted, "EndTurn resolves identically on uninterrupted and resumed paths", failures)
		if resumed_end_turn.accepted:
			var end_turn_save: Dictionary = SaveMapperScript.load_into_domain(FileAccess.get_file_as_string(suspend_path), resumed.controller.domain.content_registry)
			assert_true(end_turn_save.get("accepted", false) and end_turn_save.snapshot.checkpoint_metadata.get("stable_boundary", "") == "ENEMY_INTENT_COMPLETE", "EndTurn checkpoints record intent completion only after accepted resolution", failures)
			if uninterrupted_end_turn.accepted and end_turn_save.get("accepted", false):
				assert_true(first.controller.domain.checkpoint() == resumed.controller.domain.checkpoint(), "future Enemy Intent outputs match after disk Resume", failures)
				assert_true(first.controller.domain.rng_snapshot() == resumed.controller.domain.rng_snapshot(), "future RNG state matches after intent resolution", failures)
			var replay_report = resumed.controller.domain.verify_replay()
			assert_true(replay_report.status == "MATCH", "accepted commands after Resume replay from the restored checkpoint", failures)
	first.free()
	resumed.free()
	_clear_test_file(suspend_path)
	_clear_test_file(profile_path)
	for suffix in [".tmp", ".bak", ".rejected"]:
		_clear_test_file(suspend_path + suffix)

func test_rejected_suspend_save_is_preserved_for_explicit_recovery(failures: Array[String]) -> void:
	var suspend_path := "user://run_scene_rejected_suspend_%d.json" % Time.get_ticks_usec()
	var profile_path := "user://run_scene_rejected_suspend_profile_%d.json" % Time.get_ticks_usec()
	_clear_test_file(suspend_path)
	_clear_test_file(profile_path)
	var source_bytes := JSON.stringify(Phase2V1SuspendSnapshotFixtureScript.suspend_snapshot())
	var source_file := FileAccess.open(suspend_path, FileAccess.WRITE)
	assert_true(source_file != null, "the unsupported Suspend Save fixture is written to a real file", failures)
	if source_file == null:
		return
	source_file.store_string(source_bytes)
	source_file.close()
	var scene = _new_isolated_run_scene(suspend_path, profile_path)
	scene._ready()
	assert_true(scene.controller == null, "the scene does not silently replace an unsupported Suspend Save with a new Run", failures)
	assert_true(FileAccess.get_file_as_string(suspend_path) == source_bytes, "loading an unsupported save leaves the original source bytes unchanged", failures)
	var preserved_path := ProjectSettings.globalize_path(suspend_path) + ".rejected"
	assert_true(FileAccess.file_exists(preserved_path), "the unsupported save has a recoverable preserved copy", failures)
	if FileAccess.file_exists(preserved_path):
		assert_true(FileAccess.get_file_as_string(preserved_path) == source_bytes, "the preserved rejected copy exactly matches the source", failures)
	var status = scene.find_child("SuspendStatus", true, false)
	assert_true(status is Label and str(status.text).contains("content version"), "the player receives an actionable unsupported-content explanation", failures)
	var new_run_button = scene.find_child("NewRunFromSuspendButton", true, false)
	assert_true(new_run_button is Button, "the player can explicitly choose a new Run after preservation", failures)
	if new_run_button is Button:
		new_run_button.emit_signal("pressed")
	assert_true(scene.controller != null, "the explicit recovery choice starts a fresh Run", failures)
	assert_true(not FileAccess.file_exists(suspend_path), "the old active slot is cleared only after the explicit New Run choice", failures)
	assert_true(FileAccess.file_exists(preserved_path) and FileAccess.get_file_as_string(preserved_path) == source_bytes, "starting over keeps the rejected source available for recovery", failures)
	scene.free()
	_clear_test_file(suspend_path)
	_clear_test_file(profile_path)
	_clear_test_file(preserved_path)
	_clear_test_file(ProjectSettings.globalize_path(suspend_path) + ".rejected.1")

func test_interrupted_suspend_sources_are_not_rolled_back(failures: Array[String]) -> void:
	var suspend_path := "user://run_scene_interrupted_suspend_%d.json" % Time.get_ticks_usec()
	var profile_path := "user://run_scene_interrupted_profile_%d.json" % Time.get_ticks_usec()
	var main_bytes := JSON.stringify(Phase2V1SuspendSnapshotFixtureScript.suspend_snapshot())
	var temporary_bytes := "{ incomplete newer suspend bytes"
	var backup_bytes := "older recovery source"
	var main_file := FileAccess.open(suspend_path, FileAccess.WRITE)
	var temp_file := FileAccess.open(suspend_path + ".tmp", FileAccess.WRITE)
	var backup_file := FileAccess.open(suspend_path + ".bak", FileAccess.WRITE)
	assert_true(main_file != null and temp_file != null and backup_file != null, "all interrupted save sources can be written to isolated files", failures)
	if main_file == null or temp_file == null or backup_file == null:
		return
	main_file.store_string(main_bytes)
	main_file.close()
	temp_file.store_string(temporary_bytes)
	temp_file.close()
	backup_file.store_string(backup_bytes)
	backup_file.close()
	var scene = _new_isolated_run_scene(suspend_path, profile_path)
	scene._ready()
	assert_true(scene.controller == null, "MAIN plus TEMP fails closed instead of silently loading the older primary", failures)
	assert_true(FileAccess.get_file_as_string(suspend_path) == main_bytes, "interrupted recovery preserves the primary bytes", failures)
	assert_true(FileAccess.get_file_as_string(suspend_path + ".tmp") == temporary_bytes, "interrupted recovery preserves the temp bytes for diagnosis", failures)
	assert_true(FileAccess.get_file_as_string(suspend_path + ".bak") == backup_bytes, "interrupted recovery preserves the backup bytes", failures)
	var rejected_main := ProjectSettings.globalize_path(suspend_path) + ".rejected"
	assert_true(FileAccess.file_exists(rejected_main), "all interrupted sources receive a byte-for-byte preserved copy", failures)
	assert_true(FileAccess.file_exists(rejected_main + ".1") and FileAccess.file_exists(rejected_main + ".2"), "temp and backup receive separate preserved copies", failures)
	var status = scene.find_child("SuspendStatus", true, false)
	assert_true(status is Label and str(status.text).contains("No older save was loaded"), "interrupted recovery explains that no rollback was loaded", failures)
	var new_run_button = scene.find_child("NewRunFromSuspendButton", true, false)
	if new_run_button is Button:
		new_run_button.emit_signal("pressed")
	assert_true(scene.controller != null, "explicit New Run recovers from an interrupted slot", failures)
	assert_true(not FileAccess.file_exists(suspend_path) and not FileAccess.file_exists(suspend_path + ".tmp") and not FileAccess.file_exists(suspend_path + ".bak"), "only the explicit New Run action retires interrupted sources", failures)
	assert_true(FileAccess.get_file_as_string(rejected_main) == main_bytes and FileAccess.get_file_as_string(rejected_main + ".1") == temporary_bytes and FileAccess.get_file_as_string(rejected_main + ".2") == backup_bytes, "explicit recovery keeps every original source copied byte for byte", failures)
	scene.free()
	for path in [suspend_path, suspend_path + ".tmp", suspend_path + ".bak", profile_path, rejected_main, rejected_main + ".1", rejected_main + ".2"]:
		_clear_test_file(path)

func test_suspend_writer_preserves_unresolved_sidecars(failures: Array[String]) -> void:
	var path := "user://run_scene_writer_recovery_%d.json" % Time.get_ticks_usec()
	var store = SuspendSaveStoreScript.new(path)
	var snapshot = SuspendSnapshotScript.new("content.test.v1", "run.writer.test", 29, {}, {}, {})
	var initial_write: Dictionary = store.write_snapshot(snapshot)
	assert_true(initial_write.get("accepted", false), "the injectable single-slot writer commits an initial snapshot", failures)
	var temporary_contents := "possibly newer accepted snapshot"
	var backup_contents := "prior source retained for recovery"
	var temporary_file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	var backup_file := FileAccess.open(path + ".bak", FileAccess.WRITE)
	if temporary_file != null:
		temporary_file.store_string(temporary_contents)
		temporary_file.close()
	if backup_file != null:
		backup_file.store_string(backup_contents)
		backup_file.close()
	var prior_main := FileAccess.get_file_as_string(path)
	var retry_write: Dictionary = store.write_snapshot(snapshot)
	assert_true(not retry_write.get("accepted", false) and retry_write.get("code", "") == "SUSPEND_RECOVERY_REQUIRED", "writer refuses to replace a slot with unresolved commit sidecars", failures)
	assert_true(FileAccess.get_file_as_string(path) == prior_main, "writer keeps the current main source unchanged on recovery-required", failures)
	assert_true(FileAccess.get_file_as_string(path + ".tmp") == temporary_contents and FileAccess.get_file_as_string(path + ".bak") == backup_contents, "writer preserves temp and backup sources instead of discarding a prior checkpoint", failures)
	for candidate in [path, path + ".tmp", path + ".bak"]:
		_clear_test_file(candidate)

func test_suspend_write_failure_is_visible(failures: Array[String]) -> void:
	var suspend_path := "user://run_scene_suspend_directory_%d" % Time.get_ticks_usec()
	var profile_path := "user://run_scene_suspend_failure_profile_%d.json" % Time.get_ticks_usec()
	var absolute_suspend_path := ProjectSettings.globalize_path(suspend_path)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_suspend_path)
	assert_true(mkdir_error == OK or DirAccess.dir_exists_absolute(absolute_suspend_path), "the fixture blocks the suspend target with a directory", failures)
	var scene = _new_isolated_run_scene(suspend_path, profile_path)
	scene._ready()
	if scene.controller != null:
		scene._on_action_pressed("character:base.character.sequence")
		var accepted_contract = scene._on_action_pressed("contract:base.contract.pressure")
		assert_true(accepted_contract.accepted, "the Run proceeds after an accepted boundary whose disk write is blocked", failures)
		assert_true(str(scene.controller.snapshot().get("feedback", "")).contains("Suspend Save was not written"), "the player sees that the action succeeded but persistence failed", failures)
		assert_true(DirAccess.dir_exists_absolute(absolute_suspend_path), "the failed write does not claim that a file replaced the blocking path", failures)
	scene.free()
	DirAccess.remove_absolute(absolute_suspend_path)
	_clear_test_file(profile_path)

func test_terminal_new_run_retires_old_suspend_slot(failures: Array[String]) -> void:
	var suspend_path := "user://run_scene_terminal_suspend_%d.json" % Time.get_ticks_usec()
	var profile_path := "user://run_scene_terminal_profile_%d.json" % Time.get_ticks_usec()
	var scene = _new_isolated_run_scene(suspend_path, profile_path)
	scene._ready()
	if scene.controller == null:
		return
	scene._on_action_pressed("character:base.character.sequence")
	scene._on_action_pressed("contract:base.contract.pressure")
	var old_run_id := str(scene.controller.domain.state.run_id)
	scene.controller.domain.state.phase = RunPhaseScript.RUN_COMPLETE
	var terminal_save: Dictionary = scene.controller.save_coordinator.save(scene.controller.domain, "RUN_COMPLETE")
	assert_true(terminal_save.get("accepted", false), "fixture creates a terminal continuation checkpoint", failures)
	if terminal_save.get("accepted", false):
		var written: Dictionary = scene.suspend_store.write_snapshot(terminal_save.snapshot)
		assert_true(written.get("accepted", false), "terminal checkpoint occupies the single save slot before New Run", failures)
	scene._render()
	scene._on_new_run_pressed()
	assert_true(scene.controller != null and scene.controller.domain.state.run_id != old_run_id, "explicit terminal New Run starts a different Run", failures)
	assert_true(not FileAccess.file_exists(suspend_path), "terminal New Run clears the prior Run slot before starting", failures)
	if scene.controller != null:
		var new_run_id := str(scene.controller.domain.state.run_id)
		scene._on_action_pressed("character:base.character.sequence")
		scene._on_action_pressed("contract:base.contract.pressure")
		var new_save: Dictionary = SaveMapperScript.load_into_domain(FileAccess.get_file_as_string(suspend_path), scene.controller.domain.content_registry)
		assert_true(new_save.get("accepted", false) and new_save.domain.state.run_id == new_run_id, "the next accepted checkpoint writes the new Run instead of being blocked by the terminal slot", failures)
	scene.free()
	for path in [suspend_path, suspend_path + ".tmp", suspend_path + ".bak", profile_path]:
		_clear_test_file(path)

func test_player_can_discard_a_hand_tile(failures: Array[String]) -> void:
	var suspend_path := "user://run_scene_discard_suspend_%d.json" % Time.get_ticks_usec()
	var profile_path := "user://run_scene_discard_profile_%d.json" % Time.get_ticks_usec()
	var scene = _new_isolated_run_scene(suspend_path, profile_path)
	scene._ready()
	if scene.controller == null:
		scene.free()
		return
	scene._on_action_pressed("character:base.character.sequence")
	scene._on_action_pressed("contract:base.contract.pressure")
	var map_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "MAP_NODE")
	if not map_actions.is_empty():
		scene._on_action_pressed(str(map_actions[0].get("id", "")))
	var draw_result = scene._on_action_pressed("battle.draw")
	assert_true(draw_result != null and draw_result.accepted, "the Discard fixture reaches a drawn Hand tile", failures)
	var discard_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "DISCARD")
	var hand_size: int = scene.controller.domain.current_battle.zones.size(TileZoneScript.HAND)
	assert_true(discard_actions.size() == hand_size and not discard_actions.is_empty(), "the battle action surface exposes one normal Discard option per Hand tile", failures)
	if not discard_actions.is_empty():
		var discard_action: Dictionary = discard_actions[0]
		var instance_id := str(discard_action.get("target_id", ""))
		var discard_result = scene._on_action_pressed(str(discard_action.get("id", "")))
		assert_true(discard_result.accepted, "the player can submit the Discard action through RunScene", failures)
		assert_true(discard_result.events.any(func(event): return event.event_type == DomainEventScript.TILE_DISCARDED), "accepted Discard returns a factual TileDiscarded event", failures)
		assert_true(scene.controller.domain.current_battle.zones.zone_of(instance_id) == TileZoneScript.DISCARD, "accepted Discard moves the selected TileInstance from Hand to Discard", failures)
		var loaded: Dictionary = SaveMapperScript.load_into_domain(FileAccess.get_file_as_string(suspend_path), scene.controller.domain.content_registry)
		assert_true(loaded.get("accepted", false), "the accepted Discard writes a reloadable Suspend Save (%s)" % str(loaded), failures)
		if loaded.get("accepted", false):
			assert_true(loaded.snapshot.checkpoint_metadata.get("stable_boundary", "") == "BATTLE_ACTION", "Discard persistence names the completed battle action boundary", failures)
		assert_true(scene.controller.domain.verify_replay().status == "MATCH", "accepted Discard remains in deterministic replay", failures)
	scene.free()
	for path in [suspend_path, suspend_path + ".tmp", suspend_path + ".bak", profile_path]:
		_clear_test_file(path)

func test_reserve_swap_is_atomic_and_limited_per_draw(failures: Array[String]) -> void:
	var suspend_path := "user://run_scene_swap_suspend_%d.json" % Time.get_ticks_usec()
	var profile_path := "user://run_scene_swap_profile_%d.json" % Time.get_ticks_usec()
	var scene = _new_isolated_run_scene(suspend_path, profile_path)
	scene._ready()
	if scene.controller == null:
		scene.free()
		return
	scene._on_action_pressed("character:base.character.sequence")
	scene._on_action_pressed("contract:base.contract.pressure")
	var map_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "MAP_NODE")
	if not map_actions.is_empty():
		scene._on_action_pressed(str(map_actions[0].get("id", "")))
	var first_draw = scene._on_action_pressed("battle.draw")
	assert_true(first_draw != null and first_draw.accepted, "the Reserve fixture opens a normal Draw Action", failures)
	var store_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "RESERVE")
	assert_true(not store_actions.is_empty(), "the Hand exposes Store options after Draw", failures)
	if store_actions.is_empty():
		scene.free()
		return
	var stored_id := str(store_actions[0].get("target_id", ""))
	var stored_result = scene._on_action_pressed(str(store_actions[0].get("id", "")))
	assert_true(stored_result.accepted, "Store moves one selected Hand tile into Reserve", failures)
	assert_true(scene.controller.domain.current_battle.zones.zone_of(stored_id) == TileZoneScript.RESERVE, "the stored TileInstance enters Reserve", failures)
	var remaining_reserve_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") in ["RESERVE", "DISCARD", "RESERVE_SWAP"])
	assert_true(remaining_reserve_actions.is_empty(), "Store consumes the single Hand/Reserve manipulation for this Draw Action", failures)
	var before_rejected_store: Dictionary = scene.controller.domain.checkpoint()
	var rng_before_rejected_store: Dictionary = scene.controller.domain.rng_snapshot()
	var rejected_store = scene.controller.domain.execute(StoreTileCommandScript.new("swap.budget.store", stored_id))
	assert_true(not rejected_store.accepted, "a second tile manipulation in the same Draw Action is rejected", failures)
	assert_true(scene.controller.domain.checkpoint() == before_rejected_store and scene.controller.domain.rng_snapshot() == rng_before_rejected_store, "the rejected second manipulation preserves RunState and every RNG stream", failures)
	var second_draw = scene._on_action_pressed("battle.draw")
	assert_true(second_draw.accepted, "the next accepted normal Draw opens a new manipulation allowance", failures)
	var swap_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "RESERVE_SWAP")
	var expected_swap_count: int = int(scene.controller.domain.current_battle.zones.size(TileZoneScript.HAND)) * int(scene.controller.domain.current_battle.zones.size(TileZoneScript.RESERVE))
	assert_true(swap_actions.size() == expected_swap_count and not swap_actions.is_empty(), "the action surface exposes every current Hand-to-Reserve pair after the next Draw", failures)
	if not swap_actions.is_empty():
		var swap_action: Dictionary = swap_actions[0]
		var hand_id := str(swap_action.get("hand_instance_id", ""))
		var reserve_id := str(swap_action.get("reserve_instance_id", ""))
		var swap_result = scene._on_action_pressed(str(swap_action.get("id", "")))
		assert_true(swap_result.accepted, "the selected Hand and Reserve tiles swap in one accepted command", failures)
		assert_true(swap_result.events.any(func(event): return event.event_type == DomainEventScript.RESERVE_SWAPPED), "atomic Swap emits the factual ReserveSwapped event", failures)
		assert_true(scene.controller.domain.current_battle.zones.zone_of(hand_id) == TileZoneScript.RESERVE and scene.controller.domain.current_battle.zones.zone_of(reserve_id) == TileZoneScript.HAND, "both TileInstances exchange zones atomically", failures)
		var before_stale_swap: Dictionary = scene.controller.domain.checkpoint()
		var rng_before_stale_swap: Dictionary = scene.controller.domain.rng_snapshot()
		var rejected_swap = scene.controller.domain.execute(SwapReserveTileCommandScript.new("swap.stale", hand_id, reserve_id))
		assert_true(not rejected_swap.accepted, "stale zone IDs are rejected after the atomic Swap", failures)
		assert_true(scene.controller.domain.checkpoint() == before_stale_swap and scene.controller.domain.rng_snapshot() == rng_before_stale_swap, "a rejected stale Swap preserves RunState and all RNG streams", failures)
		var loaded: Dictionary = SaveMapperScript.load_into_domain(FileAccess.get_file_as_string(suspend_path), scene.controller.domain.content_registry)
		assert_true(loaded.get("accepted", false), "accepted Store and Swap snapshots reload", failures)
		if loaded.get("accepted", false):
			assert_true(loaded.domain.checkpoint() == scene.controller.domain.checkpoint(), "Resume restores the exact post-Swap battle checkpoint", failures)
			assert_true(loaded.snapshot.checkpoint_metadata.get("stable_boundary", "") == "BATTLE_ACTION", "Swap persistence names the completed battle action boundary", failures)
	assert_true(scene.controller.domain.verify_replay().status == "MATCH", "accepted Store and Swap commands remain in deterministic replay", failures)
	scene.free()
	for path in [suspend_path, suspend_path + ".tmp", suspend_path + ".bak", profile_path]:
		_clear_test_file(path)

func test_owned_active_technique_is_available(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var suspend_path := "user://run_scene_technique_suspend_%s.json" % suffix
	var profile_path := "user://run_scene_technique_profile_%s.json" % suffix
	var scene = _new_isolated_run_scene(suspend_path, profile_path)
	scene._ready()
	if scene.controller == null:
		scene.free()
		return
	scene._on_action_pressed("character:base.character.sequence")
	scene._on_action_pressed("contract:base.contract.pressure")
	var owned_ids := [
		"base.technique.stability_breath",
		"base.technique.reserve_exchange",
		"base.technique.reaction_guard",
		"base.technique.settlement_focus",
		"alpha.technique.reserve_survey",
	]
	for technique_id in owned_ids:
		scene.controller.domain.state.build_ownership.run_technique_ids.append(technique_id)
	var map_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "MAP_NODE")
	if not map_actions.is_empty():
		scene._on_action_pressed(str(map_actions[0].get("id", "")))
	var battle = scene.controller.domain.current_battle
	assert_true(battle != null, "the owned Technique fixture starts a real BattleDomain", failures)
	if battle != null:
		battle.combat_state.tp = 0
		var unaffordable_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "TECHNIQUE")
		assert_true(unaffordable_actions.size() == 1 and unaffordable_actions[0].get("target_id", "") == "base.technique.core.sequence_line", "the zero-cost Core remains available while TP-gated Techniques are hidden", failures)
		var before_unaffordable: Dictionary = scene.controller.domain.checkpoint()
		var rng_before_unaffordable: Dictionary = scene.controller.domain.rng_snapshot()
		var unaffordable = scene.controller.domain.execute(UseTechniqueCommandScript.new("technique.unaffordable", "base.technique.stability_breath"))
		assert_true(not unaffordable.accepted and unaffordable.validation.code == "INSUFFICIENT_TP", "the authoritative command rejects an Active Technique when TP is insufficient", failures)
		assert_true(scene.controller.domain.checkpoint() == before_unaffordable and scene.controller.domain.rng_snapshot() == rng_before_unaffordable, "an unaffordable Technique preserves RunState and every RNG stream", failures)
		var before_unowned: Dictionary = scene.controller.domain.checkpoint()
		var rng_before_unowned: Dictionary = scene.controller.domain.rng_snapshot()
		var unowned = scene.controller.domain.execute(UseTechniqueCommandScript.new("technique.unowned", "base.technique.draw_surge"))
		assert_true(not unowned.accepted and unowned.validation.code == "TECHNIQUE_NOT_OWNED", "the authoritative command rejects a registered but unowned Technique", failures)
		assert_true(scene.controller.domain.checkpoint() == before_unowned and scene.controller.domain.rng_snapshot() == rng_before_unowned, "an unowned Technique preserves RunState and all RNG streams", failures)
		battle.combat_state.tp = 3
		var hidden_settlement_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("target_id", "") == "base.technique.settlement_focus")
		assert_true(hidden_settlement_actions.is_empty(), "Settlement Techniques stay hidden until a Settlement Window is open", failures)
		# Build a real open Settlement Window around existing owned TileInstances so
		# timing and capacity behavior also survive checkpoint reconstruction.
		var settlement_definitions := ["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3"]
		for definition_id in settlement_definitions:
			var selected_tile = null
			for zone in TileZoneScript.all():
				for tile in battle.zones.contents(zone):
					if tile.definition_id == definition_id:
						selected_tile = tile
						break
				if selected_tile != null:
					break
			if selected_tile != null and battle.zones.zone_of(selected_tile.instance_id) != TileZoneScript.HAND:
				battle.zones.transfer(selected_tile.instance_id, battle.zones.zone_of(selected_tile.instance_id), TileZoneScript.HAND)
		assert_true(battle.settlement_window.open(), "the fixture opens its Settlement Window from a legal Hand Sequence", failures)
		assert_true(battle.settlement_window.settlement_capacity().consume(), "the fixture marks one Settlement use as spent before the Technique", failures)
		var technique_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "TECHNIQUE")
		assert_true(technique_actions.size() == 4, "the action surface offers the owned Active, Core, and open-window Settlement Techniques", failures)
		assert_true(not technique_actions.any(func(candidate): return candidate.get("target_id", "") in ["base.technique.reaction_guard", "alpha.technique.reserve_survey"]), "Reaction and Passive timing are not exposed as ordinary battle actions", failures)
		if technique_actions.size() == 4:
			var action: Dictionary = technique_actions.filter(func(candidate): return candidate.get("target_id", "") == "base.technique.stability_breath")[0]
			assert_true(action.get("id", "") == "battle.technique:base.technique.stability_breath", "the Technique action ID is stable and derived from its content ID", failures)
			assert_true(action.get("details", {}).get("technique_kind", "") == "ACTIVE" and int(action.get("details", {}).get("tp_cost", -1)) == 1, "the action details show its registered kind and TP cost", failures)
			assert_true(not str(scene._action_label(action)).is_empty(), "the owned Technique has a readable player-facing label", failures)
			# Reconstruct from a stable checkpoint so replay starts with the injected test ownership.
			scene.controller.domain.state.current_battle_snapshot = RunBattleSnapshotScript.new(battle.checkpoint())
			var start_save: Dictionary = scene.controller.save_coordinator.save(scene.controller.domain, "BATTLE_START")
			assert_true(start_save.get("accepted", false), "the in-test owned-Technique fixture can be rebased at a stable Battle checkpoint", failures)
			if start_save.get("accepted", false):
				var written_start: Dictionary = scene.suspend_store.write_snapshot(start_save.snapshot)
				assert_true(written_start.get("accepted", false), "the stable test checkpoint can be written before the Resume comparison", failures)
				var loaded_start: Dictionary = SaveMapperScript.load_into_domain(FileAccess.get_file_as_string(suspend_path), scene.controller.domain.content_registry)
				assert_true(loaded_start.get("accepted", false), "the owned-Technique checkpoint reconstructs through SaveMapper", failures)
				if loaded_start.get("accepted", false):
					scene.controller.domain = loaded_start.domain
					scene.controller._refresh([])
					assert_true(scene.controller.domain.verify_replay().status == "MATCH", "the reconstructed fixture starts a fresh accepted-only replay segment", failures)
					battle = scene.controller.domain.current_battle
					var before_stability: int = battle.combat_state.stability
					var technique_result = scene._on_action_pressed("battle.technique:base.technique.stability_breath")
					assert_true(technique_result.accepted, "the player can activate the owned Active Technique", failures)
					assert_true(battle.combat_state.tp == 2 and battle.combat_state.stability == before_stability + 1, "Technique activation spends its exact TP cost and resolves its typed Stability effect", failures)
					assert_true(technique_result.events.any(func(event): return event.event_type == DomainEventScript.TECHNIQUE_USED), "accepted activation emits a factual TechniqueUsed event", failures)
					assert_true(technique_result.events.any(func(event): return event.event_type == DomainEventScript.TP_CHANGED), "accepted activation reports the TP cost", failures)
					assert_true(technique_result.events.any(func(event): return event.event_type == DomainEventScript.STABILITY_CHANGED), "accepted activation exposes the typed effect event", failures)
					var core_result = scene._on_action_pressed("battle.technique:base.technique.core.sequence_line")
					assert_true(core_result.accepted, "the owned Core Technique can be activated", failures)
					assert_true(battle.combat_state.tp == 3 and battle.combat_state.core_technique_used_this_turn, "the zero-cost Core resolves its typed effect and records the bounded use", failures)
					assert_true(not scene.controller.action_descriptors().any(func(candidate): return candidate.get("target_id", "") == "base.technique.core.sequence_line"), "the Core Technique disappears after its one use this turn", failures)
					var before_repeat_core: Dictionary = scene.controller.domain.checkpoint()
					var rng_before_repeat_core: Dictionary = scene.controller.domain.rng_snapshot()
					var repeated_core = scene.controller.domain.execute(UseTechniqueCommandScript.new("technique.core.repeat", "base.technique.core.sequence_line"))
					assert_true(not repeated_core.accepted and repeated_core.validation.code == "CORE_TECHNIQUE_ALREADY_USED", "the authoritative command rejects a repeated Core Technique", failures)
					assert_true(scene.controller.domain.checkpoint() == before_repeat_core and scene.controller.domain.rng_snapshot() == rng_before_repeat_core, "a repeated Core Technique preserves RunState and all RNG streams", failures)
					var reserve_result = scene._on_action_pressed("battle.technique:base.technique.reserve_exchange")
					assert_true(reserve_result.accepted, "the owned Reserve capacity Technique resolves", failures)
					assert_true(battle.combat_state.reserve_capacity == 4 and battle.reserve_service.reserve_capacity == 4 and battle.zones.reserve_capacity == 4, "Reserve capacity effects immediately synchronize CombatState, ReserveService, and TileZoneContainer", failures)
					assert_true(reserve_result.events.any(func(event): return event.event_type == DomainEventScript.CAPACITY_CHANGED and event.data.get("capacity", "") == "reserve_capacity"), "Reserve capacity activation emits the factual capacity event", failures)
					var settlement_result = scene._on_action_pressed("battle.technique:base.technique.settlement_focus")
					assert_true(settlement_result.accepted, "the owned Settlement Technique resolves while its Window is open", failures)
					assert_true(battle.combat_state.settlement_capacity == 3 and battle.settlement_window.settlement_capacity().maximum == 3 and battle.settlement_window.settlement_capacity().remaining == 2, "Settlement capacity synchronizes immediately while preserving the one spent use", failures)
					assert_true(settlement_result.events.any(func(event): return event.event_type == DomainEventScript.CAPACITY_CHANGED and event.data.get("capacity", "") == "settlement_capacity"), "Settlement capacity activation emits the factual capacity event", failures)
					var technique_save: Dictionary = SaveMapperScript.load_into_domain(FileAccess.get_file_as_string(suspend_path), scene.controller.domain.content_registry)
					assert_true(technique_save.get("accepted", false), "accepted Technique activation writes a reloadable Suspend Save", failures)
					if technique_save.get("accepted", false):
						assert_true(technique_save.snapshot.checkpoint_metadata.get("stable_boundary", "") == "BATTLE_ACTION", "Technique persistence names the completed battle action boundary", failures)
						assert_true(technique_save.domain.checkpoint() == scene.controller.domain.checkpoint(), "the Technique save restores its exact battle checkpoint", failures)
						assert_true(technique_save.domain.rng_snapshot() == scene.controller.domain.rng_snapshot(), "the Technique save restores exact RNG state", failures)
					assert_true(scene.controller.domain.verify_replay().status == "MATCH", "the accepted Technique is present in deterministic replay", failures)
					var resumed = _new_isolated_run_scene(suspend_path, profile_path)
					resumed._ready()
					var resume_button = resumed.find_child("ResumeRunButton", true, false)
					if resume_button is Button:
						resume_button.emit_signal("pressed")
					assert_true(resumed.controller != null and resumed.controller.domain.checkpoint() == scene.controller.domain.checkpoint(), "player-facing Resume restores the post-Technique state exactly", failures)
					if resumed.controller != null:
						assert_true(resumed.controller.action_descriptors() == scene.controller.action_descriptors(), "Resume restores the same legal action choices", failures)
						var first_end_turn = scene.controller.confirm("battle.end_turn")
						var resumed_end_turn = resumed.controller.confirm("battle.end_turn")
						assert_true(first_end_turn.accepted and resumed_end_turn.accepted, "the same next End Turn is accepted on both paths", failures)
						assert_true(not scene.controller.domain.current_battle.combat_state.core_technique_used_this_turn and scene.controller.action_descriptors().any(func(candidate): return candidate.get("target_id", "") == "base.technique.core.sequence_line"), "an accepted End Turn resets the serialized once-per-turn Core allowance", failures)
						var first_draw = scene.controller.confirm("battle.draw")
						var resumed_draw = resumed.controller.confirm("battle.draw")
						assert_true(first_draw.accepted and resumed_draw.accepted, "the same future Draw is accepted after Resume", failures)
						if first_draw.accepted and resumed_draw.accepted:
							assert_true(scene.controller.domain.current_battle.checkpoint() == resumed.controller.domain.current_battle.checkpoint(), "future battle output remains exact after Resume", failures)
							assert_true(scene.controller.domain.rng_snapshot() == resumed.controller.domain.rng_snapshot(), "future RNG output remains exact after Resume", failures)
							assert_true(resumed.controller.domain.verify_replay().status == "MATCH", "accepted post-Resume commands replay from the restored checkpoint", failures)
						resumed.free()
		scene.free()
	for path in [suspend_path, suspend_path + ".tmp", suspend_path + ".bak", profile_path]:
		_clear_test_file(path)

func test_battle_action_descriptors_only_offer_legal_manipulations(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var suspend_path := "user://run_scene_full_reserve_suspend_%s.json" % suffix
	var profile_path := "user://run_scene_full_reserve_profile_%s.json" % suffix
	var scene = _new_isolated_run_scene(suspend_path, profile_path)
	scene._ready()
	if scene.controller != null:
		scene._on_action_pressed("character:base.character.sequence")
		scene._on_action_pressed("contract:base.contract.pressure")
		var map_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "MAP_NODE")
		if not map_actions.is_empty():
			scene._on_action_pressed(str(map_actions[0].get("id", "")))
		var battle = scene.controller.domain.current_battle
		if battle != null:
			scene._on_action_pressed("battle.draw")
			var reserve_tiles: Array = []
			for zone in TileZoneScript.all():
				for tile in battle.zones.contents(zone):
					if tile.instance_id != "" and reserve_tiles.size() < battle.combat_state.reserve_capacity:
						if zone != TileZoneScript.RESERVE:
							reserve_tiles.append(tile)
			for tile in reserve_tiles:
				var source_zone: String = battle.zones.zone_of(tile.instance_id)
				if source_zone != TileZoneScript.RESERVE:
					battle.zones.transfer(tile.instance_id, source_zone, TileZoneScript.RESERVE)
			var actions: Array = scene.controller.action_descriptors()
			var hand_tiles: Array = battle.zones.contents(TileZoneScript.HAND)
			var hand_ids: Array[String] = []
			for tile in hand_tiles:
				hand_ids.append(str(tile.instance_id))
			assert_true(battle.zones.size(TileZoneScript.RESERVE) == battle.combat_state.reserve_capacity, "the action fixture fills Reserve to its current capacity", failures)
			assert_true(not actions.any(func(action): return action.get("kind", "") == "RESERVE"), "Store is not offered when Reserve is full", failures)
			assert_true(actions.filter(func(action): return action.get("kind", "") == "DISCARD").size() == hand_tiles.size(), "Discard remains available once for each current Hand TileInstance", failures)
			var swaps: Array = actions.filter(func(action): return action.get("kind", "") == "RESERVE_SWAP")
			assert_true(swaps.size() == hand_tiles.size() * battle.zones.size(TileZoneScript.RESERVE), "every displayed Swap corresponds to one current Hand and Reserve pair", failures)
			for action in actions:
				match str(action.get("kind", "")):
					"DISCARD":
						assert_true(battle.validate_discard_tile(str(action.get("target_id", ""))).is_valid(), "every displayed Discard passes authoritative validation", failures)
					"RESERVE_SWAP":
						assert_true(battle.validate_swap_reserve_tiles(str(action.get("hand_instance_id", "")), str(action.get("reserve_instance_id", ""))).is_valid(), "every displayed Swap passes authoritative validation", failures)
	scene.free()
	for path in [suspend_path, suspend_path + ".tmp", suspend_path + ".bak", profile_path]:
		_clear_test_file(path)

func test_late_technique_effect_rejection_rolls_back(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var suspend_path := "user://run_scene_late_effect_suspend_%s.json" % suffix
	var profile_path := "user://run_scene_late_effect_profile_%s.json" % suffix
	var scene = _new_isolated_run_scene(suspend_path, profile_path)
	scene._ready()
	if scene.controller == null:
		scene.free()
		return
	scene._on_action_pressed("character:base.character.sequence")
	scene._on_action_pressed("contract:base.contract.pressure")
	var map_actions: Array = scene.controller.action_descriptors().filter(func(action): return action.get("kind", "") == "MAP_NODE")
	if not map_actions.is_empty():
		scene._on_action_pressed(str(map_actions[0].get("id", "")))
	var battle = scene.controller.domain.current_battle
	if battle != null:
		var technique_id := "base.technique.test.late_reject"
		var before_stability: int = battle.combat_state.stability
		var second_effect := EffectScript.new(
			"test.late_reject.guarded_tp",
			EffectTriggerScript.new(EffectTriggerScript.MANUAL),
			[StateEffectConditionScript.new("stability", StateEffectConditionScript.EQUAL, before_stability)],
			[],
			[GainTPOperationScript.new(1)],
		)
		var late_definition := TechniqueDefinitionScript.new(
			technique_id,
			TechniqueDefinitionScript.ACTIVE,
			1,
			[Phase2CatalogScript.typed_effect("test.late_reject.stability", "GainStability", 1), second_effect],
		)
		var registration = scene.controller.domain.content_registry.register(late_definition)
		assert_true(registration.is_valid(), "the typed late-rejection Technique fixture registers", failures)
		scene.controller.domain.state.build_ownership.run_technique_ids.append(technique_id)
		battle.context.build_state.run_technique_ids.append(technique_id)
		battle.combat_state.tp = 2
		scene.controller.domain.state.current_battle_snapshot = RunBattleSnapshotScript.new(battle.checkpoint())
		var baseline_save: Dictionary = scene.controller.save_coordinator.save(scene.controller.domain, "BATTLE_START")
		if baseline_save.get("accepted", false):
			scene.suspend_store.write_snapshot(baseline_save.snapshot)
		var before: Dictionary = scene.controller.domain.checkpoint()
		var rng_before: Dictionary = scene.controller.domain.rng_snapshot()
		var result = scene.controller.domain.execute(UseTechniqueCommandScript.new("technique.late.reject", technique_id))
		assert_true(not result.accepted and result.status == "REJECTED", "a late rejected typed effect rejects the Technique command even when the queue resolves", failures)
		assert_true(result.validation.code == "TECHNIQUE_EFFECT_REJECTED", "the command explains that an individual Technique effect rejected", failures)
		assert_true(scene.controller.domain.checkpoint() == before and scene.controller.domain.rng_snapshot() == rng_before, "late effect rejection rolls back TP, earlier effects, state, and RNG", failures)
		assert_true(scene.controller.domain.verify_replay().status == "MATCH", "a rejected late-effect Technique is excluded from accepted-only replay", failures)
	scene.free()
	for path in [suspend_path, suspend_path + ".tmp", suspend_path + ".bak", profile_path]:
		_clear_test_file(path)

func _new_isolated_run_scene(suspend_path: String, profile_path: String):
	var scene = RunScene.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(profile_path))
	return scene

func _clear_test_file(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)

func test_pre_mvp_scene_has_no_device_capture_ui(failures: Array[String]) -> void:
	var suspend_path := "user://run_scene_device_scope_suspend_%d.json" % Time.get_ticks_usec()
	var scene = RunScene.instantiate()
	scene.suspend_file_path = suspend_path
	scene.meta_progress_coordinator = MetaProgressCoordinatorScript.new(
		MetaProgressStoreScript.new("user://run_scene_device_scope_test.json"),
	)
	scene._ready()
	assert_true(scene.find_child("DeviceEvidenceCapture", true, false) == null, "the pre-MVP Run scene does not create a device evidence capture node", failures)
	assert_true(not scene._profile_status.text.contains("device"), "profile messaging does not imply device checks", failures)
	scene.free()
	_clear_test_file(suspend_path)

func test_invalid_catalogs_block_run_start(failures: Array[String]) -> void:
	var suffix := str(Time.get_ticks_usec())
	var duplicate_registration_scene = RunScene.instantiate()
	duplicate_registration_scene.suspend_file_path = "user://run_scene_invalid_registration_suspend_%s.json" % suffix
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
	_clear_test_file("user://run_scene_invalid_registration_suspend_%s.json" % suffix)

	var missing_reference_scene = RunScene.instantiate()
	missing_reference_scene.suspend_file_path = "user://run_scene_missing_reference_suspend_%s.json" % suffix
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
	_clear_test_file("user://run_scene_missing_reference_suspend_%s.json" % suffix)

func test_rejected_profile_is_explained_and_can_be_reset(failures: Array[String]) -> void:
	var path := "user://run_scene_rejected_profile_%d.json" % Time.get_ticks_usec()
	var suspend_path := "user://run_scene_rejected_profile_suspend_%d.json" % Time.get_ticks_usec()
	var source := "{ unsupported profile bytes"
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "the isolated rejected-profile fixture can be written", failures)
	if file == null:
		return
	file.store_string(source)
	file.close()
	var scene = RunScene.instantiate()
	scene.suspend_file_path = suspend_path
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
	_clear_test_file(suspend_path)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
