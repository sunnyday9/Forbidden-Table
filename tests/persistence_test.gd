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
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const SuspendSnapshot = preload("res://src/infrastructure/persistence/suspend_snapshot.gd")
const MetaProgressSnapshot = preload("res://src/infrastructure/persistence/meta_progress_snapshot.gd")
const RunRecord = preload("res://src/infrastructure/persistence/run_record.gd")
const MigrationPipeline = preload("res://src/infrastructure/persistence/migration_pipeline.gd")
const SaveCoordinator = preload("res://src/infrastructure/persistence/save_coordinator.gd")
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
	test_suspend_snapshot_has_explicit_v1_envelope_and_round_trips(failures)
	test_run_record_and_meta_progress_are_distinct_records(failures)
	test_load_reconstructs_without_mutating_a_live_domain(failures)
	test_battle_snapshot_reconstructs_live_child_and_can_continue(failures)
	test_nested_run_and_battle_state_round_trips(failures)
	test_validator_rejects_identity_boundary_and_missing_registry(failures)
	test_invalid_snapshot_is_rejected_atomically(failures)
	test_migrations_are_sequential(failures)
	test_restored_domains_rebind_service_and_summary_flows(failures)
	test_phase2_v1_suspend_fixture_requires_explicit_content_migration(failures)
	test_phase2_v1_serialized_checkpoint_preserves_int64_wire_values(failures)
	test_archived_v1_wire_checkpoint_migrates_from_a_genuine_stable_save(failures)
	test_phase2_v1_pending_boss_reward_migrates_deterministically(failures)
	test_save_coordinator_accepts_stable_and_rejects_unstable_boundaries(failures)
	return failures

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
	var selection = source.execute(SelectMapNodeCommand.new("persist.battle.select", "base.map_node.normal.left"))
	assert_true(selection.accepted and source.current_battle != null, "a valid battle snapshot has a live BattleDomain before saving", failures)
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

	assert_true(explicit_load.snapshot.content_version == "content.slice.v2", "the migrated snapshot uses the active v2 content bundle", failures)
	assert_true(explicit_load.domain.state.content_version == "content.slice.v2", "the reconstructed RunState uses the active v2 content bundle", failures)
	assert_true(explicit_load.snapshot.to_dictionary().run_state.content_version == "content.slice.v2", "explicit content migration updates the full-DTO run_state alias", failures)
	assert_true(explicit_load.domain.state.phase == "MAP_CHOICE", "migration resumes at the fixture's stable Map boundary", failures)
	assert_true(explicit_load.domain.state.character_id == "base.character.sequence" and explicit_load.domain.state.contract_id == "base.contract.pressure", "migration preserves the selected Character and Contract", failures)
	assert_true(explicit_load.pipeline.has("Explicit Content Migration: content.slice.v1 -> content.slice.v2"), "the returned load pipeline identifies the explicit content migration", failures)
	assert_true(explicit_load.domain.validate_select_map_node("base.map_node.normal.left").is_valid(), "a valid next Map command remains available after migration", failures)

	var expected_state: Dictionary = original.authoritative_state.duplicate(true)
	expected_state["content_version"] = "content.slice.v2"
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
	assert_true(explicit_load.snapshot.content_version == "content.slice.v2", "only the named migration advances the serialized fixture's content version", failures)
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
	assert_true(migrated.snapshot.content_version == "content.slice.v2", "only explicit migration advances the archived fixture content version", failures)
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
	var stable = SaveCoordinator.new().save(domain)
	assert_true(stable.accepted, "Map node is a stable save checkpoint", failures)
	for boundary in SaveCoordinator.STABLE_BOUNDARIES:
		assert_true(SaveCoordinator.new().can_save(domain, boundary).accepted, "%s is an allowed stable checkpoint" % boundary, failures)
	domain.state.phase = "UNSTABLE_EFFECT_QUEUE"
	var unstable = SaveCoordinator.new().save(domain)
	assert_true(not unstable.accepted, "unstable resolution boundaries are rejected", failures)
	for boundary in ["EFFECT_QUEUE", "REACTION_WINDOW", "PATTERN_RESOLUTION", "BOSS_TRANSITION"]:
		assert_true(not SaveCoordinator.new().can_save(domain, boundary).accepted, "%s is not a save boundary" % boundary, failures)

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
	assert_true(first_snapshot.content_version == "content.slice.v2", "the explicit migration advances content_version", failures)
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
	assert_true(first.pipeline.has("Explicit Content Migration: content.slice.v1 -> content.slice.v2"), "the returned pipeline identifies the explicit content migration", failures)

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
	registry.register(EncounterDefinition.new("base.encounter.normal.left", ["base.enemy.persistence"], EncounterDefinition.NORMAL))
	return registry

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
