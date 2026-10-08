class_name ReplayTest
extends RefCounted

const BattleController = preload("res://src/presentation/battle/battle_controller.gd")
const CommandResult = preload("res://src/domain/commands/command_result.gd")
const DrawCommand = preload("res://src/domain/commands/draw_command.gd")
const ResolveEnemyIntentCommand = preload("res://src/domain/commands/resolve_enemy_intent_command.gd")
const SettlePatternCommand = preload("res://src/domain/commands/settle_pattern_command.gd")
const ReplayCommandFactory = preload("res://src/infrastructure/replay/replay_command_factory.gd")
const ReplayCommandRecord = preload("res://src/infrastructure/replay/replay_command_record.gd")
const ReplayVerifier = preload("res://src/infrastructure/replay/replay_verifier.gd")
const DeterministicSerializer = preload("res://src/infrastructure/serialization/deterministic_serializer.gd")
const SaveMapper = preload("res://src/infrastructure/persistence/save_mapper.gd")
const SaveCoordinator = preload("res://src/infrastructure/persistence/save_coordinator.gd")
const ReplayRecord = preload("res://src/infrastructure/replay/replay_record.gd")
const RunDomain = preload("res://src/domain/run/run_domain.gd")
const RunTileInstanceRecord = preload("res://src/domain/run/run_tile_instance_record.gd")
const ChooseCharacterCommand = preload("res://src/domain/commands/choose_character_command.gd")
const ChooseContractCommand = preload("res://src/domain/commands/choose_contract_command.gd")
const SelectMapNodeCommand = preload("res://src/domain/commands/select_map_node_command.gd")
const ChooseRewardCommand = preload("res://src/domain/commands/choose_reward_command.gd")
const BuyShopOfferCommand = preload("res://src/domain/commands/buy_shop_offer_command.gd")
const RefreshShopCommand = preload("res://src/domain/commands/refresh_shop_command.gd")
const UseWorkshopServiceCommand = preload("res://src/domain/commands/use_workshop_service_command.gd")
const EnterEventCommand = preload("res://src/domain/commands/enter_event_command.gd")
const ChooseEventOptionCommand = preload("res://src/domain/commands/choose_event_option_command.gd")
const EnterShopCommand = preload("res://src/domain/commands/enter_shop_command.gd")
const ExitShopCommand = preload("res://src/domain/commands/exit_shop_command.gd")
const EnterWorkshopCommand = preload("res://src/domain/commands/enter_workshop_command.gd")
const ExitWorkshopCommand = preload("res://src/domain/commands/exit_workshop_command.gd")
const AcknowledgeRunSummaryCommand = preload("res://src/domain/commands/acknowledge_run_summary_command.gd")
const Phase2Catalog = preload("res://src/content/catalogs/phase_2_catalog.gd")
const ContentRegistry = preload("res://src/content/registry/content_registry.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	test_replay_command_serialization_has_stable_order(failures)
	test_replay_excludes_rejected_and_preview_commands(failures)
	test_identical_replay_reproduces_checkpoints_and_terminal_outcome(failures)
	test_changed_command_is_structured_divergence(failures)
	test_replay_game_and_schema_versions_are_validated(failures)
	test_replay_missing_schema_identity_is_unavailable(failures)
	test_unavailable_content_version_is_structured(failures)
	test_phase2_v1_replay_stays_pinned_and_mismatches_v2(failures)
	test_phase2_v2_replay_is_unavailable_under_updated_events(failures)
	test_rng_divergence_is_structured(failures)
	test_run_domain_records_only_accepted_commands_and_events(failures)
	test_run_replay_is_byte_stable_and_reproducible(failures)
	test_run_command_factory_round_trips_stable_payloads(failures)
	test_run_replay_reports_unsupported_commands(failures)
	test_run_replay_crosses_suspend_resume(failures)
	test_run_replay_records_bounded_battle_command(failures)
	return failures

func run_run_replay() -> Array[String]:
	var failures: Array[String] = []
	test_phase2_v2_replay_is_unavailable_under_updated_events(failures)
	test_run_domain_records_only_accepted_commands_and_events(failures)
	test_run_replay_is_byte_stable_and_reproducible(failures)
	test_run_command_factory_round_trips_stable_payloads(failures)
	test_run_replay_reports_unsupported_commands(failures)
	test_run_replay_crosses_suspend_resume(failures)
	test_run_replay_records_bounded_battle_command(failures)
	return failures

func test_replay_command_serialization_has_stable_order(failures: Array[String]) -> void:
	var command := SettlePatternCommand.new(
		"replay.settle.1",
		["tile.b", "tile.a"],
		"player.1",
		"battle.hand",
	)
	var expected := "{\"actor_id\":\"player.1\",\"command_id\":\"replay.settle.1\",\"command_type\":\"SettlePattern\",\"instance_ids\":[\"tile.a\",\"tile.b\"],\"preview\":false,\"target_id\":\"battle.hand\"}"
	assert_true(command.serialize() == expected, "command serialization has a stable field and payload order", failures)

func test_replay_excludes_rejected_and_preview_commands(failures: Array[String]) -> void:
	var controller := BattleController.new(13, "content.replay.test")
	var preview_result = controller.submit(DrawCommand.new("replay.preview", "player.1", "", true))
	var rejected_result = controller.submit(SettlePatternCommand.new("replay.rejected", ["missing.tile"]))
	var accepted_result = controller.submit(DrawCommand.new("replay.accepted", "player.1"))

	assert_true(preview_result.status == CommandResult.PREVIEW_ONLY, "preview command has preview status", failures)
	assert_true(not rejected_result.accepted, "invalid command is rejected", failures)
	assert_true(accepted_result.accepted, "valid command is accepted", failures)
	assert_true(controller.replay_record.commands.size() == 1, "only accepted authoritative commands enter ReplayRecord", failures)
	assert_true(controller.replay_record.commands[0].command_id == "replay.accepted", "ReplayRecord excludes preview and rejected IDs", failures)

func test_identical_replay_reproduces_checkpoints_and_terminal_outcome(failures: Array[String]) -> void:
	var controller := BattleController.new(13, "content.replay.test")
	controller.submit(DrawCommand.new("replay.same.draw", "player.1"))
	var report = controller.verify_replay()

	assert_true(report.is_match(), "identical seed, content, commands, and checkpoints replay identically", failures)
	assert_true(report.terminal_outcome == controller.combat_state.terminal_outcome, "identical replay preserves terminal outcome", failures)

func test_rng_divergence_is_structured(failures: Array[String]) -> void:
	var controller := BattleController.new(13, "content.replay.test")
	controller.submit(DrawCommand.new("replay.rng.draw", "player.1"))
	var checkpoint = controller.replay_record.checkpoints[1]
	checkpoint.rng_state["streams"]["draw_wall"]["state"] += 1
	var report = controller.verify_replay()

	assert_true(report.is_diverged(), "a changed RNG checkpoint diverges", failures)
	assert_true(report.reason == "RNG_STATE_MISMATCH", "RNG divergence has a structured reason", failures)
	assert_true(report.checkpoint_index == 1, "RNG divergence identifies its checkpoint", failures)

func test_changed_command_is_structured_divergence(failures: Array[String]) -> void:
	var controller := BattleController.new(13, "content.replay.test")
	controller.submit(DrawCommand.new("replay.command.original", "player.1"))
	controller.replay_record.commands[0].command_id = "replay.command.changed"
	var report = controller.verify_replay()

	assert_true(report.is_diverged(), "a changed command diverges", failures)
	assert_true(report.reason == "COMMAND_MISMATCH", "command divergence has a structured reason", failures)

func test_unavailable_content_version_is_structured(failures: Array[String]) -> void:
	var controller := BattleController.new(13, "content.replay.test")
	controller.replay_record.content_version = "content.replay.changed"
	var report = controller.verify_replay()

	assert_true(report.is_unavailable(), "a missing matching content version makes replay unavailable", failures)
	assert_true(report.reason == "CONTENT_VERSION_UNAVAILABLE", "unavailable replay has a distinct structured reason", failures)

func test_replay_game_and_schema_versions_are_validated(failures: Array[String]) -> void:
	var record := ReplayRecord.new(2038, "content.slice.v1", "phase2.version.fixture")
	var record_data: Dictionary = record.to_dictionary()
	assert_true(record_data.get("game_version", "") == ReplayRecord.GAME_VERSION, "ReplayRecord stores the current mechanical rules identity", failures)
	var round_tripped = ReplayRecord.from_dictionary(record_data)
	assert_true(round_tripped.to_dictionary() == record_data, "ReplayRecord game-version metadata round-trips", failures)

	var unsupported_game := ReplayRecord.new(2038, "content.slice.v1", "phase2.version.fixture", "game.unavailable")
	var unsupported_game_serialization := unsupported_game.serialize()
	var game_report = ReplayVerifier.verify(unsupported_game, Callable())
	assert_true(game_report.is_unavailable() and game_report.reason == "GAME_VERSION_UNAVAILABLE", "replay verification rejects an unavailable game version", failures)
	assert_true(unsupported_game.serialize() == unsupported_game_serialization, "game-version rejection leaves the replay record unchanged", failures)

	var missing_game_data: Dictionary = record_data.duplicate(true)
	missing_game_data.erase("game_version")
	var missing_game = ReplayRecord.from_dictionary(missing_game_data)
	var missing_game_report = ReplayVerifier.verify(missing_game, Callable())
	assert_true(missing_game.game_version.is_empty(), "a missing legacy game version is not silently defaulted", failures)
	assert_true(missing_game_report.is_unavailable() and missing_game_report.reason == "GAME_VERSION_UNAVAILABLE", "a replay without a game version reports reproduction unavailable", failures)
	assert_true(not missing_game_data.has("game_version"), "decoding an unversioned replay does not rewrite its source record", failures)

	var unsupported_schema := ReplayRecord.new(2038, "content.slice.v1", "phase2.version.fixture")
	unsupported_schema.schema_version = 99
	var schema_report = ReplayVerifier.verify(unsupported_schema, Callable())
	assert_true(schema_report.is_unavailable() and schema_report.reason == "REPLAY_SCHEMA_VERSION_UNAVAILABLE", "replay verification rejects an unavailable schema version", failures)

func test_replay_missing_schema_identity_is_unavailable(failures: Array[String]) -> void:
	var controller := BattleController.new(73, "content.replay.missing-schema")
	controller.submit(DrawCommand.new("replay.missing-schema.draw", "player.1"))
	var record_data: Dictionary = controller.replay_record.to_dictionary()
	record_data.erase("schema_version")
	var record = ReplayRecord.from_dictionary(record_data)
	var factory_call_count := [0]
	var replay_factory := func(seed: int, content_version: String):
		factory_call_count[0] = int(factory_call_count[0]) + 1
		return BattleController.new(seed, content_version)

	var report = ReplayVerifier.verify(record, replay_factory, "content.replay.missing-schema")
	assert_true(report.is_unavailable(), "a ReplayRecord without an explicit schema identity is unavailable", failures)
	assert_true(report.reason == "REPLAY_SCHEMA_VERSION_UNAVAILABLE", "a missing schema identity has the structured unavailable reason", failures)
	assert_true(int(factory_call_count[0]) == 0, "a replay with a missing schema identity never starts playback", failures)

func test_phase2_v1_replay_stays_pinned_and_mismatches_v2(failures: Array[String]) -> void:
	var record := ReplayRecord.new(2039, "content.slice.v1", "phase2.v1.fixture")
	var original_serialization := record.serialize()
	var report = ReplayVerifier.verify(record, Callable(), ContentRegistry.CONTENT_VERSION)
	assert_true(report.is_unavailable(), "a v1 replay cannot claim reproduction under the active v3 bundle", failures)
	assert_true(report.status == "UNAVAILABLE", "a missing historical bundle has a distinct structured status", failures)
	assert_true(report.reason == "CONTENT_VERSION_UNAVAILABLE", "an unavailable v1 replay bundle is not misreported as behavioral divergence", failures)
	assert_true(record.content_version == "content.slice.v1", "verification does not relabel the original replay content version", failures)
	assert_true(record.serialize() == original_serialization, "verification does not rewrite the old replay record", failures)

func test_phase2_v2_replay_is_unavailable_under_updated_events(failures: Array[String]) -> void:
	var old_controller := BattleController.new(2040, "content.slice.v2")
	var original_serialization: String = old_controller.replay_record.serialize()
	var report = ReplayVerifier.verify(
		old_controller.replay_record,
		func(replay_seed: int, replay_content_version: String): return BattleController.new(replay_seed, replay_content_version),
		ContentRegistry.CONTENT_VERSION,
	)
	assert_true(report.is_unavailable(), "a Phase 2 v2 replay is unavailable under current Event rules", failures)
	assert_true(report.reason == "CONTENT_VERSION_UNAVAILABLE", "an old replay reports the explicit content-version boundary", failures)
	assert_true(old_controller.replay_record.serialize() == original_serialization, "version rejection does not rewrite the archived replay", failures)

func test_run_domain_records_only_accepted_commands_and_events(failures: Array[String]) -> void:
	var domain := _run_domain("replay.run.accepted", 9001)
	var preview = domain.execute(ChooseCharacterCommand.new("run.preview", "base.character.sequence", "player.1", "", true))
	var rejected = domain.execute(ChooseContractCommand.new("run.rejected", "base.contract.pressure"))
	var accepted_character = domain.execute(ChooseCharacterCommand.new("run.accepted.character", "base.character.sequence"))
	var accepted_contract = domain.execute(ChooseContractCommand.new("run.accepted.contract", "base.contract.pressure"))

	assert_true(preview.status == CommandResult.PREVIEW_ONLY, "RunDomain preview is non-authoritative", failures)
	assert_true(not rejected.accepted, "RunDomain rejected command is not accepted", failures)
	assert_true(accepted_character.accepted and accepted_contract.accepted, "RunDomain accepts valid selection commands", failures)
	assert_true(domain.replay_record.commands.size() == 2, "Run Replay excludes preview and rejected Commands", failures)
	assert_true(domain.replay_record.commands[0].command_id == "run.accepted.character", "Run Replay keeps the accepted Character ID", failures)
	assert_true(domain.replay_record.checkpoints[1].domain_events.size() == accepted_character.events.size(), "Run Replay records factual Domain events", failures)
	assert_true(domain.replay_record.checkpoints[1].domain_events[0]["event_type"] == "CharacterSelected", "Run Replay records event types, not presentation state", failures)

func test_run_replay_is_byte_stable_and_reproducible(failures: Array[String]) -> void:
	var first := _run_domain("replay.run.stable", 9002)
	var second := _run_domain("replay.run.stable", 9002)
	for domain in [first, second]:
		domain.execute(ChooseCharacterCommand.new("stable.character", "base.character.sequence"))
		domain.execute(ChooseContractCommand.new("stable.contract", "base.contract.pressure"))

	assert_true(first.replay_record.serialize() == second.replay_record.serialize(), "identical Run Replays serialize byte-for-byte", failures)
	assert_true(first.verify_replay().is_match(), "identical seed, content and accepted Run Commands replay identically", failures)
	assert_true(first.replay_record.checkpoints.back().rng_state == first.rng_snapshot(), "Run Replay checkpoint stores every RNG stream", failures)
	assert_true(first.replay_record.checkpoints.back().domain_snapshot.to_dictionary()["data"]["run_state"]["map_state"]["payload_ids"].size() == 10, "Run Replay checkpoint stores deterministic map payloads", failures)

func test_run_command_factory_round_trips_stable_payloads(failures: Array[String]) -> void:
	var commands: Array = [
		ChooseCharacterCommand.new("factory.character", "base.character.sequence", "player.1"),
		ChooseContractCommand.new("factory.contract", "base.contract.pressure", "player.1"),
		SelectMapNodeCommand.new("factory.map", "base.map_node.intro", "player.1"),
		ChooseRewardCommand.new("factory.reward", "reward.option", "reward.draft", "player.1"),
		BuyShopOfferCommand.new("factory.shop.buy", "shop.offer", "shop.entry", "player.1"),
		RefreshShopCommand.new("factory.shop.refresh", "shop.entry", "player.1"),
		UseWorkshopServiceCommand.new("factory.workshop", UseWorkshopServiceCommand.ADD_MODIFIER, "tile.1", "", "modifier.1", true, "player.1"),
		EnterEventCommand.new("factory.event.enter", "event.1", "player.1"),
		ChooseEventOptionCommand.new("factory.event.choose", "option.1", "event.1", "entry.1", "player.1"),
		EnterShopCommand.new("factory.shop.enter", "player.1"),
		ExitShopCommand.new("factory.shop.exit", "player.1"),
		EnterWorkshopCommand.new("factory.workshop.enter", "player.1"),
		ExitWorkshopCommand.new("factory.workshop.exit", "player.1"),
		AcknowledgeRunSummaryCommand.new("factory.summary", "player.1"),
	]
	for command in commands:
		var record := ReplayCommandRecord.new(command.to_dictionary())
		var restored = ReplayCommandFactory.from_record(record)
		assert_true(restored != null, "Replay factory supports %s" % command.command_type(), failures)
		if restored != null:
			assert_true(restored.serialize() == command.serialize(), "Replay factory preserves %s stable payload" % command.command_type(), failures)
	assert_true(not SelectMapNodeCommand.new("factory.no-index", "base.map_node.intro").to_dictionary().has("node_index"), "Map Replay uses stable node IDs", failures)

func test_run_replay_reports_unsupported_commands(failures: Array[String]) -> void:
	var domain := _run_domain("replay.run.unsupported", 9003)
	domain.execute(ChooseCharacterCommand.new("unsupported.character", "base.character.sequence"))
	var record = domain.replay_record
	var command = record.commands[0]
	command.command_type = "UnsupportedRunCommand"
	command.serialized_command = DeterministicSerializer.serialize_command(command.to_command_dictionary())
	var report = domain.verify_replay(record)

	assert_true(report.is_diverged(), "unsupported Run Command diverges", failures)
	assert_true(report.reason == "COMMAND_TYPE_UNSUPPORTED", "unsupported Run Command has a structured reason", failures)
	assert_true(report.expected == "UnsupportedRunCommand", "unsupported report identifies the stable command type", failures)

func test_run_replay_crosses_suspend_resume(failures: Array[String]) -> void:
	var domain := _run_domain("replay.run.resume", 9004)
	domain.execute(ChooseCharacterCommand.new("resume.character", "base.character.sequence"))
	domain.execute(ChooseContractCommand.new("resume.contract", "base.contract.pressure"))
	var resume_diagnostics: Array[Dictionary] = []
	var resume_factory := func(controller):
		var checkpoint: Dictionary = controller.checkpoint()
		if not ["MAP_NODE", "BATTLE_START", "SHOP", "WORKSHOP", "REWARD", "EVENT_CHOICE_BEFORE"].has(checkpoint.get("stable_boundary", "")):
			return controller
		var loaded = SaveMapper.load_into_domain(SaveMapper.suspend_snapshot(controller).to_dictionary(), controller.content_registry)
		if not loaded.accepted:
			resume_diagnostics.append(loaded.duplicate(true))
		return loaded.domain if loaded.accepted else null
	var report = domain.verify_replay(domain.replay_record, resume_factory)

	assert_true(report.is_match(), "Run Replay crossing Suspend/Resume matches uninterrupted execution (%s; resume=%s)" % [report.reason, resume_diagnostics], failures)

func _assert_accepted(domain: RunDomain, command, label: String, failures: Array[String]) -> void:
	var result = domain.execute(command)
	assert_true(result.accepted and result.replayable, "%s is accepted and replayable (%s: %s)" % [label, result.validation.code, result.message], failures)

func test_run_replay_records_bounded_battle_command(failures: Array[String]) -> void:
	var domain := _phase2_battle_domain("replay.bounded.battle", 9101)
	_assert_accepted(domain, ChooseCharacterCommand.new("bounded.character", "base.character.sequence"), "Character selection", failures)
	_assert_accepted(domain, ChooseContractCommand.new("bounded.contract", "base.contract.pressure"), "Contract selection", failures)
	_assert_accepted(domain, SelectMapNodeCommand.new("bounded.normal.intro", "base.map_node.intro"), "mandatory intro Normal Map selection", failures)
	var battle_result = domain.execute(DrawCommand.new("bounded.battle.draw", "player.1"))
	if not battle_result.accepted:
		battle_result = domain.execute(ResolveEnemyIntentCommand.new("bounded.battle.intent"))
	assert_true(battle_result.accepted and battle_result.replayable, "one bounded battle Command is accepted and replayable (%s: %s)" % [battle_result.validation.code, battle_result.message], failures)
	assert_true(domain.replay_record.commands.size() == 4, "the bounded replay contains Character, Contract, Map, and one battle Command", failures)
	var has_battle_command := false
	var has_battle_event := false
	for command in domain.replay_record.commands:
		if command.command_type in ["Draw", "ResolveEnemyIntent"]:
			has_battle_command = true
	for checkpoint in domain.replay_record.checkpoints:
		for event in checkpoint.domain_events:
			if event.get("event_type", "") == "BattleStarted":
				has_battle_event = true
	assert_true(has_battle_command, "the ReplayRecord contains the accepted battle Command", failures)
	assert_true(has_battle_event, "the ReplayRecord contains factual battle events", failures)
	var replay_factory: Callable = func(replay_seed: int, _replay_content_version: String):
		return _phase2_battle_domain("replay.bounded.battle", replay_seed)
	var report = ReplayVerifier.verify(domain.replay_record, replay_factory, domain.state.content_version)
	assert_true(report.is_match(), "bounded Phase2 battle replay matches (%s)" % report.reason, failures)

func _phase2_battle_domain(run_id: String, seed: int) -> RunDomain:
	var domain := _run_domain(run_id, seed)
	for index in range(20):
		domain.state.tile_pool.add_tile_instance(RunTileInstanceRecord.new(
			"%s.tile.%d" % [run_id, index + 1],
			"base.tile.characters.%d" % ((index % 9) + 1),
			"RUN",
			"RUN",
		))
	domain.replay_record = ReplayRecord.new(seed, domain.state.content_version, run_id)
	domain.replay_record.record_initial_checkpoint(domain.checkpoint(), domain.rng_snapshot(), "ONGOING")
	return domain

func _run_domain(run_id: String, seed: int) -> RunDomain:
	var registry := ContentRegistry.new()
	Phase2Catalog.register_all(registry)
	return RunDomain.new(run_id, seed, registry)

func assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("ASSERTION FAILED: " + message)
		push_error("ASSERTION FAILED: " + message)
