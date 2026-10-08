class_name RunDomainTest
extends RefCounted

const CharacterDefinition = preload("res://src/content/definitions/character_definition.gd")
const ContentDefinition = preload("res://src/content/definitions/content_definition.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")
const ContractDefinition = preload("res://src/content/definitions/contract_definition.gd")
const DomainEvent = preload("res://src/domain/events/domain_event.gd")
const RelicDefinition = preload("res://src/content/definitions/relic_definition.gd")
const RunBuildState = preload("res://src/domain/run/run_build_state.gd")
const RunBattleSnapshot = preload("res://src/domain/run/run_battle_snapshot.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunMapState = preload("res://src/domain/run/run_map_state.gd")
const RunPhase = preload("res://src/domain/run/run_phase.gd")
const RunTileInstanceRecord = preload("res://src/domain/run/run_tile_instance_record.gd")
const RunTilePoolState = preload("res://src/domain/run/run_tile_pool_state.gd")
const RunTerminalSummary = preload("res://src/domain/run/run_terminal_summary.gd")
const RunTutorialState = preload("res://src/domain/run/run_tutorial_state.gd")
const TechniqueDefinition = preload("res://src/content/definitions/technique_definition.gd")
const TileDefinition = preload("res://src/content/definitions/tile_definition.gd")
const AcknowledgeRunSummaryCommand = preload("res://src/domain/commands/acknowledge_run_summary_command.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_run_state_contains_typed_persistent_state(failures)
	test_phase2_and_alpha_run_profiles_keep_distinct_act_counts(failures)
	test_checkpoint_retains_tile_pool_and_current_battle_snapshot(failures)
	test_character_selection_advances_the_authoritative_run(failures)
	test_contract_selection_advances_to_map_choice(failures)
	test_invalid_phase_and_id_rejections_are_atomic(failures)
	test_duplicate_choice_is_atomic(failures)
	test_preview_choice_is_atomic_and_not_replayable(failures)
	test_commands_use_stable_content_ids(failures)
	test_same_seed_and_commands_produce_same_run_checkpoint(failures)
	test_terminal_summary_acknowledgment_is_authoritative(failures)
	return failures

func test_run_state_contains_typed_persistent_state(failures: Array[String]) -> void:
	var domain := RunDomain.new("run.state", 101, _registry())
	var state = domain.state

	assert_true(state.run_id == "run.state", "RunState stores the run ID", failures)
	assert_true(state.seed == 101, "RunState stores the run seed", failures)
	assert_true(state.content_version == ContentRegistry.CONTENT_VERSION, "RunState stores the content version", failures)
	assert_true(state.act_count == 1, "the Phase 2 RunDomain constructor preserves the one-Act default", failures)
	assert_true(state.phase == RunPhase.CHARACTER_SELECT, "RunState starts in Character Select", failures)
	assert_true(state.character_id.is_empty() and state.contract_id.is_empty(), "RunState starts without selections", failures)
	assert_true(state.map_state is RunMapState, "RunState owns typed map/path state", failures)
	assert_true(state.tile_pool is RunTilePoolState, "RunState owns a typed Tile Pool child state", failures)
	assert_true(state.current_battle_snapshot == null, "RunState starts without a current battle snapshot", failures)
	assert_true(state.gold == 0 and state.refinement_tokens == 0, "RunState starts with typed run currencies", failures)
	assert_true(state.build_ownership is RunBuildState, "RunState owns typed build ownership", failures)
	assert_true(state.tutorial_state is RunTutorialState, "RunState owns typed tutorial state", failures)
	assert_true(state.terminal_summary is RunTerminalSummary, "RunState owns typed terminal summary state", failures)
	assert_true(state.to_dictionary().has("map_state"), "RunState checkpoint includes map/path state", failures)
	assert_true(state.to_dictionary().get("act_count", 0) == 1, "RunState checkpoint records its one-Act profile", failures)

func test_phase2_and_alpha_run_profiles_keep_distinct_act_counts(failures: Array[String]) -> void:
	var registry = _registry()
	var phase2_domain := RunDomain.new("run.phase2-profile", 102, registry)
	var alpha_domain = RunDomain.new_alpha_run("run.alpha-profile", 103, registry)
	assert_true(phase2_domain.state.act_count == 1, "the compatibility constructor creates a one-Act Phase 2 Run", failures)
	assert_true(alpha_domain.state.act_count == 2, "the named Alpha factory creates a two-Act Run", failures)
	assert_true(alpha_domain.checkpoint().run_state.act_count == 2, "the Alpha profile is present in the first replay checkpoint", failures)
	assert_true(alpha_domain.replay_record.checkpoints[0].domain_snapshot.data == alpha_domain.checkpoint(), "the Alpha replay's initial snapshot includes its two-Act profile", failures)

func test_checkpoint_retains_tile_pool_and_current_battle_snapshot(failures: Array[String]) -> void:
	var domain := RunDomain.new("run.child-state", 111, _registry())
	domain.state.phase = RunPhase.BATTLE
	domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
		"run.tile.1",
		"base.tile.characters.1",
		"RUN",
		"RUN",
	))
	domain.state.current_battle_snapshot = RunBattleSnapshot.new({
		"combat_state": {"terminal_outcome": "ONGOING"},
		"zones": {"hand": ["run.tile.1"]},
	})

	var run_state_checkpoint: Dictionary = domain.checkpoint()["run_state"]
	var tile_records: Array = run_state_checkpoint["tile_pool"]["tile_instances"]
	var battle_snapshot: Dictionary = run_state_checkpoint["current_battle_snapshot"]

	assert_true(tile_records.size() == 1, "RunState checkpoint retains every run TileInstance record", failures)
	assert_true(tile_records[0]["instance_id"] == "run.tile.1", "tile checkpoint retains stable TileInstance ownership identity", failures)
	assert_true(tile_records[0]["definition_id"] == "base.tile.characters.1", "tile checkpoint retains stable TileDefinition identity", failures)
	assert_true(tile_records[0]["ownership_scope"] == "RUN", "tile checkpoint retains TileInstance ownership state", failures)
	assert_true(tile_records[0]["lifetime_scope"] == "RUN", "tile checkpoint retains TileInstance lifetime state", failures)
	assert_true(battle_snapshot["combat_state"]["terminal_outcome"] == "ONGOING", "BATTLE-phase checkpoint retains the current battle snapshot", failures)
	assert_true(battle_snapshot["zones"]["hand"] == ["run.tile.1"], "battle snapshot retains stable TileInstance references", failures)

func test_contract_selection_advances_to_map_choice(failures: Array[String]) -> void:
	var domain := RunDomain.new("run.contract", 202, _registry())
	domain.execute(ChooseCharacterCommand.new("run.contract.character", "base.character.sequence"))
	var result = domain.execute(ChooseContractCommand.new("run.contract.choose", "base.contract.pressure"))

	assert_true(result.accepted, "a valid Contract choice is accepted", failures)
	assert_true(domain.state.phase == RunPhase.MAP_CHOICE, "Contract choice advances to Map Choice", failures)
	assert_true(domain.state.contract_id == "base.contract.pressure", "RunState stores the stable Contract ID", failures)
	assert_true(_has_event(result.events, DomainEvent.CONTRACT_SELECTED), "Contract choice emits a factual ContractSelected event", failures)
	assert_true(_has_event(result.events, DomainEvent.RUN_PHASE_CHANGED), "Contract choice emits a factual phase transition event", failures)

func test_invalid_phase_and_id_rejections_are_atomic(failures: Array[String]) -> void:
	var phase_domain := RunDomain.new("run.invalid.phase", 303, _registry())
	var phase_before := phase_domain.checkpoint()
	var phase_rng_before := phase_domain.rng_snapshot()
	var phase_result = phase_domain.execute(ChooseContractCommand.new("run.invalid.phase.contract", "base.contract.pressure"))

	assert_true(not phase_result.accepted, "Contract choice is rejected during Character Select", failures)
	assert_true(phase_result.validation.code == "INVALID_PHASE", "invalid phase rejection is explicit", failures)
	assert_true(phase_result.events.is_empty(), "invalid phase emits no factual events", failures)
	assert_true(phase_domain.checkpoint() == phase_before, "invalid phase leaves RunState unchanged", failures)
	assert_true(phase_domain.rng_snapshot() == phase_rng_before, "invalid phase leaves every RNG stream unchanged", failures)

	var id_domain := RunDomain.new("run.invalid.id", 404, _registry())
	var id_before := id_domain.checkpoint()
	var id_rng_before := id_domain.rng_snapshot()
	var id_result = id_domain.execute(ChooseCharacterCommand.new("run.invalid.id.character", "base.character.missing"))

	assert_true(not id_result.accepted, "an unknown Character ID is rejected", failures)
	assert_true(id_result.validation.code == "INVALID_CHARACTER_ID", "invalid Character IDs are explicit", failures)
	assert_true(id_domain.checkpoint() == id_before, "invalid IDs leave RunState unchanged", failures)
	assert_true(id_domain.rng_snapshot() == id_rng_before, "invalid IDs leave every RNG stream unchanged", failures)

	var contract_id_domain := RunDomain.new("run.invalid.contract", 405, _registry())
	contract_id_domain.execute(ChooseCharacterCommand.new("run.invalid.contract.character", "base.character.sequence"))
	var contract_id_before := contract_id_domain.checkpoint()
	var contract_id_rng_before := contract_id_domain.rng_snapshot()
	var contract_id_result = contract_id_domain.execute(ChooseContractCommand.new("run.invalid.contract.choice", "base.contract.missing"))

	assert_true(not contract_id_result.accepted, "an unknown Contract ID is rejected", failures)
	assert_true(contract_id_result.validation.code == "INVALID_CONTRACT_ID", "invalid Contract IDs are explicit", failures)
	assert_true(contract_id_domain.checkpoint() == contract_id_before, "invalid Contract IDs leave RunState unchanged", failures)
	assert_true(contract_id_domain.rng_snapshot() == contract_id_rng_before, "invalid Contract IDs leave every RNG stream unchanged", failures)

func test_duplicate_choice_is_atomic(failures: Array[String]) -> void:
	var domain := RunDomain.new("run.duplicate", 505, _registry())
	var accepted = domain.execute(ChooseCharacterCommand.new("run.duplicate.first", "base.character.sequence"))
	var before := domain.checkpoint()
	var rng_before := domain.rng_snapshot()
	var duplicate = domain.execute(ChooseCharacterCommand.new("run.duplicate.again", "base.character.sequence"))

	assert_true(accepted.accepted, "duplicate-choice setup is accepted", failures)
	assert_true(not duplicate.accepted, "repeating a selected Character is rejected", failures)
	assert_true(duplicate.validation.code == "DUPLICATE_CHOICE", "duplicate choice rejection is explicit", failures)
	assert_true(duplicate.events.is_empty(), "duplicate choice emits no factual events", failures)
	assert_true(domain.checkpoint() == before, "duplicate choice leaves RunState unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "duplicate choice leaves every RNG stream unchanged", failures)

	var contract_domain := RunDomain.new("run.duplicate.contract", 506, _registry())
	contract_domain.execute(ChooseCharacterCommand.new("run.duplicate.contract.character", "base.character.sequence"))
	var contract_accepted = contract_domain.execute(ChooseContractCommand.new("run.duplicate.contract.first", "base.contract.pressure"))
	var contract_before := contract_domain.checkpoint()
	var contract_rng_before := contract_domain.rng_snapshot()
	var contract_duplicate = contract_domain.execute(ChooseContractCommand.new("run.duplicate.contract.again", "base.contract.pressure"))

	assert_true(contract_accepted.accepted, "duplicate Contract setup is accepted", failures)
	assert_true(not contract_duplicate.accepted, "repeating a selected Contract is rejected", failures)
	assert_true(contract_duplicate.validation.code == "DUPLICATE_CHOICE", "duplicate Contract choice rejection is explicit", failures)
	assert_true(contract_domain.checkpoint() == contract_before, "duplicate Contract choice leaves RunState unchanged", failures)
	assert_true(contract_domain.rng_snapshot() == contract_rng_before, "duplicate Contract choice leaves every RNG stream unchanged", failures)

func test_preview_choice_is_atomic_and_not_replayable(failures: Array[String]) -> void:
	var domain := RunDomain.new("run.preview", 606, _registry())
	var before := domain.checkpoint()
	var rng_before := domain.rng_snapshot()
	var result = domain.execute(ChooseCharacterCommand.new(
		"run.preview.character",
		"base.character.sequence",
		"player.1",
		"",
		true,
	))

	assert_true(not result.accepted, "preview Character choice is not accepted authoritatively", failures)
	assert_true(result.preview, "preview result is marked as preview", failures)
	assert_true(not result.replayable, "preview result is not replayable", failures)
	assert_true(result.events.is_empty(), "preview choice emits no authoritative events", failures)
	assert_true(domain.checkpoint() == before, "preview choice leaves RunState unchanged", failures)
	assert_true(domain.rng_snapshot() == rng_before, "preview choice leaves every RNG stream unchanged", failures)

func test_commands_use_stable_content_ids(failures: Array[String]) -> void:
	var command := ChooseCharacterCommand.new("run.ids.character", "base.character.sequence", "player.1")
	var expected := {
		"command_id": "run.ids.character",
		"command_type": "ChooseCharacter",
		"actor_id": "player.1",
		"target_id": "",
		"preview": false,
		"character_id": "base.character.sequence",
	}

	assert_true(command.to_dictionary() == expected, "Character commands serialize a stable content ID", failures)
	assert_true(not command.to_dictionary().has("character_index"), "Character commands do not serialize UI indexes", failures)

func test_same_seed_and_commands_produce_same_run_checkpoint(failures: Array[String]) -> void:
	var first := RunDomain.new("run.deterministic", 707, _registry())
	var second := RunDomain.new("run.deterministic", 707, _registry())
	first.execute(ChooseCharacterCommand.new("run.deterministic.character", "base.character.sequence"))
	second.execute(ChooseCharacterCommand.new("run.deterministic.character", "base.character.sequence"))
	first.execute(ChooseContractCommand.new("run.deterministic.contract", "base.contract.pressure"))
	second.execute(ChooseContractCommand.new("run.deterministic.contract", "base.contract.pressure"))

	assert_true(first.checkpoint() == second.checkpoint(), "same seed and accepted run commands produce the same checkpoint", failures)
	assert_true(first.checkpoint().state_hash == second.checkpoint().state_hash, "deterministic checkpoints expose the same state hash", failures)

func test_terminal_summary_acknowledgment_is_authoritative(failures: Array[String]) -> void:
	var domain := RunDomain.new("run.terminal", 808, _registry())
	domain.execute(ChooseCharacterCommand.new("run.terminal.character", "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("run.terminal.contract", "base.contract.pressure"))
	var summary_events = domain.enter_run_summary("VICTORY", "completed_fixture", {"gold": 12})
	var summary_phase: String = domain.state.phase
	var before_ack := domain.checkpoint()
	var result = domain.execute(AcknowledgeRunSummaryCommand.new("run.terminal.ack"))

	assert_true(summary_events.size() == 2, "terminal outcome emits summary and phase facts", failures)
	assert_true(_has_event(summary_events, DomainEvent.RUN_SUMMARY_REACHED), "terminal outcome emits a factual summary event", failures)
	assert_true(_has_event(summary_events, DomainEvent.RUN_PHASE_CHANGED), "terminal outcome emits a factual phase transition event", failures)
	assert_true(summary_phase == RunPhase.RUN_SUMMARY, "terminal outcome enters Run Summary", failures)
	assert_true(domain.state.terminal_summary.outcome == "VICTORY", "RunState stores terminal outcome", failures)
	assert_true(result.accepted, "Run Summary acknowledgment is accepted", failures)
	assert_true(domain.state.phase == RunPhase.RUN_COMPLETE, "Run Summary acknowledgment reaches Run Complete", failures)
	assert_true(_has_event(result.events, DomainEvent.RUN_COMPLETED), "terminal acknowledgment emits a factual completion event", failures)
	assert_true(domain.checkpoint() != before_ack, "terminal acknowledgment advances the authoritative checkpoint", failures)
	var terminal_before := domain.checkpoint()
	var terminal_rng_before := domain.rng_snapshot()
	var terminal_repeat = domain.execute(AcknowledgeRunSummaryCommand.new("run.terminal.ack.again"))
	assert_true(not terminal_repeat.accepted, "acknowledgment after Run Complete is rejected", failures)
	assert_true(terminal_repeat.validation.code == "INVALID_PHASE", "terminal rejection reports the current phase", failures)
	assert_true(domain.checkpoint() == terminal_before, "terminal rejection leaves RunState unchanged", failures)
	assert_true(domain.rng_snapshot() == terminal_rng_before, "terminal rejection leaves every RNG stream unchanged", failures)

func _registry():
	var registry := ContentRegistry.new()
	for suit in ["characters", "bamboo", "dots"]:
		for rank in range(1, 10):
			registry.register(TileDefinition.new("base.tile.%s.%d" % [suit, rank], suit, rank))
	for honor in ["east", "south", "west", "north", "red", "green", "white"]:
		registry.register(TileDefinition.new("base.tile.honors.%s" % honor, "honors", 0))
	registry.register(RelicDefinition.new("base.relic.open_hand"))
	registry.register(TechniqueDefinition.new("base.technique.core.sequence_line", TechniqueDefinition.CORE, 1))
	registry.register(ContentDefinition.new("base.passive.sequence"))
	registry.register(CharacterDefinition.new(
		"base.character.sequence",
		["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3"],
		"base.relic.open_hand",
		"base.technique.core.sequence_line",
		"base.passive.sequence",
	))
	registry.register(CharacterDefinition.new(
		"base.character.triplet",
		["base.tile.characters.1", "base.tile.characters.2", "base.tile.characters.3"],
		"base.relic.open_hand",
		"base.technique.core.sequence_line",
		"base.passive.sequence",
	))
	registry.register(ContractDefinition.new("base.contract.pressure", ContractDefinition.PRESSURE, {"pressure": 1}, {"draw_actions": 1}))
	registry.register(ContractDefinition.new("base.contract.pool_bias", ContractDefinition.POOL_BIAS, {"pool": 1}, {"gold": 5}))
	return registry

func test_character_selection_advances_the_authoritative_run(failures: Array[String]) -> void:
	var domain := RunDomain.new("run.character", 4242, _registry())
	var result = domain.execute(ChooseCharacterCommand.new("run.character.choose", "base.character.sequence"))

	assert_true(result.accepted, "a valid Character choice is accepted", failures)
	assert_true(domain.state.phase == RunPhase.CONTRACT_SELECT, "Character choice advances to Contract Select", failures)
	assert_true(domain.state.character_id == "base.character.sequence", "RunState stores the stable Character ID", failures)
	assert_true(_has_event(result.events, DomainEvent.CHARACTER_SELECTED), "Character choice emits a factual CharacterSelected event", failures)
	assert_true(_has_event(result.events, DomainEvent.RUN_PHASE_CHANGED), "Character choice emits a factual phase transition event", failures)
	assert_true(result.state_checkpoint == domain.checkpoint(), "accepted choice returns the resulting deterministic checkpoint", failures)

func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event.event_type == event_type:
			return true
	return false

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
