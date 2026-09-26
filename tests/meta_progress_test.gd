class_name MetaProgressTest
extends RefCounted

const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const AlphaActTwoCatalogScript = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const MetaProgressCoordinatorScript = preload("res://src/presentation/run/meta_progress_coordinator.gd")
const MetaProgressSnapshotScript = preload("res://src/infrastructure/persistence/meta_progress_snapshot.gd")
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")
const MetaProgressStoreScript = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunPhaseScript = preload("res://src/domain/run/run_phase.gd")
const RunPresentationControllerScript = preload("res://src/presentation/run/run_presentation_controller.gd")
const RunStateScript = preload("res://src/domain/run/run_state.gd")
const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_default_and_all_unlocked_profiles(failures)
	test_only_act_two_normal_ending_unlocks_for_later_runs(failures)
	test_profile_persists_and_migrates_without_overwriting_source(failures)
	test_rejected_profile_is_preserved_and_progression_is_read_only(failures)
	test_authoritative_run_commands_enforce_unlocks(failures)
	return failures

func test_default_and_all_unlocked_profiles(failures: Array[String]) -> void:
	var default_profile = MetaProgressStateScript.new()
	assert_true(default_profile.unlocked_character_ids.size() == 2, "default profile begins with two unlocked Characters", failures)
	assert_true(default_profile.unlocked_contract_ids.size() == 3, "default profile begins with three unlocked Contracts", failures)
	assert_true(not default_profile.is_unlocked("CHARACTER", AlphaScaleCatalogScript.CHARACTER_ID), "the third Character is locked in a new profile", failures)
	assert_true(not default_profile.is_unlocked("CONTRACT", AlphaScaleCatalogScript.CONTRACT_IDS[0]), "the fourth Contract is locked in a new profile", failures)
	assert_true(default_profile.is_unlocked("RELIC", AlphaScaleCatalogScript.RELIC_IDS[0]), "the unlock path does not add meta locks to Act 2 Relics", failures)
	var test_profile = MetaProgressStateScript.all_unlocked_test_profile()
	assert_true(test_profile.unlocked_character_ids.size() == 3 and test_profile.unlocked_contract_ids.size() == 6, "the automated profile exposes the full Character and Contract roster", failures)
	var test_store = MetaProgressStoreScript.new(_temporary_path("test-profile"))
	var rejected := test_store.save_profile(test_profile)
	assert_true(not rejected.accepted and rejected.code == "TEST_PROFILE_CANNOT_BE_PERSISTED", "the all-unlocked test profile cannot overwrite player progression", failures)

func test_only_act_two_normal_ending_unlocks_for_later_runs(failures: Array[String]) -> void:
	var path := _temporary_path("normal-ending")
	var store = MetaProgressStoreScript.new(path)
	var coordinator = MetaProgressCoordinatorScript.new(store)
	var loaded: Dictionary = coordinator.load_profile()
	assert_true(loaded.accepted and loaded.created_default, "a missing profile starts from the default progression", failures)
	var act_one = _run_summary("meta.act-one", 1, 2, "VICTORY", "BOSS_DEFEATED")
	var act_one_result: Dictionary = coordinator.observe_run_state(act_one)
	assert_true(not act_one_result.get("changed", false), "an Act 1 Boss reward does not unlock later-run content", failures)
	var defeat = _run_summary("meta.defeat", 2, 2, "DEFEAT", "BATTLE_DEFEAT")
	var defeat_result: Dictionary = coordinator.observe_run_state(defeat)
	assert_true(not defeat_result.get("changed", false), "an Act 2 defeat does not unlock later-run content", failures)
	var completed_run = _run_summary("meta.normal-ending", 2, 2, "VICTORY", "BOSS_DEFEATED")
	var run_before: Dictionary = completed_run.to_dictionary()
	var completed_result: Dictionary = coordinator.observe_run_state(completed_run)
	assert_true(completed_result.get("changed", false) and completed_result.get("persisted", false), "an Act 2 Normal Ending unlocks the full additional selection roster and persists it", failures)
	assert_true(completed_run.to_dictionary() == run_before, "recording meta progress does not mutate the completed Run", failures)
	assert_true(coordinator.state.unlocked_character_ids.size() == 3 and coordinator.state.unlocked_contract_ids.size() == 6, "the milestone grants Character 3 and Contracts 4–6 together", failures)
	var repeated: Dictionary = coordinator.observe_run_state(completed_run)
	assert_true(not repeated.get("changed", false) and coordinator.state.progress_count() == 1, "observing the same completed Run twice is idempotent", failures)
	var resumed_coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(path))
	var reloaded: Dictionary = resumed_coordinator.load_profile()
	assert_true(reloaded.accepted and resumed_coordinator.state.unlocked_character_ids.size() == 3, "a new coordinator reloads the persisted unlocks", failures)
	var registry = _registry()
	var controller := RunPresentationControllerScript.new(
		RunDomainScript.new_alpha_run("meta.next-run", 5102, registry, "", null, null, resumed_coordinator.state),
		null,
		resumed_coordinator,
	)
	assert_true(_action_count(controller.action_descriptors(), "CHARACTER") == 3, "later Run Character selection presents the unlocked roster", failures)
	controller.confirm(str(controller.action_descriptors().filter(func(action): return action.get("kind") == "CHARACTER")[0].id))
	assert_true(_action_count(controller.action_descriptors(), "CONTRACT") == 6, "later Run Contract selection presents the unlocked roster", failures)
	_remove_temporary(path)

func test_profile_persists_and_migrates_without_overwriting_source(failures: Array[String]) -> void:
	var path := _temporary_path("schema-migration")
	var legacy_data := {
		"schema_version": 1,
		"game_version": "game.phase2.v1",
		"content_version": "legacy.meta.v1",
		"save_kind": MetaProgressSnapshotScript.SAVE_KIND,
		"run_id": "",
		"run_seed": 0,
		"authoritative_state": {"unlocked": [Phase2CatalogScript.CHARACTER_IDS[0], Phase2CatalogScript.CONTRACT_IDS[0]]},
		"rng_state": {},
		"checkpoint_metadata": {"stable_boundary": "META_PROGRESS"},
	}
	var legacy_text := JSON.stringify(legacy_data)
	var legacy_file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(legacy_file != null, "the isolated migration fixture can be written", failures)
	if legacy_file == null:
		return
	legacy_file.store_string(legacy_text)
	legacy_file.close()
	var store = MetaProgressStoreScript.new(path)
	var migrated: Dictionary = store.load_profile()
	assert_true(migrated.accepted and migrated.migrated, "schema-v1 profile migrates to the current meta schema", failures)
	assert_true(migrated.state.unlocked_character_ids.size() == 2 and migrated.state.unlocked_contract_ids.size() == 3, "migration retains the default Phase 2 unlock baseline", failures)
	assert_true(FileAccess.get_file_as_string(path) == legacy_text, "loading a migration candidate preserves the source until a validated save", failures)
	var rewritten: Dictionary = store.save_profile(migrated.state)
	assert_true(rewritten.accepted, "the migrated profile can be written in the current schema", failures)
	var reloaded: Dictionary = MetaProgressStoreScript.new(path).load_profile()
	assert_true(reloaded.accepted and not reloaded.migrated, "the current schema reloads without migration", failures)
	_remove_temporary(path)

func test_rejected_profile_is_preserved_and_progression_is_read_only(failures: Array[String]) -> void:
	var path := _temporary_path("unsupported")
	var source := JSON.stringify({"schema_version": 99, "save_kind": MetaProgressSnapshotScript.SAVE_KIND, "authoritative_state": {"preserve_me": true}})
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "the isolated unsupported-profile fixture can be written", failures)
	if file == null:
		return
	file.store_string(source)
	file.close()
	var coordinator = MetaProgressCoordinatorScript.new(MetaProgressStoreScript.new(path))
	var loaded: Dictionary = coordinator.load_profile()
	assert_true(not loaded.accepted and coordinator.recovery_required, "an unsupported profile requires recovery", failures)
	assert_true(not loaded.get("preserved_path", "").is_empty(), "the rejected source is copied to a recovery file", failures)
	assert_true(FileAccess.get_file_as_string(path) == source, "rejection leaves the original profile byte-for-byte unchanged", failures)
	var completed_run = _run_summary("meta.rejected-profile", 2, 2, "VICTORY", "BOSS_DEFEATED")
	var observed: Dictionary = coordinator.observe_run_state(completed_run)
	assert_true(not observed.get("changed", false) and coordinator.state.progress_count() == 0, "a later victory cannot mutate fallback progression after profile rejection", failures)
	assert_true(FileAccess.get_file_as_string(path) == source, "a completed Run cannot replace the rejected source save", failures)
	var reset: Dictionary = coordinator.reset_profile()
	assert_true(reset.get("accepted", false) and not coordinator.recovery_required, "explicit reset installs a valid starter profile and re-enables progression", failures)
	assert_true(FileAccess.get_file_as_string(str(loaded.get("preserved_path", ""))) == source, "explicit reset retains the rejected source copy", failures)
	_remove_temporary(path)

func test_authoritative_run_commands_enforce_unlocks(failures: Array[String]) -> void:
	var registry = _registry()
	var locked_domain = RunDomainScript.new_alpha_run("meta.locked-direct", 5201, registry)
	var locked_character = locked_domain.execute(ChooseCharacterCommandScript.new("choose.locked.character", AlphaScaleCatalogScript.CHARACTER_ID))
	assert_true(not locked_character.accepted and locked_character.validation.code == "CHARACTER_LOCKED", "a direct Run command cannot select a registered but locked Character", failures)
	var choose_base = locked_domain.execute(ChooseCharacterCommandScript.new("choose.base.character", Phase2CatalogScript.CHARACTER_IDS[0]))
	assert_true(choose_base.accepted, "the default unlock policy permits a base Character", failures)
	assert_true(locked_domain.state.tile_pool.tile_instances.size() == 14, "the authoritative Character command initializes the starting Tile Pool", failures)
	var locked_contract = locked_domain.execute(ChooseContractCommandScript.new("choose.locked.contract", AlphaScaleCatalogScript.CONTRACT_IDS[0]))
	assert_true(not locked_contract.accepted and locked_contract.validation.code == "CONTRACT_LOCKED", "a direct Run command cannot select a registered but locked Contract", failures)
	var all_unlocked = RunDomainScript.new_alpha_run("meta.all-unlocked-direct", 5202, registry, "", null, null, MetaProgressStateScript.all_unlocked_test_profile())
	var selected_character = all_unlocked.execute(ChooseCharacterCommandScript.new("choose.test.character", AlphaScaleCatalogScript.CHARACTER_ID))
	var selected_contract = all_unlocked.execute(ChooseContractCommandScript.new("choose.test.contract", AlphaScaleCatalogScript.CONTRACT_IDS[0]))
	assert_true(selected_character.accepted and selected_contract.accepted, "the explicit all-unlocked test policy permits Scale roster selection", failures)

func _run_summary(run_id: String, act_index: int, act_count: int, outcome: String, reason: String):
	var run_state = RunStateScript.new(run_id, 42, "meta.test")
	run_state.act_index = act_index
	run_state.act_count = act_count
	run_state.phase = RunPhaseScript.RUN_SUMMARY
	run_state.terminal_summary.outcome = outcome
	run_state.terminal_summary.reason = reason
	return run_state

func _registry():
	var registry = ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	AlphaActTwoCatalogScript.register_all(registry)
	AlphaScaleCatalogScript.register_all(registry)
	return registry

func _action_count(actions: Array, kind: String) -> int:
	return actions.filter(func(action): return action.get("kind", "") == kind).size()

func _temporary_path(label: String) -> String:
	return "user://meta-progress-%s-%d.json" % [label, Time.get_ticks_usec()]

func _remove_temporary(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	for suffix in ["", ".tmp", ".bak", ".rejected", ".rejected.1"]:
		var candidate := "%s%s" % [absolute_path, suffix]
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
