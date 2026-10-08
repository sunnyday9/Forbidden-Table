extends RefCounted

const ChooseCharacterCommandScript = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommandScript = preload("res://src/domain/commands/choose_contract_command.gd")
const ContentRegistryScript = preload("res://src/content/registry/content_registry.gd")
const AlphaScaleCatalogScript = preload("res://src/content/catalogs/alpha_scale_catalog.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")
const DeterministicSerializerScript = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const LoadValidatorScript = preload("res://src/infrastructure/persistence/load_validator.gd")
const MetaProgressStateScript = preload("res://src/domain/run/meta_progress_state.gd")
const ReplayCommandFactoryScript = preload("res://src/infrastructure/replay/replay_command_factory.gd")
const ReplayCommandRecordScript = preload("res://src/infrastructure/replay/replay_command_record.gd")
const ReplayRecordScript = preload("res://src/infrastructure/replay/replay_record.gd")
const ReplayVerifierScript = preload("res://src/infrastructure/replay/replay_verifier.gd")
const RunDomainScript = preload("res://src/domain/run/run_domain.gd")
const RunStartingPoolFactoryScript = preload("res://src/domain/run/run_starting_pool_factory.gd")
const RunTilePoolStateScript = preload("res://src/domain/run/run_tile_pool_state.gd")
const SaveMapperScript = preload("res://src/infrastructure/persistence/save_mapper.gd")
const AlphaSimulationStartingPoolFixtureScript = preload("res://src/infrastructure/simulation/alpha_simulation_starting_pool_fixture.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_basic_character_starting_pools(failures)
	test_every_reserve_suit_and_rejected_choice(failures)
	test_locked_character_keeps_the_legacy_biased_pool(failures)
	test_starting_pool_save_restore_and_legacy_save_preservation(failures)
	test_replay_rules_boundary_and_excluded_suit_round_trip(failures)
	test_simulation_fixture_versions_remain_explicit(failures)
	return failures

func test_basic_character_starting_pools(failures: Array[String]) -> void:
	var sequence_domain: Variant = _new_domain("starting-pool.sequence")
	var sequence_result = sequence_domain.execute(ChooseCharacterCommandScript.new(
		"starting-pool.sequence.choose",
		"base.character.sequence",
	))
	_assert(sequence_result.accepted, "Sequence Character selection is accepted", failures)
	if sequence_result.accepted:
		var sequence_tiles: Array = sequence_domain.state.tile_pool.tile_instances
		_assert(sequence_tiles.size() == 68, "Sequence starts with exactly 68 physical Tiles", failures)
		_assert(_definition_counts(sequence_tiles).size() == 34, "Sequence starts with every suited and honor Tile definition", failures)
		var sequence_counts := _definition_counts(sequence_tiles)
		for definition_id in sequence_counts:
			_assert(int(sequence_counts[definition_id]) == 2, "Sequence contains two physical copies of %s" % definition_id, failures)
		_assert(_unique_instance_count(sequence_tiles) == 68, "Sequence physical Tile instance IDs are unique", failures)
		for honor in ["east", "south", "west", "north", "red", "green", "white"]:
			_assert(int(sequence_counts.get("base.tile.honors.%s" % honor, 0)) == 2, "Sequence includes two copies of honor %s" % honor, failures)

	var reserve_domain: Variant = _new_domain("starting-pool.reserve")
	var reserve_result = reserve_domain.execute(ChooseCharacterCommandScript.new(
		"starting-pool.reserve.choose",
		"base.character.reserve",
	))
	_assert(reserve_result.accepted, "Reserve Character selection without a suit preserves the legacy default", failures)
	if reserve_result.accepted:
		var reserve_tiles: Array = reserve_domain.state.tile_pool.tile_instances
		_assert(reserve_tiles.size() == 72, "Reserve starts with 72 physical Tiles after removing one suit and all honors", failures)
		_assert(str(reserve_domain.state.to_dictionary().get("excluded_suit", "")) == "characters", "Reserve persists its legacy default excluded suit", failures)
		_assert(_unique_instance_count(reserve_tiles) == 72, "Reserve physical Tile instance IDs are unique", failures)
		var reserve_counts := _definition_counts(reserve_tiles)
		for definition_id in reserve_counts:
			_assert(not definition_id.begins_with("base.tile.characters."), "Reserve default excludes Character-suit Tiles", failures)
			_assert(not definition_id.begins_with("base.tile.honors."), "Reserve excludes honor Tiles", failures)
			_assert(int(reserve_counts[definition_id]) == 4, "Reserve retains four physical copies of %s" % definition_id, failures)

func test_every_reserve_suit_and_rejected_choice(failures: Array[String]) -> void:
	for suit in ["characters", "dots", "bamboo"]:
		var domain: Variant = _new_domain("starting-pool.reserve.%s" % suit)
		var result = domain.execute(ChooseCharacterCommandScript.new(
			"starting-pool.reserve.%s.choose" % suit,
			"base.character.reserve",
			"",
			"",
			false,
			suit,
		))
		_assert(result.accepted, "Reserve accepts the %s exclusion choice" % suit, failures)
		if not result.accepted:
			continue
		var records: Array = domain.state.tile_pool.tile_instances
		var counts := _definition_counts(records)
		_assert(records.size() == 72 and counts.size() == 18, "Reserve has 72 physical Tiles over the remaining 18 suited definitions (%s excluded)" % suit, failures)
		_assert(domain.state.excluded_suit == suit, "RunState records the selected %s exclusion" % suit, failures)
		for definition_id in counts:
			_assert(not str(definition_id).begins_with("base.tile.honors."), "Reserve excludes honors for every suit choice", failures)
			_assert(not str(definition_id).begins_with("base.tile.%s." % suit), "Reserve excludes the selected %s suit" % suit, failures)
			_assert(int(counts[definition_id]) == 4, "Reserve preserves four copies of each remaining definition", failures)
		_assert(_unique_instance_count(records) == 72, "Reserve instance IDs remain unique for %s" % suit, failures)

	var invalid_domain: Variant = _new_domain("starting-pool.reserve.invalid")
	var before: Dictionary = invalid_domain.checkpoint()
	var rng_before: Dictionary = invalid_domain.rng_snapshot()
	var invalid_result = invalid_domain.execute(ChooseCharacterCommandScript.new(
		"starting-pool.reserve.invalid.choose", "base.character.reserve", "", "", false, "honors",
	))
	_assert(not invalid_result.accepted and invalid_result.validation.code == "INVALID_EXCLUDED_SUIT", "Reserve rejects a non-suit exclusion", failures)
	_assert(invalid_domain.checkpoint() == before and invalid_domain.rng_snapshot() == rng_before, "invalid Reserve suit rejection is state- and RNG-atomic", failures)
	_assert(invalid_domain.replay_record.commands.is_empty(), "invalid Reserve suit is never recorded in replay", failures)

	var not_applicable_domain: Variant = _new_domain("starting-pool.sequence.no-exclusion")
	var not_applicable = not_applicable_domain.execute(ChooseCharacterCommandScript.new(
		"starting-pool.sequence.no-exclusion.choose", "base.character.sequence", "", "", false, "bamboo",
	))
	_assert(not not_applicable.accepted and not_applicable.validation.code == "EXCLUDED_SUIT_NOT_APPLICABLE", "Sequence rejects a suit exclusion because its pool includes every suit", failures)

	var preview_domain: Variant = _new_domain("starting-pool.reserve.preview")
	var preview_before: Dictionary = preview_domain.checkpoint()
	var preview_rng: Dictionary = preview_domain.rng_snapshot()
	var preview_result = preview_domain.execute(ChooseCharacterCommandScript.new(
		"starting-pool.reserve.preview.choose", "base.character.reserve", "", "", true, "dots",
	))
	_assert(not preview_result.accepted and preview_result.preview and not preview_result.replayable, "Reserve suit preview does not become authoritative", failures)
	_assert(preview_domain.checkpoint() == preview_before and preview_domain.rng_snapshot() == preview_rng, "Reserve suit preview leaves RunState and RNG untouched", failures)
	_assert(preview_domain.replay_record.commands.is_empty(), "Reserve suit preview is excluded from replay", failures)

func test_locked_character_keeps_the_legacy_biased_pool(failures: Array[String]) -> void:
	var registry = ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	AlphaScaleCatalogScript.register_all(registry)
	var domain = RunDomainScript.new(
		"starting-pool.harbor-reader", 6108, registry, "", null, 1, null,
		MetaProgressStateScript.all_unlocked_test_profile(),
	)
	var definition = registry.resolve("alpha.character.harbor_reader")
	var result = domain.execute(ChooseCharacterCommandScript.new("starting-pool.harbor-reader.choose", "alpha.character.harbor_reader"))
	_assert(result.accepted, "the locked roster Character remains selectable in the all-unlocked domain fixture", failures)
	if result.accepted:
		var expected_ids := RunStartingPoolFactoryScript.tile_definition_ids(definition.starting_tile_pool_bias)
		var actual_ids: Array[String] = []
		for record in domain.state.tile_pool.tile_instances:
			actual_ids.append(str(record.definition_id))
		_assert(actual_ids == expected_ids and actual_ids.size() == RunStartingPoolFactoryScript.LEGACY_TILE_COUNT, "Harbor Reader keeps its legacy bias-based starting pool", failures)
		_assert(domain.state.excluded_suit.is_empty(), "Harbor Reader does not acquire Reserve-only exclusion state", failures)

func test_starting_pool_save_restore_and_legacy_save_preservation(failures: Array[String]) -> void:
	var registry = _phase2_registry()
	var reserve_domain = RunDomainScript.new("starting-pool.save.reserve", 6109, registry)
	var reserve_result = reserve_domain.execute(ChooseCharacterCommandScript.new(
		"starting-pool.save.reserve.choose", "base.character.reserve", "", "", false, "dots",
	))
	_assert(reserve_result.accepted, "Reserve save setup accepts its chosen excluded suit", failures)
	if reserve_result.accepted:
		var contract_result = reserve_domain.execute(ChooseContractCommandScript.new("starting-pool.save.reserve.contract", "base.contract.pressure"))
		_assert(contract_result.accepted, "Reserve save setup reaches a stable Map checkpoint", failures)
		var original_pool: Dictionary = reserve_domain.state.tile_pool.to_dictionary()
		var snapshot = SaveMapperScript.suspend_snapshot(reserve_domain)
		var saved_data: Dictionary = snapshot.to_dictionary()
		_assert(str(saved_data.game_version) == "game.phase2.v1", "SuspendSnapshot keeps the compatible save game identity", failures)
		var loaded: Dictionary = SaveMapperScript.load_into_domain(saved_data, registry)
		_assert(loaded.get("accepted", false), "a current Reserve save reloads successfully (%s)" % str(loaded.get("errors", [])), failures)
		if loaded.get("accepted", false):
			_assert(loaded.domain.state.excluded_suit == "dots", "SaveMapper restores the selected excluded suit", failures)
			_assert(loaded.domain.state.tile_pool.to_dictionary() == original_pool, "SaveMapper restores the exact Reserve TilePool without redealing", failures)
			_assert(loaded.domain.state.to_dictionary().get("excluded_suit", "") == "dots", "excluded suit is part of a resumed checkpoint", failures)

	var legacy_domain = RunDomainScript.new("starting-pool.save.legacy", 6110, registry)
	var legacy_character = registry.resolve("base.character.reserve")
	legacy_domain.state.character_id = "base.character.reserve"
	legacy_domain.state.phase = "CONTRACT_SELECT"
	legacy_domain.state.tile_pool = RunTilePoolStateScript.new(RunStartingPoolFactoryScript.create(
		"base.character.reserve", legacy_character.starting_tile_pool_bias,
	))
	var legacy_contract_result = legacy_domain.execute(ChooseContractCommandScript.new("starting-pool.save.legacy.contract", "base.contract.pressure"))
	_assert(legacy_contract_result.accepted, "legacy save setup reaches a stable Map checkpoint", failures)
	var legacy_pool: Dictionary = legacy_domain.state.tile_pool.to_dictionary()
	var legacy_snapshot = SaveMapperScript.suspend_snapshot(legacy_domain)
	var legacy_data: Dictionary = legacy_snapshot.to_dictionary()
	_assert(not legacy_data.authoritative_state.has("excluded_suit"), "legacy-format state omits an unset excluded suit", failures)
	var legacy_loaded: Dictionary = SaveMapperScript.load_into_domain(legacy_data, registry)
	_assert(legacy_loaded.get("accepted", false), "a legacy save without excluded_suit remains loadable (%s)" % str(legacy_loaded.get("errors", [])), failures)
	if legacy_loaded.get("accepted", false):
		_assert(legacy_loaded.domain.state.excluded_suit.is_empty(), "legacy save hydration defaults excluded_suit to empty", failures)
		_assert(legacy_loaded.domain.state.tile_pool.to_dictionary() == legacy_pool, "legacy save keeps the old TilePool exactly instead of redealing", failures)

	var bad_type_data: Dictionary = legacy_data.duplicate(true)
	bad_type_data.authoritative_state["excluded_suit"] = 4
	bad_type_data.checkpoint_metadata["state_hash"] = _state_hash(bad_type_data.authoritative_state)
	var bad_type_validation: Dictionary = LoadValidatorScript.new().validate(bad_type_data, registry)
	_assert(not bad_type_validation.get("accepted", true) and _has_error(bad_type_validation.errors, "INVALID_EXCLUDED_SUIT"), "load validation rejects a non-string excluded_suit", failures)

	var bad_applicability_data: Dictionary = legacy_data.duplicate(true)
	bad_applicability_data.authoritative_state["excluded_suit"] = "dots"
	bad_applicability_data.authoritative_state["character_id"] = "base.character.sequence"
	bad_applicability_data.checkpoint_metadata["state_hash"] = _state_hash(bad_applicability_data.authoritative_state)
	var bad_applicability_validation: Dictionary = LoadValidatorScript.new().validate(bad_applicability_data, registry)
	_assert(not bad_applicability_validation.get("accepted", true) and _has_error(bad_applicability_validation.errors, "EXCLUDED_SUIT_NOT_APPLICABLE"), "load validation rejects suit state on a non-Reserve Character", failures)

func test_replay_rules_boundary_and_excluded_suit_round_trip(failures: Array[String]) -> void:
	var registry = _phase2_registry()
	var domain = RunDomainScript.new("starting-pool.replay.reserve", 6111, registry)
	var command = ChooseCharacterCommandScript.new(
		"starting-pool.replay.reserve.choose", "base.character.reserve", "player.1", "", false, "bamboo",
	)
	var accepted = domain.execute(command)
	_assert(accepted.accepted, "Reserve command with an explicit suit is accepted", failures)
	if accepted.accepted:
		var serialized_command: Dictionary = domain.replay_record.commands[0].to_command_dictionary()
		_assert(str(serialized_command.get("excluded_suit", "")) == "bamboo", "accepted Character replay payload records the selected suit", failures)
		var replay_command = ReplayCommandFactoryScript.from_record(domain.replay_record.commands[0])
		_assert(replay_command != null and replay_command.excluded_suit == "bamboo", "ReplayCommandFactory restores the selected suit", failures)
		if replay_command != null:
			_assert(replay_command.serialize() == command.serialize(), "the suit-bearing Character command round-trips exactly", failures)
		var record_copy = ReplayRecordScript.from_dictionary(domain.replay_record.to_dictionary())
		_assert(record_copy.game_version == ReplayRecordScript.GAME_VERSION, "new Run Replay records use the RC6 gameplay-rules identity", failures)
		var replay_factory: Callable = func(seed: int, content_version: String):
			return RunDomainScript.new("starting-pool.replay.reserve", seed, registry, content_version)
		var report = ReplayVerifierScript.verify(record_copy, replay_factory, domain.state.content_version)
		_assert(report.is_match(), "a suit-specific Reserve replay round-trips and reproduces (%s)" % report.reason, failures)

	var default_sequence_command := ChooseCharacterCommandScript.new("starting-pool.replay.sequence.choose", "base.character.sequence")
	_assert(not default_sequence_command.to_dictionary().has("excluded_suit"), "Sequence commands omit the Reserve-only field", failures)
	_assert(ReplayRecordScript.new(1, "content.rules.test").game_version == "game.rules.rc8.v1", "current replay default identifies the RC8 rules", failures)
	var rc6_record := ReplayRecordScript.new(6111, "content.rules.test", "starting-pool.replay.rc6", "game.rules.rc6.v1")
	var rc6_original_hash := DeterministicSerializerScript.hash(rc6_record.to_dictionary())
	var rc6_factory_calls := [0]
	var rc6_factory: Callable = func(_seed: int, _content_version: String):
		rc6_factory_calls[0] = int(rc6_factory_calls[0]) + 1
		return null
	var rc6_report = ReplayVerifierScript.verify(rc6_record, rc6_factory, "content.rules.test")
	_assert(rc6_report.status == "UNAVAILABLE" and rc6_report.reason == "GAME_VERSION_UNAVAILABLE", "RC6 gameplay-rule replays are unavailable under the RC7 rules boundary", failures)
	_assert(int(rc6_factory_calls[0]) == 0 and DeterministicSerializerScript.hash(rc6_record.to_dictionary()) == rc6_original_hash, "the RC7 boundary rejects RC6 replay before playback without relabeling its data", failures)

	var old_record = ReplayRecordScript.new(6112, "content.rules.test", "starting-pool.replay.old", "game.phase2.v1")
	var original_hash := DeterministicSerializerScript.hash(old_record.to_dictionary())
	var factory_calls := [0]
	var old_factory: Callable = func(_seed: int, _content_version: String):
		factory_calls[0] = int(factory_calls[0]) + 1
		return null
	var old_report = ReplayVerifierScript.verify(old_record, old_factory, "content.rules.test")
	_assert(old_report.status == "UNAVAILABLE" and old_report.reason == "GAME_VERSION_UNAVAILABLE", "older gameplay-rule replays are unavailable at the RC7 boundary", failures)
	_assert(int(factory_calls[0]) == 0, "old replay is rejected before a playback domain is constructed", failures)
	_assert(DeterministicSerializerScript.hash(old_record.to_dictionary()) == original_hash, "old replay version rejection leaves serialized identity unchanged", failures)
	_assert(ReplayRecordScript.from_dictionary(old_record.to_dictionary()).game_version == "game.phase2.v1", "decoding does not relabel a legacy replay", failures)

func test_simulation_fixture_versions_remain_explicit(failures: Array[String]) -> void:
	var bias: Array[String] = ["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3"]
	var legacy_ids := AlphaSimulationStartingPoolFixtureScript.legacy_v1_tile_definition_ids(bias)
	_assert(AlphaSimulationStartingPoolFixtureScript.LEGACY_FIXTURE_ID == "phase2.character_biased_complete_hand.v1", "the old biased fixture retains its historical identity", failures)
	_assert(legacy_ids.size() == AlphaSimulationStartingPoolFixtureScript.LEGACY_TILE_COUNT, "the historical fixture continues to materialize its original 14 definitions", failures)
	_assert(AlphaSimulationStartingPoolFixtureScript.legacy_v1_hash("base.character.sequence", bias) == AlphaSimulationStartingPoolFixtureScript.legacy_v1_hash("base.character.sequence", bias), "the historical fixture hash is stable", failures)
	_assert(AlphaSimulationStartingPoolFixtureScript.FIXTURE_ID != AlphaSimulationStartingPoolFixtureScript.LEGACY_FIXTURE_ID, "new Alpha simulation attempts carry a distinct starting-pool fixture version", failures)
	var sequence_character = _phase2_registry().resolve("base.character.sequence")
	var reserve_character = _phase2_registry().resolve("base.character.reserve")
	var sequence_ids := AlphaSimulationStartingPoolFixtureScript.tile_definition_ids("base.character.sequence", sequence_character.starting_tile_pool_bias)
	var reserve_ids := AlphaSimulationStartingPoolFixtureScript.tile_definition_ids("base.character.reserve", reserve_character.starting_tile_pool_bias, "dots")
	_assert(sequence_ids.size() == 68 and reserve_ids.size() == 72, "the active simulation fixture matches both authoritative starting pools", failures)
	_assert(
		AlphaSimulationStartingPoolFixtureScript.hash("base.character.reserve", reserve_character.starting_tile_pool_bias, "dots") != AlphaSimulationStartingPoolFixtureScript.hash("base.character.reserve", reserve_character.starting_tile_pool_bias, "bamboo"),
		"Reserve simulation hashes pin the selected excluded suit",
		failures,
	)

func _new_domain(run_id: String):
	var registry = ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	return RunDomainScript.new(run_id, 6107, registry)

func _phase2_registry():
	var registry = ContentRegistryScript.new()
	Phase2CatalogScript.register_all(registry)
	return registry

func _definition_counts(records: Array) -> Dictionary:
	var counts := {}
	for record in records:
		var identifier := str(record.definition_id)
		counts[identifier] = int(counts.get(identifier, 0)) + 1
	return counts

func _unique_instance_count(records: Array) -> int:
	var identifiers := {}
	for record in records:
		identifiers[str(record.instance_id)] = true
	return identifiers.size()

func _has_error(errors: Array, code: String) -> bool:
	for error in errors:
		if error is Dictionary and str(error.get("code", "")) == code:
			return true
	return false

func _state_hash(state: Dictionary) -> String:
	var normalized := state.duplicate(true)
	normalized.erase("run_started_at_unix_seconds")
	return DeterministicSerializerScript.hash(normalized)

func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
