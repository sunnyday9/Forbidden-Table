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
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const DrawCommand = preload("res://src/domain/commands/draw_command.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const SuspendSnapshot = preload("res://src/infrastructure/persistence/suspend_snapshot.gd")
const MetaProgressSnapshot = preload("res://src/infrastructure/persistence/meta_progress_snapshot.gd")
const RunRecord = preload("res://src/infrastructure/persistence/run_record.gd")
const MigrationPipeline = preload("res://src/infrastructure/persistence/migration_pipeline.gd")
const SaveCoordinator = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const RunTileInstanceRecord = preload("res://src/domain/run/run_tile_instance_record.gd")
const RunBattleSnapshot = preload("res://src/domain/run/run_battle_snapshot.gd")
const TileZone = preload("res://src/domain/tiles/tile_zone.gd")
const ShopOffer = preload("res://src/domain/run/shop_offer.gd")
const BattleSnapshot = preload("res://src/infrastructure/persistence/battle_snapshot.gd")

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
	assert_true(loaded.accepted, "a stable BATTLE snapshot loads", failures)
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

func _domain(run_id: String, seed: int) -> RunDomain:
	return RunDomain.new(run_id, seed, _registry())

func _registry():
	var registry := ContentRegistry.new()
	for rank in range(1, 5):
		registry.register(TileDefinition.new("base.tile.characters.%d" % rank, "characters", rank))
	registry.register(RelicDefinition.new("base.relic.open_hand"))
	registry.register(TechniqueDefinition.new("base.technique.core.sequence_line", TechniqueDefinition.CORE, 1))
	registry.register(ContentDefinition.new("base.passive.sequence"))
	registry.register(CharacterDefinition.new("base.character.sequence", ["base.tile.characters.1"], "base.relic.open_hand", "base.technique.core.sequence_line", "base.passive.sequence"))
	registry.register(ContractDefinition.new("base.contract.pressure", ContractDefinition.PRESSURE, {"pressure": 1}, {"draw_actions": 1}))
	var graph := IntentGraph.new("pressure", [EnemyIntent.new("pressure", "Pressure", 1, EnemyIntent.PRESSURE, [IntentTransition.fixed("pressure.loop", "pressure")])])
	registry.register(EnemyDefinition.new("base.enemy.persistence", graph, EnemyDefinition.NORMAL, 9, {"pressure_limit": 9}))
	registry.register(EncounterDefinition.new("base.encounter.normal.left", ["base.enemy.persistence"], EncounterDefinition.NORMAL))
	return registry

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
