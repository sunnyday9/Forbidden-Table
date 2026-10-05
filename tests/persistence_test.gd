class_name PersistenceTest
extends RefCounted

const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const EnemyDefinition = preload("res://src/content/definitions/enemy_definition.gd")
const EnemyIntent = preload("res://src/domain/combat/enemy_intent.gd")
const EncounterDefinition = preload("res://src/content/definitions/encounter_definition.gd")
const IntentGraph = preload("res://src/domain/combat/intent_graph.gd")
const IntentTransition = preload("res://src/domain/combat/intent_transition.gd")
const RelicDefinition = preload("res://src/content/definitions/relic_definition.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const UseWorkshopServiceCommand = preload("res://src/domain/commands/use_workshop_service_command.gd")
const AcknowledgeRunSummaryCommand = preload("res://src/domain/commands/acknowledge_run_summary_command.gd")
const DrawCommand = preload("res://src/domain/commands/draw_command.gd")
const ChooseRewardCommand = preload("res://src/domain/commands/choose_reward_command.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const AlphaActTwoCatalog = preload("res://src/content/catalogs/alpha_act_two_catalog.gd")
const AlphaScaleCatalog = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const SuspendSnapshot = preload("res://src/infrastructure/persistence/suspend_snapshot.gd")
const MetaProgressSnapshot = preload("res://src/infrastructure/persistence/meta_progress_snapshot.gd")
const MetaProgressStore = preload("res://src/infrastructure/persistence/meta_progress_store.gd")
const RunRecord = preload("res://src/infrastructure/persistence/run_record.gd")
const ReplayRecord = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifier = preload("res://src/infrastructure/replay/replay_verifier.gd")
const SnapshotDto = preload("res://src/infrastructure/persistence/snapshot_dto.gd")
const MigrationPipeline = preload("res://src/infrastructure/persistence/migration_pipeline.gd")
const ContentVersionMigration = preload("res://src/infrastructure/persistence/content_version_migration.gd")
const SaveCoordinator = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const SuspendCheckpointPolicy = preload("res://src/domain/run/suspend_checkpoint_policy.gd")
const ActiveEffectInstance = preload("res://src/domain/effects/active_effect_instance.gd")
const DurationSpec = preload("res://src/domain/effects/duration_spec.gd")
const StackPolicy = preload("res://src/domain/effects/stack_policy.gd")
const DomainRngStreams = preload("res://src/infrastructure/rng/domain_rng_streams.gd")
const DeterministicSerializer = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const JsonIntegerCodec = preload("res://src/infrastructure/serialization/json_integer_codec.gd")
const LoadValidator = preload("res://src/infrastructure/persistence/load_validator.gd")
const RunTileInstanceRecord = preload("res://src/domain/run/run_tile_instance_record.gd")
const RunBattleSnapshot = preload("res://src/domain/run/run_battle_snapshot.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const ShopOffer = preload("res://src/domain/run/shop_offer.gd")
const BattleSnapshot = preload("res://src/infrastructure/persistence/battle_snapshot.gd")
const Phase2V1SuspendSnapshotFixture = preload("res://tests/fixtures/phase2_v1_suspend_snapshot.gd")
const Phase2V1BossRewardSuspendSnapshotFixture = preload("res://tests/fixtures/phase2_v1_boss_reward_suspend_snapshot.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_stage4_beta_compatibility_manifest_and_frozen_fixtures(failures)
	test_stage5_100_compatibility_baseline_is_frozen_and_continuable(failures)
	test_suspend_snapshot_has_explicit_v1_envelope_and_round_trips(failures)
	test_run_record_and_meta_progress_are_distinct_records(failures)
	test_load_reconstructs_without_mutating_a_live_domain(failures)
	test_battle_snapshot_reconstructs_live_child_and_can_continue(failures)
	test_nested_run_and_battle_state_round_trips(failures)
	test_validator_rejects_identity_boundary_and_missing_registry(failures)
	test_v2_suspend_snapshot_is_rejected_by_current_bundle(failures)
	test_v2_act_two_suspend_migration_preserves_bundle_identity(failures)
	test_issue_85_content_identities_migrate_without_changing_bundle_scope(failures)
	test_invalid_snapshot_is_rejected_atomically(failures)
	test_migrations_are_sequential(failures)
	test_restored_domains_rebind_service_and_summary_flows(failures)
	test_phase2_v1_suspend_fixture_requires_explicit_content_migration(failures)
	test_phase2_v1_migrates_to_both_act_two_catalog_identities(failures)
	test_phase2_v1_migration_rejects_active_event_semantic_changes(failures)
	test_v2_migration_rejects_unverifiable_active_effect_state(failures)
	test_phase2_v1_serialized_checkpoint_preserves_int64_wire_values(failures)
	test_archived_v1_wire_checkpoint_migrates_from_a_genuine_stable_save(failures)
	test_phase2_v1_pending_boss_reward_migrates_deterministically(failures)
	test_save_coordinator_accepts_stable_and_rejects_unstable_boundaries(failures)
	test_checkpoint_policy_writer_loader_phase_matrix_and_transitions(failures)
	return failures

func test_stage4_beta_compatibility_manifest_and_frozen_fixtures(failures: Array[String]) -> void:
	var manifest_path := "res://tests/fixtures/stage4_beta_compatibility_manifest.json"
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	assert_true(manifest_file != null, "the Stage 4 Beta compatibility manifest is available", failures)
	if manifest_file == null:
		return
	var manifest_text := manifest_file.get_as_text()
	manifest_file.close()
	var parsed = JSON.parse_string(manifest_text)
	assert_true(parsed is Dictionary, "the Stage 4 Beta compatibility manifest parses as JSON", failures)
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	var candidate: Dictionary = manifest.get("candidate", {})
	var candidate_schemas: Dictionary = candidate.get("record_schemas", {})
	assert_true(int(candidate_schemas.get("suspend_snapshot", -1)) == SuspendSnapshot.SCHEMA_VERSION, "the manifest records the current SuspendSnapshot schema", failures)
	assert_true(int(candidate_schemas.get("meta_progress", -1)) == MetaProgressStore.CURRENT_SCHEMA_VERSION, "the manifest records the current MetaProgress schema", failures)
	assert_true(int(candidate_schemas.get("replay_record", -1)) == ReplayRecord.SCHEMA_VERSION, "the manifest records the current ReplayRecord schema", failures)

	var content_targets: Dictionary = candidate.get("content_targets", {})
	var default_registry := ContentRegistry.new()
	Phase2Catalog.register_all(default_registry)
	AlphaActTwoCatalog.register_all(default_registry)
	AlphaScaleCatalog.register_all(default_registry)
	assert_true(default_registry.content_version() == str(content_targets.get("default_run_scene", "")), "the full candidate identity matches the default RunScene content registry", failures)
	var act_two_registry := ContentRegistry.new()
	Phase2Catalog.register_all(act_two_registry)
	AlphaActTwoCatalog.register_all(act_two_registry)
	assert_true(act_two_registry.content_version() == str(content_targets.get("act_two_without_scale", "")), "the no-Scale candidate identity matches the Act Two registry", failures)
	assert_true(ContentVersionMigration.ACT_TWO_SCALE_V13 == str(content_targets.get("default_run_scene", "")), "the default candidate identity matches its explicit migration target", failures)
	assert_true(ContentVersionMigration.ACT_TWO_V5 == str(content_targets.get("act_two_without_scale", "")), "the no-Scale candidate identity matches its explicit migration target", failures)

	var supported_formats: Array = manifest.get("supported_source_formats", [])
	assert_true(supported_formats.size() == 1, "the manifest claims only the mandated Phase 2 v1 source format", failures)
	for source_format in supported_formats:
		if not source_format is Dictionary:
			assert_true(false, "each supported source format is a dictionary", failures)
			continue
		var source: Dictionary = source_format
		assert_true(source.get("record", "") == "SuspendSnapshot" and int(source.get("schema_version", -1)) == 1, "the supported source fixture format is Phase 2 SuspendSnapshot schema 1", failures)
		assert_true(source.get("game_version", "") == "game.phase2.v1" and source.get("content_version", "") == "content.slice.v1", "the supported source fixture keeps the Phase 2 v1 envelope", failures)
		for fixture_value in source.get("fixtures", []):
			if not fixture_value is Dictionary:
				assert_true(false, "each frozen fixture entry is a dictionary", failures)
				continue
			var fixture: Dictionary = fixture_value
			var fixture_path := "res://%s" % str(fixture.get("path", ""))
			var fixture_file := FileAccess.open(fixture_path, FileAccess.READ)
			assert_true(fixture_file != null, "%s remains available as an immutable source fixture" % fixture_path, failures)
			if fixture_file == null:
				continue
			var fixture_bytes := fixture_file.get_buffer(fixture_file.get_length())
			fixture_file.close()
			var fixture_text := fixture_bytes.get_string_from_utf8()
			var actual_hash := _sha256(_canonical_lf_bytes(fixture_text))
			assert_true(actual_hash == str(fixture.get("sha256_lf_canonical", "")), "%s matches its pinned canonical-LF Phase 2 v1 fixture hash" % fixture_path, failures)
			var canonical_lf_text := _canonical_lf_bytes(fixture_text).get_string_from_utf8()
			var simulated_windows_text := canonical_lf_text.replace("\n", "\r\n")
			assert_true(_sha256(_canonical_lf_bytes(simulated_windows_text)) == actual_hash, "%s has the same fixture hash after simulated Windows CRLF checkout conversion" % fixture_path, failures)

func test_stage5_100_compatibility_baseline_is_frozen_and_continuable(failures: Array[String]) -> void:
	var manifest_path := "res://tests/fixtures/stage5_compatibility_manifest.json"
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	assert_true(manifest_file != null, "the Stage 5 1.0 compatibility manifest is available", failures)
	if manifest_file == null:
		return
	var manifest_text := manifest_file.get_as_text()
	manifest_file.close()
	var manifest_parse := JsonIntegerCodec.parse(manifest_text)
	assert_true(manifest_parse.get("accepted", false), "the Stage 5 compatibility manifest parses", failures)
	if not manifest_parse.get("accepted", false) or not manifest_parse.get("data") is Dictionary:
		return
	var manifest: Dictionary = manifest_parse.data
	var support: Dictionary = manifest.get("support", {})
	assert_true(support.get("starts_at", "") == "1.0.0", "public compatibility begins at 1.0.0", failures)
	assert_true(support.get("patch_line", "") == "1.0.x", "the compatibility window covers 1.0.x patches", failures)
	assert_true(support.get("pre_1_0", "") == "unsupported", "pre-1.0 formats are outside the compatibility promise", failures)
	assert_true(support.get("downgrades", "") == "unsupported", "save downgrades are outside the compatibility promise", failures)
	assert_true(support.get("1_1_plus", "") == "undecided", "1.1+ compatibility remains undecided", failures)

	var candidate: Dictionary = manifest.get("baseline_candidate", {})
	var candidate_provenance_failures_before := failures.size()
	assert_true(str(candidate.get("application_version", "")).begins_with("1.0.0-rc."), "the baseline records the frozen private 1.0.0 release candidate", failures)
	assert_true(candidate.get("public_baseline_version", "") == support.get("starts_at", ""), "the candidate fixtures are assigned to the agreed first public format", failures)
	assert_true(candidate.get("application_version", "") == "1.0.0-rc.1", "the immutable fixtures are pinned to the RC1 source candidate", failures)
	assert_true(candidate.get("source_commit", "") == "05b183e6825ccfa8c7674c493644bba2f3840e99", "the baseline records the exact clean RC1 source commit", failures)
	assert_true(not bool(candidate.get("source_dirty", true)), "the frozen candidate was built from a clean source commit", failures)
	assert_true(candidate.get("artifact_sha256", "") == "1c24a36d807866cd73533c9f17ab45860e2acdc945f6033b064518e32ecb1e1d", "the baseline records the hash-identified RC1 Windows package", failures)
	var candidate_provenance_valid := failures.size() == candidate_provenance_failures_before

	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	AlphaActTwoCatalog.register_all(registry)
	AlphaScaleCatalog.register_all(registry)

	var target_version := str(ProjectSettings.get_setting("application/config/version", ""))
	assert_true(target_version.begins_with("1.0."), "the compatibility gate runs against a 1.0.x candidate target", failures)
	var fixtures: Array = manifest.get("fixtures", [])
	assert_true(fixtures.size() >= 2, "the frozen baseline contains SuspendSnapshot and ReplayRecord fixtures", failures)
	if fixtures.size() < 2:
		return
	var save_fixture_count := 0
	var replay_fixture_count := 0
	for fixture_value in fixtures:
		if not fixture_value is Dictionary:
			assert_true(false, "each Stage 5 compatibility fixture entry is a dictionary", failures)
			continue
		var fixture: Dictionary = fixture_value
		if fixture.get("record", "") == "SuspendSnapshot":
			save_fixture_count += 1
			_verify_stage5_suspend_fixture(fixture, candidate, candidate_provenance_valid, registry, target_version, failures)
		elif fixture.get("record", "") == "ReplayRecord":
			replay_fixture_count += 1
			_verify_stage5_replay_fixture(fixture, candidate, candidate_provenance_valid, registry, target_version, failures)
		else:
			assert_true(false, "the manifest names only supported SuspendSnapshot and ReplayRecord fixtures", failures)
	assert_true(save_fixture_count > 0, "at least one immutable SuspendSnapshot fixture is exercised", failures)
	assert_true(replay_fixture_count > 0, "at least one immutable ReplayRecord fixture is exercised", failures)

func _verify_stage5_suspend_fixture(fixture: Dictionary, candidate: Dictionary, candidate_provenance_valid: bool, registry, target_version: String, failures: Array[String]) -> void:
	var failure_count_before := failures.size()
	var save_path := "res://%s" % str(fixture.get("path", ""))
	var save_text := _read_stage5_fixture(save_path, str(fixture.get("sha256_lf_canonical", "")), failures)
	if save_text.is_empty():
		_print_stage5_fixture_result("SuspendSnapshot", candidate, fixture, target_version, false, candidate_provenance_valid)
		return
	var parsed := JsonIntegerCodec.parse(save_text)
	assert_true(parsed.get("accepted", false) and parsed.get("data") is Dictionary, "%s parses as a SuspendSnapshot" % save_path, failures)
	if not parsed.get("accepted", false) or not parsed.get("data") is Dictionary:
		_print_stage5_fixture_result("SuspendSnapshot", candidate, fixture, target_version, false, candidate_provenance_valid)
		return
	var snapshot_data: Dictionary = parsed.data
	assert_true(int(snapshot_data.get("schema_version", -1)) == int(fixture.get("schema_version", -2)), "%s keeps its frozen save schema identity" % save_path, failures)
	assert_true(str(snapshot_data.get("game_version", "")) == str(fixture.get("game_version", "")), "%s keeps its frozen game identity" % save_path, failures)
	assert_true(str(snapshot_data.get("content_version", "")) == str(fixture.get("content_version", "")), "%s keeps its frozen content identity" % save_path, failures)
	_assert_stage5_fixture_game_content_identity(fixture, candidate, save_path, failures)
	var save_schemas: Dictionary = candidate.get("save_schema_versions", {})
	assert_true(int(fixture.get("schema_version", -1)) == int(save_schemas.get("suspend_snapshot", -2)), "%s schema matches the frozen candidate manifest" % save_path, failures)

	var load_result: Dictionary = SaveMapper.load_into_domain(save_text, registry)
	assert_true(load_result.get("accepted", false), "source=%s/SuspendSnapshot@%d loads into target=%s (%s: %s)" % [
		candidate.get("application_version", ""),
		int(fixture.get("schema_version", -1)),
		target_version,
		load_result.get("code", ""),
		load_result.get("errors", []),
	], failures)
	if not load_result.get("accepted", false):
		_print_stage5_fixture_result("SuspendSnapshot", candidate, fixture, target_version, false, candidate_provenance_valid)
		return
	var resumed: RunDomain = load_result.domain
	var expected_state_hash := str(fixture.get("checkpoint_state_hash", ""))
	assert_true(resumed.checkpoint().state_hash == expected_state_hash, "the resumed Run matches its frozen authoritative checkpoint hash", failures)
	assert_true(resumed.rng_snapshot() == snapshot_data.get("rng_state", {}), "the resumed Run restores the exact frozen RNG checkpoint", failures)

	var continuation: Dictionary = fixture.get("continuation", {})
	var route_result = resumed.execute(SelectMapNodeCommand.new("stage5.compatibility.route", str(continuation.get("route_node_id", ""))))
	var route_passed: bool = route_result != null and route_result.is_accepted()
	assert_true(route_passed, "the resumed Run accepts the frozen public map-route command", failures)
	if not route_passed:
		_print_stage5_fixture_result("SuspendSnapshot", candidate, fixture, target_version, false, candidate_provenance_valid)
		return
	assert_true(resumed.state.phase == RunPhase.BATTLE, "the resumed route reaches the candidate Battle phase", failures)
	assert_true(resumed.replay_record.checkpoints.size() > 1 and resumed.replay_record.checkpoints[1].domain_state_hash == str(continuation.get("route_checkpoint_state_hash", "")), "the route command matches its frozen authoritative checkpoint", failures)
	var draw_result = resumed.execute(DrawCommand.new("stage5.compatibility.draw", "player.1"))
	var draw_passed: bool = draw_result != null and draw_result.is_accepted()
	assert_true(draw_passed, "the resumed Battle accepts the frozen public Draw command", failures)
	if draw_passed:
		assert_true(resumed.checkpoint().state_hash == str(continuation.get("draw_checkpoint_state_hash", "")), "the resumed Draw matches its frozen authoritative checkpoint", failures)
		assert_true(resumed.rng_snapshot() == continuation.get("draw_rng_state", {}), "the resumed Draw matches the frozen deterministic RNG outcome", failures)
		assert_true(str(resumed.state.phase) == str(continuation.get("final_phase", "")), "the resumed Draw ends in the expected Run phase", failures)
	_print_stage5_fixture_result("SuspendSnapshot", candidate, fixture, target_version, failures.size() == failure_count_before, candidate_provenance_valid)

func _verify_stage5_replay_fixture(fixture: Dictionary, candidate: Dictionary, candidate_provenance_valid: bool, registry, target_version: String, failures: Array[String]) -> void:
	var failure_count_before := failures.size()
	var replay_path := "res://%s" % str(fixture.get("path", ""))
	var replay_text := _read_stage5_fixture(replay_path, str(fixture.get("sha256_lf_canonical", "")), failures)
	if replay_text.is_empty():
		_print_stage5_fixture_result("ReplayRecord", candidate, fixture, target_version, false, candidate_provenance_valid, "NOT_RUN:FIXTURE_UNAVAILABLE")
		return
	var replay_parse := JsonIntegerCodec.parse(replay_text)
	assert_true(replay_parse.get("accepted", false) and replay_parse.get("data") is Dictionary, "%s parses with exact integer values" % replay_path, failures)
	if not replay_parse.get("accepted", false) or not replay_parse.get("data") is Dictionary:
		_print_stage5_fixture_result("ReplayRecord", candidate, fixture, target_version, false, candidate_provenance_valid, "NOT_RUN:FIXTURE_PARSE_FAILED")
		return
	var replay_data: Dictionary = replay_parse.data
	var record = ReplayRecord.from_dictionary(replay_data)
	assert_true(int(record.schema_version) == int(fixture.get("schema_version", -1)), "%s keeps its frozen replay schema identity" % replay_path, failures)
	assert_true(str(record.game_version) == str(fixture.get("game_version", "")), "%s keeps its frozen game identity" % replay_path, failures)
	assert_true(str(record.content_version) == str(fixture.get("content_version", "")), "%s keeps its frozen content identity" % replay_path, failures)
	_assert_stage5_fixture_game_content_identity(fixture, candidate, replay_path, failures)
	assert_true(int(fixture.get("schema_version", -1)) == int(candidate.get("replay_schema_version", -2)), "%s schema matches the frozen candidate manifest" % replay_path, failures)
	assert_true(record.commands.size() == int(fixture.get("command_count", -1)), "%s keeps the frozen replay command count" % replay_path, failures)
	assert_true(str(record.terminal_outcome) == str(fixture.get("terminal_outcome", "")), "%s keeps the frozen terminal outcome" % replay_path, failures)

	var replay_run_id := str(fixture.get("run_id", ""))
	var factory_call_count := [0]
	var replay_factory := func(seed: int, content_version: String):
		factory_call_count[0] = int(factory_call_count[0]) + 1
		return RunDomain.new_alpha_run(replay_run_id, seed, registry, content_version)
	var identities_match: bool = (
		record.schema_version == ReplayRecord.SCHEMA_VERSION
		and record.game_version == SnapshotDto.GAME_VERSION
		and record.content_version == registry.content_version()
	)
	var replay_report = ReplayVerifier.verify(record, replay_factory, registry.content_version())
	if identities_match:
		assert_true(replay_report.is_match(), "source=%s/ReplayRecord@%d reproduces every authoritative checkpoint on target=%s (%s)" % [
			candidate.get("application_version", ""),
			record.schema_version,
			target_version,
			replay_report.reason,
		], failures)
		assert_true(int(factory_call_count[0]) > 0, "matching replay identities run deterministic checkpoint verification", failures)
	else:
		assert_true(replay_report.is_unavailable(), "source=%s/ReplayRecord@%d reports unavailable on target=%s when identities differ" % [
			candidate.get("application_version", ""),
			record.schema_version,
			target_version,
		], failures)
		assert_true(int(factory_call_count[0]) == 0, "an identity-mismatched fixture never starts deterministic replay", failures)

	for identity_case in [
		{"field": "schema_version", "value": int(record.schema_version) + 1, "reason": "REPLAY_SCHEMA_VERSION_UNAVAILABLE"},
		{"field": "game_version", "value": "game.unavailable", "reason": "GAME_VERSION_UNAVAILABLE"},
		{"field": "content_version", "value": "content.unavailable", "reason": "CONTENT_VERSION_UNAVAILABLE"},
	]:
		var incompatible_data: Dictionary = replay_data.duplicate(true)
		incompatible_data[str(identity_case.field)] = identity_case.value
		var incompatible_record = ReplayRecord.from_dictionary(incompatible_data)
		factory_call_count[0] = 0
		var unavailable_report = ReplayVerifier.verify(incompatible_record, replay_factory, registry.content_version())
		assert_true(unavailable_report.is_unavailable() and unavailable_report.reason == str(identity_case.reason), "replay identity mismatch for %s is reported unavailable" % identity_case.field, failures)
		assert_true(int(factory_call_count[0]) == 0, "replay identity mismatch for %s does not call the verifier factory" % identity_case.field, failures)

	var missing_schema_data: Dictionary = replay_data.duplicate(true)
	missing_schema_data.erase("schema_version")
	var missing_schema_record = ReplayRecord.from_dictionary(missing_schema_data)
	factory_call_count[0] = 0
	var missing_schema_report = ReplayVerifier.verify(missing_schema_record, replay_factory, registry.content_version())
	assert_true(missing_schema_report.is_unavailable() and missing_schema_report.reason == "REPLAY_SCHEMA_VERSION_UNAVAILABLE", "missing replay schema identity reports unavailable", failures)
	assert_true(int(factory_call_count[0]) == 0, "missing replay schema identity never starts verification", failures)
	var verifier_result := "MATCH" if replay_report.is_match() else "UNAVAILABLE:%s" % replay_report.reason if replay_report.is_unavailable() else "DIVERGED:%s" % replay_report.reason if replay_report.is_diverged() else "UNKNOWN:%s" % replay_report.status
	_print_stage5_fixture_result("ReplayRecord", candidate, fixture, target_version, failures.size() == failure_count_before, candidate_provenance_valid, verifier_result)

func _assert_stage5_fixture_game_content_identity(fixture: Dictionary, candidate: Dictionary, fixture_path: String, failures: Array[String]) -> void:
	assert_true(str(fixture.get("game_version", "")) == str(candidate.get("game_version", "")), "%s identifies the baseline candidate game format" % fixture_path, failures)
	assert_true(str(fixture.get("content_version", "")) == str(candidate.get("content_version", "")), "%s identifies the baseline candidate content format" % fixture_path, failures)

func _print_stage5_fixture_result(record_type: String, candidate: Dictionary, fixture: Dictionary, target_version: String, passed: bool, candidate_provenance_valid: bool, verifier_result: String = "") -> void:
	var outcome := "PASS" if passed else "FAIL"
	if not candidate_provenance_valid:
		outcome = "FAIL"
	var verifier_text := " verifier=%s" % verifier_result if not verifier_result.is_empty() else ""
	print("S5.3 compatibility: source=%s/%s@%d game=%s content=%s -> target=%s result=%s%s" % [
		candidate.get("application_version", ""),
		record_type,
		int(fixture.get("schema_version", -1)),
		fixture.get("game_version", ""),
		fixture.get("content_version", ""),
		target_version,
		outcome,
		verifier_text,
	])

func _read_stage5_fixture(path: String, expected_sha256: String, failures: Array[String]) -> String:
	var fixture_file := FileAccess.open(path, FileAccess.READ)
	assert_true(fixture_file != null, "%s remains available as an immutable Stage 5 source fixture" % path, failures)
	if fixture_file == null:
		return ""
	var fixture_bytes := fixture_file.get_buffer(fixture_file.get_length())
	fixture_file.close()
	var fixture_text := fixture_bytes.get_string_from_utf8()
	var actual_sha256 := _sha256(_canonical_lf_bytes(fixture_text))
	assert_true(actual_sha256 == expected_sha256 and not expected_sha256.is_empty(), "%s matches its pinned canonical-LF SHA-256" % path, failures)
	return fixture_text

func _canonical_lf_bytes(fixture_text: String) -> PackedByteArray:
	return fixture_text.replace("\r\n", "\n").to_utf8_buffer()

func _sha256(source_bytes: PackedByteArray) -> String:
	var hash_context := HashingContext.new()
	if hash_context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hash_context.update(source_bytes) != OK:
		return ""
	return hash_context.finish().hex_encode()

func test_suspend_snapshot_has_explicit_v1_envelope_and_round_trips(failures: Array[String]) -> void:
	var domain := _domain("persist.roundtrip", 1201)
	domain.execute(ChooseCharacterCommand.new("persist.character", "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("persist.contract", "base.contract.pressure"))
	var snapshot = SaveMapper.suspend_snapshot(domain)
	var data: Dictionary = snapshot.to_dictionary()
	for field in ["schema_version", "game_version", "content_version", "save_kind", "run_id", "run_seed", "run_state", "rng_state", "checkpoint_metadata"]:
		assert_true(data.has(field), "SuspendSnapshot contains %s" % field, failures)
	assert_true(data.schema_version == 1, "SuspendSnapshot uses schema version 1", failures)
	assert_true(data.save_kind == SuspendSnapshot.SAVE_KIND, "SuspendSnapshot identifies its save kind", failures)
	var parsed = SuspendSnapshot.from_dictionary(data)
	assert_true(parsed.to_dictionary() == data, "SuspendSnapshot round-trips through its explicit DTO", failures)
	assert_true(parsed.authoritative_state["map_state"].has("ordered_path"), "Map state is persisted as authoritative DTO data", failures)

func test_run_record_and_meta_progress_are_distinct_records(failures: Array[String]) -> void:
	var domain := _domain("persist.records", 1202)
	var run_record = SaveMapper.run_record(domain)
	var meta = MetaProgressSnapshot.new("game.phase2.v1", "meta.v1", {"unlocked": ["base.character.sequence"]})
	assert_true(run_record is RunRecord, "RunRecord is a distinct persistence DTO", failures)
	assert_true(run_record.save_kind == RunRecord.SAVE_KIND, "RunRecord has its own save kind", failures)
	assert_true(meta.save_kind == MetaProgressSnapshot.SAVE_KIND, "MetaProgressSnapshot has its own save kind", failures)
	assert_true(meta.to_dictionary().has("rng_state"), "MetaProgressSnapshot carries the common persistence envelope", failures)

func test_load_reconstructs_without_mutating_a_live_domain(failures: Array[String]) -> void:
	var source := _domain("persist.load", 1203)
	source.execute(ChooseCharacterCommand.new("persist.load.character", "base.character.sequence"))
	source.execute(ChooseContractCommand.new("persist.load.contract", "base.contract.pressure"))
	source.state.pattern_counts["SEQUENCE"] = 2
	source.state.yaku_counts["base.yaku.sequence"] = 1
	source.state.complete_hand_count = 1
	source.state.maximum_mahjong_score = 48
	source.state.boss_progress.append({"act_index": 1, "encounter_id": "base.encounter.boss"})
	source.state.milestones.append("first_complete_hand")
	var snapshot = SaveMapper.suspend_snapshot(source)
	var target := _domain("persist.target", 9999)
	var target_before := target.checkpoint()
	var loaded = SaveMapper.load_into_domain(snapshot.to_dictionary(), _registry(), target)
	assert_true(loaded.accepted, "a valid snapshot loads", failures)
	assert_true(target.checkpoint() == target_before, "load validation does not partially mutate the supplied domain", failures)
	assert_true(loaded.domain.state.to_dictionary() == source.state.to_dictionary(), "RunState reconstructs from explicit DTOs", failures)
	assert_true(loaded.domain.rng_snapshot() == source.rng_snapshot(), "RNG stream states reconstruct exactly", failures)
	assert_true(loaded.domain.checkpoint().state_hash == source.checkpoint().state_hash, "reconstruction preserves the authoritative state hash", failures)
	for stream_id in ["combat", "draw_wall", "enemy", "map", "reward", "shop", "event", "cosmetic"]:
		var source_stream = source.rng_streams.get(stream_id)
		var loaded_stream = loaded.domain.rng_streams.get(stream_id)
		assert_true(source_stream.next_int(0, 100) == loaded_stream.next_int(0, 100), "reconstruction preserves future %s RNG outcomes" % stream_id, failures)

func test_battle_snapshot_reconstructs_live_child_and_can_continue(failures: Array[String]) -> void:
	var source := _domain("persist.battle.resume", 1207)
	source.execute(ChooseCharacterCommand.new("persist.battle.character", "base.character.sequence"))
	source.execute(ChooseContractCommand.new("persist.battle.contract", "base.contract.pressure"))
	for tile_data in [
		["persist.battle.tile.1", "base.tile.characters.1"],
		["persist.battle.tile.2", "base.tile.characters.2"],
		["persist.battle.tile.3", "base.tile.characters.3"],
		["persist.battle.tile.4", "base.tile.characters.4"],
	]:
		source.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(tile_data[0], tile_data[1], "RUN", "RUN"))
	var selection = source.execute(SelectMapNodeCommand.new("persist.battle.select", source.map_definition.start_node_id))
	assert_true(selection.accepted and source.current_battle != null, "a valid battle snapshot has a live BattleDomain before saving (%s: %s)" % [selection.validation.code, selection.validation.message], failures)
	if not selection.accepted or source.current_battle == null:
		return
	var draw_wall_ids: Array[String] = []
	for tile in source.current_battle.zones.contents(TileZone.DRAW_WALL):
		draw_wall_ids.append(tile.instance_id)
	var serialized_draw_wall_order: Array[String] = draw_wall_ids.duplicate()
	var first_id: String = serialized_draw_wall_order[0]
	serialized_draw_wall_order[0] = serialized_draw_wall_order[-1]
	serialized_draw_wall_order[-1] = first_id
	assert_true(source.current_battle.zones.reorder(TileZone.DRAW_WALL, serialized_draw_wall_order), "the fixture creates a nontrivial serialized Draw Wall order", failures)
	source.state.current_battle_snapshot = RunBattleSnapshot.new(source.current_battle.checkpoint())
	var battle_checkpoint: Dictionary = source.current_battle.checkpoint()
	var run_checkpoint: Dictionary = source.checkpoint()
	var snapshot = SaveMapper.suspend_snapshot(source, {"stable": true, "stable_boundary": "BATTLE_START", "state_hash": run_checkpoint.state_hash})
	var loaded = SaveMapper.load_into_domain(snapshot.to_dictionary(), _registry())
	assert_true(loaded.accepted, "a stable BATTLE snapshot loads (%s: %s)" % [loaded.get("code", ""), loaded.get("errors", [])], failures)
	if not loaded.accepted:
		return
	assert_true(loaded.domain.current_battle != null, "loading a BATTLE snapshot reconstructs the live BattleDomain child", failures)
	assert_true(loaded.domain.state.current_battle_snapshot.to_dictionary() == battle_checkpoint, "the authoritative child BattleDomain checkpoint is preserved", failures)
	assert_true(loaded.domain.current_battle.checkpoint() == battle_checkpoint, "the reconstructed BattleDomain checkpoint round-trips exactly", failures)
	assert_true(loaded.domain.checkpoint().state_hash == run_checkpoint.state_hash, "the loaded run checkpoint hash is preserved", failures)
	assert_true(loaded.domain.current_battle.checkpoint() == source.current_battle.checkpoint(), "the loaded child checkpoint equals the source checkpoint", failures)
	var malformed_order: Dictionary = snapshot.to_dictionary()
	malformed_order["authoritative_state"]["current_battle_snapshot"]["zones"].erase(TileZone.PURGED)
	assert_true(not SaveMapper.load_into_domain(malformed_order, _registry()).accepted, "missing zone order is rejected", failures)
	var duplicate_order: Dictionary = snapshot.to_dictionary()
	var duplicate_draw_wall: Array = duplicate_order["authoritative_state"]["current_battle_snapshot"]["zones"][TileZone.DRAW_WALL].duplicate()
	duplicate_draw_wall[0] = duplicate_draw_wall[1]
	duplicate_order["authoritative_state"]["current_battle_snapshot"]["zones"][TileZone.DRAW_WALL] = duplicate_draw_wall
	assert_true(not SaveMapper.load_into_domain(duplicate_order, _registry()).accepted, "duplicate zone order is rejected", failures)
	var continuation = loaded.domain.execute(DrawCommand.new("persist.battle.resume.draw"))
	assert_true(continuation.accepted, "a loaded stable battle can continue through the public command seam", failures)

func test_invalid_snapshot_is_rejected_atomically(failures: Array[String]) -> void:
	var source := _domain("persist.invalid", 1204)
	var snapshot: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	snapshot["schema_version"] = 99
	var target := _domain("persist.atomic", 4321)
	var before := target.checkpoint()
	var result = SaveMapper.load_into_domain(snapshot, _registry(), target)
	assert_true(not result.accepted, "unsupported schemas are rejected", failures)
	assert_true(target.checkpoint() == before, "unsupported schemas cannot partially mutate a target", failures)
	var invalid_phase: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	invalid_phase["authoritative_state"]["phase"] = "NOT_A_PHASE"
	var phase_result = SaveMapper.load_into_domain(invalid_phase, _registry())
	assert_true(not phase_result.accepted, "invalid phases are rejected before reconstruction", failures)
	var invalid_currency: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	invalid_currency["authoritative_state"]["gold"] = -1
	var currency_result = SaveMapper.load_into_domain(invalid_currency, _registry())
	assert_true(not currency_result.accepted, "negative currency is rejected before reconstruction", failures)
	var invalid_id: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	invalid_id["authoritative_state"]["character_id"] = "base.character.missing"
	var id_result = SaveMapper.load_into_domain(invalid_id, _registry())
	assert_true(not id_result.accepted, "unknown content IDs are rejected before reconstruction", failures)
	var invalid_path: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	invalid_path["authoritative_state"]["map_state"]["current_node_id"] = "base.map_node.missing"
	var path_result = SaveMapper.load_into_domain(invalid_path, _registry())
	assert_true(not path_result.accepted, "invalid map nodes and paths are rejected", failures)
	var invalid_purchase: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	invalid_purchase["authoritative_state"]["shop_state"]["refreshes_remaining"] = -1
	var purchase_result = SaveMapper.load_into_domain(invalid_purchase, _registry())
	assert_true(not purchase_result.accepted, "invalid Shop purchase state is rejected", failures)
	var invalid_rng: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	invalid_rng["rng_state"]["streams"]["map"]["state"] = "not-an-integer"
	var rng_result = SaveMapper.load_into_domain(invalid_rng, _registry())
	assert_true(not rng_result.accepted, "invalid RNG state is rejected", failures)
	var invalid_game_version: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	invalid_game_version["game_version"] = "game.unavailable"
	var game_version_copy: Dictionary = invalid_game_version.duplicate(true)
	var game_version_result = SaveMapper.load_into_domain(invalid_game_version, _registry())
	assert_true(not game_version_result.accepted, "unsupported game versions are rejected", failures)
	assert_true(invalid_game_version == game_version_copy, "unsupported game-version rejection leaves input unchanged", failures)

func test_validator_rejects_identity_boundary_and_missing_registry(failures: Array[String]) -> void:
	var source := _domain("persist.validator", 1208)
	source.execute(ChooseCharacterCommand.new("persist.validator.character", "base.character.sequence"))
	source.execute(ChooseContractCommand.new("persist.validator.contract", "base.contract.pressure"))
	var mismatched_envelope: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	mismatched_envelope["authoritative_state"]["run_id"] = "persist.other-run"
	var envelope_result = SaveMapper.load_into_domain(mismatched_envelope, _registry())
	assert_true(not envelope_result.accepted, "envelope run identity must match authoritative state", failures)
	var mismatched_seed: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	mismatched_seed["authoritative_state"]["seed"] = 9999
	var seed_result = SaveMapper.load_into_domain(mismatched_seed, _registry())
	assert_true(not seed_result.accepted, "envelope seed must match authoritative state", failures)
	var mismatched_boundary: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	mismatched_boundary["checkpoint_metadata"]["stable_boundary"] = "SHOP"
	var boundary_result = SaveMapper.load_into_domain(mismatched_boundary, _registry())
	assert_true(not boundary_result.accepted, "checkpoint boundary must agree with the current run phase", failures)
	var invalid_act_count: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	invalid_act_count["authoritative_state"]["act_count"] = 3
	var act_count_result = LoadValidator.new().validate(invalid_act_count, _registry())
	assert_true(_has_validation_error(act_count_result, "INVALID_ACT_COUNT"), "saved Run profiles cannot introduce an optional Act 3", failures)
	var invalid_act_index: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	invalid_act_index["authoritative_state"]["act_count"] = 1
	invalid_act_index["authoritative_state"]["act_index"] = 2
	var act_index_result = LoadValidator.new().validate(invalid_act_index, _registry())
	assert_true(_has_validation_error(act_index_result, "INVALID_ACT_INDEX"), "saved Runs cannot resume in an Act beyond their profile", failures)
	var registry_result = SaveMapper.load_into_domain(SaveMapper.suspend_snapshot(source).to_dictionary(), null)
	assert_true(not registry_result.accepted, "content-bearing snapshots require a content registry for ID resolution", failures)

func test_v2_suspend_snapshot_is_rejected_by_current_bundle(failures: Array[String]) -> void:
	var source := RunDomain.new("persist.old-v2", 1218, _phase2_registry())
	source.execute(ChooseCharacterCommand.new("persist.old-v2.character", "base.character.sequence"))
	source.execute(ChooseContractCommand.new("persist.old-v2.contract", "base.contract.pressure"))
	var old_v2: Dictionary = SaveMapper.suspend_snapshot(source).to_dictionary()
	old_v2.content_version = "content.slice.v2"
	old_v2.authoritative_state.content_version = "content.slice.v2"
	old_v2.run_state.content_version = "content.slice.v2"
	old_v2.checkpoint_metadata.state_hash = _run_state_hash(old_v2.authoritative_state)
	var original := old_v2.duplicate(true)
	var rejected = SaveMapper.load_into_domain(old_v2, _phase2_registry())
	assert_true(not rejected.accepted, "an old v2 save cannot load under the new Event rules", failures)
	assert_true(_has_validation_error(rejected, "UNSUPPORTED_CONTENT_VERSION"), "old v2 saves report an explicit content-version boundary", failures)
	assert_true(old_v2 == original, "old-version rejection leaves the supplied save unchanged", failures)
	var migrated = SaveMapper.load_phase2_v2_suspend_snapshot_into_domain(old_v2, _phase2_registry())
	assert_true(migrated.accepted, "explicit v2 migration accepts a stable snapshot with no changed Event modifier (%s: %s)" % [migrated.get("code", ""), migrated.get("errors", [])], failures)
	assert_true(old_v2 == original, "successful v2 migration leaves the archived input unchanged", failures)
	if migrated.accepted:
		assert_true(migrated.snapshot.content_version == "content.slice.v4", "explicit v2 migration labels the authored Reaction rules accurately", failures)
		assert_true(migrated.pipeline.has("Explicit Content Migration: content.slice.v2 -> content.slice.v4"), "the load pipeline records explicit v2 migration", failures)
		assert_true(migrated.domain.replay_record.content_version == migrated.snapshot.content_version, "the resumed replay starts with the migrated content identity", failures)
		assert_true(migrated.domain.replay_record.checkpoints.size() == 1, "the resumed replay starts from the migrated checkpoint", failures)
		assert_true(migrated.domain.verify_replay().is_match(), "the migrated replay verifies from its new initial checkpoint", failures)
func test_phase2_v2_migration_rejects_active_event_semantic_changes(failures: Array[String]) -> void:
	var domain := RunDomain.new("persist.old-v2-effect", 1219, _phase2_registry())
	domain.execute(ChooseCharacterCommand.new("persist.old-v2-effect.character", "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("persist.old-v2-effect.contract", "base.contract.pressure"))
	var source: Dictionary = SaveMapper.suspend_snapshot(domain).to_dictionary()
	source.content_version = "content.slice.v2"
	source.authoritative_state.content_version = "content.slice.v2"
	source.run_state.content_version = "content.slice.v2"
	var active_modifier := ActiveEffectInstance.new(
		"run.modifier.event.risk_bargain.accept",
		DurationSpec.new(DurationSpec.RUN, 1),
		StackPolicy.new(StackPolicy.REPLACE),
		"event.risk_bargain.accept",
		1,
		-1,
		-1,
		"event.risk_bargain.accept",
		0,
		{"modifier_id": "event.risk_bargain.accept"},
	)
	source.authoritative_state.active_effects = [active_modifier.to_dictionary()]
	source.run_state = source.authoritative_state.duplicate(true)
	source.checkpoint_metadata.state_hash = _run_state_hash(source.authoritative_state)
	var original := source.duplicate(true)
	var rejected = SaveMapper.load_phase2_v2_suspend_snapshot_into_domain(source, _phase2_registry())
	assert_true(not rejected.accepted and rejected.get("code", "") == "UNSUPPORTED_ACTIVE_EVENT_MODIFIER_MIGRATION", "v2 migration refuses to reinterpret an active Event modifier", failures)
	assert_true(source == original, "rejected v2 Event migration leaves the old snapshot unchanged", failures)

func test_v2_act_two_suspend_migration_preserves_bundle_identity(failures: Array[String]) -> void:
	for include_scale in [false, true]:
		var registry := ContentRegistry.new()
		Phase2Catalog.register_all(registry)
		AlphaActTwoCatalog.register_all(registry)
		if include_scale:
			AlphaScaleCatalog.register_all(registry)
		var run_id := "persist.old-v2-act-two%s" % ("-scale" if include_scale else "")
		var domain: RunDomain = RunDomain.new_alpha_run(run_id, 1220 if not include_scale else 1222, registry)
		domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence"))
		domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure"))
		var source: Dictionary = SaveMapper.suspend_snapshot(domain).to_dictionary()
		var old_version := "content.bundle.v1.alpha.act_two@v2+phase2@v2"
		if include_scale:
			old_version = "content.bundle.v1.alpha.act_two@v2+alpha.scale@v2+phase2@v2"
		source.content_version = old_version
		source.authoritative_state.content_version = old_version
		source.run_state.content_version = old_version
		source.checkpoint_metadata.state_hash = _run_state_hash(source.authoritative_state)
		if include_scale:
			var no_scale_registry := ContentRegistry.new()
			Phase2Catalog.register_all(no_scale_registry)
			AlphaActTwoCatalog.register_all(no_scale_registry)
			var scaled_source_before: Dictionary = source.duplicate(true)
			var scale_downgrade = SaveMapper.load_phase2_v2_suspend_snapshot_into_domain(source, no_scale_registry)
			assert_true(not scale_downgrade.accepted and scale_downgrade.get("code", "") == "UNSUPPORTED_CONTENT_MIGRATION_TARGET", "a Scale v2 source cannot silently migrate into the Act Two-only registry", failures)
			assert_true(source == scaled_source_before, "a rejected Scale-to-Act-Two-only migration preserves its source snapshot", failures)
		var migrated = SaveMapper.load_phase2_v2_suspend_snapshot_into_domain(source, registry)
		var bundle_label := "Act Two+Scale" if include_scale else "Act Two"
		assert_true(migrated.accepted, "explicit v2 migration accepts an unchanged %s snapshot (%s: %s)" % [bundle_label, migrated.get("code", ""), migrated.get("errors", [])], failures)
		if migrated.accepted:
			assert_true(migrated.snapshot.content_version == registry.content_version(), "%s migration uses the exact active bundle combination" % bundle_label, failures)
			assert_true(migrated.domain.verify_replay().is_match(), "the migrated %s replay starts at a reproducible checkpoint" % bundle_label, failures)

func test_issue_85_content_identities_migrate_without_changing_bundle_scope(failures: Array[String]) -> void:
	for include_scale in [false, true]:
		var registry := ContentRegistry.new()
		Phase2Catalog.register_all(registry)
		AlphaActTwoCatalog.register_all(registry)
		if include_scale:
			AlphaScaleCatalog.register_all(registry)
		var run_id := "persist.issue-85-current%s" % ("-scale" if include_scale else "-act-two")
		var domain: RunDomain = RunDomain.new_alpha_run(run_id, 1280 if include_scale else 1281, registry) if include_scale else RunDomain.new(run_id, 1281, registry)
		assert_true(domain.execute(ChooseCharacterCommand.new("%s.character" % run_id, "base.character.sequence")).accepted, "%s legacy checkpoint selects its Character" % run_id, failures)
		assert_true(domain.execute(ChooseContractCommand.new("%s.contract" % run_id, "base.contract.pressure")).accepted, "%s legacy checkpoint selects its Contract" % run_id, failures)
		var source: Dictionary = SaveMapper.suspend_snapshot(domain).to_dictionary()
		var source_state: Dictionary = source.authoritative_state.duplicate(true)
		var map_state: Dictionary = source_state.get("map_state", {}).duplicate(true)
		var payload_ids: Dictionary = map_state.get("payload_ids", {}).duplicate(true)
		var old_act_one_ids := [
			"base.event.tile_surgery", "base.event.risk_bargain", "base.event.gold_exchange",
			"base.event.map_reveal", "base.event.contract_clause", "base.event.rule_memory",
		]
		for event_index in AlphaScaleCatalog.ACT_ONE_EVENT_IDS.size():
			for node_id in payload_ids.keys():
				if str(payload_ids[node_id]) == AlphaScaleCatalog.ACT_ONE_EVENT_IDS[event_index]:
					payload_ids[node_id] = old_act_one_ids[event_index]
		for event_index in AlphaActTwoCatalog.ACT_TWO_ADDITIONAL_EVENT_IDS.size():
			for node_id in payload_ids.keys():
				if str(payload_ids[node_id]) == AlphaActTwoCatalog.ACT_TWO_ADDITIONAL_EVENT_IDS[event_index]:
					payload_ids[node_id] = AlphaActTwoCatalog.ACT_TWO_EVENT_IDS[event_index]
		map_state["payload_ids"] = payload_ids
		source_state["map_state"] = map_state
		var prior_rule_memory := ActiveEffectInstance.new(
			"event.act_two.rule_memory",
			DurationSpec.new(DurationSpec.RUN, 1),
			StackPolicy.new(StackPolicy.UNIQUE),
			"event.act_two.rule_memory",
			1,
			-1,
			-1,
			"run.modifier.event.act_two.rule_memory",
			0,
			{"modifier_id": "event.act_two.rule_memory"},
		)
		source_state["active_effects"] = [prior_rule_memory.to_dictionary()]
		var legacy_identity := "content.bundle.v1.alpha.act_two@v4+alpha.scale@v11+phase2@v4" if include_scale else "content.bundle.v1.alpha.act_two@v4+phase2@v4"
		source["content_version"] = legacy_identity
		source_state["content_version"] = legacy_identity
		source["authoritative_state"] = source_state
		source["run_state"] = source_state.duplicate(true)
		var metadata: Dictionary = source.checkpoint_metadata.duplicate(true)
		metadata["state_hash"] = _run_state_hash(source_state)
		source["checkpoint_metadata"] = metadata
		var migrated = SaveMapper.load_full_v12_suspend_snapshot_into_domain(source, registry) if include_scale else SaveMapper.load_act_two_v4_suspend_snapshot_into_domain(source, registry)
		var scope := "Act Two + Scale" if include_scale else "Act Two only"
		assert_true(migrated.accepted, "the #85 %s identity migrates from a stable save (%s: %s)" % [scope, migrated.get("code", ""), migrated.get("errors", [])], failures)
		if migrated.accepted:
			assert_true(migrated.snapshot.content_version == registry.content_version(), "the #85 %s save adopts the exact current identity" % scope, failures)
			assert_true(migrated.snapshot.content_version.contains("alpha.scale") == include_scale, "the #85 %s save keeps its original bundle scope" % scope, failures)
			assert_true(migrated.domain.rng_snapshot() == source.rng_state, "the #85 %s migration preserves all RNG streams" % scope, failures)
			assert_true(migrated.domain.state.active_modifier("event.act_two.rule_memory") != null, "the #85 %s migration preserves an existing Rule Memory modifier" % scope, failures)

func test_v2_migration_rejects_unverifiable_active_effect_state(failures: Array[String]) -> void:
	var domain := RunDomain.new("persist.old-v2-malformed-effects", 1221, _phase2_registry())
	domain.execute(ChooseCharacterCommand.new("persist.old-v2-malformed-effects.character", "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("persist.old-v2-malformed-effects.contract", "base.contract.pressure"))
	var source: Dictionary = SaveMapper.suspend_snapshot(domain).to_dictionary()
	source.content_version = "content.slice.v2"
	source.authoritative_state.content_version = "content.slice.v2"
	source.run_state.content_version = "content.slice.v2"
	source.authoritative_state.active_effects = "unreadable"
	source.run_state = source.authoritative_state.duplicate(true)
	source.checkpoint_metadata.state_hash = _run_state_hash(source.authoritative_state)
	var rejected = SaveMapper.load_phase2_v2_suspend_snapshot_into_domain(source, _phase2_registry())
	assert_true(not rejected.accepted and rejected.get("code", "") == "UNVERIFIABLE_ACTIVE_EVENT_MODIFIER_STATE", "malformed active effects cannot bypass the migration guard", failures)
	var incomplete_effect: Dictionary = source.duplicate(true)
	incomplete_effect.authoritative_state.active_effects = [{"instance_id": "legacy.effect", "definition_id": "legacy.effect", "source_id": ""}]
	incomplete_effect.run_state = incomplete_effect.authoritative_state.duplicate(true)
	incomplete_effect.checkpoint_metadata.state_hash = _run_state_hash(incomplete_effect.authoritative_state)
	var incomplete_rejected = SaveMapper.load_phase2_v2_suspend_snapshot_into_domain(incomplete_effect, _phase2_registry())
	assert_true(not incomplete_rejected.accepted and incomplete_rejected.get("code", "") == "UNVERIFIABLE_ACTIVE_EVENT_MODIFIER_STATE", "an active effect without modifier identity data is rejected conservatively", failures)

func test_nested_run_and_battle_state_round_trips(failures: Array[String]) -> void:
	var source := _domain("persist.nested", 1206)
	source.execute(ChooseCharacterCommand.new("persist.nested.character", "base.character.sequence"))
	source.execute(ChooseContractCommand.new("persist.nested.contract", "base.contract.pressure"))
	source.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new("persist.tile", "base.tile.characters.1", "RUN", "RUN"))
	source.state.shop_state.begin("base.map_node.shop", "shop.entry", [ShopOffer.new("offer.1", 0, ShopOffer.RELIC, "base.relic.open_hand", 2)], 1, source.rng_streams.shop.snapshot())
	source.state.workshop_state.begin("base.map_node.workshop", "workshop.entry")
	var snapshot = SaveMapper.suspend_snapshot(source, {"stable": true, "stable_boundary": "MAP_NODE"})
	var loaded = SaveMapper.load_into_domain(snapshot.to_dictionary(), _registry())
	assert_true(loaded.accepted, "nested run child state is valid", failures)
	if loaded.accepted:
		assert_true(loaded.domain.state.shop_state.to_dictionary() == source.state.shop_state.to_dictionary(), "Shop state round-trips through the DTO mapper", failures)
		assert_true(loaded.domain.state.workshop_state.to_dictionary() == source.state.workshop_state.to_dictionary(), "Workshop state round-trips through the DTO mapper", failures)
	var battle_checkpoint := {"combat_state": {"terminal_outcome": "ONGOING"}, "zones": {"hand": ["persist.tile"]}}
	var battle_dto := BattleSnapshot.new(source.state.content_version, source.state.run_id, source.state.seed, battle_checkpoint, source.rng_snapshot(), {"stable": true, "stable_boundary": "BATTLE_START"})
	assert_true(BattleSnapshot.from_dictionary(battle_dto.to_dictionary()).to_dictionary() == battle_dto.to_dictionary(), "BattleSnapshot has an explicit DTO round-trip", failures)

func test_restored_domains_rebind_service_and_summary_flows(failures: Array[String]) -> void:
	var workshop_source := _domain("persist.rebind.workshop", 1210)
	workshop_source.execute(ChooseCharacterCommand.new("persist.rebind.workshop.character", "base.character.sequence"))
	workshop_source.execute(ChooseContractCommand.new("persist.rebind.workshop.contract", "base.contract.pressure"))
	workshop_source.state.phase = RunPhase.WORKSHOP
	workshop_source.state.gold = 100
	workshop_source.state.workshop_state.begin("base.map_node.workshop", "persist.rebind.workshop.entry")
	var tile_instance_id: String = workshop_source.state.tile_pool.tile_instances[0].instance_id
	var original_tile_definition_id: String = workshop_source.state.tile_pool.tile_instances[0].definition_id
	var workshop_snapshot = SaveMapper.suspend_snapshot(workshop_source)
	var restored_workshop = SaveMapper.load_into_domain(workshop_snapshot.to_dictionary(), _registry())
	assert_true(restored_workshop.accepted, "an active Workshop checkpoint restores", failures)
	if restored_workshop.accepted:
		var transform = restored_workshop.domain.execute(UseWorkshopServiceCommand.new(
			"persist.rebind.workshop.transform",
			UseWorkshopServiceCommand.TRANSFORM,
			tile_instance_id,
			"base.tile.bamboo.4",
		))
		assert_true(transform.accepted, "a restored domain accepts a Workshop service", failures)
		assert_true(restored_workshop.domain.state.tile_pool.tile_instances[0].definition_id == "base.tile.bamboo.4", "the Workshop flow mutates the restored authoritative RunState", failures)
		assert_true(workshop_source.state.tile_pool.tile_instances[0].definition_id == original_tile_definition_id, "the Workshop flow does not mutate the pre-load RunState", failures)

	var summary_source := _domain("persist.rebind.summary", 1211)
	summary_source.enter_run_summary("VICTORY", "RESTORE_TEST")
	var summary_snapshot = SaveMapper.suspend_snapshot(summary_source)
	var restored_summary = SaveMapper.load_into_domain(summary_snapshot.to_dictionary(), _registry())
	assert_true(restored_summary.accepted, "a Run Summary checkpoint restores", failures)
	if restored_summary.accepted:
		var acknowledgement = restored_summary.domain.execute(AcknowledgeRunSummaryCommand.new("persist.rebind.summary.acknowledge"))
		assert_true(acknowledgement.accepted, "a restored domain accepts Run Summary acknowledgement", failures)
		assert_true(restored_summary.domain.state.phase == RunPhase.RUN_COMPLETE, "the Run Summary flow advances the restored authoritative RunState", failures)
		assert_true(summary_source.state.phase == RunPhase.RUN_SUMMARY, "Run Summary acknowledgement does not mutate the pre-load RunState", failures)

func test_migrations_are_sequential(failures: Array[String]) -> void:
	var pipeline := MigrationPipeline.new(1)
	pipeline.register_migration(1, func(value: Dictionary) -> Dictionary:
		value["step_one"] = true
		value["schema_version"] = 2
		return value
	)
	pipeline.register_migration(2, func(value: Dictionary) -> Dictionary:
		value["step_two"] = true
		value["schema_version"] = 3
		return value
	)
	var result = pipeline.migrate({"schema_version": 1})
	assert_true(result.accepted, "registered migrations can advance a DTO", failures)
	assert_true(result.data.get("step_one", false) and result.data.get("step_two", false), "migrations run in sequential order", failures)

func test_phase2_v1_suspend_fixture_requires_explicit_content_migration(failures: Array[String]) -> void:
	var source: Dictionary = Phase2V1SuspendSnapshotFixture.suspend_snapshot()
	assert_true(typeof(source.run_seed) == TYPE_INT, "the immutable fixture retains the seed's integer DTO type", failures)
	assert_true(typeof(source.authoritative_state.gold) == TYPE_INT, "the immutable fixture retains currency integer DTO types", failures)
	assert_true(typeof(source.rng_state.streams.combat.state) == TYPE_INT, "the immutable fixture retains exact RNG integer DTO types", failures)
	assert_true(source.run_state == source.authoritative_state, "the historical SuspendSnapshot contains a consistent full-DTO state alias", failures)
	var original: Dictionary = source.duplicate(true)
	var schema_result = MigrationPipeline.new(1).migrate(source)
	assert_true(schema_result.accepted, "the v1 fixture passes the unchanged schema-only pipeline", failures)
	if schema_result.accepted:
		assert_true(schema_result.data.content_version == "content.slice.v1", "schema migration never changes content_version", failures)
		assert_true(schema_result.data.run_state.content_version == "content.slice.v1", "schema migration preserves the run_state alias content_version", failures)
	assert_true(source == original, "schema migration does not mutate the immutable fixture input", failures)

	var implicit_load = SaveMapper.load_into_domain(source, _registry())
	assert_true(not implicit_load.accepted, "ordinary loading does not silently migrate a v1 content version", failures)
	assert_true(source == original, "a rejected ordinary load leaves the fixture input untouched", failures)

	var explicit_load = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(source, _registry())
	assert_true(explicit_load.accepted, "the named Phase 2 v1 content migration loads the stable fixture (%s)" % explicit_load.get("code", ""), failures)
	assert_true(source == original, "successful content migration leaves the v1 fixture input untouched", failures)
	if not explicit_load.accepted:
		return

	assert_true(explicit_load.snapshot.content_version == "content.slice.v4", "the migrated snapshot uses the active v4 content bundle", failures)
	assert_true(explicit_load.domain.state.content_version == "content.slice.v4", "the reconstructed RunState uses the active v4 content bundle", failures)
	assert_true(explicit_load.snapshot.to_dictionary().run_state.content_version == "content.slice.v4", "explicit content migration updates the full-DTO run_state alias", failures)
	assert_true(explicit_load.domain.state.phase == "MAP_CHOICE", "migration resumes at the fixture's stable Map boundary", failures)
	assert_true(explicit_load.domain.state.character_id == "base.character.sequence" and explicit_load.domain.state.contract_id == "base.contract.pressure", "migration preserves the selected Character and Contract", failures)
	assert_true(explicit_load.pipeline.has("Explicit Content Migration: content.slice.v1 -> content.slice.v4"), "the returned load pipeline identifies the explicit content migration", failures)
	assert_true(explicit_load.domain.replay_record.content_version == "content.slice.v4" and explicit_load.domain.replay_record.checkpoints.size() == 1, "the resumed replay starts from the migrated v4 checkpoint", failures)
	assert_true(explicit_load.domain.verify_replay().is_match(), "the migrated v1 replay verifies from its new initial checkpoint", failures)
	assert_true(explicit_load.domain.validate_select_map_node("base.map_node.normal.left").is_valid(), "a valid next Map command remains available after migration", failures)

	var expected_state: Dictionary = original.authoritative_state.duplicate(true)
	expected_state["content_version"] = "content.slice.v4"
	expected_state["act_index"] = 1
	expected_state["act_count"] = 1
	assert_true(DeterministicSerializer.serialize(explicit_load.domain.state.to_dictionary()) == DeterministicSerializer.serialize(expected_state), "migration preserves the authoritative state apart from the content version and explicit one-Act profile fields", failures)
	var old_state_hash := DeterministicSerializer.hash(original.authoritative_state)
	var migrated_state_hash := DeterministicSerializer.hash(expected_state)
	assert_true(original.checkpoint_metadata.state_hash == old_state_hash, "the immutable fixture's original checkpoint hash verifies", failures)
	assert_true(explicit_load.snapshot.checkpoint_metadata.state_hash == migrated_state_hash, "the migrated checkpoint hash covers the migrated state", failures)
	assert_true(explicit_load.domain.checkpoint().state_hash == migrated_state_hash, "the reconstructed stable checkpoint reports the migrated state hash", failures)
	assert_true(migrated_state_hash != old_state_hash, "the explicit content-version change cannot retain a stale checkpoint hash", failures)

	assert_true(explicit_load.domain.rng_snapshot() == original.rng_state, "migration restores every saved RNG stream exactly", failures)
	var expected_rng := DomainRngStreams.new(int(original.run_seed))
	assert_true(expected_rng.restore(original.rng_state), "the fixture RNG state can be independently restored", failures)
	for stream_id in ["combat", "draw_wall", "enemy", "map", "reward", "shop", "event", "cosmetic"]:
		for draw_index in range(3):
			var expected_output: int = expected_rng.get(stream_id).next_int(0, 1000000)
			var migrated_output: int = explicit_load.domain.rng_streams.get(stream_id).next_int(0, 1000000)
			assert_true(migrated_output == expected_output, "migration preserves future %s RNG output %d" % [stream_id, draw_index + 1], failures)

	var rejected_fixture: Dictionary = original.duplicate(true)
	rejected_fixture.checkpoint_metadata.stable = false
	var rejected_copy: Dictionary = rejected_fixture.duplicate(true)
	var rejected_migration = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(rejected_fixture, _registry())
	assert_true(not rejected_migration.accepted, "content migration rejects an unstable v1 snapshot", failures)
	assert_true(rejected_fixture == rejected_copy, "failed content migration leaves its supplied snapshot untouched", failures)
	var alias_mismatch: Dictionary = original.duplicate(true)
	alias_mismatch.run_state.content_version = "content.slice.v2"
	var alias_mismatch_copy: Dictionary = alias_mismatch.duplicate(true)
	var alias_mismatch_result = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(alias_mismatch, _registry())
	assert_true(not alias_mismatch_result.accepted and alias_mismatch_result.code == "RUN_STATE_ALIAS_MISMATCH", "content migration rejects a conflicting legacy state alias", failures)
	assert_true(alias_mismatch == alias_mismatch_copy, "rejected alias migration leaves its supplied snapshot untouched", failures)
	var invalid_hash: Dictionary = original.duplicate(true)
	invalid_hash.checkpoint_metadata.state_hash = "not-the-source-state-hash"
	var invalid_hash_copy: Dictionary = invalid_hash.duplicate(true)
	var invalid_hash_result = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(invalid_hash, _registry())
	assert_true(not invalid_hash_result.accepted and invalid_hash_result.code == "SOURCE_STATE_HASH_MISMATCH", "content migration rejects a fixture whose source state hash is invalid", failures)
	assert_true(invalid_hash == invalid_hash_copy, "rejected hash migration leaves its supplied snapshot untouched", failures)

func test_phase2_v1_migrates_to_both_act_two_catalog_identities(failures: Array[String]) -> void:
	for include_scale in [false, true]:
		var registry := ContentRegistry.new()
		Phase2Catalog.register_all(registry)
		AlphaActTwoCatalog.register_all(registry)
		if include_scale:
			AlphaScaleCatalog.register_all(registry)
		var source: Dictionary = Phase2V1SuspendSnapshotFixture.suspend_snapshot()
		var migration = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(source, registry)
		var registry_label := "Act Two + Phase 2 + Alpha Scale" if include_scale else "Act Two + Phase 2"
		assert_true(migration.accepted, "Phase 2 v1 migrates into the %s registry (%s)" % [registry_label, migration.get("code", "")], failures)
		if migration.accepted:
			assert_true(migration.snapshot.content_version == registry.content_version(), "%s migration uses the exact registered content identity" % registry_label, failures)
			assert_true(migration.domain.state.content_version == registry.content_version(), "%s RunState and registry identities agree after migration" % registry_label, failures)

func test_phase2_v1_migration_rejects_active_event_semantic_changes(failures: Array[String]) -> void:
	var source: Dictionary = Phase2V1SuspendSnapshotFixture.suspend_snapshot()
	var changed_state: Dictionary = source.authoritative_state.duplicate(true)
	var active_modifier := ActiveEffectInstance.new(
		"run.modifier.event.risk_bargain.accept",
		DurationSpec.new(DurationSpec.RUN, 1),
		StackPolicy.new(StackPolicy.REPLACE),
		"event.risk_bargain.accept",
		1,
		-1,
		-1,
		"event.risk_bargain.accept",
		0,
		{"modifier_id": "event.risk_bargain.accept"},
	)
	changed_state.active_effects = [active_modifier.to_dictionary()]
	source.authoritative_state = changed_state
	source.run_state = changed_state.duplicate(true)
	source.checkpoint_metadata.state_hash = DeterministicSerializer.hash(changed_state)
	var original := source.duplicate(true)
	var rejected = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(source, _phase2_registry())
	assert_true(not rejected.accepted and rejected.get("code", "") == "UNSUPPORTED_ACTIVE_EVENT_MODIFIER_MIGRATION", "v1 migration refuses to activate an inert saved Event modifier under the new rules", failures)
	assert_true(source == original, "rejected Event modifier migration leaves the v1 archive unchanged", failures)

func test_phase2_v1_serialized_checkpoint_preserves_int64_wire_values(failures: Array[String]) -> void:
	var codec_boundaries = JsonIntegerCodec.parse("{\"max\":9223372036854775807,\"min\":-9223372036854775808,\"decimal\":1.25,\"text\":\"9223372036854775807\"}")
	assert_true(codec_boundaries.accepted, "JSON integer codec parses valid int64 boundaries", failures)
	if codec_boundaries.accepted:
		assert_true(typeof(codec_boundaries.data.max) == TYPE_INT and codec_boundaries.data.max == 9223372036854775807, "JSON integer codec preserves signed int64 maximum type and value", failures)
		assert_true(typeof(codec_boundaries.data.min) == TYPE_INT and codec_boundaries.data.min == -9223372036854775808, "JSON integer codec preserves signed int64 minimum type and value", failures)
		assert_true(typeof(codec_boundaries.data.decimal) == TYPE_FLOAT and is_equal_approx(codec_boundaries.data.decimal, 1.25), "JSON integer codec leaves decimal values numeric", failures)
		assert_true(typeof(codec_boundaries.data.text) == TYPE_STRING and codec_boundaries.data.text == "9223372036854775807", "JSON integer codec leaves numeric strings unchanged", failures)
	var escaped_marker = JsonIntegerCodec.parse("{\"value\":\"\\u005f\\u005fFORBIDDEN_TABLE_JSON_INTEGER__123\"}")
	assert_true(escaped_marker.accepted, "JSON integer codec parses strings containing escaped marker prefixes", failures)
	if escaped_marker.accepted:
		assert_true(typeof(escaped_marker.data.value) == TYPE_STRING and escaped_marker.data.value == "__FORBIDDEN_TABLE_JSON_INTEGER__123", "JSON integer codec preserves escaped marker-prefix strings without integer coercion", failures)
	assert_true(not JsonIntegerCodec.parse("{\"value\":9223372036854775808}").accepted, "JSON integer codec rejects values above signed int64", failures)
	assert_true(not JsonIntegerCodec.parse("{\"value\":-9223372036854775809}").accepted, "JSON integer codec rejects values below signed int64", failures)

	var fixture_path := "res://tests/fixtures/phase2_v1_serialized_suspend_snapshot.json"
	var fixture_file := FileAccess.open(fixture_path, FileAccess.READ)
	assert_true(fixture_file != null, "the immutable archived-v1 serialized fixture is available", failures)
	if fixture_file == null:
		return
	var serialized := fixture_file.get_as_text()
	fixture_file.close()
	assert_true(not serialized.is_empty(), "the immutable archived-v1 JSON fixture is non-empty", failures)
	var parsed_result = JsonIntegerCodec.parse(serialized)
	assert_true(parsed_result.accepted, "the lossless JSON codec parses the archived-v1 serialized fixture", failures)
	if not parsed_result.accepted:
		return
	var source: Dictionary = parsed_result.data
	var original: Dictionary = source.duplicate(true)
	assert_true(source.get("game_version", "") == "game.phase2.v1" and source.get("content_version", "") == "content.slice.v1", "the serialized fixture retains the immutable Phase 2 v1 envelope", failures)
	assert_true(typeof(source.get("run_seed", null)) == TYPE_INT, "the serialized fixture restores its run seed as an integer", failures)
	var stream_ids := ["combat", "draw_wall", "enemy", "map", "reward", "shop", "event", "cosmetic"]
	var has_wide_state := false
	for stream_id in stream_ids:
		var stream_state = source.rng_state.streams[stream_id].state
		assert_true(typeof(stream_state) == TYPE_INT, "the serialized %s RNG state is restored as an integer" % stream_id, failures)
		if typeof(stream_state) == TYPE_INT and (stream_state > 9007199254740991 or stream_state < -9007199254740991):
			has_wide_state = true
	assert_true(has_wide_state, "the serialized fixture exercises RNG values wider than exact IEEE-754 integer range", failures)
	assert_true(typeof(source.authoritative_state.gold) == TYPE_INT and typeof(source.authoritative_state.refinement_tokens) == TYPE_INT, "serialized currencies retain integer DTO types", failures)
	assert_true(source.checkpoint_metadata.state_hash == DeterministicSerializer.hash(source.authoritative_state), "the immutable serialized fixture's source hash verifies", failures)

	var ordinary_json_data = JSON.parse_string(serialized)
	var naive_validation = LoadValidator.new().validate(ordinary_json_data)
	var reproduced: Dictionary = {}
	for error in naive_validation.get("errors", []):
		if error is Dictionary:
			var code := str(error.get("code", ""))
			var field := str(error.get("field", ""))
			if code == "INVALID_CURRENCY":
				reproduced[code + ":" + field] = true
			else:
				reproduced[code] = true
	for expected_failure in ["INVALID_RNG_STATE", "INVALID_RUN_SEED", "INVALID_CURRENCY:gold", "INVALID_CURRENCY:refinement_tokens", "STATE_HASH_MISMATCH"]:
		assert_true(reproduced.has(expected_failure), "ordinary JSON parsing reproduces legacy failure %s" % expected_failure, failures)

	var implicit_load = SaveMapper.load_into_domain(serialized, _phase2_registry())
	assert_true(not implicit_load.accepted, "ordinary loading does not silently migrate serialized content.slice.v1", failures)
	var explicit_load = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(serialized, _phase2_registry())
	assert_true(explicit_load.accepted, "explicit migration loads the immutable serialized v1 fixture (%s)" % explicit_load.get("code", ""), failures)
	assert_true(source == original, "explicit JSON migration leaves the parsed source fixture unchanged", failures)
	var unchanged_fixture_file := FileAccess.open(fixture_path, FileAccess.READ)
	assert_true(unchanged_fixture_file != null, "the serialized fixture remains readable after migration", failures)
	if unchanged_fixture_file != null:
		assert_true(unchanged_fixture_file.get_as_text() == serialized, "migration does not rewrite the immutable serialized fixture bytes", failures)
		unchanged_fixture_file.close()
	if not explicit_load.accepted:
		return
	assert_true(explicit_load.snapshot.content_version == "content.slice.v4", "only the named migration advances the serialized fixture's content version", failures)
	assert_true(explicit_load.snapshot.checkpoint_metadata.state_hash == DeterministicSerializer.hash(explicit_load.domain.state.to_dictionary()), "migrated serialized checkpoint hash matches reconstructed state", failures)
	assert_true(explicit_load.domain.rng_snapshot() == source.rng_state, "every migrated serialized RNG stream restores its exact saved state", failures)
	var expected_rng := DomainRngStreams.new(int(source.run_seed))
	assert_true(expected_rng.restore(source.rng_state), "serialized fixture RNG state restores independently", failures)
	for stream_id in stream_ids:
		for draw_index in range(3):
			var expected_output: int = expected_rng.get(stream_id).next_int(0, 1000000)
			var migrated_output: int = explicit_load.domain.rng_streams.get(stream_id).next_int(0, 1000000)
			assert_true(migrated_output == expected_output, "serialized migration preserves future %s RNG output %d" % [stream_id, draw_index + 1], failures)

func test_archived_v1_wire_checkpoint_migrates_from_a_genuine_stable_save(failures: Array[String]) -> void:
	var fixture_path := "res://tests/fixtures/phase2_v1_archived_valid_suspend_snapshot.json"
	var fixture_file := FileAccess.open(fixture_path, FileAccess.READ)
	assert_true(fixture_file != null, "the archived-validator-accepted v1 JSON fixture is available", failures)
	if fixture_file == null:
		return
	var serialized := fixture_file.get_as_text()
	fixture_file.close()
	var parsed_result = JsonIntegerCodec.parse(serialized)
	assert_true(parsed_result.accepted, "the archived valid v1 fixture parses losslessly from its frozen JSON bytes", failures)
	if not parsed_result.accepted:
		return
	var source: Dictionary = parsed_result.data
	var original: Dictionary = source.duplicate(true)
	assert_true(source.get("game_version", "") == "game.phase2.v1" and source.get("content_version", "") == "content.slice.v1", "the archived stable fixture retains its Phase 2 v1 envelope", failures)
	assert_true(typeof(source.get("run_seed", null)) == TYPE_INT, "the archived stable fixture restores its integer run seed", failures)
	assert_true(typeof(source.authoritative_state.get("gold", null)) == TYPE_INT and typeof(source.authoritative_state.get("refinement_tokens", null)) == TYPE_INT, "the archived stable fixture restores integer currency fields", failures)
	var stream_ids := ["combat", "draw_wall", "enemy", "map", "reward", "shop", "event", "cosmetic"]
	var has_wide_state := false
	for stream_id in stream_ids:
		var stream_state = source.rng_state.streams[stream_id].state
		assert_true(typeof(stream_state) == TYPE_INT, "the archived stable fixture restores an integer %s RNG state" % stream_id, failures)
		if typeof(stream_state) == TYPE_INT and (stream_state > 9007199254740991 or stream_state < -9007199254740991):
			has_wide_state = true
	assert_true(has_wide_state, "the archived stable fixture includes RNG integers wider than the exact IEEE-754 range", failures)
	assert_true(source.checkpoint_metadata.state_hash == DeterministicSerializer.hash(source.authoritative_state), "the archived stable fixture state hash verifies before migration", failures)

	var registry = _phase2_registry()
	var ordinary_load = SaveMapper.load_into_domain(serialized, registry)
	assert_true(not ordinary_load.accepted, "ordinary loading does not silently migrate the archived v1 content version", failures)
	var migrated = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(serialized, registry)
	assert_true(migrated.accepted, "explicit v1 content migration accepts the archived-validator fixture (%s)" % migrated.get("code", ""), failures)
	assert_true(source == original, "migration leaves the archived v1 source DTO unchanged", failures)
	var unchanged_fixture := FileAccess.open(fixture_path, FileAccess.READ)
	assert_true(unchanged_fixture != null, "the immutable archived v1 fixture remains readable", failures)
	if unchanged_fixture != null:
		assert_true(unchanged_fixture.get_as_text() == serialized, "migration leaves the archived v1 JSON bytes unchanged", failures)
		unchanged_fixture.close()
	if not migrated.accepted:
		return
	assert_true(migrated.snapshot.content_version == "content.slice.v4", "only explicit migration advances the archived fixture content version", failures)
	assert_true(migrated.snapshot.checkpoint_metadata.state_hash == DeterministicSerializer.hash(migrated.domain.state.to_dictionary()), "the migrated archived fixture has a valid reconstructed state hash", failures)
	assert_true(migrated.domain.rng_snapshot() == source.rng_state, "every archived stream state survives migration exactly", failures)
	var expected_rng := DomainRngStreams.new(int(source.run_seed))
	assert_true(expected_rng.restore(source.rng_state), "the archived RNG snapshot restores independently", failures)
	for stream_id in stream_ids:
		for draw_index in range(3):
			var expected_output: int = expected_rng.get(stream_id).next_int(0, 1000000)
			var migrated_output: int = migrated.domain.rng_streams.get(stream_id).next_int(0, 1000000)
			assert_true(migrated_output == expected_output, "archived fixture migration preserves future %s RNG output %d" % [stream_id, draw_index + 1], failures)
func test_save_coordinator_accepts_stable_and_rejects_unstable_boundaries(failures: Array[String]) -> void:
	var domain := _domain("persist.coordinator", 1205)
	domain.execute(ChooseCharacterCommand.new("persist.coordinator.character", "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("persist.coordinator.contract", "base.contract.pressure"))
	var coordinator := SaveCoordinator.new()
	var stable = coordinator.save(domain)
	assert_true(stable.accepted, "Map node is a stable save checkpoint", failures)
	assert_true(coordinator.can_save(domain, "MAP_NODE").accepted, "MAP_NODE remains a valid checkpoint in Map Choice", failures)
	var invalid_map_boundary = coordinator.can_save(domain, "BATTLE_ACTION")
	assert_true(not invalid_map_boundary.accepted and invalid_map_boundary.get("code", "") == "CHECKPOINT_BOUNDARY_MISMATCH", "the writer rejects a Battle label for a Map Choice state", failures)
	var map_node_id: String = domain.map_definition.start_node_id
	var battle_entry = domain.execute(SelectMapNodeCommand.new("persist.coordinator.select-map-node", map_node_id))
	assert_true(battle_entry.accepted and domain.state.phase == RunPhase.BATTLE, "the writer fixture enters a real Battle through SelectMapNode", failures)
	assert_true(coordinator.can_save(domain, "DRAW_ACTION").accepted, "Battle action checkpoints remain valid in the resulting Battle phase", failures)
	var invalid_battle_boundary = coordinator.can_save(domain, "MAP_NODE")
	assert_true(not invalid_battle_boundary.accepted and invalid_battle_boundary.get("code", "") == "CHECKPOINT_BOUNDARY_MISMATCH", "the writer rejects MAP_NODE after Battle begins", failures)
	domain.state.phase = "UNSTABLE_EFFECT_QUEUE"
	var unstable = SaveCoordinator.new().save(domain)
	assert_true(not unstable.accepted, "unstable resolution boundaries are rejected", failures)
	for boundary in ["EFFECT_QUEUE", "REACTION_WINDOW", "PATTERN_RESOLUTION", "BOSS_TRANSITION"]:
		assert_true(not coordinator.can_save(domain, boundary).accepted, "%s is not a save boundary" % boundary, failures)

func test_checkpoint_policy_writer_loader_phase_matrix_and_transitions(failures: Array[String]) -> void:
	var expected_boundaries_by_phase: Dictionary = {
		RunPhase.MAP_CHOICE: ["MAP_NODE"],
		RunPhase.BATTLE: ["BATTLE_START", "TURN_START", "DRAW_ACTION", "BATTLE_ACTION", "SETTLEMENT_COMPLETE", "ENEMY_INTENT_COMPLETE"],
		RunPhase.SHOP: ["SHOP"],
		RunPhase.WORKSHOP: ["WORKSHOP"],
		RunPhase.EVENT: ["EVENT_CHOICE_BEFORE", "EVENT_CHOICE_AFTER"],
		RunPhase.REWARD_CHOICE: ["REWARD"],
		RunPhase.ELITE_REWARD: ["REWARD"],
		RunPhase.BOSS_REWARD: ["REWARD"],
		RunPhase.RUN_SUMMARY: ["RUN_SUMMARY"],
		RunPhase.RUN_COMPLETE: ["RUN_COMPLETE"],
	}
	var domain := _domain("persist.checkpoint.policy", 1206)
	domain.execute(ChooseCharacterCommand.new("persist.checkpoint.policy.character", "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("persist.checkpoint.policy.contract", "base.contract.pressure"))
	var coordinator := SaveCoordinator.new()
	var validator := LoadValidator.new()
	for phase in RunPhase.all():
		domain.state.phase = phase
		var expected: Array = expected_boundaries_by_phase.get(phase, [])
		for boundary in SaveCoordinator.STABLE_BOUNDARIES:
			var should_accept: bool = expected.has(boundary)
			var writer_result: Dictionary = coordinator.can_save(domain, boundary)
			assert_true(writer_result.get("accepted", false) == should_accept, "writer phase matrix %s/%s agrees with the checkpoint contract" % [phase, boundary], failures)
			var battle_snapshot: Dictionary = {"fixture": true} if phase == RunPhase.BATTLE else {}
			var checkpoint_errors: Array = []
			validator._validate_checkpoint(
				{"stable": true, "stable_boundary": boundary},
				{"phase": phase, "current_battle_snapshot": battle_snapshot},
				checkpoint_errors,
			)
			var loader_rejects_mismatch: bool = checkpoint_errors.any(func(error): return str(error.get("code", "")) == "CHECKPOINT_BOUNDARY_MISMATCH")
			assert_true(loader_rejects_mismatch == not should_accept, "loader phase matrix %s/%s agrees with the checkpoint contract" % [phase, boundary], failures)

	var transitions: Array[Dictionary] = [
		{"phase": RunPhase.BATTLE, "requested": "MAP_NODE", "inferred": "BATTLE_START", "expected": "BATTLE_START", "context": "map entry"},
		{"phase": RunPhase.REWARD_CHOICE, "requested": "ENEMY_INTENT_COMPLETE", "inferred": "REWARD", "expected": "REWARD", "context": "Battle victory"},
		{"phase": RunPhase.RUN_SUMMARY, "requested": "ENEMY_INTENT_COMPLETE", "inferred": "RUN_SUMMARY", "expected": "RUN_SUMMARY", "context": "terminal Battle defeat"},
		{"phase": RunPhase.REWARD_CHOICE, "requested": "SETTLEMENT_COMPLETE", "inferred": "REWARD", "expected": "REWARD", "context": "settlement into Reward"},
		{"phase": RunPhase.RUN_SUMMARY, "requested": "SETTLEMENT_COMPLETE", "inferred": "RUN_SUMMARY", "expected": "RUN_SUMMARY", "context": "terminal settlement into Summary"},
		{"phase": RunPhase.MAP_CHOICE, "requested": "REWARD", "inferred": "MAP_NODE", "expected": "MAP_NODE", "context": "Reward exit"},
		{"phase": RunPhase.RUN_SUMMARY, "requested": "REWARD", "inferred": "RUN_SUMMARY", "expected": "RUN_SUMMARY", "context": "Reward completion into Summary"},
		{"phase": RunPhase.MAP_CHOICE, "requested": "EVENT_CHOICE_AFTER", "inferred": "MAP_NODE", "expected": "MAP_NODE", "context": "Event exit"},
		{"phase": RunPhase.MAP_CHOICE, "requested": "SHOP", "inferred": "MAP_NODE", "expected": "MAP_NODE", "context": "Shop exit"},
		{"phase": RunPhase.MAP_CHOICE, "requested": "WORKSHOP", "inferred": "MAP_NODE", "expected": "MAP_NODE", "context": "Workshop exit"},
		{"phase": RunPhase.RUN_SUMMARY, "requested": "RUN_COMPLETE", "inferred": "RUN_SUMMARY", "expected": "RUN_SUMMARY", "context": "summary remains open"},
		{"phase": RunPhase.RUN_COMPLETE, "requested": "RUN_COMPLETE", "inferred": "RUN_COMPLETE", "expected": "RUN_COMPLETE", "context": "acknowledged summary"},
	]
	for transition in transitions:
		var resolved: String = SuspendCheckpointPolicy.resolve_result_boundary(
			str(transition.get("requested", "")),
			str(transition.get("phase", "")),
			str(transition.get("inferred", "")),
		)
		assert_true(resolved == str(transition.get("expected", "")), "%s resolves to a checkpoint valid for its resulting phase" % transition.get("context", "transition"), failures)

func test_phase2_v1_pending_boss_reward_migrates_deterministically(failures: Array[String]) -> void:
	var source: Dictionary = Phase2V1BossRewardSuspendSnapshotFixture.suspend_snapshot()
	var original: Dictionary = source.duplicate(true)
	assert_true(source.authoritative_state.phase == "BOSS_REWARD", "the archived v1 fixture is a pending Boss reward checkpoint", failures)
	assert_true(source.authoritative_state.reward_draft.is_empty(), "the archived v1 Boss reward has no draft", failures)
	assert_true(source.checkpoint_metadata.stable_boundary == "REWARD", "the archived v1 Boss reward is a stable REWARD boundary", failures)
	assert_true(source.authoritative_state.map_state.current_node_id == "base.map_node.boss", "the archived checkpoint is on the Boss map node", failures)
	assert_true(source.run_state == source.authoritative_state, "the archived v1 full-DTO alias is consistent", failures)
	assert_true(source.checkpoint_metadata.state_hash == DeterministicSerializer.hash(source.authoritative_state), "the archived v1 state hash verifies before migration", failures)

	var first = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(source, _phase2_registry())
	var second = SaveMapper.load_phase2_v1_suspend_snapshot_into_domain(source, _phase2_registry())
	assert_true(first.accepted and second.accepted, "repeated explicit migration accepts the archived pending Boss snapshot (%s / %s)" % [first.get("code", ""), second.get("code", "")], failures)
	assert_true(source == original, "successful repeated migration never mutates the immutable v1 input", failures)
	if not first.accepted or not second.accepted:
		return

	var first_snapshot: Dictionary = first.snapshot.to_dictionary()
	var second_snapshot: Dictionary = second.snapshot.to_dictionary()
	assert_true(first_snapshot == second_snapshot, "repeated migrations produce byte-equivalent migrated DTOs", failures)
	assert_true(first.domain.state.to_dictionary() == second.domain.state.to_dictionary(), "repeated migrations reconstruct identical RunState", failures)
	assert_true(first.domain.rng_snapshot() == second.domain.rng_snapshot(), "repeated migrations reconstruct identical post-draft RNG state", failures)
	assert_true(first_snapshot.content_version == "content.slice.v4", "the explicit migration advances content_version", failures)
	assert_true(first_snapshot.authoritative_state.phase == "BOSS_REWARD", "migration preserves the stable Boss reward phase", failures)
	assert_true(first_snapshot.authoritative_state.act_index == 1 and first_snapshot.authoritative_state.act_count == 1, "Phase 2 content migration preserves its one-Act run profile", failures)
	assert_true(first_snapshot.checkpoint_metadata.stable_boundary == "REWARD", "migration preserves the stable REWARD checkpoint boundary", failures)
	assert_true(first_snapshot.authoritative_state.reward_draft_sequence == int(original.authoritative_state.reward_draft_sequence) + 1, "migration advances the Boss draft sequence exactly once", failures)
	assert_true(first_snapshot.checkpoint_metadata.checkpoint_sequence == int(original.checkpoint_metadata.checkpoint_sequence) + 1, "migration advances checkpoint_sequence with the synthesized draft", failures)
	assert_true(first_snapshot.run_state == first_snapshot.authoritative_state, "migration updates the complete state alias without divergence", failures)
	assert_true(first_snapshot.rng_state.streams.reward == first_snapshot.authoritative_state.reward_draft.reward_rng_state, "saved Reward RNG state matches the generated draft's post-generation checkpoint", failures)
	assert_true(first_snapshot.rng_state.streams.reward != original.rng_state.streams.reward, "Boss choice generation advances the saved Reward RNG", failures)
	for stream_id in ["combat", "draw_wall", "enemy", "map", "shop", "event", "cosmetic"]:
		assert_true(first_snapshot.rng_state.streams[stream_id] == original.rng_state.streams[stream_id], "migration leaves the unrelated %s RNG stream untouched" % stream_id, failures)
	var draft = first.domain.state.reward_draft
	assert_true(draft != null and draft.options.size() == 3, "the resumed legacy Boss checkpoint exposes exactly three choices", failures)
	if draft == null or draft.options.size() != 3:
		return
	for option in draft.options:
		assert_true(option.kind == "RULE_BREAKER", "each migrated Boss choice is a Rule Breaker", failures)
	assert_true(draft.to_dictionary() == second.domain.state.reward_draft.to_dictionary(), "repeated migration produces identical ordered Boss choices", failures)
	var migrated_state_hash := DeterministicSerializer.hash(first_snapshot.authoritative_state)
	assert_true(first_snapshot.checkpoint_metadata.state_hash == migrated_state_hash, "migration replaces the source checkpoint hash with the migrated state hash", failures)
	assert_true(first.domain.checkpoint().state_hash == migrated_state_hash, "the resumed Domain reports the migrated checkpoint hash", failures)
	assert_true(migrated_state_hash != original.checkpoint_metadata.state_hash, "the migrated checkpoint cannot retain the pre-migration hash", failures)
	assert_true(first.pipeline.has("Explicit Content Migration: content.slice.v1 -> content.slice.v4"), "the returned pipeline identifies the explicit content migration", failures)

	var selected_option = draft.options[0]
	var first_choice = first.domain.execute(ChooseRewardCommand.new("legacy.boss.choice", selected_option.option_id, draft.draft_id))
	var second_choice = second.domain.execute(ChooseRewardCommand.new("legacy.boss.choice", selected_option.option_id, second.domain.state.reward_draft.draft_id))
	assert_true(first_choice.accepted and second_choice.accepted, "a legal typed Boss choice is accepted after Resume", failures)
	assert_true(first.domain.state.phase == "RUN_SUMMARY" and second.domain.state.phase == "RUN_SUMMARY", "the migrated pending Boss reward can complete into Run Summary", failures)
	assert_true(first.domain.state.act_count == 1 and second.domain.state.act_count == 1, "a migrated Phase 2 Boss reward remains a one-Act ending", failures)
	assert_true(first.domain.state.build_ownership.acquired_rule_breaker_ids == [selected_option.content_id], "the typed choice records the selected Rule Breaker", failures)
	assert_true(first.domain.state.terminal_summary.summary_data.get("rule_breaker_id", "") == selected_option.content_id, "Run Summary identifies the selected Rule Breaker", failures)
	assert_true(first.domain.checkpoint().state_hash == second.domain.checkpoint().state_hash, "repeatedly migrated Runs reach the identical post-Resume state hash", failures)
	assert_true(first.domain.rng_snapshot() == second.domain.rng_snapshot(), "typed selection after Resume preserves identical RNG state", failures)
	var expected_rng := DomainRngStreams.new(int(original.run_seed))
	assert_true(expected_rng.restore(first.domain.rng_snapshot()), "the post-Resume RNG snapshot restores independently", failures)
	for stream_id in ["combat", "draw_wall", "enemy", "map", "reward", "shop", "event", "cosmetic"]:
		for draw_index in range(3):
			var expected_output: int = expected_rng.get(stream_id).next_int(0, 1000000)
			var first_output: int = first.domain.rng_streams.get(stream_id).next_int(0, 1000000)
			var second_output: int = second.domain.rng_streams.get(stream_id).next_int(0, 1000000)
			assert_true(first_output == expected_output and second_output == expected_output, "post-Resume %s RNG output %d is deterministic" % [stream_id, draw_index + 1], failures)

func _domain(run_id: String, seed: int) -> RunDomain:
	return RunDomain.new(run_id, seed, _registry())

func _phase2_registry():
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	return registry

func _run_state_hash(state: Dictionary) -> String:
	var deterministic_state: Dictionary = state.duplicate(true)
	deterministic_state.erase("run_started_at_unix_seconds")
	return DeterministicSerializer.hash(deterministic_state)

func _has_validation_error(result: Dictionary, code: String) -> bool:
	for error in result.get("errors", []):
		if str(error.get("code", "")) == code:
			return true
	return false

func _registry():
	var registry := ContentRegistry.new()
	for tile_id in [
		"base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3", "base.tile.characters.4",
		"base.tile.bamboo.4", "base.tile.bamboo.5", "base.tile.bamboo.6",
		"base.tile.dots.7", "base.tile.dots.8", "base.tile.dots.9",
		"base.tile.honors.east", "base.tile.honors.white",
	]:
		var parts: PackedStringArray = tile_id.split(".")
		registry.register(TileDefinition.new(tile_id, parts[2], int(parts[3])))
	registry.register(RelicDefinition.new("base.relic.open_hand"))
	registry.register(TechniqueDefinition.new("base.technique.core.sequence_line", TechniqueDefinition.CORE, 1))
	registry.register(ContentDefinition.new("base.passive.sequence"))
	registry.register(CharacterDefinition.new("base.character.sequence", ["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3"], "base.relic.open_hand", "base.technique.core.sequence_line", "base.passive.sequence"))
	registry.register(ContractDefinition.new("base.contract.pressure", ContractDefinition.PRESSURE, {"pressure": 1}, {"draw_actions": 1}))
	var graph := IntentGraph.new("pressure", [EnemyIntent.new("pressure", "Pressure", 1, EnemyIntent.PRESSURE, [IntentTransition.fixed("pressure.loop", "pressure")])])
	registry.register(EnemyDefinition.new("base.enemy.persistence", graph, EnemyDefinition.NORMAL, 9, {"pressure_limit": 9}))
	registry.register(EncounterDefinition.new("base.encounter.intro", ["base.enemy.persistence"], EncounterDefinition.NORMAL))
	registry.register(EncounterDefinition.new("base.encounter.normal.left", ["base.enemy.persistence"], EncounterDefinition.NORMAL))
	return registry

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
